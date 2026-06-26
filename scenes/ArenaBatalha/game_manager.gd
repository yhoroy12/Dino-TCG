extends Node

# ==============================================================================
# GameManager — Maestro Visual da Partida (scenes/game/game_manager.gd)
# Coordena a renderização de campo, interações de clique e inputs do jogador.
# Intermedeia os dados brutos do GameState e as instâncias visuais de Card.
# ==============================================================================

# --- COMPONENTES SISTÊMICOS ---
var battle_manager: Node = null

# --- VARIÁVEIS DE CONTROLE DE INPUT / INTERACTION ---
var fase_inicial_definindo_ativo: bool = true
var aguardando_alvo_energia: bool = false
var carta_energia_selecionada_dados: Dictionary = {}
var nodo_energia_selecionada: Control = null

var aguardando_alvo_evolucao: bool = false
var carta_evolucao_selecionada_dados: Dictionary = {}
var nodo_evolucao_selecionada: Control = null

# Lista de espécies pequenas de evolução direta (Regra do manual)
var especies_evolucao_direta: Array[String] = [
	"Dryossauro", "Ornithomimus", "Psittacossauro", "Struthiomimus", 
	"Compsognathus", "Troodon", "Elasmossauro", "Sinosauropteryx", "Titanoboa"
]

# --- REFERÊNCIAS DE NÓS DA MESA GRÁFICA ---
# --- REFERÊNCIAS DE NÓS DA MESA GRÁFICA ---
@onready var comida_jogador_label: Label  = $InterfaceDoJogo/comida_jogador
@onready var comida_jogador2_label: Label = $InterfaceDoJogo/comida_jogador2
@onready var ativo_jogador_container      = $InterfaceDoJogo/ativo_jogador
@onready var ativo_jogador2_container     = $InterfaceDoJogo/ativo_jogador2
@onready var banco_jogador_container      = $InterfaceDoJogo/banco_jogador
@onready var mao_jogador_container        = $InterfaceDoJogo/mao_jogador
@onready var mao_jogador2_container       = $InterfaceDoJogo/mao_jogador2
@onready var deck_jogador_container       = $InterfaceDoJogo/deck_jogador
@onready var deck_jogador2_container      = $InterfaceDoJogo/deck_jogador2

@export var card_scene: PackedScene = preload("res://components/card/Card.tscn")

func _ready() -> void:
	# 1. Instancia o processador de combate refatorado
	battle_manager = load("res://core/systems/Battlemanager.gd").new()
	add_child(battle_manager)
	
	# 2. Conecta os sinais lógicos do GameState às funções de reatualização gráfica
	GameState.turno_iniciado.connect(_on_turno_iniciado)
	GameState.alimentacao_distribuida.connect(_on_alimentacao_atualizada)
	GameState.animal_nocauteado.connect(_on_animal_nocauteado_mesa)
	GameState.vitoria.connect(_on_fim_de_jogo)
	
# Disparar botão de start iniciar a partida.
func _on_start_pressed() -> void:
	print("🚀 Botão Start Pressionado: Inicializando Decks e Validando Mulligan...")
	
	var lista_decks = DeckManager.obter_lista_de_decks_salvos()
	var deck_id_teste = lista_decks[0] if not lista_decks.is_empty() else "DeckPadrao"
	
	var deck_j0 = DeckManager.preparar_deck_para_partida(DeckManager.carregar_deck(deck_id_teste))
	var deck_j1 = DeckManager.preparar_deck_para_partida(DeckManager.carregar_deck(deck_id_teste))
	
	# Inicializa o motor lógico do GameState
	GameState.iniciar_partida(deck_j0, deck_j1)
	
	# Esconde o botão start para limpar a tela após o jogo começar
	if has_node("InterfaceDoJogo/start"):
		$InterfaceDoJogo/start.hide()
		
	# Renderização inicial do tabuleiro completo
	_atualizar_toda_a_mesa_grafica()
	# Conecta os sinais textuais vindos do gerenciador de batalhas
	battle_manager.efeito_resolvido.connect(func(msg): print("🧬 Efeito em Campo: ", msg))

	# 3. Exemplo de inicialização de partida com decks simulados vindos do DeckManager
	_inicializar_partida_teste()

