# ==============================================================================
# MesaDoTabuleiro — Camada de Renderização e Interface (UI)
# Renderiza o estado do jogo, gerencia interações do jogador e anima transições.
# NUNCA calcula regras — apenas reage a sinais dos managers (SetupManager,
# TurnManager) e lê estado de GameState/PlayerState.
#
# Ações do jogador que exigem validação de regra (jogar carta, atacar, usar
# habilidade, recuar) NÃO são executadas aqui. A UI apenas emite
# `acao_jogador_solicitada` — quem decide se a ação é válida e a aplica é o
# BattleManager (ainda esqueleto na nova arquitetura; ver TODOs abaixo).
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
const DURACAO_POPUP_ORDEM: float = 15.0  # Segundos até decidir sozinho, se o jogador não clicar

# Tamanhos dos slots, copiados do MesaJogador.tscn — usados pra
# escalar as cartas (nascem em 150x233, maiores que qualquer slot daqui).
const TAMANHO_SLOT_ATIVO: Vector2 = Vector2(128, 179)
const TAMANHO_SLOT_BANCO: Vector2 = Vector2(100, 145)
const ALTURA_MAO: float = 133.0

# ID fixo do jogador humano nesta cena. Se algum dia isso deixar de ser fixo
# (ex: espectador, replay), é só isso que precisa mudar.
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
@onready var painel_zoom: CardPreviewPanel = $zoom_slot  # Ajuste o caminho conforme sua árvore

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

# Pop-up ativo de qualquer etapa do setup (moeda, ordem, mulligan) —
# só um por vez, todos sequenciais, por isso uma variável só.
var _popup_setup_ativo: Control = null

# true enquanto o setup não termina. Usado só pra saber se o Animal
# Ativo inicial deve nascer virado pra baixo (os dois só viram de
# frente juntos, quando _ao_setup_concluido roda).
var _setup_em_andamento: bool = true

# Controle de seleção de alvo (Crescer, Fortalecer, Retroceder,
# Alimentar) — substitui o antigo sistema de arrasto (drag-and-drop),
# removido por gerar bug de estado: clicar numa segunda carta enquanto
# a primeira estava "grudada" no mouse sobrescrevia a variável de
# controle sem soltar a primeira, deixando-a órfã na árvore.
#
# Fluxo novo: clique na carta de origem -> menu contextual -> opção
# que precisa de alvo entra em "modo seleção" -> próximo clique num
# animal válido em campo completa a ação. ESC cancela a qualquer
# momento (ver _input).
var _selecao_alvo_ativa: bool = false
var _selecao_alvo_tipo: String = ""       # "crescer" | "fortalecer" | "retroceder" | "alimentar"
var _selecao_alvo_dados: Dictionary = {}  # dados extra da ação (indice_mao, carta, quantidade, etc)

# Animações
var dicionario_tweens_cartas: Dictionary = {}  # { CardUI: Tween }

# Sistema de zoom (integração com CardZoomManager)
var card_zoom_manager: Control = null
var menu_contextual_ativo: Control = null

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================

func _ready() -> void:
	_validar_referencias()
	_conectar_sinais_setup_manager()
	_conectar_sinais_turn_manager()
	_configurar_interface_inicial()

	print("✓ MesaDoTabuleiro inicializada com sucesso")

	# MatchData é só o "envelope" de transição entre a tela de seleção
	# de deck e esta cena — ver MatchData.gd. Quem de fato inicia a
	# partida é o SetupManager, não o GameState.
	SetupManager.iniciar_partida(MatchData.deck_pendente_j0, MatchData.deck_pendente_j1)
	MatchData.limpar()


func _process(delta: float) -> void:
	if turno_em_progresso:
		_atualizar_contador_turno(delta)


func _input(event: InputEvent) -> void:
	if not get_tree().root.is_ancestor_of(self):
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancelar_selecao_alvo()
		_fechar_menu_contextual()
		get_tree().root.set_input_as_handled()

# ==============================================================================
# VALIDAÇÃO E CONEXÃO DE SINAIS
# ==============================================================================

func _validar_referencias() -> void:
	var nodos_criticos: Array[String] = [
		"MesaContainer/LadoJogador/JogadorFlow/CombatRow/CampoAtivo",
		"MesaContainer/LadoOponente/OponenteRotator/OponenteFlow/CombatRow/CampoAtivo",
		"Button",
		"TimerTurno",
		"Progessbar"
	]

	for caminho_nodo in nodos_criticos:
		if not has_node(caminho_nodo):
			push_error("❌ Nó crítico não encontrado: " + caminho_nodo)

	card_zoom_manager = get_tree().root.find_child("CardZoomManager", true, false)


func _conectar_sinais_setup_manager() -> void:
	"""Conecta os sinais de SetupManager — todos existem hoje, mapeiam
	1:1 pras etapas oficiais de preparação da partida."""
	if not SetupManager:
		push_error("❌ SetupManager (Autoload) não está disponível!")
		return

	SetupManager.solicitar_lancamento_moeda.connect(_ao_solicitar_lancamento_moeda)
	SetupManager.sorteio_realizado.connect(_ao_sorteio_realizado)
	SetupManager.solicitar_escolha_ordem.connect(_ao_solicitar_escolha_ordem)
	SetupManager.mulligan_necessario.connect(_ao_mulligan_necessario)
	SetupManager.mulligan_realizado.connect(_ao_mulligan_realizado)
	SetupManager.solicitar_escolha_ativo.connect(_ao_solicitar_escolha_ativo)
	SetupManager.setup_concluido.connect(_ao_setup_concluido)


func _conectar_sinais_turn_manager() -> void:
	"""Requer o patch que adiciona turno_iniciado/turno_encerrado ao
	TurnManager — sem isso a UI não sabe quando os turnos mudam."""
	if not TurnManager:
		push_error("❌ TurnManager (Autoload) não está disponível!")
		return

	TurnManager.turno_iniciado.connect(_ao_turno_iniciado)
	TurnManager.turno_encerrado.connect(_ao_turno_encerrado)

	botao_passar_turno.pressed.connect(_ao_botao_passar_turno_pressionado)
	timer_turno.timeout.connect(_ao_timer_turno_expirado)


func _configurar_interface_inicial() -> void:
	botao_passar_turno.disabled = true
	progresso_turno.value = 0
	turno_em_progresso = false

# ==============================================================================
# CALLBACKS — SETUP DA PARTIDA (SetupManager)
# ==============================================================================

func _ao_solicitar_lancamento_moeda() -> void:
	"""Só o jogador humano vê esse botão — o sorteio é aleatório de
	qualquer forma, não faz sentido pedir pro oponente 'clicar' nele."""
	_fechar_popup_setup()

	var refs := HelperUI.criar_popup_base(
		self,
		"Sorteio",
		"Clique para lançar a moeda e ver quem começa."
	)
	var botao := Button.new()
	botao.text = "Lançar Moeda"
	botao.pressed.connect(func():
		_fechar_popup_setup()
		SetupManager.lancar_moeda()
	)
	refs["vbox"].add_child(botao)

	_popup_setup_ativo = refs["overlay"]


