class_name TokenData
extends RefCounted
## Estado PERSISTENTE de um token. Sem nenhuma dependência de Node/UI.
## Não conhece regras de RPG: dados específicos de sistema vão em `props`.

var id: String = ""
var token_name: String = "Token"
var asset_id: String = ""
var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0              # radianos
var scale: Vector2 = Vector2.ONE       # múltiplos de células do grid
var layer: int = 1                     # 0 = fundo/objetos, 1 = tokens, 2 = GM/overlay
var visible_to_players: bool = true
var owner_peer: int = 0                # 0 = somente o Mestre controla
var props: Dictionary = {}             # HP, condições, barras, fichas... (futuro)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": token_name,
		"asset": asset_id,
		"pos": [position.x, position.y],
		"rot": rotation,
		"scale": [scale.x, scale.y],
		"layer": layer,
		"visible": visible_to_players,
		"owner": owner_peer,
		"props": props.duplicate(true),
	}


static func from_dict(d: Dictionary) -> TokenData:
	var t := TokenData.new()
	t.id = str(d.get("id", ""))
	t.token_name = str(d.get("name", "Token"))
	t.asset_id = str(d.get("asset", ""))
	var p: Array = d.get("pos", [0, 0])
	t.position = Vector2(float(p[0]), float(p[1]))
	t.rotation = float(d.get("rot", 0.0))
	var s: Array = d.get("scale", [1, 1])
	t.scale = Vector2(float(s[0]), float(s[1]))
	t.layer = int(d.get("layer", 1))
	t.visible_to_players = bool(d.get("visible", true))
	t.owner_peer = int(d.get("owner", 0))
	t.props = (d.get("props", {}) as Dictionary).duplicate(true)
	return t
