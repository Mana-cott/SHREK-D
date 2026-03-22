extends CharacterBody3D

const KNOCKBACK_FRICTION = 8.0
@export var move_speed = 2.0
@export var attack_range = 3.0
@export var damage = 1.0
@export var max_health = 5
@export var type = "reg" # or cgd

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var health
var knockback_velocity = Vector3.ZERO
# Enemy states
var attacking = false
var hurt = false
var dead = false

@onready var player : CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var sprite : AnimatedSprite3D = $AnimatedSprite3D
@onready var alive_collision_shape : CollisionShape3D = $AliveCollisionShape
@onready var dead_collision_shape : CollisionShape3D = $DeadCollisionShape

func _ready():
	dead_collision_shape.disabled = true
	health = max_health
	
func _physics_process(delta):
	# decay knockback
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if dead or player == null:
		if dead:
			update_animations()
			move_and_slide()
			return

	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player <= attack_range and not hurt:
		attacking = true

	handle_movement(delta)
	update_animations()

func handle_movement(_delta):
	if dead:
		return

	if hurt:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
	elif attacking:
		velocity.x = 0
		velocity.z = 0
	else:
		var dir = (player.global_position - global_position).normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		
		# face player
		var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		look_at(look_target, Vector3.UP)
	
	move_and_slide()

func update_animations():
	# order of priority
	if dead:
		sprite.play("dead_" + type)
		return
	if hurt:
		sprite.play("hurt_" + type)
	elif attacking:
		sprite.play("attack_" + type)
	elif velocity.length() > 0.1:
		sprite.play("walk_" + type)
	else:
		sprite.play("idle_" + type)

func attempt_to_kill_player():
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player > attack_range:
		return
	
	var eye_line = Vector3.UP * 1.5
	var query = PhysicsRayQueryParameters3D.create(global_position + eye_line, player.global_position + eye_line, 1)
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	if result.is_empty():
		if player.has_method("take_damage"):
			player.take_damage(damage)
			
func take_damage(damage = 1):
	if dead:
		return
	health -= damage
	hurt = true
	if health <= 0:
		kill()
	
func knockback(force: Vector3):
	if dead:
		return
	knockback_velocity = force
	velocity.y = force.y
	attacking = false
	hurt = true

func kill():
	dead = true
	attacking = false
	hurt = false
	dead_collision_shape.disabled = false
	alive_collision_shape.disabled = true
	

func _on_animated_sprite_3d_animation_finished():
	if sprite.animation == "attack_" + type:
		attempt_to_kill_player()
		attacking = false
		
	if sprite.animation == "hurt_" + type:
		hurt = false
