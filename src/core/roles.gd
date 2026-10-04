class_name Roles
extends RefCounted
## Papéis e permissões. Centraliza TODA decisão de "quem pode o quê" no servidor.

enum Role { MASTER, PLAYER, SPECTATOR }


static func can_edit_scene(role: int) -> bool:
	return role == Role.MASTER


static func can_move_token(role: int, peer_id: int, token: TokenData) -> bool:
	match role:
		Role.MASTER:
			return true
		Role.PLAYER:
			return token.owner_peer == peer_id and token.visible_to_players
		_:
			return false
