class_name Proto
extends RefCounted
## Protocolo de mensagens cliente <-> servidor.
## Mensagens são Dictionaries simples (serializáveis por qualquer transporte):
##   { "t": <tipo>, ...campos }
## REQ_* = cliente -> servidor (pedido, nunca fato).
## EVT_* = servidor -> cliente (fato já validado, replicado de forma incremental).

const T := "t"

# Cliente -> Servidor
const REQ_HELLO := "req_hello"
const REQ_MOVE_TOKENS := "req_move_tokens"
const REQ_ADD_TOKEN := "req_add_token"
const REQ_REMOVE_TOKEN := "req_remove_token"
const REQ_SWITCH_SCENE := "req_switch_scene"

# Servidor -> Cliente
const EVT_WELCOME := "evt_welcome"
const EVT_SNAPSHOT := "evt_snapshot"
const EVT_TOKEN_ADDED := "evt_token_added"
const EVT_TOKENS_MOVED := "evt_tokens_moved"
const EVT_TOKEN_REMOVED := "evt_token_removed"
const EVT_REJECTED := "evt_rejected"

# Limites validados pelo servidor
const MAX_MOVES_PER_REQUEST := 256
const MAX_NAME_LEN := 64
const MAX_ASSET_ID_LEN := 256
const WORLD_LIMIT := 1.0e6


## Converte [x, y] em Vector2, ou retorna null se for inválido (tipo, NaN, Inf, fora do mundo).
static func vec2_from(v: Variant) -> Variant:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
		return null
	var x: Variant = v[0]
	var y: Variant = v[1]
	if not _is_number(x) or not _is_number(y):
		return null
	var fx := float(x)
	var fy := float(y)
	if is_nan(fx) or is_nan(fy) or is_inf(fx) or is_inf(fy):
		return null
	if absf(fx) > WORLD_LIMIT or absf(fy) > WORLD_LIMIT:
		return null
	return Vector2(fx, fy)


## IDs de asset aceitos: "" (sem imagem), "builtin:*", "res://*", "user://*". Sem "..".
static func valid_asset_id(s: String) -> bool:
	if s.length() > MAX_ASSET_ID_LEN or s.contains(".."):
		return false
	if s.is_empty():
		return true
	return s.begins_with("builtin:") or s.begins_with("res://") or s.begins_with("user://")


static func _is_number(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_INT or t == TYPE_FLOAT
