extends Node
## Teste headless do cliente: instancia a cena principal e dirige o sistema
## por Commands (como se o usuário usasse o mouse).
## Rodar:  godot --headless --path . res://tests/test_client.tscn

var _fails := 0
var _main: Node


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   - ", label)
	else:
		print("  FAIL - ", label)
		_fails += 1


func _frames(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame


func _ptr(cls: GDScript, pos: Vector2, shift := false, multi := false) -> Object:
	var c: Object = cls.new()
	c.world_pos = pos
	c.shift = shift
	c.multi = multi
	return c


func _server_token(token_name: String) -> TokenData:
	var scene: SceneData = _main.server.campaign.get_active_scene()
	for t: TokenData in scene.tokens.values():
		if t.token_name == token_name:
			return t
	return null


func _ready() -> void:
	_run()


func _run() -> void:
	_main = (load("res://src/app/vtt_table.tscn") as PackedScene).instantiate()
	add_child(_main)
	await _frames()

	print("-- cena inicial")
	_check(_main.token_layer.token_count() == 4, "4 TokenViews criados a partir do snapshot")
	_check(AssetRegistry.ref_count("builtin:circle") == 4, "placeholder compartilhado: 1 textura, 4 usos")
	_check(AssetRegistry.loaded_count() == 1, "apenas 1 asset em memória")

	print("-- arrastar token (pedido -> servidor -> réplica)")
	var aria := _server_token("Aria")
	var start := aria.position
	_main._dispatch(_ptr(Cmd.PointerDown, start))
	_check(_main.selection.is_selected(aria.id), "clique seleciona o token")
	_main._dispatch(_ptr(Cmd.PointerMove, start + Vector2(70, 5)))
	_check(_main.token_layer.view_of(aria.id).position == start + Vector2(70, 5), "preview local durante o arrasto")
	_check(aria.position == start, "servidor ainda não mudou durante o arrasto")
	_main._dispatch(_ptr(Cmd.PointerUp, start + Vector2(70, 5)))
	await _frames()
	_check(aria.position == start + Vector2(64, 0), "servidor aplicou posição com snap ao grid")
	_check(_main.session.active_scene.get_token(aria.id).position == aria.position, "réplica do cliente confere")
	_check(_main.token_layer.view_of(aria.id).position == aria.position, "view confere")

	print("-- seleção por área / multi")
	_main._dispatch(_ptr(Cmd.PointerDown, Vector2(-600, -600), true))
	_main._dispatch(_ptr(Cmd.PointerMove, Vector2(600, 600), true))
	_main._dispatch(_ptr(Cmd.PointerUp, Vector2(600, 600), true))
	_check(_main.selection.count() == 4, "Shift+arrastar seleciona os 4 tokens")
	_main._dispatch(_ptr(Cmd.PointerDown, Vector2(-5000, 5000)))
	_main._dispatch(_ptr(Cmd.PointerUp, Vector2(-5000, 5000)))
	_check(_main.selection.count() == 0, "clique no vazio limpa a seleção")
	_main._dispatch(_ptr(Cmd.PointerDown, _server_token("Borin").position, false, true))
	_main._dispatch(_ptr(Cmd.PointerUp, _server_token("Borin").position, false, true))
	_main._dispatch(_ptr(Cmd.PointerDown, _server_token("Goblin").position, false, true))
	_main._dispatch(_ptr(Cmd.PointerUp, _server_token("Goblin").position, false, true))
	_check(_main.selection.count() == 2, "Ctrl+clique acumula seleção")

	print("-- mover grupo")
	var b0 := _server_token("Borin").position
	var g0 := _server_token("Goblin").position
	_main._dispatch(_ptr(Cmd.PointerDown, b0))
	_main._dispatch(_ptr(Cmd.PointerMove, b0 + Vector2(0, 128)))
	_main._dispatch(_ptr(Cmd.PointerUp, b0 + Vector2(0, 128)))
	await _frames()
	_check(_server_token("Borin").position == b0 + Vector2(0, 128)
			and _server_token("Goblin").position == g0 + Vector2(0, 128), "grupo movido junto num único pedido")

	print("-- criar / excluir")
	_main._dispatch(Cmd.AddToken.new())
	await _frames()
	_check(_main.token_layer.token_count() == 5, "token criado e replicado")
	_check(AssetRegistry.ref_count("builtin:circle") == 5, "uso do asset acompanha views")
	_main.selection.set_selection(_main.selection.get_ids())
	_main._dispatch(Cmd.DeleteSelected.new())
	await _frames()
	_check(_main.token_layer.token_count() == 3, "2 tokens selecionados excluídos")
	_check(AssetRegistry.ref_count("builtin:circle") == 3, "assets liberados ao excluir")

	print("-- câmera")
	var cam: CameraController = _main.camera
	var anchor := Vector2(900, 200)
	var world_before := cam.screen_to_world(anchor)
	cam.zoom_at(1.5, anchor)
	_check(is_equal_approx(cam.zoom.x, 1.5), "zoom aplicado")
	_check(cam.screen_to_world(anchor).distance_to(world_before) < 0.01, "zoom ancorado no cursor")
	for i in 40:
		cam.zoom_at(0.5, anchor)
	_check(is_equal_approx(cam.zoom.x, CameraController.ZOOM_MIN), "zoom respeita o mínimo")
	cam.pan_by_screen(Vector2(1e9, 1e9))
	_check(cam.position.x >= cam.world_bounds.position.x, "pan respeita limites")
	cam.reset_view()
	_check(cam.position == Vector2.ZERO and cam.zoom == Vector2.ONE, "reset da vista")

	print("-- trocar de cena")
	_main.session.request_switch_scene("forest")
	await _frames()
	_check(_main.token_layer.token_count() == 2, "views da cena anterior removidas, novas criadas")
	_check(AssetRegistry.ref_count("builtin:circle") == 2, "sem vazamento de uso de assets ao trocar de cena")
	_check(_main.selection.count() == 0, "seleção limpa ao trocar de cena")
	_main.session.request_switch_scene("tavern")
	await _frames()
	_check(_main.token_layer.token_count() == 3, "cena Taverna manteve o próprio estado")

	print("RESULTADO: %s" % ("TODOS OS TESTES PASSARAM" if _fails == 0 else "%d FALHA(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
