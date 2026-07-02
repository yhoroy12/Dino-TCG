extends Node

# ==============================================================================
# GameState — Autoload Singleton (core/autoloads/GameState.gd)
# Fonte da Verdade Absoluta. Gerencia estados, turnos, fases e regras do TCG.
# ==============================================================================

# -----------------------------------------------------------------------------
# SINAIS DE NOTIFICAÇÃO (Para a Interface Gráfica escutar)
# -----------------------------------------------------------------------------
signal turno_iniciado(jogador_id: int)
signal turno_encerrado(jogador_id: int)
signal animal_nocauteado(jogador_id: int, instancia: AnimalInstance)
signal condicao_aplicada(jogador_id: int, condicao: int)
signal vitoria(jogador_id: int)
signal empate()
signal alimentacao_distribuida(jogador_id: int)
signal moeda_lancada(acao: String, resultado: bool)
signal animal_nocauteado_por_fome(jogador_id: int)
signal animal_evoluido(jogador_id: int, instancia: AnimalInstance)
signal energia_anexada(jogador_id: int, instancia: AnimalInstance, energia: CardResource)
signal ataque_declarado(jogador_id: int, dano: int)
signal recuo_executado(jogador_id: int)
signal solicitar_lancamento_moeda()
signal solicitar_mulligan(jogador_id: int)
signal cartas_extras_mulligan_entregues(jogador_id: int, quantidade: int)
signal solicitar_escolha_ativo(jogador_id: int)
signal setup_concluido()

# -----------------------------------------------------------------------------
# CONSTANTES E ENUMS DE REGRAS (Rulebook v3)
# -----------------------------------------------------------------------------
enum Condicao {
	NENHUMA,
	ADORMECIDO,
	PARALISADO,
	ENVENENADO,
	SANGRANDO
}

const DANO_CONDICAO := {
	Condicao.ENVENENADO: 10,
	Condicao.SANGRANDO:  20,
}

const PONTOS_COMIDA_POR_TURNO := 3
const ANIMAIS_PARA_VENCER     := 4
const MAX_BANCO_RESERVA       := 5
const TURNO_INICIAL           := 1

const EMOJI_COR := {
	"🔵": "azul",
	"🟡": "amarelo",
	"🟢": "verde",
	"🟤": "marrom",
	"🔴": "vermelho",
	"⚪": "incolor"
}

# -----------------------------------------------------------------------------
# ESTADO CÉLULA DA PARTIDA ATIVA
# -----------------------------------------------------------------------------
enum Fase { COMPRAR, ALIMENTACAO, PRINCIPAL, ATAQUE, FIM }


var _mulligans_jogador: Array = [0, 0]  # contagem por jogador
var _ativo_confirmado: Array = [false, false]  # controle de confirmação

var partida_ativa: bool = false
var turno_atual: int    = TURNO_INICIAL
var jogador_ativo: int  = 0 # 0 = Jogador Humano, 1 = Oponente/IA
var fase_atual: Fase    = Fase.COMPRAR
var energia_anexada_neste_turno: bool = false
var deck_pendente_j0: String = ""
var deck_pendente_j1: String = ""


# Dicionário de Estado dos Jogadores - Correção dos casts de Array e do valor Null
var jogadores: Dictionary = {
	0: {
		"deck": [] as Array[CardResource],
		"mao": [] as Array[CardResource],
		"banco": [],   # Array[AnimalInstance]
		"zona_ativo": null, # Removido o cast inválido de null
		"pilha_descarte": [] as Array[CardResource],
		"pontos_comida": 0,
		"animais_nocauteados": 0,
		"condicao": Condicao.NENHUMA,
		"turnos_na_condicao": 0
	},
	1: {
		"deck": [] as Array[CardResource],
		"mao": [] as Array[CardResource],
		"banco": [],   # Array[AnimalInstance]
		"zona_ativo": null, # Removido o cast inválido de null
		"pilha_descarte": [] as Array[CardResource],
		"pontos_comida": 0,
		"animais_nocauteados": 0,
		"condicao": Condicao.NENHUMA,
		"turnos_na_condicao": 0
	}
}

# -----------------------------------------------------------------------------
# FLUXO PRINCIPAL: INICIALIZAÇÃO E CONTROLE DE TURNOS
# -----------------------------------------------------------------------------

