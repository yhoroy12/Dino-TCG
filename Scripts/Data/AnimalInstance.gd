# ==================================================
# Nome: AnimalInstance
# Categoria: Data
# Responsável por representar um animal durante a partida.
#
# Deve armazenar:
# - Vida atual
# - Comida atual
# - Evolução
# - Status
# - Energias anexadas
# - Efeitos temporários
# ==================================================

class_name AnimalInstance
extends RefCounted

var card : CardResource
#Variaveis de estado das cartas

var current_hp : int # hp atual
var current_food : int # comida atual
var attached_energies : Array = [] # futuramente var attached_energies : Array[EnergyResource] = [] energias anexadas
var conditions : Array = [] #Estatus de condiçao especial
var entrou_este_turno := true #verifica se foi colocado nesse turno ou nao.
var evoluiu_este_turno := false# verifica se ele evoluiu nesse turno ou nao.
var temporary_effects : Array = []
var ja_atacou_este_turno := false # Impede múltiplos ataques no mesmo turno
var pilha_evolucao : Array[CardResource] = []

func _init(card_resource : CardResource):

	card = card_resource

	current_hp = card.hp
	current_food = 0

	attached_energies.clear()
	conditions.clear()
	temporary_effects.clear()
	pilha_evolucao.clear()

func contar_energias_por_cor() -> Dictionary:
	var contagem := {}
	for energia in attached_energies:
		if energia == null:
			continue
		
		var cor_raw: String = ""
		
		# Duck Typing: Funciona independente da classe da carta (CardResource, EffectResource, etc)
		if "mec_filter_color" in energia and not str(energia.mec_filter_color).strip_edges().is_empty():
			cor_raw = str(energia.mec_filter_color)
		elif "color" in energia:
			cor_raw = str(energia.color)

		var cor: String = cor_raw.strip_edges().to_lower()
		if not cor.is_empty():
			contagem[cor] = contagem.get(cor, 0) + 1

	return contagem
	
func tem_energias_suficientes(custo: Dictionary) -> bool:
	if custo.is_empty():
		return true

	# Clona a contagem para podermos abater conforme validamos
	var disponiveis := contar_energias_por_cor()

	# PASSO 1: Valida e abate os custos de cores específicas (ex: "azul", "amarelo")
	for cor in custo.keys():
		if cor == "incolor":
			continue

		var necessario: int = custo[cor]
		var possui: int = disponiveis.get(cor, 0)

		if possui < necessario:
			return false # Faltou energia da cor exata exigida

		disponiveis[cor] -= necessario

	# PASSO 2: Soma todas as energias sobrantes de qualquer cor para pagar o custo 'incolor'
	var incolor_necessario: int = custo.get("incolor", 0)
	if incolor_necessario > 0:
		var total_sobra: int = 0
		for cor in disponiveis.keys():
			total_sobra += disponiveis[cor]

		if total_sobra < incolor_necessario:
			return false # Não sobrou energia suficiente para o custo incolor

	return true
	
func pode_usar_ataque(ataque: CardResource) -> bool:
	if ataque == null:
		return false
	return tem_energias_suficientes(ataque.obter_custo_ataque_dict())
