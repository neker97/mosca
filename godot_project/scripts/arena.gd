extends Node3D

const SYNC_CONTROL_MODE_TRAINING := 1  # Sync.ControlModes.TRAINING (addons/godot_rl_agents/sync.gd)

@onready var fly_a: Fly = $FlyA
@onready var fly_b: Fly = $FlyB
@onready var sync: Node = $Sync

var start_pos_a: Vector3
var start_pos_b: Vector3
var score_a: int = 0
var score_b: int = 0


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
			break

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
	if fly_a.hp <= 0.0 or fly_b.hp <= 0.0:
		_end_round()


func _end_round() -> void:
	var ctrl_a: AIController3D = fly_a.get_node("AIController")
	var ctrl_b: AIController3D = fly_b.get_node("AIController")
	if fly_a.hp <= 0.0:
		ctrl_a.reward -= 10.0
		ctrl_b.reward += 10.0
		score_b += 1
	else:
		ctrl_b.reward -= 10.0
		ctrl_a.reward += 10.0
		score_a += 1
	ctrl_a.done = true
	ctrl_b.done = true

	fly_a.global_position = start_pos_a
	fly_b.global_position = start_pos_b
	fly_a.reset_state()
	fly_b.reset_state()