func _ao_sorteio_realizado(vencedor_id: int) -> void:
	print("🪙 Jogador %d venceu o sorteio." % vencedor_id)
	# O resultado é anunciado junto com o pop-up de escolha de ordem
	# (_ao_solicitar_escolha_ordem, emitido em seguida pelo SetupManager)
	# — não duplicamos aviso aqui.


func _ao_solicitar_escolha_ordem(vencedor_id: int) -> void:
	if vencedor_id == ID_JOGADOR_HUMANO:
		_exibir_popup_escolha_ordem(vencedor_id)
	else:
		# TODO(IA): enquanto não existe IA de verdade, o oponente
		# sempre decide jogar primeiro. Quando a IA existir, essa
		# decisão deve vir dela em vez de um valor fixo aqui.
		_exibir_popup_resultado_sorteio(vencedor_id)
		SetupManager.confirmar_escolha_ordem(vencedor_id, true)


func _ao_mulligan_necessario(jogador_id: int) -> void:
	if jogador_id != ID_JOGADOR_HUMANO:
		# Sem IA de verdade ainda: o oponente confirma na hora, sem
		# popup nem espera.
		SetupManager.confirmar_mulligan(jogador_id)
		return

	_fechar_popup_setup()

	var refs := HelperUI.criar_popup_base(
		self,
		"Mulligan necessário",
		"Sua mão não tem nenhum Animal Filhote. Ela será embaralhada de volta e uma nova mão será comprada."
	)
	var overlay: Control = refs["overlay"]

	var botao := Button.new()
	botao.text = "Confirmar"
	botao.pressed.connect(func(): _confirmar_mulligan_visual(jogador_id, overlay))
	refs["vbox"].add_child(botao)

	_popup_setup_ativo = overlay

	await get_tree().create_timer(DURACAO_POPUP_ORDEM).timeout
	# Guarda igual aos outros pop-ups de setup: se o jogador já
	# confirmou por clique antes do timeout, _popup_setup_ativo já foi
	# pra null (ou trocou de popup) e overlay já foi queue_free()ado —
	# sem essa checagem, o timeout tentaria chamar a função passando
	# um Control já destruído, o que crasha o jogo.
	if is_instance_valid(_popup_setup_ativo) and _popup_setup_ativo == overlay:
		_confirmar_mulligan_visual(jogador_id, overlay)


func _confirmar_mulligan_visual(jogador_id: int, popup_de_origem: Control) -> void:
	# Evita confirmar duas vezes (clique + timeout chegando quase
	# juntos, ou popup já fechado por outra etapa).
	if _popup_setup_ativo != popup_de_origem:
		return

	_fechar_popup_setup()
	SetupManager.confirmar_mulligan(jogador_id)


func _ao_mulligan_realizado(jogador_id: int, quantidade: int) -> void:
	# Notificação pós-fato, só log — a confirmação de verdade já
	# aconteceu em _ao_mulligan_necessario / _confirmar_mulligan_visual.
	print("🔀 Jogador %d fez %d mulligan(s)." % [jogador_id, quantidade])


func _ao_solicitar_escolha_ativo(jogador_id: int) -> void:
	if jogador_id == ID_JOGADOR_HUMANO:
		print("🦖 Jogador %d deve escolher o Animal Ativo inicial (clique num Filhote na mão)." % jogador_id)
		_jogador_aguardando_escolha_ativo = jogador_id
		organizar_cartas_nas_zonas(jogador_id)
		_exibir_texto_flutuante("Selecione um Animal Ativo", 2.0)
		# TODO(UI): destacar visualmente os Filhotes elegíveis na mão.
	else:
		# TODO(IA): sem IA real ainda, o oponente escolhe sozinho o
		# primeiro Filhote que aparecer na mão — só pra não travar o
		# setup em teste. Trocar por decisão de verdade quando a IA
		# existir.
		_auto_escolher_ativo_oponente(jogador_id)


func _auto_escolher_ativo_oponente(jogador_id: int) -> void:
	var jogador := _obter_player_state(jogador_id)

	for i in jogador.mao.size():
		var carta := jogador.mao[i]
		if carta is CardResource and carta.super_type == "animal" and carta.stage == "Filhote":
			SetupManager.confirmar_animal_ativo(jogador_id, i)
			return

	push_error("Oponente (Jogador %d) não tem Filhote na mão — mulligan deveria ter garantido isso." % jogador_id)


func _ao_setup_concluido() -> void:
	print("✅ Setup concluído. Partida iniciada!")

	# Os dois Animais Ativos iniciais nascem virados pra baixo durante
	# o setup (ver _adicionar_carta_na_zona) — aqui é onde eles viram
	# de frente, os dois "ao mesmo tempo" (mesmo frame).
	_setup_em_andamento = false

	organizar_cartas_nas_zonas(0)
	organizar_cartas_nas_zonas(1)
	atualizar_visual_comida(0)
	atualizar_visual_comida(1)
	atualizar_visual_deck(0, _obter_player_state(0).deck.size())
	atualizar_visual_deck(1, _obter_player_state(1).deck.size())

# ==============================================================================
# POP-UP DE RESULTADO DO SORTEIO / ESCOLHA DE ORDEM
# ==============================================================================

func _exibir_popup_escolha_ordem(vencedor_id: int) -> void:
	"""Pop-up com escolha real: o jogador humano venceu o sorteio e
	decide se joga primeiro ou deixa o oponente começar. Se ele não
	decidir a tempo, o pop-up fecha sozinho aplicando o padrão (jogar
	primeiro) — mesmo padrão de timeout já usado no menu contextual
	de cartas (_abrir_menu_generico)."""
	_fechar_popup_setup()

	var refs := HelperUI.criar_popup_base(
		self,
		"Você venceu o sorteio!",
		"Escolha se quer jogar primeiro ou deixar o oponente começar."
	)
	var overlay: Control = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	var botao_primeiro := Button.new()
	botao_primeiro.text = "Jogar Primeiro"
	botao_primeiro.pressed.connect(func(): _confirmar_ordem_escolhida(vencedor_id, true))
	vbox.add_child(botao_primeiro)

	var botao_segundo := Button.new()
	botao_segundo.text = "Deixar Oponente Começar"
	botao_segundo.pressed.connect(func(): _confirmar_ordem_escolhida(vencedor_id, false))
	vbox.add_child(botao_segundo)

	_popup_setup_ativo = overlay

	await get_tree().create_timer(DURACAO_POPUP_ORDEM).timeout
	if is_instance_valid(_popup_setup_ativo) and _popup_setup_ativo == overlay:
		_confirmar_ordem_escolhida(vencedor_id, true)


