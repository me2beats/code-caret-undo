tool
extends EditorPlugin

# ==== user variables (you can change them) ======

var undo_scancode:int = KEY_F11
var redo_scancode:int = KEY_F12

var use_undo_when_unfocused:bool = false

var timer_time:float = 1
var except_selection:bool = true
var undo_max_size:int = 16

#==================================================

# currently this doesnt respect code changes
# I guess this would not be so easy.

# getting textedits could be optimized

# clear undo history button could be added
# maybe also some controls to see current undo point/total points etc

#==================================================


onready var scr_ed: = get_editor_interface().get_script_editor()

onready var timer: = Timer.new()



func _ready():
	
	timer.wait_time = timer_time
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", self, "on_timeout")
	
	scr_ed.connect("editor_script_changed", self, 'on_script_changed')


	var current_script = scr_ed.get_current_script()
	if not current_script: return
	if !current_script is GDScript: return
	var text_edit: = get_current_text_ed(scr_ed)
	
	if not text_edit.is_connected("cursor_changed", self, "on_caret"):
		text_edit.connect("cursor_changed", self, "on_caret")
	
	clear_undo(current_script)
	
	add_undo_to_current_script()


func on_script_changed(script:Script):

	if !script is GDScript: return
	var text_edit: = get_current_text_ed(scr_ed)
	
	if not text_edit.is_connected("cursor_changed", self, "on_caret"):
		text_edit.connect("cursor_changed", self, "on_caret")


#var pass_me = true
func on_timeout():

#	pass_me = true
	var current_script = scr_ed.get_current_script()
	if not current_script: return
	if !current_script is GDScript: return
	var current_textedit = get_current_text_ed(scr_ed)

	add_undo_point(current_script, current_textedit)



func on_caret():
	timer.start()
	


func add_undo_to_current_script():
	var current_script = scr_ed.get_current_script()
	if not current_script: return
	if !current_script is GDScript: return
	var text_edit: = get_current_text_ed(scr_ed)
	add_undo_point(current_script, text_edit)


func add_undo_point(script:GDScript, text_edit:TextEdit):

	if except_selection and text_edit.is_selection_active(): return

	var undo = script.get('__meta__').get("caret_undo")

	if undo == null:
		undo = []
		script.set_meta("caret_undo", undo)
	else:
		undo = script.get_meta("caret_undo")
	
	undo = undo as Array
	
	
	var caret_col = text_edit.cursor_get_column()
	var caret_row = text_edit.cursor_get_line()

	var current_point = script.get('__meta__').get("caret_undo_current")
	

	# Todo: check this area better ==========================

	if !current_point == null and current_point+1<undo.size():
		undo = undo.slice(0, current_point)
	

	var undo_new = Vector2(caret_col, caret_row)

	# dont add same point again	
	if undo:
		var undo_last = undo[-1]
		if undo_last == undo_new: #?
			return
	
	#====================================================

	

	undo.push_back(undo_new)
	
	if undo.size()>undo_max_size:
		undo.remove(0)
	
	script.set_meta("caret_undo_current", undo.size())
	script.set_meta("caret_undo", undo)



# is needed?
static func remove_undo_point(script:GDScript):
	var undo:Array = script.get('__meta__').get("caret_undo")
	if not undo: return
	undo.pop_back()

	script.set_meta("caret_undo_current", undo.size())



# need this property because func undo_or_redo uses yield
# so it should be completed before next undo_or_redo() call
var undo_blocked = false


func undo_or_redo(script:GDScript, text_edit:TextEdit, is_undo:=true):
	if undo_blocked:
		return
	
	undo_blocked = true


	var current_point = script.get('__meta__').get("caret_undo_current")
	if current_point == null:
		push_error("no current point")
		undo_blocked = false
		return

	var undo:Array = script.get('__meta__').get("caret_undo")
	
	var caret_pos:Vector2
	
	if is_undo:
		
		if current_point<=0:
#			push_warning("nothing to undo")
			undo_blocked = false
			return
		
		current_point-=1
		if undo[-1] == undo[current_point]:

			current_point-=1


	else:
		
		if undo.size()<=current_point+1:
