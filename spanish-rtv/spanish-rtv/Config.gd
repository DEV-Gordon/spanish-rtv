extends Node

var McmHelpers = preload("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")

const MOD_ID    = "spanish-rtv"
const FILE_PATH = "user://MCM/spanish-rtv"

func _ready():
	var _config = ConfigFile.new()

	_config.set_value("Bool", "enabled", {
		"name"    = "Traducción activa",
		"tooltip" = "Activa o desactiva la traducción al español sin reiniciar",
		"default" = true,
		"value"   = true,
	})

	_config.set_value("Dropdown", "fallback", {
		"name"    = "Texto sin traducir",
		"tooltip" = "Qué mostrar cuando una cadena no tiene traducción",
		"default" = "Original",
		"value"   = "Original",
		"options" = {
			"Original": "Original",
			"Vacío":    "Vacío",
		}
	})

	if !FileAccess.file_exists(FILE_PATH + "/config.ini"):
		DirAccess.open("user://").make_dir(FILE_PATH)
		_config.save(FILE_PATH + "/config.ini")
	else:
		McmHelpers.CheckConfigurationHasUpdated(MOD_ID, _config, FILE_PATH + "/config.ini")
		_config.load(FILE_PATH + "/config.ini")

	McmHelpers.RegisterConfiguration(
		MOD_ID,
		"Traducción ES",
		FILE_PATH,
		"tu_nombre",
		{"config.ini" = _on_config_updated}
	)

func _on_config_updated(config: ConfigFile):
	var main = get_node_or_null("/root/RtvEs")
	if main:
		main.apply_from_config(config)

func get_setting(section: String, key: String, default_val):
	var _config = ConfigFile.new()
	if _config.load(FILE_PATH + "/config.ini") != OK:
		return default_val
	var data = _config.get_value(section, key, null)
	if data is Dictionary and data.has("value"):
		return data["value"]
	return default_val