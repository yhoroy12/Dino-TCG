# ==================================================
# Nome: TurnManager
# Categoria: Managers
# Responsável pelo fluxo dos turnos.
# ==================================================
extends Node

# ==================================================
# SINAIS
# ==================================================
signal turno_iniciado(jogador_id: int)
signal turno_encerrado(jogador_id: int)
signal partida_encerrada(vencedor_id: int, motivo: String) 
signal substituicao_ativo_solicitada(jogador_id: int) # 👈 NOVO: Notifica a UI/IA que precisa escolher um substituto do banco


# ==================================================
# FASES DO TURNO
# ==================================================

func iniciar_turno() -> void:
	GameState.fase_atual = GameState.Fase.INICIO
	print("🟢 [TurnManager] Iniciando Turno %d | Jogador Ativo: %d" % [GameState.turno_atual, GameState.jogador_ativo])

	_resetar_flags_turno()
	fase_compra()
	
	turno_iniciado.emit(GameState.jogador_ativo)


func fase_compra() -> void:
	GameState.fase_atual = GameState.Fase.COMPRA
	print("🎴 [TurnManager] Entrou na fase_compra (Jogador %d)." % GameState.jogador_ativo)

	# Checa se o jogador da vez perdeu por falta de deck
	var res_deck = WinConditionSystem.checar_vitoria_por_deckout(GameState.jogador_ativo)
	if _verificar_e_notificar_fim_de_jogo(res_deck, "Jogador sem cartas no baralho no início do turno!"):
		return # Interrompe o turno, o jogo acabou.

	DrawSystem.comprar_carta(GameState.get_jogador_atual())
	fase_comida()


func fase_comida() -> void:
	GameState.fase_atual = GameState.Fase.COMIDA
	print("🥩 [TurnManager] Entrou na fase_comida (Jogador %d)." % GameState.jogador_ativo)
	
	FoodSystem.ganhar_pool_comida(GameState.get_jogador_atual())
	fase_principal()


func fase_principal() -> void:
	GameState.fase_atual = GameState.Fase.PRINCIPAL
	print("⚙️ [TurnManager] Entrou na fase_principal (Jogador %d)." % GameState.jogador_ativo)


func fase_ataque() -> void:
	GameState.fase_atual = GameState.Fase.ATAQUE
	print("⚔️ [TurnManager] Entrou na fase_ataque (Jogador %d)." % GameState.jogador_ativo)


func fase_final() -> void:
	GameState.fase_atual = GameState.Fase.FINAL
	print("🔍 [TurnManager] Entrou na fase_final (Jogador %d)." % GameState.jogador_ativo)

	print("➡️ [TurnManager] Processando efeitos e fome de fim de turno...")
	_processar_fim_de_turno_dos_animais()

	# Avalia se a fome/efeitos causaram nocaute que deixou alguém sem campo (Vitória)
	var res_campo = WinConditionSystem.checar_vitoria_por_campo_vazio()
	
	# Se houve fim de jogo, processa APENAS AQUI e interrompe o fluxo imediatamente
	if _verificar_e_notificar_fim_de_jogo(res_campo, "Sem animais no banco para substituir o ativo!"):
		return

	# 👈 CORRIGIDO: Se alguém está sem ativo, emite sinal e interrompe até a substituição ser concluída
	if GameState.jogador_sem_ativo != -1:
		var id_pendente: int = GameState.jogador_sem_ativo
		print("⚠️ [TurnManager] Travado: Jogador %d está sem ativo! Solicitando substituição..." % id_pendente)
		substituicao_ativo_solicitada.emit(id_pendente)
		return

	print("🔄 [TurnManager] Fim de turno validado. Avançando para o próximo turno!")
	_encerrar_fase_final_e_passar_turno()


