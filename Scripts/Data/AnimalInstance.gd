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
var attached_energies : Array = [] #energias anexadas
var conditions : Array = [] #Estatus de condiçao especial
var entrou_este_turno : bool = true #verifica se foi colocado nesse turno ou nao.
var evoluiu_este_turno : bool = false# verifica se ele evoluiu nesse turno ou nao.

func _init(card_resource : CardResource):

	card = card_resource

	current_hp = card.hp

	current_food = 0
	
	attached_energies = []
	
func contar_energias_por_cor() -> Dictionary:
	var contagem := {}
	for energia in attached_energies:
		var cor: String = energia.mec_filter_color
		contagem[cor] = contagem.get(cor, 0) + 1
	return contagem

func tem_energias_suficientes(custo: Dictionary) -> bool:
	var disponivel := contar_energias_por_cor()
	var total_disponivel := attached_energies.size()
	var incolores_necessarios := custo.get("incolor", 0) as int

	# Valida cores obrigatórias primeiro
	for cor in custo:
		if cor == "incolor": continue
		var necessario: int = custo[cor]
		var tem: int = disponivel.get(cor, 0)
		if tem < necessario: return false
		total_disponivel -= necessario

	# Valida incolores com o que sobrou
	if total_disponivel < incolores_necessarios: return false
	return true
