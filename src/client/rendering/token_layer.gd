class_name TokenLayer
extends Node2D
## Camada que mantém um TokenView por token da réplica.
## Atualização incremental: reage a eventos do ClientSession e mexe SÓ nos
## tokens afetados (nunca reconstrói a cena inteira por causa de um movimento).
## Busca espacial é linear por enquanto (ok para centenas); grid espacial é o
## próximo passo se necessário (ver docs/ARCHITECTURE.md).

var _session: ClientSession
var _views: Dictionary = {}       # token_id -> TokenView
var _selected_ids: Dictionary = {}
var _grid: int = 64


func bind(session: ClientSession, selection: SelectionManager) -> void:
	_session = session
	session.scene_loaded.connect(_on_scene_loaded)
	session.token_added.connect(_on_token_added)
	session.tokens_moved.connect(_on_tokens_moved)
	session.token_removed.connect(_on_token_removed)
	selection.selection_changed.connect(_on_selection_changed)


func token_count() -> int:
	return _views.size()


func view_of(token_id: String) -> TokenView:
	return _views.get(token_id, null)


## Token mais acima sob o ponto (maior z; em empate, o mais recente).
func pick(world_pos: Vector2) -> TokenView:
	var best: TokenView = null
	for child in get_children():
		var v := child as TokenView
		if v != null and v.contains_world_point(world_pos):
			if best == null or v.z_index >= best.z_index:
				best = v
	return best


func tokens_in_rect(rect: Rect2) -> Array:
	var ids: Array = []
	for id: String in _views:
		if rect.intersects((_views[id] as TokenView).world_aabb()):
			ids.append(id)
	return ids


func _on_scene_loaded(scene: SceneData) -> void:
	_grid = scene.grid_size
	for id: String in _views:
		var v: TokenView = _views[id]
		remove_child(v)   # dispara _exit_tree -> release dos assets
		v.queue_free()
	_views.clear()
	for token: TokenData in scene.tokens.values():
		_add_view(token)
	AssetRegistry.collect_unused()


func _on_token_added(token: TokenData) -> void:
	_add_view(token)


func _on_tokens_moved(ids: Array) -> void:
	for id: String in ids:
		var v: TokenView = _views.get(id, null)
		var data := _session.active_scene.get_token(id)
		if v != null and data != null:
			v.update_from(data, _grid)


func _on_token_removed(token_id: String) -> void:
	var v: TokenView = _views.get(token_id, null)
	if v != null:
		_views.erase(token_id)
		remove_child(v)
		v.queue_free()
		AssetRegistry.collect_unused()


func _on_selection_changed(ids: Array) -> void:
	var new_set: Dictionary = {}
	for id: String in ids:
		new_set[id] = true
	for id: String in _selected_ids:
		if not new_set.has(id) and _views.has(id):
			(_views[id] as TokenView).selected = false
	for id: String in new_set:
		if _views.has(id):
			(_views[id] as TokenView).selected = true
	_selected_ids = new_set


func _add_view(token: TokenData) -> void:
	var v := TokenView.new()
	add_child(v)
	v.setup(token, _grid)
	v.selected = _selected_ids.has(token.id)
	_views[token.id] = v
