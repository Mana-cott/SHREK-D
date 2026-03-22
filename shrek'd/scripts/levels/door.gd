extends Area3D

@export var front_mode : String

@onready var front = $door_front
@onready var col = $CollisionShape3D

# Called when the node enters the scene tree for the first time.
func _ready():
	match front_mode:
		"closed":
			col.disabled = false
			front.play("closed")
		"open":
			col.disabled = true
			front.play("open")
		"locked":
			col.disabled = false
			front.play("locked")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
