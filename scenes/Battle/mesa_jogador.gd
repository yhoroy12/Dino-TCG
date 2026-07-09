# ==============================================================================
# MesaDoTabuleiro — Camada de Renderização e Interface (UI)
# Renderiza o estado do jogo, gerencia interações do jogador e anima transições
# NUNCA calcula regras — apenas reage aos sinais do GameState
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
const DISTANCIA_SNAP_ZONAS: float = 50.0  # Pixels
const VELOCIDADE_CARTA_HAND: float = 8.0  # Unidades por frame
const CENA_CARTA := preload("res://Scenes/Components/card/Card.tscn")

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

# Controle de cartas
var carta_selecionada: Control = null
var carta_em_arrasto: Control = null
var offset_arrasto: Vector2 = Vector2.ZERO
var zona_alvo_potencial: Control = null

# Animações
var tween_ativa: Tween = null
var dicionario_tweens_cartas: Dictionary = {}  # { CardUI: Tween }

# Sistema de zoom (integração com CardZoomManager)
var card_zoom_manager: Control = null
var menu_contextual_ativo: Control = null

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================

func _ready() -> void:
	"""Inicializa a mesa de jogo e conecta os sinais do GameState"""
	_validar_referencias()
	_conectar_sinais_gamestate()
	_configurar_interface_inicial()
	
	print("✓ MesaDoTabuleiro inicializada com sucesso")
	GameState.inicializar_setup(GameState.deck_pendente_j0, GameState.deck_pendente_j1)

func _process(delta: float) -> void:
	"""Atualiza UI em tempo real (timer de turno, arrasto de cartas)"""
	if turno_em_progresso:
		_atualizar_contador_turno(delta)
	
	# Atualização de arrasto de cartas
	if carta_em_arrasto != null and is_instance_valid(carta_em_arrasto):
		_processar_arrasto_carta()


func _input(event: InputEvent) -> void:
	"""Processa inputs do teclado e mouse"""
	if not get_tree().root.is_ancestor_of(self):
		return
	
	# ESC para cancelar arrasto
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancelar_arrasto()
		get_tree().root.set_input_as_handled()
# ==================================================
# FLUXO DE SETUP DA PARTIDA
# ==================================================

# Func: _iniciar_setup_visual
# Responsável por iniciar toda a sequência visual de preparação da partida.
# Deve ser chamada assim que a cena MesaJogador estiver pronta.
# Não executa regras do jogo, apenas inicia a primeira etapa do setup.
# Próximo passo esperado: _mostrar_escolha_moeda()
#
# Return:
# void
func _iniciar_setup_visual() -> void:
	pass


# Func: _mostrar_escolha_moeda
# Exibe a interface para o jogador escolher Cara ou Coroa.
# Deve habilitar os controles de seleção e aguardar interação do jogador.
# Nenhuma regra do GameState é executada nesta etapa.
#
# Return:
# void
func _mostrar_escolha_moeda() -> void:
	pass


# Func: _ao_escolher_moeda
# Callback disparado quando o jogador escolhe Cara ou Coroa.
# Armazena a escolha localmente e solicita ao GameState a execução do sorteio.
# Também pode iniciar a animação da moeda.
#
# Parâmetros:
# escolha: String ("cara" ou "coroa")
#
# Return:
# void
func _ao_escolher_moeda(escolha: String) -> void:
	pass


# Func: _ao_resultado_moeda
# Recebe o resultado oficial do sorteio vindo do GameState.
# Atualiza a interface mostrando o resultado da moeda.
# Informa ao jogador se ele será o primeiro ou o segundo a jogar.
# Ao finalizar a animação ou confirmação visual, deve avançar para a compra inicial.
#
# Return:
# void
func _ao_resultado_moeda() -> void:
	pass


# Func: _mostrar_mao_inicial
# Solicita ao sistema visual a renderização da mão inicial, deck,
# descarte e demais elementos básicos da mesa.
# Deve ser executada antes da etapa de Mulligan para que o jogador
# possa visualizar as cartas recebidas.
#
# Return:
# void
func _mostrar_mao_inicial() -> void:
	pass


# Func: _iniciar_mulligan
# Inicia a fase de Mulligan.
# Verifica junto ao GameState se o jogador possui uma mão válida.
# Caso necessário, apresenta os controles para confirmar o Mulligan.
# Caso não seja necessário, encaminha diretamente para a próxima etapa.
#
# Return:
# void
func _iniciar_mulligan() -> void:
	pass


