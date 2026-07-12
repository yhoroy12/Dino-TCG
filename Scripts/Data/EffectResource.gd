class_name EffectResource
extends CardBaseResource
# ==================================================
# Dado puro de uma carta de Efeito: Energia, Vestígio, Cataclismo ou
# Território. Preenchido pelo CardImporterButton a partir de
# efeitos_profissional.csv.
#
# id, name, super_type e text_ui vêm de CardBaseResource — não
# duplicar esses campos aqui. super_type aqui assume os valores
# "energia", "vestigio", "cataclismo" ou "territorio".
# ==================================================

@export_group("Motor do Jogo (mec_*)")
@export var mec_trigger: String = ""
@export var mec_condition: String = ""
@export var mec_action: String = ""
@export var mec_resource: String = ""
@export var mec_target_player: String = ""
@export var mec_target_zone: String = ""
@export var mec_quantity: int = 0
@export var mec_status_name: String = ""
@export var mec_filter_color: String = ""
@export var mec_filter_stage: String = ""
@export var mec_origin_zone: String = ""
@export var mec_duration: int = 0
@export_multiline var mec_custom_json: String = ""


func _init() -> void:
	super_type = "vestigio"
