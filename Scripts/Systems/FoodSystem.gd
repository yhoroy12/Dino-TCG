class_name FoodSystem

# ==================================================
# FOOD SYSTEM — Modelo B (pool manual, confirmado com o time)
# Responsável por:
# - Acumular o pool de comida do jogador (+3/turno, cumulativo)
# - Distribuir comida do pool pra um animal específico (ação do jogador)
# - Consumir comida (redução passiva do Ativo, custo de habilidades, etc)
# - Verificar fome
#
# REGRA CONFIRMADA COM O TIME (2026-07):
# - O jogador ganha 3 pontos de comida no POOL (PlayerState.comida_disponivel)
#   no início do próprio turno. O pool é CUMULATIVO — se o jogador não gastar,
#   soma com o do próximo turno (3, depois 6, depois 9...).
# - A distribuição do pool pros animais é 100% manual, feita pelo jogador
#   durante a Fase Principal, quantas vezes quiser, pra qualquer animal em
#   campo (Ativo ou Banco).
# - A redução passiva de 1 ponto por turno (fome) só se aplica ao Animal
#   ATIVO — o Banco Reserva nunca perde comida passivamente. Banco só perde
#   comida por efeito de carta/habilidade explícito (EffectSystem).
# ==================================================


const PONTOS_POOL_POR_TURNO: int = 3
const REDUCAO_PASSIVA_ATIVO: int = 1


## Chamado pelo TurnManager no início do turno de um jogador — soma
## PONTOS_POOL_POR_TURNO ao pool. Cumulativo por design: NÃO zera o
## valor anterior antes de somar.
static func ganhar_pool_comida(player: PlayerState) -> void:
	if player == null:
		return

	player.comida_disponivel += PONTOS_POOL_POR_TURNO


## Distribui `quantidade` pontos do pool do jogador pra um animal
## específico. Quem valida se a quantidade é permitida (pool
## suficiente, animal pertence ao jogador) é o RuleValidator — esta
## função assume que a validação já passou, igual ao resto dos
## Systems do projeto.
static func distribuir_comida(
	player: PlayerState,
	animal: AnimalInstance,
	quantidade: int
) -> void:

	if player == null or animal == null or quantidade <= 0:
		return

	player.comida_disponivel -= quantidade
	animal.current_food += quantidade


## Consumo genérico de comida (fome passiva do Ativo, custo de
## habilidade, efeito de carta). Nunca deixa o valor negativo.
static func consumir_comida(
	animal: AnimalInstance,
	quantidade: int
) -> void:

	if animal == null:
		return

	animal.current_food = max(0, animal.current_food - quantidade)


## Verifica se um animal tem comida suficiente pra pagar um custo
## (ex: custo de habilidade que "cobra" comida).
static func possui_comida_suficiente(
	animal: AnimalInstance,
	quantidade: int
) -> bool:

	if animal == null:
		return false

	return animal.current_food >= quantidade


## Verifica fome (comida chegou a zero).
static func verificar_fome(
	animal: AnimalInstance
) -> bool:

	if animal == null:
		return false

	return animal.current_food <= 0


## Aplica a redução passiva de fome — SÓ no Animal Ativo do jogador,
## nunca no Banco. Chamar uma vez por processamento de fim de turno,
## para o jogador cujo turno está terminando.
##
## Não decide nocaute aqui — só reduz o valor. Quem verifica se isso
## resultou em nocaute é o KnockoutSystem (via RuleValidator.validate_starvation
## ou esta_nocauteado), chamado logo em seguida pelo TurnManager/BattleManager.
static func aplicar_reducao_passiva(player: PlayerState) -> void:
	if player == null or player.ativo == null:
		return

	consumir_comida(player.ativo, REDUCAO_PASSIVA_ATIVO)
## Mínimo necessário pra crescer: metade (arred. pra cima) do
## food_points do estágio ATUAL do animal.
static func _minimo_para_crescimento(instancia: AnimalInstance) -> int:
	return ceili(instancia.card.food_points / 2.0)


## Retorna true se a comida atualmente investida no animal (do
## estágio atual, antes de evoluir) atinge o mínimo pra crescer.
static func pode_pagar_crescimento(instancia: AnimalInstance) -> bool:
	return instancia.current_food >= _minimo_para_crescimento(instancia)


## Consome o mínimo necessário do current_food do animal.
## Sobra (crédito acima do mínimo) permanece acumulada — NÃO zera
## current_food inteiro. [Opção A — confirmar se é isso mesmo.]
static func consumir_para_crescimento(instancia: AnimalInstance) -> void:
	instancia.current_food -= _minimo_para_crescimento(instancia)
