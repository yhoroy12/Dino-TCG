# ==================================================
# Nome: SetupManager
# Categoria: Core
# Responsável pela preparação da partida.
#
# Deve controlar:
# - Escolha de moeda
# - Lançamento da moeda
# - Compra inicial
# - Mulligan
# - Cartas bônus do mulligan
# - Escolha do animal ativo inicial
#
# Não deve controlar turnos.
# ==================================================
func escolher_moeda():
	#Responsavel por verificar qual a escolha do jogador se ele quer ser o primeiro ou segundo
	return

func lançar_moeda():
	#Responsavel por lançar a moeda e gerar o resultado de cara ou coroa
	return
func renderizar_deck():
	#responsavel por embaralhar o deck dos jogadores no inicio da partida
	return
func compra_inicial():
	#Responsavel por comprar as primeiras 7 cartas da mao de cada jogador
	return
func mulligan():
	#responsavel por verificar a mão de cada jogador se possui ao menos um filhote, executar o mulligan
	return
func entregar_cartas_extras():
	#responsavel por entregar as cartas extras para o jogador como resultado do mulligan
	return
func escolher_animal_ativo():
	#responsavel por solicitar o animal ativo para inicio da partida
	return


#==============================================
# Funções que tinha o Gamestate antigo
#======================================
func confirmar_lancamento_moeda() -> void:
	var resultado := lancar_moeda("Sorteio do Primeiro Jogador")
	jogador_ativo = 0 if resultado else 1
	print("GameState: Jogador %d vai jogar primeiro." % jogador_ativo)
	_executar_compra_inicial()

func _executar_compra_inicial() -> void:
	print("\n========== COMPRA INICIAL ==========")
	for i in range(7):
		print("Rodada de compra: ", i + 1)
		_comprar_carta_silencioso(0)
		_comprar_carta_silencioso(1)
	print("Mão Jogador 0: ", jogadores[0]["mao"].size())
	print("Mão Jogador 1: ", jogadores[1]["mao"].size())	
	
	print("Iniciando verificação de mulligan...")
	_verificar_mulligan(0)

func _verificar_mulligan(jogador_id: int) -> void:
	print("\n========== VERIFICAR MULLIGAN ==========")
	print("Jogador: ", jogador_id)
	print("Cartas na mão: ", jogadores[jogador_id]["mao"].size())
	var tem_filhote := false
	for carta in jogadores[jogador_id]["mao"]:
		if carta == null:
			print("Carta NULL encontrada")
			continue

		print(
			"Carta: ",
			carta.name,
			" | Tipo: ",
			carta.super_type,
			" | Stage: ",
			carta.stage
		)
		
		if carta.super_type == "animal" and carta.stage == "Filhote":
			print("FILHOTE ENCONTRADO!")
			tem_filhote = true
			break
	print("Resultado Mulligan: ", tem_filhote)
	
	if tem_filhote:
		# Passa para o próximo jogador ou para escolha do ativo
		if jogador_id == 0:
			_verificar_mulligan(1)
		else:
			_entregar_cartas_extras_mulligan()
	else:
		print("Solicitando mulligan...")
		emit_signal("solicitar_mulligan", jogador_id)

func confirmar_mulligan(jogador_id: int) -> void:
	print("\n========== MULLIGAN ==========")
	print("Jogador: ", jogador_id)
	print("Mulligan #: ", _mulligans_jogador[jogador_id] + 1)

	print("Cartas devolvidas ao deck: ",jogadores[jogador_id]["mao"].size())
	
	_mulligans_jogador[jogador_id] += 1
	# Devolve a mão ao deck e reembaralha
	for carta in jogadores[jogador_id]["mao"]:
		jogadores[jogador_id]["deck"].append(carta)
	
	jogadores[jogador_id]["mao"].clear()
	print("Deck após devolver cartas: ",jogadores[jogador_id]["deck"].size())
	
	jogadores[jogador_id]["deck"].shuffle()

	# Compra nova mão
	for i in range(7):
		_comprar_carta_silencioso(jogador_id)
	print("Nova mão: ",
		jogadores[jogador_id]["mao"].size())

	_verificar_mulligan(jogador_id)

func _entregar_cartas_extras_mulligan() -> void:
	for jogador_id in [0, 1]:
		var quantidade = _mulligans_jogador[jogador_id]
		if quantidade > 0:
			var adversario_id := 1 if jogador_id == 0 else 0
			for i in range(quantidade):
				_comprar_carta_silencioso(adversario_id)
			print("GameState: Jogador %d recebeu %d carta(s) extra(s) por mulligan do adversário." % [adversario_id, quantidade])
			emit_signal("cartas_extras_entregues", adversario_id, quantidade)

	# Solicita escolha do ativo para o jogador que vai jogar primeiro
	emit_signal("solicitar_escolha_ativo", jogador_ativo)

func inicializar_setup(nome_deck_j0: String, nome_deck_j1: String) -> void:
	# Inicializa estruturas sem iniciar o turno
	partida_ativa = false
	turno_atual = TURNO_INICIAL
	fase_atual = Fase.COMPRAR
	_mulligans_jogador = [0, 0]
	_ativo_confirmado = [false, false]

	jogadores = {
		0: {
			"deck": DeckManager.carregar_deck_para_partida(nome_deck_j0),
			"mao": [] as Array[CardResource],
			"banco": [],
			"zona_ativo": null,
			"pilha_descarte": [] as Array[CardResource],
			"pontos_comida": 0,
			"animais_nocauteados": 0,
			"condicao": Condicao.NENHUMA,
			"turnos_na_condicao": 0
		},
		1: {
			"deck": DeckManager.carregar_deck_para_partida(nome_deck_j1),
			"mao": [] as Array[CardResource],
			"banco": [],
			"zona_ativo": null,
			"pilha_descarte": [] as Array[CardResource],
			"pontos_comida": 0,
			"animais_nocauteados": 0,
			"condicao": Condicao.NENHUMA,
			"turnos_na_condicao": 0
		}
	}

	jogadores[0]["deck"].shuffle()
	jogadores[1]["deck"].shuffle()
	print("GameState: inicializar_setup chamado. Jogadores prontos.")
	emit_signal("solicitar_lancamento_moeda")

func confirmar_ativo(jogador_id: int, indice_na_mao: int) -> bool:
	var resultado := jogar_animal_para_ativo(jogador_id, indice_na_mao)
	if not resultado: return false

	_ativo_confirmado[jogador_id] = true
	print("GameState: Jogador %d confirmou o ativo inicial." % jogador_id)

	# Verifica se o outro jogador ainda não confirmou
	var outro_id := 1 if jogador_id == 0 else 0
	if not _ativo_confirmado[outro_id]:
		emit_signal("solicitar_escolha_ativo", outro_id)
	else:
		_iniciar_primeiro_turno()
	return true
