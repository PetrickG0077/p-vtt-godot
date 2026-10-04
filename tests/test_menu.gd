extends Node
## Teste headless do fluxo de navegação: Menu -> Jogar -> Mesa -> Menu.
## O próprio teste se move para a raiz para sobreviver às trocas de cena.
## Rodar:  godot --headless --path . res://tests/test_menu.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   - ", label)
	else:
		print("  FAIL - ", label)
		_fails += 1


func _frames(n: int = 5) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run()


func _run() -> void:
	await _frames(2)
	reparent(get_tree().root)   # sai de current_scene

	var menu: Control = (load(AppScenes.MENU) as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames()

	print("-- menu principal")
	var buttons: Array[String] = []
	for b in menu.find_children("*", "Button", true, false):
		buttons.append((b as Button).text)
	_check(buttons.has("Jogar") and buttons.has("Sair"), "menu tem os botões Jogar e Sair")
	_check(menu._play_button.has_focus(), "Jogar começa com foco (teclado/gamepad)")

	print("-- Jogar abre a mesa")
	menu._play_button.pressed.emit()
	await _frames(8)
	var table := get_tree().current_scene
	_check(table != null and table.scene_file_path == AppScenes.TABLE, "cena atual é a mesa")
	_check(table.token_layer.token_count() == 4, "mesa carregou a Taverna com 4 tokens")

	print("-- Menu volta ao menu principal")
	table.ui.exit_requested.emit()
	await _frames(8)
	_check(get_tree().current_scene != null
			and get_tree().current_scene.scene_file_path == AppScenes.MENU, "voltou ao menu")
	_check(AssetRegistry.ref_count("builtin:circle") == 0, "nenhuma textura segue em uso após sair da mesa")
	_check(AssetRegistry.loaded_count() == 0, "assets sem uso foram descarregados")

	print("RESULTADO: %s" % ("TODOS OS TESTES PASSARAM" if _fails == 0 else "%d FALHA(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
