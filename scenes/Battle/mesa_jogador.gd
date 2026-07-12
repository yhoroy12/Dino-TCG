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
const DISTANCIA_SNAP_ZONAS: float = 50.0  # Pixels

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

# Controle de cartas
var carta_selecionada: Control = null
var carta_em_arrasto: Control = null
var offset_arrasto: Vector2 = Vector2.ZERO
var zona_alvo_potencial: Control = null

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

	if carta_em_arrasto != null and is_instance_valid(carta_em_arrasto):
		_processar_arrasto_carta()


func _input(event: InputEvent) -> void:
	if not get_tree().root.is_ancestor_of(self):
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancelar_arrasto()
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
	de cartas (_abrir_menu_contextual)."""
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
		_adicionar_carta_na_zona(jogador_id, "banco", instancia.card)

	if jogador.ativo != null:
		_adicionar_carta_na_zona(jogador_id, "ativo", jogador.ativo.card)


func _adicionar_carta_na_zona(jogador_id: int, zona_nome: String, carta: CardBaseResource) -> void:
	# Convenção de TCG: só a mão é informação escondida — mas o Animal
	# Ativo inicial também fica virado pra baixo enquanto o setup
	# ainda está rolando (os dois viram juntos em _ao_setup_concluido).
	# Fora do setup, ativo/banco/descarte são sempre públicos, de frente.
	var eh_mao_do_oponente: bool = (zona_nome == "mao" and jogador_id != ID_JOGADOR_HUMANO)
	var eh_ativo_inicial_escondido: bool = (zona_nome == "ativo" and _setup_em_andamento)
	var face_para_baixo: bool = eh_mao_do_oponente or eh_ativo_inicial_escondido

	# Padrão do envelope (mesmo do deck_builder.gd, agora centralizado
	# em HelperUI.instanciar_carta_escalada): o Container/Panel-pai só
	# enxerga um Control vazio com custom_minimum_size já correto; a
	# carta real fica livre dentro dele, sem brigar por tamanho com
	# ninguém. Isso elimina a necessidade de call_deferred — a escala
	# é calculada matematicamente, não depende do _ready() da carta
	# nem do sort do Container.
	match zona_nome:
		"mao":
			var mao_container: HBoxContainer = jogador_mao if jogador_id == 0 else oponente_mao
			var resultado := HelperUI.instanciar_carta_escalada(carta, Vector2(9999, ALTURA_MAO), face_para_baixo)
			if resultado.is_empty():
				return
			mao_container.add_child(resultado["envelope"])

			# Carta da mão do oponente fica escondida (verso). Não
			# conectamos input nela: nem clique nem zoom devem expor
			# o que é.
			if jogador_id == ID_JOGADOR_HUMANO:
				_configurar_inputs_carta(resultado["visual"], carta, jogador_id)

		"ativo":
			var campo_ativo: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
			var resultado := HelperUI.instanciar_carta_escalada(carta, TAMANHO_SLOT_ATIVO, face_para_baixo)
			if resultado.is_empty():
				return
			var envelope: Control = resultado["envelope"]
			campo_ativo.add_child(envelope)
			_centralizar_envelope_no_painel(envelope)

		"banco":
			var slots_banco: HBoxContainer = jogador_slots_banco if jogador_id == 0 else oponente_slots_banco
			var resultado := HelperUI.instanciar_carta_escalada(carta, TAMANHO_SLOT_BANCO, face_para_baixo)
			if resultado.is_empty():
				return
			for slot in slots_banco.get_children():
				if slot.get_child_count() == 0:
					slot.add_child(resultado["envelope"])
					break

		"descarte":
			pass  # Descarte é apenas visual (pilha), não instancia carta a carta.


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


func _configurar_inputs_carta(carta_visual: Control, carta_resource: CardBaseResource, jogador_id: int) -> void:
	if not carta_visual.is_connected("gui_input", Callable(self, "_ao_input_carta")):
		carta_visual.gui_input.connect(_ao_input_carta.bindv([carta_visual, carta_resource, jogador_id]))


func _ao_input_carta(event: InputEvent, carta_visual: Control, carta_resource: CardBaseResource, jogador_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Durante a escolha do Animal Ativo inicial, clique na mão tem
		# um significado especial e não deve virar arrasto/menu normal.
		if _jogador_aguardando_escolha_ativo == jogador_id:
			_tentar_confirmar_ativo_inicial(jogador_id, carta_resource)
			return

	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_iniciar_arrasto_carta(carta_visual, carta_resource, jogador_id)
				MOUSE_BUTTON_RIGHT:
					_abrir_zoom_leitura(carta_visual, carta_resource)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_finalizar_arrasto_carta(carta_visual, carta_resource)


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


func _iniciar_arrasto_carta(carta_visual: Control, carta_resource: CardBaseResource, jogador_id: int) -> void:
	if jogador_id != ID_JOGADOR_HUMANO:
		return

	# Containers (a HandContainer é um HBoxContainer) reposicionam os
	# filhos sozinhos e brigam com qualquer position/global_position
	# manual. Pra arrastar de verdade, a carta precisa sair do
	# Container enquanto dura o arrasto — reparenta preservando a
	# posição visual, pra não dar um "pulo" perceptível.
	#
	# IMPORTANTE: carta_visual aqui é a carta "nua" (dentro do
	# envelope), não o envelope em si. Ao reparentar só ela pra fora
	# do envelope, o envelope-vazio fica órfão dentro da mão — por
	# isso removemos o envelope também, senão ele deixa um "buraco"
	# do tamanho de uma carta na HandContainer enquanto dura o arrasto.
	var envelope_origem: Node = carta_visual.get_parent()
	var pai_do_envelope: Node = envelope_origem.get_parent() if envelope_origem else null

	var posicao_global: Vector2 = carta_visual.global_position
	if envelope_origem:
		envelope_origem.remove_child(carta_visual)
	if pai_do_envelope and envelope_origem:
		pai_do_envelope.remove_child(envelope_origem)
		envelope_origem.queue_free()

	add_child(carta_visual)
	carta_visual.global_position = posicao_global

	carta_em_arrasto = carta_visual
	carta_selecionada = carta_visual
	offset_arrasto = carta_visual.get_local_mouse_position()

	carta_visual.z_index = 100
	carta_visual.modulate.a = 0.8

	print("👆 Arrasto iniciado: %s" % carta_resource.name)


func _processar_arrasto_carta() -> void:
	if carta_em_arrasto == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	carta_em_arrasto.global_position = mouse_pos - offset_arrasto

	_detectar_zona_alvo(carta_em_arrasto)


func _detectar_zona_alvo(carta_visual: Control) -> void:
	var zonas_potenciais: Array[Control] = [
		jogador_campo_ativo,
		jogador_slots_banco,
		jogador_zona_descarte
	]

	zona_alvo_potencial = null
	var distancia_minima: float = DISTANCIA_SNAP_ZONAS

	for zona in zonas_potenciais:
		var distancia: float = carta_visual.global_position.distance_to(zona.global_position)
		if distancia < distancia_minima:
			distancia_minima = distancia
			zona_alvo_potencial = zona
			zona.self_modulate = Color.YELLOW


func _cancelar_arrasto() -> void:
	if carta_em_arrasto == null:
		return

	# Não dá pra animar de volta pro slot certo dentro da
	# HandContainer (Container reposiciona filhos sozinho — tentar
	# tween.global_position é isso que causava as cartas empilhando no
	# canto). A carta nunca saiu de PlayerState.mao, só a visual foi
	# arrancada do Container (e o envelope original já foi destruído
	# em _iniciar_arrasto_carta) — então descarta essa visual órfã e
	# reconstrói a mão inteira (com um envelope novo), que a
	# HandContainer resolve o posicionamento sozinha.
	if is_instance_valid(carta_em_arrasto):
		carta_em_arrasto.queue_free()

	carta_em_arrasto = null
	carta_selecionada = null
	zona_alvo_potencial = null

	organizar_cartas_nas_zonas(ID_JOGADOR_HUMANO)


func _finalizar_arrasto_carta(carta_visual: Control, carta_resource: CardBaseResource) -> void:
	"""IMPORTANTE: esta função NÃO move mais a carta nem confia que a
	jogada deu certo. Não existe hoje um manager que aplique "jogar
	carta pro campo/banco" com validação de regra — isso é trabalho
	pendente do BattleManager (ou de um novo PlayCardManager) usando
	RuleValidator.validate_bench_placement / validate_bench_size etc.
	Por ora só emitimos o pedido e devolvemos a carta pra mão; quando
	o manager existir, ele deve chamar de volta algo como
	`organizar_cartas_nas_zonas(jogador_id)` pra esta cena refletir o
	resultado real."""
	if zona_alvo_potencial == null:
		_abrir_menu_contextual(carta_visual, carta_resource)
		_cancelar_arrasto()
		return

	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)
	var indice_mao: int = jogador.mao.find(carta_resource)
	if indice_mao == -1:
		print("⚠️ Carta não encontrada na mão!")
		_cancelar_arrasto()
		return

	if zona_alvo_potencial == jogador_campo_ativo:
		acao_jogador_solicitada.emit("jogar_para_ativo", {"indice_mao": indice_mao, "carta": carta_resource})
	elif zona_alvo_potencial == jogador_slots_banco:
		acao_jogador_solicitada.emit("jogar_para_banco", {"indice_mao": indice_mao, "carta": carta_resource})

	# TODO(core): trocar por animação condicionada à confirmação do
	# manager. Por enquanto sempre cancela visualmente (a carta volta
	# pra mão) até existir um listener que aplique e confirme a jogada.
	_cancelar_arrasto()

	carta_em_arrasto = null
	zona_alvo_potencial = null

# ==============================================================================
# SISTEMA DE ZOOM E MENU CONTEXTUAL
# ==============================================================================

func _abrir_zoom_leitura(carta_visual: Control, carta_resource: CardBaseResource) -> void:
	if card_zoom_manager == null:
		print("⚠️ CardZoomManager não disponível")
		return

	card_zoom_manager.exibir_zoom_carta(carta_visual, carta_resource)


func _abrir_menu_contextual(carta_visual: Control, carta_resource: CardBaseResource) -> void:
	if is_instance_valid(menu_contextual_ativo):
		menu_contextual_ativo.queue_free()

	var menu: Panel = Panel.new()
	menu.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	menu.custom_minimum_size = Vector2(150, 120)
	menu.global_position = carta_visual.global_position + Vector2(100, 100)

	var vbox: VBoxContainer = VBoxContainer.new()
	menu.add_child(vbox)

	var botoes: Array = [
		{"texto": "Prender/Presente", "acao": "_acao_prender"},
		{"texto": "Atacar", "acao": "_acao_atacar"},
		{"texto": "Usar Habilidade", "acao": "_acao_usar_habilidade"},
		{"texto": "Recuar", "acao": "_acao_recuar"}
	]

	for item_botao in botoes:
		var botao: Button = Button.new()
		botao.text = item_botao["texto"]
		botao.pressed.connect(Callable(self, item_botao["acao"]).bindv([carta_resource]))

		var habilitado: bool = _validar_acao_permitida(item_botao["acao"], carta_resource)
		botao.disabled = not habilitado

		vbox.add_child(botao)

	add_child(menu)
	menu_contextual_ativo = menu

	await get_tree().create_timer(30.0).timeout
	if is_instance_valid(menu_contextual_ativo):
		menu_contextual_ativo.queue_free()
		menu_contextual_ativo = null


func _validar_acao_permitida(acao: String, carta: CardBaseResource) -> bool:
	"""Delega pro RuleValidator sempre que a regra já está
	implementada. Ações cuja regra ainda é esqueleto (validate_retreat
	hoje sempre retorna false) ficam corretamente desabilitadas até
	serem implementadas no RuleValidator — não simulamos aqui.

	Prender/Atacar/Habilidade/Recuar só existem pra Animal — cartas de
	Efeito/Território/Energia não têm essas ações, então nem chegam a
	entrar no match (evita passar EffectResource/etc pro RuleValidator,
	que espera CardResource especificamente)."""
	if not (carta is CardResource) or carta.super_type != "animal":
		return false

	var jogador := _obter_player_state(ID_JOGADOR_HUMANO)

	match acao:
		"_acao_prender":
			return jogador.ativo != null and jogador.comida_disponivel >= 1

		"_acao_atacar":
			if GameState.fase_atual != GameState.Fase.ATAQUE:
				return false
			if jogador.ativo == null:
				return false
			return RuleValidator.validate_attack(jogador.ativo, carta)

		"_acao_usar_habilidade":
			return jogador.ativo != null and carta.text_ui != ""

		"_acao_recuar":
			return RuleValidator.validate_retreat(jogador.ativo, jogador, GameState)

	return false


func _acao_prender(carta: CardBaseResource) -> void:
	print("📌 Ação: Prender/Presente em %s" % carta.name)
	acao_jogador_solicitada.emit("prender", {"carta": carta})


func _acao_atacar(carta: CardBaseResource) -> void:
	print("⚔️ Ação: Atacar com %s" % carta.name)
	acao_jogador_solicitada.emit("atacar", {"carta": carta})
	_animar_ataque(carta)


func _acao_usar_habilidade(carta: CardBaseResource) -> void:
	print("✨ Ação: Usar habilidade de %s" % carta.name)
	acao_jogador_solicitada.emit("usar_habilidade", {"carta": carta})


func _acao_recuar(carta: CardBaseResource) -> void:
	print("🔄 Ação: Recuar %s" % carta.name)
	acao_jogador_solicitada.emit("recuar", {"carta": carta})

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
		contador_panel.mouse_entered.connect(_ao_mouse_entrou_comida.bindv([jogador_id, pontos]))
		contador_panel.mouse_exited.connect(_ao_mouse_saiu_comida)

	print("🍖 Contador de comida atualizado: %d pontos (Jogador %d)" % [pontos, jogador_id])


func _ao_mouse_entrou_comida(jogador_id: int, pontos: int) -> void:
	print("ℹ️ Hover em contador de comida: %d pontos" % pontos)


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
		"banco":
			container = jogador_slots_banco if jogador_id == 0 else oponente_slots_banco
		"ativo":
			container = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
		"descarte":
			container = jogador_zona_descarte if jogador_id == 0 else oponente_zona_descarte

	if container:
		for child in container.get_children():
			child.queue_free()


func _get_first_child_of_type(parent: Node, tipo: Object) -> Control:
	for child in parent.get_children():
		if is_instance_of(child, tipo):
			return child as Control
	return null

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
