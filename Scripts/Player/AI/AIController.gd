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
		
	
	if self.battle_manager and self.battle_manager.has_signal("acao_resolvida"):
		_conectar_sinal_seguro(self.battle_manager.acao_resolvida, _on_acao_resolvida)

func _exit_tree() -> void:
	if TurnManager and TurnManager.turno_iniciado.is_connected(_on_turno_iniciado):
		TurnManager.turno_iniciado.disconnect(_on_turno_iniciado)


func _on_turno_iniciado(jogador_id_ativo: int) -> void:
	if jogador_id_ativo != ID_IA:
		return

	print("🤖 IA: Iniciando processamento do turno...")
	_executar_rotina_turno()


func _executar_rotina_turno() -> void:
		
	var estado_ia: PlayerState = GameState.jogador_2
	
	await get_tree().create_timer(tempo_entre_acoes).timeout

	# 1. ALIMENTAR: Passa o estado_ia diretamente
	await _tentar_alimentar_animal(estado_ia)

	# 2. BANCO: Tenta baixar animais Filhotes no banco
	await _tentar_baixar_animais_no_banco(estado_ia)

	# 3. ENERGIA: Tenta anexar energia da mão a um animal
	await _tentar_anexar_energias(estado_ia)

	# 4. PASSA TURNO: Finaliza o turno após as ações
	await get_tree().create_timer(tempo_entre_acoes).timeout
	_finalizar_turno()
func _tentar_alimentar_animal(estado_ia: PlayerState) -> void:
	var ativo_ia: AnimalInstance = GameState.obter_ativo(ID_IA)
	if ativo_ia == null:
		return

	# Acessa diretamente a variável do PlayerState
	var comida: int = estado_ia.comida_disponivel
	if comida <= 0:
		return

	# Garante a distribuição de no máximo 2 pontos
	var qtd_comida: int = mini(2, comida)
	print("🤖 IA: Distribuindo %d ponto(s) de comida para %s..." % [qtd_comida, ativo_ia.card.name])

	battle_manager.processar_acao("distribuir_comida", {
		"animal": ativo_ia,
		"quantidade": qtd_comida
	})

	await get_tree().create_timer(tempo_entre_acoes).timeout
func _tentar_baixar_animais_no_banco(estado_ia: PlayerState) -> void:
	var mao_copia: Array = estado_ia.mao.duplicate()

	for carta in mao_copia:
		if carta is CardResource and carta.stage == "Filhote":
			var banco_ia: Array = GameState.obter_banco(ID_IA)
			
			if banco_ia.size() < RuleValidator.TAMANHO_MAXIMO_BANCO:
				var indice_real: int = estado_ia.mao.find(carta)
				if indice_real != -1:
					print("🤖 IA: Baixando %s no banco..." % carta.name)
					
					battle_manager.processar_acao("jogar_para_banco", {
						"indice_mao": indice_real,
						"carta": carta
					})
					
					await get_tree().create_timer(tempo_entre_acoes).timeout
func _tentar_anexar_energias(estado_ia: PlayerState) -> void:
	if GameState.energia_anexada_neste_turno:
		return

	var mao_copia: Array = estado_ia.mao.duplicate()
	var ativo_ia: AnimalInstance = GameState.obter_ativo(ID_IA)
	var banco_ia: Array = GameState.obter_banco(ID_IA)

	for carta in mao_copia:
		if carta is EffectResource and carta.super_type == "energia":
			var alvo: AnimalInstance = null

			if ativo_ia != null:
				alvo = ativo_ia
			elif not banco_ia.is_empty():
				alvo = banco_ia[0]

			if alvo != null:
				var indice_real: int = estado_ia.mao.find(carta)
				if indice_real != -1:
					print("🤖 IA: Anexando energia em %s..." % alvo.card.name)
					
					var res = battle_manager.processar_acao("anexar_energia", {
						"indice_mao": indice_real,
						"carta": carta,
						"animal": alvo
					})
					
					if res.get("sucesso", false):
						await get_tree().create_timer(tempo_entre_acoes).timeout
						break
func _on_acao_resolvida(_tipo_acao: String, sucesso: bool, _motivo: String, _dados: Dictionary) -> void:
	# 🟢 TRAVA DE SEGURANÇA
	if not GameState.partida_ativa or GameState.vencedor != null:
		return

	if not sucesso:
		return

func _conectar_sinal_seguro(sinal: Signal, metodo: Callable) -> void:
	if not sinal.is_connected(metodo):
		sinal.connect(metodo)
func _finalizar_turno() -> void:
	print("🤖 IA: Finalizando o turno.")
	TurnManager.fase_final()
