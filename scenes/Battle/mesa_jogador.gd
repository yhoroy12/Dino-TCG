# ==============================================================================
# MesaDoTabuleiro — Camada de Renderização e Interface (UI)
# Renderiza o estado do jogo, gerencia interações do jogador e anima transições.
# NUNCA calcula regras — apenas reage a sinais dos managers (SetupManager,
# TurnManager) e lê estado de GameState/PlayerState.
#
# Ações do jogador que exigem validação de regra (jogar carta, atacar, usar
# habilidade, recuar) NÃO são executadas aqui. A UI apenas emite
# `acao_jogador_solicitada` — quem decide se a ação é válida e a aplica é o
# BattleManager.
#
# Requer os seguintes autoloads: GameState, PlayerState (classe, não autoload),
# SetupManager, TurnManager, MatchData, RuleValidator, ConditionSystem.
# ==============================================================================
extends Control

# ==============================================================================
# SINAIS CUSTOMIZADOS
# ==============================================================================
signal acao_jogador_solicitada(tipo_acao: String, dados: Dictionary)
signal turno_visual_atualizado(info_turno: Dictionary)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const DURACAO_ANIMACAO_CARTA: float = 0.3
const DURACAO_ANIMACAO_MOEDA: float = 1.5

# Tamanhos dos slots, copiados do MesaJogador.tscn — usados pra
# escalar as cartas (nascem em 150x233, maiores que qualquer slot daqui).
const TAMANHO_SLOT_ATIVO: Vector2 = Vector2(128, 179)
const TAMANHO_SLOT_BANCO: Vector2 = Vector2(100, 145)
const ALTURA_MAO: float = 133.0

# ID fixo do jogador humano nesta cena.
const ID_JOGADOR_HUMANO := 0

# ==============================================================================
# REFERÊNCIAS DE NÓS (@onready)
# ==============================================================================

# Lado do Jogador Humano (ID 0)
@onready var jogador_campo_ativo: Panel = $MesaContainer/LadoJogador/JogadorFlow/CombatRow/CampoAtivo
@onready var jogador_contador_comida: Panel = $MesaContainer/LadoJogador/JogadorFlow/CombatRow/ContadorComida
@onready var jogador_condicao_especial: Panel = $MesaContainer/LadoJogador/JogadorFlow/CombatRow/CondicaoEspecial
@onready var jogador_zona_descarte: Panel = $MesaContainer/LadoJogador/JogadorFlow/BoardRow/ZonaDescarte
@onready var jogador_slots_banco: HBoxContainer = $MesaContainer/LadoJogador/JogadorFlow/BoardRow/BenchContainer
@onready var jogador_zona_deck: Panel = $MesaContainer/LadoJogador/JogadorFlow/BoardRow/ZonaDeck
@onready var jogador_mao: HBoxContainer = $MesaContainer/LadoJogador/JogadorFlow/HandContainer

# Lado do Oponente (ID 1)
@onready var oponente_campo_ativo: Panel = $MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/CombatRow/CampoAtivo
@onready var oponente_contador_comida: Panel = $MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/CombatRow/ContadorComida
@onready var oponente_condicao_especial: Panel = $MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/CombatRow/CondicaoEspecial
@onready var oponente_zona_descarte: Panel = $MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/BoardRow/ZonaDescarte
@onready var oponente_slots_banco: HBoxContainer = $MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/BoardRow/BenchContainer
@onready var oponente_zona_deck: Panel = $MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/BoardRow/ZonaDeck
@onready var oponente_mao: HBoxContainer = $MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/HandContainer

# Componentes Compartilhados
@onready var botao_passar_turno: Button = $Button
@onready var timer_turno: Timer = $TimerTurno
@onready var progresso_turno: TextureProgressBar = $Progessbar
@onready var painel_zoom: CardPreviewPanel = $zoom_slot

# ==============================================================================
# VARIÁVEIS INTERNAS
# ==============================================================================

# Estado visual do turno
var tempo_restante_turno: float = 0.0
var turno_em_progresso: bool = false
var jogador_ativo_id: int = -1

# Setup: enquanto != -1, indica que estamos esperando ESSE jogador clicar
# numa carta da própria mão para escolher o Animal Ativo inicial.
var _jogador_aguardando_escolha_ativo: int = -1

# true enquanto o setup não termina. Usado só pra saber se o Animal
# Ativo inicial deve nascer virado pra baixo.
var _setup_em_andamento: bool = true

# Controle de seleção de alvo (Crescer, Fortalecer, Retroceder, Alimentar)
var _selecao_alvo_ativa: bool = false
var _selecao_alvo_tipo: String = ""       # "crescer" | "fortalecer" | "retroceder" | "alimentar"
var _selecao_alvo_dados: Dictionary = {}  # dados extra da ação
var _callback_alvo_pendente: Callable = Callable()

# Animações
var dicionario_tweens_cartas: Dictionary = {}  # { CardUI: Tween }

# Sistema de zoom e menus
var card_zoom_manager: Control = null
var menu_contextual_ativo: Control = null

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================

func _ready() -> void:
	print("[MesaUI] Iniciando ciclo _ready()...")
	_validar_referencias()
	_conectar_sinais_setup_manager()
	_conectar_sinais_turn_manager()
	_conectar_sinais_battle_manager()
	_configurar_interface_inicial()

	# Agente do jogador humano — sempre Jogador 0 nesta cena.
	BattleManager.registrar_agente(ID_JOGADOR_HUMANO, HumanAgent.new(ID_JOGADOR_HUMANO, self))

	# 1. Instancia o Cérebro da IA se a partida for Modo Treino / Vs IA
	_configurar_ia_se_necessario()

	print("[MesaUI] ✓ MesaDoTabuleiro inicializada com sucesso")

	SetupManager.iniciar_partida(MatchData.deck_pendente_j0, MatchData.deck_pendente_j1)
	MatchData.limpar()
	
func _configurar_ia_se_necessario() -> void:
	if MatchData.adversario_ia_id != "":
		var adversario: String = MatchData.adversario_ia_id
		var dificuldade: String = MatchData.dificuldade_ia

		if adversario == "Trike" and dificuldade == "Facil":
			var ai_brain := AIController.new()
			ai_brain.name = "AIBrain_Trike_Facil"
			add_child(ai_brain)
			ai_brain.inicializar(BattleManager)

			# Agente responsável só pela decisão de promoção por enquanto
			# (Etapa 1 da migração) — o resto das decisões da IA continua
			# no AIController até a Etapa 2/3.
			BattleManager.registrar_agente(1, AIAgent.new(1, get_tree(), ai_brain.tempo_entre_acoes))

			print("[MesaUI] 🤖 IA Trike (Fácil) inicializada com sucesso!")
			
func _process(delta: float) -> void:
	if turno_em_progresso:
		_atualizar_contador_turno(delta)

func _input(event: InputEvent) -> void:
	if not get_tree().root.is_ancestor_of(self):
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		print("[MesaUI] Tecla ESC pressionada. Cancelando seleções e menus.")
		_cancelar_selecao_alvo()
		_fechar_menu_contextual()
		_fechar_popups_abertos()
		get_tree().root.set_input_as_handled()

func _fechar_popups_abertos() -> void:
	for child in get_children():
		if child is PopupSelecaoCartas or child is PopupDescarteEnergia or child is PopupSelecaoAnimal:
			if child.has_signal("cancelado"):
				child.cancelado.emit()  # desbloqueia o await pendente no BattleManager antes de fechar
			child.fechar()
		elif child is PopupAlimentar or child is PopupRecuo or child is PopupPromocao:
			child.fechar()  # esses não bloqueiam await nenhum, fechar direto é seguro

# ==============================================================================
# VALIDAÇÃO E CONEXÃO DE SINAIS
# ==============================================================================
#Valida as referencias.
func _validar_referencias() -> void:
	var nos_para_validar: Dictionary = {
		"botao_passar_turno": botao_passar_turno,
		"timer_turno": timer_turno,
		"progresso_turno": progresso_turno,
		"jogador_campo_ativo": jogador_campo_ativo,
		"oponente_campo_ativo": oponente_campo_ativo
	}

	for nome_no in nos_para_validar:
		if nos_para_validar[nome_no] == null:
			push_error("❌ ERRO CRÍTICO: Nó @onready não encontrado -> %s" % nome_no)

	card_zoom_manager = get_tree().root.find_child("CardZoomManager", true, false)
	if card_zoom_manager == null:
		push_warning("⚠️ CardZoomManager não foi encontrado na árvore de nós.")