# Func: _finalizar_mulligan
# Executada após todos os Mulligans terem sido resolvidos.
# Atualiza visualmente a mão do jogador, entrega cartas extras quando necessário
# e garante que a mesa reflita o estado final do setup.
# Ao concluir esta etapa, deve emitir ou solicitar a conclusão oficial do setup.
#
# Return:
# void
func _finalizar_mulligan() -> void:
	pass


# Func: _iniciar_escolha_ativo
# Inicia a etapa de seleção do Animal Ativo inicial.
# Destaca os Filhotes elegíveis na mão do jogador.
# Aguarda a escolha e envia a seleção ao GameState para validação.
# Esta é a última etapa do setup antes do início da partida.
#
# Return:
# void
func _iniciar_escolha_ativo() -> void:
	pass

# ==============================================================================
# VALIDAÇÃO E CONEXÃO DE SINAIS
# ==============================================================================

func _validar_referencias() -> void:
	"""Valida se todos os nós necessários existem"""
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
	
	# Tenta encontrar CardZoomManager se existir na cena
	card_zoom_manager = get_tree().root.find_child("CardZoomManager", true, false)


func _conectar_sinais_gamestate() -> void:
	"""Conecta os sinais do GameState para atualizações visuais"""
	if not GameState:
		push_error("❌ GameState (Autoload) não está disponível!")
		return
	#solicitar o lançamento da moeda para jogador inicial
	GameState.solicitar_lancamento_moeda.connect(_ao_solicitar_lancamento_moeda)
	
	#Mulligan
	GameState.solicitar_mulligan.connect(_ao_solicitar_mulligan)
	
	#Escolher Animal Ativo
	GameState.solicitar_escolha_ativo.connect(_ao_solicitar_escolha_ativo)
	
	#Morreu de fome
	GameState.animal_nocauteado_por_fome.connect(_ao_animal_nocauteado_por_fome)
	
	#Setup 
	GameState.setup_concluido.connect(_ao_setup_concluido)
	
	# Turnos e Fases
	GameState.turno_iniciado.connect(_ao_turno_iniciado)
	GameState.turno_encerrado.connect(_ao_turno_encerrado)
	
	# Cartas
	GameState.animal_nocauteado.connect(_ao_animal_nocauteado)
	
	# Condições
	GameState.condicao_aplicada.connect(_ao_condicao_aplicada)
	
	# Alimentação
	GameState.alimentacao_distribuida.connect(_ao_alimentacao_distribuida)
	
	# Moedas
	GameState.moeda_lancada.connect(_ao_moeda_lancada)
	
	# Vitória
	GameState.vitoria.connect(_ao_vitoria)
	GameState.empate.connect(_ao_empate)
	
	# Botão Passar Turno
	botao_passar_turno.pressed.connect(_ao_botao_passar_turno_pressionado)
	
	# Timer do Turno
	timer_turno.timeout.connect(_ao_timer_turno_expirado)


func _configurar_interface_inicial() -> void:
	"""Configura o estado inicial da interface"""
	botao_passar_turno.disabled = true
	progresso_turno.value = 0
	turno_em_progresso = false

# ==============================================================================
# CALLBACKS DO GAMESTATE — TURNOS
# ==============================================================================
func _ao_solicitar_lancamento_moeda() -> void:
	print("🪙 Sorteando primeiro jogador...")

	GameState.confirmar_lancamento_moeda()

func _ao_solicitar_mulligan(jogador_id: int) -> void:
	# Por enquanto apenas confirma automaticamente
	# Futuramente exibe um painel de confirmação para o jogador
	print("🔀 Mulligan necessário para Jogador %d" % jogador_id)
	GameState.confirmar_mulligan(jogador_id)

func _ao_solicitar_escolha_ativo(jogador_id: int) -> void:
	# Habilita o modo de seleção de ativo inicial
	# A carta clicada na mão vai chamar confirmar_ativo()
	print("🦖 Jogador %d deve escolher o animal ativo inicial." % jogador_id)
	# Futuramente exibe um painel orientando o jogador

