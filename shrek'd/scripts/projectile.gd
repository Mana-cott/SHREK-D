extends Area3D
const SPEED = 12.0
const LIFETIME = 4.0
var direction = Vector3.ZERO
var timer = 0.0
var source

@onready var sprite : AnimatedSprite3D = $AnimatedSprite3D

func _ready():
	sprite.play("default")
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _process(delta):
	timer += delta
	if timer >= LIFETIME:
		queue_free()
	global_position += direction * SPEED * delta

func _on_body_entered(body):
	if body == source:
		return
	if body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()
