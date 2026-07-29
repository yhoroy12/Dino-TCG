# ==================================================
# Nome: RuleValidator
# Categoria: Core
# Responsável por validar TODAS as regras oficiais
# do Dino TCG.
#
# Não altera estado da partida.
# Não compra cartas.
# Não aplica dano.
# Não move cartas.
# Não executa efeitos.
#
# Apenas verifica se uma ação é válida
# de acordo com o Rulebook.
# ==================================================
class_name RuleValidator


# ==================================================
# SETUP DA PARTIDA
# ==================================================

static func validate_coin_flip(_game_state) -> bool:
	return false


static func validate_starting_hand(_player) -> bool:
	return false


static func validate_mulligan(_player) -> bool:
	return false


static func validate_active_animal(_card) -> bool:
	return false


static func validate_initial_bench(_player) -> bool:
	return false


static func validate_match_start(_game_state) -> bool:
	return false


# ==================================================
# REGRAS DE BARALHO
# ==================================================

static func validate_deck(deck: DeckData) -> bool:
	if deck == null:
		return false

	return DeckRulesSystem.validar_deck(deck)["valido"]


static func validate_deck_size(deck: DeckData) -> bool:
	if deck == null:
		return false

	return deck.cartas.size() == DeckRulesSystem.TAMANHO_DECK_VALIDO


static func validate_card_copies(deck: DeckData) -> bool:
	if deck == null:
		return false

	for carta in deck.cartas:
		var limite: int = DeckRulesSystem.obter_limite_copias(carta)
		var copias: int = DeckRulesSystem.contar_copias(deck.cartas, carta.id)

		if copias > limite:
			return false

	return true


static func validate_baby_requirement(deck: DeckData) -> bool:
	if deck == null:
		return false

	return DeckRulesSystem.validar_deck(deck)["possui_filhote"]


# ==================================================
# COMPRA DE CARTAS
# ==================================================

static func validate_card_draw(_player, _game_state) -> bool:
	return false


static func validate_deck_out(_player) -> bool:
	return false


# ==================================================
# BANCO RESERVA
# ==================================================

const TAMANHO_MAXIMO_BANCO: int = 4


static func validate_bench_placement(card, player: PlayerState) -> bool:
	if card == null or player == null:
		return false

	if not (card is CardResource):
		return false

	if card.super_type != "animal":
		return false

	if card.stage != "Filhote":
		return false

	return validate_bench_size(player)


static func validate_bench_size(player: PlayerState) -> bool:
	if player == null:
		return false

	return GameState.obter_banco(player.id).size() < TAMANHO_MAXIMO_BANCO


# ==================================================
# EVOLUÇÃO
# ==================================================

static func validate_evolution(instancia: AnimalInstance, nova_carta: CardResource, _game_state = null) -> bool:
	return EvolutionSystem.pode_crescer(instancia, nova_carta)


static func validate_evolution_line(instancia: AnimalInstance, nova_carta: CardResource) -> bool:
	if instancia == null or nova_carta == null:
		return false

	return nova_carta.grow_from == instancia.card.id


static func validate_evolution_food(_instancia) -> bool:
	return false


static func validate_evolution_turn_requirement(_instancia) -> bool:
	return false


# ==================================================
# SISTEMA DE COMIDA
# ==================================================

static func validate_food_distribution(player: PlayerState, animal: AnimalInstance, quantidade: int) -> bool:
	if player == null or animal == null:
		return false

	if quantidade <= 0:
		return false

	if quantidade > player.comida_disponivel:
		return false

	var ativo := GameState.obter_ativo(player.id)
	var banco := GameState.obter_banco(player.id)

	if animal != ativo and not banco.has(animal):
		return false

	return true


static func validate_food_limit(_animal) -> bool:
	return false


static func validate_food_type(_animal, _food_type) -> bool:
	return false


static func validate_food_consumption(_animal) -> bool:
	return false


static func validate_starvation(animal: AnimalInstance) -> bool:
	if animal == null:
		return false

	return animal.current_food <= 0


# ==================================================
# ENERGIAS
# ==================================================

static func validate_energy_attachment(player: PlayerState, animal: AnimalInstance, energy) -> bool:
	if player == null or animal == null or energy == null:
		return false

	if not (energy is EffectResource):
		return false

	if energy.super_type != "energia":
		return false

	var ativo := GameState.obter_ativo(player.id)
	var banco := GameState.obter_banco(player.id)

	if animal != ativo and not banco.has(animal):
		return false

	return validate_energy_attachment_limit(player)


