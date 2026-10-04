class_name Cmd
extends RefCounted
## Comandos: o que o usuário QUER fazer, independente de como (mouse, toque, teclado).
## Input -> Command -> System. Os sistemas nunca leem InputEvent.

class Pan:
	var screen_delta := Vector2.ZERO


class Zoom:
	var factor := 1.0
	var screen_pos := Vector2.ZERO


class ResetView:
	pass


class Pointer:
	var world_pos := Vector2.ZERO
	var multi := false   # Ctrl (Cmd no macOS): multi-seleção
	var shift := false   # seleção por área
	var alt := false     # desliga snap


class PointerDown extends Pointer:
	pass


class PointerMove extends Pointer:
	pass


class PointerUp extends Pointer:
	pass


class DeleteSelected:
	pass


class AddToken:
	pass
