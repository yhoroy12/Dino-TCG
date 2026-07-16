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

## ⚠️ AJUSTE AQUI se o valor oficial for outro — hoje 4, conforme
## confirmado com o time (não é mais 5, valor antigo assumido errado).
## Nenhum outro lugar do projeto tem esse número hardcoded; só esta
## constante precisa mudar.
const TAMANHO_MAXIMO_BANCO: int = 4


## Valida entrada de um animal (vindo da mão) no Banco Reserva.
##
## Regra confirmada: só Animais Bebês (stage == "Filhote") podem ser
## colocados no Banco a partir da mão durante a Fase Principal —
## animais em estágios posteriores só chegam a campo por evolução
## (EvolutionSystem/GrowSystem), nunca direto da mão.
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


## Valida se ainda há espaço no Banco Reserva.
static func validate_bench_size(player: PlayerState) -> bool:
	if player == null:
		return false

	return player.banco.size() < TAMANHO_MAXIMO_BANCO


# ==================================================
# EVOLUÇÃO
# ==================================================

## Valida crescimento de um animal.
##
## Delega para EvolutionSystem.pode_crescer, que já cobre: não evoluir
## no turno em que entrou, não evoluir 2x no mesmo turno, e linhagem
## correta (carta_evolucao.stage_from == instancia.card.card_id) —
## evita duas fontes de verdade pra mesma regra, mesmo padrão já usado
## em validate_deck (delega pro DeckRulesSystem).
##
## game_state não é usado hoje (a regra não depende de fase/turno além
## do que já está em AnimalInstance), mas o parâmetro fica pra manter
## a assinatura consistente com o resto do arquivo e permitir extensão
## futura sem quebrar quem já chama esta função.
static func validate_evolution(instancia: AnimalInstance, nova_carta: CardResource, _game_state = null) -> bool:
	return EvolutionSystem.pode_crescer(instancia, nova_carta)


## Valida linhagem evolutiva isoladamente (sem checar turno) — útil
## pra UI destacar quais cartas da mão são evoluções válidas pro
## animal selecionado, sem se importar se ele pode evoluir *agora*.
static func validate_evolution_line(instancia: AnimalInstance, nova_carta: CardResource) -> bool:
	if instancia == null or nova_carta == null:
		return false

	return nova_carta.stage_from == instancia.card.card_id


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

## Valida distribuição de comida do pool do jogador (comida_disponivel)
## pra um animal específico.
##
## Regra confirmada (Modelo B): o jogador ganha 3 pontos de pool por
## turno, cumulativos, e distribui manualmente pra qualquer animal em
## campo (Ativo ou Banco), quantas vezes quiser, respeitando só o que
## sobrar no pool.
static func validate_food_distribution(player: PlayerState, animal: AnimalInstance, quantidade: int) -> bool:
	if player == null or animal == null:
		return false

	if quantidade <= 0:
		return false

	if quantidade > player.comida_disponivel:
		return false

	if animal != player.ativo and not player.banco.has(animal):
		return false

	return true


## Valida limite máximo de comida por animal.
##
## TODO: o rulebook não define um teto de comida por animal — deixado
## como esqueleto até essa regra existir. Enquanto não implementada,
## NÃO chamar esta função pra bloquear distribuição (validate_food_distribution
## não depende dela).
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

## Valida anexação de uma carta de energia (força primordial) a um
## animal. Cobre: energia é de fato EffectResource super_type
## "energia", animal pertence ao jogador (Ativo ou Banco), e o limite
## de 1x por turno (GameState.energia_anexada_neste_turno).
static func validate_energy_attachment(player: PlayerState, animal: AnimalInstance, energy) -> bool:
	if player == null or animal == null or energy == null:
		return false

	if not (energy is EffectResource):
		return false

	if energy.super_type != "energia":
		return false

	if animal != player.ativo and not player.banco.has(animal):
		return false

	return validate_energy_attachment_limit(player)


## Valida limite de energia por turno: só 1 anexação de força
## primordial por turno, independente de quantos animais o jogador
## tenha.
static func validate_energy_attachment_limit(player) -> bool:
	if player == null:
		return false

	return not GameState.energia_anexada_neste_turno


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

