extends CanvasLayer
# Speedometer, gear indicator and multi-touch on-screen controls.

signal camera_toggled

var car: VehicleBody3D
var pads := {}
var touches := {}
var speed_label: Label
var gear_label: Label

const HOLD := ["left", "right", "gas", "brake", "handbrake"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # HUD works while paused

	speed_label = _make_label(56)
	speed_label.position = Vector2(30, 15)
	gear_label = _make_label(36)
	gear_label.position = Vector2(30, 85)

	_make_pad("left", "<")
	_make_pad("right", ">")
	_make_pad("gas", "GAS")
	_make_pad("brake", "BRAKE")
	_make_pad("handbrake", "HAND\nBRAKE")
	_make_pad("pause", "II")
	_make_pad("cam", "CAM")
	_make_pad("rev", "D")

	get_viewport().size_changed.connect(_layout)
	_layout()


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l


func _make_pad(id: String, text: String) -> void:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = Color(1, 1, 1, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	pads[id] = p


func _place(id: String, pos: Vector2, sz: Vector2) -> void:
	pads[id].position = pos
	pads[id].size = sz


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := minf(vs.y * 0.22, 150.0)
	var m := 30.0
	_place("left", Vector2(m, vs.y - s - m), Vector2(s, s))
	_place("right", Vector2(m + s + 20, vs.y - s - m), Vector2(s, s))
	_place("gas", Vector2(vs.x - s - m, vs.y - s * 1.3 - m), Vector2(s, s * 1.3))
	_place("brake", Vector2(vs.x - 2 * s - m - 20, vs.y - s - m), Vector2(s, s))
	_place("handbrake", Vector2(vs.x - 2 * s - m - 20, vs.y - 1.8 * s - m - 20), Vector2(s, s * 0.8))
	var t := s * 0.7
	_place("pause", Vector2(vs.x - t - m, m), Vector2(t, t))
	_place("cam", Vector2(vs.x - 2 * t - m - 15, m), Vector2(t, t))
	_place("rev", Vector2(vs.x - 3 * t - m - 30, m), Vector2(t, t))


func _pad_at(pos: Vector2) -> String:
	for id in pads:
		if pads[id].get_global_rect().has_point(pos):
			return id
	return ""


func _press(id: String) -> void:
	match id:
		"left": car.steer_input = 1.0
		"right": car.steer_input = -1.0
		"gas": car.throttle_input = 1.0
		"brake": car.brake_input = 1.0
		"handbrake": car.handbrake = true
		"pause": get_tree().paused = not get_tree().paused
		"cam": camera_toggled.emit()
		"rev":
			car.toggle_reverse()
			pads["rev"].get_child(0).text = "R" if car.reverse_mode else "D"


func _release(id: String) -> void:
	match id:
		"left", "right": car.steer_input = 0.0
		"gas": car.throttle_input = 0.0
		"brake": car.brake_input = 0.0
		"handbrake": car.handbrake = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var id := _pad_at(event.position)
			if id != "":
				touches[event.index] = id
				_press(id)
		elif touches.has(event.index):
			_release(touches[event.index])
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var now := _pad_at(event.position)
		var old: String = touches.get(event.index, "")
		if now != old:
			if old != "":
				_release(old)
				touches.erase(event.index)
			if now in HOLD:
				touches[event.index] = now
				_press(now)


func _process(_delta: float) -> void:
	var kmh := car.linear_velocity.length() * 3.6
	var fwd := -car.global_transform.basis.z.dot(car.linear_velocity)
	speed_label.text = "%d km/h" % int(kmh)
	if car.reverse_mode:
		gear_label.text = "Gear: R"
	elif absf(fwd) < 0.5:
		gear_label.text = "Gear: N"
	else:
		gear_label.text = "Gear: D%d" % clampi(int(kmh / 25.0) + 1, 1, 5)
