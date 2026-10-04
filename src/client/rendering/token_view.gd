class_name TokenView
extends Node2D
## Apresentação de UM token. Lê TokenData (réplica), nunca o modifica.
## Textura vem do AssetRegistry (cache + contagem de uso); libera ao sair da árvore.
## Só redesenha quando seleção/nome mudam (queue_redraw explícito).

var token_id: String = ""
var selected: bool = false : set = set_selected

var _name: String = ""
var _size := Vector2(64, 64)
var _sprite: Sprite2D
var _held: Array[String] = []   # assets adquiridos (para release)


func setup(data: TokenData, cell: int) -> void:
	token_id = data.id
	_name = data.token_name
	_sprite = Sprite2D.new()
	add_child(_sprite)

	var tex: Texture2D = AssetRegistry.acquire(data.asset_id)
	if not data.asset_id.is_empty():
		_held.append(data.asset_id)
	if tex == null:
		# Placeholder compartilhado (uma única textura) tingido por id.
		tex = AssetRegistry.acquire(AssetRegistry.BUILTIN_CIRCLE)
		_held.append(AssetRegistry.BUILTIN_CIRCLE)
		_sprite.modulate = Color.from_hsv(float(absi(hash(data.id)) % 360) / 360.0, 0.55, 0.92)
	_sprite.texture = tex
	update_from(data, cell)


## Sincroniza posição/rotação/escala com os dados (também desfaz preview de arrasto).
func update_from(data: TokenData, cell: int) -> void:
	position = data.position
	rotation = data.rotation
	z_index = data.layer
	_size = data.scale * float(cell)
	if _name != data.token_name:
		_name = data.token_name
	if _sprite != null and _sprite.texture != null:
		_sprite.scale = _size / _sprite.texture.get_size()
	queue_redraw()


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()


func contains_world_point(p: Vector2) -> bool:
	var local := (p - position).rotated(-rotation)
	return absf(local.x) <= _size.x * 0.5 and absf(local.y) <= _size.y * 0.5


func world_aabb() -> Rect2:
	return Rect2(position - _size * 0.5, _size)


func _draw() -> void:
	var half := _size * 0.5
	if selected:
		draw_arc(Vector2.ZERO, maxf(half.x, half.y) + 4.0, 0.0, TAU, 48, Color(0.3, 0.8, 1.0, 0.95), 3.0)
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, Vector2(-half.x, half.y + 18.0), _name,
			HORIZONTAL_ALIGNMENT_CENTER, _size.x, 14, Color(1, 1, 1, 0.9))


func _exit_tree() -> void:
	for id in _held:
		AssetRegistry.release(id)
	_held.clear()
