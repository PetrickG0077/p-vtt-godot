class_name SceneData
extends RefCounted
## Estado PERSISTENTE de uma cena. Cada cena mantém seu próprio estado.
## Walls/doors/fog são reservados para milestones futuros.

var id: String = ""
var scene_name: String = "Cena"
var grid_size: int = 64                # pixels (unidades de mundo) por célula
var background_asset_id: String = ""
var tokens: Dictionary = {}            # id (String) -> TokenData
var walls: Array = []                  # futuro (Milestone 4)
var doors: Array = []                  # futuro (Milestone 4)


func add_token(t: TokenData) -> void:
	tokens[t.id] = t


func remove_token(token_id: String) -> bool:
	return tokens.erase(token_id)


func get_token(token_id: String) -> TokenData:
	return tokens.get(token_id, null)


func to_dict() -> Dictionary:
	var token_list: Array = []
	for t: TokenData in tokens.values():
		token_list.append(t.to_dict())
	return {
		"id": id,
		"name": scene_name,
		"grid": grid_size,
		"background": background_asset_id,
		"tokens": token_list,
		"walls": walls.duplicate(true),
		"doors": doors.duplicate(true),
	}


## Versão filtrada para clientes que não são Mestre (esconde tokens ocultos).
func to_dict_for_players() -> Dictionary:
	var d := to_dict()
	var visible_tokens: Array = []
	for td: Dictionary in d["tokens"]:
		if td.get("visible", true):
			visible_tokens.append(td)
	d["tokens"] = visible_tokens
	return d


static func from_dict(d: Dictionary) -> SceneData:
	var s := SceneData.new()
	s.id = str(d.get("id", ""))
	s.scene_name = str(d.get("name", "Cena"))
	s.grid_size = int(d.get("grid", 64))
	s.background_asset_id = str(d.get("background", ""))
	for td: Dictionary in d.get("tokens", []):
		s.add_token(TokenData.from_dict(td))
	s.walls = (d.get("walls", []) as Array).duplicate(true)
	s.doors = (d.get("doors", []) as Array).duplicate(true)
	return s
