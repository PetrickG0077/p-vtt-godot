class_name ClientSession
extends RefCounted
## Lado CLIENTE da sessão: mantém uma RÉPLICA do estado e expõe a API de pedidos.
## Nunca altera a réplica por conta própria: só aplica o que o servidor confirmou.
## A UI, o renderizador e os sistemas falam com esta classe, nunca com a rede.

signal welcomed(peer_id: int, role: int)
signal campaign_changed()
signal scene_loaded(scene: SceneData)
signal token_added(token: TokenData)
signal tokens_moved(ids: Array)
signal token_removed(token_id: String)
signal request_rejected(request: String, reason: String)

var peer_id: int = 0
var role: int = Roles.Role.SPECTATOR
var player_name: String = "Jogador"

var campaign_id: String = ""
var campaign_name: String = ""
var scene_list: Array = []             # [{id, name}]
var active_scene: SceneData = null     # réplica da cena ativa

var _transport: ClientTransport


func _init(p_transport: ClientTransport, p_name: String = "Jogador") -> void:
	_transport = p_transport
	player_name = p_name
	_transport.connected.connect(_on_connected)
	_transport.message_received.connect(_on_message)


func is_master() -> bool:
	return role == Roles.Role.MASTER


# ------------------------------------------------------------ pedidos

## moves: Array de { "id": String, "pos": Vector2 }
func request_move_tokens(moves: Array) -> void:
	if active_scene == null or moves.is_empty():
		return
	var wire: Array = []
	for m: Dictionary in moves:
		var p: Vector2 = m["pos"]
		wire.append({"id": m["id"], "pos": [p.x, p.y]})
	_transport.send({Proto.T: Proto.REQ_MOVE_TOKENS, "scene": active_scene.id, "moves": wire})


func request_add_token(asset_id: String, pos: Vector2, token_name: String = "Token") -> void:
	if active_scene == null:
		return
	_transport.send({
		Proto.T: Proto.REQ_ADD_TOKEN, "scene": active_scene.id,
		"asset": asset_id, "pos": [pos.x, pos.y], "name": token_name,
	})


func request_remove_token(token_id: String) -> void:
	if active_scene == null:
		return
	_transport.send({Proto.T: Proto.REQ_REMOVE_TOKEN, "scene": active_scene.id, "id": token_id})


func request_switch_scene(scene_id: String) -> void:
	_transport.send({Proto.T: Proto.REQ_SWITCH_SCENE, "id": scene_id})


# ---------------------------------------------------------- recepção

func _on_connected(_pid: int) -> void:
	_transport.send({Proto.T: Proto.REQ_HELLO, "name": player_name})


func _on_message(msg: Dictionary) -> void:
	match msg.get(Proto.T, ""):
		Proto.EVT_WELCOME:
			peer_id = int(msg["peer_id"])
			role = int(msg["role"])
			welcomed.emit(peer_id, role)
		Proto.EVT_SNAPSHOT:
			_apply_snapshot(msg)
		Proto.EVT_TOKEN_ADDED:
			if _is_active(msg):
				var t := TokenData.from_dict(msg["token"])
				active_scene.add_token(t)
				token_added.emit(t)
		Proto.EVT_TOKENS_MOVED:
			if _is_active(msg):
				var ids: Array = []
				for m: Dictionary in msg["moves"]:
					var t := active_scene.get_token(str(m["id"]))
					if t == null:
						continue
					var p: Array = m["pos"]
					t.position = Vector2(float(p[0]), float(p[1]))
					ids.append(t.id)
				if not ids.is_empty():
					tokens_moved.emit(ids)
		Proto.EVT_TOKEN_REMOVED:
			if _is_active(msg) and active_scene.remove_token(str(msg["id"])):
				token_removed.emit(str(msg["id"]))
		Proto.EVT_REJECTED:
			request_rejected.emit(str(msg.get("request", "")), str(msg.get("reason", "")))


func _is_active(msg: Dictionary) -> bool:
	return active_scene != null and str(msg.get("scene", "")) == active_scene.id


func _apply_snapshot(msg: Dictionary) -> void:
	var c: Dictionary = msg["campaign"]
	campaign_id = str(c["id"])
	campaign_name = str(c["name"])
	scene_list = c["scenes"]
	campaign_changed.emit()
	active_scene = SceneData.from_dict(msg["scene"])
	scene_loaded.emit(active_scene)