static func validate_energy_attachment_limit(player) -> bool:
	if player == null:
		return false

	return not GameState.energia_anexada_neste_turno


static func validate_energy_cost(_animal, _cost) -> bool:
	return false


static func validate_attached_energies(_animal) -> bool:
	return false


# ==================================================
# HABILIDADES
# ==================================================

static func validate_ability_use(_ability, _source, _game_state) -> bool:
	return false


static func validate_trigger(_trigger, _game_state) -> bool:
	return false


static func validate_condition(_condition, _source) -> bool:
	return false


static func validate_target(_target, _source, _game_state) -> bool:
	return false


static func validate_ability_cost(_ability, _source) -> bool:
	return false


# ==================================================
# VESTÍGIOS
# ==================================================

static func validate_fossil_card(_card, _player, _game_state) -> bool:
	return false


# ==================================================
# CATACLISMOS
# ==================================================

static func validate_cataclysm(_card, _player, _game_state) -> bool:
	return false


static func validate_cataclysm_limit(_player) -> bool:
	return false


# ==================================================
# TERRITÓRIOS
# ==================================================

static func validate_territory(_card, _game_state) -> bool:
	return false


static func validate_territory_replacement(_card, _game_state) -> bool:
	return false


# ==================================================
# CONDIÇÕES ESPECIAIS
# ==================================================

static func validate_status_application(_target, _status) -> bool:
	return false


static func validate_status_removal(_target, _status) -> bool:
	return false


# ==================================================
# SONO / PARALISIA / VENENO / SANGRAMENTO
# ==================================================

static func validate_sleep(_animal) -> bool:
	return false


static func validate_paralysis(_animal) -> bool:
	return false


static func validate_poison(_animal) -> bool:
	return false


static func validate_bleeding(_animal) -> bool:
	return false


# ==================================================
# RECUO
# ==================================================

static func validate_retreat_possivel(animal: AnimalInstance, player: PlayerState) -> bool:
	if animal == null or player == null:
		return false

	var ativo := GameState.obter_ativo(player.id)

	if animal != ativo:
		return false

	if GameState.recuo_realizado_neste_turno:
		return false

	if not ConditionSystem.pode_tentar_acao(animal, "recuar"):
		return false

	if animal.attached_energies.size() < animal.card.cost_retreat:
		return false

	return validate_replacement_active(player)


static func validate_retreat(animal: AnimalInstance, player: PlayerState, energias_selecionadas: Array = [], _game_state = null) -> bool:
	if not validate_retreat_possivel(animal, player):
		return false

	return validate_retreat_cost(animal, energias_selecionadas)


static func validate_retreat_cost(animal: AnimalInstance, energias_selecionadas: Array = []) -> bool:
	if animal == null or animal.card == null:
		return false

	var custo: int = animal.card.cost_retreat

	if custo <= 0:
		return true

	if energias_selecionadas.size() != custo:
		return false

	for energia in energias_selecionadas:
		if not animal.attached_energies.has(energia):
			return false

	return true


static func validate_retreat_target(player: PlayerState, replacement: AnimalInstance) -> bool:
	if player == null or replacement == null:
		return false

	var banco := GameState.obter_banco(player.id)

	if not banco.has(replacement):
		return false

	return replacement.current_hp > 0


# ==================================================
# ATAQUE & COMBATE
# ==================================================