func _ao_animal_nocauteado_por_fome(jogador_id: int) -> void:
	print("💀 Animal do Jogador %d morreu de fome. Escolha um substituto do banco." % jogador_id)
	# Futuramente abre painel de seleção do banco
	# Por enquanto a mesa aguarda o jogador clicar em um animal do banco

func _ao_setup_concluido() -> void:
	print("✅ Setup concluído. Partida iniciada!")
	organizar_cartas_nas_zonas(0)
	organizar_cartas_nas_zonas(1)
	print("Mesa: setup_concluido recebido!")
func _ao_turno_iniciado(jogador_id: int) -> void:
	"""Chamado quando um novo turno inicia"""
	jogador_ativo_id = jogador_id
	turno_em_progresso = true
	tempo_restante_turno = timer_turno.wait_time
	
	# Habilita botão apenas se for o turno do jogador humano
	botao_passar_turno.disabled = (jogador_id != 0)
	
	# Inicia o timer visual
	if timer_turno.is_stopped():
		timer_turno.start()
	
	print("🟢 Turno iniciado! Jogador: %d | Tempo: %.1fs" % [jogador_id, tempo_restante_turno])
	
	# Emite sinal de atualização
	turno_visual_atualizado.emit({
		"jogador_id": jogador_id,
		"fase": GameState.fase_atual,
		"turno_numero": GameState.turno_atual
	})

func _ao_turno_encerrado(jogador_id: int) -> void:
	"""Chamado quando um turno encerra"""
	turno_em_progresso = false
	timer_turno.stop()
	botao_passar_turno.disabled = true
	
	print("🔴 Turno encerrado! Jogador: %d" % jogador_id)

func _atualizar_contador_turno(delta: float) -> void:
	"""Atualiza o progresso do timer do turno"""
	tempo_restante_turno = maxf(tempo_restante_turno - delta, 0.0)
	
	# Atualiza barra de progresso (0 a 100)
	progresso_turno.value = (1.0 - (tempo_restante_turno / timer_turno.wait_time)) * 100
	
	# Debug opcional
	if fmod(tempo_restante_turno, 10.0) < delta:
		print("⏱️ Tempo restante: %.1fs" % tempo_restante_turno)

func _ao_timer_turno_expirado() -> void:
	"""Chamado quando o tempo do turno expira automaticamente"""
	print("⚠️ Tempo do turno expirado! Forçando avanço automático...")
	_ao_botao_passar_turno_pressionado()

func _ao_botao_passar_turno_pressionado() -> void:
	"""Chamado quando o jogador clica em 'Passar Turno'"""
	if jogador_ativo_id != 0:
		print("⚠️ Não é o seu turno!")
		return
	
	# Comunica ao GameState
	GameState.alternar_turno()
	turno_em_progresso = false

# ==============================================================================
# CALLBACKS DO GAMESTATE — CARTAS E CONDIÇÕES
# ==============================================================================

func _ao_animal_nocauteado(jogador_id: int, instancia: AnimalInstance) -> void:
	"""Chamado quando um animal é nocauteado"""
	print("💥 Animal Nocauteado: %s (Jogador %d)" % [instancia.card.name, jogador_id])
	
	# Anima a carta saindo da zona ativa
	var campo_origem: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
	var zona_descarte: Panel = jogador_zona_descarte if jogador_id == 0 else oponente_zona_descarte
	
	if _has_child_of_type(campo_origem, Control):
		var carta_visual: Control = _get_first_child_of_type(campo_origem, Control)
		_animar_carta_para_zona(carta_visual, zona_descarte)

func _ao_condicao_aplicada(jogador_id: int, condicao: int) -> void:
	"""Chamado quando uma condição especial é aplicada"""
	var nome_condicao: String = GameState.Condicao.keys()[condicao]
	print("🔧 Condição Aplicada: %s (Jogador %d)" % [nome_condicao, jogador_id])
	
	# Atualiza visual da zona de condição
	_atualizar_visual_condicao(jogador_id, condicao)


func _ao_alimentacao_distribuida(jogador_id: int) -> void:
	var j = GameState.jogadores[jogador_id]
	var deposito: int = j["pontos_comida"]
	var comida_dino: int = 0
	if j["zona_ativo"] != null:
		comida_dino = j["zona_ativo"].current_food
	print("🍖 Depósito: %d | Comida do Dino: %d (Jogador %d)" % [deposito, comida_dino, jogador_id])
	_atualizar_visual_contador_comida(jogador_id, deposito)