func avancar_fase() -> void:
	if not partida_ativa: return

	match fase_atual:
		Fase.COMPRAR:
			fase_atual = Fase.ALIMENTACAO
			_processar_fase_alimentacao()
		Fase.ALIMENTACAO:
			fase_atual = Fase.PRINCIPAL
		Fase.PRINCIPAL:
			fase_atual = Fase.ATAQUE
		Fase.ATAQUE:
			fase_atual = Fase.FIM
			_processar_fase_fim()


func alternar_turno() -> void:
	if not partida_ativa: return
	
	emit_signal("turno_encerrado", jogador_ativo)
	
	# Alterna o ponteiro do jogador
	jogador_ativo = 1 if jogador_ativo == 0 else 0
	fase_atual = Fase.COMPRAR
	energia_anexada_neste_turno = false
	if jogador_ativo == 0:
		turno_atual += 1
	
		
	print("GameState: Novo Turno iniciado! Turno: %d, Jogador Ativo: %d" % [turno_atual, jogador_ativo])
	var novo_ativo: AnimalInstance = jogadores[jogador_ativo]["zona_ativo"]
	if novo_ativo != null:
		novo_ativo.entrou_este_turno = false
		novo_ativo.evoluiu_este_turno = false
	
	_processar_fase_comprar()


# -----------------------------------------------------------------------------
# SISTEMAS INTERNOS DE REGRAS POR FASE
# -----------------------------------------------------------------------------

func _processar_fase_comprar() -> void:
	if _verificar_vitoria_deck_vazio(): return
	
	# Compra automática da fase de compra obrigatória
	var carta_comprada = _comprar_carta_silencioso(jogador_ativo)
	if carta_comprada:
		print("GameState: Jogador %d comprou: %s" % [jogador_ativo, carta_comprada.name])
		
	emit_signal("turno_iniciado", jogador_ativo)


func _processar_fase_alimentacao() -> void:
	# Distribui pontos de comida por turno para o jogador ativo
	jogadores[jogador_ativo]["pontos_comida"] += PONTOS_COMIDA_POR_TURNO
	emit_signal("alimentacao_distribuida", jogador_ativo)
	avancar_fase()


func _processar_fase_fim() -> void:
	_aplicar_danos_de_condicao()
	_atualizar_contadores_de_condicao()
	
	var ativo: AnimalInstance = jogadores[jogador_ativo]["zona_ativo"]
	if ativo != null:
		if ativo.current_food > 0:
			ativo.current_food -= 1
			print("GameState: %s consumiu 1 de comida. Restante: %d" % [ativo.card.name, ativo.current_food])
			alternar_turno()
		else:
			print("GameState: %s sem comida — Nocauteado por fome!" % ativo.card.name)
			_processar_nocaute_ativo(jogador_ativo)
			emit_signal("animal_nocauteado_por_fome", jogador_ativo)
			# alternar_turno() NÃO é chamado aqui
			# A mesa escuta o sinal e força o jogador a escolher um do banco
			# Só então a mesa chama alternar_turno() manualmente
	else:
		alternar_turno()
		
# -----------------------------------------------------------------------------
# SUB-ROTINAS DE SUPORTE E MANIPULAÇÃO DE RECURSOS
# -----------------------------------------------------------------------------
func _executar_compra_inicial() -> void:
	for i in range(7):
		_comprar_carta_silencioso(0)
		_comprar_carta_silencioso(1)
	_verificar_mulligan(0)
func _verificar_mulligan(jogador_id: int) -> void:
	var tem_filhote := false
	for carta in jogadores[jogador_id]["mao"]:
		if carta.super_type == "animal" and carta.stage == "Filhote":
			tem_filhote = true
			break

	if tem_filhote:
		# Passa para o próximo jogador ou para escolha do ativo
		if jogador_id == 0:
			_verificar_mulligan(1)
		else:
			_entregar_cartas_extras_mulligan()
	else:
		emit_signal("solicitar_mulligan", jogador_id)
			
