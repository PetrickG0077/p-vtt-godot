class_name ClientTransport
extends RefCounted
## Interface abstrata do lado CLIENTE de um transporte.

signal connected(peer_id: int)
signal disconnected()
signal message_received(msg: Dictionary)


func send(_msg: Dictionary) -> void:
	push_error("ClientTransport.send() não implementado")
