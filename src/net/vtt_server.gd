class_name VttServer
extends RefCounted
## Lógica AUTORITATIVA da sessão. Única parte que muda o estado persistente.
## Fluxo: Request -> validação -> mudança de estado -> replicação incremental.
## Não conhece Nodes, UI nem câmera. Funciona igual offline, LAN ou internet:
## só depende de um ServerTransport.

var campaign: CampaignData
var _transport: ServerTransport
var _peers: Dictionary = {}   # peer_id -> { "role": int, "name": String, "ready": bool }


func _init(p_campaign: CampaignData, p_transport: ServerTransport) -> void:
	campaign = p_campaign
	_transport = p_transport
	_transport.peer_connected.connect(_on_peer_connected)
	_transport.peer_disconnected.connect(_on_peer_disconnected)
	_transport.request_received.connect(_on_request)


# ---------------------------------------------------------------- peers

func _on_peer_connected(peer_id: int) -> void:
	_peers[peer_id] = {"role": Roles.Role.SPECTATOR, "name": "", "ready": false}
	Log.info(Log.NETWORK, "peer %d conectado" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_peers.erase(peer_id)
	Log.info(Log.NETWORK, "peer %d desconectado" % peer_id)


func peer_count() -> int:
	return _peers.size()


# ------------------------------------------------------------- requests

func _on_request(peer_id: int, msg: Dictionary) -> void:
	if not _peers.has(peer_id):
		return
	var type: Variant = msg.get(Proto.T)
	if typeof(type) != TYPE_STRING:
		_reject(peer_id, "?", "bad_message")
		return
	var peer: Dictionary = _peers[peer_id]
	if type == Proto.REQ_HELLO:
		_handle_hello(peer_id, msg)
		return
	if not peer["ready"]:
		_reject(peer_id, type, "not_ready")
		return
	match type:
		Proto.REQ_MOVE_TOKENS:
			_handle_move_tokens(peer_id, msg)
		Proto.REQ_ADD_TOKEN:
			_handle_add_token(peer_id, msg)
		Proto.REQ_REMOVE_TOKEN:
			_handle_remove_token(peer_id, msg)
		Proto.REQ_SWITCH_SCENE:
			_handle_switch_scene(peer_id, msg)
		_:
			_reject(peer_id, type, "unknown_request")


func _handle_hello(peer_id: int, msg: Dictionary) -> void:
	var peer: Dictionary = _peers[peer_id]
	if peer["ready"]:
		return
	var pname := str(msg.get("name", "Jogador")).left(Proto.MAX_NAME_LEN)
	peer["name"] = pname
	# Regra provisória: peer 1 (host) é o Mestre. Autenticação real: Milestone 6.
	peer["role"] = Roles.Role.MASTER if peer_id == 1 else Roles.Role.PLAYER
	peer["ready"] = true
	_send(peer_id, {Proto.T: Proto.EVT_WELCOME, "peer_id": peer_id, "role": peer["role"]})
	_send(peer_id, _snapshot_for(peer["role"]))


func _handle_move_tokens(peer_id: int, msg: Dictionary) -> void:
	var peer: Dictionary = _peers[peer_id]
	var scene := campaign.get_active_scene()
	if scene == null or str(msg.get("scene", "")) != scene.id:
		_reject(peer_id, Proto.REQ_MOVE_TOKENS, "wrong_scene")
		return
	var moves: Variant = msg.get("moves")
	if typeof(moves) != TYPE_ARRAY or (moves as Array).is_empty() \
			or (moves as Array).size() > Proto.MAX_MOVES_PER_REQUEST:
		_reject(peer_id, Proto.REQ_MOVE_TOKENS, "bad_moves")
		return

	var applied: Array = []       # TokenData movidos
	var corrections: Array = []   # movimentos negados -> corrigir o cliente
	for m: Variant in moves:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var token := scene.get_token(str((m as Dictionary).get("id", "")))
		if token == null:
			continue
		var pos: Variant = Proto.vec2_from((m as Dictionary).get("pos"))
		if pos == null:
			continue
		if not Roles.can_move_token(peer["role"], peer_id, token):
			corrections.append(_move_entry(token))
			continue
		token.position = pos
		applied.append(token)

	# Replicação incremental: só os tokens que mudaram, filtrados por visibilidade.
	for pid: int in _peers:
		var p: Dictionary = _peers[pid]
		if not p["ready"]:
			continue
		var entries: Array = []
		for t: TokenData in applied:
			if t.visible_to_players or p["role"] == Roles.Role.MASTER:
				entries.append(_move_entry(t))
		if not entries.is_empty():
			_send(pid, {Proto.T: Proto.EVT_TOKENS_MOVED, "scene": scene.id, "moves": entries})

	if not corrections.is_empty():
		_send(peer_id, {Proto.T: Proto.EVT_TOKENS_MOVED, "scene": scene.id, "moves": corrections})
		_reject(peer_id, Proto.REQ_MOVE_TOKENS, "forbidden")


func _handle_add_token(peer_id: int, msg: Dictionary) -> void:
	var peer: Dictionary = _peers[peer_id]
	if not Roles.can_edit_scene(peer["role"]):
		_reject(peer_id, Proto.REQ_ADD_TOKEN, "forbidden")
		return
	var scene := campaign.get_active_scene()
	if scene == null or str(msg.get("scene", "")) != scene.id:
		_reject(peer_id, Proto.REQ_ADD_TOKEN, "wrong_scene")
		return
	var asset := str(msg.get("asset", ""))
	var pos: Variant = Proto.vec2_from(msg.get("pos"))
	if pos == null or not Proto.valid_asset_id(asset):
		_reject(peer_id, Proto.REQ_ADD_TOKEN, "bad_token")
		return
	var t := TokenData.new()
	t.id = Ids.new_id("t")
	t.token_name = str(msg.get("name", "Token")).left(Proto.MAX_NAME_LEN)
	t.asset_id = asset
	t.position = pos
	t.owner_peer = int(msg.get("owner", 0))
	t.visible_to_players = bool(msg.get("visible", true))
	scene.add_token(t)
	Log.info(Log.TOKEN, "token %s adicionado em %s" % [t.id, scene.id])
	for pid: int in _peers:
		var p: Dictionary = _peers[pid]
		if p["ready"] and (t.visible_to_players or p["role"] == Roles.Role.MASTER):
			_send(pid, {Proto.T: Proto.EVT_TOKEN_ADDED, "scene": scene.id, "token": t.to_dict()})


func _handle_remove_token(peer_id: int, msg: Dictionary) -> void:
	var peer: Dictionary = _peers[peer_id]
	if not Roles.can_edit_scene(peer["role"]):
		_reject(peer_id, Proto.REQ_REMOVE_TOKEN, "forbidden")
		return
	var scene := campaign.get_active_scene()
	var token_id := str(msg.get("id", ""))
	if scene == null or str(msg.get("scene", "")) != scene.id or not scene.remove_token(token_id):
		_reject(peer_id, Proto.REQ_REMOVE_TOKEN, "not_found")
		return
	_broadcast({Proto.T: Proto.EVT_TOKEN_REMOVED, "scene": scene.id, "id": token_id})


func _handle_switch_scene(peer_id: int, msg: Dictionary) -> void:
	var peer: Dictionary = _peers[peer_id]
	if not Roles.can_edit_scene(peer["role"]):
		_reject(peer_id, Proto.REQ_SWITCH_SCENE, "forbidden")
		return
	var scene_id := str(msg.get("id", ""))
	if campaign.get_scene(scene_id) == null:
		_reject(peer_id, Proto.REQ_SWITCH_SCENE, "not_found")
		return
	campaign.active_scene_id = scene_id
	Log.info(Log.SCENE, "cena ativa: %s" % scene_id)
	for pid: int in _peers:
		var p: Dictionary = _peers[pid]
		if p["ready"]:
			_send(pid, _snapshot_for(p["role"]))


# -------------------------------------------------------------- helpers

func _snapshot_for(role: int) -> Dictionary:
	var scene := campaign.get_active_scene()
	return {
		Proto.T: Proto.EVT_SNAPSHOT,
		"campaign": {
			"id": campaign.id,
			"name": campaign.campaign_name,
			"scenes": campaign.scene_list(),
			"active": campaign.active_scene_id,
		},
		"scene": scene.to_dict() if role == Roles.Role.MASTER else scene.to_dict_for_players(),
	}


func _move_entry(t: TokenData) -> Dictionary:
	return {"id": t.id, "pos": [t.position.x, t.position.y]}


func _send(peer_id: int, msg: Dictionary) -> void:
	_transport.send_to(peer_id, msg)


func _broadcast(msg: Dictionary) -> void:
	for pid: int in _peers:
		if _peers[pid]["ready"]:
			_transport.send_to(pid, msg)


func _reject(peer_id: int, request: String, reason: String) -> void:
	Log.info(Log.NETWORK, "peer %d rejeitado em %s: %s" % [peer_id, request, reason])
	_send(peer_id, {Proto.T: Proto.EVT_REJECTED, "request": request, "reason": reason})
