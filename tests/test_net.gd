extends Node
## Teste headless da camada core + rede (sem UI).
## Roda como cena para que os autoloads (Log, AssetRegistry) existam.
## Rodar:  godot --headless --path . res://tests/test_net.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   - ", label)
	else:
		print("  FAIL - ", label)
		_fails += 1


func _frames(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame

	var camp := CampaignData.new()
	camp.id = "c1"
	var s1 := SceneData.new()
	s1.id = "s1"
	s1.scene_name = "Taverna"
	var s2 := SceneData.new()
	s2.id = "s2"
	s2.scene_name = "Floresta"
	camp.add_scene(s1)
	camp.add_scene(s2)
	var tok := TokenData.new()
	tok.id = "tok1"
	tok.owner_peer = 2
	s1.add_token(tok)
	var hidden := TokenData.new()
	hidden.id = "hid"
	hidden.visible_to_players = false
	s1.add_token(hidden)

	var link := LocalLink.new()
	var server := VttServer.new(camp, link.server)
	var master := ClientSession.new(link.create_client(), "Mestre")
	var player := ClientSession.new(link.create_client(), "Ana")
	var rejected: Array = []
	player.request_rejected.connect(func(r, why): rejected.append(why))
	await _frames()

	print("-- handshake / snapshot")
	_check(master.role == Roles.Role.MASTER and master.peer_id == 1, "peer 1 é MASTER")
	_check(player.role == Roles.Role.PLAYER and player.peer_id == 2, "peer 2 é PLAYER")
	_check(master.active_scene.tokens.size() == 2, "mestre vê 2 tokens")
	_check(player.active_scene.tokens.size() == 1, "jogador não vê token oculto")

	print("-- movimento autoritativo")
	player.request_move_tokens([{"id": "tok1", "pos": Vector2(128, 64)}])
	await _frames()
	_check(s1.get_token("tok1").position == Vector2(128, 64), "dono moveu o próprio token (servidor)")
	_check(master.active_scene.get_token("tok1").position == Vector2(128, 64), "mestre recebeu delta")
	_check(player.active_scene.get_token("tok1").position == Vector2(128, 64), "jogador recebeu delta")

	master.request_move_tokens([{"id": "hid", "pos": Vector2(5, 5)}])
	await _frames()
	_check(s1.get_token("hid").position == Vector2(5, 5), "mestre moveu token oculto")
	_check(player.active_scene.get_token("hid") == null, "jogador não recebeu delta do oculto")

	player.request_move_tokens([{"id": "hid", "pos": Vector2(9, 9)}])
	await _frames()
	_check(s1.get_token("hid").position == Vector2(5, 5), "jogador NÃO moveu token alheio")
	_check(rejected.has("forbidden"), "jogador recebeu REJECTED forbidden")

	print("-- validação de entrada")
	player.request_move_tokens([{"id": "tok1", "pos": Vector2(INF, 0)}])
	await _frames()
	_check(s1.get_token("tok1").position == Vector2(128, 64), "posição inválida (inf) ignorada")
	player.request_move_tokens([{"id": "tok1", "pos": Vector2(9e9, 0)}])
	await _frames()
	_check(s1.get_token("tok1").position == Vector2(128, 64), "posição fora do mundo ignorada")

	print("-- tokens: criar/remover (só Mestre)")
	player.request_add_token("", Vector2.ZERO, "Intruso")
	await _frames()
	_check(s1.tokens.size() == 2, "jogador não criou token")
	master.request_add_token("builtin:circle", Vector2(64, 64), "Goblin")
	await _frames()
	_check(s1.tokens.size() == 3, "mestre criou token")
	_check(master.active_scene.tokens.size() == 3 and player.active_scene.tokens.size() == 2,
			"replicação do novo token ok")
	master.request_add_token("../../etc/passwd", Vector2.ZERO)
	await _frames()
	_check(s1.tokens.size() == 3, "asset id malicioso recusado")

	print("-- cenas")
	player.request_switch_scene("s2")
	await _frames()
	_check(camp.active_scene_id == "s1", "jogador não trocou de cena")
	master.request_switch_scene("s2")
	await _frames()
	_check(camp.active_scene_id == "s2", "mestre trocou de cena")
	_check(player.active_scene.id == "s2", "jogador recebeu novo snapshot")

	print("-- serialização")
	var round_trip := SceneData.from_dict(s1.to_dict())
	_check(round_trip.tokens.size() == 3, "SceneData to_dict/from_dict")

	print("-- AssetRegistry")
	var tex: Texture2D = AssetRegistry.acquire("builtin:circle")
	var tex2: Texture2D = AssetRegistry.acquire("builtin:circle")
	_check(tex != null and tex == tex2, "mesma textura reutilizada (sem carga dupla)")
	_check(AssetRegistry.ref_count("builtin:circle") == 2, "contagem de uso = 2")
	_check(AssetRegistry.collect_unused() == 0, "em uso não é descarregado")
	AssetRegistry.release("builtin:circle")
	AssetRegistry.release("builtin:circle")
	_check(AssetRegistry.collect_unused() == 1, "sem uso é descarregado")
	_check(AssetRegistry.acquire("user://nao_existe.png") == null and AssetRegistry.has_error("user://nao_existe.png"),
			"falha de carga registrada")

	print("RESULTADO: %s" % ("TODOS OS TESTES PASSARAM" if _fails == 0 else "%d FALHA(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
