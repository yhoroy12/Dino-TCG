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

# NOVO: pilha de evolução (padrão Pokémon/Digimon TCG). Quando o
# animal cresce, a carta do estágio anterior NÃO é descartada — ela
# fica "por baixo" da carta nova, guardada aqui. Regra confirmada
# com o time:
# - Só vai pra pilha de descarte do dono quando o animal é
#   nocauteado (KnockoutSystem.processar_nocaute descarta tudo que
#   está aqui, junto com a carta atual e as energias anexadas).
# - Se a carta de cima (a atual, `card`) for devolvida pra mão do
#   jogador por algum efeito (nenhuma carta faz isso ainda —
#   Vestígio/Cataclismo são prioridades futuras), as cartas
#   empilhadas aqui vão pro descarte também, NÃO voltam pra mão junto
#   — só a carta do topo retorna. Ainda não há gatilho implementado
#   pra esse caso (não existe carta com esse efeito no projeto hoje).
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
