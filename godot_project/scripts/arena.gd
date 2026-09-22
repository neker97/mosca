extends Node3D

const SYNC_CONTROL_MODE_TRAINING := 1  # Sync.ControlModes.TRAINING (addons/godot_rl_agents/sync.gd)

@onready var fly_a: Fly = $FlyA
@onready var fly_b: Fly = $FlyB
@onready var sync: Node = $Sync

var start_pos_a: Vector3
var start_pos_b: Vector3
var score_a: int = 0
var score_b: int = 0
var freeze_on_ko: bool = false  # --freeze_on_ko: niente reset automatico, per vedere il KO
var round_over: bool = false
var last_winner: String = ""  # "MOSCA A" / "MOSCA B" / "PAREGGIO", letto dall'HUD per il banner
var sim_paused: bool = false


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

	fly_a.opponent = fly_b
	fly_b.opponent = fly_a
	start_pos_a = fly_a.global_position
	start_pos_b = fly_b.global_position

	if sync.control_mode != SYNC_CONTROL_MODE_TRAINING:
		# demo alpha: nessun training richiesto, le mosche giocano da sole
		fly_a.autonomous = true
		fly_b.autonomous = true
		print("Modalita' autonoma (demo alpha) attiva: le mosche giocano da sole.")


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
		last_winner = "MOSCA B"
	else:
		ctrl_b.reward -= 10.0
		ctrl_a.reward += 10.0
		score_a += 1
		last_winner = "MOSCA A"
	ctrl_a.done = true
	ctrl_b.done = true

	if freeze_on_ko:
		round_over = true
		return

	_reset_round()


func _reset_round() -> void:
	fly_a.global_position = start_pos_a
	fly_b.global_position = start_pos_b
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
