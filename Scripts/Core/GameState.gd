# ==================================================
# Nome: GameState
# Categoria: Core
# Responsável por armazenar o estado atual da partida.
#
# Deve controlar:
# - Jogadores
# - Turno atual
# - Fase atual
# - Mão dos jogadores
# - Campo dos jogadores
# - Banco dos jogadores
# - Descarte
# - Deck
#
# Não deve executar regras.
# ==================================================
#class_name GameState

# Partida

var partida_ativa := false

# Turno

var turno_atual := 1

var jogador_ativo := 0

var fase_atual = TurnManager.INICIO

# Flags

var energia_anexada_neste_turno := false

var recuo_realizado_neste_turno := false

var cataclismo_jogado_neste_turno := false

# Jogadores

var jogador_1: PlayerState

var jogador_2: PlayerState

# Campo Global

var territorio_ativo = null

# Vitória

var vencedor = null
