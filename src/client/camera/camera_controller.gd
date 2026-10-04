class_name CameraController
extends Camera2D
## Câmera 2D dedicada: pan, zoom ancorado no cursor, limites, foco.
## Estado de APRESENTAÇÃO: nunca é salvo na campanha nem replicado.
## Quem usa (input, UI) só chama a API pública; não sabe como a câmera é feita.

## Emitido sempre que a vista muda (usado para redesenhar o grid só quando necessário).
signal view_changed

const ZOOM_MIN := 0.1
const ZOOM_MAX := 4.0

var world_bounds := Rect2(-8192, -8192, 16384, 16384)


func _ready() -> void:
	get_viewport().size_changed.connect(func() -> void: view_changed.emit())


## Move a câmera em resposta a um arrasto na tela (pixels de tela).
func pan_by_screen(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	_clamp_to_bounds()
	view_changed.emit()


## Zoom multiplicativo mantendo fixo o ponto do mundo sob `screen_pos`.
func zoom_at(factor: float, screen_pos: Vector2) -> void:
	var new_zoom := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, zoom.x):
		return
	var before := screen_to_world(screen_pos)
	zoom = Vector2(new_zoom, new_zoom)
	position += before - screen_to_world(screen_pos)
	_clamp_to_bounds()
	view_changed.emit()


func focus_on(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_to_bounds()
	view_changed.emit()


func reset_view() -> void:
	zoom = Vector2.ONE
	focus_on(Vector2.ZERO)


func set_world_bounds(rect: Rect2) -> void:
	world_bounds = rect
	_clamp_to_bounds()


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return position + (screen_pos - get_viewport_rect().size * 0.5) / zoom.x


func visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom.x
	return Rect2(position - size * 0.5, size)


func _clamp_to_bounds() -> void:
	position = position.clamp(world_bounds.position, world_bounds.end)
