class_name AbilityResource
extends Resource
# ==================================================
# Dado puro de uma Habilidade de animal. Preenchido pelo
# CardImporterButton a partir de habilidade_profissional.csv.
# ==================================================

@export_group("Identificadores")
@export var id: String = ""
@export var name: String = ""
@export_multiline var text_ui: String = ""

@export_group("Motor do Jogo (mec_*)")
@export var mec_trigger: String = ""
@export var mec_condition: String = ""
@export var mec_action: String = ""
@export var mec_resource: String = ""
@export var mec_target_player: String = ""
@export var mec_target_zone: String = ""
@export var mec_quantity: int = 0
@export_multiline var mec_custom_json: String = ""