func _exibir_popup_resultado_sorteio(vencedor_id: int) -> void:
	"""Pop-up só informativo — usado quando quem venceu o sorteio não
	é o jogador humano, então não há escolha pra fazer aqui, só aviso."""
	_fechar_popup_setup()

	var refs := HelperUI.criar_popup_base(
		self,
		"Jogador %d venceu o sorteio!" % vencedor_id,
		"O oponente decidiu jogar primeiro."
	)
	_popup_setup_ativo = refs["overlay"]

	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(_popup_setup_ativo) and _popup_setup_ativo == refs["overlay"]:
		_fechar_popup_setup()


func _confirmar_ordem_escolhida(vencedor_id: int, quer_jogar_primeiro: bool) -> void:
	_fechar_popup_setup()
	SetupManager.confirmar_escolha_ordem(vencedor_id, quer_jogar_primeiro)


func _fechar_popup_setup() -> void:
	if is_instance_valid(_popup_setup_ativo):
		_popup_setup_ativo.queue_free()
	_popup_setup_ativo = null

# ==============================================================================
# CALLBACKS — TURNOS E FASES (TurnManager)
# ==============================================================================
func _ao_turno_iniciado(jogador_id: int) -> void:
	# === ADICIONE ESTAS 4 LINHAS AQUI ===
	var p0 := _obter_player_state(0)
	var p1 := _obter_player_state(1)
	_atualizar_visual_contador_comida(0, p0.comida_disponivel)
	_atualizar_visual_contador_comida(1, p1.comida_disponivel)
	# ====================================

	jogador_ativo_id = jogador_id
	turno_em_progresso = true
	tempo_restante_turno = timer_turno.wait_time

	botao_passar_turno.disabled = (jogador_id != ID_JOGADOR_HUMANO)

	if timer_turno.is_stopped():
		timer_turno.start()

	print("🟢 Turno iniciado! Jogador: %d | Tempo: %.1fs" % [jogador_id, tempo_restante_turno])

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
	tempo_restante_turno = maxf(tempo_restante_turno - delta, 0.0)
	progresso_turno.value = (1.0 - (tempo_restante_turno / timer_turno.wait_time)) * 100

	if fmod(tempo_restante_turno, 10.0) < delta:
		print("⏱️ Tempo restante: %.1fs" % tempo_restante_turno)


func _ao_timer_turno_expirado() -> void:
	print("⚠️ Tempo do turno expirado! Forçando avanço automático...")
	_ao_botao_passar_turno_pressionado()


func _ao_botao_passar_turno_pressionado() -> void:
	"""Chamado quando o jogador clica em 'Passar Turno'. Vai direto pra
	fase final — pular pra ATAQUE é uma escolha do jogador via botão de
	atacar (menu contextual), não deste botão."""
	if jogador_ativo_id != ID_JOGADOR_HUMANO:
		print("⚠️ Não é o seu turno!")
		return

	TurnManager.fase_final()
	turno_em_progresso = false

# ==============================================================================
# TODO(core): SINAIS QUE AINDA NÃO EXISTEM
#
# Os pontos abaixo dependiam, na arquitetura antiga, de sinais emitidos
# pelo GameState (animal_nocauteado, condicao_aplicada,
# alimentacao_distribuida, vitoria, empate). Hoje ConditionSystem,
# KnockoutSystem e FoodSystem são "calculadoras" puras — não emitem
# nada, só calculam quando chamadas.
#
# Isso significa que, por enquanto, esta cena NÃO reage automaticamente
# a nocautes/condições/comida/vitória. Os métodos públicos abaixo
# (atualizar_visual_condicao, atualizar_visual_comida,
# animar_animal_nocauteado, _exibir_tela_vitoria, _exibir_tela_empate)
# continuam existindo e funcionam se chamados — falta só quem os chame
# no momento certo. O candidato natural é o BattleManager (ainda
# esqueleto) coordenando CombatSystem -> DamageSystem -> KnockoutSystem
# e emitindo sinais próprios ao final de cada resolução, e um sistema
# de vitória ainda não escrito validando RuleValidator.validate_*_victory().
# ==============================================================================

func atualizar_visual_condicao(jogador_id: int) -> void:
	"""Chamar depois de qualquer ação que possa ter mudado a condição
	especial do Animal Ativo de um jogador."""
	var jogador := _obter_player_state(jogador_id)
	if jogador.ativo == null:
		return

	var tipo: ConditionSystem.Tipo = ConditionSystem.obter_condicao(jogador.ativo)
	_renderizar_condicao(jogador_id, tipo)


func atualizar_visual_comida(jogador_id: int) -> void:
	"""Chamar depois de qualquer ação que possa ter mudado a comida
	disponível de um jogador (ex: fase de comida, alimentar manual)."""
	var jogador := _obter_player_state(jogador_id)
	_atualizar_visual_contador_comida(jogador_id, jogador.comida_disponivel)


func animar_animal_nocauteado(jogador_id: int, instancia: AnimalInstance) -> void:
	print("💥 Animal Nocauteado: %s (Jogador %d)" % [instancia.card.name, jogador_id])

	var campo_origem: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
	var zona_descarte: Panel = jogador_zona_descarte if jogador_id == 0 else oponente_zona_descarte

	# O filho direto do campo_ativo agora é o envelope (ver
	# _adicionar_carta_na_zona), não mais a carta visual crua — mas
	# como o envelope também é um Control comum, animar seu
	# global_position tem exatamente o mesmo efeito visual de animar a
	# carta diretamente, então nenhuma outra mudança é necessária aqui.
	var envelope := _get_first_child_of_type(campo_origem, Control)
	if envelope != null:
		_animar_carta_para_zona(envelope, zona_descarte)


func _ao_vitoria(jogador_id: int) -> void:
	print("🏆 VITÓRIA! Jogador %d venceu!" % jogador_id)
	_exibir_tela_vitoria(jogador_id)
	turno_em_progresso = false


func _ao_empate() -> void:
	print("🤝 EMPATE!")
	_exibir_tela_empate()
	turno_em_progresso = false

# ==============================================================================
# DECK E COMPRA DE CARTAS
# ==============================================================================

func comprar_carta_animada(jogador_id: int, carta: CardBaseResource) -> void:
	var zona_deck: Panel = jogador_zona_deck if jogador_id == 0 else oponente_zona_deck
	var mao_container: HBoxContainer = jogador_mao if jogador_id == 0 else oponente_mao

	var eh_oponente: bool = jogador_id != ID_JOGADOR_HUMANO
	var carta_visual: Control = _criar_carta_ui(carta, eh_oponente)
	carta_visual.global_position = zona_deck.global_position
	add_child(carta_visual)

	_animar_carta_para_zona(carta_visual, mao_container)

	print("🃏 Carta comprada animada: %s (Jogador %d)" % [carta.name, jogador_id])


