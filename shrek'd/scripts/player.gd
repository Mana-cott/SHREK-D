extends CharacterBody3D

const SPEED = 6
const LOOK_SENS = 0.5
const JUMP_FORCE = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_shoot = false
var dead = false

# screen shake

@onready var left_arm = $CanvasLayer/GunBase/LeftArm
@onready var right_arm = $CanvasLayer/GunBase/RightArm
@onready var raycast = $RayCast3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	left_arm.play()
	right_arm.play()
	
func _input(event):
	if dead:
		return
	if event is InputEventMouseMotion:
		rotation_degrees.y -= LOOK_SENS * event.relative.x
		
func _process(delta):
	if Input.is_action_pressed("exit"):
		get_tree().quit()
		
	if dead:
		return
	if Input.is_action_just_pressed("shoot"):
		shoot()

func _physics_process(delta):
	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	move_and_slide()
		
func shoot():
	if !can_shoot:
		return
	can_shoot = false
	#right_arm.play("shoot")
	if raycast.is_colliding() and raycast.get_collider().has_method("kill"):
		raycast.get_collider().kill()

func kill():
	dead = true
	$CanvasLayer/DeathScreen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