func confirmar_mulligan(jogador_id: int) -> void:
	_mulligans_jogador[jogador_id] += 1
	print("GameState: Jogador %d fez mulligan #%d." % [jogador_id, _mulligans_jogador[jogador_id]])

	# Devolve a mão ao deck e reembaralha
	for carta in jogadores[jogador_id]["mao"]:
		jogadores[jogador_id]["deck"].append(carta)
	jogadores[jogador_id]["mao"].clear()
	jogadores[jogador_id]["deck"].shuffle()

	# Compra nova mão
	for i in range(7):
		_comprar_carta_silencioso(jogador_id)

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
	
func _comprar_carta_silencioso(jogador_id: int) -> CardResource:
	var j = jogadores[jogador_id]
	if j["deck"].is_empty(): return null
	
	# Remove do topo do deck e puxa a instância limpa e duplicada para a partida
	var carta: CardResource = j["deck"].pop_front()
	j["mao"].append(carta)
	return carta


func _aplicar_danos_de_condicao() -> void:
	var j = jogadores[jogador_ativo]
	var cond = j["condicao"]
	
	if DANO_CONDICAO.has(cond):
		var dano = DANO_CONDICAO[cond]
		print("GameState: Condição ativa prejudicando o Jogador %d em %d de dano." % [jogador_ativo, dano])
		aplicar_dano_ativo(jogador_ativo, dano)


func _atualizar_contadores_de_condicao() -> void:
	var j = jogadores[jogador_ativo]
	if j["condicao"] != Condicao.NENHUMA:
		j["turnos_na_condicao"] += 1
		
		# Mecânica de cura natural para Paralisia ou Sono no fim do turno
		if j["condicao"] == Condicao.ADORMECIDO or j["condicao"] == Condicao.PARALISADO:
			if lancar_moeda("Cura de Condição Natural"):
				_remover_condicao(jogador_ativo)


func _remover_condicao(jogador_id: int) -> void:
	jogadores[jogador_id]["condicao"] = Condicao.NENHUMA
	jogadores[jogador_id]["turnos_na_condicao"] = 0
	
func _validar_evolucao(instancia: AnimalInstance, carta_evolucao: CardResource) -> bool:
	if instancia.entrou_este_turno: return false
	if instancia.evoluiu_este_turno: return false

	# Valida grow_from contra o ID da carta atual
	if carta_evolucao.grow_from != instancia.card.id: return false

	# Valida cadeia de estágios permitidos
	var progressao_valida := {
		"filhote": ["jovem","adulto"],
		"jovem": ["adulto"],
	}
	var estagios_permitidos = progressao_valida.get(instancia.card.stage, [])
	if carta_evolucao.stage not in estagios_permitidos: return false

	# Valida comida mínima (metade do máximo, arredondando para cima)
	var minimo := ceili(instancia.card.food_points / 2.0)
	if instancia.current_food < minimo: return false

	return true

func _validar_anexar_energia(jogador_id: int, indice_na_mao: int) -> CardResource:
	if energia_anexada_neste_turno: return null
	var j = jogadores[jogador_id]
	if indice_na_mao < 0 or indice_na_mao >= j["mao"].size(): return null
	var carta: CardResource = j["mao"][indice_na_mao]
	if carta.super_type != "energia": return null
	return carta
# -----------------------------------------------------------------------------
# INTERFACE PÚBLICA DE AÇÕES DE JOGO (Chamado pela Mesa/Cartas Visuais)
# -----------------------------------------------------------------------------
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

func _iniciar_primeiro_turno() -> void:
	partida_ativa = true
	emit_signal("setup_concluido")
	print("GameState: Setup concluído. Primeiro turno do Jogador %d." % jogador_ativo)
	_processar_fase_comprar()

func jogar_animal_para_ativo(jogador_id: int, indice_na_mao: int) -> bool:
	var j = jogadores[jogador_id]
	if indice_na_mao < 0 or indice_na_mao >= j["mao"].size(): return false
	
	var carta: CardResource = j["mao"][indice_na_mao]
	if carta.super_type != "animal" or j["zona_ativo"] != null: return false
	
	# Move da mão para o campo de batalha ativo
	j["mao"].remove_at(indice_na_mao)
	var instancia = AnimalInstance.new(carta)
	j["zona_ativo"] = instancia
	print("GameState: Jogador %d moveu %s para Ativo!" % [jogador_id, carta.name])
	return true


