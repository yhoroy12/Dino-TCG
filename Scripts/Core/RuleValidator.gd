# ==================================================

# Nome: RuleValidator

# Categoria: Core

# Responsável por validar TODAS as regras oficiais

# do Dino TCG.

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
## Valida o resultado do sorteio inicial.
static func validate_coin_flip(game_state) -> bool:
	
	pass

## Valida a mão inicial do jogador.

static func validate_starting_hand(player) -> bool:
	pass

## Valida as condições para mulligan.

static func validate_mulligan(player) -> bool:
	pass

## Valida o Animal Ativo inicial.

static func validate_active_animal(card) -> bool:
pass

## Valida o Banco Inicial.

static func validate_initial_bench(player) -> bool:
pass

## Valida se a partida pode iniciar.

static func validate_match_start(game_state) -> bool:
pass

# ==================================================

# REGRAS DE BARALHO

# ==================================================

## Valida construção do deck.

static func validate_deck(deck) -> bool:
pass

## Valida quantidade de cartas.

static func validate_deck_size(deck) -> bool:
pass

## Valida limite de cópias.

static func validate_card_copies(deck) -> bool:
pass

## Valida presença obrigatória de filhote.

static func validate_baby_requirement(deck) -> bool:
pass

# ==================================================

# COMPRA DE CARTAS

# ==================================================

## Valida compra de carta.

static func validate_card_draw(player, game_state) -> bool:
pass

## Valida condição de deck out.

static func validate_deck_out(player) -> bool:
pass

# ==================================================

# BANCO RESERVA

# ==================================================

## Valida entrada de animal no banco.

static func validate_bench_placement(card, player) -> bool:
pass

## Valida limite de banco.

static func validate_bench_size(player) -> bool:
pass

# ==================================================

# EVOLUÇÃO

# ==================================================

## Valida crescimento de um animal.

static func validate_evolution(instancia, nova_carta, game_state) -> bool:
pass

## Valida linhagem evolutiva.

static func validate_evolution_line(instancia, nova_carta) -> bool:
pass

## Valida requisito de comida.

static func validate_evolution_food(instancia) -> bool:
pass

## Valida permanência mínima em campo.

static func validate_evolution_turn_requirement(instancia) -> bool:
pass

# ==================================================

# SISTEMA DE COMIDA

# ==================================================

## Valida distribuição de comida.

static func validate_food_distribution(player, targets) -> bool:
pass

## Valida limite de comida.

static func validate_food_limit(animal) -> bool:
pass

## Valida dieta do animal.

static func validate_food_type(animal, food_type) -> bool:
pass

## Valida consumo obrigatório.

static func validate_food_consumption(animal) -> bool:
pass

## Valida fome.

static func validate_starvation(animal) -> bool:
pass

# ==================================================

# ENERGIAS

# ==================================================

## Valida anexação de energia.

static func validate_energy_attachment(player, animal, energy) -> bool:
pass

## Valida limite de energia por turno.

static func validate_energy_attachment_limit(player) -> bool:
pass

## Valida custo de energia.

static func validate_energy_cost(animal, cost) -> bool:
pass

## Valida energias anexadas.

static func validate_attached_energies(animal) -> bool:
pass

# ==================================================

# HABILIDADES

# ==================================================

## Valida ativação de habilidade.

static func validate_ability_use(ability, source, game_state) -> bool:
pass

## Valida gatilho.

static func validate_trigger(trigger, game_state) -> bool:
pass

## Valida condição.

static func validate_condition(condition, source) -> bool:
pass

## Valida alvo.

static func validate_target(target, source, game_state) -> bool:
pass

## Valida custo da habilidade.

static func validate_ability_cost(ability, source) -> bool:
pass

# ==================================================

# VESTÍGIOS

# ==================================================

## Valida uso de vestígio.

static func validate_fossil_card(card, player, game_state) -> bool:
pass

# ==================================================

# CATACLISMOS

# ==================================================

