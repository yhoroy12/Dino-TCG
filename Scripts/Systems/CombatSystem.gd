# ==================================================
# Nome: CombatSystem
# Categoria: Systems
#
# Responsável exclusivamente por CALCULAR dano.
#
# O QUE ESTE SISTEMA NÃO FAZ (de propósito):
# - Não aplica dano ao alvo.
# - Não remove animais do campo.
# - Não verifica nocaute.
# - Não dá recompensas.
# - Não declara vencedor.
# - Não altera GameState, PlayerState ou AnimalInstance.
# - Não acessa nós de cena, UI, sinais ou SceneTree.
#
# Fluxo esperado:
# BattleManager -> CombatSystem.calcular_dano()
#                -> DamageSystem.aplicar_dano() (aplica o int retornado)
#                -> KnockoutSystem.verificar_nocaute()
#
# Regra de Data Driven:
# Nenhuma função aqui deve comparar "card.name". Toda regra deve
# se basear em atributos genéricos (color, weakness, resistance)
# ou em efeitos genéricos guardados em "temporary_effects", que é
# o canal usado por Territórios, Vestígios e Cataclismos para
# empurrar bônus/reduções sem o CombatSystem precisar conhecê-los.
# ==================================================

class_name CombatSystem


# --------------------------------------------------
# CONSTANTES DE BALANCEAMENTO
# Centralizadas aqui para facilitar ajustes futuros
# sem precisar mexer na lógica das funções.
# --------------------------------------------------

const MULTIPLICADOR_FRAQUEZA: float = 2.0
const REDUCAO_RESISTENCIA: int = 20

# As tags de efeito (TAG_BONUS_DANO, TAG_REDUCAO_DANO, etc.) e o
# formato do Dictionary de temporary_effects são de propriedade
# do EffectSystem. O CombatSystem nunca lê AnimalInstance.temporary_effects
# diretamente — sempre consulta via EffectSystem.obter_soma() /
# EffectSystem.obter_multiplicador(), para existir uma única fonte
# da verdade sobre o formato desse dado.


# ==================================================
# API PÚBLICA
# ==================================================

## Calcula o dano final de um ataque.
## Não modifica atacante, defensor nem o ataque recebido.
## Retorna sempre um inteiro >= 0.
static func calcular_dano(
	atacante: AnimalInstance,
	defensor: AnimalInstance,
	ataque: CardResource
) -> int:

	if atacante == null or defensor == null or ataque == null:
		return 0

	var dano: int = _obter_dano_base(ataque)

	dano = _aplicar_fraqueza(dano, atacante, defensor)
	dano = _aplicar_resistencia(dano, atacante, defensor)
	dano = _aplicar_bonus(dano, atacante, defensor, ataque)
	dano = _aplicar_reducao(dano, atacante, defensor)
	dano = _aplicar_efeitos_temporarios(dano, atacante, defensor)

	return _validar_dano_final(dano)


# ==================================================
# ETAPAS DO CÁLCULO (privadas)
# Cada função representa UMA regra do rulebook.
# ==================================================

## Extrai o dano base definido na carta/ataque.
## Ponto único de leitura do dado bruto, isolando o resto
## do sistema de onde o dano_base realmente é armazenado.
static func _obter_dano_base(
	ataque: CardResource
) -> int:

	return max(0, ataque.damage_base)


## Aplica a regra de Fraqueza.
## Se a cor do atacante corresponde à fraqueza do defensor,
## o dano é multiplicado por MULTIPLICADOR_FRAQUEZA.
static func _aplicar_fraqueza(
	dano: int,
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> int:

	var fraqueza: String = defensor.card.weakness
	var cor_atacante: String = atacante.card.color

	if fraqueza == "" or cor_atacante == "":
		return dano

	if fraqueza != cor_atacante:
		return dano

	return int(round(dano * MULTIPLICADOR_FRAQUEZA))


## Aplica a regra de Resistência.
## Se a cor do atacante corresponde à resistência do defensor,
## reduz o dano em REDUCAO_RESISTENCIA (nunca abaixo de 0).
static func _aplicar_resistencia(
	dano: int,
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> int:

	var resistencia: String = defensor.card.resistance
	var cor_atacante: String = atacante.card.color

	if resistencia == "" or cor_atacante == "":
		return dano

	if resistencia != cor_atacante:
		return dano

	return max(0, dano - REDUCAO_RESISTENCIA)


## Aplica bônus de dano vindos de efeitos genéricos anexados
## ao atacante (ex: Território favorável, Vestígio, buff de
## habilidade passiva). O CombatSystem não sabe a origem do
## efeito, apenas soma o valor marcado com TAG_BONUS_DANO.
static func _aplicar_bonus(
	dano: int,
	atacante: AnimalInstance,
	defensor: AnimalInstance,
	ataque: CardResource
) -> int:

	var bonus: int = int(EffectSystem.obter_soma(
		atacante,
		EffectSystem.TAG_BONUS_DANO
	))

	return dano + bonus


## Aplica reduções de dano genéricas vindas de efeitos anexados
## ao defensor (ex: Território defensivo, Cataclismo, escudo
## temporário). Não pode deixar o dano negativo.
static func _aplicar_reducao(
	dano: int,
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> int:

	var reducao: int = int(EffectSystem.obter_soma(
		defensor,
		EffectSystem.TAG_REDUCAO_DANO
	))

	return max(0, dano - reducao)


## Aplica multiplicadores vindos de efeitos temporários (ex:
## "próximo ataque causa 150% de dano"). Fica separado das
## regras de bônus/redução fixos porque multiplicadores devem
## ser resolvidos depois dos valores fixos, para não distorcer
## o balanceamento de fraqueza/resistência.
static func _aplicar_efeitos_temporarios(
	dano: int,
	atacante: AnimalInstance,
	defensor: AnimalInstance
) -> int:

	var multiplicador: float = EffectSystem.obter_multiplicador(
		atacante,
		EffectSystem.TAG_MULTIPLICADOR_DANO
	)

	if multiplicador == 1.0:
		return dano

	return int(round(dano * multiplicador))


## Garante que o valor final de dano é um inteiro válido e
## nunca negativo. Última etapa antes do retorno público.
static func _validar_dano_final(
	dano: int
) -> int:

	return max(0, dano)
