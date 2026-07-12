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
#
# Autoload (singleton). Por isso NÃO possui class_name: o Godot
# não permite registrar um autoload e uma classe global com o
# mesmo nome ao mesmo tempo. Outros scripts continuam acessando
# por "GameState.algo", como qualquer autoload.
# ==================================================
extends Node


# ==================================================
# FASES DO TURNO
# O enum vive aqui — na fonte da verdade — e não no TurnManager.
# GameState é quem ARMAZENA o dado; TurnManager é só quem o
# modifica. BattleManager e a UI também vão precisar LER a fase
# sem precisar depender do TurnManager para isso.
# ==================================================

enum Fase {INICIO, COMPRA, COMIDA, PRINCIPAL, ATAQUE, FINAL}


# Partida

var partida_ativa := false


# Turno

var turno_atual := 1

var jogador_ativo := 0

var fase_atual: Fase = Fase.INICIO


# Flags

var energia_anexada_neste_turno := false

var recuo_realizado_neste_turno := false

var cataclismo_jogado_neste_turno := false


# Jogadores

var jogador_1: PlayerState

var jogador_2: PlayerState


# Campo Global

var territorio_ativo: EffectResource = null


# Vitória

var vencedor: PlayerState = null


# ==================================================
# CONSULTAS
# Leitura pura, sem alterar estado. Existem para que nenhum
# outro sistema precise repetir a lógica
# "jogador_ativo == 0 ? jogador_1 : jogador_2" espalhada pelo
# projeto — se essa regra mudar (ex: mais de 2 jogadores no
# futuro), só este arquivo precisa mudar.
# ==================================================

## Retorna o PlayerState do jogador da vez.
func get_jogador_atual() -> PlayerState:
	return jogador_1 if jogador_ativo == 0 else jogador_2


## Retorna o PlayerState do jogador adversário do jogador da vez.
func get_jogador_adversario() -> PlayerState:
	return jogador_2 if jogador_ativo == 0 else jogador_1