func jogar_animal_para_banco(jogador_id: int, indice_na_mao: int) -> bool:
	var j = jogadores[jogador_id]
	if indice_na_mao < 0 or indice_na_mao >= j["mao"].size(): return false
	if j["banco"].size() >= MAX_BANCO_RESERVA: return false
	
	var carta: CardResource = j["mao"][indice_na_mao]
	if carta.super_type != "animal": return false
	
	j["mao"].remove_at(indice_na_mao)
	var instancia = AnimalInstance.new(carta)
	j["banco"].append(instancia)
	print("GameState: Jogador %d colocou %s na Reserva do Banco." % [jogador_id, carta.name])
	return true

func evoluir_animal_ativo(jogador_id: int, indice_na_mao: int) -> bool:
	var j = jogadores[jogador_id]
	var ativo: AnimalInstance = j["zona_ativo"]
	if ativo == null: return false

	if indice_na_mao < 0 or indice_na_mao >= j["mao"].size(): return false
	var carta_evolucao: CardResource = j["mao"][indice_na_mao]
	if carta_evolucao.super_type != "animal": return false

	if not _validar_evolucao(ativo, carta_evolucao): return false

	# Aplica a evolução mantendo o estado
	j["mao"].remove_at(indice_na_mao)
	j["pilha_descarte"].append(ativo.card)  # carta base vai pro descarte

	ativo.card = carta_evolucao
	var dano_acumulado := ativo.card.hp - ativo.current_hp
	ativo.current_hp = carta_evolucao.hp - dano_acumulado   
	ativo.evoluiu_este_turno = true
	# current_food, attached_energies e conditions são preservados

	print("GameState: Jogador %d evoluiu para %s!" % [jogador_id, carta_evolucao.name])
	emit_signal("animal_evoluido", jogador_id, ativo)
	return true

func anexar_energia_no_ativo(jogador_id: int, indice_na_mao: int) -> bool:
	var j = jogadores[jogador_id]
	var ativo: AnimalInstance = j["zona_ativo"]
	if ativo == null: return false
	var carta := _validar_anexar_energia(jogador_id, indice_na_mao)
	if carta == null: return false
	j["mao"].remove_at(indice_na_mao)
	ativo.attached_energies.append(carta)
	energia_anexada_neste_turno = true
	print("GameState: Jogador %d anexou %s em %s." % [jogador_id, carta.mec_filter_color, ativo.card.name])
	emit_signal("energia_anexada", jogador_id, ativo, carta)
	return true


func anexar_energia_no_banco(jogador_id: int, indice_na_mao: int, indice_no_banco: int) -> bool:
	var j = jogadores[jogador_id]
	if indice_no_banco < 0 or indice_no_banco >= j["banco"].size(): return false
	var alvo: AnimalInstance = j["banco"][indice_no_banco]
	var carta := _validar_anexar_energia(jogador_id, indice_na_mao)
	if carta == null: return false
	j["mao"].remove_at(indice_na_mao)
	alvo.attached_energies.append(carta)
	energia_anexada_neste_turno = true
	print("GameState: Jogador %d anexou %s em %s (banco)." % [jogador_id, carta.mec_filter_color, alvo.card.name])
	emit_signal("energia_anexada", jogador_id, alvo, carta)
	return true
	
func pode_atacar(jogador_id: int) -> bool:
	var ativo: AnimalInstance = jogadores[jogador_id]["zona_ativo"]
	if ativo == null: return false
	if ativo.card.attack_cost == "": return true  # sem custo
	var custo := _parsear_custo(ativo.card.attack_cost)
	return ativo.tem_energias_suficientes(custo)

func declarar_ataque(jogador_id: int, dano: int) -> bool:
	if not pode_atacar(jogador_id): return false
	var oponente_id := 1 if jogador_id == 0 else 0
	aplicar_dano_ativo(oponente_id, dano)
	print("GameState: Jogador %d atacou por %d de dano!" % [jogador_id, dano])
	emit_signal("ataque_declarado", jogador_id, dano)
	return true
	
func pode_recuar(jogador_id: int) -> bool:
	var j = jogadores[jogador_id]
	var ativo: AnimalInstance = j["zona_ativo"]
	if ativo == null: return false
	if j["banco"].is_empty(): return false  # sem animal para trocar
	if ativo.card.cost_retreat == 0: return true  # recuo gratuito
	var total_disponivel := ativo.attached_energies.size() + ativo.current_food
	return total_disponivel >= ativo.card.cost_retreat