## Valida uso de cataclismo.

static func validate_cataclysm(card, player, game_state) -> bool:
pass

## Valida limite de cataclismos.

static func validate_cataclysm_limit(player) -> bool:
pass

# ==================================================

# TERRITÓRIOS

# ==================================================

## Valida entrada de território.

static func validate_territory(card, game_state) -> bool:
pass

## Valida substituição de território.

static func validate_territory_replacement(card, game_state) -> bool:
pass

# ==================================================

# CONDIÇÕES ESPECIAIS

# ==================================================

## Valida aplicação de condição.

static func validate_status_application(target, status) -> bool:
pass

## Valida remoção de condição.

static func validate_status_removal(target, status) -> bool:
pass

# ==================================================

# SONO

# ==================================================

## Valida regras de sono.

static func validate_sleep(animal) -> bool:
pass

# ==================================================

# PARALISIA

# ==================================================

## Valida regras de paralisia.

static func validate_paralysis(animal) -> bool:
pass

# ==================================================

# ENVENENAMENTO

# ==================================================

## Valida regras de veneno.

static func validate_poison(animal) -> bool:
pass

# ==================================================

# SANGRAMENTO

# ==================================================

## Valida regras de sangramento.

static func validate_bleeding(animal) -> bool:
pass

# ==================================================

# RECUO

# ==================================================

## Valida recuo.

static func validate_retreat(animal, player, game_state) -> bool:
pass

## Valida pagamento do custo de recuo.

static func validate_retreat_cost(animal) -> bool:
pass

## Valida escolha do novo ativo.

static func validate_retreat_target(animal, replacement) -> bool:
pass

# ==================================================

# ATAQUE

# ==================================================

## Valida declaração de ataque.

static func validate_attack(attacker, attack_data, game_state) -> bool:
pass

## Valida custo do ataque.

static func validate_attack_cost(attacker, attack_data) -> bool:
pass

## Valida alvo do ataque.

static func validate_attack_target(attacker, defender) -> bool:
pass

# ==================================================

# DANO

# ==================================================

## Valida aplicação de dano.

static func validate_damage(source, target, amount) -> bool:
pass

# ==================================================

# FRAQUEZA

# ==================================================

## Valida aplicação de fraqueza.

static func validate_weakness(attacker, defender) -> bool:
pass

# ==================================================

# RESISTÊNCIA

# ==================================================

## Valida aplicação de resistência.

static func validate_resistance(attacker, defender) -> bool:
pass

# ==================================================

# NOCAUTE

# ==================================================

## Valida nocaute.

static func validate_knockout(animal) -> bool:
pass

## Valida envio para zona fóssil.

static func validate_fossil_zone_transfer(animal) -> bool:
pass

## Valida escolha de novo ativo após nocaute.

static func validate_replacement_active(player) -> bool:
pass

# ==================================================

# CONDIÇÕES DE VITÓRIA

# ==================================================

## Valida vitória por nocautes.

static func validate_knockout_victory(game_state) -> bool:
pass

## Valida vitória por campo vazio.

static func validate_empty_field_victory(game_state) -> bool:
pass

## Valida vitória por deck out.

static func validate_deck_out_victory(game_state) -> bool:
pass

## Valida empate.

static func validate_draw_condition(game_state) -> bool:
pass

# ==================================================

# TURNO

# ==================================================

## Valida início de turno.

static func validate_turn_start(game_state) -> bool:
pass

## Valida encerramento de turno.

static func validate_turn_end(game_state) -> bool:
pass

# ==================================================

# VALIDAÇÕES GERAIS

# ==================================================

## Valida execução de ação.

static func validate_action(action, source, game_state) -> bool:
pass

## Valida pagamento de custo.

static func validate_cost(cost, source) -> bool:
pass

## Valida seleção de alvo.

static func validate_target_selection(target, source) -> bool:
pass

## Valida resolução de efeito.

static func validate_effect_resolution(effect, source) -> bool:
pass
