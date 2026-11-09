extends Node3D
# Reads an OpenStreetMap .osm (XML) file and builds roads + buildings.
# North = -Z, East = +X. 1 unit = 1 metre.

const ROAD_WIDTH := {
	"motorway": 14.0, "trunk": 14.0, "primary": 12.0, "secondary": 10.0,
	"tertiary": 9.0, "unclassified": 7.0, "residential": 7.0,
	"living_street": 6.0, "service": 5.0,
	"motorway_link": 8.0, "trunk_link": 8.0, "primary_link": 8.0,
	"secondary_link": 7.0, "tertiary_link": 7.0,
}
const MAX_BUILDINGS := 1500
const ROAD_Y := 0.05

var spawn_pos := Vector3(0, 1.0, 0)
var spawn_yaw := 0.0
var road_count := 0
var building_count := 0

var _center := Vector2.ZERO
var _kx := 1.0
var _ky := 110540.0


func load_map(path: String) -> bool:
	if not FileAccess.file_exists(path):
		print("OSM: file not found: ", path)
		return false
	var data := _parse(path)
	if data.is_empty():
		print("OSM: could not read file")
		return false

	var nodes: Dictionary = data["nodes"]
	var ways: Array = data["ways"]
	if nodes.size() == 0:
		return false

	var sum := Vector2.ZERO
	for id in nodes:
		sum += nodes[id]
	_center = sum / float(nodes.size())
	_kx = 111320.0 * cos(deg_to_rad(_center.y))

	var road_lines := []
	var buildings := []
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)

	for way in ways:
		var tags: Dictionary = way["tags"]
		var pts := PackedVector2Array()
		for r in way["refs"]:
			if nodes.has(r):
				pts.append(_proj(nodes[r]))
		if pts.size() < 2:
			continue
		if tags.has("highway") and ROAD_WIDTH.has(tags["highway"]):
			road_lines.append({"pts": pts, "w": ROAD_WIDTH[tags["highway"]]})
			for p in pts:
				minp.x = minf(minp.x, p.x)
				minp.y = minf(minp.y, p.y)
				maxp.x = maxf(maxp.x, p.x)
				maxp.y = maxf(maxp.y, p.y)
		elif tags.has("building") and pts.size() >= 4 and buildings.size() < MAX_BUILDINGS:
			buildings.append({"pts": pts, "h": _height(tags)})

	if road_lines.is_empty():
		print("OSM: no roads found in file")
		return false

	_add_ground(minp, maxp)
	_build_roads(road_lines)
	_build_buildings(buildings)
	_find_spawn(road_lines)
	road_count = road_lines.size()
	building_count = buildings.size()
	print("OSM: roads=%d buildings=%d" % [road_count, building_count])
	return true


func _parse(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return {}
	var parser := XMLParser.new()
	if parser.open_buffer(bytes) != OK:
		return {}
	var nodes := {}
	var ways := []
	var cur = null
	while parser.read() == OK:
		var t := parser.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var n := parser.get_node_name()
			if n == "node":
				nodes[parser.get_named_attribute_value_safe("id")] = Vector2(
					float(parser.get_named_attribute_value_safe("lon")),
					float(parser.get_named_attribute_value_safe("lat")))
			elif n == "way":
				cur = {"refs": [], "tags": {}}
			elif n == "nd" and cur != null:
				cur["refs"].append(parser.get_named_attribute_value_safe("ref"))
			elif n == "tag" and cur != null:
				var k := parser.get_named_attribute_value_safe("k")
				cur["tags"][k] = parser.get_named_attribute_value_safe("v")
		elif t == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "way" and cur != null:
				ways.append(cur)
				cur = null
	return {"nodes": nodes, "ways": ways}


func _proj(ll: Vector2) -> Vector2:
	return Vector2((ll.x - _center.x) * _kx, -(ll.y - _center.y) * _ky)


func _height(tags: Dictionary) -> float:
	if tags.has("height") and str(tags["height"]).is_valid_float():
		return clampf(float(tags["height"]), 3.0, 80.0)
	if tags.has("building:levels") and str(tags["building:levels"]).is_valid_float():
		return clampf(float(tags["building:levels"]) * 3.0, 3.0, 80.0)
	return 8.0


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_ground(minp: Vector2, maxp: Vector2) -> void:
	var size := (maxp - minp) + Vector2(600, 600)
	var ctr := (minp + maxp) / 2.0
	var body := StaticBody3D.new()
	body.position = Vector3(ctr.x, -0.5, ctr.y)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 1, size.y)
	bm.material = _mat(Color(0.35, 0.45, 0.28))
	mi.mesh = bm
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size.x, 1, size.y)
	cs.shape = sh
	body.add_child(mi)
	body.add_child(cs)
	add_child(body)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _add_mesh_with_collision(st: SurfaceTool, color: Color) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, _mat(color))
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := mesh.create_trimesh_shape()
	if shape != null:
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	add_child(body)


func _build_roads(lines: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for l in lines:
		var pts: PackedVector2Array = l["pts"]
		var hw: float = float(l["w"]) / 2.0
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var d := b - a
			if d.length() < 0.01:
				continue
			var nrm := Vector2(-d.y, d.x).normalized() * hw
			var a1 := a + nrm
			var a2 := a - nrm
			var b1 := b + nrm
			var b2 := b - nrm
			_tri(st, Vector3(a1.x, ROAD_Y, a1.y), Vector3(b1.x, ROAD_Y, b1.y), Vector3(a2.x, ROAD_Y, a2.y))
			_tri(st, Vector3(b1.x, ROAD_Y, b1.y), Vector3(b2.x, ROAD_Y, b2.y), Vector3(a2.x, ROAD_Y, a2.y))
	st.generate_normals()
	_add_mesh_with_collision(st, Color(0.16, 0.16, 0.18))


func _build_buildings(list: Array) -> void:
	if list.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in list:
		var pts: PackedVector2Array = b["pts"]
		var h: float = b["h"]
		var n := pts.size()
		if pts[0].distance_to(pts[n - 1]) < 0.01:
			n -= 1
		if n < 3:
			continue
		var poly := PackedVector2Array()
		for i in range(n):
			poly.append(pts[i])
		for i in range(n):
			var p := poly[i]
			var q := poly[(i + 1) % n]
			var v1 := Vector3(p.x, 0.0, p.y)
			var v2 := Vector3(q.x, 0.0, q.y)
			var v3 := Vector3(q.x, h, q.y)
			var v4 := Vector3(p.x, h, p.y)
			_tri(st, v1, v2, v3)
			_tri(st, v1, v3, v4)
		var idx := Geometry2D.triangulate_polygon(poly)
		for k in range(0, idx.size(), 3):
			var r1 := poly[idx[k]]
			var r2 := poly[idx[k + 1]]
			var r3 := poly[idx[k + 2]]
			_tri(st, Vector3(r1.x, h, r1.y), Vector3(r2.x, h, r2.y), Vector3(r3.x, h, r3.y))
	st.generate_normals()
	_add_mesh_with_collision(st, Color(0.78, 0.72, 0.64))


func _find_spawn(lines: Array) -> void:
	var best := INF
	for l in lines:
		var pts: PackedVector2Array = l["pts"]
		for i in range(pts.size() - 1):
			var dist := pts[i].length()
			if dist < best:
				var d := pts[i + 1] - pts[i]
				if d.length() < 0.01:
					continue
				best = dist
				spawn_pos = Vector3(pts[i].x, 1.0, pts[i].y)
				spawn_yaw = atan2(-d.x, -d.y)