func executar_recuo(jogador_id: int, indice_do_banco: int, indices_energias: Array, quantidade_comida: int) -> bool:
	var j = jogadores[jogador_id]
	var ativo: AnimalInstance = j["zona_ativo"]
	if ativo == null: return false
	if j["banco"].is_empty(): return false
	if indice_do_banco < 0 or indice_do_banco >= j["banco"].size(): return false

	# Recuo gratuito — troca direta
	if ativo.card.cost_retreat == 0:
		_trocar_ativo_com_banco(jogador_id, indice_do_banco)
		emit_signal("recuo_executado", jogador_id)
		return true

	# Valida se a combinação escolhida atinge exatamente o custo
	var total_pago := indices_energias.size() + quantidade_comida
	if total_pago != ativo.card.cost_retreat: return false

	# Valida índices de energia
	for idx in indices_energias:
		if idx < 0 or idx >= ativo.attached_energies.size(): return false

	# Valida comida disponível
	if ativo.current_food < quantidade_comida: return false

	# Paga energias em ordem reversa para não deslocar índices
	indices_energias.sort()
	indices_energias.reverse()
	for idx in indices_energias:
		j["pilha_descarte"].append(ativo.attached_energies[idx])
		ativo.attached_energies.remove_at(idx)

	# Paga comida
	ativo.current_food -= quantidade_comida

	_trocar_ativo_com_banco(jogador_id, indice_do_banco)
	emit_signal("recuo_executado", jogador_id)
	return true
	
func aplicar_dano_ativo(jogador_id: int, quantidade: int) -> void:
	var ativo = jogadores[jogador_id]["zona_ativo"]
	if ativo == null: return
	
	var ativo_inst = ativo as AnimalInstance
	ativo_inst.current_hp -= quantidade
	print("GameState: Ativo do Jogador %d sofreu %d de dano. HP Restante: %d" % [jogador_id, quantidade, ativo_inst.hp])
	
	if ativo_inst.current_hp <= 0:
		_processar_nocaute_ativo(jogador_id)


func _processar_nocaute_ativo(jogador_id: int) -> void:
	var ativo = jogadores[jogador_id]["zona_ativo"]
	if ativo == null: return
	
	var ativo_inst = ativo as AnimalInstance
	jogadores[jogador_id]["zona_ativo"] = null
	jogadores[jogador_id]["pilha_descarte"].append(ativo_inst.card)
	
	# Descarta todas as energias anexadas
	for energia in ativo_inst.attached_energies:
		jogadores[jogador_id]["pilha_descarte"].append(energia)
	ativo_inst.attached_energies.clear()

	# Ponto de nocaute dado ao adversário
	var oponente_id = 1 if jogador_id == 0 else 0
	jogadores[oponente_id]["animais_nocauteados"] += 1
	
	print("GameState: %s foi Nocauteado!" % ativo_inst.card.name)
	emit_signal("animal_nocauteado", jogador_id, ativo_inst)
	if jogadores[jogador_id]["banco"].is_empty():
		_declarar_vitoria(1 if jogador_id == 0 else 0)
	else:
		_verificar_vitoria()


func aplicar_condicao_ativo(jogador_id: int, nova_condicao: Condicao) -> void:
	if jogadores[jogador_id]["zona_ativo"] == null: return
	
	jogadores[jogador_id]["condicao"] = nova_condicao
	jogadores[jogador_id]["turnos_na_condicao"] = 0
	emit_signal("condicao_aplicada", jogador_id, int(nova_condicao))
	print("GameState: Condição especial aplicada ao Jogador %d: %s" % [jogador_id, Condicao.keys()[nova_condicao]])


func usar_pontos_comida(jogador_id: int, quantidade: int) -> bool:
	var j = jogadores[jogador_id]
	if j["pontos_comida"] < quantidade: return false
	var ativo: AnimalInstance = j["zona_ativo"]
	if ativo == null: return false
	if ativo.current_food >= ativo.card.food_points: return false #já e o maximo
	j["pontos_comida"] -= quantidade
	ativo.current_food = min(ativo.current_food + quantidade, ativo.card.food_points) # não ultrapassa o máximo
	print("GameState: Jogador %d alimentou %s com %d. Comida do dino: %d" % [jogador_id, ativo.card.name, quantidade, ativo.current_food])
	return true


