# ==================================================
# Nome: GameState
# Categoria: Core
# Responsável por armazenar o estado público da partida (Mesa/Tabuleiro).
#
# Deve controlar:
# - Turno e Fase atuais
# - Cartas expostas na mesa (Ativos, Bancos, Descartes, Território)
# - Jogadores inscritos na partida (PlayerStates)
# - Flags de estado de ações do turno
#
# Não deve executar regras.
# Autoload (singleton).
# ==================================================
extends Node

# ==================================================
# FASES DO TURNO
# ==================================================
enum Fase {INICIO, COMPRA, COMIDA, PRINCIPAL, ATAQUE, FINAL}

# ==================================================
# ESTADO DA PARTIDA E TURNO
# ==================================================
var partida_ativa := false
var turno_atual := 1
var jogador_ativo := 0
var fase_atual: Fase = Fase.INICIO

# Flags de limite por turno
var energia_anexada_neste_turno := false
var recuo_realizado_neste_turno := false
var cataclismo_jogado_neste_turno := false

# ==================================================
# JOGADORES (INFORMAÇÃO PRIVADA/METRICAS)
# ==================================================
var jogador_1: PlayerState
var jogador_2: PlayerState

# ==================================================
# CAMPO GLOBAL / TABULEIRO (INFORMAÇÃO PÚBLICA)
# ==================================================
# Animais Ativos em combate
var ativo_j0: AnimalInstance = null
var ativo_j1: AnimalInstance = null

# Bancos de reserva
var banco_j0: Array[AnimalInstance] = []
var banco_j1: Array[AnimalInstance] = []

# Pilhas de Descarte visíveis na mesa
var descarte_j0: Array[CardBaseResource] = []
var descarte_j1: Array[CardBaseResource] = []

# Território Ativo
var territorio_ativo: EffectResource = null
var jogador_sem_ativo: int = -1

# Animais nocateados pelos jogadortes
var nocautes_j0: int = 0 # Quantos animais o Jogador 0 nocauteou
var nocautes_j1: int = 0 # Quantos animais o Jogador 1 nocauteou

# Vitória
var vencedor: PlayerState = null

# ==================================================
# CONSULTAS DO TABULEIRO E JOGADORES
# ==================================================

## Retorna o PlayerState do jogador da vez.
func get_jogador_atual() -> PlayerState:
	return jogador_1 if jogador_ativo == 0 else jogador_2

func get_jogador_por_id(jogador_id: int) -> PlayerState:
	return jogador_1 if jogador_id == 0 else jogador_2
	
## Retorna o PlayerState do jogador adversário.
func get_jogador_adversario() -> PlayerState:
	return jogador_2 if jogador_ativo == 0 else jogador_1

## Retorna o Animal Ativo de um jogador específico (0 ou 1).
func obter_ativo(jogador_id: int) -> AnimalInstance:
	return ativo_j0 if jogador_id == 0 else ativo_j1

## Retorna o Banco de um jogador específico (0 ou 1).
func obter_banco(jogador_id: int) -> Array[AnimalInstance]:
	return banco_j0 if jogador_id == 0 else banco_j1

## Retorna a Zona de Descarte de um jogador específico (0 ou 1).
func obter_descarte(jogador_id: int) -> Array[CardBaseResource]:
	return descarte_j0 if jogador_id == 0 else descarte_j1

## Retorna o Animal Ativo do jogador da vez.
func get_ativo_atual() -> AnimalInstance:
	return obter_ativo(jogador_ativo)

## Retorna o Banco do jogador da vez.
func get_banco_atual() -> Array[AnimalInstance]:
	return obter_banco(jogador_ativo)

## Retorna todos os animais em campo de um jogador (Ativo + Banco).
func obter_animais_em_campo(jogador_id: int) -> Array[AnimalInstance]:
	var animais: Array[AnimalInstance] = []
	var ativo := obter_ativo(jogador_id)
	
	if ativo != null:
		animais.append(ativo)
		
	animais.append_array(obter_banco(jogador_id))
	return animais
