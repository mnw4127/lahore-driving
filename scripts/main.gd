extends Node3D
# Loads real roads from res://map_data/map.osm if present, otherwise builds a test road.

const MAP_PATH := "res://map_data/map.osm"

var car: VehicleBody3D
var chase_cam: Camera3D
var cockpit_cam: Camera3D
var hud: CanvasLayer
var first_person := false
var spawn_pos := Vector3(2.0, 1.0, 0.0)
var spawn_yaw := 0.0


func _ready() -> void:
	_make_environment()
	_make_world()
	_make_car()
	_make_hud()


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = false
	add_child(sun)


func _make_world() -> void:
	var loader: Node3D = load("res://scripts/osm_loader.gd").new()
	add_child(loader)
	if loader.load_map(MAP_PATH):
		spawn_pos = loader.spawn_pos
		spawn_yaw = loader.spawn_yaw
	else:
		_make_test_world()


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(mi)
	body.add_child(cs)
	add_child(body)


func _make_test_world() -> void:
	_box(Vector3(800, 1, 1200), Vector3(0, -0.5, -300), Color(0.25, 0.5, 0.2))
	_box(Vector3(10, 0.05, 500), Vector3(0, 0.025, -200), Color(0.15, 0.15, 0.17))
	_box(Vector3(400, 0.05, 10), Vector3(0, 0.03, -120), Color(0.15, 0.15, 0.17))
	for i in range(0, 24):
		var z := 40.0 - i * 20.0
		if abs(z + 120.0) < 12.0:
			continue
		for side in [-1, 1]:
			var x: float = side * 9.0
			_box(Vector3(0.4, 3, 0.4), Vector3(x, 1.5, z), Color(0.4, 0.25, 0.1))
			_box(Vector3(2.2, 2.2, 2.2), Vector3(x, 4, z), Color(0.1, 0.4, 0.1))
			var h: float = 6.0 + (i % 4) * 3.0
			_box(Vector3(10, h, 12), Vector3(side * 20.0, h / 2.0, z - 6), Color(0.75, 0.7, 0.62))


func _make_car() -> void:
	car = VehicleBody3D.new()
	car.set_script(load("res://scripts/car.gd"))
	car.mass = 800.0
	car.position = spawn_pos
	car.rotation.y = spawn_yaw

	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.8, 0.7, 4.0)
	cs.shape = sh
	cs.position = Vector3(0, 0.6, 0)
	car.add_child(cs)

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.7, 4.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.9)
	bm.material = mat
	body.mesh = bm
	body.position = Vector3(0, 0.6, 0)
	car.add_child(body)

	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.6, 0.6, 2.0)
	cm.material = mat
	cabin.mesh = cm
	cabin.position = Vector3(0, 1.25, 0.3)
	car.add_child(cabin)

	for x in [-0.9, 0.9]:
		for z in [-1.3, 1.3]:
			var w := VehicleWheel3D.new()
			w.position = Vector3(x, 0.35, z)
			w.wheel_radius = 0.35
			w.wheel_rest_length = 0.15
			w.suspension_travel = 0.3
			w.suspension_stiffness = 40.0
			w.wheel_friction_slip = 3.0
			w.use_as_steering = z < 0
			w.use_as_traction = z > 0
			var wm := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.35
			cyl.bottom_radius = 0.35
			cyl.height = 0.3
			var wmat := StandardMaterial3D.new()
			wmat.albedo_color = Color(0.05, 0.05, 0.05)
			cyl.material = wmat
			wm.mesh = cyl
			wm.rotation_degrees = Vector3(0, 0, 90)
			w.add_child(wm)
			car.add_child(w)

	cockpit_cam = Camera3D.new()
	cockpit_cam.position = Vector3(0.4, 1.3, -0.1)
	cockpit_cam.fov = 75
	cockpit_cam.far = 1500.0
	car.add_child(cockpit_cam)

	add_child(car)

	chase_cam = Camera3D.new()
	chase_cam.fov = 70
	chase_cam.far = 1500.0
	add_child(chase_cam)
	chase_cam.global_position = car.global_position + car.global_transform.basis.z * 7.0 + Vector3(0, 3, 0)
	chase_cam.make_current()


func _make_hud() -> void:
	hud = load("res://scripts/hud.gd").new()
	hud.car = car
	hud.camera_toggled.connect(_toggle_camera)
	add_child(hud)


func _toggle_camera() -> void:
	first_person = not first_person
	if first_person:
		cockpit_cam.make_current()
	else:
		chase_cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_toggle_camera()


func _physics_process(delta: float) -> void:
	var back := car.global_transform.basis.z
	var target := car.global_position + back * 7.0 + Vector3(0, 2.8, 0)
	chase_cam.global_position = chase_cam.global_position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	chase_cam.look_at(car.global_position + Vector3(0, 1.0, 0), Vector3.UP)

	if car.global_position.y < -10.0:
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		car.global_transform = Transform3D(Basis(Vector3.UP, spawn_yaw), spawn_pos)
