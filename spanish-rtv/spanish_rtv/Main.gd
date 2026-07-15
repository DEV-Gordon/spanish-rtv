extends Node

const FILE_PATH = "res://spanish_rtv/translations/spanish.json"

const DEF_ENABLED = true
const SCAN_INTERVAL : float = 2.0

const META_KEY         = "_spanish-rtv_original"
const META_APPLIED_KEY = "_spanish-rtv_applied"
const LOCALE           = "es"

# Diagnóstico: volcar a user:// los textos sin traducción (solo para desarrollo)
const DEBUG_DUMP_UNMATCHED : bool = false
const DUMP_PATH = "user://spanish_rtv_unmatched.txt"

var _translations      : Dictionary = {}
var _translations_norm : Dictionary = {}
var _enabled           : bool = DEF_ENABLED
var _translation_res   : Translation = null
var _scan_timer        : float = 0.0
var _dumped            : Dictionary = {}
var _re_days           : RegEx


func _ready() -> void:
	process_priority = 10000
	process_mode     = Node.PROCESS_MODE_ALWAYS

	_re_days = RegEx.new()
	_re_days.compile("^In (\\d+) [Dd]ays?$")

	_load_json()
	_load_and_apply()

	get_tree().node_added.connect(_on_node_added)
	print("[RTV-ES] Cargado — %d entradas en el JSON" % _translations.size())

func _process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		if _enabled:
			_patch_tree(get_tree().root)

func _on_node_added(node: Node) -> void:
	if _enabled:
		_patch_node(node)


func _load_json() -> void:
	var f = FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		push_error("[RTV-ES] Archivo no encontrado: " + FILE_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_translations = parsed
		for k in _translations:
			var nk: String = _normalize(k)
			if not _translations_norm.has(nk):
				_translations_norm[nk] = _translations[k]
	else:
		push_error("[RTV-ES] Error al parsear spanish.json")

func _load_and_apply() -> void:
	var cfg_node = get_node_or_null("/root/RtvEsConfig")
	if cfg_node:
		var cfg = ConfigFile.new()
		cfg.load("user://MCM/spanish_rtv/config.ini")
		apply_from_config(cfg)
	else:
		_enabled = DEF_ENABLED
		_apply_all()

func apply_from_config(cfg: ConfigFile) -> void:
	_enabled = _get(cfg, "Bool", "enabled", DEF_ENABLED)
	_apply_all()

func _get(cfg: ConfigFile, section: String, key: String, default):
	var data = cfg.get_value(section, key, null)
	if data is Dictionary and data.has("value"):
		return data["value"]
	return default

func _apply_all() -> void:
	_inject_translation_server()
	_patch_tree(get_tree().root)

func _inject_translation_server() -> void:
	if _enabled:
		# El recurso se inyecta una sola vez; los toggles solo cambian el locale
		if _translation_res == null:
			_translation_res = Translation.new()
			_translation_res.locale = LOCALE
			for key in _translations:
				_translation_res.add_message(key, _translations[key])
			TranslationServer.add_translation(_translation_res)
		TranslationServer.set_locale(LOCALE)
	else:
		TranslationServer.set_locale("en")


# Normalización tolerante: \r\n, apóstrofes tipográficos, comillas, elipsis
func _normalize(s: String) -> String:
	var t: String = s.replace("\r\n", "\n").replace("\r", "\n")
	t = t.replace("’", "'").replace("‘", "'")
	t = t.replace("“", "\"").replace("”", "\"")
	t = t.replace("…", "...")
	return t.strip_edges()

# Busca traducción; "" = sin match
func _lookup(source: String) -> String:
	if _translations.has(source):
		return _translations[source]
	var norm: String = _normalize(source)
	if _translations_norm.has(norm):
		return _translations_norm[norm]

	# Contadores de eventos: "In 12 Days" / "In 10 days"
	var m = _re_days.search(source)
	if m:
		var n: String = m.get_string(1)
		return ("En 1 día") if n == "1" else ("En %s días" % n)

	# Listas compuestas por el juego: "Lumber, Toolbox, Bucket".
	# Solo si TODOS los tramos resuelven, para no traducir frases a medias.
	if source.contains(", ") and not source.contains("\n"):
		var parts: PackedStringArray = source.split(", ")
		var out: PackedStringArray = PackedStringArray()
		for p in parts:
			if _translations.has(p):
				out.append(_translations[p])
			else:
				var np: String = _normalize(p)
				if _translations_norm.has(np):
					out.append(_translations_norm[np])
				else:
					return ""
		return ", ".join(out)

	# Tooltips compuestos: "Fusebox [Locked]" -> base y sufijo por separado
	if source.ends_with("]"):
		var idx: int = source.rfind(" [")
		if idx > 0:
			var base: String = source.substr(0, idx)
			var suffix: String = source.substr(idx + 1)
			var base_t: String = ""
			if _translations.has(base):
				base_t = _translations[base]
			elif _translations_norm.has(_normalize(base)):
				base_t = _translations_norm[_normalize(base)]
			if base_t != "" and _translations.has(suffix):
				return base_t + " " + _translations[suffix]

	return ""

func _dump_unmatched(node: Node, source: String) -> void:
	if not DEBUG_DUMP_UNMATCHED:
		return
	if source.length() < 8 or not source.contains(" "):
		return
	if _dumped.has(source):
		return
	_dumped[source] = true
	var f = FileAccess.open(DUMP_PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(DUMP_PATH) else FileAccess.open(DUMP_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("=== [%s] %s" % [node.get_class(), str(node.get_path())])
	f.store_line(JSON.stringify(source))
	f.store_line("")


func _patch_tree(node: Node) -> void:
	_patch_node(node)
	for child in node.get_children():
		_patch_tree(child)

func _patch_node(node: Node) -> void:
	var is_rtl: bool = node is RichTextLabel
	if not (node is Label or node is Button or is_rtl or node is Label3D or node is TextEdit):
		return

	var text_now: String = node.get_parsed_text() if is_rtl else node.text
	if text_now == "":
		return

	var last_original: String = node.get_meta(META_KEY) if node.has_meta(META_KEY) else ""
	var last_applied: String  = node.get_meta(META_APPLIED_KEY) if node.has_meta(META_APPLIED_KEY) else ""

	# Texto nuevo: el juego reutilizó el nodo para otro contenido
	if text_now != last_original and text_now != last_applied:
		node.set_meta(META_KEY, text_now)
		last_original = text_now
		if node.has_meta(META_APPLIED_KEY):
			node.remove_meta(META_APPLIED_KEY)
		last_applied = ""

	if _enabled:
		var translated: String = _lookup(last_original)
		if translated == "":
			_dump_unmatched(node, last_original)
		elif text_now != translated:
			node.text = translated
			node.set_meta(META_APPLIED_KEY, translated)
	elif node.has_meta(META_KEY) and text_now != last_original:
		# Restaurar el original al desactivar la traducción
		node.text = last_original
