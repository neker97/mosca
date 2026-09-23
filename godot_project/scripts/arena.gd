extends Node3D

const SYNC_CONTROL_MODE_HUMAN := 0  # Sync.ControlModes.HUMAN (addons/godot_rl_agents/sync.gd)
const SYNC_CONTROL_MODE_TRAINING := 1  # Sync.ControlModes.TRAINING
const SYNC_CONTROL_MODE_ONNX := 2  # Sync.ControlModes.ONNX_INFERENCE

@onready var fly_a: Fly = $FlyA
@onready var fly_b: Fly = $FlyB
@onready var sync: Node = $Sync
@onready var bgm: AudioStreamPlayer = $BGM
@onready var start_menu: CanvasLayer = $StartMenu
@onready var start_menu_name_a: LineEdit = $StartMenu/Panel/VBox/NameEditA
@onready var start_menu_name_b: LineEdit = $StartMenu/Panel/VBox/NameEditB
@onready var start_menu_btn: Button = $StartMenu/Panel/VBox/BtnStartMatch

var start_pos_a: Vector3
var start_pos_b: Vector3
var score_a: int = 0
var score_b: int = 0
var freeze_on_ko: bool = false  # --freeze_on_ko: niente reset automatico, per vedere il KO
var round_over: bool = false
var last_winner: String = ""  # nome mosca vincitrice / "PAREGGIO", letto dall'HUD per il banner
var sim_paused: bool = false
var fly_a_name: String = "MOSCA A"
var fly_b_name: String = "MOSCA B"
var muted: bool = false


func _ready() -> void:
	# Opt-in esplicito al training via CLI (--train). Di default Sync resta in
	# modalita' HUMAN (impostata sul nodo in arena.tscn): NON tenta mai la
	# connessione TCP al server RL, che su questa macchina si blocca a tempo
	# indeterminato quando nessun server e' in ascolto (bug/quirk WinSock,
	# osservato: 30s+ senza risolversi). Questo deve girare PRIMA che Sync
	# riprenda dal suo "await get_parent().ready".
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--train"):
			sync.control_mode = SYNC_CONTROL_MODE_TRAINING
		elif arg.begins_with("--freeze_on_ko"):
			freeze_on_ko = true
		elif arg.begins_with("--onnx"):
			# --onnx oppure --onnx=<nome senza estensione>, file cercato in
			# models/<nome>.onnx (fuori da res://, va esportato a mano prima
			# con export_onnx.py: sync.gd non carica .zip di stable-baselines3)
			var onnx_name := "fly_ppo_v2"
			var eq := arg.find("=")
			if eq != -1:
				onnx_name = arg.substr(eq + 1)
			sync.control_mode = SYNC_CONTROL_MODE_ONNX
			sync.onnx_model_path = ProjectSettings.globalize_path("res://../models/%s.onnx" % onnx_name)

	fly_a.opponent = fly_b
	fly_b.opponent = fly_a
	start_pos_a = fly_a.global_position
	start_pos_b = fly_b.global_position
	_reset_round()  # anche il primo round parte con lato random, non sempre A a sinistra

	# Il malus anti-passivita' (fly.gd: no_hit_timeout) e' solo un trucco di
	# reward shaping per il training PPO: in partita vera (demo o inferenza
	# ONNX) non deve esistere nessun limite di tempo, si vince solo azzerando
	# gli HP avversari.
	var is_training: bool = sync.control_mode == SYNC_CONTROL_MODE_TRAINING
	fly_a.enforce_no_hit_timeout = is_training
	fly_b.enforce_no_hit_timeout = is_training

	if sync.control_mode == SYNC_CONTROL_MODE_HUMAN:
		# demo alpha: nessun training ne' inferenza richiesti, le mosche giocano da sole
		fly_a.autonomous = true
		fly_b.autonomous = true
		print("Modalita' autonoma (demo alpha) attiva: le mosche giocano da sole.")

	start_menu_btn.pressed.connect(_on_start_match_pressed)
	if is_training or DisplayServer.get_name() == "headless":
		# --train o qualunque run --headless (es. batch di round automatici
		# per statistiche): nessun essere umano puo' cliccare "Inizia", quindi
		# il menu bloccherebbe tutto per sempre in attesa di un input che non
		# arrivera' mai
		start_menu.visible = false
	else:
		start_menu_name_a.text = fly_a_name
		start_menu_name_b.text = fly_b_name
		set_paused(true)
		start_menu.visible = true