func atualizar_visual_deck(jogador_id: int, cartas_restantes: int) -> void:
	"""Desenha a pilha do deck como cartas de verso empilhadas (padrão
	físico de TCG), com o total de cartas restantes embaixo.

	TODO(core): não existe hoje um sinal de "carta comprada" — nem
	DrawSystem (puro/estático) nem TurnManager emitem nada quando
	compram. Por enquanto isso só é chamado uma vez, em
	_ao_setup_concluido(). Precisa ser chamado de novo a cada compra
	assim que esse sinal existir, senão a pilha visual fica
	desatualizada durante a partida."""
	const MAX_CARTAS_VISIVEIS := 6
	const OFFSET_PILHA := Vector2(1.5, -1.5)

	var zona_deck: Panel = jogador_zona_deck if jogador_id == 0 else oponente_zona_deck

	for child in zona_deck.get_children():
		child.queue_free()

	if cartas_restantes <= 0:
		print("📚 Deck vazio (Jogador %d)" % jogador_id)
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

	print("📚 Deck atualizado: %d cartas restantes (Jogador %d)" % [cartas_restantes, jogador_id])

# ==============================================================================
# GERENCIAMENTO DE ZONAS E DRAG & DROP
# ==============================================================================

func organizar_cartas_nas_zonas(jogador_id: int) -> void:
	"""Reorganiza todas as cartas do jogador em suas respectivas zonas,
	lendo direto do PlayerState (GameState.jogador_1 / jogador_2)."""
	var jogador := _obter_player_state(jogador_id)

	_limpar_zona(jogador_id, "mao")
	_limpar_zona(jogador_id, "banco")
	_limpar_zona(jogador_id, "ativo")
	_limpar_zona(jogador_id, "descarte")

	for carta_base in jogador.mao:
		_adicionar_carta_na_zona(jogador_id, "mao", carta_base)

	for instancia in jogador.banco:
		_adicionar_carta_na_zona(jogador_id, "banco", instancia.card, instancia)

	if jogador.ativo != null:
		_adicionar_carta_na_zona(jogador_id, "ativo", jogador.ativo.card, jogador.ativo)


func _adicionar_carta_na_zona(jogador_id: int, zona_nome: String, carta: CardBaseResource, instancia: AnimalInstance = null) -> void:
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
				card_visual.mouse_entered.connect(func(): _abrir_zoom_leitura(card_visual, carta))
				card_visual.mouse_exited.connect(func(): _fechar_zoom_leitura())

		"ativo":
			var campo_ativo: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
			
			var grupo_cartas := Control.new()
			grupo_cartas.name = "GrupoAtivo"
			grupo_cartas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			campo_ativo.add_child(grupo_cartas)

			var deslocamento_x : float = 0.0
			var deslocamento_y : float = 0.0
			var passo_x : float = 10.0
			var passo_y : float = 12.0

			# 1. Instancia as energias PRIMEIRO (Ficam atrás na árvore de nós)
			if instancia is AnimalInstance:
				for energia_carta in instancia.attached_energies:
					deslocamento_x += passo_x
					deslocamento_y += passo_y
					
					var res_energia := HelperUI.instanciar_carta_escalada(energia_carta, TAMANHO_SLOT_ATIVO, false)
					if not res_energia.is_empty():
						var env_energia: Control = res_energia["envelope"]
						var vis_energia = res_energia["visual"]
						
						grupo_cartas.add_child(env_energia)
						_centralizar_envelope_no_painel(env_energia)
						
						# Aplica a cascata diagonal apenas nas energias
						env_energia.offset_left += deslocamento_x
						env_energia.offset_right += deslocamento_x
						env_energia.offset_top += deslocamento_y
						env_energia.offset_bottom += deslocamento_y
						
						vis_energia.mouse_entered.connect(func(): _abrir_zoom_leitura(vis_energia, energia_carta))
						vis_energia.mouse_exited.connect(func(): _fechar_zoom_leitura())

			# 2. Instancia o Animal POR ÚLTIMO (Fica na frente de todas as energias)
			var resultado := HelperUI.instanciar_carta_escalada(carta, TAMANHO_SLOT_ATIVO, face_para_baixo)
			if resultado.is_empty():
				return
			var envelope: Control = resultado["envelope"]
			var card_visual = resultado["visual"]
			
			grupo_cartas.add_child(envelope)
			_centralizar_envelope_no_painel(envelope)
			
			# Animal NÃO recebe deslocamento (Fica na origem exata do slot)

			if jogador_id == ID_JOGADOR_HUMANO:
				_configurar_inputs_carta(card_visual, carta, jogador_id, "ativo", instancia)
			
			if not face_para_baixo:
				card_visual.mouse_entered.connect(func(): _abrir_zoom_leitura(card_visual, carta))
				card_visual.mouse_exited.connect(func(): _fechar_zoom_leitura())

		"banco":
			var slots_banco: HBoxContainer = jogador_slots_banco if jogador_id == 0 else oponente_slots_banco
			
			var slot_disponivel: Control = null
			for slot in slots_banco.get_children():
				if slot.get_child_count() == 0:
					slot_disponivel = slot
					break
			
			if slot_disponivel != null:
				var grupo_cartas := Control.new()
				grupo_cartas.name = "GrupoBanco"
				grupo_cartas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				slot_disponivel.add_child(grupo_cartas)

				var deslocamento_x : float = 0.0
				var deslocamento_y : float = 0.0
				var passo_x : float = 10.0
				var passo_y : float = 12.0

				# 1. Instancia as energias PRIMEIRO
				if instancia is AnimalInstance:
					for energia_carta in instancia.attached_energies:
						deslocamento_x += passo_x
						deslocamento_y += passo_y
						
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
							
							vis_energia.mouse_entered.connect(func(): _abrir_zoom_leitura(vis_energia, energia_carta))
							vis_energia.mouse_exited.connect(func(): _fechar_zoom_leitura())

				# 2. Instancia o Animal POR ÚLTIMO
				var resultado := HelperUI.instanciar_carta_escalada(carta, TAMANHO_SLOT_BANCO, face_para_baixo)
				if resultado.is_empty():
					return
				var card_visual = resultado["visual"]
				var envelope: Control = resultado["envelope"]
				
				grupo_cartas.add_child(envelope)
				_centralizar_envelope_no_painel(envelope)
				
				# Animal NÃO recebe deslocamento

				if jogador_id == ID_JOGADOR_HUMANO:
					_configurar_inputs_carta(card_visual, carta, jogador_id, "banco", instancia)
				
				card_visual.mouse_entered.connect(func(): _abrir_zoom_leitura(card_visual, carta))
				card_visual.mouse_exited.connect(func(): _fechar_zoom_leitura())

		"descarte":
			pass

