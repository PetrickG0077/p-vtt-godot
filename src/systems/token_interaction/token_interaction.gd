class_name TokenInteraction
extends RefCounted
## Sistema de interação com tokens: máquina de estados IDLE / DRAG / BOX.
## Recebe Commands (nunca InputEvents). Para mudar o mundo, apenas faz
## PEDIDOS ao ClientSession; o servidor decide. Durante o arrasto move só a
## apresentação (preview); ao soltar, envia UM pedido com todos os movimentos.

enum Mode { IDLE, DRAG, BOX }

const DRAG_THRESHOLD_SQ := 9.0   # unidades de mundo ao quadrado

var snap_enabled := true
## Callable() -> Vector2: centro da vista atual (onde novos tokens aparecem).
var view_center: Callable = func() -> Vector2: return Vector2.ZERO

var _session: ClientSession
var _layer: TokenLayer
var _selection: SelectionManager
var _box: SelectionBoxView

var _mode := Mode.IDLE
var _start := Vector2.ZERO
var _origins: Dictionary = {}     # id -> posição original (mundo)
var _moved := false
var _clicked_id := ""
var _spawn_counter := 0


func _init(session: ClientSession, layer: TokenLayer, selection: SelectionManager,
		box: SelectionBoxView) -> void:
	_session = session
	_layer = layer
	_selection = selection
	_box = box


func handle(cmd: Object) -> void:
	if cmd is Cmd.PointerDown:
		_on_down(cmd as Cmd.PointerDown)
	elif cmd is Cmd.PointerMove:
		_on_move(cmd as Cmd.PointerMove)
	elif cmd is Cmd.PointerUp:
		_on_up(cmd as Cmd.PointerUp)
	elif cmd is Cmd.DeleteSelected:
		for id: String in _selection.get_ids():
			_session.request_remove_token(id)
	elif cmd is Cmd.AddToken:
		_spawn_counter += 1
		var pos := _snap(view_center.call())
		_session.request_add_token(AssetRegistry.BUILTIN_CIRCLE, pos, "Token %d" % _spawn_counter)


func _on_down(cmd: Cmd.PointerDown) -> void:
	_start = cmd.world_pos
	_moved = false
	_clicked_id = ""
	var hit := _layer.pick(cmd.world_pos)
	if hit != null:
		_clicked_id = hit.token_id
		if cmd.multi:
			_selection.toggle(hit.token_id)
		elif not _selection.is_selected(hit.token_id):
			_selection.select_only(hit.token_id)
		if _selection.is_selected(hit.token_id):
			_begin_drag()
	elif cmd.shift:
		_mode = Mode.BOX
	elif not cmd.multi:
		_selection.clear()


func _on_move(cmd: Cmd.PointerMove) -> void:
	var delta := cmd.world_pos - _start
	match _mode:
		Mode.DRAG:
			if not _moved and delta.length_squared() < DRAG_THRESHOLD_SQ:
				return
			_moved = true
			for id: String in _origins:
				var v := _layer.view_of(id)
				if v != null:
					v.position = _origins[id] + delta   # preview local, não é estado
		Mode.BOX:
			_box.show_rect(Rect2(_start, delta).abs())


func _on_up(cmd: Cmd.PointerUp) -> void:
	match _mode:
		Mode.DRAG:
			if _moved:
				_commit_drag(cmd)
			elif not cmd.multi and _selection.count() > 1 and _selection.is_selected(_clicked_id):
				_selection.select_only(_clicked_id)   # clique simples num grupo
		Mode.BOX:
			var ids := _layer.tokens_in_rect(Rect2(_start, cmd.world_pos - _start).abs())
			if cmd.multi:
				_selection.add_many(ids)
			else:
				_selection.set_selection(ids)
			_box.hide_box()
	_mode = Mode.IDLE
	_origins.clear()


func _begin_drag() -> void:
	_origins.clear()
	for id: String in _selection.get_ids():
		var data := _session.active_scene.get_token(id)
		var v := _layer.view_of(id)
		# Filtro só de UX; quem decide de verdade é o servidor (mesmo Roles).
		if data != null and v != null and Roles.can_move_token(_session.role, _session.peer_id, data):
			_origins[id] = data.position
	_mode = Mode.DRAG if not _origins.is_empty() else Mode.IDLE


func _commit_drag(cmd: Cmd.PointerUp) -> void:
	var delta := cmd.world_pos - _start
	var moves: Array = []
	for id: String in _origins:
		var target: Vector2 = _origins[id] + delta
		if snap_enabled and not cmd.alt:
			target = _snap(target)
		var v := _layer.view_of(id)
		if v != null:
			v.position = target   # preview final; o servidor corrige se negar
		moves.append({"id": id, "pos": target})
	_session.request_move_tokens(moves)


func _snap(p: Vector2) -> Vector2:
	var step := float(_session.active_scene.grid_size) * 0.5
	return Vector2(snappedf(p.x, step), snappedf(p.y, step))