func _ao_moeda_lancada(acao: String, resultado: bool) -> void:
	"""Chamado quando uma moeda é lançada"""
	var resultado_texto: String = "CARA" if resultado else "COROA"
	print("🪙 Moeda Lançada (%s): %s" % [acao, resultado_texto])
	
	# Anima lançamento de moeda
	_animar_lancamento_moeda(resultado)


func _ao_vitoria(jogador_id: int) -> void:
	"""Chamado quando um jogador vence"""
	print("🏆 VITÓRIA! Jogador %d venceu!" % jogador_id)
	_exibir_tela_vitoria(jogador_id)
	turno_em_progresso = false


func _ao_empate() -> void:
	"""Chamado quando há empate"""
	print("🤝 EMPATE!")
	_exibir_tela_empate()
	turno_em_progresso = false

# ==============================================================================
# DECK E COMPRA DE CARTAS
# ==============================================================================

func comprar_carta_animada(jogador_id: int, carta: CardResource) -> void:
	"""Anima uma carta sendo comprada do deck para a mão"""
	var zona_deck: Panel = jogador_zona_deck if jogador_id == 0 else oponente_zona_deck
	var mao_container: HBoxContainer = jogador_mao if jogador_id == 0 else oponente_mao
	
	# Cria instância visual da carta (você precisa implementar sua classe CardUI)
	var carta_visual: Control = _criar_carta_ui(carta)
	carta_visual.global_position = zona_deck.global_position
	add_child(carta_visual)
	
	# Anima movimento para a mão
	_animar_carta_para_zona(carta_visual, mao_container)
	
	print("🃏 Carta comprada animada: %s" % carta.name)


func atualizar_visual_deck(jogador_id: int, cartas_restantes: int) -> void:
	"""Atualiza o visual do deck baseado no número de cartas"""
	var zona_deck: Panel = jogador_zona_deck if jogador_id == 0 else oponente_zona_deck
	
	# Exemplo: modula cor ou escala baseada no número de cartas
	if cartas_restantes <= 0:
		zona_deck.modulate = Color.RED
		zona_deck.self_modulate = Color(1, 0.5, 0.5)  # Avermelhado
	elif cartas_restantes <= 5:
		zona_deck.modulate = Color.YELLOW
		zona_deck.self_modulate = Color(1, 1, 0.5)  # Amarelado
	else:
		zona_deck.modulate = Color.WHITE
		zona_deck.self_modulate = Color.WHITE
	
	print("📚 Deck atualizado: %d cartas restantes (Jogador %d)" % [cartas_restantes, jogador_id])


# ==============================================================================
# GERENCIAMENTO DE ZONAS E DRAG & DROP
# ==============================================================================

func organizar_cartas_nas_zonas(jogador_id: int) -> void:
	"""Reorganiza todas as cartas do jogador em suas respectivas zonas"""
	var dados_jogador: Dictionary = GameState.jogadores[jogador_id]
	
	# Limpa zonas
	_limpar_zona(jogador_id, "mao")
	_limpar_zona(jogador_id, "banco")
	_limpar_zona(jogador_id, "ativo")
	_limpar_zona(jogador_id, "descarte")
	
	# Adiciona mão
	for carta in dados_jogador["mao"]:
		_adicionar_carta_na_zona(jogador_id, "mao", carta)
	
	# Adiciona banco
	for instancia in dados_jogador["banco"]:
		_adicionar_carta_na_zona(jogador_id, "banco", instancia.card)
	
	# Adiciona ativo
	if dados_jogador["zona_ativo"] != null:
		_adicionar_carta_na_zona(jogador_id, "ativo", dados_jogador["zona_ativo"].card)