## Centraliza um envelope (já com custom_minimum_size correto) dentro
## do Panel pai via anchors — substitui o antigo
## _aplicar_escala_e_centralizar_ativo. Não precisa de call_deferred:
## HelperUI.instanciar_carta_escalada calcula o tamanho final na hora,
## então a centralização roda no mesmo frame, sem esperar layout
## nenhum.
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
	if not carta_visual.is_connected("gui_input", Callable(self, "_ao_input_carta")):
		carta_visual.gui_input.connect(_ao_input_carta.bindv([carta_visual, carta_resource, jogador_id, contexto, instancia]))


## Despachante único de clique em carta. Decide entre 3 caminhos,
## nesta ordem de prioridade:
##   1. Escolha do Animal Ativo inicial (setup) — comportamento especial.
##   2. Modo de seleção de alvo já ativo (Crescer/Fortalecer/Retroceder/
##      Alimentar esperando um animal) — clique tenta completar a ação
##      pendente, não abre menu novo.
##   3. Clique normal — abre o menu contextual com as opções válidas
##      pra esta carta neste contexto (mão/ativo/banco).
##
## `contexto` é "mao" | "ativo" | "banco". `instancia` é a
## AnimalInstance correspondente quando o contexto é "ativo"/"banco"
## (null pra "mao", onde o animal ainda não existe em campo) — precisa
## ser a instância, não só a carta, porque duas cópias da mesma
## espécie no Banco compartilham o mesmo CardResource e ficariam
## ambíguas se identificássemos só pela carta.
func _ao_input_carta(event: InputEvent, carta_visual: Control, carta_resource: CardBaseResource, jogador_id: int, contexto: String, instancia: AnimalInstance) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		_abrir_zoom_leitura(carta_visual, carta_resource)
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _jogador_aguardando_escolha_ativo == jogador_id:
		_tentar_confirmar_ativo_inicial(jogador_id, carta_resource)
		return

	if _selecao_alvo_ativa:
		_tentar_completar_selecao_alvo(instancia, contexto)
		return

	# Menu de ações só existe pras próprias cartas do jogador humano —
	# cartas do oponente continuam só com zoom (botão direito, acima).
	if jogador_id != ID_JOGADOR_HUMANO:
		return

	var opcoes: Array[Dictionary] = _construir_opcoes_menu(carta_resource, contexto, instancia)
	if opcoes.is_empty():
		return

	_abrir_menu_generico(carta_visual.global_position, opcoes)


func _tentar_confirmar_ativo_inicial(jogador_id: int, carta_resource: CardBaseResource) -> void:
	var jogador := _obter_player_state(jogador_id)
	var indice: int = jogador.mao.find(carta_resource)

	if indice == -1:
		return

	if SetupManager.confirmar_animal_ativo(jogador_id, indice):
		_jogador_aguardando_escolha_ativo = -1
		organizar_cartas_nas_zonas(jogador_id)
	else:
		_exibir_texto_flutuante("Selecione um Animal Filhote", 1.5)


# ==============================================================================
# CONSTRUÇÃO DO MENU — regra travada com o time:
# o TIPO/DADOS da carta decide QUAIS botões existem (Filhote não tem
# "Crescer", animal sem habilidade não tem "Habilidade" — o botão nem
# aparece). O ESTADO DO TURNO (já usou energia, já recuou, já jogou
# cataclismo) decide se um botão que EXISTE fica habilitado — isso já
# é responsabilidade do RuleValidator, checado antes de adicionar a
# opção na lista (se não pode, a opção simplesmente não entra —
# preferimos "não aparece" a "aparece cinza" pra manter o menu curto).
# ==============================================================================

func _construir_opcoes_menu(carta: CardBaseResource, contexto: String, instancia: AnimalInstance) -> Array[Dictionary]:
	var opcoes: Array[Dictionary] = []
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)

	if carta is CardResource and carta.super_type == "animal":
		match contexto:
			"mao":
				if carta.stage == "Filhote":
					opcoes.append({"texto": "Reserva", "callback": _acao_reserva.bind(carta)})
				elif _existe_alvo_de_crescimento(carta, jogador):
					opcoes.append({"texto": "Crescer", "callback": _iniciar_selecao_crescer.bind(carta)})

			"ativo":
				if RuleValidator.validate_retreat_possivel(jogador.ativo, jogador):
					opcoes.append({"texto": "Retroceder", "callback": _iniciar_selecao_retroceder})
				if carta.text_ui != "":
					opcoes.append({"texto": "Habilidade", "callback": _acao_usar_habilidade.bind(carta)})
				if RuleValidator.validate_attack(jogador.ativo, carta):
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


## Existe algum animal em campo (Ativo ou Banco) que essa carta possa
## evoluir? Usado só pra decidir se o botão "Crescer" aparece — a
## validação de verdade (turno, etc.) roda de novo na hora de
## executar, via RuleValidator.validate_evolution dentro do
## BattleManager.
func _existe_alvo_de_crescimento(carta_evolucao: CardResource, jogador: PlayerState) -> bool:
	for instancia in jogador.animais_em_campo():
		if RuleValidator.validate_evolution_line(instancia, carta_evolucao):
			return true
	return false

# ==============================================================================
# SISTEMA DE ZOOM E MENU CONTEXTUAL
# ==============================================================================

func _abrir_zoom_leitura(_carta_visual: Control, carta_resource: CardBaseResource) -> void:
	if painel_zoom:
		# Passamos o recurso direto. O painel se adapta se for CardResource ou EffectResource
		painel_zoom.exibir_preview(carta_resource, false)

func _fechar_zoom_leitura() -> void:
	if painel_zoom:
		painel_zoom.esconder_preview()

func _abrir_menu_generico(posicao_global: Vector2, opcoes: Array[Dictionary]) -> void:
	_fechar_menu_contextual()

	var menu: Panel = Panel.new()
	menu.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	menu.custom_minimum_size = Vector2(150, 36 * opcoes.size() + 20)
	menu.global_position = posicao_global + Vector2(100, 0)

	var vbox: VBoxContainer = VBoxContainer.new()
	menu.add_child(vbox)

	for opcao in opcoes:
		var botao: Button = Button.new()
		botao.text = opcao["texto"]
		botao.pressed.connect(func():
			_fechar_menu_contextual()
			opcao["callback"].call()
		)
		vbox.add_child(botao)

	add_child(menu)
	menu_contextual_ativo = menu

	await get_tree().create_timer(30.0).timeout
	if is_instance_valid(menu_contextual_ativo) and menu_contextual_ativo == menu:
		_fechar_menu_contextual()


func _fechar_menu_contextual() -> void:
	if is_instance_valid(menu_contextual_ativo):
		menu_contextual_ativo.queue_free()
	menu_contextual_ativo = null


# ==============================================================================
# MODO DE SELEÇÃO DE ALVO — Crescer, Fortalecer, Retroceder, Alimentar
# Todas essas ações precisam de um segundo clique (no animal-alvo) pra
# completar. Entram em modo de seleção via _iniciar_selecao_*, e são
# resolvidas em _tentar_completar_selecao_alvo quando o jogador clica
# num animal válido em campo (ver _ao_input_carta).
# ==============================================================================

