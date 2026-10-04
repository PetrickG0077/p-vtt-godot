class_name SelectionManager
extends RefCounted
## Conjunto de ids selecionados. Estado TEMPORÁRIO (local ao cliente, nunca salvo
## nem replicado). Genérico em ids: serve para tokens agora e objetos/paredes depois.

signal selection_changed(ids: Array)

var _ids: Dictionary = {}   # id -> true


func is_selected(id: String) -> bool:
	return _ids.has(id)


func count() -> int:
	return _ids.size()


func get_ids() -> Array:
	return _ids.keys()


func select_only(id: String) -> void:
	set_selection([id])


func toggle(id: String) -> void:
	if _ids.has(id):
		_ids.erase(id)
	else:
		_ids[id] = true
	_emit()


func add_many(ids: Array) -> void:
	var changed := false
	for id: String in ids:
		if not _ids.has(id):
			_ids[id] = true
			changed = true
	if changed:
		_emit()


func set_selection(ids: Array) -> void:
	_ids.clear()
	for id: String in ids:
		_ids[id] = true
	_emit()


func remove(id: String) -> void:
	if _ids.erase(id):
		_emit()


func clear() -> void:
	if not _ids.is_empty():
		_ids.clear()
		_emit()


func _emit() -> void:
	selection_changed.emit(_ids.keys())