func _inicializar_partida_teste() -> void:
	var lista_decks = DeckManager.obter_lista_de_decks_salvos()
	var deck_id_teste = lista_decks[0] if not lista_decks.is_empty() else "DeckPadrao"
	
	# Carrega os decks em IDs salvos do usuário e converte em objetos dicionários profundos
	var deck_j0 = DeckManager.preparar_deck_para_partida(DeckManager.carregar_deck(deck_id_teste))
	var deck_j1 = DeckManager.preparar_deck_para_partida(DeckManager.carregar_deck(deck_id_teste))
	
	# Entrega o controle de dados absolutos para o GameState
	GameState.iniciar_partida(deck_j0, deck_j1)
	
	# Distribui a mão inicial gráfica
	_atualizar_toda_a_mesa_grafica()

# -----------------------------------------------------------------------------
# REATIVIDADE DA UI (Escutando os Sinais do GameState)
# -----------------------------------------------------------------------------

func _on_turno_iniciado(jogador_id: int) -> void:
	print("⏰ UI: Turno iniciado para o Jogador %d. Atualizando componentes visuais..." % jogador_id)
	_atualizar_toda_a_mesa_grafica()
	
	# Desliga travas de preparação visual se saímos do Turno 1
	if GameState.turno_atual > 1:
		fase_inicial_definindo_ativo = false

func _on_alimentacao_atualizada(jogador_id: int) -> void:
	var j = GameState.get_jogador(jogador_id)
	if jogador_id == 0 and comida_jogador_label:
		comida_jogador_label.text = "Sua Comida: %d" % j["comida_acumulada"]
	elif jogador_id == 1 and comida_jogador2_label:
		comida_jogador2_label.text = "Comida Oponente: %d" % j["comida_acumulada"]

func _on_animal_nocauteado_mesa(jogador_id: int, _carta_caida: Dictionary) -> void:
	print("💀 UI: Removendo bicho nocauteado da mesa gráfica do jogador %d." % jogador_id)
	_atualizar_toda_a_mesa_grafica()

func _on_fim_de_jogo(ganhador_id: int) -> void:
	print("🎉 UI: Tela de Fim de Jogo. Vitória do Jogador %d!" % ganhador_id)
	# Aqui você pode chamar um painel popup de Vitória/Derrota

# -----------------------------------------------------------------------------
# RECONSTRUÇÃO COMPLETA DE CENÁRIO (Visual Mirroring)
# -----------------------------------------------------------------------------
## Limpa e redesenha todos os slots da mesa espelhando o estado interno real do GameState
func _atualizar_toda_a_mesa_grafica() -> void:
	_renderizar_conteudo_mao(0, mao_jogador_container)
	_renderizar_conteudo_mao(1, mao_jogador2_container)
	_renderizar_slot_ativo(0, ativo_jogador_container)
	_renderizar_slot_ativo(1, ativo_jogador2_container)
	_renderizar_banco_reserva(0, banco_jogador_container)
	
	# Renderiza os montantes visuais dos Decks físicos
	_renderizar_pilha_deck(0, deck_jogador_container)
	_renderizar_pilha_deck(1, deck_jogador2_container)
	
	_on_alimentacao_atualizada(0)
	_on_alimentacao_atualizada(1)
# GERENCIADOR VISUAL DE PILHA DE CARTAS (Efeito deck empilhado) ---
func _renderizar_pilha_deck(jogador_id: int, container: Control) -> void:
	if not container: return
	for filho in container.get_children():
		filho.queue_free()
		
	var j = GameState.get_jogador(jogador_id)
	var cartas_restantes = j["deck"].size()
	
	# Regra visual solicitada: 1 carta física para cada 10 cartas no baralho (máximo 6 cartas sobrepostas)
	var quantidade_cards_visuais = clamp(ceil(cartas_restantes / 10.0), 0, 6)
	
	for i in range(quantidade_cards_visuais):
		var instancia = card_scene.instantiate()
		container.add_child(instancia)
		
		# Força o deck a sempre exibir o verso virado para cima
		instancia.virada_para_baixo = true
		instancia.atualizar_exibicao({}) # Envia dicionário vazio apenas para renderizar a moldura traseira
		
		# Efeito opcional de micro deslocamento de pixel no motor para parecer um monte 3D
		instancia.position = Vector2(i * -2, i * -2)
func _renderizar_conteudo_mao(jogador_id: int, container: Control) -> void:
	if not container: return
	for filho in container.get_children():
		filho.queue_free()
		
	var j = GameState.get_jogador(jogador_id)
	for dados_carta in j["mao"]:
		var instancia = card_scene.instantiate()
		container.add_child(instancia)
		
		# Oponente joga com cartas viradas para baixo (se for multiplayer local/AI simples)
		if jogador_id == 1:
			instancia.virada_para_baixo = true
			
		instancia.atualizar_exibicao(dados_carta)
		
		# Registra clique na carta contida dentro da mão do jogador ativo
		if jogador_id == GameState.jogador_ativo_id:
			instancia.clicado.connect(_on_carta_da_mao_clicada)