## 👈 NOVO: Chamado externamente (via BattleManager ou MesaUI) assim que a substituição do ativo for concluída.
func notificar_ativo_substituido(jogador_id: int) -> void:
	if GameState.jogador_sem_ativo == jogador_id and GameState.obter_ativo(jogador_id) != null:
		print("✅ [TurnManager] Ativo do Jogador %d foi promovido com sucesso! Retomando validação do turno..." % jogador_id)
		GameState.jogador_sem_ativo = -1
		fase_final() # Reavalia a fase final para concluir o turno
	else:
		push_error("❌ [TurnManager] Erro ao tentar validar substituição para o Jogador %d." % jogador_id)

	
func _encerrar_fase_final_e_passar_turno() -> void:
	print("🏁 [TurnManager] Finalizando turno do Jogador %d." % GameState.jogador_ativo)
	turno_encerrado.emit(GameState.jogador_ativo)
	_passar_turno()

# ==================================================
# FUNÇÕES PRIVADAS E SISTEMAS
# ==================================================

func _passar_turno() -> void:
	_trocar_jogador()
	GameState.turno_atual += 1
	print("🔀 [TurnManager] Alternando turno. Novo Jogador Ativo: %d | Novo Turno: %d" % [GameState.jogador_ativo, GameState.turno_atual])
	iniciar_turno()


func _trocar_jogador() -> void:
	GameState.jogador_ativo = 1 if GameState.jogador_ativo == 0 else 0


func _resetar_flags_turno() -> void:
	print("🧹 [TurnManager] Resetando flags do turno do Jogador %d..." % GameState.jogador_ativo)
	GameState.energia_anexada_neste_turno = false
	GameState.recuo_realizado_neste_turno = false
	GameState.cataclismo_jogado_neste_turno = false

	for animal in GameState.obter_animais_em_campo(GameState.jogador_ativo):
		animal.evoluiu_este_turno = false


func atualizar_sistema_de_nocautes(player: PlayerState, player_id: int) -> void:
	print("💥 [TurnManager] Checando nocautes para o Jogador %d..." % player_id)
	var nocauteados = KnockoutSystem.processar_todos_nocautes(player)
	
	if GameState.obter_ativo(player_id) == null and not GameState.obter_banco(player_id).is_empty():
		GameState.jogador_sem_ativo = player_id
		print("⚠️ [TurnManager] Jogador %d ficou sem animal ativo, mas possui reserva no banco." % player_id)


func _processar_fim_de_turno_dos_animais() -> void:
	var id_da_vez: int = GameState.jogador_ativo
	var id_adversario: int = 1 if id_da_vez == 0 else 0

	for animal in GameState.obter_animais_em_campo(id_da_vez):
		ConditionSystem.processar_fim_de_turno(animal)
		EffectSystem.processar_fim_de_turno(animal, true)
		animal.entrou_este_turno = false

	for animal in GameState.obter_animais_em_campo(id_adversario):
		ConditionSystem.processar_fim_de_turno(animal)
		EffectSystem.processar_fim_de_turno(animal, false)

	FoodSystem.aplicar_reducao_passiva(GameState.get_jogador_atual())
	atualizar_sistema_de_nocautes(GameState.get_jogador_atual(), id_da_vez)


## Função auxiliar interna no TurnManager.gd para validar vitórias:
func _verificar_e_notificar_fim_de_jogo(resultado: WinConditionSystem.Resultado, motivo: String) -> bool:
	if resultado == WinConditionSystem.Resultado.NENHUM:
		return false

	# 1. Atualiza GameState
	WinConditionSystem.processar_resultado(resultado, motivo)

	# 2. Pega o ID numérico correto (0, 1 ou -1)
	var vencedor_id: int = WinConditionSystem.obter_vencedor_id(resultado)

	# 3. Emite o sinal UMA ÚNICA VEZ
	print("📢 [TurnManager] EMITINDO SINAL: partida_encerrada(Vencedor: %d, Motivo: '%s')" % [vencedor_id, motivo])
	partida_encerrada.emit(vencedor_id, motivo)
	return true
