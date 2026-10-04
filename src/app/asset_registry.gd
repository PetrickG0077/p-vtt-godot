extends Node
## AssetRegistry — autoload. Único ponto de carregamento de texturas.
##   Asset ID -> (cache + contagem de uso + estado) -> Texture2D
## Garante: nunca carregar a mesma textura duas vezes, saber quem usa,
## poder descarregar o que ninguém usa, e não repetir carga que falhou.
##
## IDs aceitos: "builtin:circle", "res://...", "user://...".
## Texturas grandes são reduzidas para MAX_TEXTURE_SIZE (a original fica no disco).
## Futuro: thumbnails separados, mipmaps, carregamento assíncrono (ResourceLoader threaded).

enum State { LOADED, ERROR }

const MAX_TEXTURE_SIZE := 2048
const BUILTIN_CIRCLE := "builtin:circle"

# id -> { "tex": Texture2D, "refs": int, "state": State }
var _entries: Dictionary = {}


## Pega a textura e incrementa o uso. Cada acquire() exige um release() correspondente.
## Retorna null para id vazio ou se o carregamento falhou (chamador usa placeholder).
func acquire(asset_id: String) -> Texture2D:
	if asset_id.is_empty():
		return null
	var e: Dictionary = _entries.get(asset_id, {})
	if e.is_empty():
		e = _load(asset_id)
		_entries[asset_id] = e
	e["refs"] += 1
	return e["tex"] if e["state"] == State.LOADED else null


func release(asset_id: String) -> void:
	if not _entries.has(asset_id):
		return
	var e: Dictionary = _entries[asset_id]
	e["refs"] = maxi(0, e["refs"] - 1)


## Descarrega tudo que ninguém usa. Chamar periodicamente / ao trocar de cena.
func collect_unused() -> int:
	var to_free: Array = []
	for id: String in _entries:
		var e: Dictionary = _entries[id]
		if e["refs"] <= 0:
			to_free.append(id)
	for id: String in to_free:
		_entries.erase(id)
	if not to_free.is_empty():
		Log.info(Log.ASSET, "descarregados %d assets sem uso" % to_free.size())
	return to_free.size()


func loaded_count() -> int:
	var n := 0
	for id: String in _entries:
		if _entries[id]["state"] == State.LOADED:
			n += 1
	return n


func ref_count(asset_id: String) -> int:
	return _entries[asset_id]["refs"] if _entries.has(asset_id) else 0


func has_error(asset_id: String) -> bool:
	return _entries.has(asset_id) and _entries[asset_id]["state"] == State.ERROR


func _load(asset_id: String) -> Dictionary:
	var tex: Texture2D = null
	if not Proto.valid_asset_id(asset_id):
		Log.warn(Log.ASSET, "id de asset inválido: %s" % asset_id)
	elif asset_id == BUILTIN_CIRCLE:
		tex = _make_circle(128)
	elif asset_id.begins_with("res://") and ResourceLoader.exists(asset_id):
		tex = load(asset_id) as Texture2D
	elif FileAccess.file_exists(asset_id):
		var img := Image.load_from_file(asset_id)
		if img != null and not img.is_empty():
			var biggest := maxi(img.get_width(), img.get_height())
			if biggest > MAX_TEXTURE_SIZE:
				var f := float(MAX_TEXTURE_SIZE) / float(biggest)
				img.resize(int(img.get_width() * f), int(img.get_height() * f), Image.INTERPOLATE_LANCZOS)
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		Log.warn(Log.ASSET, "falha ao carregar: %s" % asset_id)
		return {"tex": null, "refs": 0, "state": State.ERROR}
	Log.info(Log.ASSET, "carregado: %s" % asset_id)
	return {"tex": tex, "refs": 0, "state": State.LOADED}


func _make_circle(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