#			push_warning("nothing to redo")
			undo_blocked = false
			return
		
		current_point+=1


	caret_pos = undo[current_point]
	

	if text_edit.is_connected("cursor_changed", self, "on_caret"):
		text_edit.disconnect("cursor_changed", self, "on_caret")

	script.set_meta("caret_undo_current", current_point)

	text_edit.set_block_signals(true)
	yield(get_tree(),"idle_frame")
	
	text_edit.cursor_set_line(caret_pos[1])
	text_edit.cursor_set_column(caret_pos[0])
	yield(get_tree(),"idle_frame")

	text_edit.set_block_signals(false)

	undo_blocked = false

	text_edit.connect("cursor_changed", self, "on_caret")


func undo_or_redo_current(is_undo:=true):
	var current_script = scr_ed.get_current_script()
	if not current_script: return
	if !current_script is GDScript: return
	var text_edit: = get_current_text_ed(scr_ed)
	undo_or_redo(current_script, text_edit, is_undo)


#todo:
static func clear_undo(script:GDScript):
	script.remove_meta("caret_undo_current")
	script.remove_meta("caret_undo")


func _exit_tree():
	pass



func _input(event):
	if event is InputEventKey:
		if Input.is_key_pressed(undo_scancode):
			var current_script = scr_ed.get_current_script()
			if not current_script: return
			if !current_script is GDScript: return
			var text_edit:TextEdit = get_current_text_ed(scr_ed)
			if not use_undo_when_unfocused and not text_edit.has_focus(): return
#
			undo_or_redo_current()
			get_tree().set_input_as_handled()

		elif Input.is_key_pressed(redo_scancode):
			var current_script = scr_ed.get_current_script()
			if !current_script is GDScript: return
			var text_edit:TextEdit = get_current_text_ed(scr_ed)
			if not text_edit.has_focus(): return

			undo_or_redo_current(false)
			get_tree().set_input_as_handled()



#  utils ==============================================================



static func find_node_by_class_path(node:Node, class_path:Array)->Node:
	var res:Node

	var stack = []
	var depths = []

	var first = class_path[0]
	for c in node.get_children():
		if c.get_class() == first:
			stack.push_back(c)
			depths.push_back(0)

	if not stack: return res
	
	var max_ = class_path.size()-1

	while stack:
		var d = depths.pop_back()
		var n = stack.pop_back()

		if d>max_:
			continue
		if n.get_class() == class_path[d]:
			if d == max_:
				res = n
				return res

			for c in n.get_children():
				stack.push_back(c)
				depths.push_back(d+1)

	return res


##########
# REFACTOR THIS !
# too many functions..
##########


static func get_script_tab_container(scr_ed:ScriptEditor)->TabContainer:
	return find_node_by_class_path(scr_ed, ['VBoxContainer', 'HSplitContainer', 'TabContainer']) as TabContainer

static func get_script_text_editor(scr_ed:ScriptEditor, idx:int)->Container:
	var tab_cont = get_script_tab_container(scr_ed)
	return tab_cont.get_child(idx)

static func get_code_editor(scr_ed:ScriptEditor, idx:int)->Container:
	var scr_text_ed = get_script_text_editor(scr_ed, idx)
	return find_node_by_class_path(scr_text_ed, ['VSplitContainer', 'CodeTextEditor']) as Container

# some items can be null, this means not previously opened?
static func get_code_editors(scr_ed:ScriptEditor)->Array:
	var scr_tab_cont:TabContainer = get_script_tab_container(scr_ed)
	var result =[]
	#var code_ed_temp
	for s in scr_tab_cont.get_children():
		if ! s.get_child_count():
			result.push_back(null)
		else:
			result.push_back(find_node_by_class_path(s, ['VSplitContainer', 'CodeTextEditor']))
	return result

static func get_text_edit(scr_ed:ScriptEditor, idx:int)->TextEdit:
	var code_ed = get_code_editor(scr_ed, idx)
	return find_node_by_class_path(code_ed, ['TextEdit']) as TextEdit

static func get_current_script_idx(scr_ed:ScriptEditor)->int:
	var current = scr_ed.get_current_script()
	var opened = scr_ed.get_open_scripts()
	return opened.find(current)

static func get_current_text_ed(scr_ed:ScriptEditor)->TextEdit:
	var idx = get_current_script_idx(scr_ed)
	return get_text_edit(scr_ed, idx)
