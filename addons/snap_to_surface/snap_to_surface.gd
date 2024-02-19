@tool
extends EditorPlugin

# references:
# https://github.com/remorse107/vertexsnap/blob/master/addons/vertexsnap/plugin.gd
# https://forums.unrealengine.com/t/rotation-from-normal/11543/3

const MyCustomGizmoPlugin = preload("res://addons/snap_to_surface/gizmo_area3d_orientation.gd")

var gizmo_plugin = MyCustomGizmoPlugin.new()
var toolbar_item : HBoxContainer = null
var toolbar_settings_popup : PopupMenu = null
var tool_active = false
var place_option = 0
var place_mode = 2
var last_selected_objects = []
var last_mouse_click : InputEventMouse = null
var last_camera : Camera3D = null

func clear_state():
	last_selected_objects.clear()
	last_mouse_click = null
	last_camera = null
	EditorInterface.get_selection().clear()

func create_anchor(node):
	var shape = SphereShape3D.new()
	shape.radius = 0.25
	
	var cshape = CollisionShape3D.new()
	cshape.shape = shape
	
	var area3d = Area3D.new()
	area3d.add_child(cshape)
	
	node.add_child(area3d)
	area3d.owner = node.owner
	cshape.owner = node.owner
	return area3d

func move_object_to(object, node, gp, n):
	var q = Quaternion(node.global_transform.basis.get_rotation_quaternion().get_axis(), node.global_transform.basis.get_rotation_quaternion().get_angle())
	object.global_transform = Transform3D(Basis(), gp)
	object.global_basis = object.global_transform.basis.looking_at(q * -n, Vector3.MODEL_FRONT)
	
func get_hypotenuse_middle_point(p1, p2, p3):
	var l1 = (p2 - p1).length()
	var l2 = (p3 - p1).length()
	var l3 = (p2 - p3).length()
	
	if l1 > l2 and l1 > l2:
		return p1.lerp(p2, 0.5)
	elif l3 > l2:
		return p3.lerp(p3, 0.5)
	else:
		return p1.lerp(p3, 0.5)
		
func get_mesh_from_object(object):
	if object:
		if object is CSGShape3D:
			var current = object
			while current.get_parent() is CSGShape3D:
				current = object.get_parent()
				var meshes = current.get_meshes()
			if current:
				var meshes = current.get_meshes()
				if len(meshes) == 2:
					return [current, meshes[1]]
		if object is MeshInstance3D:
			var am = ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, object.mesh.get_mesh_arrays())
			return [object, am]
	return []
	
func get_closest_face_to_camera(object, camera, mpos):
	var result = get_mesh_from_object(object)
	if not result or len(result) != 2: return []
	var current = result[0]
	var mesh = result[1]
	
	#Compute camera ray into scene
	var origin = camera.project_ray_origin(mpos)
	var dir = camera.project_ray_normal(mpos)
	
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	var closest_face = []
	
	for f in mdt.get_face_count():
		var gp1 = current.global_transform * mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var gp2 = current.global_transform * mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var gp3 = current.global_transform * mdt.get_vertex(mdt.get_face_vertex(f, 2))
		
		var hit = Geometry3D.ray_intersects_triangle(origin, dir, gp1, gp2, gp3 )
		if hit:
			var d = origin.distance_to(hit)
			if len(closest_face) == 0 || d < closest_face[0]:
				var n = mdt.get_face_normal(f)
				var p = hit
				if place_option == 1:
					p = get_hypotenuse_middle_point(gp1, gp2, gp3)
				closest_face = [ d, p, f, n, current]
	return closest_face
	
func event_occured():
	if place_mode == 2 and len(last_selected_objects) < 1: return
	if place_mode == 3 and len(last_selected_objects) < 2: return
	if not last_mouse_click: return
	if not last_camera: return
	
	var closest_face = get_closest_face_to_camera(last_selected_objects.pop_back(), last_camera, last_mouse_click.position)
	
	if len(closest_face) > 0:
		var hit = closest_face[1]
		var f = closest_face[2]
		var normal = closest_face[3]
		var current = closest_face[4]
		
		if place_mode == 2:
			move_object_to(create_anchor(current), current, hit, normal)
		elif place_mode == 3:
			move_object_to(last_selected_objects.pop_back(), current, hit, normal)
	clear_state()

func _forward_3d_gui_input(camera, event):
	if not tool_active: return
	if not (event is InputEventMouse): return
	if event.button_mask != MOUSE_BUTTON_MASK_LEFT: return
	if event.get_modifiers_mask() != 0: return
	last_mouse_click = event
	last_camera = camera
	event_occured()

func _handles(object):
	if not tool_active: return false
	return object is VisualInstance3D

func _edit(object):
	if not tool_active: return false
	if not object: return false
	if last_selected_objects.find(object) > -1: return false
	last_selected_objects.push_back(object)
	event_occured()
	return true

func _enter_tree():
	toolbar_item = create_toolbar_item()
	
	# Initialization of the plugin goes here.
	add_node_3d_gizmo_plugin(gizmo_plugin)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar_item)
	set_input_event_forwarding_always_enabled()
	
func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_node_3d_gizmo_plugin(gizmo_plugin)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar_item)

func create_toolbar_item():
	var button = Button.new()
	button.theme_type_variation = "FlatButton"
	button.text = "A3DSTS"
	button.tooltip_text = "Snap Area3D to selected face."
	button.toggle_mode = true
	button.pressed.connect(button_pressed)
	button.flat = true
	
	var menu_button = MenuButton.new()
	menu_button.flat = true
	menu_button.icon = EditorInterface.get_editor_theme().get_icon("GuiTabMenu", "EditorIcons")
	menu_button.get_popup().add_separator("Where to place")
	menu_button.get_popup().add_radio_check_item("Place to hit point", 0)
	menu_button.get_popup().add_radio_check_item("Place to middle of hypotenuse", 1)
	menu_button.get_popup().add_separator("What to place")
	menu_button.get_popup().add_radio_check_item("Place new Area3D object", 2)
	menu_button.get_popup().add_radio_check_item("Move selected object", 3)
	menu_button.get_popup().id_pressed.connect(_on_item_menu_pressed)
	toolbar_settings_popup = menu_button.get_popup()
	menu_button.get_popup().set_item_checked(toolbar_settings_popup.get_item_index(0), true)
	menu_button.get_popup().set_item_checked(toolbar_settings_popup.get_item_index(2), true)
	
	var toolbar = HBoxContainer.new()
	toolbar.focus_mode = Control.FOCUS_NONE
	toolbar.add_child(button)
	toolbar.add_child(menu_button)
	return toolbar
	
func button_pressed():
	tool_active = not tool_active
	if tool_active:
		clear_state()

func _on_item_menu_pressed(id: int):
	if id == 0 or id == 1:
		place_option = id
		toolbar_settings_popup.set_item_checked(toolbar_settings_popup.get_item_index(0), place_option == 0) 
		toolbar_settings_popup.set_item_checked(toolbar_settings_popup.get_item_index(1), place_option == 1)
	elif id == 2 or id == 3:
		place_mode = id
		toolbar_settings_popup.set_item_checked(toolbar_settings_popup.get_item_index(2), place_mode == 2) 
		toolbar_settings_popup.set_item_checked(toolbar_settings_popup.get_item_index(3), place_mode == 3)
	clear_state()
