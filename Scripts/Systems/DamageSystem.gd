class_name DamageSystem

# ==================================================
# DAMAGE SYSTEM
# Responsável exclusivamente por APLICAR um valor de dano já
# calculado ao HP de um animal.
#
# NÃO calcula dano (isso é CombatSystem.calcular_dano).
# NÃO verifica nocaute (isso é KnockoutSystem).
#
# Este arquivo não existia nos uploads, mas era referenciado nos
# comentários de CombatSystem.gd como parte do fluxo esperado:
# BattleManager -> CombatSystem.calcular_dano()
#                -> DamageSystem.aplicar_dano()
#                -> KnockoutSystem.verificar_nocaute()
# ==================================================


## Aplica dano ao HP atual do alvo. Nunca deixa o valor negativo.
## Quem chama (BattleManager) é responsável por, em seguida, checar
## nocaute via KnockoutSystem — este System não decide isso sozinho.
static func aplicar_dano(alvo: AnimalInstance, quantidade: int) -> void:
	if alvo == null or quantidade <= 0:
		return

	alvo.current_hp = max(0, alvo.current_hp - quantidade)


## Cura HP do alvo, sem nunca ultrapassar o HP máximo da carta atual
## (alvo.card.hp). Não existe no rulebook fornecido nenhuma fonte de
## cura ainda (fica pronto pro dia que Vestígio/Habilidade precisarem).
static func curar(alvo: AnimalInstance, quantidade: int) -> void:
	if alvo == null or quantidade <= 0:
		return

	alvo.current_hp = min(alvo.card.hp, alvo.current_hp + quantidade)
