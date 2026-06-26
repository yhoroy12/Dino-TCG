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
signal animal_nocauteado(jogador_id: int, carta: CardResource)
signal condicao_aplicada(jogador_id: int, condicao: int)
signal vitoria(jogador_id: int)
signal empate()
signal alimentacao_distribuida(jogador_id: int)
signal moeda_lancada(acao: String, resultado: bool)

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

# -----------------------------------------------------------------------------
# ESTADO CÉLULA DA PARTIDA ATIVA
# -----------------------------------------------------------------------------
enum Fase { COMPRAR, ALIMENTACAO, PRINCIPAL, ATAQUE, FIM }

var partida_ativa: bool = false
var turno_atual: int    = TURNO_INICIAL
var jogador_ativo: int  = 0 # 0 = Jogador Humano, 1 = Oponente/IA
var fase_atual: Fase    = Fase.COMPRAR

# Dicionário de Estado dos Jogadores - Correção dos casts de Array e do valor Null
var jogadores: Dictionary = {
	0: {
		"deck": [] as Array[CardResource],
		"mao": [] as Array[CardResource],
		"banco": [] as Array[CardResource],
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
		"banco": [] as Array[CardResource],
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

func inicializar_partida(nome_deck_j0: String, nome_deck_j1: String) -> void:
	partida_ativa = true
	turno_atual = TURNO_INICIAL
	fase_atual = Fase.COMPRAR
	jogador_ativo = 0
	
	# Reinicia estruturas básicas - Correção dos inicializadores de Array e Null
	jogadores = {
		0: {
			"deck": DeckManager.carregar_deck_para_partida(nome_deck_j0),
			"mao": [] as Array[CardResource],
			"banco": [] as Array[CardResource],
			"zona_ativo": null, # Removido o cast inválido de null
			"pilha_descarte": [] as Array[CardResource],
			"pontos_comida": 0,
			"animais_nocauteados": 0,
			"condicao": Condicao.NENHUMA,
			"turnos_na_condicao": 0
		},
		1: {
			"deck": DeckManager.carregar_deck_para_partida(nome_deck_j1),
			"mao": [] as Array[CardResource],
			"banco": [] as Array[CardResource],
			"zona_ativo": null, # Removido o cast inválido de null
			"pilha_descarte": [] as Array[CardResource],
			"pontos_comida": 0,
			"animais_nocauteados": 0,
			"condicao": Condicao.NENHUMA,
			"turnos_na_condicao": 0
		}
	}
	
	jogadores[0]["deck"].shuffle()
	jogadores[1]["deck"].shuffle()
	
	# Compra a mão inicial clássica de 7 cartas
	for i in range(7):
		_comprar_carta_silencioso(0)
		_comprar_carta_silencioso(1)
		
	emit_signal("turno_iniciado", jogador_ativo)


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
	
	if jogador_ativo == 0:
		turno_atual += 1
		
	print("GameState: Novo Turno iniciado! Turno: %d, Jogador Ativo: %d" % [turno_atual, jogador_ativo])
	
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
	alternar_turno()

# -----------------------------------------------------------------------------
# SUB-ROTINAS DE SUPORTE E MANIPULAÇÃO DE RECURSOS
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# INTERFACE PÚBLICA DE AÇÕES DE JOGO (Chamado pela Mesa/Cartas Visuais)
# -----------------------------------------------------------------------------

func jogar_animal_para_ativo(jogador_id: int, indice_na_mao: int) -> bool:
	var j = jogadores[jogador_id]
	if indice_na_mao < 0 or indice_na_mao >= j["mao"].size(): return false
	
	var carta: CardResource = j["mao"][indice_na_mao]
	if carta.super_type != "animal" or j["zona_ativo"] != null: return false
	
	# Move da mão para o campo de batalha ativo
	j["mao"].remove_at(indice_na_mao)
	j["zona_ativo"] = carta
	print("GameState: Jogador %d moveu %s para Ativo!" % [jogador_id, carta.name])
	return true


func jogar_animal_para_banco(jogador_id: int, indice_na_mao: int) -> bool:
	var j = jogadores[jogador_id]
	if indice_na_mao < 0 or indice_na_mao >= j["mao"].size(): return false
	if j["banco"].size() >= MAX_BANCO_RESERVA: return false
	
	var carta: CardResource = j["mao"][indice_na_mao]
	if carta.super_type != "animal": return false
	
	j["mao"].remove_at(indice_na_mao)
	j["banco"].append(carta)
	print("GameState: Jogador %d colocou %s na Reserva do Banco." % [jogador_id, carta.name])
	return true


func aplicar_dano_ativo(jogador_id: int, quantidade: int) -> void:
	var ativo = jogadores[jogador_id]["zona_ativo"]
	if ativo == null: return
	
	var ativo_res = ativo as CardResource
	ativo_res.hp -= quantidade
	print("GameState: Ativo do Jogador %d sofreu %d de dano. HP Restante: %d" % [jogador_id, quantidade, ativo_res.hp])
	
	if ativo_res.hp <= 0:
		_processar_nocaute_ativo(jogador_id)


func _processar_nocaute_ativo(jogador_id: int) -> void:
	var ativo = jogadores[jogador_id]["zona_ativo"]
	if ativo == null: return
	
	var ativo_res = ativo as CardResource
	jogadores[jogador_id]["zona_ativo"] = null
	jogadores[jogador_id]["pilha_descarte"].append(ativo_res)
	
	# Ponto de nocaute dado ao adversário
	var oponente_id = 1 if jogador_id == 0 else 0
	jogadores[oponente_id]["animais_nocauteados"] += 1
	
	print("GameState: %s foi Nocauteado!" % ativo_res.name)
	emit_signal("animal_nocauteado", jogador_id, ativo_res)
	_verificar_vitoria()


func aplicar_condicao_ativo(jogador_id: int, nova_condicao: Condicao) -> void:
	if jogadores[jogador_id]["zona_ativo"] == null: return
	
	jogadores[jogador_id]["condicao"] = nova_condicao
	jogadores[jogador_id]["turnos_na_condicao"] = 0
	emit_signal("condicao_aplicada", jogador_id, int(nova_condicao))
	print("GameState: Condição especial aplicada ao Jogador %d: %s" % [jogador_id, Condicao.keys()[nova_condicao]])


func usar_pontos_comida(jogador_id: int, quantidade: int) -> bool:
	if jogadores[jogador_id]["pontos_comida"] >= quantidade:
		jogadores[jogador_id]["pontos_comida"] -= quantidade
		return true
	return false


func lancar_moeda(motivo_acao: String) -> bool:
	var resultado = randf() >= 0.5
	emit_signal("moeda_lancada", motivo_acao, resultado)
	print("GameState: Lançamento de Moeda (%s) -> Resultado: %s" % [motivo_acao, "CARA" if resultado else "COROA"])
	return resultado

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
