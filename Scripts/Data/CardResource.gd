class_name CardResource
extends CardBaseResource
# ==================================================
# Dado puro de uma carta de Animal. Preenchido pelo CardImporterButton
# a partir de animais_profissional.csv.
#
# id, name, super_type e text_ui vêm de CardBaseResource — não
# duplicar esses campos aqui.
# ==================================================
const MAPA_EMOJIS := {
	"🔵": "azul",
	"🟢": "verde",
	"🔴": "vermelho",
	"🟡": "amarelo",
	"🟤": "marrom",
	"⚪": "incolor"
}

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
	var texto := attack_cost.strip_edges()

	if texto.is_empty():
		return custo

	# Caso 1: Custo escrito com vírgula ou dois pontos (ex: "azul:1, incolor:1" ou "🔵:1, ⚪:1")
	if "," in texto or ":" in texto:
		var partes := texto.split(",")
		for parte in partes:
			var item := parte.strip_edges()
			if item.is_empty(): continue

			var cor_raw := item
			var qtd := 1
			if ":" in item:
				var sub := item.split(":")
				cor_raw = sub[0].strip_edges()
				qtd = sub[1].strip_edges().to_int()

			var cor_norm := _normalizar_cor(cor_raw)
			if qtd > 0 and not cor_norm.is_empty():
				custo[cor_norm] = custo.get(cor_norm, 0) + qtd

	# Caso 2: Custo escrito como sequência de emojis colados (ex: "🔵⚪" ou "🔵🔵🟡")
	else:
		for caracter in texto:
			var c_str := str(caracter).strip_edges()
			if c_str.is_empty(): continue
			var cor_norm := _normalizar_cor(c_str)
			if not cor_norm.is_empty():
				custo[cor_norm] = custo.get(cor_norm, 0) + 1

	return custo


func _normalizar_cor(valor: String) -> String:
	valor = valor.strip_edges().to_lower()
	
	# Se for um emoji conhecido, retorna o texto correspondente
	if MAPA_EMOJIS.has(valor):
		return MAPA_EMOJIS[valor]

	# Fallbacks para textos equivalentes
	match valor:
		"blue", "azul": return "azul"
		"green", "verde": return "verde"
		"red", "vermelho": return "vermelho"
		"yellow", "amarelo": return "amarelo"
		"brown", "marrom": return "marrom"
		"colorless", "incolor", "cinza", "sem_cor": return "incolor"
		_: return valor
