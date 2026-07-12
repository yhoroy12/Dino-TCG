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
#
# STATUS DESTE ARQUIVO:
# - Bloco ATAQUE / DANO / FRAQUEZA / RESISTÊNCIA / NOCAUTE:
#   implementado (prioridade 2 do projeto).
# - Todos os outros blocos: sintaxe corrigida, mas ainda são
#   esqueleto (pass). Serão implementados na ordem de
#   prioridade do projeto (Setup > Mecânicas centrais >
#   Vitória > Condições especiais > Território > Vestígio >
#   Cataclismo).
#
# GameState é autoload — por isso as funções aqui NÃO recebem
# "game_state" como parâmetro; acessam GameState.algo direto,
# assim como TurnManager e SetupManager já fazem.
# ==================================================
class_name RuleValidator


# ==================================================
# SETUP DA PARTIDA
# ==================================================

## Valida o resultado do sorteio inicial.
static func validate_coin_flip(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida a mão inicial do jogador.
static func validate_starting_hand(player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida as condições para mulligan.
static func validate_mulligan(player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida o Animal Ativo inicial.
static func validate_active_animal(card) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida o Banco Inicial.
static func validate_initial_bench(player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida se a partida pode iniciar.
static func validate_match_start(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# REGRAS DE BARALHO
# ==================================================

## Valida construção do deck.
##
## Delega para DeckRulesSystem, que é a implementação real (também usada
## ao vivo pela UI do deck_builder) — evita duas fontes de verdade para
## a mesma regra.
static func validate_deck(deck: DeckData) -> bool:
	if deck == null:
		return false

	return DeckRulesSystem.validar_deck(deck)["valido"]


## Valida quantidade de cartas.
static func validate_deck_size(deck: DeckData) -> bool:
	if deck == null:
		return false

	return deck.cartas.size() == DeckRulesSystem.TAMANHO_DECK_VALIDO


## Valida limite de cópias.
static func validate_card_copies(deck: DeckData) -> bool:
	if deck == null:
		return false

	for carta in deck.cartas:
		var limite: int = DeckRulesSystem.obter_limite_copias(carta)
		var copias: int = DeckRulesSystem.contar_copias(deck.cartas, carta.id)

		if copias > limite:
			return false

	return true


## Valida presença obrigatória de filhote.
static func validate_baby_requirement(deck: DeckData) -> bool:
	if deck == null:
		return false

	return DeckRulesSystem.validar_deck(deck)["possui_filhote"]


# ==================================================
# COMPRA DE CARTAS
# ==================================================

## Valida compra de carta.
static func validate_card_draw(player, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida condição de deck out.
static func validate_deck_out(player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# BANCO RESERVA
# ==================================================

## Valida entrada de animal no banco.
static func validate_bench_placement(card, player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida limite de banco.
static func validate_bench_size(player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# EVOLUÇÃO
# ==================================================

## Valida crescimento de um animal.
static func validate_evolution(instancia, nova_carta, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida linhagem evolutiva.
static func validate_evolution_line(instancia, nova_carta) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida requisito de comida.
static func validate_evolution_food(instancia) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida permanência mínima em campo.
static func validate_evolution_turn_requirement(instancia) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# SISTEMA DE COMIDA
# ==================================================

## Valida distribuição de comida.
static func validate_food_distribution(player, targets) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida limite de comida.
static func validate_food_limit(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida dieta do animal.
static func validate_food_type(animal, food_type) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida consumo obrigatório.
static func validate_food_consumption(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida fome — usada no processamento de fim de turno do Animal
## Ativo (perda de 1 ponto de comida). Não se aplica ao Banco
## Reserva, que não perde comida ao final do turno.
##
## Implementado junto com o bloco de Nocaute porque a fome é uma
## das causas oficiais de nocaute no rulebook.
static func validate_starvation(animal: AnimalInstance) -> bool:
	if animal == null:
		return false

	return animal.current_food <= 0


# ==================================================
# ENERGIAS
# ==================================================

## Valida anexação de energia.
static func validate_energy_attachment(player, animal, energy) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida limite de energia por turno.
static func validate_energy_attachment_limit(player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida custo de energia.
static func validate_energy_cost(animal, cost) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida energias anexadas.
static func validate_attached_energies(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# HABILIDADES
# ==================================================

## Valida ativação de habilidade.
static func validate_ability_use(ability, source, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida gatilho.
static func validate_trigger(trigger, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida condição.
static func validate_condition(condition, source) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida alvo.
static func validate_target(target, source, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida custo da habilidade.
static func validate_ability_cost(ability, source) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# VESTÍGIOS
# ==================================================

## Valida uso de vestígio.
static func validate_fossil_card(card, player, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# CATACLISMOS
# ==================================================

## Valida uso de cataclismo.
static func validate_cataclysm(card, player, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida limite de cataclismos.
static func validate_cataclysm_limit(player) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# TERRITÓRIOS
# ==================================================

## Valida entrada de território.
static func validate_territory(card, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida substituição de território.
static func validate_territory_replacement(card, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# CONDIÇÕES ESPECIAIS
# ==================================================

## Valida aplicação de condição.
static func validate_status_application(target, status) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida remoção de condição.
static func validate_status_removal(target, status) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# SONO
# ==================================================

## Valida regras de sono.
static func validate_sleep(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# PARALISIA
# ==================================================

## Valida regras de paralisia.
static func validate_paralysis(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# ENVENENAMENTO
# ==================================================

## Valida regras de veneno.
static func validate_poison(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# SANGRAMENTO
# ==================================================

## Valida regras de sangramento.
static func validate_bleeding(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# RECUO
# ==================================================

## Valida recuo.
static func validate_retreat(animal, player, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida pagamento do custo de recuo.
static func validate_retreat_cost(animal) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida escolha do novo ativo.
static func validate_retreat_target(animal, replacement) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# ATAQUE
# ==================================================

## Mapa de emoji -> cor, usado para interpretar CardResource.attack_cost.
##
## ATENÇÃO: assumi essa correspondência com base em apenas 1 exemplo
## confirmado (⚪ = incolor). Confirmem se os emojis das outras 5
## cores (verde, vermelha, azul, amarela, marrom) batem exatamente
## com os usados no CSV/cartas — se não baterem, o parser abaixo
## simplesmente ignora o símbolo desconhecido, o que faria o custo
## sair menor do que deveria (bug silencioso).
const MAPA_EMOJI_COR := {
	"🟢": "verde",
	"🔴": "vermelha",
	"🔵": "azul",
	"🟡": "amarela",
	"🟤": "marrom",
	"⚪": "incolor",
}


## Converte o attack_cost (String de emojis) da carta em um
## Dictionary no formato esperado por
## AnimalInstance.tem_energias_suficientes(), ex: {"vermelha": 2, "incolor": 1}.
static func _construir_custo_do_ataque(
	ataque: CardResource
) -> Dictionary:

	var custo: Dictionary = {}

	for simbolo in ataque.attack_cost:
		var cor: String = MAPA_EMOJI_COR.get(simbolo, "")

		if cor == "":
			continue

		custo[cor] = custo.get(cor, 0) + 1

	return custo


## Valida declaração de ataque.
##
## Cobre, na ordem do rulebook:
## - Atacante e ataque existem, atacante ainda não foi nocauteado.
## - Existe um defensor (Animal Ativo do oponente).
## - Não é o turno 1 do jogo ("No primeiro turno do jogo não é
##   possível atacar").
## - O atacante não entrou em campo neste turno (regra estilo
##   Pokémon, confirmada à parte pelo time; não está no rulebook
##   escrito ainda).
## - O atacante pode TENTAR atacar de acordo com sua condição
##   especial (ex: Adormecido não pode atacar). Note que Paralisia
##   NÃO bloqueia aqui — paralisia é resolvida por sorteio de moeda
##   na hora de EXECUTAR o ataque (ConditionSystem.rodar_moeda_paralisia),
##   não na validação. Validar = "a ação pode ser tentada"; a moeda
##   decide se ela de fato acontece, e isso é responsabilidade do
##   BattleManager, não do RuleValidator.
## - O atacante tem energia suficiente para o custo do ataque.
## - O alvo é válido (Animal Ativo do oponente).
static func validate_attack(
	atacante: AnimalInstance,
	ataque: CardResource
) -> bool:

	if atacante == null or ataque == null:
		return false

	if atacante.current_hp <= 0:
		return false

	var defensor: AnimalInstance = GameState.get_jogador_adversario().ativo

	if defensor == null:
		return false

	if GameState.turno_atual <= 1:
		return false

	if atacante.entrou_este_turno:
		return false

	if not ConditionSystem.pode_tentar_acao(atacante, "atacar"):
		return false

	if not validate_attack_cost(atacante, ataque):
		return false

	if not validate_attack_target(atacante, defensor):
		return false

	return true


## Valida custo do ataque: o atacante precisa ter energia
## suficiente anexada, respeitando cores obrigatórias e incolor.
static func validate_attack_cost(
	atacante: AnimalInstance,
	ataque: CardResource
) -> bool:

	if atacante == null or ataque == null:
		return false

	var custo: Dictionary = _construir_custo_do_ataque(ataque)

	return atacante.tem_energias_suficientes(custo)


## Valida alvo do ataque.
##
## O rulebook não descreve ataques diretos ao Banco Reserva — só o
## Animal Ativo do oponente pode ser alvo.
static func validate_attack_target(
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> bool:

	if atacante == null or defensor == null:
		return false

	var jogador_defensor: PlayerState = GameState.get_jogador_adversario()

	return defensor == jogador_defensor.ativo


# ==================================================
# DANO
# ==================================================

## Valida aplicação de dano ANTES de algo (DamageSystem, quando
## existir) realmente escrever o valor em AnimalInstance.current_hp.
##
## Não recalcula o valor — isso é do CombatSystem. Aqui só se
## confirma que a operação faz sentido: fontes/alvo existem, o
## valor não é negativo, e o alvo ainda não estava nocauteado antes
## de receber esse dano (evita aplicar dano duas vezes num alvo já
## morto por outro efeito no mesmo frame).
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


# ==================================================
# FRAQUEZA
# ==================================================

## Valida se a relação de Fraqueza se aplica entre atacante e
## defensor (mesma cor do atacante == fraqueza do defensor).
##
## ATENÇÃO: o rulebook v3 diz explicitamente que "os efeitos
## mecânicos de fraqueza e resistência estão em definição". Esta
## função só confirma a RELAÇÃO (se a fraqueza é aplicável); o
## multiplicador em si (hoje 2x, hardcoded em CombatSystem) é
## provisório e precisa ser revisado quando a regra oficial for
## fechada. Hoje existe uma pequena duplicação: CombatSystem
## calcula essa mesma condição internamente para decidir o
## multiplicador. Quando a regra for fechada, o ideal é
## CombatSystem passar a chamar esta função em vez de repetir a
## comparação de cor.
static func validate_weakness(
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> bool:

	if atacante == null or defensor == null:
		return false

	return defensor.card.weakness != "" and defensor.card.weakness == atacante.card.color


# ==================================================
# RESISTÊNCIA
# ==================================================

## Mesma observação de validate_weakness: mecânica final ainda "em
## definição" no rulebook v3.
static func validate_resistance(
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> bool:

	if atacante == null or defensor == null:
		return false

	return defensor.card.resistance != "" and defensor.card.resistance == atacante.card.color


# ==================================================
# NOCAUTE
# ==================================================

## Valida nocaute por dano: HP chegou a 0.
##
## O nocaute por fome tem sua própria função (validate_starvation,
## na seção Sistema de Comida) porque só se aplica ao Animal Ativo
## e só no processamento de fim de turno — são gatilhos diferentes,
## mesma consequência (nocaute).
static func validate_knockout(
	animal: AnimalInstance
) -> bool:

	if animal == null:
		return false

	return animal.current_hp <= 0


## Valida envio para a Zona Fóssil após nocaute.
##
## Por regra, o animal e todas as cartas ligadas a ele vão para a
## Zona Fóssil do dono "a menos que uma carta diga algo diferente".
## Ainda não existe nenhuma carta de Vestígio/Cataclismo com esse
## tipo de efeito no projeto, então retorna sempre true por
## enquanto. Ponto de extensão natural quando esse tipo de carta
## existir (ex: checar EffectSystem.possui_efeito(animal, "impede_zona_fossil")).
static func validate_fossil_zone_transfer(
	animal: AnimalInstance
) -> bool:

	return animal != null


## Valida se o jogador tem um animal no Banco Reserva disponível
## para assumir como novo Animal Ativo após um nocaute. Se retornar
## false, a condição de vitória por "campo vazio" do adversário se
## aplica (RuleValidator.validate_empty_field_victory, bloco futuro).
static func validate_replacement_active(
	player: PlayerState
) -> bool:

	if player == null:
		return false

	return not player.banco.is_empty()


# ==================================================
# CONDIÇÕES DE VITÓRIA
# ==================================================

## Valida vitória por nocautes.
static func validate_knockout_victory(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida vitória por campo vazio.
static func validate_empty_field_victory(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida vitória por deck out.
static func validate_deck_out_victory(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida empate.
static func validate_draw_condition(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# TURNO
# ==================================================

## Valida início de turno.
static func validate_turn_start(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida encerramento de turno.
static func validate_turn_end(game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


# ==================================================
# VALIDAÇÕES GERAIS
# ==================================================

## Valida execução de ação.
static func validate_action(action, source, game_state) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida pagamento de custo.
static func validate_cost(cost, source) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida seleção de alvo.
static func validate_target_selection(target, source) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false


## Valida resolução de efeito.
static func validate_effect_resolution(effect, source) -> bool:
	# TODO: implementar quando este bloco entrar na ordem de prioridade.
	return false