func _adicionar_carta_na_zona(jogador_id: int, zona_nome: String, carta: CardResource) -> void:
	"""Cria uma instância visual de carta e a adiciona à zona especificada"""
	var carta_visual: Control = _criar_carta_ui(carta)
	
	match zona_nome:
		"mao":
			var mao_container: HBoxContainer = jogador_mao if jogador_id == 0 else oponente_mao
			mao_container.add_child(carta_visual)
			_configurar_inputs_carta(carta_visual, carta, jogador_id)
		
		"ativo":
			var campo_ativo: Panel = jogador_campo_ativo if jogador_id == 0 else oponente_campo_ativo
			campo_ativo.add_child(carta_visual)
			carta_visual.anchor_left = 0.5
			carta_visual.anchor_top = 0.5
			carta_visual.offset_left = -carta_visual.size.x / 2
			carta_visual.offset_top = -carta_visual.size.y / 2
		
		"banco":
			var slots_banco: HBoxContainer = jogador_slots_banco if jogador_id == 0 else oponente_slots_banco
			# Encontra primeiro slot vazio
			for slot in slots_banco.get_children():
				if slot.get_child_count() == 0:
					slot.add_child(carta_visual)
					break
		
		"descarte":
			# Descarte é apenas visual (pilha)
			pass


func _configurar_inputs_carta(carta_visual: Control, carta_resource: CardResource, jogador_id: int) -> void:
	"""Configura os inputs de mouse para uma carta"""
	if not carta_visual.is_connected("gui_input", Callable(self, "_ao_input_carta")):
		carta_visual.gui_input.connect(_ao_input_carta.bindv([carta_visual, carta_resource, jogador_id]))


func _ao_input_carta(event: InputEvent, carta_visual: Control, carta_resource: CardResource, jogador_id: int) -> void:
	"""Processa inputs em uma carta"""
	# 1. Primeiro garantimos que o evento é um clique de mouse (Pressionar ou Soltar)
	if event is InputEventMouseButton:
		
		# 2. Se o botão foi PRESSIONADO
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					# Inicia arrasto ou abre menu
					_iniciar_arrasto_carta(carta_visual, carta_resource, jogador_id)
				
				MOUSE_BUTTON_RIGHT:
					# Abre zoom estático de leitura
					_abrir_zoom_leitura(carta_visual, carta_resource)
		
		# 3. Se o botão foi SOLTO (else do event.pressed)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_finalizar_arrasto_carta(carta_visual, carta_resource)

func _iniciar_arrasto_carta(carta_visual: Control, carta_resource: CardResource, jogador_id: int) -> void:
	"""Inicia o arrasto de uma carta"""
	if jogador_id != 0:  # Só o jogador humano pode arrastar
		return
	
	carta_em_arrasto = carta_visual
	carta_selecionada = carta_visual
	offset_arrasto = carta_visual.get_local_mouse_position()
	
	# Eleva a carta visualmente
	carta_visual.z_index = 100
	carta_visual.modulate.a = 0.8
	
	print("👆 Arrasto iniciado: %s" % carta_resource.name)


func _processar_arrasto_carta() -> void:
	"""Atualiza posição da carta durante arrasto"""
	if carta_em_arrasto == null:
		return
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	carta_em_arrasto.global_position = mouse_pos - offset_arrasto
	
	# Detecta zona alvo potencial
	_detectar_zona_alvo(carta_em_arrasto)


func _detectar_zona_alvo(carta_visual: Control) -> void:
	"""Detecta se a carta está perto de uma zona de drop válida"""
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
			# Visual feedback (opcional)
			zona.self_modulate = Color.YELLOW


func _cancelar_arrasto() -> void:
	"""Cancela o arrasto da carta e a retorna à posição original"""
	if carta_em_arrasto == null:
		return
	
	# Anima volta
	_animar_carta_para_zona(carta_em_arrasto, jogador_mao)
	
	# Limpa estado
	carta_em_arrasto = null
	zona_alvo_potencial = null
	
	if is_instance_valid(carta_selecionada):
		carta_selecionada.z_index = 0
		carta_selecionada.modulate.a = 1.0


func _finalizar_arrasto_carta(carta_visual: Control, carta_resource: CardResource) -> void:
	"""Finaliza o arrasto: snap ou abre o menu de contexto"""
	if zona_alvo_potencial == null:
		# Se não foi arrastada para nenhuma zona válida, foi um clique curto!
		_abrir_menu_contextual(carta_visual, carta_resource)
		_cancelar_arrasto()
		return
	
	# Determina qual zona e comunica ao GameState
	var indice_mao: int = GameState.jogadores[0]["mao"].find(carta_resource)
	if indice_mao == -1:
		print("⚠️ Carta não encontrada na mão!")
		_cancelar_arrasto()
		return
	
	if zona_alvo_potencial == jogador_campo_ativo:
		if GameState.jogar_animal_para_ativo(0, indice_mao):
			_animar_carta_para_zona(carta_visual, jogador_campo_ativo)
			print("✓ Carta jogada no campo ativo")
		else:
			_cancelar_arrasto()
	
	elif zona_alvo_potencial == jogador_slots_banco:
		if GameState.jogar_animal_para_banco(0, indice_mao):
			_animar_carta_para_zona(carta_visual, jogador_slots_banco)
			print("✓ Carta jogada no banco")
		else:
			_cancelar_arrasto()
	
	else:
		_cancelar_arrasto()
	
	carta_em_arrasto = null
	zona_alvo_potencial = null
	
