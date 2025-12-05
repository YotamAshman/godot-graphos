extends Node2D

# Unmodifiable constants - Changing these breaks logic
const NOT_FOUND = -1
const WIDTH_IRRELEVANT = -1.0
const ID_START = 0
const HOLD_THRESHOLD = 100.0 # msecs

# Modifiable constants - Changes appearance
const NODE_RADIUS = 30
const LINK_WIDTH = 5
const REC_COLOR = Color.BLUE
const REC_WIDTH = 3.0

var node_dict:Dictionary[int,GraphosNode] = {}
var node_links:Array[GraphosLink] = []
var current_node_id := ID_START 

# Left click hold node dragging
var currently_dragged_node_id := NOT_FOUND

# Storing nodes in process of linking
var id1_to_link := NOT_FOUND
var id2_to_link := NOT_FOUND

# Mass rectangle node slection data
var rec_select_pos1 := Vector2.ZERO
var selection := Rect2(0,0,0,0) # Holds selection area
var left_click_time := 0.0
var is_making_selection := false
# Dictionary for uniqueness - Only keys matter.
var selected_nodes:Dictionary = {}
var mass_move := false

class GraphosNode:
	var pos:Vector2
	var color:Color
	var radius:float
	var filled:bool
	var width:float
	var highlighted := false 
	
	func _init(pos, color, radius, filled, width=WIDTH_IRRELEVANT) -> void:
		self.pos = pos
		self.color = color
		self.radius = radius
		self.filled = filled
		self.width=width
	
	func contains(point: Vector2) -> bool:
		return pos.distance_to(point) <= self.radius
	
	func highlight() -> void:
		self.highlighted = true
		self.color = Color.RED
		
	func no_highlight() -> void:
		self.highlighted = false
		self.color = Color.GREEN
	
	func toggle_highlight() -> void:
		if self.highlight:
			self.color = Color.GREEN
			self.highlighted = false
		else:
			self.color = Color.RED
			self.highlighted = true
	
	func is_in_selection(selection:Rect2) -> bool:
		return selection.has_point(self.pos)

class GraphosLink:
	var node1_id:int		
	var node2_id:int		
	var color:Color
	
	func _init(id1:int, id2:int, color:Color) -> void:
		self.node1_id = id1
		self.node2_id = id2
		self.color = color
	
func add_green_node(pos:Vector2):
	var node = GraphosNode.new(pos,Color.GREEN,NODE_RADIUS,true)
	node_dict[current_node_id] = node
	current_node_id += 1

func link_nodes(id1:int, id2:int) -> void:
	var link = GraphosLink.new(id1,id2,Color.RED)
	node_links.append(link)
	
func remove_node(id:int) -> void:
	node_dict.erase(id)

func draw_graphos_node(node:GraphosNode):
	# Width only relevant if circle is not filled
	var width = WIDTH_IRRELEVANT
	if not node.filled:
		width = node.width
	
	draw_circle(node.pos,node.radius,node.color,node.filled,width,true)

func draw_graphos_link(link:GraphosLink):
	if node_dict.has(link.node1_id) and node_dict.has(link.node2_id):
		var pos1 = node_dict[link.node1_id].pos
		var pos2 = node_dict[link.node2_id].pos
		var color = link.color
		draw_line(pos1,pos2,color,LINK_WIDTH,true)
	else:
		# One or more of the link's nodes have been deleted, so the link should also be deleted
		node_links.erase(link)

func _process(delta: float) -> void:
	# Handles actual movement of node mouse dragging
	if currently_dragged_node_id != NOT_FOUND:
		node_dict[currently_dragged_node_id].pos = get_global_mouse_position()
		queue_redraw()
		
	if is_making_selection:
		queue_redraw()
		update_selected_nodes()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("delete") and selected_nodes.size() > 0:
		delete_selected_nodes()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		handle_left_click()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		handle_left_click_release()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var pos = get_global_mouse_position()
		handle_right_click(pos)
	
	# Handle selection movement of multiple nodes
	if event is InputEventMouseMotion and mass_move:
		var mouse_delta = event.relative
		for node_id in selected_nodes.keys():
			var new_pos = node_dict[node_id].pos + mouse_delta
			var screen_rect = get_viewport_rect()
			# Only moving node if it stays in screen
			if screen_rect.has_point(new_pos):
				node_dict[node_id].pos = new_pos
	
	# Basically calls _draw
	queue_redraw()

