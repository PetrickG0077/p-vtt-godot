class_name ServerTransport
extends RefCounted
## Interface abstrata do lado SERVIDOR de um transporte.
## Implementações: LocalLink (in-process, offline/testes). Futuro: ENet/WebSocket.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal request_received(peer_id: int, msg: Dictionary)


func send_to(_peer_id: int, _msg: Dictionary) -> void:
	push_error("ServerTransport.send_to() não implementado")
