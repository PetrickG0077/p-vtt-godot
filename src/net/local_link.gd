class_name LocalLink
extends RefCounted
## Transporte em memória: liga um servidor a N clientes no mesmo processo.
## Usado no modo offline (1 cliente = Mestre) e em testes (vários clientes).
##
## Para imitar uma rede real:
##  - entrega é assíncrona (call_deferred), nunca reentrante;
##  - mensagens são copiadas em profundidade (sem estado compartilhado).
## O primeiro cliente criado recebe peer_id 1 (o host / Mestre).

class ServerSide extends ServerTransport:
	var link

	func send_to(peer_id: int, msg: Dictionary) -> void:
		link._to_client(peer_id, msg)


class ClientSide extends ClientTransport:
	var link
	var peer_id: int = 0

	func send(msg: Dictionary) -> void:
		link._to_server(peer_id, msg)


var server: ServerSide
var _clients: Dictionary = {}   # peer_id -> ClientSide
var _next_peer_id: int = 1


func _init() -> void:
	server = ServerSide.new()
	server.link = self


func create_client() -> ClientTransport:
	var c := ClientSide.new()
	c.link = self
	c.peer_id = _next_peer_id
	_next_peer_id += 1
	_clients[c.peer_id] = c
	call_deferred("_finish_connect", c.peer_id)
	return c


func disconnect_client(peer_id: int) -> void:
	if not _clients.has(peer_id):
		return
	var c: ClientSide = _clients[peer_id]
	_clients.erase(peer_id)
	server.peer_disconnected.emit(peer_id)
	c.disconnected.emit()


func _finish_connect(peer_id: int) -> void:
	if not _clients.has(peer_id):
		return
	server.peer_connected.emit(peer_id)
	(_clients[peer_id] as ClientSide).connected.emit(peer_id)


func _to_server(peer_id: int, msg: Dictionary) -> void:
	call_deferred("_deliver_to_server", peer_id, msg.duplicate(true))


func _to_client(peer_id: int, msg: Dictionary) -> void:
	call_deferred("_deliver_to_client", peer_id, msg.duplicate(true))


func _deliver_to_server(peer_id: int, msg: Dictionary) -> void:
	if _clients.has(peer_id):
		server.request_received.emit(peer_id, msg)


func _deliver_to_client(peer_id: int, msg: Dictionary) -> void:
	if _clients.has(peer_id):
		(_clients[peer_id] as ClientSide).message_received.emit(msg)
