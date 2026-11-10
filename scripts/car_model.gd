extends Node3D
# Low-poly luxury convertible (pearl white body, cream seats). Built fully in code.
# Front of the car is -Z. Wheels are added separately by make_wheel_visual().

# [z, half_width, y_bottom, y_top]
const STATIONS := [
	[-2.45, 0.55, 0.34, 0.62],
	[-2.20, 0.85, 0.30, 0.72],
	[-1.60, 0.95, 0.28, 0.86],
	[-0.80, 0.97, 0.28, 0.98],
	[-0.20, 0.97, 0.28, 0.98],
	[0.70, 0.97, 0.28, 0.98],
	[1.50, 0.97, 0.28, 1.00],
	[2.10, 0.90, 0.30, 0.95],
	[2.45, 0.70, 0.36, 0.82],
]

const BODY_COLOR := Color(0.90, 0.92, 0.95)
const SEAT_COLOR := Color(0.85, 0.80, 0.70)
const DARK := Color(0.05, 0.05, 0.06)
const SILVER := Color(0.80, 0.82, 0.86)


func _ready() -> void:
	_build_body()
	_build_details()


func _mat(color: Color, metallic := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ring(z: float, w: float, yb: float, yt: float) -> Array:
	var h := yt - yb
	return [
		Vector3(-0.8 * w, yb, z),
		Vector3(-w, yb + 0.3 * h, z),
		Vector3(-w, yb + 0.7 * h, z),
		Vector3(-0.7 * w, yt, z),
		Vector3(0.7 * w, yt, z),
		Vector3(w, yb + 0.7 * h, z),
		Vector3(w, yb + 0.3 * h, z),
		Vector3(0.8 * w, yb, z),
	]


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _build_body() -> void:
	var rings := []
	for s in STATIONS:
		rings.append(_ring(s[0], s[1], s[2], s[3]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 8
	for i in range(rings.size() - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for j in range(n):
			var j2 := (j + 1) % n
			_tri(st, r0[j], r1[j], r1[j2])
			_tri(st, r0[j], r1[j2], r0[j2])
	# End caps (nose and tail)
	for idx in [0, rings.size() - 1]:
		var r: Array = rings[idx]
		var c := Vector3.ZERO
		for p in r:
			c += p
		c /= float(n)
		for j in range(n):
			_tri(st, c, r[j], r[(j + 1) % n])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(BODY_COLOR, 0.5, 0.3)
	add_child(mi)


func _add_box(size: Vector3, pos: Vector3, color: Color, rot_deg := Vector3.ZERO, metallic := 0.0, rough := 0.6, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := _mat(Color(color.r, color.g, color.b, alpha), metallic, rough)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi


func _build_details() -> void:
	# Cabin floor (cream leather) on the open deck
	_add_box(Vector3(1.30, 0.02, 2.30), Vector3(0, 1.0, 0.45), SEAT_COLOR)
	# Dashboard
	_add_box(Vector3(1.60, 0.16, 0.30), Vector3(0, 1.08, -0.50), DARK)
	# Front seats (driver on right side, +X) and rear seats
	for x in [-0.42, 0.42]:
		_add_box(Vector3(0.50, 0.12, 0.50), Vector3(x, 1.06, 0.30), SEAT_COLOR)
		_add_box(Vector3(0.50, 0.55, 0.10), Vector3(x, 1.32, 0.58), SEAT_COLOR, Vector3(-12, 0, 0))
		_add_box(Vector3(0.46, 0.12, 0.40), Vector3(x, 1.06, 1.15), SEAT_COLOR)
		_add_box(Vector3(0.46, 0.45, 0.10), Vector3(x, 1.28, 1.42), SEAT_COLOR, Vector3(-10, 0, 0))
	# Steering wheel (right side)
	var sw := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.17
	cyl.bottom_radius = 0.17
	cyl.height = 0.03
	sw.mesh = cyl
	sw.material_override = _mat(DARK)
	sw.position = Vector3(0.42, 1.22, -0.20)
	sw.rotation_degrees = Vector3(-65, 0, 0)
	add_child(sw)
	# Windshield (glass) and A-pillar frame
	_add_box(Vector3(1.50, 0.02, 0.75), Vector3(0, 1.17, -0.55), Color(0.35, 0.50, 0.60), Vector3(-38, 0, 0), 0.0, 0.1, 0.35)
	for x in [-0.78, 0.78]:
		_add_box(Vector3(0.04, 0.04, 0.80), Vector3(x, 1.17, -0.55), SILVER, Vector3(-38, 0, 0), 0.8, 0.2)
	_add_box(Vector3(1.56, 0.04, 0.04), Vector3(0, 1.36, -0.24), SILVER, Vector3.ZERO, 0.8, 0.2)
	# Side mirrors
	for x in [-1.0, 1.0]:
		_add_box(Vector3(0.12, 0.08, 0.14), Vector3(x, 1.10, -0.70), BODY_COLOR, Vector3.ZERO, 0.5, 0.3)
	# Front grille and headlights
	_add_box(Vector3(0.80, 0.22, 0.04), Vector3(0, 0.48, -2.43), DARK)
	for x in [-0.62, 0.62]:
		_add_box(Vector3(0.34, 0.08, 0.06), Vector3(x, 0.66, -2.28), Color(0.15, 0.2, 0.3), Vector3(0, 0, 0), 0.8, 0.1)
	# Tail lights
	for x in [-0.60, 0.60]:
		_add_box(Vector3(0.40, 0.08, 0.04), Vector3(x, 0.78, 2.42), Color(0.8, 0.05, 0.05))


func make_wheel_visual() -> Node3D:
	# Wheel axis is X. Tyre + dark rim + silver spokes.
	var root := Node3D.new()
	var tyre := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.36
	tm.bottom_radius = 0.36
	tm.height = 0.28
	tyre.mesh = tm
	tyre.material_override = _mat(DARK, 0.0, 0.9)
	tyre.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(tyre)

	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.27
	rm.bottom_radius = 0.27
	rm.height = 0.30
	rim.mesh = rm
	rim.material_override = _mat(Color(0.08, 0.08, 0.09), 0.6, 0.4)
	rim.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(rim)

	for i in range(5):
		var sp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.31, 0.035, 0.52)
		sp.mesh = bm
		sp.material_override = _mat(SILVER, 0.9, 0.25)
		sp.rotation_degrees = Vector3(i * 36.0, 0, 0)
		root.add_child(sp)
	return root