## Valida se o jogador ativo pode realizar um ataque neste momento.
## Retorna um Dictionary: {"sucesso": bool, "motivo": String}
static func validar_atacar(jogador_id: int) -> Dictionary:
	print("\n🔍 [RuleValidator] Iniciando validação de ataque para o Jogador %d..." % jogador_id)

	# --------------------------------------------------
	# BLOCO 1: Estado do Jogo e Turno
	# --------------------------------------------------
	if not GameState.partida_ativa:
		var msg := "A partida não está ativa."
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}

	if GameState.jogador_ativo != jogador_id:
		var msg := "Não é o seu turno de jogar."
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}

	if GameState.fase_atual != GameState.Fase.PRINCIPAL:
		var msg := "Ataques só podem ser realizados durante a Fase Principal."
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}

	# Regra oficial TCG: O primeiro jogador não pode atacar no primeiro turno do jogo
	if GameState.turno_atual <= 1:
		var msg := "Não é permitido atacar no Turno 1 do jogo."
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}


	# --------------------------------------------------
	# BLOCO 2: Validação do Atacante (Seu Animal Ativo)
	# --------------------------------------------------
	var atacante: AnimalInstance = GameState.obter_ativo(jogador_id)
	if atacante == null:
		var msg := "Você não possui um animal ativo na mesa para atacar."
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}

	if atacante.current_hp <= 0:
		var msg := "%s está nocauteado e não pode atacar." % atacante.card.name
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}

	if atacante.ja_atacou_este_turno:
		var msg := "%s já realizou um ataque neste turno." % atacante.card.name
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}


	# --------------------------------------------------
	# BLOCO 3: Condições Especiais e Status
	# --------------------------------------------------
	if not ConditionSystem.pode_tentar_acao(atacante, "atacar"):
		var status_nome: String = ConditionSystem.Tipo.keys()[ConditionSystem.obter_condicao(atacante)]
		var msg := "%s está impedido de atacar devido ao status: %s." % [atacante.card.name, status_nome]
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}


	# --------------------------------------------------
	# BLOCO 4: Energias Suficientes (Usa o Passo 1)
	# --------------------------------------------------
	if not atacante.pode_usar_ataque(atacante.card):
		var msg := "%s não possui as energias necessárias anexadas para este ataque." % atacante.card.name
		print("❌ [RuleValidator] Recusado: %s (Custo: %s | Anexadas: %d)" % [
			msg, 
			atacante.card.attack_cost, 
			atacante.attached_energies.size()
		])
		return {"sucesso": false, "motivo": msg}


	# --------------------------------------------------
	# BLOCO 5: Validação do Defensor (Oponente)
	# --------------------------------------------------
	var id_oponente: int = 1 if jogador_id == 0 else 0
	var defensor: AnimalInstance = GameState.obter_ativo(id_oponente)

	if defensor == null:
		var msg := "O oponente não possui um animal ativo no campo para ser atacado."
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}

	if defensor.current_hp <= 0:
		var msg := "O animal ativo do oponente já está nocauteado."
		print("❌ [RuleValidator] Recusado: %s" % msg)
		return {"sucesso": false, "motivo": msg}


	# --------------------------------------------------
	# SUCESSO: Todas as regras foram atendidas
	# --------------------------------------------------
	print("✅ [RuleValidator] Ataque AUTORIZADO! %s -> %s" % [atacante.card.name, defensor.card.name])
	return {"sucesso": true, "motivo": "Ataque autorizado."}


## Wrapper booleano mantido para compatibilidade com chamadas simples de outros sistemas
static func validate_attack(atacante: AnimalInstance, ataque: CardResource) -> bool:
	if atacante == null:
		return false
	# Descobre quem é o dono do atacante no GameState
	var jogador_id: int = 0 if GameState.obter_ativo(0) == atacante else 1
	var resultado := validar_atacar(jogador_id)
	return resultado["sucesso"]

# ==================================================
# DANO / FRAQUEZA / RESISTÊNCIA / NOCAUTE
# ==================================================

static func validate_damage(
	source: AnimalInstance,
	target: AnimalInstance,
	amount: int
) -> bool:

	if source == null or target == null:
		return false

	if amount < 0:
		return false

	if target.current_hp <= 0:
		return false

	return true


static func validate_weakness(
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> bool:

	if atacante == null or defensor == null:
		return false

	return defensor.card.weakness != "" and defensor.card.weakness == atacante.card.color


static func validate_resistance(
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> bool:

	if atacante == null or defensor == null:
		return false

	return defensor.card.resistance != "" and defensor.card.resistance == atacante.card.color


static func validate_knockout(animal: AnimalInstance) -> bool:
	if animal == null:
		return false

	return animal.current_hp <= 0


static func validate_fossil_zone_transfer(animal: AnimalInstance) -> bool:
	return animal != null


static func validate_replacement_active(player: PlayerState) -> bool:
	if player == null:
		return false

	return not GameState.obter_banco(player.id).is_empty()


# ==================================================
# CONDIÇÕES DE VITÓRIA & TURNO
# ==================================================

static func validate_knockout_victory(_game_state) -> bool:
	return false


static func validate_empty_field_victory(_game_state) -> bool:
	return false


static func validate_deck_out_victory(_game_state) -> bool:
	return false


static func validate_draw_condition(_game_state) -> bool:
	return false


static func validate_turn_start(_game_state) -> bool:
	return false


static func validate_turn_end(_game_state) -> bool:
	return false


static func validate_action(_action, _source, _game_state) -> bool:
	return false


static func validate_cost(_cost, _source) -> bool:
	return false


static func validate_target_selection(_target, _source) -> bool:
	return false


static func validate_effect_resolution(_effect, _source) -> bool:
	return false
## Valida se o jogador ativo pode realizar um ataque neste momento.
## Retorna um Dictionary com {"sucesso": bool, "motivo": String}
