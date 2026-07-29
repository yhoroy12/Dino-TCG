# ==================================================
# Nome: SetupManager
# Categoria: Managers
# Responsável pela preparação da partida.
# ==================================================
extends Node

# ==================================================
# SIGNALS
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
# ==================================================
var _vencedor_sorteio: int = -1
var _mulligans_por_jogador: Dictionary = {0: 0, 1: 0}
var _ativo_confirmado: Dictionary = {0: false, 1: false}
var _fila_mulligan: Array[int] = []

# ==================================================
# ENTRADA PÚBLICA
# ==================================================

func iniciar_partida(nome_deck_j0: String, nome_deck_j1: String) -> void:
	GameState.partida_ativa = false

	# Reseta o tabuleiro no GameState para a nova partida
	GameState.ativo_j0 = null
	GameState.ativo_j1 = null
	GameState.banco_j0.clear()
	GameState.banco_j1.clear()
	GameState.descarte_j0.clear()
	GameState.descarte_j1.clear()
	GameState.jogador_sem_ativo = -1

	_vencedor_sorteio = -1
	_mulligans_por_jogador = {0: 0, 1: 0}
	_ativo_confirmado = {0: false, 1: false}
	_fila_mulligan = []

	GameState.jogador_1 = _criar_jogador(0, nome_deck_j0)
	GameState.jogador_2 = _criar_jogador(1, nome_deck_j1)

	solicitar_lancamento_moeda.emit()


func confirmar_escolha_ordem(vencedor_id: int, quer_jogar_primeiro: bool) -> void:
	if vencedor_id != _vencedor_sorteio:
		return

	if quer_jogar_primeiro:
		GameState.jogador_ativo = vencedor_id
	else:
		GameState.jogador_ativo = 1 if vencedor_id == 0 else 0

	_executar_compra_inicial()


func confirmar_animal_ativo(jogador_id: int, indice_na_mao: int) -> bool:
	var jogador := _obter_jogador(jogador_id)

	if indice_na_mao < 0 or indice_na_mao >= jogador.mao.size():
		return false

	var carta_base: CardBaseResource = jogador.mao[indice_na_mao]

	if not (carta_base is CardResource):
		return false

	var carta: CardResource = carta_base as CardResource

	if carta.super_type != "animal" or carta.stage != "Filhote":
		return false

	jogador.mao.remove_at(indice_na_mao)
	
	# CORREÇÃO: Atribuindo a nova instância à variável correta no GameState
	var nova_instancia := AnimalInstance.new(carta)
	nova_instancia.entrou_este_turno = false

	if jogador_id == 0:
		GameState.ativo_j0 = nova_instancia
	else:
		GameState.ativo_j1 = nova_instancia

	_ativo_confirmado[jogador_id] = true

	var adversario_id := 1 if jogador_id == 0 else 0
	if not _ativo_confirmado[adversario_id]:
		_processar_escolha_ativo(adversario_id)
	else:
		_concluir_setup()

	return true

# ==================================================
# SORTEIO
# ==================================================

func lancar_moeda() -> void:
	_vencedor_sorteio = 0 if randf() < 0.5 else 1
	sorteio_realizado.emit(_vencedor_sorteio)

	if _vencedor_sorteio == 1:
		confirmar_escolha_ordem(1, true)
	else:
		solicitar_escolha_ordem.emit(_vencedor_sorteio)

# ==================================================
# COMPRA INICIAL E MULLIGAN
# ==================================================

func _executar_compra_inicial() -> void:
	_comprar_mao_inicial(GameState.jogador_1)
	_comprar_mao_inicial(GameState.jogador_2)

	_fila_mulligan = [0, 1]
	_processar_proximo_mulligan()


func _processar_proximo_mulligan() -> void:
	if _fila_mulligan.is_empty():
		_entregar_cartas_extras_por_mulligan()
		_processar_escolha_ativo(GameState.jogador_ativo)
		return

	var jogador_id: int = _fila_mulligan[0]
	var jogador := _obter_jogador(jogador_id)

	if _mao_possui_filhote(jogador):
		_fila_mulligan.pop_front()
		_processar_proximo_mulligan()
		return

	if jogador_id == 1:
		confirmar_mulligan(1)
	else:
		mulligan_necessario.emit(jogador_id)


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


