extends RigidBody3D

@export var speed: float = 14.0
@export var damage: float = 0.2
@export var lifetime: float = 4.0

var shooter: Fly


func _ready() -> void:
	add_to_group("fireball")
	gravity_scale = 0.0
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func launch(direction: Vector3) -> void:
	linear_velocity = direction * speed


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body is Fly:
		body.take_damage(damage)
		shooter.register_hit_dealt(damage)
	queue_free()