## Valida se ainda há energia suficiente ANEXADA pro custo de recuo,
## sem exigir uma seleção específica ainda — usado pra habilitar/
## desabilitar a AÇÃO na UI (ex: menu contextual), antes do jogador
## escolher quais energias exatas vai descartar.
static func validate_retreat_possivel(animal: AnimalInstance, player: PlayerState) -> bool:
	if animal == null or player == null:
		return false

	if animal != player.ativo:
		return false

	if GameState.recuo_realizado_neste_turno:
		return false

	if not ConditionSystem.pode_tentar_acao(animal, "recuar"):
		return false

	if animal.attached_energies.size() < animal.card.cost_retreat:
		return false

	return validate_replacement_active(player)


## Valida recuo do Animal Ativo (troca por um animal do Banco).
##
## `energias_selecionadas` são as energias anexadas ao animal que o
## JOGADOR escolheu descartar pra pagar o custo de recuo — a escolha
## de QUAIS energias descartar (quando há mais de uma opção que serve,
## já que o custo é uma contagem simples, sem exigir cor específica)
## é decisão estratégica do jogador, nunca automática.
static func validate_retreat(animal: AnimalInstance, player: PlayerState, energias_selecionadas: Array = [], _game_state = null) -> bool:
	if not validate_retreat_possivel(animal, player):
		return false

	return validate_retreat_cost(animal, energias_selecionadas)


## BUG CORRIGIDO: cost_retreat em CardResource é um int (contagem
## simples de energias, QUALQUER cor) — não uma String de emoji como
## attack_cost. A suposição anterior (parsear como custo colorido)
## estava errada; corrigido pra contagem simples.
##
## A seleção precisa: (a) ter exatamente `animal.card.cost_retreat`
## energias (não permite "sobrar" selecionada à toa), e (b) todas as
## energias selecionadas precisarem estar de fato anexadas a este
## animal. Não há exigência de cor.
static func validate_retreat_cost(animal: AnimalInstance, energias_selecionadas: Array = []) -> bool:
	if animal == null or animal.card == null:
		return false

	var custo: int = animal.card.cost_retreat

	# Carta sem custo de recuo (0) = recuo gratuito.
	if custo <= 0:
		return true

	if energias_selecionadas.size() != custo:
		return false

	for energia in energias_selecionadas:
		if not animal.attached_energies.has(energia):
			return false

	return true


## Valida se o animal escolhido no Banco pra substituir o Ativo é
## válido (pertence ao Banco do mesmo jogador e ainda está vivo).
static func validate_retreat_target(player: PlayerState, replacement: AnimalInstance) -> bool:
	if player == null or replacement == null:
		return false

	if not player.banco.has(replacement):
		return false

	return replacement.current_hp > 0


# ==================================================
# ATAQUE
# ==================================================

## Mapa de emoji -> cor, usado para interpretar attack_cost/retreat_cost
## de CardResource.
##
## ATENÇÃO: assumi essa correspondência com base em apenas 1 exemplo
## confirmado (⚪ = incolor). Confirmem se os emojis das outras 5
## cores (verde, vermelha, azul, amarela, marrom) batem exatamente
## com os usados no CSV/cartas — se não baterem, o parser abaixo
## simplesmente ignora o símbolo desconhecido, o que faria o custo
## sair menor do que deveria (bug silencioso).
const MAPA_EMOJI_COR := {
	"🟢": "verde",
	"🔴": "vermelho",
	"🔵": "azul",
	"🟡": "amarelo",
	"🟤": "marrom",
	"⚪": "incolor",
}


## Converte uma String de emojis (attack_cost OU retreat_cost) num
## Dictionary no formato esperado por
## AnimalInstance.tem_energias_suficientes(), ex: {"vermelha": 2, "incolor": 1}.
## Generalizado a partir do parser de custo de ataque pra ser reusado
## também pelo custo de recuo — mesma sintaxe de dado, mesmo parser,
## uma fonte só de verdade.
static func _construir_custo_por_emojis(simbolos: String) -> Dictionary:
	var custo: Dictionary = {}

	for simbolo in simbolos:
		var cor: String = MAPA_EMOJI_COR.get(simbolo, "")

		if cor == "":
			continue

		custo[cor] = custo.get(cor, 0) + 1

	return custo


## Converte o attack_cost (String de emojis) da carta em um
## Dictionary no formato esperado por
## AnimalInstance.tem_energias_suficientes(), ex: {"vermelha": 2, "incolor": 1}.
static func _construir_custo_do_ataque(
	ataque: CardResource
) -> Dictionary:

	return _construir_custo_por_emojis(ataque.attack_cost)


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