func _on_start_match_pressed() -> void:
	if start_menu_name_a.text.strip_edges() != "":
		fly_a_name = start_menu_name_a.text
	if start_menu_name_b.text.strip_edges() != "":
		fly_b_name = start_menu_name_b.text
	start_menu.visible = false
	set_paused(false)


func _physics_process(_delta: float) -> void:
	if round_over:
		return
	if fly_a.hp <= 0.0 or fly_b.hp <= 0.0:
		_end_round()


func _end_round() -> void:
	var ctrl_a: AIController3D = fly_a.get_node("AIController")
	var ctrl_b: AIController3D = fly_b.get_node("AIController")
	var a_lost := fly_a.hp <= 0.0
	var b_lost := fly_b.hp <= 0.0

	if a_lost and b_lost:
		# doppio KO nello stesso frame (es. entrambe scadono per timeout
		# insieme, partendo sincronizzate): pareggio, nessun punto a nessuna.
		# Prima non c'era questo caso: veniva sempre attribuita la vittoria
		# a B perche' "fly_a.hp <= 0.0" e' il primo controllo nell'if/else,
		# risultato: punteggio 0-12 sempre a favore della stessa mosca.
		last_winner = "PAREGGIO"
	elif a_lost:
		ctrl_a.reward -= 10.0
		ctrl_b.reward += 10.0
		score_b += 1
		last_winner = fly_b_name
	else:
		ctrl_b.reward -= 10.0
		ctrl_a.reward += 10.0
		score_a += 1
		last_winner = fly_a_name
	ctrl_a.done = true
	ctrl_b.done = true

	print("[ROUND] vincitore=%s punteggio=%d-%d" % [last_winner, score_a, score_b])

	if freeze_on_ko:
		round_over = true
		return

	_reset_round()


func _reset_round() -> void:
	# spawn ruotato a random ad ogni round attorno al centro arena (non solo
	# sinistra/destra: qualunque angolo, alto/basso, diagonali, ecc), sempre
	# alla stessa distanza reciproca. Le due mosche si guardano comunque
	# sempre in faccia grazie al look_at in fly.gd (gira ogni frame verso
	# l'avversario, indipendente dallo spawn). Rimuove il bias di geometria
	# fissa nel training self-play (vedi analisi round automatici: 62.5%
	# vittorie rossa su 32 round quando lo spawn era sempre sinistra/destra).
	var center := (start_pos_a + start_pos_b) * 0.5
	var radius := start_pos_a.distance_to(center)
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
	fly_a.global_position = center + offset
	fly_b.global_position = center - offset
	fly_a.reset_state()
	fly_b.reset_state()


func restart_round() -> void:
	# richiamabile dal pulsante Restart in HUD, forza il reset anche se
	# freeze_on_ko e' attivo o non era ancora finito il round
	round_over = false
	last_winner = ""
	sim_paused = false
	fly_a.set_physics_process(true)
	fly_b.set_physics_process(true)
	_reset_round()


func set_paused(paused: bool) -> void:
	# non usa get_tree().set_pause(): Sync gia' mette in pausa/riprende
	# l'albero ad ogni step RL (protocollo di sincronizzazione col training),
	# un pause globale nostro verrebbe sovrascritto quasi subito da quello
	sim_paused = paused
	fly_a.set_physics_process(not paused)
	fly_b.set_physics_process(not paused)
	bgm.stream_paused = paused or muted


func toggle_mute() -> void:
	muted = not muted
	bgm.stream_paused = muted or sim_paused
