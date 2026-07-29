# ==================================================
# Nome: PlayerState
# Categoria: Core
# Responsável por armazenar os dados PRIVADOS e métricas do jogador.
#
# Contém:
# - Mão (privada)
# - Deck (pilha fechada)
# - Pontos de comida disponíveis (recurso)
# - Status de vitória/derrota
# ==================================================
class_name PlayerState
extends RefCounted

var id: int

# Deck e Mão
# CardBaseResource permite armazenar Animais e Efeitos misturados.
var deck: Array[CardBaseResource] = []
var mao: Array[CardBaseResource] = []

# Recursos
var comida_disponivel: int = 0

# Controle
var venceu := false
var derrotado := false

# ==================================================
# CONSULTAS LOCAIS
# ==================================================

## Procura o índice da mão que contém o primeiro animal do estágio Filhote.
## Retorna -1 se não encontrar.
func obter_indice_primeiro_filhote() -> int:
	for i in mao.size():
		var carta = mao[i]
		if carta is CardResource and carta.super_type == "animal" and carta.stage == "Filhote":
			return i
	return -1