func _mao_possui_filhote(jogador: PlayerState) -> bool:
	for carta in jogador.mao:
		if carta is CardResource and carta.super_type == "animal" and carta.stage == "Filhote":
			return true
	return false


func _entregar_cartas_extras_por_mulligan() -> void:
	for jogador_id in _mulligans_por_jogador.keys():
		var quantidade: int = _mulligans_por_jogador[jogador_id]
		if quantidade <= 0:
			continue

		var adversario := _obter_adversario(jogador_id)
		for i in range(quantidade):
			DrawSystem.comprar_carta(adversario)

# ==================================================
# DELEGAÇÃO DE ESCOLHA DE ATIVO (IA vs HUMANO)
# ==================================================

func _processar_escolha_ativo(jogador_id: int) -> void:
	if jogador_id == 1:
		print("🤖 [SETUP IA] Procurando Animal Filhote na mão da IA...")
		var jogador := GameState.jogador_2
		var indice_filhote: int = -1

		for i in range(jogador.mao.size()):
			var carta = jogador.mao[i]
			if carta is CardResource and carta.super_type == "animal" and carta.stage == "Filhote":
				indice_filhote = i
				print("🤖 [SETUP IA] Filhote encontrado na mão: '%s' (Índice: %d)" % [carta.name, i])
				break

		if indice_filhote != -1:
			var nome_carta: String = jogador.mao[indice_filhote].name
			print("🤖 [SETUP IA] Confirmando '%s' como Animal Ativo da IA..." % nome_carta)
			confirmar_animal_ativo(1, indice_filhote)
			print("✅ [SETUP IA] Animal Ativo da IA definido com sucesso!")
		else:
			push_error("❌ SetupManager: IA não encontrou nenhum filhote na mão para definir ativo!")
	else:
		print("👤 [SETUP] Solicitando escolha de Ativo para o Jogador Humano (ID: %d)..." % jogador_id)
		solicitar_escolha_ativo.emit(jogador_id)

# ==================================================
# FINALIZAÇÃO E HELPERS
# ==================================================

func _concluir_setup() -> void:
	GameState.partida_ativa = true
	setup_concluido.emit()
	TurnManager.iniciar_turno()


func _criar_jogador(id: int, identificador_deck: String) -> PlayerState:
	var jogador := PlayerState.new()
	jogador.id = id

	var cartas: Array[CardBaseResource] = _carregar_cartas_do_deck(identificador_deck)
	
	if cartas.is_empty():
		push_error("⚠️ SetupManager: Deck do jogador %d carregou VAZIO: %s" % [id, identificador_deck])

	jogador.deck = cartas.duplicate()
	jogador.deck.shuffle()
	return jogador


func _carregar_cartas_do_deck(identificador: String) -> Array[CardBaseResource]:
	var cartas: Array[CardBaseResource] = []

	if identificador.ends_with(".json") or identificador.begins_with("user://"):
		if not FileAccess.file_exists(identificador):
			push_error("❌ Arquivo de deck JSON não encontrado: " + identificador)
			return cartas

		var file := FileAccess.open(identificador, FileAccess.READ)
		var json_string := file.get_as_text()
		file.close()

		var json := JSON.new()
		if json.parse(json_string) == OK:
			var data: Dictionary = json.data
			var colecao: Array = data.get("colecao", [])

			for item in colecao:
				var carta_id: String = item.get("id", "")
				var qtd: int = item.get("quantidade", 1)

				var carta_res: CardBaseResource = CardDatabase.obter_qualquer(carta_id)
				if carta_res != null:
					for i in range(qtd):
						cartas.append(carta_res)
				else:
					print("⚠️ Carta ID '%s' não foi encontrada no CardDatabase" % carta_id)
	else:
		var deck_data: DeckData = DeckManager.carregar_deck(identificador)
		if deck_data != null and deck_data.cartas != null:
			cartas = deck_data.cartas.duplicate()

	return cartas


func _obter_jogador(id: int) -> PlayerState:
	return GameState.jogador_1 if id == 0 else GameState.jogador_2


func _obter_adversario(id: int) -> PlayerState:
	return GameState.jogador_2 if id == 0 else GameState.jogador_1
