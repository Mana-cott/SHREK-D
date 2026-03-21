extends CharacterBody3D

const SPEED = 4
const LOOK_SENS = 0.5
const JUMP_FORCE = 4.5
const MAX_HEALTH = 4
const HURT_FACE_DURATION = 0.5
const BASH_SPEED = 28.0
const BASH_MIN_STAMINA = 10.0
const BASH_DRAIN_RATE = 35.0
const PUNCH_STAMINA_COST = 8.0
const STAMINA_REGEN = 18.0
const STAMINA_REGEN_DELAY = 1.5
const MAX_STAMINA = 100.0
const AFTERIMAGE_INTERVAL = 0.04

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_shoot = false
var dead = false
var punch_right_next = true
var health
var stamina = MAX_STAMINA
var roared_at = []
var mouse_x_velocity = 0.0
var stamina_regen_timer = 0.0
var hurt_face_timer = 0.0

# bash
var bashing = false
var bash_timer = 0.0
var bash_direction = Vector3.ZERO
var hit_during_bash = []
var afterimage_timer = 0.0

# punch transform changes
var left_arm_scale
var right_arm_scale
var left_arm_offset
var right_arm_offset
var left_tween: Tween
var right_tween: Tween

@onready var left_arm = $CanvasLayer/GunBase/LeftArm
@onready var right_arm = $CanvasLayer/GunBase/RightArm
@onready var shoulder = $CanvasLayer/GunBase/Shoulder
@onready var shrek_faces = $CanvasLayer/PlayerData/HBoxContainer/ShrekFace
@onready var stamina_bar = $CanvasLayer/PlayerData/HBoxContainer/VBoxContainer/Stamina
@onready var raycast = $RayCast3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	left_arm.play("idle")
	right_arm.play("idle")
	left_arm_scale = left_arm.scale
	right_arm_scale = right_arm.scale
	left_arm_offset = left_arm.offset
	right_arm_offset = right_arm.offset
	stamina_bar.min_value = 0
	stamina_bar.max_value = MAX_STAMINA
	stamina_bar.value = MAX_STAMINA
	health = MAX_HEALTH
	can_shoot = true
	
	# set visibility
	shoulder.visible = false
	left_arm.visible = true
	right_arm.visible = true

func _input(event):
	if dead:
		return
	if event is InputEventMouseMotion:
		rotation_degrees.y -= LOOK_SENS * event.relative.x
		mouse_x_velocity = event.relative.x

func _process(delta):
	if Input.is_action_pressed("exit"):
		get_tree().quit()
	if dead:
		return
	if Input.is_action_just_pressed("shoot"):
		shoot()
	if Input.is_action_just_pressed("charge") and not bashing:
		start_bash()
	if Input.is_action_just_released("charge") and bashing:
		end_bash()