# ==============================================================================
# SISTEMA DE ZOOM E MENU CONTEXTUAL
# ==============================================================================

func _abrir_zoom_leitura(carta_visual: Control, carta_resource: CardResource) -> void:
	"""Abre o zoom estático para leitura (botão direito)"""
	if card_zoom_manager == null:
		print("⚠️ CardZoomManager não disponível")
		return
	
	# Usa CardZoomManager para fazer zoom
	card_zoom_manager.exibir_zoom_carta(carta_visual, carta_resource)
	
	#COMENTE A LINHA ABAIXO QUE ESTAVA AQUI:
	# _abrir_menu_contextual(carta_visual, carta_resource)


func _abrir_menu_contextual(carta_visual: Control, carta_resource: CardResource) -> void:
	"""Abre menu flutuante com ações disponíveis (botão esquerdo depois de zoom)"""
	# 🔥 CORREÇÃO AQUI: Se já existe um menu aberto na tela, fecha ele antes!
	if is_instance_valid(menu_contextual_ativo):
		menu_contextual_ativo.queue_free()	
	# Cria painel flutuante com botões
	var menu: Panel = Panel.new()
	menu.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	menu.custom_minimum_size = Vector2(150, 120)
	menu.global_position = carta_visual.global_position + Vector2(100, 100)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	menu.add_child(vbox)
	
	# Botões do menu (ativados/desativados baseado em regras do GameState)
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
		
		# Valida se a ação é permitida pelo GameState
		var habilitado: bool = _validar_acao_permitida(item_botao["acao"], carta_resource)
		botao.disabled = not habilitado
		
		vbox.add_child(botao)
	
	# Adiciona à cena
	add_child(menu)
	menu_contextual_ativo = menu
	
	# Fecha menu após 30 segundos ou clique fora
	await get_tree().create_timer(30.0).timeout
	if is_instance_valid(menu_contextual_ativo):
		menu_contextual_ativo.queue_free()
		menu_contextual_ativo = null


func _validar_acao_permitida(acao: String, carta: CardResource) -> bool:
	"""Valida se uma ação é permitida baseado no GameState"""
	var dados_jogador: Dictionary = GameState.jogadores[0]
	
	match acao:
		"_acao_prender":
			return dados_jogador["zona_ativo"] != null and dados_jogador["pontos_comida"] >= 1
		
		"_acao_atacar":
			return GameState.fase_atual == GameState.Fase.ATAQUE and GameState.pode_atacar(0)
		
		"_acao_usar_habilidade":
			return dados_jogador["zona_ativo"] != null and carta.text_ui != ""
		
		"_acao_recuar":
			return GameState.pode_recuar(0)
	
	return false


func _acao_prender(carta: CardResource) -> void:
	"""Ação: Prender/Presente"""
	print("📌 Ação: Prender/Presente em %s" % carta.name)
	acao_jogador_solicitada.emit("prender", {"carta": carta})


func _acao_atacar(carta: CardResource) -> void:
	"""Ação: Atacar com o animal ativo"""
	print("⚔️ Ação: Atacar com %s" % carta.name)
	acao_jogador_solicitada.emit("atacar", {"carta": carta})
	
	# Toca animação de ataque
	_animar_ataque(carta)


func _acao_usar_habilidade(carta: CardResource) -> void:
	"""Ação: Usar habilidade da carta"""
	print("✨ Ação: Usar habilidade de %s" % carta.name)
	acao_jogador_solicitada.emit("usar_habilidade", {"carta": carta})


func _acao_recuar(carta: CardResource) -> void:
	"""Ação: Recuar animal ativo"""
	print("🔄 Ação: Recuar %s" % carta.name)
	acao_jogador_solicitada.emit("recuar", {"carta": carta})

