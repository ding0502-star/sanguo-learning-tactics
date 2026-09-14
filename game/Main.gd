extends Node2D

const ORIGIN = Vector2(204, 234)
const CELL = 88
const COLS = 9
const ROWS = 6
const HOME = Vector2i(0, 3)
const BLOCKS = [Vector2i(3,1), Vector2i(4,4), Vector2i(6,0), Vector2i(6,5)]
var font: Font
var title_font: Font
var art: Dictionary = {}
var sprite_art: Array = []
var portrait_art: Array = []
var portrait_buttons: Array = []
var visual_positions: Dictionary = {}
var known_hp: Dictionary = {}
var clock_time = 0.0
var qa_enabled = false
var fx: Array = []
var panel_heading: Label
var round_label: Label
var point_label: Label
var village_label: Label
var ui: Control
var hud: Label
var info: Label
var log_label: Label
var panel: PanelContainer
var end_button: Button
var units: Array = []
var selected = 1
var mode = "move"
var round_no = 1
var points = 0
var village = 8
var phase = "quiz"
var bank: Array = []
var deck: Array = []
var quiz_index = 0
var current: Dictionary = {}
var attempts: Array = []
var missed: Array = []
var history: Dictionary = {}
var feedback = ""
var hint_label: Label
var action_buttons: Array = []
var moves: Dictionary = {}
var battle_log = "歡迎！完成軍師挑戰，再帶領劉關張守住村莊。"

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if OS.has_feature("web"):
		font = load("res://assets/fonts/LearningSansTC.ttf")
		title_font = load("res://assets/fonts/LearningSerifTC.ttf")
	else:
		font = SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC"])
		title_font = SystemFont.new()
		title_font.font_names = PackedStringArray(["DFKai-SB", "Microsoft JhengHei"])
	load_art()
	if OS.has_feature("web"): qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa')",true))
	bank = JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
	if FileAccess.file_exists("user://learning.json"):
		var saved = JSON.parse_string(FileAccess.get_file_as_string("user://learning.json"))
		if saved is Dictionary: history = saved
	make_ui()
	restart()
	if "--self-test" in OS.get_cmdline_user_args(): call_deferred("self_test")
	if "--capture" in OS.get_cmdline_user_args(): call_deferred("capture")

func label_at(text: String, pos: Vector2, size: Vector2, fs = 22) -> Label:
	var l = Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(l)
	return l

func button_at(text: String, pos: Vector2, size: Vector2, fn: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(fn)
	style_button(b)
	ui.add_child(b)
	return b

func atlas(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var t = AtlasTexture.new()
	t.atlas = texture
	t.region = rect
	t.filter_clip = true
	return t

func load_art():
	art.background = load("res://assets/art/battlefield.png")
	var sheet = load("res://assets/art/ui.png")
	art.paper = atlas(sheet,Rect2(58,16,513,760))
	art.scroll = atlas(sheet,Rect2(627,302,625,221))
	art.blue = atlas(sheet,Rect2(50,895,530,257))
	art.gold = atlas(sheet,Rect2(669,895,532,257))
	var props = load("res://assets/art/props.png")
	art.tree = atlas(props,Rect2(0,0,882,875))
	art.home = atlas(props,Rect2(888,0,886,875))
	for n in ["liubei","guanyu","zhangfei","soldier"]:
		var t: Texture2D = load("res://assets/art/"+n+".png")
		sprite_art.append(t)
		var regions = {"liubei":Rect2(160,25,850,800),"guanyu":Rect2(145,30,830,780),"zhangfei":Rect2(140,80,870,810),"soldier":Rect2(240,200,880,820)}
		portrait_art.append(atlas(t,regions[n]))
	for n in ["move","attack","skill","hint","shield"]:
		art[n] = load("res://assets/icons/"+n+".svg")

func texture_at(texture: Texture2D, rect: Rect2, parent: Node = null) -> TextureRect:
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture = texture
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else ui).add_child(image)
	return image

func paper_style(texture: Texture2D, margin: int = 34) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,0)
		style.set_content_margin(side,18)
	return style