func _physics_process(delta):
	# stamina regen
	if not bashing:
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		else:
			stamina = min(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
	stamina_bar.value = stamina

	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	if bashing:
		tick_bash(delta)
		move_and_slide()
		update_animations()
		update_face(delta)
		return

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
	update_animations()
	update_face(delta)

func start_bash():
	if dead or stamina < BASH_MIN_STAMINA:
		return
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var forward = -transform.basis.z
	if move_dir.dot(forward) < 0:
		move_dir = forward
	
	bash_direction = move_dir if move_dir.length() > 0.1 else -transform.basis.z
	
	bashing = true
	can_shoot = false
	afterimage_timer = 0.0
	hit_during_bash.clear()
	shoulder.visible = true
	left_arm.visible = false
	right_arm.visible = false
	shoulder.play("default")
	
func end_bash():
	bashing = false
	can_shoot = true
	hit_during_bash.clear()
	stamina_regen_timer = STAMINA_REGEN_DELAY
	shoulder.visible = false
	left_arm.visible = true
	right_arm.visible = true

func tick_bash(delta):
	# drain stamina
	stamina -= BASH_DRAIN_RATE * delta
	stamina = max(stamina, 0.0)
	if stamina <= 0:
		end_bash()
		return

	velocity.x = bash_direction.x * BASH_SPEED
	velocity.z = bash_direction.z * BASH_SPEED

	afterimage_timer -= delta
	if afterimage_timer <= 0:
		afterimage_timer = AFTERIMAGE_INTERVAL
		spawn_afterimage()

	for body in get_tree().get_nodes_in_group("enemies"):
		if body not in hit_during_bash and body.has_method("knockback"):
			if global_position.distance_to(body.global_position) < 2.5:
				hit_during_bash.append(body)
				body.knockback(bash_direction * 12.0)

func spawn_afterimage():
	var image = shoulder.duplicate() as AnimatedSprite2D
	image.play(shoulder.animation)
	image.frame = shoulder.frame
	$CanvasLayer.add_child(image)
	image.global_position = shoulder.global_position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(image, "modulate:a", 0.0, 0.25)
	tween.tween_property(image, "scale", image.scale * 1.1, 0.25)
	tween.chain().tween_callback(image.queue_free)

func shoot():
	if not can_shoot or dead:
		return
	if stamina < PUNCH_STAMINA_COST:
		return
	can_shoot = false
	stamina -= PUNCH_STAMINA_COST
	stamina_regen_timer = STAMINA_REGEN_DELAY
	
	if punch_right_next:
		right_arm.play("punch")
		_tween_arm_punch(right_arm, Vector2(-300, 0), right_arm_scale * 1.5)
	else:
		left_arm.play("punch")
		_tween_arm_punch(left_arm, Vector2(300, 0), left_arm_scale * 1.5)
	if raycast.is_colliding() and raycast.get_collider().has_method("take_damage"):
		raycast.get_collider().take_damage()

func update_animations():
	if dead:
		return
	if not can_shoot:
		return
	if not is_on_floor():
		left_arm.play("airborne")
		right_arm.play("airborne")
	else:
		left_arm.play("idle")
		right_arm.play("idle")

func update_face(delta):
	if dead:
		return
	if hurt_face_timer > 0:
		hurt_face_timer -= delta
		shrek_faces.play("hurt")
		mouse_x_velocity = 0.0
		return
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider not in roared_at and collider.has_method("kill"):
			roared_at.append(collider)
			shrek_faces.play("roar")
			mouse_x_velocity = 0.0
			return
	if shrek_faces.animation == "roar" and shrek_faces.is_playing():
		mouse_x_velocity = 0.0
		return
	if abs(mouse_x_velocity) > 40.0:
		if mouse_x_velocity > 0:
			shrek_faces.play("look_left")
		else:
			shrek_faces.play("look_right")
		mouse_x_velocity = 0.0
		return
	if shrek_faces.animation in ["look_left", "look_right"] and shrek_faces.is_playing():
		mouse_x_velocity = 0.0
		return
	mouse_x_velocity = 0.0
	match health:
		4: shrek_faces.play("health_3")
		3: shrek_faces.play("health_2")
		2: shrek_faces.play("health_1")
		1, 0: shrek_faces.play("health_0")

func take_damage():
	health -= 1
	hurt_face_timer = HURT_FACE_DURATION
	if health <= 0:
		kill()

func kill():
	dead = true
	$CanvasLayer/DeathScreen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_enemy_killed():
	shrek_faces.play("happy")

func _tween_arm_punch(arm: AnimatedSprite2D, target_offset: Vector2, target_scale: Vector2):
	if arm == left_arm and left_tween:
		left_tween.kill()
	elif arm == right_arm and right_tween:
		right_tween.kill()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(arm, "scale", target_scale, 0.08)
	tween.tween_property(arm, "offset", target_offset, 0.08)
	if arm == left_arm:
		left_tween = tween
	else:
		right_tween = tween

func _on_punch_finished():
	punch_right_next = !punch_right_next
	can_shoot = true
	for arm in [left_arm, right_arm]:
		if arm == left_arm and left_tween:
			left_tween.kill()
		elif arm == right_arm and right_tween:
			right_tween.kill()
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(arm, "scale", left_arm_scale if arm == left_arm else right_arm_scale, 0.25)
		tween.tween_property(arm, "offset", left_arm_offset if arm == left_arm else right_arm_offset, 0.25)
		if arm == left_arm:
			left_tween = tween
		else:
			right_tween = tween
	left_arm.play("idle")
	right_arm.play("idle")