# Conecta aos sinais que sao emitidos pelo SetupManager
func _conectar_sinais_setup_manager() -> void:
	if not SetupManager:
		push_error("❌ SetupManager (Autoload) não está disponível!")
		return

	_conectar_sinal_seguro(SetupManager.solicitar_lancamento_moeda, _ao_solicitar_lancamento_moeda)
	_conectar_sinal_seguro(SetupManager.sorteio_realizado, _ao_sorteio_realizado)
	_conectar_sinal_seguro(SetupManager.solicitar_escolha_ordem, _ao_solicitar_escolha_ordem)
	_conectar_sinal_seguro(SetupManager.mulligan_necessario, _ao_mulligan_necessario)
	_conectar_sinal_seguro(SetupManager.mulligan_realizado, _ao_mulligan_realizado)
	_conectar_sinal_seguro(SetupManager.solicitar_escolha_ativo, _ao_solicitar_escolha_ativo)
	_conectar_sinal_seguro(SetupManager.setup_concluido, _ao_setup_concluido)
# Conecta aos sinais que sao emitidos pelo TurnManager
func _conectar_sinais_turn_manager() -> void:
	if not TurnManager:
		push_error("❌ TurnManager (Autoload) não está disponível!")
		return

	_conectar_sinal_seguro(TurnManager.turno_iniciado, _ao_turno_iniciado)
	_conectar_sinal_seguro(TurnManager.turno_encerrado, _ao_turno_encerrado)
	_conectar_sinal_seguro(TurnManager.partida_encerrada, _ao_partida_encerrada)

	

	if botao_passar_turno:
		_conectar_sinal_seguro(botao_passar_turno.pressed, _ao_botao_passar_turno_pressionado)

	if timer_turno:
		_conectar_sinal_seguro(timer_turno.timeout, _ao_timer_turno_expirado)
# Conecta aos sinais que sao emitidos pelo BattleManager
func _conectar_sinais_battle_manager() -> void:
	if not BattleManager:
		push_error("❌ BattleManager (Autoload) não está disponível!")
		return

	_conectar_sinal_seguro(BattleManager.acao_resolvida, _ao_acao_resolvida)
	
	_conectar_sinal_seguro(BattleManager.solicitacao_selecao_animal, _ao_solicitacao_selecao_animal)
# Conecta aos sinais que sao emitidos pelo Gamestate
func _conectar_sinais_gamestate() -> void:
	pass
#Configurações iniciais da Interface
func _configurar_interface_inicial() -> void:
	if botao_passar_turno:
		botao_passar_turno.disabled = true
	if progresso_turno:
		progresso_turno.value = 0
		
	turno_em_progresso = false
	tempo_restante_turno = 0.0
#Segurança para a configuração dos sinais
func _conectar_sinal_seguro(sinal: Signal, metodo: Callable) -> void:
	if not sinal.is_connected(metodo):
		sinal.connect(metodo)

# ==============================================================================
# CALLBACKS — SETUP DA PARTIDA (SetupManager)
# ==============================================================================

func _ao_solicitar_lancamento_moeda() -> void:
	var popup := CoinFlipPanel.new()
	add_child(popup)
	popup.moeda_lancada.connect(func(): SetupManager.lancar_moeda())
	popup.exibir_sorteio_moeda(self)

func _ao_sorteio_realizado(vencedor_id: int) -> void:
	print("[Setup] 🪙 Sorteio realizado! Vencedor: Jogador %d." % vencedor_id)

func _ao_solicitar_escolha_ordem(vencedor_id: int) -> void:
	print("[Setup] Solicitando escolha de ordem. Vencedor do sorteio: %d" % vencedor_id)
	var popup := CoinFlipPanel.new()
	add_child(popup)
	
	if vencedor_id == ID_JOGADOR_HUMANO:
		popup.ordem_escolhida.connect(func(quer_jogar_primeiro: bool):
			SetupManager.confirmar_escolha_ordem(vencedor_id, quer_jogar_primeiro)
		)
		popup.exibir_escolha_ordem(self)
	else:
		popup.exibir_resultado_derrota(self, vencedor_id)
		SetupManager.confirmar_escolha_ordem(vencedor_id, true)

func _ao_mulligan_necessario(jogador_id: int) -> void:
	print("[Setup] Mulligan necessário para Jogador %d." % jogador_id)
	if jogador_id != ID_JOGADOR_HUMANO:
		SetupManager.confirmar_mulligan(jogador_id)
		return

	var popup := MulliganPanel.new()
	add_child(popup)
	popup.mulligan_confirmado.connect(func(id: int):
		SetupManager.confirmar_mulligan(id)
	)
	popup.exibir(self, jogador_id)

func _ao_mulligan_realizado(jogador_id: int, quantidade: int) -> void:
	print("[Setup] 🔀 Jogador %d concluiu mulligan (Total acumulado: %d)." % [jogador_id, quantidade])

func _ao_solicitar_escolha_ativo(jogador_id: int) -> void:
	print("[Setup] 🦖 Aguardando escolha de Animal Ativo inicial do Jogador %d." % jogador_id)
	if jogador_id == ID_JOGADOR_HUMANO:
		_jogador_aguardando_escolha_ativo = jogador_id
		organizar_cartas_nas_zonas(jogador_id)
		_exibir_texto_flutuante("Selecione um Animal Ativo", 2.0)
	else:
		_auto_escolher_ativo_oponente(jogador_id)

func _auto_escolher_ativo_oponente(jogador_id: int) -> void:
	var jogador := _obter_player_state(jogador_id)
	var idx_filhote: int = jogador.obter_indice_primeiro_filhote() if jogador.has_method("obter_indice_primeiro_filhote") else _buscar_primeiro_filhote_fallback(jogador)

	if idx_filhote != -1:
		print("[Setup] Oponente auto-selecionou o filhote no índice: %d" % idx_filhote)
		SetupManager.confirmar_animal_ativo(jogador_id, idx_filhote)
	else:
		push_error("❌ Oponente (Jogador %d) não tem Filhote na mão!" % jogador_id)

func _buscar_primeiro_filhote_fallback(jogador: Object) -> int:
	for i in jogador.mao.size():
		var carta = jogador.mao[i]
		if carta is CardResource and carta.super_type == "animal" and carta.stage == "Filhote":
			return i
	return -1

func _ao_setup_concluido() -> void:
	print("[Setup] ✅ Setup concluído! Revelando cartas e iniciando o jogo.")
	_setup_em_andamento = false

	organizar_cartas_nas_zonas(0)
	organizar_cartas_nas_zonas(1)
	atualizar_visual_comida(0)
	atualizar_visual_comida(1)
	atualizar_visual_deck(0, _obter_player_state(0).deck.size())
	atualizar_visual_deck(1, _obter_player_state(1).deck.size())
# ==============================================================================
# CALLBACKS — TURNOS E FASES (TurnManager)
# ==============================================================================

func _ao_turno_iniciado(jogador_id: int) -> void:
	jogador_ativo_id = jogador_id
	turno_em_progresso = true
	tempo_restante_turno = timer_turno.wait_time

	botao_passar_turno.disabled = (jogador_id != ID_JOGADOR_HUMANO)

	if timer_turno.is_stopped():
		timer_turno.start()

	atualizar_visual_comida(0)
	atualizar_visual_comida(1)
	organizar_cartas_nas_zonas(0)
	organizar_cartas_nas_zonas(1)

	print("🟢 Turno iniciado! Jogador Ativo: %d | Tempo: %.1fs" % [jogador_id, tempo_restante_turno])

	turno_visual_atualizado.emit({
		"jogador_id": jogador_id,
		"fase": GameState.fase_atual,
		"turno_numero": GameState.turno_atual
	})

func _ao_turno_encerrado(jogador_id: int) -> void:
	turno_em_progresso = false
	timer_turno.stop()
	botao_passar_turno.disabled = true

	print("🔴 Turno encerrado! Jogador: %d" % jogador_id)