func _renderizar_slot_ativo(jogador_id: int, container: Control) -> void:
	if not container: return
	for filho in container.get_children():
		filho.queue_free()
		
	var j = GameState.get_jogador(jogador_id)
	if j["ativo"].is_empty():
		return
		
	var instancia = card_scene.instantiate()
	container.add_child(instancia)
	
	# Cria dicionário híbrido contendo o estado mutável do GameState para o card renderizar
	var dados_mesa = j["ativo"].duplicate(true)
	dados_mesa["hp_atual"] = j["hp_ativo"]
	dados_mesa["comida_atual"] = j["comida_ativo"]
	dados_mesa["condicao_ativa"] = j["condicao"]
	
	instancia.atualizar_exibicao(dados_mesa)
	instancia.clicado.connect(func(nodo): _on_animal_mesa_clicado(nodo, jogador_id, -1))

func _renderizar_banco_reserva(jogador_id: int, container: Control) -> void:
	if not container: return
	for filho in container.get_children():
		filho.queue_free()
		
	var j = GameState.get_jogador(jogador_id)
	for i in range(j["banco"].size()):
		var instancia = card_scene.instantiate()
		container.add_child(instancia)
		
		var dados_banco = j["banco"][i].duplicate(true)
		dados_banco["hp_atual"] = j["hp_banco"][i]
		
		instancia.atualizar_exibicao(dados_banco)
		
		# Passa o índice correto do banco para sabermos quem foi selecionado no recuo/evolução
		var indice_banco = i
		instancia.clicado.connect(func(nodo): _on_animal_mesa_clicado(nodo, jogador_id, indice_banco))

# -----------------------------------------------------------------------------
# CONTROLADORES DE ENTRADA GRÁFICA (Input Event Handlers)
# -----------------------------------------------------------------------------

func _on_carta_da_mao_clicada(nodo_carta: Control) -> void:
	var j = GameState.get_jogador(GameState.jogador_ativo_id)
	var dados = nodo_carta.dados_carta
	var tipo: String = dados.get("tipo", "animal").to_lower()
	var estagio: String = str(dados.get("estagio", "")).to_lower()

	# AÇÃO 1: Definir Dinossauro Ativo Inicial (Turno 1)
	if fase_inicial_definindo_ativo and tipo == "animal":
		if not ("bebe" in estagio or "bebê" in estagio):
			print("❌ Regra: O animal ativo inicial deve ser obrigatoriamente um Bebê.")
			return
		j["ativo"] = dados.duplicate(true)
		j["hp_ativo"] = int(dados.get("hp", 0))
		j["mao"].erase(dados)
		_atualizar_toda_a_mesa_grafica()
		return

	# AÇÃO 2: Baixar Animal Bebê para a Reserva
	if tipo == "animal" and ("bebe" in estagio or "bebê" in estagio):
		if j["banco"].size() >= GameState.MAX_BANCO_RESERVA:
			print("❌ Banco Reserva completamente cheio.")
			return
		j["banco"].append(dados.duplicate(true))
		j["hp_banco"].append(int(dados.get("hp", 0)))
		j["mao"].erase(dados)
		_atualizar_toda_a_mesa_grafica()
		return

	# AÇÃO 3: Preparar Acoplamento de Força Primordial (Energia)
	if tipo == "energia":
		aguardando_alvo_evolucao = false
		aguardando_alvo_energia = true
		carta_energia_selecionada_dados = dados
		nodo_energia_selecionada = nodo_carta
		print("⚡ UI: Energia selecionada. Clique em um bicho na mesa para ligá-la.")
		return

	# AÇÃO 4: Preparar Crescimento (Evolução Jovem/Adulto)
	if "jovem" in estagio or "adulto" in estagio:
		aguardando_alvo_energia = false
		aguardando_alvo_evolucao = true
		carta_evolucao_selecionada_dados = dados
		nodo_evolucao_selecionada = nodo_carta
		print("🦖 UI: Evolução selecionada. Clique no bicho correspondente na mesa para crescer.")

