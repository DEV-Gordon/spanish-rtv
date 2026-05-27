extends Node

const FILE_PATH  = "res://spanish-rtv/translations/spanish.json"

# Defaults
const DEF_ENABLED  = true
const DEF_FALLBACK = "Original"

# Estado 
var _translations : Dictionary = {}
var _enabled      : bool   = DEF_ENABLED
var _fallback     : String = DEF_FALLBACK

# Timers 
var _scan_timer : float = 0.0
const SCAN_INTERVAL : float = 2.0

# Constantes internas
const META_KEY = "_spanish-rtv_original"   # metadata guardada en cada nodo
const LOCALE   = "es"


func _ready() -> void:
	process_priority  = 10000
	process_mode      = Node.PROCESS_MODE_ALWAYS

	_load_json()
	_load_and_apply()

	# Conectar señal para nodos que aparecen después (menús, popups, etc.)
	get_tree().node_added.connect(_on_node_added)

	print("[RTV-ES] Cargado — %d entradas en el JSON" % _translations.size())

func _process(delta: float) -> void:
	# Re-escaneo periódico: captura texto que el juego regenera dinámicamente
	# (igual que VisualZone sigue la cámara activa cada SEARCH_INTERVAL)
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
	else:
		push_error("[RTV-ES] Error al parsear es.json")

# Carga config guardada y aplica 
func _load_and_apply() -> void:
	var cfg_node = get_node_or_null("/root/RtvEsConfig")
	if cfg_node:
		var cfg = ConfigFile.new()
		cfg.load("user://MCM/spanish-rtv/config.ini")
		apply_from_config(cfg)
	else:
		# Sin MCM: aplicar con defaults
		_enabled  = DEF_ENABLED
		_fallback = DEF_FALLBACK
		_apply_all()

func apply_from_config(cfg: ConfigFile) -> void:
	_enabled  = _get(cfg, "Bool",     "enabled",  DEF_ENABLED)
	_fallback = _get(cfg, "Dropdown", "fallback",  DEF_FALLBACK)
	_apply_all()

func _get(cfg: ConfigFile, section: String, key: String, default):
	var data = cfg.get_value(section, key, null)
	if data is Dictionary and data.has("value"):
		return data["value"]
	return default

func _apply_all() -> void:
	# Método 1: TranslationServer 
	_inject_translation_server()
	# Método 2: parcheo directo de nodos visibles
	_patch_tree(get_tree().root)

# TranslationServer 
func _inject_translation_server() -> void:
	if _enabled:
		var t = Translation.new()
		t.locale = LOCALE
		for key in _translations:
			t.add_message(key, _translations[key])
		TranslationServer.add_translation(t)
		TranslationServer.set_locale(LOCALE)
	else:
		TranslationServer.set_locale("en")

# Parcheo directo
func _patch_tree(node: Node) -> void:
	_patch_node(node)
	for child in node.get_children():
		_patch_tree(child)

# Parchea un nodo individual
func _patch_node(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		var text_now: String = node.text if not (node is RichTextLabel) else node.get_parsed_text()

		# guardar el texto original la primera vez (como VisualZone guarda orig en metadata)
		if not node.has_meta(META_KEY) and text_now != "":
			node.set_meta(META_KEY, text_now)

		var source: String = node.get_meta(META_KEY) if node.has_meta(META_KEY) else text_now

		if _enabled:
			if _translations.has(source):
				node.text = _translations[source]
			# si no hay traducción, dejamos el original (fallback "Original")
			# o limpiamos si el usuario eligió "Vacío"
			elif _fallback == "Vacío" and node.has_meta(META_KEY):
				node.text = ""
		else:
			# restaurar original al desactivar
			if node.has_meta(META_KEY):
				node.text = node.get_meta(META_KEY)