# ==============================================================================
# ANIMAÇÕES VISUAIS
# ==============================================================================

func _animar_carta_para_zona(carta_visual: Control, zona_alvo: Control, duracao: float = DURACAO_ANIMACAO_CARTA) -> void:
	"""Anima uma carta se movendo para uma zona"""
	# Mata tween anterior se existir
	if dicionario_tweens_cartas.has(carta_visual):
		dicionario_tweens_cartas[carta_visual].kill()
	
	var tween: Tween = create_tween()
	dicionario_tweens_cartas[carta_visual] = tween
	
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_duration(duracao)
	
	# Anima posição
	tween.tween_property(
		carta_visual,
		"global_position",
		zona_alvo.global_position,
		duracao
	)
	
	# Callback ao terminar
	tween.tween_callback(func():
		dicionario_tweens_cartas.erase(carta_visual)
		if is_instance_valid(carta_visual):
			carta_visual.z_index = 0
			carta_visual.modulate.a = 1.0
	)


func _animar_ataque(carta: CardResource) -> void:
	"""Anima o ataque visual do animal ativo"""
	var campo_ativo: Panel = jogador_campo_ativo
	if campo_ativo.get_child_count() == 0:
		return
	
	var carta_visual: Control = _get_first_child_of_type(campo_ativo, Control)
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Animação de pulso
	tween.tween_property(carta_visual, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(carta_visual, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(carta_visual, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(carta_visual, "scale", Vector2(1.0, 1.0), 0.1)


func _animar_lancamento_moeda(resultado: bool) -> void:
	"""Anima um lançamento de moeda"""
	print("🎪 Lançamento de moeda animado: %s" % ("CARA" if resultado else "COROA"))
	
	# Você pode instanciar um AnimatedSprite2D ou criar uma animação visual aqui
	# Por enquanto, é apenas um placeholder
	var moeda_label: Label = Label.new()
	moeda_label.text = "CARA" if resultado else "COROA"
	moeda_label.add_theme_font_size_override("font_size", 48)
	moeda_label.global_position = get_viewport().get_visible_rect().get_center()
	add_child(moeda_label)
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(moeda_label, "modulate", Color.TRANSPARENT, DURACAO_ANIMACAO_MOEDA)
	tween.tween_callback(func(): moeda_label.queue_free())


# ==============================================================================
# FEEDBACKS VISUAIS — CONDIÇÕES E COMIDA
# ==============================================================================

func _atualizar_visual_condicao(jogador_id: int, condicao: int) -> void:
	"""Altera o visual da carta ativa baseado na condição"""
	var zona_condicao: Panel = jogador_condicao_especial if jogador_id == 0 else oponente_condicao_especial
	var nome_condicao: String = GameState.Condicao.keys()[condicao]
	
	# Cria um label ou ícone representando a condição
	var condicao_visual: Label = Label.new()
	condicao_visual.text = nome_condicao
	condicao_visual.add_theme_font_size_override("font_size", 24)
	
	match condicao:
		GameState.Condicao.ADORMECIDO:
			condicao_visual.self_modulate = Color.LIGHT_BLUE
		GameState.Condicao.PARALISADO:
			condicao_visual.self_modulate = Color.YELLOW
		GameState.Condicao.ENVENENADO:
			condicao_visual.self_modulate = Color.GREEN
		GameState.Condicao.SANGRANDO:
			condicao_visual.self_modulate = Color.RED
	
	# Limpa zona anterior
	for child in zona_condicao.get_children():
		child.queue_free()
	
	zona_condicao.add_child(condicao_visual)
	print("🔧 Visual de condição atualizado: %s" % nome_condicao)


func _atualizar_visual_contador_comida(jogador_id: int, pontos: int) -> void:
	"""Atualiza o sprite e UI do contador de comida"""
	var contador_panel: Panel = jogador_contador_comida if jogador_id == 0 else oponente_contador_comida
	
	# Limpa filhos anteriores
	for child in contador_panel.get_children():
		child.queue_free()
	
	# Cria Label com número de pontos
	var label_comida: Label = Label.new()
	label_comida.text = str(pontos)
	label_comida.add_theme_font_size_override("font_size", 32)
	label_comida.modulate = Color.ORANGE
	
	contador_panel.add_child(label_comida)
	
	# Configura hover para exibir tooltip
	if not contador_panel.is_connected("mouse_entered", Callable(self, "_ao_mouse_entrou_comida")):
		contador_panel.mouse_entered.connect(_ao_mouse_entrou_comida.bindv([jogador_id, pontos]))
		contador_panel.mouse_exited.connect(_ao_mouse_saiu_comida)
	
	print("🍖 Contador de comida atualizado: %d pontos (Jogador %d)" % [pontos, jogador_id])


func _ao_mouse_entrou_comida(jogador_id: int, pontos: int) -> void:
	"""Exibe tooltip ao hover no contador de comida"""
	print("ℹ️ Hover em contador de comida: %d pontos" % pontos)


func _ao_mouse_saiu_comida() -> void:
	"""Remove tooltip ao sair do hover"""
	pass

# ==============================================================================
# TELAS FINAIS
# ==============================================================================

func _exibir_tela_vitoria(ganhador_id: int) -> void:
	"""Exibe a tela de vitória"""
	var tela_vitoria: Panel = Panel.new()
	tela_vitoria.anchor_left = 0
	tela_vitoria.anchor_top = 0
	tela_vitoria.anchor_right = 1
	tela_vitoria.anchor_bottom = 1
	
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = Color.BLACK
	stylebox.set_corner_radius_all(0)
	tela_vitoria.add_theme_stylebox_override("panel", stylebox)
	
	var label_vitoria: Label = Label.new()
	label_vitoria.text = "🏆 JOGADOR %d VENCEU! 🏆" % ganhador_id
	label_vitoria.add_theme_font_size_override("font_size", 64)
	label_vitoria.anchor_left = 0.5
	label_vitoria.anchor_top = 0.5
	label_vitoria.offset_left = -250
	label_vitoria.offset_top = -50
	
	tela_vitoria.add_child(label_vitoria)
	add_child(tela_vitoria)
	
	print("🏆 Tela de vitória exibida para Jogador: %d" % ganhador_id)


func _exibir_tela_empate() -> void:
	"""Exibe a tela de empate"""
	var tela_empate: Panel = Panel.new()
	tela_empate.anchor_left = 0
	tela_empate.anchor_top = 0
	tela_empate.anchor_right = 1
	tela_empate.anchor_bottom = 1
	
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = Color.GRAY
	tela_empate.add_theme_stylebox_override("panel", stylebox)
	
	var label_empate: Label = Label.new()
	label_empate.text = "🤝 EMPATE! 🤝"
	label_empate.add_theme_font_size_override("font_size", 64)
	label_empate.anchor_left = 0.5
	label_empate.anchor_top = 0.5
	label_empate.offset_left = -200
	label_empate.offset_top = -50
	
	tela_empate.add_child(label_empate)
	add_child(tela_empate)
	
	print("🤝 Tela de empate exibida")

# ==============================================================================
# MÉTODOS AUXILIARES
# ==============================================================================

func _criar_carta_ui(carta: CardResource) -> Control:
	var instancia = CENA_CARTA.instantiate()
	instancia.inicializar(carta)
	return instancia
	
func _limpar_zona(jogador_id: int, zona_nome: String) -> void:
	"""Remove todas as cartas visuais de uma zona"""
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


func _has_child_of_type(parent: Node, tipo: Object) -> bool:
	"""Verifica se um nó tem filhos do tipo especificado"""
	for child in parent.get_children():
		if is_instance_of(child, tipo):
			return true
	return false


func _get_first_child_of_type(parent: Node, tipo: Object) -> Control:
	"""Retorna o primeiro filho do tipo especificado"""
	
	for child in parent.get_children():
		if is_instance_of(child, tipo):
			return child as Control
	return null


# ==============================================================================
# CLEANUP
# ==============================================================================

func _exit_tree() -> void:
	"""Limpa recursos ao sair da cena"""
	if tween_ativa:
		tween_ativa.kill()
	
	for tween in dicionario_tweens_cartas.values():
		if tween:
			tween.kill()
	
	# Desconecta sinais para evitar erros
	if GameState and GameState.is_connected("turno_iniciado", Callable(self, "_ao_turno_iniciado")):
		GameState.turno_iniciado.disconnect(_ao_turno_iniciado)

# ==============================================================================
# FIM DO SCRIPT
# ==============================================================================
