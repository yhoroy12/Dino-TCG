class_name CardResource
extends CardBaseResource
# ==================================================
# Dado puro de uma carta de Animal. Preenchido pelo CardImporterButton
# a partir de animais_profissional.csv.
#
# id, name, super_type e text_ui vêm de CardBaseResource — não
# duplicar esses campos aqui.
# ==================================================

@export_group("Identificadores")
@export var sub_type: String = ""

@export_group("Atributos e Stats")
@export var color: String = ""
@export var stage: String = ""
@export var grow_from: String = ""
@export var hp: int = 0
@export var food_points: int = 0
@export var weakness: String = ""
@export var resistance: String = ""
@export var cost_retreat: int = 0

@export_group("Habilidade e Ataque")
@export var ability_name: String = ""
@export var attack_name: String = ""
@export var attack_cost: String = ""
@export var damage_base: int = 0
@export var damage_type: String = "fixo"

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
	super_type = "animal"
## Converte a String attack_cost (ex: "amarelo:1, incolor:2") em um Dictionary com as contagens.
## Aceita formatos como "amarelo:1, incolor:2", "azul:2" ou vazio.
func obter_custo_ataque_dict() -> Dictionary:
	var custo := {}
	var texto_limpo := attack_cost.strip_edges()
	
	if texto_limpo.is_empty():
		return custo

	# Separa múltiplos custos por vírgula
	var partes := texto_limpo.split(",")
	for parte in partes:
		var item := parte.strip_edges()
		if item.is_empty():
			continue
		
		# Processa chave:valor (ex: "amarelo:1")
		if ":" in item:
			var sub := item.split(":")
			var cor := sub[0].strip_edges().to_lower()
			var qtd := sub[1].strip_edges().to_int()
			if qtd > 0:
				custo[cor] = custo.get(cor, 0) + qtd
		else:
			# Caso venha apenas a cor sem quantidade definida, assume 1
			var cor := item.to_lower()
			custo[cor] = custo.get(cor, 0) + 1

	return custo