func _iniciar_selecao_crescer(carta_evolucao: CardResource) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var indice_mao: int = jogador.mao.find(carta_evolucao)
	if indice_mao == -1:
		return

	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "crescer"
	_selecao_alvo_dados = {"indice_mao": indice_mao, "carta_evolucao": carta_evolucao}
	_exibir_texto_flutuante("Selecione o animal que vai crescer", 2.0)


func _iniciar_selecao_fortalecer(carta_energia: EffectResource) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var indice_mao: int = jogador.mao.find(carta_energia)
	if indice_mao == -1:
		return

	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "fortalecer"
	_selecao_alvo_dados = {"indice_mao": indice_mao, "carta": carta_energia}
	_exibir_texto_flutuante("Selecione o animal que vai receber a energia", 2.0)


func _iniciar_selecao_retroceder() -> void:
	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "retroceder"
	_selecao_alvo_dados = {}
	_exibir_texto_flutuante("Selecione o animal do Banco que vai substituir", 2.0)


func _iniciar_selecao_alimentar() -> void:
	_selecao_alvo_ativa = true
	_selecao_alvo_tipo = "alimentar"
	_selecao_alvo_dados = {}
	_exibir_texto_flutuante("Selecione o animal que vai se alimentar", 2.0)


func _cancelar_selecao_alvo() -> void:
	if not _selecao_alvo_ativa:
		return

	_selecao_alvo_ativa = false
	_selecao_alvo_tipo = ""
	_selecao_alvo_dados = {}


## Chamado quando o jogador clica num animal (Ativo ou Banco) enquanto
## há uma seleção de alvo pendente. `instancia` é a AnimalInstance
## clicada (null se o clique não foi num animal em campo — nesse
## caso ignoramos, o jogador precisa clicar num animal de verdade ou
## apertar ESC pra cancelar).
func _tentar_completar_selecao_alvo(instancia: AnimalInstance, contexto: String) -> void:
	if instancia == null or (contexto != "ativo" and contexto != "banco"):
		return

	match _selecao_alvo_tipo:
		"crescer":
			_acao_crescer(_selecao_alvo_dados["indice_mao"], _selecao_alvo_dados["carta_evolucao"], instancia)

		"fortalecer":
			_acao_fortalecer(_selecao_alvo_dados["indice_mao"], _selecao_alvo_dados["carta"], instancia)

		"retroceder":
			if contexto != "banco":
				_exibir_texto_flutuante("Escolha um animal do Banco", 1.5)
				return
			_acao_retroceder(instancia)

		"alimentar":
			_abrir_popup_quantidade_alimento(instancia)
			# Não fecha o modo de seleção aqui — o popup de quantidade
			# é quem decide (confirmar ou cancelar), ver função abaixo.
			return

	_cancelar_selecao_alvo()


## Popup simples de "quanto alimentar"
func _abrir_popup_quantidade_alimento(animal: AnimalInstance) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var maximo: int = jogador.comida_disponivel

	var refs := HelperUI.criar_popup_base(
		self,
		"Alimentar",
		"Pool disponível: %d" % maximo
	)
	var overlay: Control = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	# Criamos um dicionário para garantir que o escopo da variável 
	# seja compartilhado corretamente entre as lambdas (passagem por referência)
	var estado_popup := {
		"quantidade": 1
	}

	var label_quantidade := Label.new()
	label_quantidade.text = str(estado_popup["quantidade"])
	label_quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_quantidade.add_theme_font_size_override("font_size", 28)
	vbox.add_child(label_quantidade)

	var linha_botoes := HBoxContainer.new()
	linha_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(linha_botoes)

	var botao_menos := Button.new()
	botao_menos.text = "-"
	linha_botoes.add_child(botao_menos)

	var botao_mais := Button.new()
	botao_mais.text = "+"
	linha_botoes.add_child(botao_mais)

	botao_menos.pressed.connect(func():
		estado_popup["quantidade"] = maxi(1, estado_popup["quantidade"] - 1)
		label_quantidade.text = str(estado_popup["quantidade"])
	)
	
	botao_mais.pressed.connect(func():
		estado_popup["quantidade"] = mini(maximo, estado_popup["quantidade"] + 1)
		label_quantidade.text = str(estado_popup["quantidade"])
	)

	var botao_confirmar := Button.new()
	botao_confirmar.text = "Confirmar"
	botao_confirmar.pressed.connect(func():
		var quant_final: int = estado_popup["quantidade"]
		overlay.queue_free()
		_cancelar_selecao_alvo()
		_acao_alimentar(animal, quant_final)
	)
	vbox.add_child(botao_confirmar)

	var botao_cancelar := Button.new()
	botao_cancelar.text = "Cancelar"
	botao_cancelar.pressed.connect(func():
		overlay.queue_free()
		_cancelar_selecao_alvo()
	)
	vbox.add_child(botao_cancelar)


# ==============================================================================
# AÇÕES — cada uma chama BattleManager.processar_acao diretamente
# (é um autoload, acessível daqui), emite acao_jogador_solicitada pra
# quem mais quiser escutar (log, futuro replay), e reage ao resultado:
# sucesso -> refresca o tabuleiro; falha -> mostra o motivo.
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
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var custo: int = jogador.ativo.card.cost_retreat if jogador.ativo != null else 0

	if custo <= 0:
		_resolver_acao("recuar", {"substituto": substituto, "energias_para_descarte": []})
		return

	# Custo > 0: precisa que o jogador escolha QUAIS energias
	# descartar. Reaproveita a mesma ideia do menu genérico, mas com
	# uma lista construída a partir de attached_energies.
	_abrir_selecao_energias_para_recuo(substituto, custo)


func _ao_alternar_selecao_energia(pressionado: bool, energia: EffectResource, selecionadas: Array) -> void:
	if pressionado and not selecionadas.has(energia):
		selecionadas.append(energia)
	elif not pressionado and selecionadas.has(energia):
		selecionadas.erase(energia)


func _abrir_selecao_energias_para_recuo(substituto: AnimalInstance, custo: int) -> void:
	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var ativo: AnimalInstance = jogador.ativo

	if ativo.attached_energies.size() < custo:
		_exibir_texto_flutuante("Energia insuficiente pra recuar", 1.5)
		return

	var refs := HelperUI.criar_popup_base(
		self,
		"Pagar custo de recuo",
		"Escolha %d energia(s) pra descartar" % custo
	)
	var overlay: Control = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	var selecionadas: Array = []

	for energia in ativo.attached_energies:
		var botao := Button.new()
		botao.text = str(energia.name)
		botao.toggle_mode = true
		botao.toggled.connect(_ao_alternar_selecao_energia.bindv([energia, selecionadas]))
		vbox.add_child(botao)

	var botao_confirmar := Button.new()
	botao_confirmar.text = "Confirmar"
	botao_confirmar.pressed.connect(func():
		if selecionadas.size() != custo:
			_exibir_texto_flutuante("Selecione exatamente %d energia(s)" % custo, 1.5)
			return
		overlay.queue_free()
		_resolver_acao("recuar", {"substituto": substituto, "energias_para_descarte": selecionadas})
	)
	vbox.add_child(botao_confirmar)


