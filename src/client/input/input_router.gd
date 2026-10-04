class_name InputRouter
extends Node
## Traduz InputEvents (mouse hoje; toque/gamepad no futuro) em Commands.
## Não contém lógica de jogo e não conhece a câmera: recebe um Callable
## `to_world` para converter posição de tela em mundo.
## Releases são lidos em _input (para nunca "perder" o fim de um arrasto sobre a UI).

signal command_issued(cmd: Object)

const ZOOM_STEP := 1.12

var to_world: Callable = func(p: Vector2) -> Vector2: return p

var _panning := false
var _left_down := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_emit_zoom(ZOOM_STEP, mb.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_emit_zoom(1.0 / ZOOM_STEP, mb.position)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_panning = true
			MOUSE_BUTTON_LEFT:
				_left_down = true
				command_issued.emit(_pointer(Cmd.PointerDown.new(), mb, mb.position))
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			var pan := Cmd.Pan.new()
			pan.screen_delta = mm.relative
			command_issued.emit(pan)
		elif _left_down:
			command_issued.emit(_pointer(Cmd.PointerMove.new(), mm, mm.position))
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
				command_issued.emit(Cmd.DeleteSelected.new())
			elif key.keycode == KEY_HOME:
				command_issued.emit(Cmd.ResetView.new())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if _left_down:
					_left_down = false
					command_issued.emit(_pointer(Cmd.PointerUp.new(), mb, mb.position))
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_panning = false


func _emit_zoom(factor: float, screen_pos: Vector2) -> void:
	var z := Cmd.Zoom.new()
	z.factor = factor
	z.screen_pos = screen_pos
	command_issued.emit(z)


func _pointer(cmd: Cmd.Pointer, ev: InputEventWithModifiers, screen_pos: Vector2) -> Cmd.Pointer:
	cmd.world_pos = to_world.call(screen_pos)
	cmd.multi = ev.is_command_or_control_pressed()
	cmd.shift = ev.shift_pressed
	cmd.alt = ev.alt_pressed
	return cmd