func _atualizar_contador_turno(delta: float) -> void:
	if not turno_em_progresso:
		return

	tempo_restante_turno = maxf(tempo_restante_turno - delta, 0.0)
	progresso_turno.value = (1.0 - (tempo_restante_turno / timer_turno.wait_time)) * 100

func _ao_timer_turno_expirado() -> void:
	if jogador_ativo_id == ID_JOGADOR_HUMANO:
		print("⚠️ [MesaUI] Tempo do turno expirado! Forçando avanço de turno...")
		TurnManager.fase_final()

func _ao_botao_passar_turno_pressionado() -> void:
	print("🚨 [MesaUI] BOTÃO PASSAR TURNO PRESSIONADO! (Jogador Ativo: %d)" % jogador_ativo_id)
	
	if jogador_ativo_id != ID_JOGADOR_HUMANO:
		print("⚠️ [MesaUI] Bloqueado: Não é o seu turno!")
		return

	print("➡️ [MesaUI] Solicitando TurnManager.fase_final()...")
	TurnManager.fase_final()

# ==============================================================================
# CALLBACKS — BATALHA (BattleManager)
# ==============================================================================
func _ao_acao_resolvida(tipo_acao: String, sucesso: bool, motivo: String, dados: Dictionary) -> void:
	# Atualiza a tela sempre que uma ação terminar, substituindo o antigo sinal 'turno_visual_atualizado'
	_refrescar_tabuleiro()
	if not sucesso:
		_exibir_texto_flutuante(_traduzir_motivo_falha(motivo), 1.5)

func _ao_solicitacao_selecao_animal(id_solicitacao: int, jogador_id: int, animais_elegiveis: Array, quantidade: int, contexto: String) -> void:
	if jogador_id != ID_JOGADOR_HUMANO:
		return # IA decide sozinha depois

	var animais_tipados: Array[AnimalInstance] = []
	animais_tipados.assign(animais_elegiveis)

	var popup := PopupSelecaoAnimal.new()
	add_child(popup)
	popup.animais_selecionados.connect(func(escolhidos: Array[AnimalInstance]):
		BattleManager.confirmar_selecao_ui(id_solicitacao, {"animais_selecionados": escolhidos})
	)
	popup.cancelado.connect(func():
		BattleManager.confirmar_selecao_ui(id_solicitacao, {"animais_selecionados": []})
	)
	popup.exibir(self, "Seleção", "Escolha %d animal(is):" % quantidade, animais_tipados, quantidade)

# ==============================================================================
# CALLBACKS — Atualização das zonas (GameState)
# ==============================================================================


# ==============================================================================
# MÉTODOS VISUAIS DE SUPORTE
# ==============================================================================

func atualizar_visual_condicao(jogador_id: int) -> void:
	var ativo := GameState.obter_ativo(jogador_id)
	if ativo == null:
		return

	var tipo: ConditionSystem.Tipo = ConditionSystem.obter_condicao(ativo)
	_renderizar_condicao(jogador_id, tipo)

func atualizar_visual_comida(jogador_id: int) -> void:
	var jogador := _obter_player_state(jogador_id)
	_atualizar_visual_contador_comida(jogador_id, jogador.comida_disponivel)

func animar_animal_nocauteado(jogador_id: int, instancia: AnimalInstance) -> void:
	print("💥 [MesaUI] Animando Animal Nocauteado: %s (Jogador %d)" % [instancia.card.name, jogador_id])

	var campo_origem: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
	var zona_descarte: Panel = jogador_zona_descarte if jogador_id == 0 else oponente_zona_descarte

	var grupo_ativo := campo_origem.get_node_or_null("GrupoAtivo")
	if grupo_ativo != null:
		_animar_carta_para_zona(grupo_ativo, zona_descarte)

func _ao_vitoria(jogador_id: int) -> void:
	print("🏆 [MesaUI] VITÓRIA REGISTRADA! Jogador %d venceu!" % jogador_id)
	_exibir_tela_vitoria(jogador_id)
	turno_em_progresso = false

func _ao_empate() -> void:
	print("🤝 [MesaUI] EMPATE REGISTRADO!")
	_exibir_tela_empate()
	turno_em_progresso = false

func atualizar_zona_descarte(jogador_id: int, pilha_descarte: Array[CardBaseResource]) -> void:
	var painel_descarte: Panel = jogador_zona_descarte if jogador_id == ID_JOGADOR_HUMANO else oponente_zona_descarte
	if not painel_descarte:
		return

	# Limpa tudo no container
	for child in painel_descarte.get_children():
		child.queue_free()

	# Se a pilha não estiver vazia, renderiza a última carta (topo do descarte)
	if not pilha_descarte.is_empty():
		var carta_topo: CardBaseResource = pilha_descarte.back()
		_adicionar_carta_na_zona(jogador_id, "descarte", carta_topo)

# ==============================================================================
# DECK E COMPRA DE CARTAS
# ==============================================================================

