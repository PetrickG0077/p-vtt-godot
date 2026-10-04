class_name CampaignData
extends RefCounted
## Estado PERSISTENTE de uma campanha: várias cenas, uma ativa por vez.
## Persistência futura: campaign.json + scenes/<id>.json (um arquivo por cena).

var id: String = ""
var campaign_name: String = "Nova Campanha"
var scenes: Dictionary = {}            # id -> SceneData
var scene_order: Array[String] = []
var active_scene_id: String = ""


func add_scene(s: SceneData) -> void:
	scenes[s.id] = s
	if not scene_order.has(s.id):
		scene_order.append(s.id)
	if active_scene_id.is_empty():
		active_scene_id = s.id


func get_scene(scene_id: String) -> SceneData:
	return scenes.get(scene_id, null)


func get_active_scene() -> SceneData:
	return scenes.get(active_scene_id, null)


## Metadados leves (sem tokens) — usados em snapshots e na UI de cenas.
func scene_list() -> Array:
	var out: Array = []
	for sid in scene_order:
		var s: SceneData = scenes[sid]
		out.append({"id": s.id, "name": s.scene_name})
	return out
