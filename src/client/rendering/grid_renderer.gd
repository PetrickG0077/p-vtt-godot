class_name GridRenderer
extends Node2D
## Desenha o grid apenas na área visível. Redesenha SOMENTE quando a câmera
## muda ou o tamanho da célula muda (dirty-state), nunca todo frame.
## LOD: quando as células ficam pequenas na tela, usa múltiplos da célula,
## mantendo o número de linhas limitado independentemente do zoom.

const MIN_CELL_PX := 8.0
const MAJOR_EVERY := 5

var cell_size: int = 64
var minor_color := Color(1, 1, 1, 0.07)
var major_color := Color(1, 1, 1, 0.16)

var _camera: CameraController


func setup(camera: CameraController) -> void:
	_camera = camera
	_camera.view_changed.connect(queue_redraw)
	queue_redraw()


func set_cell_size(size: int) -> void:
	cell_size = maxi(4, size)
	queue_redraw()


func _draw() -> void:
	if _camera == null:
		return
	var z := _camera.zoom.x
	var step := float(cell_size)
	while step * z < MIN_CELL_PX:
		step *= 2.0

	var r := _camera.visible_world_rect()
	var minor := PackedVector2Array()
	var major := PackedVector2Array()

	for i in range(int(floorf(r.position.x / step)), int(ceilf(r.end.x / step)) + 1):
		var x := i * step
		if i % MAJOR_EVERY == 0:
			major.append(Vector2(x, r.position.y))
			major.append(Vector2(x, r.end.y))
		else:
			minor.append(Vector2(x, r.position.y))
			minor.append(Vector2(x, r.end.y))
	for j in range(int(floorf(r.position.y / step)), int(ceilf(r.end.y / step)) + 1):
		var y := j * step
		if j % MAJOR_EVERY == 0:
			major.append(Vector2(r.position.x, y))
			major.append(Vector2(r.end.x, y))
		else:
			minor.append(Vector2(r.position.x, y))
			minor.append(Vector2(r.end.x, y))

	var w := 1.0 / z   # largura constante de ~1px na tela
	if not minor.is_empty():
		draw_multiline(minor, minor_color, w)
	if not major.is_empty():
		draw_multiline(major, major_color, w * 1.5)
