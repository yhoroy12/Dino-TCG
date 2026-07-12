# ==================================================
# Nome: MatchData
# Categoria: Data
# Responsável por armazenar dados completos de uma partida.
#
# Hoje cobre a etapa de TRANSIÇÃO: os nomes dos decks
# escolhidos antes da partida começar, que a cena da mesa
# (MesaJogador) consome para chamar
# SetupManager.iniciar_partida(deck_j0, deck_j1).
#
# NÃO é estado de partida em andamento (isso é GameState) e
# NÃO decide regra nenhuma. Existe como autoload pela mesma
# razão do DeckManager.deck_em_edicao: change_scene_to_file()
# não permite passar argumentos, então algum lugar precisa
# guardar o dado entre uma cena e outra.
#
# Autoload (singleton), no mesmo padrão de GameState/DeckManager.
# ==================================================
extends Node

var deck_pendente_j0: String = ""
var deck_pendente_j1: String = ""

## Dados de contexto da IA, coletados hoje pela tela ModoTreino
## (seleção de adversário Rex/Trike/Raptor + dificuldade) mas ainda
## não consumidos por nenhum sistema de IA — guardados aqui pra não
## se perderem até esse sistema existir.
var adversario_ia_id: String = ""
var dificuldade_ia: String = ""


## Prepara os dados de uma partida contra a IA usando o deck
## atualmente marcado como ativo pelo DeckManager para o
## jogador humano, e o deck informado para o oponente.
func preparar_partida_vs_ia(nome_deck_ia: String, dificuldade: String = "", adversario_id: String = "") -> bool:
	var deck_humano: String = DeckManager.obter_deck_ativo()

	if deck_humano == "":
		push_error("MatchData: nenhum deck ativo definido pelo jogador (DeckManager.obter_deck_ativo() retornou vazio).")
		return false

	deck_pendente_j0 = deck_humano
	deck_pendente_j1 = nome_deck_ia
	dificuldade_ia = dificuldade
	adversario_ia_id = adversario_id
	return true


## Limpa os dados pendentes. Chamar depois que
## SetupManager.iniciar_partida() já consumiu os valores, pra
## não vazar os decks de uma partida antiga pra próxima.
func limpar() -> void:
	deck_pendente_j0 = ""
	deck_pendente_j1 = ""
	dificuldade_ia = ""
	adversario_ia_id = ""
