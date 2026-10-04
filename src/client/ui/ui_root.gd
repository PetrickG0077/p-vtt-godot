class_name UiRoot
extends CanvasLayer
## Interface mínima (barra superior + overlay de debug). Montada por código,
## com containers e âncoras (redimensionável). SEM lógica de negócio:
## só emite Commands ou chama a API de pedidos do ClientSession.

signal command_issued(cmd: Object)
signal exit_requested()

## Callable() -> Dictionary com métricas extras (ex.: {"tokens": n}).
var stats_provider: Callable = func() -> Dictionary: return {}

var _session: ClientSession
var _scene_picker: OptionButton
var _role_label: Label
var _master_only: Array[Control] = []
var _debug: Label


func setup(session: ClientSession) -> void:
	_session = session
	_build()
	session.welcomed.connect(_on_welcomed)
	session.scene_loaded.connect(_on_scene_loaded)


func _build() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.pressed.connect(func() -> void: exit_requested.emit())
	row.add_child(menu_btn)
	row.add_child(VSeparator.new())

	var scene_label := Label.new()
	scene_label.text = "Cena:"
	row.add_child(scene_label)

	_scene_picker = OptionButton.new()
	_scene_picker.custom_minimum_size.x = 140
	_scene_picker.item_selected.connect(_on_scene_picked)
	row.add_child(_scene_picker)
	_master_only.append(_scene_picker)

	var add_btn := Button.new()
	add_btn.text = "+ Token"
	add_btn.pressed.connect(func() -> void: command_issued.emit(Cmd.AddToken.new()))
	row.add_child(add_btn)
	_master_only.append(add_btn)

	var del_btn := Button.new()
	del_btn.text = "Excluir seleção"
	del_btn.pressed.connect(func() -> void: command_issued.emit(Cmd.DeleteSelected.new()))
	row.add_child(del_btn)
	_master_only.append(del_btn)

	var hint := Label.new()
	hint.text = "Roda: zoom · Botão do meio/direito: mover vista · Shift+arrastar: caixa · Ctrl: multi · Alt: sem snap · Home: resetar · F3: debug"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.modulate = Color(1, 1, 1, 0.55)
	row.add_child(hint)

	_role_label = Label.new()
	row.add_child(_role_label)

	_debug = Label.new()
	_debug.position = Vector2(10, 52)
	_debug.visible = false
	add_child(_debug)

	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_debug)
	add_child(timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug.visible = not _debug.visible
		_update_debug()


func _on_welcomed(_peer_id: int, role: int) -> void:
	_role_label.text = "Papel: %s" % Roles.Role.keys()[role]
	for c in _master_only:
		c.visible = (role == Roles.Role.MASTER)


func _on_scene_loaded(scene: SceneData) -> void:
	_scene_picker.clear()
	var selected := 0
	for i in _session.scene_list.size():
		var entry: Dictionary = _session.scene_list[i]
		_scene_picker.add_item(str(entry["name"]), i)
		_scene_picker.set_item_metadata(i, str(entry["id"]))
		if entry["id"] == scene.id:
			selected = i
	_scene_picker.select(selected)


func _on_scene_picked(index: int) -> void:
	_session.request_switch_scene(str(_scene_picker.get_item_metadata(index)))


func _update_debug() -> void:
	if not _debug.visible:
		return   # custo zero quando oculto
	var extra: Dictionary = stats_provider.call()
	_debug.text = "FPS: %d\nDraw calls: %d\nRAM: %.1f MB\nVRAM texturas: %.1f MB\nTokens: %s\nAssets carregados: %s" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		extra.get("tokens", "?"), extra.get("assets", "?"),
	]