func make_ui():
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	texture_at(art.scroll,Rect2(15,6,515,127))
	var title = label_at("三國小軍師",Vector2(67,33),Vector2(411,72),52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",title_font)
	title.add_theme_color_override("font_color",Color("392719"))
	texture_at(art.scroll,Rect2(519,25,510,88))
	var chapter = label_at("劉關張合作守村",Vector2(576,46),Vector2(396,46),30)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter.add_theme_font_override("font",title_font)
	chapter.add_theme_color_override("font_color",Color("493222"))
	texture_at(art.scroll,Rect2(1062,18,346,92))
	round_label = label_at("",Vector2(1102,40),Vector2(266,48),29)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_label.add_theme_color_override("font_color",Color("493222"))
	button_at("重新開始",Vector2(1410,36),Vector2(155,56),restart)
	var band = Panel.new()
	band.position = Vector2(31,145)
	band.size = Vector2(1000,51)
	var band_style = StyleBoxFlat.new()
	band_style.bg_color = Color(0.15,0.22,0.13,0.83)
	band_style.set_corner_radius_all(14)
	band.add_theme_stylebox_override("panel",band_style)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(band)
	village_label = label_at("",Vector2(57,151),Vector2(270,40),23)
	point_label = label_at("",Vector2(350,151),Vector2(270,40),23)
	label_at("社會三年級・合作與競爭",Vector2(653,151),Vector2(365,40),23)
	hud = Label.new()
	hud.visible = false
	ui.add_child(hud)
	texture_at(art.paper,Rect2(1066,125,516,837))
	texture_at(art.scroll,Rect2(1084,127,478,126))
	panel_heading = label_at("軍師挑戰",Vector2(1145,158),Vector2(360,69),46)
	panel_heading.add_theme_font_override("font",title_font)
	panel_heading.add_theme_color_override("font_color",Color("392719"))
	panel_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel = PanelContainer.new()
	panel.position = Vector2(1109,268)
	panel.size = Vector2(428,480)
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	ui.add_child(panel)
	log_label = label_at("",Vector2(1112,768),Vector2(423, 64),21)
	log_label.add_theme_color_override("font_color",Color("735334"))
	end_button = button_at("結束我方回合",Vector2(1110,845),Vector2(431,65),end_turn)
	texture_at(art.scroll,Rect2(516,802,528,83))
	info = label_at("",Vector2(558,817),Vector2(456,59),19)
	info.add_theme_color_override("font_color",Color("4c3926"))
	info.add_theme_color_override("font_shadow_color",Color("243323"))
	info.add_theme_constant_override("shadow_offset_x",0)
	info.add_theme_constant_override("shadow_offset_y",0)
	for i in range(3):
		var idx = i
		var btn = button_at("",Vector2(28+i*165,819),Vector2(154,152),func(): select_unit(idx))
		for state in ["normal","hover","pressed","disabled"]:
			var style = paper_style(art.paper,60)
			if state == "hover": style.modulate_color = Color(1.14,1.1,0.86)
			btn.add_theme_stylebox_override(state,style)
		texture_at(portrait_art[i],Rect2(13,9,128,108),btn)
		var name_label = Label.new()
		name_label.text = ["劉備","關羽","張飛"][i]
		name_label.position = Vector2(10,113)
		name_label.size = Vector2(134,34)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font",title_font)
		name_label.add_theme_font_size_override("font_size",25)
		name_label.add_theme_color_override("font_color",Color("35271b"))
		btn.add_child(name_label)
		portrait_buttons.append(btn)
	for i in range(3):
		var action = ["move","attack","skill"][i]
		var btn = button_at(["移動","攻擊","技能"][i],Vector2(530+i*171,883),Vector2(161,77),func(): set_mode(action))
		btn.icon = art[action]
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width",40)
		btn.add_theme_constant_override("h_separation",8)
		if i == 1: tint_button(btn,Color(1.0,0.5,0.47),true)
		if i == 2: tint_button(btn,Color.WHITE,true)
		action_buttons.append(btn)
	var footer = label_at("點武將 → 選指令 → 點目標。每回合可移動與行動各一次。",Vector2(43,975),Vector2(1030,25),17)
	footer.add_theme_color_override("font_shadow_color",Color("182a20"))
	footer.add_theme_constant_override("shadow_offset_x",1)
	footer.add_theme_constant_override("shadow_offset_y",2)
	footer.add_theme_color_override("font_outline_color",Color("182a20"))
	footer.add_theme_constant_override("outline_size",3)

func panel_content(title: String, body: String) -> VBoxContainer:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(428,476)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	panel_heading.text = "軍師挑戰" if phase in ["quiz","feedback"] else ("戰後小記" if phase == "result" else "軍師帳")
	if title.begins_with("守村成功"): panel_heading.text = "守村成功"
	if title.begins_with("錯題複習"): panel_heading.text = "錯題複習"
	if title.begins_with("整隊再挑戰"): panel_heading.text = "再接再厲"
	for entry in [[title,24],[body,24]]:
		var l = Label.new()
		l.text = entry[0]
		l.add_theme_font_override("font",font)
		l.add_theme_font_size_override("font_size",entry[1])
		l.add_theme_color_override("font_color",Color("263c38"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	return box

func panel_button(box: VBoxContainer,text: String,fn: Callable):
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 57
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",21)
	b.pressed.connect(fn)
	style_button(b)
	if text.begins_with("正確") or text.begins_with("錯誤"):
		for state in ["normal","hover","pressed"]:
			var style = StyleBoxFlat.new()
			style.bg_color = Color("fff6df") if state == "normal" else Color("f1dfb0")
			style.border_color = Color("b28d55")
			style.set_border_width_all(2)
			style.set_corner_radius_all(10)
			b.add_theme_stylebox_override(state,style)
		for key in ["font_color","font_hover_color","font_pressed_color"]: b.add_theme_color_override(key,Color("513c26"))
		b.add_theme_constant_override("shadow_offset_x",0)
		b.add_theme_constant_override("shadow_offset_y",0)
	elif text == "提示":
		b.icon = art.hint
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",26)
	box.add_child(b)

func style_button(b: Button):
	tint_button(b,Color.WHITE,false)

func tint_button(b: Button, tint: Color, gold: bool):
	for state in ["normal","hover","pressed","disabled"]:
		var style = paper_style(art.gold if gold else art.blue,56)
		style.modulate_color = tint
		if state == "hover": style.modulate_color = tint.lightened(0.18)
		if state == "pressed": style.modulate_color = tint.darkened(0.15)
		if state == "disabled": style.modulate_color = Color(0.65,0.64,0.60,0.75)
		b.add_theme_stylebox_override(state,style)
	b.add_theme_color_override("font_color",Color("fff7df"))
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color.WHITE)
	b.add_theme_color_override("font_disabled_color",Color("e7dcc2"))
	b.add_theme_color_override("font_shadow_color",Color("4d341f"))
	b.add_theme_constant_override("shadow_offset_x",1)
	b.add_theme_constant_override("shadow_offset_y",2)

func make_unit(n: String, p: Vector2i, hp: int, atk: int, color: String, enemy = false) -> Dictionary:
	return {"name":n,"pos":p,"hp":hp,"max":hp,"atk":atk,"color":Color(color),"enemy":enemy,"moved":false,"acted":false,"guard":false}

func restart():
	units = [make_unit("劉備",Vector2i(1,3),10,3,"68b87d"),make_unit("關羽",Vector2i(2,2),12,4,"288469"),make_unit("張飛",Vector2i(2,4),15,3,"697889"),make_unit("黃巾兵",Vector2i(8,1),7,2,"d8b550",true),make_unit("黃巾兵",Vector2i(8,3),7,2,"d8b550",true),make_unit("黃巾兵",Vector2i(8,5),7,2,"d8b550",true)]
	selected = 1
	round_no = 1
	points = 0
	village = 8
	attempts = []
	missed = []
	deck = bank.duplicate(true)
	deck.shuffle()
	# Previously missed questions are revisited first, without repeats within a battle.
	deck.sort_custom(func(a,b): return int(history.get(a.id,{}).get("wrong",0)) > int(history.get(b.id,{}).get("wrong",0)))
	battle_log = "守住村莊 5 回合，或擊退全部敵軍即可獲勝。"
	visual_positions.clear()
	known_hp.clear()
	fx.clear()
	begin_quiz()

func begin_quiz():
	phase = "quiz"
	quiz_index = 0
	ask_question()

func ask_question():
	phase = "quiz"
	current = deck.pop_front()
	var box = panel_content("軍師挑戰  %d / 2" % (quiz_index+1),current.question)
	for i in range(current.options.size()):
		var index = i
		panel_button(box,current.options[i],func(): answer(index))
	panel_button(box,"提示",func(): hint_label.visible = true)
	hint_label = Label.new()
	hint_label.text = "想一想：有沒有分工、盡責、遵守規則？遇到失敗時，能不能從中學習？"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_override("font",font)
	hint_label.add_theme_font_size_override("font_size",19)
	hint_label.add_theme_color_override("font_color",Color("3b6556"))
	hint_label.visible = false
	box.add_child(hint_label)
	refresh()

func answer(index: int):
	if phase != "quiz": return
	phase = "feedback"
	var correct = index == int(current.answer)
	var key = str(current.id)
	var stat = history.get(key,{"seen":0,"wrong":0})
	stat.seen += 1
	if not correct:
		stat.wrong += 1
		missed.append(current.duplicate(true))
	history[key] = stat
	attempts.append({"id":key,"correct":correct})
	points += 2 if correct else 1
	var explanation = str(current.explanation)
	if explanation.is_empty(): explanation = "這題原始題庫未附詳解，可以與老師或家長一起討論理由。"
	var box = panel_content("答對了！＋2 計策點" if correct else "一起訂正！＋1 計策點", "正確答案：%s\n%s" % [current.options[int(current.answer)],explanation])
	panel_button(box,"我懂了，繼續",next_question)
	save_learning()
	refresh()

func next_question():
	quiz_index += 1
	if quiz_index < 2: ask_question()
	else:
		phase = "player"
		set_mode("move")

func save_learning():
	if "--self-test" in OS.get_cmdline_user_args(): return
	var file = FileAccess.open("user://learning.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(history,"\t"))

func select_unit(i: int):
	if phase != "player" or units[i].hp <= 0: return
	selected = i
	set_mode("move")

func set_mode(value: String):
	if phase != "player": return
	mode = value
	var descriptions = ["仁心：選擇距離 3 格內的我方武將，回復 5 點生命。", "青龍斬：選擇距離 2 格內的敵軍，造成 7 點傷害。", "守護：點選張飛自己，本回合所有存活隊友受到的傷害減少 1 點。"]
	panel_content("武將指令 · " + units[selected].name,descriptions[selected]+"\n\n技能消耗 2 計策點及本回合行動。普通攻擊不消耗計策點。\n\n樹木不可通行；村莊位於左側小屋。")
	refresh()

func occupied(p: Vector2i) -> int:
	for i in range(units.size()):
		if units[i].hp > 0 and units[i].pos == p: return i
	return -1

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS

func distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func reachable(start: Vector2i, steps: int) -> Dictionary:
	var result = {start:0}
	var queue = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if result[p] >= steps: continue
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var n = p+d
			if inside(n) and n not in BLOCKS and n != HOME and occupied(n) == -1 and not result.has(n):
				result[n] = result[p]+1
				queue.append(n)
	return result

func screen_unit_at(pos: Vector2) -> int:
	var order = range(units.size())
	order.sort_custom(func(a,b): return units[a].pos.y > units[b].pos.y)
	for i in order:
		if units[i].hp <= 0: continue
		if mode == "move" and units[i].enemy: continue
		if mode == "attack" and not units[i].enemy: continue
		var foot = visual_positions.get(i,ORIGIN+Vector2(units[i].pos)*CELL+Vector2(CELL/2.0,CELL*0.78))
		var height = 157.0 if not units[i].enemy else 140.0
		var rect = Rect2(foot-Vector2(37,height*0.85),Vector2(74,height*0.9))
		if rect.has_point(pos): return i
	return -1

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and phase == "player":
		var mouse = get_global_mouse_position()
		var hit = screen_unit_at(mouse)
		if hit >= 0:
			click_cell(units[hit].pos)
			return
		var p = Vector2i((mouse-ORIGIN)/CELL)
		if mouse.x < ORIGIN.x or mouse.y < ORIGIN.y: return
		if inside(p): click_cell(p)

func click_cell(p: Vector2i):
	var target = occupied(p)
	var hero: Dictionary = units[selected]
	if mode == "move":
		if target >= 0 and not units[target].enemy:
			select_unit(target)
			return
		if not hero.moved and reachable(hero.pos,3).has(p) and target == -1:
			hero.pos = p
			hero.moved = true
			battle_log = hero.name + " 已移動，仍可攻擊或使用技能。"
	elif not hero.acted:
		if mode == "attack" and target >= 0 and units[target].enemy and distance(hero.pos,p) <= 1:
			units[target].hp -= hero.atk
			hero.acted = true
			battle_log = "%s 普通攻擊，造成 %d 點傷害。" % [hero.name,hero.atk]
		elif mode == "skill" and points >= 2 and target >= 0:
			var valid = false
			if selected == 0 and not units[target].enemy and distance(hero.pos,p) <= 3 and units[target].hp < units[target].max:
				units[target].hp = mini(units[target].max,units[target].hp+5)
				valid = true
			elif selected == 1 and units[target].enemy and distance(hero.pos,p) <= 2:
				units[target].hp -= 7
				valid = true
			elif selected == 2 and target == selected:
				for unit in units:
					if not unit.enemy: unit.guard = true
				valid = true
			if valid:
				points -= 2
				hero.acted = true
				battle_log = hero.name + " 施放技能！"
			else: battle_log = "目標不適用：請確認技能距離、陣營與生命值。"
		else: battle_log = "請確認目標與距離；技能需要 2 計策點。"
	else: battle_log = "這位武將本回合已行動，可選其他武將。"
	check_result()
	refresh()

func end_turn():
	if phase != "player": return
	phase = "enemy"
	panel_content("敵方回合","黃巾軍正在逼近村莊……")
	refresh()
	for i in range(3,units.size()):
		if phase != "enemy": return
		if units[i].hp <= 0: continue
		enemy_action(i)
		refresh()
		await get_tree().create_timer(0.45).timeout
		if phase != "enemy": return
		if check_result(): return
	if round_no >= 5:
		finish(true)
		return
	round_no += 1
	if round_no == 3:
		for pos in [Vector2i(8,0),Vector2i(8,4)]:
			if occupied(pos) == -1: units.append(make_unit("黃巾兵",pos,7,2,"d8b550",true))
	for unit in units:
		unit.moved = false
		unit.acted = false
		unit.guard = false
	if units[selected].hp <= 0:
		for i in range(3):
			if units[i].hp > 0:
				selected = i
				break
	begin_quiz()

func enemy_action(i: int):
	var enemy: Dictionary = units[i]
	for step in range(3):
		var target = -1
		for h in range(3):
			if units[h].hp > 0 and distance(enemy.pos,units[h].pos) <= 1:
				target = h
				break
		if target >= 0:
			var damage = maxi(1,enemy.atk-int(units[target].guard))
			units[target].hp -= damage
			battle_log = "黃巾軍攻擊 %s，造成 %d 點傷害。" % [units[target].name,damage]
			return
		if distance(enemy.pos,HOME) <= 1:
			village -= 2
			battle_log = "村莊受到攻擊！耐久 -2。"
			return
		if step == 2: return
		enemy.pos = enemy_step(enemy.pos)

func enemy_step(start: Vector2i) -> Vector2i:
	var queue = [start]
	var previous = {start:start}
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		var goal = distance(p,HOME) <= 1
		for h in range(3):
			if units[h].hp > 0 and distance(p,units[h].pos) <= 1: goal = true
		if goal and p != start:
			while previous[p] != start: p = previous[p]
			return p
		for delta in [Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN,Vector2i.RIGHT]:
			var n = p+delta
			if inside(n) and n not in BLOCKS and n != HOME and occupied(n) == -1 and not previous.has(n):
				previous[n] = p
				queue.append(n)
	return start

func check_result() -> bool:
	if phase == "result": return true
	var allies = 0
	var enemies = 0
	for unit in units:
		if unit.hp > 0:
			if unit.enemy: enemies += 1
			else: allies += 1
	if village <= 0 or allies == 0:
		finish(false)
		return true
	if enemies == 0:
		finish(true)
		return true
	return false

func finish(won: bool):
	phase = "result"
	var correct = 0
	for attempt in attempts:
		if attempt.correct: correct += 1
	var box = panel_content("守村成功！" if won else "整隊再挑戰", "完成 %d 題，首次答對 %d 題。\n本場有 %d 題值得再複習。\n武將撤退後可以重新挑戰。" % [attempts.size(),correct,missed.size()])
	if not missed.is_empty(): panel_button(box,"複習本場錯題",func(): review(0))
	panel_button(box,"再玩一次",restart)
	save_learning()
	refresh()

func review(index: int):
	var q = missed[index]
	var exp = q.explanation if not q.explanation.is_empty() else "原題未附詳解，請與老師或家長討論。"
	var box = panel_content("錯題複習 %d / %d" % [index+1,missed.size()],q.question+"\n\n正確答案："+q.options[int(q.answer)]+"\n"+exp)
	if index+1 < missed.size(): panel_button(box,"下一題",func(): review(index+1))
	else: panel_button(box,"完成複習，再玩一次",restart)

func refresh():
	hud.text = "第 %d / 5 回合    村莊 %d / 8    計策點 %d" % [round_no,maxi(0,village),points]
	round_label.text = "第 %d / 5 回合" % round_no
	point_label.text = "計策點  %d" % points
	village_label.text = "村莊耐久  %d / 8" % maxi(0,village)
	log_label.text = battle_log
	var u = units[selected]
	info.text = "%s  HP %d/%d   %s  ·  %s\n目前指令：%s" % [u.name,maxi(0,u.hp),u.max,"已移動" if u.moved else "可移動 3 格","已行動" if u.acted else "可行動",{"move":"移動","attack":"普通攻擊（相鄰）","skill":"技能"}[mode]]
	end_button.disabled = phase != "player"
	for b in action_buttons: b.disabled = phase != "player"
	for i in range(portrait_buttons.size()):
		portrait_buttons[i].modulate = Color.WHITE if units[i].hp > 0 else Color(0.55,0.55,0.55)
	for i in range(units.size()):
		if known_hp.has(i) and known_hp[i] != units[i].hp:
			fx.append({"pos":ORIGIN+Vector2(units[i].pos)*CELL+Vector2(48,20),"age":0.0,"value":units[i].hp-known_hp[i]})
		known_hp[i] = units[i].hp
	moves = reachable(u.pos,3) if phase == "player" and mode == "move" and not u.moved and u.hp > 0 else {}

	queue_redraw()

func publish_web_snapshot():
	var snapshot = {"phase":phase,"round":round_no,"points":points,"village":village,"selected":selected,"question_id":current.get("id",""),"attempts":attempts.size(),"history":history,"units":[],"buttons":[]}
	for unit in units: snapshot.units.append({"name":unit.name,"x":unit.pos.x,"y":unit.pos.y,"hp":unit.hp,"moved":unit.moved,"acted":unit.acted})
	for button in ui.find_children("*","Button",true,false):
		var rect = button.get_global_rect()
		snapshot.buttons.append({"text":button.text,"disabled":button.disabled,"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y})
	JavaScriptBridge.eval("window.sanguoState="+JSON.stringify(snapshot),true)

func _process(delta):
	if qa_enabled and Engine.get_process_frames()%15 == 0: publish_web_snapshot()
	clock_time += delta
	for i in range(units.size()):
		var target = ORIGIN+Vector2(units[i].pos)*CELL+Vector2(CELL/2.0,CELL*0.78)
		if not visual_positions.has(i): visual_positions[i] = target
		visual_positions[i] = visual_positions[i].lerp(target,1.0-exp(-14.0*delta))
	for effect in fx: effect.age += delta
	fx = fx.filter(func(e): return e.age < 1.1)
	queue_redraw()

func _draw():
	if art.is_empty(): return
	draw_texture_rect(art.background,Rect2(0,0,1600,1000),false)
	for y in range(ROWS):
		for x in range(COLS):
			var p = Vector2i(x,y)
			var r = Rect2(ORIGIN+Vector2(p)*CELL,Vector2(CELL,CELL))
			draw_rect(r,Color(0.95,0.96,0.76,0.06))
			draw_rect(r,Color(0.95,0.96,0.77,0.35),false,1.3)
			if moves.has(p):
				draw_rect(r.grow(-3),Color(0.2,0.73,1.0,0.27))
				draw_rect(r.grow(-3),Color(0.62,0.93,1,0.8),false,2)
			if phase == "player" and mode != "move" and units[selected].hp > 0 and not units[selected].acted:
				var reach = 1 if mode == "attack" else [3,2,0][selected]
				if distance(units[selected].pos,p) <= reach:
					draw_rect(r.grow(-3),Color(1,0.7,0.2,0.15))
	# Sort props and actors by row so characters sit naturally on the terrain.
	for y in range(ROWS):
		for p in BLOCKS:
			if p.y == y:
				var foot = ORIGIN+Vector2(p)*CELL+Vector2(CELL/2.0,79)
				draw_texture_rect(art.tree,Rect2(foot-Vector2(61,119),Vector2(122,122)),false)
		if HOME.y == y:
			var foot = ORIGIN+Vector2(HOME)*CELL+Vector2(CELL/2.0,79)
			draw_texture_rect(art.home,Rect2(foot-Vector2(72,123),Vector2(144,142)),false)
			draw_tag("守護村莊",foot+Vector2(-44,23),88,Color("543c26"))
		for i in range(units.size()):
			if units[i].hp > 0 and units[i].pos.y == y: draw_hero(units[i],i)
	for effect in fx:
		var color = Color("aeffba") if effect.value > 0 else Color("ffdf8c")
		color.a = 1.0-effect.age/1.1
		var pos = effect.pos-Vector2(0,effect.age*47)
		var text = ("+" if effect.value > 0 else "")+str(effect.value)
		draw_string_outline(font,pos,text,HORIZONTAL_ALIGNMENT_CENTER,50,30,5,Color(0.22,0.12,0.05,color.a))
		draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_CENTER,50,30,color)
		draw_arc(effect.pos+Vector2(0,32),18+effect.age*35,0,TAU,40,color,2,true)
	if phase == "player":
		draw_rect(Rect2(28+selected*165,819,154,152),Color("ffdd77"),false,3)

func draw_tag(text: String,pos: Vector2,width: float,bg: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(4)
	draw_style_box(style,Rect2(pos,Vector2(width,24)))
	draw_string(font,pos+Vector2(0,19),text,HORIZONTAL_ALIGNMENT_CENTER,width,17,Color("fff5d9"))

func draw_hero(u: Dictionary,i: int):
	var foot = visual_positions.get(i,ORIGIN+Vector2(u.pos)*CELL+Vector2(48,75))
	draw_set_transform(foot,0,Vector2(1,0.36))
	draw_circle(Vector2.ZERO,33,Color(0.12,0.19,0.1,0.24),true,-1,true)
	if i == selected and not u.enemy:
		draw_arc(Vector2.ZERO,39+sin(clock_time*3.0),0,TAU,48,Color("b9efff"),5,true)
		draw_arc(Vector2.ZERO,43,0,TAU,48,Color(0.28,0.79,1.0,0.6),2,true)
	if u.guard: draw_arc(Vector2.ZERO,36,0,TAU,48,Color("b9ffb1"),4,true)
	draw_set_transform(Vector2.ZERO)
	var texture: Texture2D = sprite_art[3 if u.enemy else i]
	var height = 157.0 if not u.enemy else 140.0
	var width = height*texture.get_width()/float(texture.get_height())
	var bob = sin(clock_time*2.2+i)*1.5
	var color = Color(0.84,0.86,0.83) if u.acted and not u.enemy else Color.WHITE
	draw_texture_rect(texture,Rect2(foot-Vector2(width/2,height+bob),Vector2(width,height)),false,color)
	var bar = Rect2(foot+Vector2(-32,6),Vector2(64,7))
	draw_rect(bar.grow(2),Color("243a2b"))
	draw_rect(Rect2(bar.position,Vector2(64*float(u.hp)/u.max,7)),Color("f28e74") if u.enemy else Color("96ef99"))
	draw_tag(u.name,foot+Vector2(-35,19),70,Color("553827") if u.enemy else Color("31513d"))

func capture():
	if "--long-question" in OS.get_cmdline_user_args():
		var sorted_bank = bank.duplicate()
		sorted_bank.sort_custom(func(a,b): return a.question.length() > b.question.length())
		deck.push_front(sorted_bank[0])
		ask_question()
		hint_label.visible = true
	if "--victory" in OS.get_cmdline_user_args():
		finish(true)
	if "--battle" in OS.get_cmdline_user_args():
		phase = "player"
		points = 4
		set_mode("move")
	if "--review" in OS.get_cmdline_user_args():
		missed = [bank[0]]
		phase = "result"
		review(0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image_path = "res://preview.png"
	if "--battle" in OS.get_cmdline_user_args(): image_path = "res://preview-battle.png"
	if "--review" in OS.get_cmdline_user_args(): image_path = "res://preview-review.png"
	if "--victory" in OS.get_cmdline_user_args(): image_path = "res://preview-victory.png"
	if "--long-question" in OS.get_cmdline_user_args(): image_path = "res://preview-long.png"
	get_viewport().get_texture().get_image().save_png(image_path)
	get_tree().quit()

func self_test():
	assert(bank.size() == 30)
	for q in bank:
		assert(q.options.size() == 2 and int(q.answer) in [0,1])
	assert(not reachable(Vector2i(2,2),3).has(Vector2i(3,1)))
	answer(int(current.answer))
	assert(points == 2)
	next_question()
	answer(1-int(current.answer))
	assert(points == 3 and missed.size() == 1)
	next_question()
	assert(phase == "player")
	assert(screen_unit_at(ORIGIN+Vector2(units[1].pos)*CELL+Vector2(CELL/2.0,-10)) == 1)
	units[3].pos = Vector2i(3,2)
	set_mode("skill")
	click_cell(Vector2i(3,2))
	assert(units[3].hp == 0 and points == 1 and units[1].acted)
	var before = units[4].hp
	click_cell(units[4].pos)
	assert(units[4].hp == before)
	village = 0
	assert(check_result() and phase == "result")
	restart()
	phase = "player"
	points = 6
	selected = 0
	units[1].hp = 3
	set_mode("skill")
	click_cell(units[1].pos)
	assert(units[1].hp == 8 and points == 4)
	selected = 2
	set_mode("skill")
	click_cell(units[2].pos)
	assert(units[0].guard and units[1].guard and points == 2)
	units[3].pos = Vector2i(3,4)
	var hp_before = units[2].hp
	enemy_action(3)
	assert(units[2].hp == hp_before-1)
	assert(enemy_step(Vector2i(7,0)) != Vector2i(7,0))
	for i in range(3,units.size()): units[i].hp = 0
	assert(check_result() and phase == "result")
	restart()
	phase = "player"
	round_no = 5
	await end_turn()
	assert(phase == "result" and village > 0)
	print("SELF_TEST_PASS: scoring, correction, obstacles, skill cost/damage, action limit, heal, guard, enemy path, defeat, elimination victory, five-round victory")
	get_tree().quit()
