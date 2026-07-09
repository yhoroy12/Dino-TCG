class_name PlayerState
extends RefCounted

var id : int

# Deck

var deck : Array[CardResource] = []
var mao : Array[CardResource] = []
var descarte : Array[CardResource] = []

# Campo

var ativo : AnimalInstance = null

var banco : Array[AnimalInstance] = []

# Recursos

var comida_disponivel : int = 0

# Controle

var venceu := false
var derrotado := false


# ==================================================
# CONSULTAS
# ==================================================

## Retorna todos os animais em campo deste jogador (ativo + banco).
## Centraliza essa consulta aqui para que TurnManager, EffectSystem,
## ConditionSystem e (em breve) BattleManager não precisem repetir
## a lógica de "ativo != null ? [ativo] + banco : banco" cada um
## com sua própria variação.
func animais_em_campo() -> Array[AnimalInstance]:
	var animais: Array[AnimalInstance] = []

	if ativo != null:
		animais.append(ativo)

	animais.append_array(banco)

	return animais