func _acao_alimentar(animal: AnimalInstance, quantidade: int) -> void:
	_resolver_acao("distribuir_comida", {"animal": animal, "quantidade": quantidade})


func _acao_atacar(carta: CardResource) -> void:
	var resultado := _resolver_acao("atacar", {"ataque": carta}, false)
	if resultado.get("sucesso", false):
		_animar_ataque(carta)


func _acao_usar_habilidade(carta: CardBaseResource) -> void:
	# Ainda não existe intérprete de AbilityResource/text_ui no
	# projeto — fora do escopo do Turno 1. O botão aparece (porque a
	# carta tem texto de habilidade), mas por enquanto só avisa.
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

	# Território substitui o que já estiver ativo (é global, ver
	# GameState.territorio_ativo) — confirmação antes de resolver.
	if carta.super_type == "territorio" and GameState.territorio_ativo != null:
		_confirmar_substituicao_territorio(indice_mao, carta, tipo_acao)
		return

	_resolver_acao(tipo_acao, {"indice_mao": indice_mao, "carta": carta})


func _confirmar_substituicao_territorio(indice_mao: int, carta: EffectResource, tipo_acao: String) -> void:
	var refs := HelperUI.criar_popup_base(
		self,
		"Substituir Território?",
		"Isso vai descartar o território ativo atual."
	)
	var overlay: Control = refs["overlay"]

	var botao_confirmar := Button.new()
	botao_confirmar.text = "Confirmar"
	botao_confirmar.pressed.connect(func():
		overlay.queue_free()
		_resolver_acao(tipo_acao, {"indice_mao": indice_mao, "carta": carta})
	)
	refs["vbox"].add_child(botao_confirmar)

	var botao_cancelar := Button.new()
	botao_cancelar.text = "Cancelar"
	botao_cancelar.pressed.connect(func(): overlay.queue_free())
	refs["vbox"].add_child(botao_cancelar)


## Ponto único de saída pra qualquer ação: chama o BattleManager,
## emite o sinal público (observabilidade externa), e reage ao
## resultado. `refrescar_automatico=false` é usado só por "atacar",
## porque ele já dispara sua própria animação antes do refresh.
func _resolver_acao(tipo_acao: String, dados: Dictionary, refrescar_automatico: bool = true) -> Dictionary:
	var resultado: Dictionary = BattleManager.processar_acao(tipo_acao, dados)
	acao_jogador_solicitada.emit(tipo_acao, dados)

	if resultado.get("sucesso", false):
		# VERIFICAÇÃO DE BLOQUEIO: Se o ataque nocauteou alguém e exige promoção
		if resultado.get("status") == "aguardando_promocao":
			var jogador_bloqueado_id: int = resultado.get("jogador_bloqueado")
			exibir_popup_promocao_obrigatoria(jogador_bloqueado_id)
		
		# Fluxo normal sem mortes/bloqueios
		elif refrescar_automatico:
			_refrescar_tabuleiro()
	else:
		var motivo: String = resultado.get("motivo", "acao_invalida")
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


## Re-renderiza os dois lados do tabuleiro após qualquer ação bem
## sucedida. Simples e sempre correto; otimizar (renderizar só o que
## mudou) fica pra depois, quando performance virar problema de
## verdade — não é ainda.
func _refrescar_tabuleiro() -> void:
	organizar_cartas_nas_zonas(0)
	organizar_cartas_nas_zonas(1)
	atualizar_visual_comida(0)
	atualizar_visual_comida(1)

# ==============================================================================
# ANIMAÇÕES VISUAIS
# ==============================================================================

func _animar_carta_para_zona(carta_visual: Control, zona_alvo: Control, duracao: float = DURACAO_ANIMACAO_CARTA) -> void:
	if dicionario_tweens_cartas.has(carta_visual):
		dicionario_tweens_cartas[carta_visual].kill()

	var tween: Tween = create_tween()
	dicionario_tweens_cartas[carta_visual] = tween

	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

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


func _animar_ataque(carta: CardResource) -> void:
	var campo_ativo: Panel = jogador_campo_ativo
	if campo_ativo.get_child_count() == 0:
		return

	# O filho direto do campo_ativo é o envelope, não a carta. Precisa
	# furar mais um nível pra chegar na carta visual de verdade.
	var envelope := _get_first_child_of_type(campo_ativo, Control)
	if envelope == null or envelope.get_child_count() == 0:
		return

	var carta_visual: Control = envelope.get_child(0) as Control
	if carta_visual == null:
		return

	# BUG CORRIGIDO: a versão anterior fazia
	# `carta_visual.scale = Vector2(1.2, 1.2)` — um valor ABSOLUTO.
	# Isso sobrescrevia a escala correta calculada por
	# HelperUI.instanciar_carta_escalada (ex.: 0.55 pro slot ativo),
	# fazendo a carta "explodir" pro tamanho de uma carta não escalada
	# durante o pulso de ataque. O pulso agora é relativo à escala de
	# repouso da própria carta.
	var escala_base: Vector2 = carta_visual.scale
	var escala_pulso: Vector2 = escala_base * 1.15

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(carta_visual, "scale", escala_pulso, 0.1)
	tween.tween_property(carta_visual, "scale", escala_base, 0.1)
	tween.tween_property(carta_visual, "scale", escala_pulso, 0.1)
	tween.tween_property(carta_visual, "scale", escala_base, 0.1)


func _exibir_texto_flutuante(texto: String, duracao: float) -> void:
	"""Substitui o antigo _animar_lancamento_moeda — generalizado pra
	qualquer mensagem central de curta duração (resultado de sorteio,
	etc.), evitando duplicar a mesma animação de Label pra cada caso."""
	var label: Label = Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 48)
	label.global_position = get_viewport().get_visible_rect().get_center()
	add_child(label)

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(label, "modulate", Color.TRANSPARENT, duracao)
	tween.tween_callback(func(): label.queue_free())

# ==============================================================================
# FEEDBACKS VISUAIS — CONDIÇÕES E COMIDA
# ==============================================================================

func _renderizar_condicao(jogador_id: int, tipo: ConditionSystem.Tipo) -> void:
	var zona_condicao: Panel = jogador_condicao_especial if jogador_id == 0 else oponente_condicao_especial

	for child in zona_condicao.get_children():
		child.queue_free()

	if tipo == ConditionSystem.Tipo.NENHUMA:
		return

	var nome_condicao: String = ConditionSystem.Tipo.keys()[tipo]

	var condicao_visual: Label = Label.new()
	condicao_visual.text = nome_condicao
	condicao_visual.add_theme_font_size_override("font_size", 24)

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
	print("🔧 Visual de condição atualizado: %s" % nome_condicao)


