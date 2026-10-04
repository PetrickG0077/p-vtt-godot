class_name Ids
extends RefCounted
## Geração de IDs. IDs são sempre gerados pelo SERVIDOR (autoridade).

static var _counter: int = 0


static func new_id(prefix: String = "") -> String:
	_counter += 1
	var rnd: int = randi() & 0xFFFFFF
	return "%s%x%06x%x" % [prefix, int(Time.get_unix_time_from_system()), rnd, _counter]
