# =========================================================
# Animal Instance 
# =========================================================
# =========================================================
# Responsavel por armazenar as mudanças que ocorrem durante o jogo
# Danos, Condição de status, energias associadas etc.
# =========================================================
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
