# ==================================================
# Nome: SetupManager
# Categoria: Managers
# Responsável pela preparação da partida.
#
# Deve controlar:
# - Sorteio de quem joga primeiro
# - Escolha de ordem (o vencedor decide 1º ou 2º)
# - Compra inicial (7 cartas)
# - Mulligan (repete a compra automaticamente até haver Filhote)
# - Cartas bônus de compensação por mulligan
# - Escolha do animal ativo inicial
#
# Não deve controlar turnos (isso é do TurnManager, que este
# script chama apenas UMA vez, ao final, para iniciar a partida).
#
# Autoload (singleton), no mesmo padrão de GameState/TurnManager.
# Usa signals porque duas etapas dependem de decisão do jogador
# (via UI): escolha de ordem e escolha do animal ativo.
# ==================================================
extends Node


# ==================================================
# SIGNALS
# A UI escuta esses sinais para saber quando pedir uma decisão
# ao jogador, e chama de volta confirmar_escolha_ordem() /
# confirmar_animal_ativo() quando o jogador decidir.
# ==================================================

signal sorteio_realizado(vencedor_id: int)
signal solicitar_escolha_ordem(vencedor_id: int)
signal mulligan_realizado(jogador_id: int, quantidade: int)
signal solicitar_escolha_ativo(jogador_id: int)
signal setup_concluido()


# ==================================================
# ESTADO INTERNO DO SETUP
# Existe só durante a preparação da partida. Depois que
# setup_concluido é emitido, GameState passa a ser a única
# fonte da verdade — nada aqui deve ser lido de fora.
# ==================================================

var _vencedor_sorteio: int = -1
var _mulligans_por_jogador: Dictionary = {0: 0, 1: 0}
var _ativo_confirmado: Dictionary = {0: false, 1: false}


# ==================================================
# ENTRADA PÚBLICA
# ==================================================

## Ponto de entrada do setup. Cria os dois jogadores, embaralha
## os decks e inicia o sorteio de quem joga primeiro.
func iniciar_partida(nome_deck_j0: String, nome_deck_j1: String) -> void:
	GameState.partida_ativa = false

	_vencedor_sorteio = -1
	_mulligans_por_jogador = {0: 0, 1: 0}
	_ativo_confirmado = {0: false, 1: false}

	GameState.jogador_1 = _criar_jogador(0, nome_deck_j0)
	GameState.jogador_2 = _criar_jogador(1, nome_deck_j1)

	_lancar_moeda()


## Chamado pela UI quando o vencedor do sorteio decide a ordem.
## quer_jogar_primeiro: true = vencedor joga primeiro, false =
## vencedor abre mão da ordem e deixa o adversário jogar primeiro.
func confirmar_escolha_ordem(vencedor_id: int, quer_jogar_primeiro: bool) -> void:
	if vencedor_id != _vencedor_sorteio:
		return

	if quer_jogar_primeiro:
		GameState.jogador_ativo = vencedor_id
	else:
		GameState.jogador_ativo = 1 if vencedor_id == 0 else 0

	_executar_compra_inicial()


## Chamado pela UI quando um jogador escolhe seu animal ativo
## inicial (índice de uma carta na própria mão).
## Retorna false se a escolha for inválida (ex: não é Filhote).
func confirmar_animal_ativo(jogador_id: int, indice_na_mao: int) -> bool:
	var jogador := _obter_jogador(jogador_id)

	if indice_na_mao < 0 or indice_na_mao >= jogador.mao.size():
		return false

	var carta: CardResource = jogador.mao[indice_na_mao]

	# TODO: migrar para RuleValidator.validate_active_animal(carta)
	# quando o RuleValidator estiver corrigido.
	if carta.super_type != "animal" or carta.stage != "Filhote":
		return false

	jogador.mao.remove_at(indice_na_mao)
	jogador.ativo = AnimalInstance.new(carta)

	_ativo_confirmado[jogador_id] = true

	var adversario_id := 1 if jogador_id == 0 else 0
	if not _ativo_confirmado[adversario_id]:
		solicitar_escolha_ativo.emit(adversario_id)
	else:
		_concluir_setup()

	return true


# ==================================================
# SORTEIO
# ==================================================

func _lancar_moeda() -> void:
	_vencedor_sorteio = 0 if randf() < 0.5 else 1

	sorteio_realizado.emit(_vencedor_sorteio)
	solicitar_escolha_ordem.emit(_vencedor_sorteio)


# ==================================================
# COMPRA INICIAL E MULLIGAN
# ==================================================

func _executar_compra_inicial() -> void:
	_realizar_mulligan_automatico(GameState.jogador_1)
	_realizar_mulligan_automatico(GameState.jogador_2)

	_entregar_cartas_extras_por_mulligan()

	solicitar_escolha_ativo.emit(GameState.jogador_ativo)


## Compra 7 cartas. Se a mão não tiver nenhum Filhote, devolve a
## mão ao deck, embaralha e repete — regra oficial de mulligan.
##
## TODO: migrar a checagem "mão tem Filhote" para
## RuleValidator.validate_mulligan() quando o arquivo estiver
## corrigido, para centralizar toda validação de regra num único
## lugar em vez de espalhar entre managers.
func _realizar_mulligan_automatico(jogador: PlayerState) -> void:
	_comprar_mao_inicial(jogador)

	while not _mao_possui_filhote(jogador):
		_mulligans_por_jogador[jogador.id] += 1
		mulligan_realizado.emit(jogador.id, _mulligans_por_jogador[jogador.id])

		jogador.deck.append_array(jogador.mao)
		jogador.mao.clear()
		jogador.deck.shuffle()

		_comprar_mao_inicial(jogador)


func _comprar_mao_inicial(jogador: PlayerState) -> void:
	for i in range(7):
		DrawSystem.comprar_carta(jogador)


func _mao_possui_filhote(jogador: PlayerState) -> bool:
	for carta in jogador.mao:
		if carta.super_type == "animal" and carta.stage == "Filhote":
			return true

	return false


## Compensação de mulligan: para cada mulligan que um jogador fez,
## o adversário dele compra 1 carta extra.
func _entregar_cartas_extras_por_mulligan() -> void:
	for jogador_id in _mulligans_por_jogador.keys():
		var quantidade: int = _mulligans_por_jogador[jogador_id]

		if quantidade <= 0:
			continue

		var adversario := _obter_adversario(jogador_id)

		for i in range(quantidade):
			DrawSystem.comprar_carta(adversario)


# ==================================================
# FINALIZAÇÃO
# ==================================================

func _concluir_setup() -> void:
	GameState.partida_ativa = true
	setup_concluido.emit()
	TurnManager.iniciar_turno()


# ==================================================
# HELPERS
# ==================================================

func _criar_jogador(id: int, nome_deck: String) -> PlayerState:
	var jogador := PlayerState.new()
	jogador.id = id
	jogador.deck = DeckManager.carregar_deck_para_partida(nome_deck)
	jogador.deck.shuffle()
	return jogador


func _obter_jogador(id: int) -> PlayerState:
	return GameState.jogador_1 if id == 0 else GameState.jogador_2


func _obter_adversario(id: int) -> PlayerState:
	return GameState.jogador_2 if id == 0 else GameState.jogador_1