func lancar_moeda(motivo_acao: String) -> bool:
	var resultado = randf() >= 0.5
	emit_signal("moeda_lancada", motivo_acao, resultado)
	print("GameState: Lançamento de Moeda (%s) -> Resultado: %s" % [motivo_acao, "CARA" if resultado else "COROA"])
	return resultado

func _trocar_ativo_com_banco(jogador_id: int, indice_do_banco: int) -> void:
	var j = jogadores[jogador_id]
	var saindo: AnimalInstance = j["zona_ativo"]
	var entrando: AnimalInstance = j["banco"][indice_do_banco]

	# Troca as posições
	j["banco"][indice_do_banco] = saindo
	j["zona_ativo"] = entrando

	# Animal que entrou no ativo NÃO recebe entrou_este_turno = true (regra do recuo)
	print("GameState: Jogador %d trocou %s por %s via recuo." % [jogador_id, saindo.card.name, entrando.card.name])

func confirmar_lancamento_moeda() -> void:
	var resultado := lancar_moeda("Sorteio do Primeiro Jogador")
	jogador_ativo = 0 if resultado else 1
	print("GameState: Jogador %d vai jogar primeiro." % jogador_ativo)
	_executar_compra_inicial()


# -----------------------------------------------------------------------------
# VERIFICADORES DE VITÓRIA E GETTERS DE CONSULTA
# -----------------------------------------------------------------------------

func _verificar_vitoria() -> void:
	var j0 = jogadores[0]
	var j1 = jogadores[1]

	var v0 = j0["animais_nocauteados"] >= ANIMAIS_PARA_VENCER
	var v1 = j1["animais_nocauteados"] >= ANIMAIS_PARA_VENCER

	if v0 and v1:
		partida_ativa = false
		emit_signal("empate")
	elif v0:
		_declarar_vitoria(0)
	elif v1:
		_declarar_vitoria(1)


func _verificar_vitoria_deck_vazio() -> bool:
	var j0_vazio = jogadores[0]["deck"].is_empty()
	var j1_vazio = jogadores[1]["deck"].is_empty()

	if j0_vazio and j1_vazio:
		partida_ativa = false
		emit_signal("empate")
		return true
	elif j0_vazio:
		_declarar_vitoria(1)
		return true
	elif j1_vazio:
		_declarar_vitoria(0)
		return true
	return false


func _declarar_vitoria(ganhador_id: int) -> void:
	partida_ativa = false
	print("GameState: FIM DE JOGO! Vitória esmagadora do Jogador %d!" % ganhador_id)
	emit_signal("vitoria", ganhador_id)


func obter_dados_jogador(jogador_id: int) -> Dictionary:
	return jogadores.get(jogador_id, {})
# =============================================================================
# CONTROLE DE TRANSIÇÃO DE ARQUIVOS PARA O DECK BUILDER
# =============================================================================

## Armazena temporariamente o dicionário do deck vindo do Gerenciador de Decks
var _deck_temporario_edicao: Dictionary = {}

## Chamado pelo gerenciador_decks.gd para definir qual deck abrir no construtor
func definir_deck_em_edicao(dados_deck: Dictionary) -> void:
	_deck_temporario_edicao = dados_deck

## Chamado pelo deck_builder.gd para pegar os dados armazenados e limpar a memória
func consumir_deck_em_edicao() -> Dictionary:
	var dados = _deck_temporario_edicao.duplicate(true)
	_deck_temporario_edicao.clear() # Limpa para não prender dados na memória
	return dados
# =============================================================================
# PARSEADORES E NORMALIZADORES
# =============================================================================

func _parsear_custo(custo_string: String) -> Dictionary:
	var resultado := {}
	# Itera por caractere unicode (emojis ocupam múltiplos bytes)
	for emoji in EMOJI_COR.keys():
		var count := 0
		var temp := custo_string
		while emoji in temp:
			count += 1
			temp = temp.substr(temp.find(emoji) + emoji.length())
		if count > 0:
			resultado[EMOJI_COR[emoji]] = count
	return resultado
