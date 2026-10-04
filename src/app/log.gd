extends Node
## Log — autoload. Logging por categoria, com níveis ligáveis.
## Uso: Log.info(Log.TOKEN, "mensagem")
## Mantém o log silencioso por padrão em categorias "quentes" (RENDER, NETWORK).

const NETWORK := "NETWORK"
const ASSET := "ASSET"
const RENDER := "RENDER"
const SCENE := "SCENE"
const TOKEN := "TOKEN"
const SAVE := "SAVE"
const ERROR := "ERROR"
const PERFORMANCE := "PERFORMANCE"

## Categorias habilitadas para nível info. Warnings e erros sempre aparecem.
var enabled: Dictionary = {
	NETWORK: false,
	ASSET: true,
	RENDER: false,
	SCENE: true,
	TOKEN: false,
	SAVE: true,
	PERFORMANCE: false,
}


func info(category: String, msg: String) -> void:
	if enabled.get(category, false):
		print("[%s] %s" % [category, msg])


func warn(category: String, msg: String) -> void:
	push_warning("[%s] %s" % [category, msg])


func error(msg: String) -> void:
	push_error("[%s] %s" % [ERROR, msg])


func set_category(category: String, on: bool) -> void:
	enabled[category] = on
