# ==================================================
# Nome: AIController
# Categoria: Core / AI
# Responsável pelo controle de ações do oponente autônomo (IA).
# ==================================================
class_name AIController
extends Node

## Identificador fixo da IA no GameState (Jogador 1 / Oponente)
const ID_IA: int = 1

## Intervalo entre ações (em segundos) para a UI conseguir animar
@export var tempo_entre_acoes: float = 1.0

## Referência ao BattleManager (Autoload singleton)
var battle_manager: Node = null


func inicializar(p_battle_manager: Node) -> void:
	self.battle_manager = p_battle_manager
	
	if TurnManager:
		_conectar_sinal_seguro(TurnManager.turno_iniciado, _on_turno_iniciado)
		# Conecta o sinal de solicitação de substituição de ativo
		_conectar_sinal_seguro(TurnManager.substituicao_ativo_solicitada, _on_substituicao_ativo_solicitada)


func _exit_tree() -> void:
	if TurnManager and TurnManager.turno_iniciado.is_connected(_on_turno_iniciado):
		TurnManager.turno_iniciado.disconnect(_on_turno_iniciado)


func _on_turno_iniciado(jogador_id_ativo: int) -> void:
	if jogador_id_ativo != ID_IA:
		return

	print("🤖 IA: Iniciando processamento do turno...")
	_executar_rotina_turno()


func _executar_rotina_turno() -> void:
	# O oponente sempre corresponde a GameState.jogador_2 (ID 1)
	var estado_ia: PlayerState = GameState.jogador_2
	
	await get_tree().create_timer(tempo_entre_acoes).timeout

	# 1. Tenta baixar animais Filhotes no banco
	await _tentar_baixar_animais_no_banco(estado_ia)

	# 2. Tenta anexar energia da mão a um animal
	await _tentar_anexar_energias(estado_ia)

	# 3. Passa o turno se não houver mais ações
	await get_tree().create_timer(tempo_entre_acoes).timeout
	_finalizar_turno()


func _tentar_baixar_animais_no_banco(estado_ia: PlayerState) -> void:
	var mao_copia: Array = estado_ia.mao.duplicate()

	for carta in mao_copia:
		# Validação usando as propriedades oficiais do seu CardResource (stage == "Filhote")
		if carta is CardResource and carta.stage == "Filhote":
			# CORREÇÃO: Consulta o banco da IA via GameState
			var banco_ia: Array = GameState.obter_banco(ID_IA)
			
			if banco_ia.size() < RuleValidator.TAMANHO_MAXIMO_BANCO:
				var indice_real: int = estado_ia.mao.find(carta)
				if indice_real != -1:
					print("🤖 IA: Baixando %s no banco..." % carta.name)
					
					# Envia exatamente as chaves esperadas pelo _jogar_para_banco do BattleManager
					battle_manager.processar_acao("jogar_para_banco", {
						"indice_mao": indice_real,
						"carta": carta
					})
					
					await get_tree().create_timer(tempo_entre_acoes).timeout
					
func _tentar_anexar_energias(estado_ia: PlayerState) -> void:
	# Se a IA já anexou energia neste turno, interrompe
	if GameState.energia_anexada_neste_turno:
		return

	var mao_copia: Array = estado_ia.mao.duplicate()

	# CORREÇÃO: Busca ativo e banco da IA via GameState
	var ativo_ia: AnimalInstance = GameState.obter_ativo(ID_IA)
	var banco_ia: Array = GameState.obter_banco(ID_IA)

	for carta in mao_copia:
		# Validação usando a propriedade oficial do seu EffectResource (super_type == "energia")
		if carta is EffectResource and carta.super_type == "energia":
			var alvo: AnimalInstance = null

			# Prioridade 1: Anexar no Animal Ativo
			if ativo_ia != null:
				alvo = ativo_ia
			# Prioridade 2: Anexar no primeiro animal do banco
			elif not banco_ia.is_empty():
				alvo = banco_ia[0]

			if alvo != null:
				var indice_real: int = estado_ia.mao.find(carta)
				if indice_real != -1:
					print("🤖 IA: Anexando energia em %s..." % alvo.card.name)
					
					# Envia exatamente as chaves esperadas pelo _anexar_energia do BattleManager
					var res = battle_manager.processar_acao("anexar_energia", {
						"indice_mao": indice_real,
						"carta": carta,
						"animal": alvo
					})
					
					if res.get("sucesso", false):
						await get_tree().create_timer(tempo_entre_acoes).timeout
						break

func _on_substituicao_ativo_solicitada(jogador_id: int) -> void:
	# Responde apenas se a solicitação for para o ID desta IA
	if jogador_id != ID_IA:
		return

	print("🤖 IA: Recebeu solicitação para substituir ativo nocauteado/faminto.")
	_decidir_e_promover_ativo()


func _decidir_e_promover_ativo() -> void:
	var banco_ia: Array = GameState.obter_banco(ID_IA)
	
	if banco_ia.is_empty():
		push_error("❌ [AIController] IA solicitada para promover ativo, mas o banco está vazio!")
		return

	# Têmpora / Delay para simular pensamento e dar tempo para animações na UI
	await get_tree().create_timer(tempo_entre_acoes).timeout

	# LÓGICA DA IA (Aqui você poderá evoluir para escolher o animal com mais energia/HP no futuro)
	var substituto_escolhido: AnimalInstance = banco_ia[0] 

	print("🤖 IA: Escolheu promover '%s' para a posição ativa." % substituto_escolhido.card.name)

	# Processa a ação via BattleManager
	var res = battle_manager.processar_acao("promover_ativo", {
		"jogador_id": ID_IA,
		"substituto": substituto_escolhido
	})

	# Notifica o TurnManager que a substituição da IA foi concluída
	if res.get("sucesso", false):
		TurnManager.notificar_ativo_substituido(ID_IA)


# Função utilitária interna para evitar conexões duplicadas
func _conectar_sinal_seguro(sinal: Signal, metodo: Callable) -> void:
	if not sinal.is_connected(metodo):
		sinal.connect(metodo)

func _finalizar_turno() -> void:
	print("🤖 IA: Finalizando o turno.")
	TurnManager.fase_final()
