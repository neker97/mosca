extends CanvasLayer

@onready var arena: Node3D = get_parent()
@onready var label_a: Label = $MarginContainer/HBoxContainer/PanelA/VBoxA/LabelA
@onready var label_b: Label = $MarginContainer/HBoxContainer/PanelB/VBoxB/LabelB
@onready var hp_bar_a: TextureProgressBar = $MarginContainer/HBoxContainer/PanelA/VBoxA/HPBarA
@onready var hp_bar_b: TextureProgressBar = $MarginContainer/HBoxContainer/PanelB/VBoxB/HPBarB
@onready var name_edit_a: LineEdit = $MarginContainer/HBoxContainer/PanelA/VBoxA/NameEditA
@onready var name_edit_b: LineEdit = $MarginContainer/HBoxContainer/PanelB/VBoxB/NameEditB
@onready var win_banner: Label = $WinBanner
@onready var btn_stop: Button = $Controls/BtnStop
@onready var btn_start: Button = $Controls/BtnStart
@onready var btn_restart: Button = $Controls/BtnRestart
@onready var btn_mute: Button = $BtnMute

const BANNER_DURATION := 3.0

var _last_winner_seen: String = ""
var _banner_hide_at: float = -1.0


func _ready() -> void:
	btn_stop.pressed.connect(func(): arena.set_paused(true))
	btn_start.pressed.connect(func(): arena.set_paused(false))
	btn_restart.pressed.connect(func(): arena.restart_round())
	btn_mute.pressed.connect(func(): arena.toggle_mute())
	name_edit_a.text_changed.connect(func(t): arena.fly_a_name = t)
	name_edit_b.text_changed.connect(func(t): arena.fly_b_name = t)


func _process(_delta: float) -> void:
	label_a.text = _fly_debug_text(arena.fly_a_name, arena.fly_a, arena.score_a)
	label_b.text = _fly_debug_text(arena.fly_b_name, arena.fly_b, arena.score_b)
	hp_bar_a.value = arena.fly_a.hp * 100.0
	hp_bar_b.value = arena.fly_b.hp * 100.0

	# rinominabili solo a partita ferma (Stop), altrimenti il nome
	# cambierebbe sotto le dita mentre arena.gd continua a leggerlo
	name_edit_a.editable = arena.sim_paused
	name_edit_b.editable = arena.sim_paused
	if not name_edit_a.has_focus():
		name_edit_a.text = arena.fly_a_name
	if not name_edit_b.has_focus():
		name_edit_b.text = arena.fly_b_name
	btn_mute.text = "Audio" if arena.muted else "Muto"

	if arena.last_winner != "" and arena.last_winner != _last_winner_seen:
		# nuovo round appena finito (arena.gd non azzera last_winner da solo
		# se non c'e' freeze_on_ko: senza questo timer il banner restava
		# visibile per sempre dopo la prima vittoria)
		_last_winner_seen = arena.last_winner
		_banner_hide_at = Time.get_ticks_msec() / 1000.0 + BANNER_DURATION
		win_banner.text = "%s VINCE!" % arena.last_winner if arena.last_winner != "PAREGGIO" else "PAREGGIO!"
	elif arena.last_winner == "":
		_last_winner_seen = ""

	win_banner.visible = _banner_hide_at > 0.0 and Time.get_ticks_msec() / 1000.0 < _banner_hide_at

	btn_stop.disabled = arena.sim_paused
	btn_start.disabled = not arena.sim_paused


func _fly_debug_text(fly_name: String, fly: Fly, score: int) -> String:
	var ctrl: AIController3D = fly.get_node("AIController")
	var obs: Array = ctrl.last_obs
	var obs_str := "n/d"
	if obs.size() == 6:
		obs_str = "dist=%.2f dir=(%.2f,%.2f) cd=%.2f hp=%.2f opp_hp=%.2f" % [
			obs[0], obs[1], obs[2], obs[3], obs[4], obs[5]
		]
	var action_str := "move=(%.2f,%.2f) lancia=%s" % [
		ctrl.last_move_action.x, ctrl.last_move_action.y, "SI" if ctrl.last_throw_action else "no"
	]
	return "%s  |  punteggio %d\nvede: %s\nfa: %s" % [fly_name, score, obs_str, action_str]
