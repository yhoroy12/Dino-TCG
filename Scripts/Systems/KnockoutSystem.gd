# ==================================================
# FINALIZADO
# Nome: KnockoutSystem
# Categoria: Systems
# Responsável pelos nocautes.
#
# Deve controlar:
# - Verificação de KO
# - Remoção do campo
# - Envio para descarte
# - Limpeza de condições
# ==================================================

# ==================================================
# Nome: KnockoutSystem
# Categoria: Systems
# Responsável por verificar e processar nocautes.
# ==================================================

class_name KnockoutSystem


# ==================================================
# VERIFICAÇÃO
# ==================================================

## Verifica se um animal está nocauteado.
## Verifica se um animal está nocauteado.
static func esta_nocauteado(animal: AnimalInstance) -> bool:
	if animal == null:
		return false

	# Nocaute real acontece quando o HP chega a zero.
	# A fome (current_food == 0) deve reduzir HP no FoodSystem, não matar direto no banco.
	return animal.current_hp <= 0


## Retorna todos os animais nocauteados do jogador.
static func verificar_nocaute(player: PlayerState) -> Array[AnimalInstance]:
	var nocauteados: Array[AnimalInstance] = []
	if player == null:
		return nocauteados

	var ativo := GameState.obter_ativo(player.id)
	var banco := GameState.obter_banco(player.id)

	if ativo != null and esta_nocauteado(ativo):
		nocauteados.append(ativo)

	for animal in banco:
		if esta_nocauteado(animal):
			nocauteados.append(animal)

	return nocauteados


# ==================================================
# PROCESSAMENTO
# ==================================================

## Processa o nocaute de um animal.
static func processar_nocaute(player: PlayerState, animal: AnimalInstance) -> void:
	if animal == null or player == null:
		return
	
	# Incrementa o contador de nocautes do ADVERSÁRIO de quem perdeu o animal
	if player.id == 0:
		GameState.nocautes_j1 += 1
	else:
		GameState.nocautes_j0 += 1
	
	# 1. Remove condições especiais
	ConditionSystem.limpar_todas_as_condicoes(animal)

	var descarte := GameState.obter_descarte(player.id)

	# 2. Move carta principal para descarte
	descarte.append(animal.card)

	# 3. CORREÇÃO: Move a pilha de evolução inteira usando a zona pública do GameState
	for carta_empilhada in animal.pilha_evolucao:
		descarte.append(carta_empilhada)
	animal.pilha_evolucao.clear()

	# 4. CORREÇÃO: Move as energias anexadas (energia, não animal.card)
	for energia in animal.attached_energies:
		descarte.append(energia)
	animal.attached_energies.clear()

	# 5. CORREÇÃO: Remove do campo e atualiza a trava de promoção se for o Ativo
	if GameState.obter_ativo(player.id) == animal:
		if player.id == 0:
			GameState.ativo_j0 = null
		else:
			GameState.ativo_j1 = null
		
		# Marca que este jogador precisa promover um novo ativo do banco
		GameState.jogador_sem_ativo = player.id
	else:
		GameState.obter_banco(player.id).erase(animal)
	
	var resultado = WinConditionSystem.checar_vitoria_por_nocautes()
	WinConditionSystem.processar_resultado(resultado, "Atingiu o limite de 4 nocautes!")

## Processa todos os nocautes encontrados.
static func processar_todos_nocautes(player: PlayerState) -> Array[AnimalInstance]:
	var nocauteados = verificar_nocaute(player)

	for animal in nocauteados:
		processar_nocaute(player, animal)

	return nocauteados