func _on_animal_mesa_clicado(_nodo_alvo: Control, jogador_id: int, indice_banco: int) -> void:
	# Apenas interage se clicou nos próprios animais no seu turno
	if jogador_id != GameState.jogador_ativo_id:
		return
		
	var j = GameState.get_jogador(jogador_id)

	# EXECUÇÃO: Conclui vinculação da Energia selecionada
	if aguardando_alvo_energia:
		aguardando_alvo_energia = false
		if indice_banco == -1: # Significa que clicou no Ativo
			j["energias_ativo"].append(carta_energia_selecionada_dados.get("cor", "incolor"))
			j["mao"].erase(carta_energia_selecionada_dados)
			print("⚡ Energia acoplada com sucesso ao Animal Ativo.")
		else:
			print("ℹ️ Força Primordial ligada ao banco (Rastreado estaticamente ou via array customizado).")
		_atualizar_toda_a_mesa_grafica()
		return

	# EXECUÇÃO: Conclui Processo Ecológico de Evolução
	if aguardando_alvo_evolucao:
		aguardando_alvo_evolucao = false
		var bicho_alvo_dados = j["ativo"] if indice_banco == -1 else j["banco"][indice_banco]
		
		if _validar_linha_evolutiva(bicho_alvo_dados, carta_evolucao_selecionada_dados):
			if indice_banco == -1:
				j["ativo"] = carta_evolucao_selecionada_dados.duplicate(true)
				j["hp_ativo"] = int(carta_evolucao_selecionada_dados.get("hp", 0)) # Cura ao crescer
			else:
				j["banco"][indice_banco] = carta_evolucao_selecionada_dados.duplicate(true)
				j["hp_banco"][indice_banco] = int(carta_evolucao_selecionada_dados.get("hp", 0))
				
			j["mao"].erase(carta_evolucao_selecionada_dados)
			print("🦖 Evolução bem-sucedida! O animal cresceu em campo.")
			_atualizar_toda_a_mesa_grafica()
		return

	# AÇÃO EXTRA: Clicou no bicho do banco sem nada selecionado -> Inicia comando de Recuar
	if indice_banco != -1 and not fase_inicial_definindo_ativo:
		GameState.recuar(jogador_id, indice_banco)
		_atualizar_toda_a_mesa_grafica()

# -----------------------------------------------------------------------------
# BOTÕES DE AÇÃO DO JOGADOR (UI Button Signals)
# -----------------------------------------------------------------------------

func _on_botao_atacar_pressed() -> void:
	var j_ativo = GameState.get_jogador(GameState.jogador_ativo_id)
	
	# Impeditivo ABSOLUTO de paralisia/sono verificado no motor lúdico antes de acionar a UI
	if j_ativo["condicao"] == GameState.Condicao.ADORMECIDO:
		print("❌ Ataque Negado: O animal ativo está dormindo profundamente.")
		return
		
	if j_ativo["condicao"] == GameState.Condicao.PARALISADO:
		if not GameState.testar_moeda_paralisia(GameState.jogador_ativo_id, "Executar Ataque"):
			# Falhou na moeda da paralisia, passa o turno automaticamente ou gasta a ação
			GameState.alternar_turno()
			return

	# Delegamento de responsabilidade para o BattleManager processar o cálculo e aplicar o dano
	battle_manager.resolver_ataque(GameState.jogador_ativo_id)
	
	# Ataques encerram o turno obrigatoriamente
	GameState.alternar_turno()

func _on_botao_passar_turno_pressed() -> void:
	GameState.alternar_turno()

# -----------------------------------------------------------------------------
# AUXILIARES DE SUPORTE
# -----------------------------------------------------------------------------
func _validar_linha_evolutiva(base: Dictionary, evolucao: Dictionary) -> bool:
	var animal_base: String = base.get("animal", "")
	var animal_evo: String = evolucao.get("animal", "")
	var estagio_base: String = str(base.get("estagio", "")).to_lower()
	var estagio_evo: String = str(evolucao.get("estagio", "")).to_lower()
	
	if animal_base != animal_evo:
		print("❌ Espécies incompatíveis para evolução (%s -> %s)." % [animal_base, animal_evo])
		return false
		
	if "bebe" in estagio_base and "jovem" in estagio_evo:
		return true
	if "jovem" in estagio_base and "adulto" in estagio_evo:
		return true
		
	# Regra Especial: Espécies pequenas pulam estágio Jovem e vão de Bebê direto para Adulto
	if "bebe" in estagio_base and "adulto" in estagio_evo and especies_evolucao_direta.has(animal_base):
		print("✨ Regra Especial: %s pulou o estágio Jovem com sucesso!" % animal_base)
		return true
		
	print("❌ Salto de estágio inválido no ciclo de crescimento.")
	return false