func comprar_carta_animada(jogador_id: int, carta: CardBaseResource) -> void:
	print("🃏 [MesaUI] Animando compra de carta: %s para Jogador %d" % [carta.name, jogador_id])
	var zona_deck: Panel = jogador_zona_deck if jogador_id == 0 else oponente_zona_deck
	var mao_container: HBoxContainer = jogador_mao if jogador_id == 0 else oponente_mao

	var eh_oponente: bool = jogador_id != ID_JOGADOR_HUMANO
	var carta_visual: Control = _criar_carta_ui(carta, eh_oponente)
	
	add_child(carta_visual)
	carta_visual.global_position = zona_deck.global_position

	var tween := create_tween()
	tween.tween_property(carta_visual, "global_position", mao_container.global_position, 0.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_callback(func():
		carta_visual.queue_free()
		organizar_cartas_nas_zonas(jogador_id)
		atualizar_zona_descarte(jogador_id, GameState.obter_descarte(jogador_id))
	)

func atualizar_visual_deck(jogador_id: int, cartas_restantes: int) -> void:
	const MAX_CARTAS_VISIVEIS := 6
	const OFFSET_PILHA := Vector2(1.5, -1.5)

	var zona_deck: Panel = jogador_zona_deck if jogador_id == 0 else oponente_zona_deck

	for child in zona_deck.get_children():
		child.queue_free()

	if cartas_restantes <= 0:
		print("📚 [MesaUI] Deck do Jogador %d está totalmente vazio." % jogador_id)
		return

	var quantidade_visual: int = mini(cartas_restantes, MAX_CARTAS_VISIVEIS)

	for i in range(quantidade_visual):
		var verso: Control = HelperUI.criar_verso_generico()
		verso.position = OFFSET_PILHA * i
		verso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zona_deck.add_child(verso)

	var label_contador := Label.new()
	label_contador.text = str(cartas_restantes)
	label_contador.add_theme_font_size_override("font_size", 20)
	label_contador.anchor_left = 0.5
	label_contador.anchor_top = 1.0
	label_contador.offset_left = -12
	label_contador.offset_top = 6
	label_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_contador.self_modulate = Color.RED if cartas_restantes <= 5 else Color.WHITE
	zona_deck.add_child(label_contador)

	print("📚 [MesaUI] Deck atualizado: %d cartas restantes (Jogador %d)" % [cartas_restantes, jogador_id])

# ==============================================================================
# GERENCIAMENTO DE ZONAS E INTERAÇÕES
# ==============================================================================

func organizar_cartas_nas_zonas(jogador_id: int) -> void:
	var jogador := _obter_player_state(jogador_id)
	var ativo := GameState.obter_ativo(jogador_id)
	var banco := GameState.obter_banco(jogador_id)

	_limpar_zona(jogador_id, "mao")
	_limpar_zona(jogador_id, "banco")
	_limpar_zona(jogador_id, "ativo")
	_limpar_zona(jogador_id, "descarte")

	for i in jogador.mao.size():
		var carta_base = jogador.mao[i]
		_adicionar_carta_na_zona(jogador_id, "mao", carta_base, null, i)

	if ativo != null:
		_adicionar_carta_na_zona(jogador_id, "ativo", ativo.card, ativo)

	for i in banco.size():
		var instancia = banco[i]
		_adicionar_carta_na_zona(jogador_id, "banco", instancia.card, instancia, i)

func _adicionar_carta_na_zona(jogador_id: int, zona_nome: String, carta: CardBaseResource, instancia: AnimalInstance = null, indice_ou_slot: int = -1) -> void:
	var eh_mao_do_oponente: bool = (zona_nome == "mao" and jogador_id != ID_JOGADOR_HUMANO)
	var eh_ativo_inicial_escondido: bool = (zona_nome == "ativo" and _setup_em_andamento)
	var face_para_baixo: bool = eh_mao_do_oponente or eh_ativo_inicial_escondido

	match zona_nome:
		"mao":
			var mao_container: HBoxContainer = jogador_mao if jogador_id == 0 else oponente_mao
			var resultado := HelperUI.instanciar_carta_escalada(carta, Vector2(9999, ALTURA_MAO), face_para_baixo)
			if resultado.is_empty():
				return
			var card_visual = resultado["visual"]
			mao_container.add_child(resultado["envelope"])

			if jogador_id == ID_JOGADOR_HUMANO:
				_configurar_inputs_carta(card_visual, carta, jogador_id, "mao", null)
				_conectar_zoom_hover(card_visual, carta)

		"ativo":
			var campo_ativo: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
			
			var grupo_cartas := Control.new()
			grupo_cartas.name = "GrupoAtivo"
			grupo_cartas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			campo_ativo.add_child(grupo_cartas)

			var deslocamento_x : float = 0.0
			var deslocamento_y : float = 0.0

			if instancia is AnimalInstance:
				for energia_carta in instancia.attached_energies:
					deslocamento_x += 10.0
					deslocamento_y += 12.0
					
					var res_energia := HelperUI.instanciar_carta_escalada(energia_carta, TAMANHO_SLOT_ATIVO, false)
					if not res_energia.is_empty():
						var env_energia: Control = res_energia["envelope"]
						var vis_energia = res_energia["visual"]
						
						grupo_cartas.add_child(env_energia)
						_centralizar_envelope_no_painel(env_energia)
						
						env_energia.offset_left += deslocamento_x
						env_energia.offset_right += deslocamento_x
						env_energia.offset_top += deslocamento_y
						env_energia.offset_bottom += deslocamento_y
						
						_conectar_zoom_hover(vis_energia, energia_carta)

			var resultado := HelperUI.instanciar_carta_escalada(carta, TAMANHO_SLOT_ATIVO, face_para_baixo)
			if resultado.is_empty():
				return
			var envelope: Control = resultado["envelope"]
			var card_visual = resultado["visual"]
			
			grupo_cartas.add_child(envelope)
			_centralizar_envelope_no_painel(envelope)

			# 🟢 INSERÇÃO 1: Adiciona indicador de vida/dano no Ativo
			if instancia is AnimalInstance and not face_para_baixo:
				HelperUI.adicionar_indicador_vida_e_dano(envelope, instancia)

			if jogador_id == ID_JOGADOR_HUMANO:
				_configurar_inputs_carta(card_visual, carta, jogador_id, "ativo", instancia)
			
			if not face_para_baixo:
				_conectar_zoom_hover(card_visual, carta)

		"banco":
			var slots_banco: HBoxContainer = jogador_slots_banco if jogador_id == 0 else oponente_slots_banco
			var slots := slots_banco.get_children()
			
			if indice_ou_slot < 0 or indice_ou_slot >= slots.size():
				push_error("❌ [MesaUI] Índice do banco fora do alcance: %d" % indice_ou_slot)
				return
				
			var slot_destino: Control = slots[indice_ou_slot]

			var grupo_cartas := Control.new()
			grupo_cartas.name = "GrupoBanco"
			grupo_cartas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot_destino.add_child(grupo_cartas)

			var deslocamento_x : float = 0.0
			var deslocamento_y : float = 0.0

			if instancia is AnimalInstance:
				for energia_carta in instancia.attached_energies:
					deslocamento_x += 10.0
					deslocamento_y += 12.0
					
					var res_energia := HelperUI.instanciar_carta_escalada(energia_carta, TAMANHO_SLOT_BANCO, false)
					if not res_energia.is_empty():
						var env_energia: Control = res_energia["envelope"]
						var vis_energia = res_energia["visual"]
						
						grupo_cartas.add_child(env_energia)
						_centralizar_envelope_no_painel(env_energia)
						
						env_energia.offset_left += deslocamento_x
						env_energia.offset_right += deslocamento_x
						env_energia.offset_top += deslocamento_y
						env_energia.offset_bottom += deslocamento_y
						
						_conectar_zoom_hover(vis_energia, energia_carta)

			var resultado := HelperUI.instanciar_carta_escalada(carta, TAMANHO_SLOT_BANCO, face_para_baixo)
			if resultado.is_empty():
				return
			var card_visual = resultado["visual"]
			var envelope: Control = resultado["envelope"]
			
			grupo_cartas.add_child(envelope)
			_centralizar_envelope_no_painel(envelope)

			# 🟢 INSERÇÃO 2: Adiciona indicador de vida/dano no Banco
			if instancia is AnimalInstance and not face_para_baixo:
				HelperUI.adicionar_indicador_vida_e_dano(envelope, instancia)

			if jogador_id == ID_JOGADOR_HUMANO:
				_configurar_inputs_carta(card_visual, carta, jogador_id, "banco", instancia)
			
			_conectar_zoom_hover(card_visual, carta)

		"descarte":
			var painel_descarte: Panel = jogador_zona_descarte if jogador_id == ID_JOGADOR_HUMANO else oponente_zona_descarte
			if not painel_descarte:
				push_error("❌ [MesaUI] Painel de descarte não configurado para o jogador: %d" % jogador_id)
				return

			# Limpa visualizações anteriores no painel para mostrar apenas a carta do topo
			for child in painel_descarte.get_children():
				child.queue_free()

			# Define o tamanho com base no tamanho atual do painel de descarte
			var tamanho_slot_descarte: Vector2 = painel_descarte.size
			if tamanho_slot_descarte == Vector2.ZERO:
				tamanho_slot_descarte = Vector2(100, 140) # Tamanho fallback caso a UI não tenha recalculado o layout ainda

			# Descarte costuma ser sempre com a face para cima
			var resultado := HelperUI.instanciar_carta_escalada(carta, tamanho_slot_descarte, false)
			if resultado.is_empty():
				return

			var envelope: Control = resultado["envelope"]
			var card_visual = resultado["visual"]

			painel_descarte.add_child(envelope)
			_centralizar_envelope_no_painel(envelope)

			# Conecta zoom/hover para inspeção se necessário (humano ou oponente)
			_conectar_zoom_hover(card_visual, carta)

			# Permite interações (ex: clicar no descarte para abrir histórico) se for do humano
			if jogador_id == ID_JOGADOR_HUMANO:
				_configurar_inputs_carta(card_visual, carta, jogador_id, "descarte", instancia)

func _conectar_zoom_hover(nodo_visual: Control, carta: CardBaseResource) -> void:
	if not nodo_visual.mouse_entered.is_connected(_on_card_mouse_entered):
		nodo_visual.mouse_entered.connect(_on_card_mouse_entered.bind(nodo_visual, carta))
	if not nodo_visual.mouse_exited.is_connected(_fechar_zoom_leitura):
		nodo_visual.mouse_exited.connect(_fechar_zoom_leitura)

func _on_card_mouse_entered(nodo_visual: Control, carta: CardBaseResource) -> void:
	_abrir_zoom_leitura(nodo_visual, carta)

func _centralizar_envelope_no_painel(envelope: Control) -> void:
	var tamanho: Vector2 = envelope.custom_minimum_size
	envelope.anchor_left = 0.5
	envelope.anchor_top = 0.5
	envelope.anchor_right = 0.5
	envelope.anchor_bottom = 0.5
	envelope.offset_left = -tamanho.x / 2.0
	envelope.offset_top = -tamanho.y / 2.0
	envelope.offset_right = tamanho.x / 2.0
	envelope.offset_bottom = tamanho.y / 2.0

func _configurar_inputs_carta(carta_visual: Control, carta_resource: CardBaseResource, jogador_id: int, contexto: String, instancia: AnimalInstance) -> void:
	if not carta_visual.gui_input.is_connected(_ao_input_carta):
		carta_visual.gui_input.connect(_ao_input_carta.bind(carta_visual, carta_resource, jogador_id, contexto, instancia))

func _ao_input_carta(event: InputEvent, carta_visual: Control, carta_resource: CardBaseResource, jogador_id: int, contexto: String, instancia: AnimalInstance) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	# 1. Leitura/Zoom com Botão Direito: Permitido a qualquer momento (mesmo no turno da IA)
	if event.button_index == MOUSE_BUTTON_RIGHT:
		print("[MesaUI] Clique com botão direito na carta %s (Zoom)." % carta_resource.name)
		_abrir_zoom_leitura(carta_visual, carta_resource)
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# 2. Exceção do Setup: Permite escolher o ativo inicial na fase de preparação
	if _jogador_aguardando_escolha_ativo == jogador_id:
		print("[MesaUI] Clique na carta: %s | Contexto: %s | Jogador: %d" % [carta_resource.name, contexto, jogador_id])
		_tentar_confirmar_ativo_inicial(jogador_id, carta_resource)
		return

	# 3. 🛡️ TRAVA CRÍTICA DE TURNO E JOGO ATIVO
	# Se a partida acabou ou NÃO é o turno do humano, bloqueia qualquer ação com botão esquerdo
	if not GameState.partida_ativa or GameState.jogador_ativo != ID_JOGADOR_HUMANO:
		print("⚠️ [MesaUI] Clique ignorado: Ação bloqueada fora do seu turno (Jogador Ativo: %d)." % GameState.jogador_ativo)
		return

	print("[MesaUI] Clique na carta: %s | Contexto: %s | Jogador: %d" % [carta_resource.name, contexto, jogador_id])

	# 4. Processa seleção de alvo (agora protegido pela trava de turno acima)
	if _selecao_alvo_ativa:
		_tentar_completar_selecao_alvo(instancia, contexto)
		return

	# 5. Só abre menu para cartas do próprio jogador humano
	if jogador_id != ID_JOGADOR_HUMANO:
		return

	var opcoes: Array[Dictionary] = _construir_opcoes_menu(carta_resource, contexto, instancia)
	if opcoes.is_empty():
		print("[MesaUI] Nenhuma opção disponível no menu contextual para a carta %s." % carta_resource.name)
		return

	_abrir_menu_generico(carta_visual.global_position, opcoes)

func _tentar_confirmar_ativo_inicial(jogador_id: int, carta_resource: CardBaseResource) -> void:
	var jogador := _obter_player_state(jogador_id)
	var indice: int = jogador.mao.find(carta_resource)

	if indice == -1:
		push_warning("⚠️ [MesaUI] Tentativa de selecionar carta inicial que não está na mão!")
		return

	print("[Setup] Confirmando escolha de ativo inicial (Índice %d)." % indice)
	if SetupManager.confirmar_animal_ativo(jogador_id, indice):
		_jogador_aguardando_escolha_ativo = -1
		organizar_cartas_nas_zonas(jogador_id)
	else:
		_exibir_texto_flutuante("Selecione um Animal Filhote", 1.5)

# ==============================================================================
# SISTEMA DE ZOOM (PREVIEW DE CARTA)
# ==============================================================================

func _abrir_zoom_leitura(_carta_visual: Control, carta_resource: CardBaseResource) -> void:
	if painel_zoom:
		painel_zoom.exibir_preview(carta_resource, false)

func _fechar_zoom_leitura() -> void:
	if painel_zoom:
		painel_zoom.esconder_preview()

# ==============================================================================
# MODO DE SELEÇÃO DE ALVO
# ==============================================================================

func _iniciar_selecao_crescer(carta_evolucao: CardResource) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var indice_mao: int = jogador.mao.find(carta_evolucao)
	if indice_mao == -1:
		return

	print("[Seleção] Modo seleção ativado: CRESCER (%s)" % carta_evolucao.name)
	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "crescer"
	_selecao_alvo_dados = {"indice_mao": indice_mao, "carta_evolucao": carta_evolucao}
	_exibir_texto_flutuante("Selecione o animal que vai crescer", 2.0)

func _iniciar_selecao_fortalecer(carta_energia: EffectResource) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var indice_mao: int = jogador.mao.find(carta_energia)
	if indice_mao == -1:
		return

	print("[Seleção] Modo seleção ativado: FORTALECER com %s" % carta_energia.name)
	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "fortalecer"
	_selecao_alvo_dados = {"indice_mao": indice_mao, "carta": carta_energia}
	_exibir_texto_flutuante("Selecione o animal que vai receber a energia", 2.0)

func _iniciar_selecao_retroceder() -> void:
	print("[Seleção] Modo seleção ativado: RETROCEDER")
	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "retroceder"
	_selecao_alvo_dados = {}
	_exibir_texto_flutuante("Selecione o animal do Banco que vai substituir", 2.0)

func _iniciar_selecao_alimentar() -> void:
	print("[Seleção] Modo seleção ativado: ALIMENTAR")
	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "alimentar"
	_selecao_alvo_dados = {}
	_exibir_texto_flutuante("Selecione o animal que vai se alimentar", 2.0)

func _cancelar_selecao_alvo() -> void:
	if not _selecao_alvo_ativa:
		return

	print("[Seleção] Modo de seleção de alvo cancelado.")
	_selecao_alvo_ativa = false
	_selecao_alvo_tipo = ""
	_selecao_alvo_dados = {}

func _tentar_completar_selecao_alvo(instancia: AnimalInstance, contexto: String) -> void:
	if instancia == null or (contexto != "ativo" and contexto != "banco"):
		print("[Seleção] Clique fora de um alvo válido em campo. Ignorando.")
		return

	print("[Seleção] Tentando aplicar '%s' no alvo %s (Contexto: %s)" % [_selecao_alvo_tipo, instancia.card.name, contexto])

	match _selecao_alvo_tipo:
		"crescer":
			_acao_crescer(_selecao_alvo_dados["indice_mao"], _selecao_alvo_dados["carta_evolucao"], instancia)

		"fortalecer":
			_acao_fortalecer(_selecao_alvo_dados["indice_mao"], _selecao_alvo_dados["carta"], instancia)

		"retroceder":
			if contexto != "banco":
				print("[Seleção] Alvo inválido para recuo. É necessário escolher um do Banco.")
				_exibir_texto_flutuante("Escolha um animal do Banco", 1.5)
				return
			_acao_retroceder(instancia)

		"alimentar":
			_abrir_popup_quantidade_alimento(instancia)
			return

	_cancelar_selecao_alvo()

func _abrir_popup_quantidade_alimento(animal: AnimalInstance) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	if jogador == null or jogador.comida_disponivel <= 0:
		_exibir_texto_flutuante("Sem comida disponível!", 1.5)
		_cancelar_selecao_alvo()
		return

	_cancelar_selecao_alvo()

	var popup := PopupAlimentar.new()
	add_child(popup)
	
	# Recebe os 2 argumentos do sinal e repassa para a ação
	popup.alimentacao_confirmada.connect(func(alvo: AnimalInstance, qtd: int):
		_acao_alimentar(alvo, qtd)
	)
	
	popup.exibir(self, animal, jogador.comida_disponivel)
	
	# ==============================================================================
# AÇÕES E PROCESSAMENTO DE BARRAS/REGRAS
# ==============================================================================

func _acao_reserva(carta: CardBaseResource) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var indice_mao: int = jogador.mao.find(carta)
	if indice_mao == -1:
		return

	_resolver_acao("jogar_para_banco", {"indice_mao": indice_mao, "carta": carta})

func _acao_crescer(indice_mao: int, carta_evolucao: CardResource, instancia: AnimalInstance) -> void:
	_resolver_acao("crescer", {
		"indice_mao": indice_mao,
		"carta_evolucao": carta_evolucao,
		"instancia": instancia,
	})

func _acao_fortalecer(indice_mao: int, carta: EffectResource, animal: AnimalInstance) -> void:
	_resolver_acao("anexar_energia", {
		"indice_mao": indice_mao,
		"carta": carta,
		"animal": animal,
	})

func _acao_retroceder(substituto: AnimalInstance) -> void:
	_solicitar_recuo(substituto)
	
func _solicitar_recuo(substituto: AnimalInstance) -> void:
	var ativo := GameState.obter_ativo(ID_JOGADOR_HUMANO)
	if ativo == null:
		return

	# Obtém o custo de recuo do animal (ex: 2 energias)
	var custo: int = ativo.card.cost_retreat if "cost_retreat" in ativo.card else 0

	# Se não tiver energia suficiente
	if ativo.attached_energies.size() < custo:
		_exibir_texto_flutuante("Energia insuficiente pra recuar", 1.5)
		return

	# Caso o custo seja 0, recua direto sem popup
	if custo == 0:
		_resolver_acao("recuar", {"substituto": substituto, "energias_para_descarte": []})
		return

	# Abre o Pop-up de Recuo modular
	var popup := PopupRecuo.new()
	add_child(popup)
	popup.recuo_confirmado.connect(func(_sub, energias_selecionadas):
		_resolver_acao("recuar", {
			"substituto": substituto, 
			"energias_para_descarte": energias_selecionadas
		})
	)
	popup.exibir(self, ativo, substituto, custo)
	
func _abrir_selecao_energias_para_recuo(substituto: AnimalInstance, custo: int) -> void:
	var ativo := GameState.obter_ativo(ID_JOGADOR_HUMANO)

	if ativo == null or ativo.attached_energies.size() < custo:
		print("⚠️ [Ação] Energias insuficientes para o recuo de %s." % (ativo.card.name if ativo else "Nenhum"))
		_exibir_texto_flutuante("Energia insuficiente pra recuar", 1.5)
		return

	print("[MesaUI] Exibindo pop-up de recuo (%d energias necessárias)." % custo)
	var popup := PopupRecuo.new()
	add_child(popup)
	popup.recuo_confirmado.connect(func(energias_selecionadas: Array):
		_resolver_acao("recuar", {"substituto": substituto, "energias_para_descarte": energias_selecionadas})
	)
	# 🟢 CORRIGIDO: Passando 'substituto' no 3º argumento em vez do Array de energias
	popup.exibir(self, ativo, substituto, custo)
	
func _acao_alimentar(animal: AnimalInstance, quantidade: int) -> void:
	_resolver_acao("distribuir_comida", {"animal": animal, "quantidade": quantidade})

func _acao_atacar(carta: CardBaseResource) -> void:
	var ataque_final = carta as CardResource
	if ataque_final == null:
		var ativo := GameState.obter_ativo(ID_JOGADOR_HUMANO)
		if ativo != null and ativo.card != null and "attacks" in ativo.card and ativo.card.attacks.size() > 0:
			ataque_final = ativo.card.attacks[0]

	if ataque_final == null:
		print("❌ [MesaUI] Impossível atacar: Nenhum recurso de ataque encontrado!")
		_exibir_texto_flutuante("Ataque indisponível", 1.5)
		return

	var resultado := await _resolver_acao("atacar", {"ataque": ataque_final})
	if resultado.get("sucesso", false):
		# 🟢 CORRIGIDO: Passando ID do jogador em vez do recurso da carta
		_animar_ataque(ID_JOGADOR_HUMANO)

func _acao_usar_habilidade(_carta: CardBaseResource) -> void:
	print("[Ação] Habilidade solicitada (Recurso pendente de implementação).")
	_exibir_texto_flutuante("Habilidades: em breve", 1.5)

func _acao_ativar_efeito(carta: EffectResource) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var indice_mao: int = jogador.mao.find(carta)
	if indice_mao == -1:
		return

	var tipo_acao: String
	match carta.super_type:
		"cataclismo": tipo_acao = "jogar_cataclismo"
		"vestigio": tipo_acao = "jogar_vestigio"
		"territorio": tipo_acao = "jogar_territorio"
		_: return

	if carta.super_type == "territorio" and GameState.territorio_ativo != null:
		_confirmar_substituicao_territorio(indice_mao, carta, tipo_acao)
		return

	_resolver_acao(tipo_acao, {"indice_mao": indice_mao, "carta": carta})

func _confirmar_substituicao_territorio(indice_mao: int, carta: EffectResource, tipo_acao: String) -> void:
	# 🟢 CORRIGIDO: Usa ConfirmationDialog nativo da Godot em vez de classe inexistente
	var dialog := ConfirmationDialog.new()
	dialog.title = "Substituir Território?"
	dialog.dialog_text = "Isso vai descartar o território ativo atual."
	add_child(dialog)
	dialog.confirmed.connect(func():
		_resolver_acao(tipo_acao, {"indice_mao": indice_mao, "carta": carta})
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
	
func _resolver_acao(tipo_acao: String, dados: Dictionary) -> Dictionary:
	print("[Ação] Enviando solicitação: '%s' para BattleManager..." % tipo_acao)
	var resultado: Dictionary = await BattleManager.processar_acao(tipo_acao, dados)
	acao_jogador_solicitada.emit(tipo_acao, dados)

	if resultado.get("sucesso", false):
		print("[Ação] Sucesso na execução de '%s'." % tipo_acao)
		_refrescar_tabuleiro()

		if resultado.get("status") == "aguardando_promocao":
			var jogador_bloqueado_id: int = resultado.get("jogador_bloqueado")
			print("⚠️ [Ação] Promoção obrigatória necessária para Jogador %d!" % jogador_bloqueado_id)
			
			if jogador_bloqueado_id == ID_JOGADOR_HUMANO:
				exibir_popup_promocao_obrigatoria(jogador_bloqueado_id)
			else:
				print("🤖 [MesaUI] Aguardando a IA promover o novo ativo...")
	else:
		var motivo: String = resultado.get("motivo", "acao_invalida")
		print("❌ [Ação] Falha em '%s'. Motivo: %s" % [tipo_acao, motivo])
		_exibir_texto_flutuante(_traduzir_motivo_falha(motivo), 1.5)

	return resultado

func _traduzir_motivo_falha(motivo: String) -> String:
	match motivo:
		"ainda_nao_implementado": return "Ainda não implementado"
		"colocacao_invalida": return "Banco cheio ou carta inválida"
		"evolucao_invalida": return "Evolução inválida"
		"anexacao_invalida": return "Não é possível anexar aqui"
		"distribuicao_invalida": return "Sem pool suficiente"
		"recuo_invalido": return "Não é possível recuar agora"
		"substituto_invalido": return "Alvo inválido"
		"ataque_invalido": return "Ataque indisponível"
		"paralisado_falhou": return "Paralisado! O ataque falhou"
		_: return "Ação inválida"

## Abre o PopupSelecaoCartas para qualquer zona (Deck, Zona Fóssil, Cemitério, Mão)
func solicitar_selecao_cartas_zona(
	titulo: String, 
	instrucao: String, 
	cartas_disponiveis: Array[CardBaseResource], 
	quantidade: int, 
	callback_confirmacao: Callable,
	permitir_menos: bool = false
) -> void:
	print("🔬 [DEBUG] solicitar_selecao_cartas_zona chamada | cartas_disponiveis.size() = %d" % cartas_disponiveis.size())

	if cartas_disponiveis.is_empty():
		print("🔬 [DEBUG] ⚠️ Retornou cedo — array vazio!")
		_exibir_texto_flutuante("Nenhuma carta elegível encontrada", 1.5)
		return

	var popup := PopupSelecaoCartas.new()
	add_child(popup)
	print("🔬 [DEBUG] Popup criado e adicionado à árvore: %s" % popup)
	
	popup.cartas_selecionadas.connect(func(cartas_escolhidas: Array[CardBaseResource]):
		print("🔬 [DEBUG] Sinal cartas_selecionadas disparado! Escolhidas: %d" % cartas_escolhidas.size())
		callback_confirmacao.call(cartas_escolhidas)
	)
	popup.cancelado.connect(func():
		print("🔬 [DEBUG] Sinal cancelado disparado!")
		callback_confirmacao.call([])
	)
	
	popup.exibir(self, titulo, instrucao, cartas_disponiveis, quantidade, permitir_menos)
	print("🔬 [DEBUG] popup.exibir() chamado, aguardando interação do jogador...")

## Trata o descarte de energias quando exigido por efeitos/ataques
	
func _refrescar_tabuleiro() -> void:
	organizar_cartas_nas_zonas(0)
	organizar_cartas_nas_zonas(1)
	atualizar_visual_comida(0)
	atualizar_visual_comida(1)
	atualizar_zona_descarte(0, GameState.obter_descarte(0))
	atualizar_zona_descarte(1, GameState.obter_descarte(1))
# ==============================================================================
# ANIMAÇÕES VISUAIS
# ==============================================================================

func _animar_carta_para_zona(carta_visual: Control, zona_alvo: Control, duracao: float = DURACAO_ANIMACAO_CARTA) -> Signal:
	if dicionario_tweens_cartas.has(carta_visual):
		dicionario_tweens_cartas[carta_visual].kill()

	var tween: Tween = create_tween()
	dicionario_tweens_cartas[carta_visual] = tween

	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	carta_visual.z_index = 10

	tween.tween_property(
		carta_visual,
		"global_position",
		zona_alvo.global_position,
		duracao
	)

	tween.tween_callback(func():
		dicionario_tweens_cartas.erase(carta_visual)
		if is_instance_valid(carta_visual):
			carta_visual.z_index = 0
			carta_visual.modulate.a = 1.0
	)
	
	return tween.finished

func _ao_partida_encerrada(vencedor_id: int, motivo: String) -> void:
	print("🏆 [MesaUI] Fim de jogo detectado! Vencedor: %d | Motivo: %s" % [vencedor_id, motivo])

	# 1. Limpa menus e seleções que estiverem abertos
	_cancelar_selecao_alvo()
	_fechar_menu_contextual()
	_fechar_popup_setup()

	# 2. Identifica se havia um animal ativo no perdedor e roda a animação de ir pro descarte FIRST
	var id_perdedor: int = 1 if vencedor_id == 0 else 0
	var campo_perdedor: Panel = jogador_campo_ativo if id_perdedor == 0 else oponente_campo_ativo
	var zona_descarte: Panel = jogador_zona_descarte if id_perdedor == 0 else oponente_zona_descarte
	var grupo_ativo := campo_perdedor.get_node_or_null("GrupoAtivo")

	if grupo_ativo != null and is_instance_valid(grupo_ativo):
		print("💥 [MesaUI] Animando descarte do animal nocauteado antes de finalizar...")
		await _animar_carta_para_zona(grupo_ativo, zona_descarte)
		await get_tree().create_timer(0.2).timeout # Pequena pausa para percepção visual

	# 3. Trava totalmente os inputs e temporizadores da mesa
	set_process_input(false)
	turno_em_progresso = false
	timer_turno.stop()
	if botao_passar_turno:
		botao_passar_turno.disabled = true

	# 4. Exibe a tela correspondente
	if vencedor_id == -1:
		_exibir_tela_empate()
	else:
		_exibir_tela_vitoria(vencedor_id)

func _animar_ataque(jogador_id: int = ID_JOGADOR_HUMANO) -> void:
	# 🟢 CORREÇÃO: Seleciona o campo ativo correto com base no jogador que atacou
	var campo_ativo: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
	var grupo_ativo := campo_ativo.get_node_or_null("GrupoAtivo")
	
	if grupo_ativo == null or grupo_ativo.get_child_count() == 0:
		return

	# Pega o envelope da carta principal do animal ativo no grupo
	var envelope := grupo_ativo.get_child(grupo_ativo.get_child_count() - 1) as Control
	if envelope == null or envelope.get_child_count() == 0:
		return

	var carta_visual: Control = envelope.get_child(0) as Control
	if carta_visual == null:
		return

	if dicionario_tweens_cartas.has(carta_visual):
		dicionario_tweens_cartas[carta_visual].kill()

	var escala_base: Vector2 = carta_visual.scale
	var escala_pulso: Vector2 = escala_base * 1.15

	var tween: Tween = create_tween()
	dicionario_tweens_cartas[carta_visual] = tween

	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(carta_visual, "scale", escala_pulso, 0.1)
	tween.tween_property(carta_visual, "scale", escala_base, 0.1)
	tween.tween_property(carta_visual, "scale", escala_pulso, 0.1)
	tween.tween_property(carta_visual, "scale", escala_base, 0.1)

	tween.tween_callback(func():
		dicionario_tweens_cartas.erase(carta_visual)
		if is_instance_valid(carta_visual):
			carta_visual.scale = escala_base
	)

func _exibir_texto_flutuante(texto: String, duracao: float) -> void:
	# 🟢 DELEGAÇÃO: Manda a criação e animação do Label para a classe utilitária de UI
	HelperUI.exibir_texto_flutuante(self, texto, duracao)

# ==============================================================================
# FEEDBACKS VISUAIS — CONDIÇÕES E COMIDA
# ==============================================================================

func _renderizar_condicao(jogador_id: int, tipo: ConditionSystem.Tipo) -> void:
	var zona_condicao: Panel = jogador_condicao_especial if jogador_id == 0 else oponente_condicao_especial

	for child in zona_condicao.get_children():
		child.queue_free()

	if tipo == ConditionSystem.Tipo.NENHUMA:
		return

	var nome_condicao: String = ConditionSystem.Tipo.keys()[tipo].capitalize()

	var condicao_visual := Label.new()
	condicao_visual.text = nome_condicao
	condicao_visual.add_theme_font_size_override("font_size", 24)
	condicao_visual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	condicao_visual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	condicao_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	match tipo:
		ConditionSystem.Tipo.ADORMECIDO:
			condicao_visual.self_modulate = Color.LIGHT_BLUE
		ConditionSystem.Tipo.PARALISADO:
			condicao_visual.self_modulate = Color.YELLOW
		ConditionSystem.Tipo.ENVENENADO:
			condicao_visual.self_modulate = Color.GREEN
		ConditionSystem.Tipo.SANGRANDO:
			condicao_visual.self_modulate = Color.RED
		ConditionSystem.Tipo.CONDENADO:
			condicao_visual.self_modulate = Color.PURPLE

	zona_condicao.add_child(condicao_visual)

func _atualizar_visual_contador_comida(jogador_id: int, pontos: int) -> void:
	var contador_panel: Panel = jogador_contador_comida if jogador_id == 0 else oponente_contador_comida

	var label_comida: Label = contador_panel.get_node_or_null("LabelComida") as Label
	if label_comida == null:
		label_comida = Label.new()
		label_comida.name = "LabelComida"
		label_comida.add_theme_font_size_override("font_size", 32)
		label_comida.modulate = Color.ORANGE
		label_comida.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_comida.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_comida.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contador_panel.add_child(label_comida)

		# 🟢 Conexões limpas e seguras com `.bind()` em vez de lambdas anônimas
		if not contador_panel.mouse_entered.is_connected(_ao_mouse_entrou_comida):
			contador_panel.mouse_entered.connect(_ao_mouse_entrou_comida.bind(jogador_id))
		if not contador_panel.mouse_exited.is_connected(_ao_mouse_saiu_comida):
			contador_panel.mouse_exited.connect(_ao_mouse_saiu_comida)

		if jogador_id == ID_JOGADOR_HUMANO and not contador_panel.gui_input.is_connected(_ao_input_zona_comida):
			contador_panel.gui_input.connect(_ao_input_zona_comida)

	label_comida.text = str(pontos)

func _ao_input_zona_comida(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if _selecao_alvo_ativa:
		return

	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	if jogador.comida_disponivel <= 0:
		print("⚠️ [MesaUI] Pool de comida vazio! Não é possível abrir o menu de alimentação.")
		_exibir_texto_flutuante("Sem pontos de comida no pool", 1.5)
		return

	_abrir_menu_generico(
		jogador_contador_comida.global_position + Vector2(0, -60),
		[{"texto": "Alimentar", "callback": _iniciar_selecao_alimentar}]
	)

func _ao_mouse_entrou_comida(jogador_id: int) -> void:
	var jogador := _obter_player_state(jogador_id)
	print("ℹ️ Hover em contador de comida: %d pontos (Jogador %d)" % [jogador.comida_disponivel, jogador_id])

func _ao_mouse_saiu_comida() -> void:
	pass
	
# ==============================================================================
# TELAS FINAIS
# ==============================================================================

func _exibir_tela_vitoria(ganhador_id: int) -> void:
	_exibir_tela_final("🏆 JOGADOR %d VENCEU! 🏆" % ganhador_id, Color(0, 0, 0, 0.85))
	print("🏆 Tela de vitória exibida para Jogador: %d" % ganhador_id)

func _exibir_tela_empate() -> void:
	_exibir_tela_final("🤝 EMPATE! 🤝", Color(0.2, 0.2, 0.2, 0.85))
	print("🤝 Tela de empate exibida")

func _exibir_tela_final(texto: String, cor_fundo: Color) -> void:
	var tela := Panel.new()
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_STOP

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = cor_fundo
	tela.add_theme_stylebox_override("panel", stylebox)

	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color.GOLD if "VENCEU" in texto else Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	tela.add_child(label)
	add_child(tela)

# ==============================================================================
# MÉTODOS AUXILIARES
# ==============================================================================

func _obter_player_state(jogador_id: int) -> PlayerState:
	return GameState.jogador_1 if jogador_id == 0 else GameState.jogador_2

func _limpar_zona(jogador_id: int, zona_nome: String) -> void:
	var container: Control = null

	match zona_nome:
		"mao":
			container = jogador_mao if jogador_id == 0 else oponente_mao
			if container:
				for child in container.get_children():
					container.remove_child(child)
					child.queue_free()
		
		"banco":
			var slots_container = jogador_slots_banco if jogador_id == 0 else oponente_slots_banco
			if slots_container:
				for slot in slots_container.get_children():
					for carta_no_slot in slot.get_children():
						slot.remove_child(carta_no_slot)
						carta_no_slot.queue_free()

		"ativo":
			container = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
			if container:
				for child in container.get_children():
					container.remove_child(child)
					child.queue_free()

		"descarte":
			container = jogador_zona_descarte if jogador_id == 0 else oponente_zona_descarte
			if container:
				for child in container.get_children():
					container.remove_child(child)
					child.queue_free()

func _obter_primeiro_filho_control(parent: Node) -> Control:
	if not parent:
		return null
	for child in parent.get_children():
		if child is Control:
			return child
	return null

func _criar_carta_ui(carta: CardBaseResource, face_para_baixo: bool = false) -> Control:
	return HelperUI.instanciar_carta(carta, face_para_baixo)	

func _fechar_popup_setup() -> void:
	# 🟢 CORRIGIDO: Método declarado para evitar erro de referência
	var popup_setup = get_node_or_null("PopupSetup")
	if is_instance_valid(popup_setup):
		popup_setup.queue_free()

func _abrir_menu_generico(posicao_global: Vector2, opcoes: Array[Dictionary]) -> void:
	_fechar_menu_contextual()

	if opcoes.is_empty():
		return

	# 🟢 CORRIGIDO: Constroi o menu internamente sem depender da classe inexistente MenuContextual
	var menu := Panel.new()
	menu.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	menu.custom_minimum_size = Vector2(150, 36 * opcoes.size() + 20)
	menu.global_position = posicao_global + Vector2(100, 0)

	var vbox := VBoxContainer.new()
	menu.add_child(vbox)

	for opcao in opcoes:
		var botao := Button.new()
		botao.text = opcao["texto"]
		botao.pressed.connect(func():
			_fechar_menu_contextual()
			opcao["callback"].call()
		)
		vbox.add_child(botao)

	add_child(menu)
	menu_contextual_ativo = menu
# ==============================================================================
# FLUXO DE PROMOÇÃO OBRIGATÓRIA (NOCAUTES)
# ==============================================================================

## Abre o popup de promoção obrigatória e retorna o animal escolhido.
## NÃO aplica a promoção — quem aplica é sempre o BattleManager,
## via HumanAgent.decidir_promocao_ativo() → resolver_promocao_pendente().
func exibir_popup_promocao_obrigatoria(jogador_id: int) -> AnimalInstance:
	var banco := GameState.obter_banco(jogador_id)
	if banco.is_empty():
		return null

	botao_passar_turno.disabled = true
	var popup := PopupPromocao.new()
	add_child(popup)

	var resultado: AnimalInstance = null
	var concluido := false

	popup.promocao_confirmada.connect(func(_p_id: int, substituto: AnimalInstance):
		resultado = substituto
		concluido = true
	)

	popup.exibir(self, jogador_id, banco)

	while not concluido:
		await get_tree().process_frame

	if jogador_id == ID_JOGADOR_HUMANO:
		botao_passar_turno.disabled = false

	return resultado

# ==============================================================================
# MENUS CONTEXTUAIS — CONSTRUÇÃO, VALIDAÇÃO E EXIBIÇÃO
# ==============================================================================

func _construir_opcoes_menu(carta: CardBaseResource, contexto: String, _instancia: AnimalInstance) -> Array[Dictionary]:
	var opcoes: Array[Dictionary] = []
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var ativo := GameState.obter_ativo(ID_JOGADOR_HUMANO)

	if carta is CardResource and carta.super_type == "animal":
		match contexto:
			"mao":
				if carta.stage == "Filhote":
					opcoes.append({"texto": "Reserva", "callback": _acao_reserva.bind(carta)})
				elif _existe_alvo_de_crescimento(carta, ID_JOGADOR_HUMANO):
					opcoes.append({"texto": "Crescer", "callback": _iniciar_selecao_crescer.bind(carta)})

			"ativo":
				if _pode_exibir_opcao_retroceder(ativo, jogador):
					opcoes.append({"texto": "Retroceder", "callback": _iniciar_selecao_retroceder})
				
				if carta.text_ui != "":
					opcoes.append({"texto": "Habilidade", "callback": _acao_usar_habilidade.bind(carta)})
				
				var check_ataque := RuleValidator.validar_atacar(ID_JOGADOR_HUMANO)
				if check_ataque.get("sucesso", false):
					opcoes.append({"texto": "Atacar", "callback": _acao_atacar.bind(carta)})

			"banco":
				if carta.text_ui != "":
					opcoes.append({"texto": "Habilidade", "callback": _acao_usar_habilidade.bind(carta)})

	elif carta is EffectResource:
		match carta.super_type:
			"energia":
				if contexto == "mao" and not GameState.energia_anexada_neste_turno:
					opcoes.append({"texto": "Fortalecer", "callback": _iniciar_selecao_fortalecer.bind(carta)})
			"vestigio", "territorio":
				if contexto == "mao":
					opcoes.append({"texto": "Ativar", "callback": _acao_ativar_efeito.bind(carta)})
			"cataclismo":
				if contexto == "mao" and not GameState.cataclismo_jogado_neste_turno:
					opcoes.append({"texto": "Ativar", "callback": _acao_ativar_efeito.bind(carta)})

	return opcoes

func _pode_exibir_opcao_retroceder(ativo: AnimalInstance, jogador: PlayerState) -> bool:
	if ativo == null:
		return false

	var check_recuo := RuleValidator.validar_recuo(jogador, ativo.attached_energies)
	return check_recuo.get("sucesso", false)

func _existe_alvo_de_crescimento(carta_evolucao: CardResource, jogador_id: int) -> bool:
	var animais_campo := GameState.obter_animais_em_campo(jogador_id)
	for inst in animais_campo:
		var check_evo := RuleValidator.validar_evolucao(inst, carta_evolucao)
		if check_evo.get("sucesso", false):
			return true
	return false

func _fechar_menu_contextual() -> void:
	if is_instance_valid(menu_contextual_ativo):
		menu_contextual_ativo.queue_free()
	menu_contextual_ativo = null

# ==============================================================================
# CLEANUP
# ==============================================================================

func _exit_tree() -> void:
	print("[MesaUI] Executando cleanup em _exit_tree().")
	
	# Matar e limpar animações ativas de cartas
	for tween in dicionario_tweens_cartas.values():
		if is_instance_valid(tween):
			tween.kill()
	dicionario_tweens_cartas.clear()

	# Desconectar sinais do TurnManager de forma padronizada
	if TurnManager:
		if TurnManager.turno_iniciado.is_connected(_ao_turno_iniciado):
			TurnManager.turno_iniciado.disconnect(_ao_turno_iniciado)
		if TurnManager.turno_encerrado.is_connected(_ao_turno_encerrado):
			TurnManager.turno_encerrado.disconnect(_ao_turno_encerrado)
		if TurnManager.partida_encerrada.is_connected(_ao_partida_encerrada):
			TurnManager.partida_encerrada.disconnect(_ao_partida_encerrada)
