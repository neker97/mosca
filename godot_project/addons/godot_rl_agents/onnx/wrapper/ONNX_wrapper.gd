extends Resource
class_name ONNXModel
var inferencer_script = load("res://addons/godot_rl_agents/onnx/csharp/ONNXInference.cs")

var inferencer = null

## How many action values the model outputs
var action_output_size: int

## Used to differentiate models
## that only output continuous action mean (e.g. sb3, cleanrl export)
## versus models that output mean and logstd (e.g. rllib export)
var action_means_only: bool

## Whether action_means_value has been set already for this model
var action_means_only_set: bool

# Must provide the path to the model and the batch size
func _init(model_path, batch_size):
	inferencer = inferencer_script.new()
	action_output_size = inferencer.Initialize(model_path, batch_size)

# This function is the one that will be called from the game,
# requires the observations as an Dictionary and the state_ins as an int
# returns a Dictionary containing the action the model takes.
func run_inference(obs: Dictionary, state_ins: int) -> Dictionary:
	if inferencer == null:
		printerr("Inferencer not initialized")
		return {}
	return inferencer.RunInference(obs, state_ins)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		inferencer.FreeDisposables()
		inferencer.free()

# Check whether agent uses a continuous actions model with only action means or not
func set_action_means_only(agent_action_space):
	# Bug nella versione originale: richiedeva uno spazio azioni puramente
	# continuo per considerare "means only" (export sb3/cleanrl), quindi con
	# un'azione discreta mista (es. "throw") non veniva mai impostato e
	# sync.gd si aspettava mean+logstd, sfasando gli indici e sballando
	# _extract_action_dict (accesso fuori indice sull'array di output).
	# Fix: confronta la dimensione totale attesa in modalita' "means only"
	# con la reale dimensione di output del modello onnx, indipendentemente
	# dal mix di tipi. Stessa regola di collasso binario usata in
	# sync.gd::_extract_action_dict: uno spazio misto (continuo+discreto)
	# collassa ogni azione discreta binaria (size<=2) in 1 solo valore invece
	# di "size" logit (vedi commento li' per il motivo).
	action_means_only_set = true
	var has_continuous := false
	var has_discrete := false
	for action in agent_action_space:
		if agent_action_space[action]["action_type"] == "continuous":
			has_continuous = true
		else:
			has_discrete = true
	var is_mixed_space: bool = has_continuous and has_discrete

	var total_size: int = 0
	for action in agent_action_space:
		var action_type = agent_action_space[action]["action_type"]
		var size = agent_action_space[action]["size"]
		if action_type == "discrete" and is_mixed_space and size <= 2:
			total_size += 1
		else:
			total_size += size
	if total_size == action_output_size:
		action_means_only = true
