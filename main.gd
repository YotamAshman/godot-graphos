extends Node2D

var node_dict:Dictionary[int,GraphosNode] = {}
var node_links:Array[GraphosLink] = []
var current_node_id = 0

var currently_tracked_node_id := -1
var id1_to_link := -1
var id2_to_link := -1

const NODE_RADIUS = 30
const LINK_WIDTH = 5

class GraphosNode:
	var pos:Vector2
	var color:Color
	var radius:float
	var filled:bool
	var width:float
	var highlight := false 
	
	func _init(pos, color, radius, filled, width=-1.0) -> void:
		self.pos = pos
		self.color = color
		self.radius = radius
		self.filled = filled
		self.width=width
	
	func contains(point: Vector2) -> bool:
		return pos.distance_to(point) <= self.radius
	
	func toggle_highlight() -> void:
		if self.highlight:
			self.color = Color.GREEN
			self.highlight = false
		else:
			self.color = Color.RED
			self.highlight = true
		

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
	var width = -1.0
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
		node_links.erase(link)

func _process(delta: float) -> void:
	if currently_tracked_node_id >= 0:
		node_dict[currently_tracked_node_id].pos = get_global_mouse_position()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var pos = get_global_mouse_position()
		handle_left_click(pos)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		currently_tracked_node_id = -1
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var pos = get_global_mouse_position()
		handle_right_click(pos)
	
	queue_redraw()

func _draw() -> void:
	for node in node_dict.values():
		draw_graphos_node(node)
	
	for link in node_links:
		draw_graphos_link(link)	
	
func handle_left_click(pos:Vector2):
	print_debug("Left click on pos: ",pos)
	var node_id = get_node_id_from_click_collision(pos)
	if node_id >= 0:
		currently_tracked_node_id = node_id
	else:
		add_green_node(pos)
	
func handle_right_click(pos:Vector2):
	print_debug("Right click on pos: ",pos)
	var node_id = get_node_id_from_click_collision(pos)
	if node_id >= 0:
		if id1_to_link == -1:
			id1_to_link = node_id
			node_dict[node_id].toggle_highlight()
			print("Selected first node")
		elif id2_to_link == -1:
			if node_id == id1_to_link:
				print("Selected same node. Removing selection")
				id1_to_link = -1
				id2_to_link = -1
				return
				
			id2_to_link = node_id
			print("Linking two selected nodes")
			link_nodes(id1_to_link,id2_to_link)
			node_dict[id1_to_link].toggle_highlight()
			id1_to_link = -1
			id2_to_link = -1
	else:
		print("Removing node selection")
		if id1_to_link >= 0:
			node_dict[id1_to_link].toggle_highlight()
		if id2_to_link >= 0:
			node_dict[id2_to_link].toggle_highlight()
		id1_to_link = -1
		id2_to_link = -1
		

func get_node_id_from_click_collision(pos:Vector2) -> int:
	for key in node_dict:
		var node = node_dict[key]
		if node.contains(pos):
			print_debug("Detected click on node ID:", key)
			return key
	return -1