func _atualizar_visual_contador_comida(jogador_id: int, pontos: int) -> void:
	var contador_panel: Panel = jogador_contador_comida if jogador_id == 0 else oponente_contador_comida

	for child in contador_panel.get_children():
		child.queue_free()

	var label_comida: Label = Label.new()
	label_comida.text = str(pontos)
	label_comida.add_theme_font_size_override("font_size", 32)
	label_comida.modulate = Color.ORANGE

	contador_panel.add_child(label_comida)

	if not contador_panel.is_connected("mouse_entered", Callable(self, "_ao_mouse_entrou_comida")):
		contador_panel.mouse_entered.connect(_ao_mouse_entrou_comida.bind(jogador_id))
		contador_panel.mouse_exited.connect(_ao_mouse_saiu_comida)

	# Só o pool do jogador humano é clicável — o pool do oponente é
	# só informativo (mesma lógica de por que cartas do oponente não
	# têm menu de ações).
	if jogador_id == ID_JOGADOR_HUMANO and not contador_panel.is_connected("gui_input", Callable(self, "_ao_input_zona_comida")):
		contador_panel.gui_input.connect(_ao_input_zona_comida)

	print("🍖 Contador de comida atualizado: %d pontos (Jogador %d)" % [pontos, jogador_id])


func _ao_input_zona_comida(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if _selecao_alvo_ativa:
		return

	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	if jogador.comida_disponivel <= 0:
		_exibir_texto_flutuante("Sem pontos de comida no pool", 1.5)
		return

	_abrir_menu_generico(
		jogador_contador_comida.global_position + Vector2(0, -60),
		[{"texto": "Alimentar", "callback": _iniciar_selecao_alimentar}]
	)


func _ao_mouse_entrou_comida(jogador_id: int) -> void:
	var jogador := _obter_player_state(jogador_id)
	print("ℹ️ Hover em contador de comida: %d pontos" % jogador.comida_disponivel)


func _ao_mouse_saiu_comida() -> void:
	pass

# ==============================================================================
# TELAS FINAIS
# ==============================================================================

func _exibir_tela_vitoria(ganhador_id: int) -> void:
	_exibir_tela_final("🏆 JOGADOR %d VENCEU! 🏆" % ganhador_id, Color.BLACK)
	print("🏆 Tela de vitória exibida para Jogador: %d" % ganhador_id)


func _exibir_tela_empate() -> void:
	_exibir_tela_final("🤝 EMPATE! 🤝", Color.GRAY)
	print("🤝 Tela de empate exibida")


func _exibir_tela_final(texto: String, cor_fundo: Color) -> void:
	var tela: Panel = Panel.new()
	tela.anchor_left = 0
	tela.anchor_top = 0
	tela.anchor_right = 1
	tela.anchor_bottom = 1

	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = cor_fundo
	tela.add_theme_stylebox_override("panel", stylebox)

	var label: Label = Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 64)
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.offset_left = -250
	label.offset_top = -50

	tela.add_child(label)
	add_child(tela)

# ==============================================================================
# MÉTODOS AUXILIARES
# ==============================================================================

func _obter_player_state(jogador_id: int) -> PlayerState:
	return GameState.jogador_1 if jogador_id == 0 else GameState.jogador_2


func _criar_carta_ui(carta: CardBaseResource, face_para_baixo: bool = false) -> Control:
	return HelperUI.instanciar_carta(carta, face_para_baixo)

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
			# Remove os filhos imediatamente da árvore para que o slot
			# seja detectado como vazio no mesmo frame, depois libera a memória.
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

func _get_first_child_of_type(parent: Node, tipo: Object) -> Control:
	for child in parent.get_children():
		if is_instance_of(child, tipo):
			return child as Control
	return null

# =============================================================================
# FLUXO DE PROMOÇÃO OBRIGATÓRIA (NOCAUTES)
# =============================================================================

## Abre o pop-up temporário exigindo que o jogador escolha um substituto do banco.
func exibir_popup_promocao_obrigatoria(jogador_id: int) -> void:
	# 1. Recupera o jogador que precisa promover do GameState
	var jogador_alvo = GameState.jogador_1 if jogador_id == 0 else GameState.jogador_2
	
	# Desativa o botão de passar turno para impedir que o jogo prossiga travado
	botao_passar_turno.disabled = true
	
	# 2. Como você não tem as artes prontas, criamos um Pop-up simples via código
	var popup = ConfirmationDialog.new()
	popup.title = "PROMOÇÃO OBRIGATÓRIA"
	popup.dialog_text = "Seu animal ativo foi nocauteado! Escolha um substituto do seu Banco:"
	
	# Remove os botões padrão de OK/Cancel para não deixar fechar sem escolher
	popup.get_cancel_button().visible = false
	popup.get_ok_button().visible = false
	
	# Container para listar os animais disponíveis no banco
	var container_botoes = VBoxContainer.new()
	popup.add_child(container_botoes)
	
	# 3. Cria um botão para cada animal que está no banco do jogador
	for animal in jogador_alvo.banco:
		var botao_animal = Button.new()
		# Exibe o nome do animal e sua vida restante
		botao_animal.text = "%s (HP: %d/%d)" % [animal.card.name, animal.current_hp, animal.card.hp]
		
		# Quando clicado, envia a ação de promoção e fecha o popup
		botao_animal.pressed.connect(func():
			_confirmar_promocao(jogador_id, animal)
			popup.queue_free()
		)
		container_botoes.add_child(botao_animal)
		
	# Adiciona o popup na mesa e o exibe centralizado
	add_child(popup)
	popup.popup_centered(Vector2i(400, 200))

## Dispara o sinal que o BattleManager está esperando para realizar a promoção física
func _confirmar_promocao(jogador_id: int, substituto: AnimalInstance) -> void:
	# Reabilita o botão de passar turno
	botao_passar_turno.disabled = false
	
	# Envia a ação para o gerenciador de batalha
	acao_jogador_solicitada.emit("promover_ativo", {
		"jogador_id": jogador_id,
		"substituto": substituto
	})

# ==============================================================================
# CLEANUP
# ==============================================================================

func _exit_tree() -> void:
	for tween in dicionario_tweens_cartas.values():
		if tween:
			tween.kill()

	if TurnManager and TurnManager.turno_iniciado.is_connected(_ao_turno_iniciado):
		TurnManager.turno_iniciado.disconnect(_ao_turno_iniciado)
	if TurnManager and TurnManager.turno_encerrado.is_connected(_ao_turno_encerrado):
		TurnManager.turno_encerrado.disconnect(_ao_turno_encerrado)
# ==============================================================================
# FIM DO SCRIPT
# ==============================================================================
