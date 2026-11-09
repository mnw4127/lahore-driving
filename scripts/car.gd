extends VehicleBody3D
# Car controls. Front of the car is -Z. steer_input: +1 = left, -1 = right.
# Tune these numbers on a real phone.

const MAX_ENGINE := 2500.0
const MAX_BRAKE := 20.0
const HANDBRAKE := 35.0
const MAX_STEER := 0.5
const MAX_SPEED_FWD := 28.0   # m/s (~100 km/h)
const MAX_SPEED_REV := 8.0    # m/s (~29 km/h)

var throttle_input := 0.0
var brake_input := 0.0
var steer_input := 0.0
var handbrake := false
var reverse_mode := false


func toggle_reverse() -> void:
	reverse_mode = not reverse_mode


func _physics_process(delta: float) -> void:
	var steer := steer_input
	var gas := throttle_input
	var brk := brake_input
	var hb := handbrake

	# Keyboard (for testing on PC)
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		steer = 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		steer = -1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		gas = 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		brk = 1.0
	if Input.is_physical_key_pressed(KEY_SPACE):
		hb = true

	var speed := linear_velocity.length()

	# Less steering at high speed
	var limit := lerpf(1.0, 0.3, clampf(speed / 25.0, 0.0, 1.0))
	steering = move_toward(steering, steer * MAX_STEER * limit, delta * 2.5)

	# Engine
	if reverse_mode:
		engine_force = -gas * MAX_ENGINE * 0.5 if speed < MAX_SPEED_REV else 0.0
	else:
		engine_force = gas * MAX_ENGINE if speed < MAX_SPEED_FWD else 0.0

	# Brakes
	if hb:
		brake = HANDBRAKE
	elif brk > 0.0:
		brake = brk * MAX_BRAKE
	elif gas == 0.0:
		brake = 1.0  # light engine braking
	else:
		brake = 0.0
