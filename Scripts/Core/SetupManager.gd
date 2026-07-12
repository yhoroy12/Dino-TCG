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
signal solicitar_lancamento_moeda()
signal solicitar_escolha_ordem(vencedor_id: int)
signal mulligan_necessario(jogador_id: int)
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

# Fila de jogadores ainda em checagem de mulligan (processados em
# ordem — um precisa terminar todas as tentativas antes do próximo
# começar, porque só existe uma UI de confirmação por vez).
var _fila_mulligan: Array[int] = []


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
	_fila_mulligan = []

	GameState.jogador_1 = _criar_jogador(0, nome_deck_j0)
	GameState.jogador_2 = _criar_jogador(1, nome_deck_j1)

	solicitar_lancamento_moeda.emit()


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

	var carta_base: CardBaseResource = jogador.mao[indice_na_mao]

	# TODO: migrar para RuleValidator.validate_active_animal(carta)
	# quando o RuleValidator estiver corrigido.
	if not (carta_base is CardResource):
		return false

	var carta: CardResource = carta_base as CardResource

	if carta.super_type != "animal" or carta.stage != "Filhote":
		return false

	jogador.mao.remove_at(indice_na_mao)
	jogador.ativo = AnimalInstance.new(carta)

	# O Animal Ativo inicial NÃO conta como "recém-entrado" para a
	# restrição de ataque (RuleValidator.validate_attack) — a única
	# restrição de turno inicial é "não se pode atacar no turno 1
	# do jogo", que já é checada via GameState.turno_atual. Sem este
	# ajuste, o jogador 2 nunca conseguiria atacar nem no turno 2.
	jogador.ativo.entrou_este_turno = false

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

## Chamado pela UI quando o jogador clica no botão "Lançar Moeda".
func lancar_moeda() -> void:
	_vencedor_sorteio = 0 if randf() < 0.5 else 1

	sorteio_realizado.emit(_vencedor_sorteio)
	# TODO(UI): dá pra inserir aqui um sinal de animação do coinflip
	# (ex: animacao_moeda_iniciada) pra UI tocar a animação e só then
	# revelar o resultado / pedir a escolha de ordem. Por ora os dois
	# sinais saem juntos, sem animação.
	solicitar_escolha_ordem.emit(_vencedor_sorteio)


# ==================================================
# COMPRA INICIAL E MULLIGAN
# ==================================================

func _executar_compra_inicial() -> void:
	_comprar_mao_inicial(GameState.jogador_1)
	_comprar_mao_inicial(GameState.jogador_2)

	_fila_mulligan = [0, 1]
	_processar_proximo_mulligan()


## Avança a fila de checagem de mulligan. Se o jogador da vez já tem
## Filhote na mão, passa pro próximo. Se não tem, emite
## mulligan_necessario() e PARA — só continua quando a UI chamar
## confirmar_mulligan() de volta (uma vez por tentativa).
func _processar_proximo_mulligan() -> void:
	if _fila_mulligan.is_empty():
		_entregar_cartas_extras_por_mulligan()
		solicitar_escolha_ativo.emit(GameState.jogador_ativo)
		return

	var jogador_id: int = _fila_mulligan[0]
	var jogador := _obter_jogador(jogador_id)

	if _mao_possui_filhote(jogador):
		_fila_mulligan.pop_front()
		_processar_proximo_mulligan()
		return

	mulligan_necessario.emit(jogador_id)


## Chamado pela UI depois que o jogador confirma (clique ou timeout
## de 15s) que viu o aviso de mulligan. Refaz a mão e volta a
## checar — se ainda não tiver Filhote, mulligan_necessario() dispara
## de novo (uma confirmação por tentativa, não uma por jogador).
func confirmar_mulligan(jogador_id: int) -> void:
	if _fila_mulligan.is_empty() or _fila_mulligan[0] != jogador_id:
		return

	var jogador := _obter_jogador(jogador_id)

	_mulligans_por_jogador[jogador_id] += 1
	mulligan_realizado.emit(jogador_id, _mulligans_por_jogador[jogador_id])

	jogador.deck.append_array(jogador.mao)
	jogador.mao.clear()
	jogador.deck.shuffle()
	_comprar_mao_inicial(jogador)

	_processar_proximo_mulligan()


func _comprar_mao_inicial(jogador: PlayerState) -> void:
	for i in range(7):
		DrawSystem.comprar_carta(jogador)


## TODO: migrar para RuleValidator.validate_mulligan() quando o
## arquivo estiver corrigido, para centralizar toda validação de
## regra num único lugar em vez de espalhar entre managers.
func _mao_possui_filhote(jogador: PlayerState) -> bool:
	for carta in jogador.mao:
		# .stage só existe em CardResource (Animal) — cartas de Efeito
		# na mão (Energia/Vestígio/etc.) não têm esse campo e devem
		# ser ignoradas aqui, não travar a checagem.
		if carta is CardResource and carta.super_type == "animal" and carta.stage == "Filhote":
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

	# DeckManager não tem mais carregar_deck_para_partida() — a API
	# atual é carregar_deck(nome) -> DeckData, com as cartas já
	# resolvidas em DeckData.cartas (CardBaseResource).
	var deck_data: DeckData = DeckManager.carregar_deck(nome_deck)
	jogador.deck = deck_data.cartas.duplicate()
	jogador.deck.shuffle()
	return jogador


func _obter_jogador(id: int) -> PlayerState:
	return GameState.jogador_1 if id == 0 else GameState.jogador_2


func _obter_adversario(id: int) -> PlayerState:
	return GameState.jogador_2 if id == 0 else GameState.jogador_1
