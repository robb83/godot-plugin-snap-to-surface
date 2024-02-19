extends EditorNode3DGizmoPlugin

func _get_gizmo_name():
	return "Area3D Orientation"

func _init():
	create_material("front", Color(0, 0, 1))
	create_material("left", Color(1, 0, 0))

func _has_gizmo(node):
	return node is Area3D
	return false

func _redraw(gizmo):
	gizmo.clear()
	
	var front = PackedVector3Array()
	front.push_back(Vector3())
	front.push_back(Vector3.MODEL_FRONT * 2)
	
	var left = PackedVector3Array()
	left.push_back(Vector3())
	left.push_back(Vector3.MODEL_LEFT * 2)
	
	gizmo.add_lines(front, get_material("front", gizmo), false)
	gizmo.add_lines(left, get_material("left", gizmo), false)