func _draw() -> void:
	if is_making_selection:
		draw_selection_rectangle()
	
	for node_id in node_dict.keys():
		var node = node_dict[node_id]
		if node_id in selected_nodes:
			node.highlight()
		elif node_id != id1_to_link and node_id != id2_to_link:
			node.no_highlight()
		draw_graphos_node(node)
	
	for link in node_links:
		draw_graphos_link(link)	
	
func handle_left_click():
	var pos = get_global_mouse_position()
	print_debug("Left click on pos: ",pos)
	var node_id = get_node_id_from_click_collision(pos)
	if node_id != NOT_FOUND:
		if selected_nodes.size() > 0:
			start_mass_move()
		else:
			currently_dragged_node_id = node_id
	else:
		left_click_time = Time.get_ticks_msec()
		rec_select_pos1 = pos
		start_rectangle_selection()
		
func handle_left_click_release():
	# Left click released - Stop node dragging
	currently_dragged_node_id = NOT_FOUND
	stop_rectangle_selection()
	stop_mass_move()
	# Checking if a rectangle slection was made, or a quick click to add node
	var click_duration = Time.get_ticks_msec() - left_click_time
	var initial_click_position = rec_select_pos1
	if click_duration < HOLD_THRESHOLD:
		if selected_nodes.size() > 0:
			# Left click happend while nodes are selected, erase selection
			# instead of creating another node
			selected_nodes.clear()
		else:
			add_green_node(initial_click_position)
	
func start_mass_move():
	mass_move = true
	
func stop_mass_move():
	mass_move = false

func start_rectangle_selection():
	is_making_selection = true
	
func stop_rectangle_selection():
	is_making_selection = false
	selection = Rect2(0,0,0,0) # Resetting selection

func draw_selection_rectangle():
	var mouse_pos = get_global_mouse_position()
	var rectangle = Rect2(rec_select_pos1, mouse_pos - rec_select_pos1).abs()
	selection = rectangle
	draw_rect(rectangle,REC_COLOR,false,REC_WIDTH,true)

func update_selected_nodes():
	var rectangle_selection = selection
	for node_id in node_dict.keys():
		var node = node_dict[node_id]
		if node.is_in_selection(rectangle_selection):
			selected_nodes[node_id] = true
			
func  delete_selected_nodes():
	for node_id in selected_nodes.keys():
		node_dict.erase(node_id)
	selected_nodes.clear()
	
func handle_right_click(pos:Vector2):
	print_debug("Right click on pos: ",pos)
	var node_id = get_node_id_from_click_collision(pos)
	if node_id != NOT_FOUND:
		# When 2 nodes are selected, create a link between them
		if id1_to_link == NOT_FOUND:
			id1_to_link = node_id
			node_dict[node_id].highlight()
			print("Selected first node")
		elif id2_to_link == NOT_FOUND:
			if node_id == id1_to_link:
				print("Selected same node. Removing selection")
				node_dict[node_id].no_highlight()
				id1_to_link = NOT_FOUND
				id2_to_link = NOT_FOUND
				return
				
			id2_to_link = node_id
			print("Linking two selected node ids: ", id1_to_link,", ", id2_to_link)
			link_nodes(id1_to_link,id2_to_link)
			node_dict[id1_to_link].no_highlight()
			id1_to_link = NOT_FOUND
			id2_to_link = NOT_FOUND
	else:
		print("Removing node selection")
		if id1_to_link != NOT_FOUND:
			node_dict[id1_to_link].toggle_highlight()
		if id2_to_link != NOT_FOUND:
			node_dict[id2_to_link].toggle_highlight()
		id1_to_link = NOT_FOUND
		id2_to_link = NOT_FOUND
		

func get_node_id_from_click_collision(pos:Vector2) -> int:
	for key in node_dict:
		var node = node_dict[key]
		if node.contains(pos):
			print_debug("Detected click on node ID:", key)
			return key
	return NOT_FOUND
