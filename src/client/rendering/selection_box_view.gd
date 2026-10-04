class_name SelectionBoxView
extends Node2D
## Retângulo da seleção por área (Shift + arrastar). Apenas apresentação.

var _rect := Rect2()
var _active := false


func show_rect(rect: Rect2) -> void:
	_rect = rect
	_active = true
	queue_redraw()


func hide_box() -> void:
	if _active:
		_active = false
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	draw_rect(_rect, Color(0.3, 0.8, 1.0, 0.15), true)
	draw_rect(_rect, Color(0.3, 0.8, 1.0, 0.9), false, 1.5)
