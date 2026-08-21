# ==================================================
# Nome: BattleManager
# Categoria: Core / Managers
# Responsável por ser o ÚNICO ponto de entrada para toda ação de
# jogador durante a Fase Principal e a Fase de Ataque.
#
# Fluxo padrão de qualquer ação, sem exceção:
#   1. VALIDA  -> RuleValidator.validate_*
#   2. APLICA  -> System correspondente (FoodSystem, EnergySystem,
#                 EvolutionSystem, CombatSystem + DamageSystem, etc.)
#   3. MARCA FLAG DE TURNO, se a ação for limitada (energia, recuo)
#
# A UI (mesa_jogador.gd) nunca decide se uma ação é válida — ela só
# emite `acao_jogador_solicitada(tipo_acao, dados)`. Quem escuta esse
# sinal (a cena de batalha) deve chamar
# BattleManager.processar_acao(tipo_acao, dados) e usar o resultado
# pra re-renderizar (organizar_cartas_nas_zonas) ou mostrar erro.
#
# Autoload (singleton), mesmo padrão de GameState/TurnManager/SetupManager.
# NÃO guarda estado próprio da partida — lê e escreve em GameState/
# PlayerState, que continuam sendo a única fonte da verdade.
# ==================================================
extends Node


# ==================================================
# SINAIS
# ==================================================

## Emitido ao final de QUALQUER processar_acao — sucesso ou falha.
## A UI escuta isso pra re-renderizar zonas e/ou mostrar feedback de
## erro (ex: texto flutuante "Banco cheio").
signal acao_resolvida(tipo_acao: String, sucesso: bool, motivo: String, dados: Dictionary)
signal ataque_executado(atacante: AnimalInstance, defensor: AnimalInstance, ataque: CardResource, dano: int)
signal ataque_falhou_paralisia(atacante: AnimalInstance)
# ==================================================
# SINAIS DE INTERAÇÃO / SELEÇÃO (UI)
# ==================================================
# Gera IDs únicos de solicitação — garante que confirmar_selecao_ui()
# resolva exatamente a pergunta que a originou, mesmo que no futuro
# haja solicitações encadeadas (ex: ataque busca energia E pede alvo).
var _proximo_id_solicitacao: int = 1

## Emitido sempre que um efeito precisa que o jogador escolha entre N
## CardBaseResource de alguma zona (deck, mão, descarte, topo, energias
## anexadas a um animal).
signal solicitacao_selecao_cartas(id_solicitacao: int, jogador_id: int, cartas_elegiveis: Array, quantidade: int, contexto: String)

## Emitido sempre que um efeito precisa que o jogador escolha um ou mais
## AnimalInstance em campo (banco próprio ou do oponente).
signal solicitacao_selecao_animal(id_solicitacao: int, jogador_id: int, animais_elegiveis: Array, quantidade: int, contexto: String)

## Resposta única da UI para qualquer solicitação acima.
signal selecao_interativa_concluida(id_solicitacao: int, dados_resposta: Dictionary)
# Solicitado pela ação "MODIFICAR_CUSTO"
signal modificador_custo_aplicado(jogador_id: int, recurso: String, quantidade: int, duracao: int)
# ==================================================
# API PÚBLICA — FUNIL ÚNICO
# ==================================================

## Ponto de entrada único pra qualquer ação de jogador na Fase
## Principal ou de Ataque. Retorna um Dictionary {"sucesso": bool,
## "motivo": String} — "motivo" é sempre preenchido em caso de falha,
## pra UI poder mostrar um feedback específico.
func processar_acao(tipo_acao: String, dados: Dictionary) -> Dictionary:
	print("⚔️ [BattleManager] Solicitação de ação recebida: '%s' | Jogador Ativo ID: %d" % [tipo_acao, GameState.jogador_ativo])
	var resultado: Dictionary

	match tipo_acao:
		"jogar_para_banco":
			resultado = _jogar_para_banco(dados)

		"crescer":
			resultado = _crescer(dados)

		"anexar_energia":
			resultado = _anexar_energia(dados)

		"distribuir_comida":
			resultado = _distribuir_comida(dados)

		"recuar":
			resultado = _recuar(dados)

		"promover_ativo":
			resultado = _promover_ativo(dados)

		"atacar":
			resultado = await _atacar(dados)

		"jogar_cataclismo":
			resultado = _jogar_cataclismo(dados)
		
		"jogar_territorio", "jogar_vestigio":
			# Prioridades 6 e 7 do projeto — ainda não chegaram na
			# ordem. RuleValidator já tem os esqueletos prontos.
			resultado = {"sucesso": false, "motivo": "ainda_nao_implementado"}

		"usar_habilidade":
			# Depende de um interpretador de AbilityResource que ainda
			# não existe no projeto — fora do escopo do Turno 1.
			resultado = {"sucesso": false, "motivo": "ainda_nao_implementado"}
			
		"energizar_por_efeito":
			resultado = _energizar_por_efeito(dados)

		"puxar_banco_oponente":
			resultado = _puxar_banco_oponente(dados)

		_:
			resultado = {"sucesso": false, "motivo": "acao_desconhecida"}

	if resultado.get("sucesso", false):
		print("✅ [BattleManager] Ação '%s' EXECUTADA COM SUCESSO." % tipo_acao)
	else:
		print("❌ [BattleManager] Ação '%s' FALHOU. Motivo: '%s'" % [tipo_acao, resultado.get("motivo", "")])

	acao_resolvida.emit(tipo_acao, resultado["sucesso"], resultado["motivo"], dados)
	return resultado

# ==================================================
# INTERAÇÕES E SELEÇÕES DE EFEITOS (CALLBACKS DE UI)
# ==================================================
## Resposta enviada pela MesaUI quando o jogador confirma (ou cancela)
## uma seleção. id_solicitacao é o mesmo recebido no sinal de pedido.
func confirmar_selecao_ui(id_solicitacao: int, dados_resposta: Dictionary) -> void:
	print("📥 [BattleManager] Resposta recebida p/ solicitação #%d: %s" % [id_solicitacao, dados_resposta])
	selecao_interativa_concluida.emit(id_solicitacao, dados_resposta)

## Bloqueia a execução do chamador até a resposta com o MESMO
## id_solicitacao chegar. Ignora qualquer resposta de outra solicitação
## que ainda esteja pendente.
func _aguardar_resposta_selecao(id_solicitacao: int):
	while true:
		var resposta: Array = await selecao_interativa_concluida
		var id_recebido: int = resposta[0]
		var dados: Dictionary = resposta[1]
		if id_recebido == id_solicitacao:
			return dados

## Emite o pedido de seleção de CARTAS e aguarda a resposta. Não aplica
## nada no GameState — cada função pública decide o que fazer com o
## resultado (mover pra mão, reordenar, descartar, etc).
## Pede ao agente do jogador que escolha N cartas entre as elegíveis.
## Não aplica nada no GameState — quem chama decide o que fazer com o
## resultado (mover pra mão, descartar, anexar, etc).
func _solicitar_cartas(jogador_id: int, elegiveis: Array, quantidade: int, contexto: String) -> Array:
	if elegiveis.is_empty():
		return []

	var agente: PlayerAgent = _obter_agente(jogador_id)
	if agente == null:
		return []

	print("🔍 [BattleManager] Solicitando seleção de %d carta(s) | contexto: '%s' | Jogador %d" % [quantidade, contexto, jogador_id])
	return await agente.decidir_selecao_cartas(elegiveis, quantidade, contexto)
## Mesma ideia, mas para escolha de AnimalInstance em campo.
func _solicitar_animais(jogador_id: int, elegiveis: Array, quantidade: int, contexto: String) -> Array:
	if elegiveis.is_empty():
		return []

	var id_solicitacao: int = _proximo_id_solicitacao
	_proximo_id_solicitacao += 1

	print("🎯 [BattleManager] Solicitando seleção de %d animal(is) | contexto: '%s' | id #%d" % [quantidade, contexto, id_solicitacao])
	solicitacao_selecao_animal.emit(id_solicitacao, jogador_id, elegiveis, quantidade, contexto)

	var resposta: Dictionary = await _aguardar_resposta_selecao(id_solicitacao)
	return resposta.get("animais_selecionados", [])

## Retorna a Array real (referência) da zona pedida.
func _obter_zona(player: PlayerState, nome_zona: String) -> Array:
	match nome_zona.to_upper():
		"DECK":
			return player.deck
		"MAO":
			return player.mao
		"DESCARTE":
			return GameState.obter_descarte(player.id)
		_:
			push_warning("⚠️ [BattleManager] Zona desconhecida: '%s'" % nome_zona)
			return []
## "ENERGIZAR": busca energia de uma zona e anexa no alvo já resolvido
## pelo AttackEffectResolver. Reaproveita _energizar_por_efeito, que já
## sabe remover a carta do deck ou da mão de onde ela vier.
func solicitar_energizar_animal(jogador_id: int, animal: AnimalInstance, zona_origem: String, filtro_cor: String, quantidade: int) -> Dictionary:
	if animal == null:
		return {"sucesso": false, "motivo": "alvo_invalido"}

	var player: PlayerState = GameState.get_jogador_por_id(jogador_id)
	var zona: Array = _obter_zona(player, zona_origem)

	var elegiveis: Array = []
	for carta in zona:
		if _carta_corresponde_filtros(carta, "ENERGIA", filtro_cor, "QUALQUER"):
			elegiveis.append(carta)

	if elegiveis.is_empty():
		return {"sucesso": false, "motivo": "sem_energias_elegiveis"}

	var escolhidas: Array = await _solicitar_cartas(jogador_id, elegiveis, quantidade, "energizar_por_efeito")
	if escolhidas.is_empty():
		return {"sucesso": false, "motivo": "selecao_cancelada"}

	for carta_energia in escolhidas:
		var resultado := _energizar_por_efeito({
			"jogador_id": jogador_id,
			"animal_alvo": animal,
			"carta_energia": carta_energia
		})
		if not resultado.get("sucesso", false):
			return resultado

	return {"sucesso": true, "motivo": "", "energias_anexadas": escolhidas}

## "BUSCAR": move N cartas de uma zona (deck/descarte) para a mão.
func solicitar_busca_cartas_zona(jogador_id: int, zona_origem: String, filtro_cor: String, filtro_estagio: String, quantidade: int) -> Dictionary:
	var player: PlayerState = GameState.get_jogador_atual()
	var zona: Array = _obter_zona(player, zona_origem)

	var elegiveis: Array = []
	for carta in zona:
		if _carta_corresponde_filtros(carta, "QUALQUER", filtro_cor, filtro_estagio):
			elegiveis.append(carta)

	if elegiveis.is_empty():
		return {"sucesso": false, "motivo": "sem_cartas_elegiveis"}

	var escolhidas: Array = await _solicitar_cartas(jogador_id, elegiveis, quantidade, "busca_zona")
	if escolhidas.is_empty():
		return {"sucesso": false, "motivo": "selecao_cancelada"}

	for carta in escolhidas:
		zona.erase(carta)
		player.mao.append(carta)

	return {"sucesso": true, "motivo": "", "cartas_selecionadas": escolhidas}

## "OLHAR": exibe as N cartas do topo sem alterar nada, só aguarda a
## confirmação de "visualizado".
func solicitar_olhar_topo_deck(jogador_id: int, quantidade: int) -> Dictionary:
	var player: PlayerState = GameState.get_jogador_por_id(jogador_id)
	var topo: Array = player.deck.slice(0, mini(quantidade, player.deck.size()))

	if topo.is_empty():
		return {"sucesso": false, "motivo": "deck_vazio"}

	await _solicitar_cartas(jogador_id, topo, topo.size(), "olhar_topo")
	return {"sucesso": true, "motivo": "", "cartas_visualizadas": topo}

## "DEVOLVER": move N cartas escolhidas de uma zona para outra.
func solicitar_devolver_carta(jogador_id: int, zona_origem: String, zona_destino: String, quantidade: int) -> Dictionary:
	var player: PlayerState = GameState.get_jogador_por_id(jogador_id)
	var origem: Array = _obter_zona(player, zona_origem)
	var destino: Array = _obter_zona(player, zona_destino)

	if origem.is_empty():
		return {"sucesso": false, "motivo": "zona_origem_vazia"}

	var escolhidas: Array = await _solicitar_cartas(jogador_id, origem, quantidade, "devolver_carta")
	if escolhidas.is_empty():
		return {"sucesso": false, "motivo": "selecao_cancelada"}

	for carta in escolhidas:
		origem.erase(carta)
		destino.append(carta)

	return {"sucesso": true, "motivo": "", "cartas_devolvidas": escolhidas}

## "REORGANIZAR": jogador reordena as N cartas do topo do deck. A UI
## devolve a nova ordem pronta em "nova_ordem".
func solicitar_reorganizar_topo(jogador_id: int, quantidade: int) -> Dictionary:
	var player: PlayerState = GameState.get_jogador_por_id(jogador_id)
	var topo: Array = player.deck.slice(0, mini(quantidade, player.deck.size()))

	if topo.is_empty():
		return {"sucesso": false, "motivo": "deck_vazio"}

	var id_solicitacao: int = _proximo_id_solicitacao
	_proximo_id_solicitacao += 1

	solicitacao_selecao_cartas.emit(id_solicitacao, jogador_id, topo, topo.size(), "reorganizar_topo")
	var resposta: Dictionary = await _aguardar_resposta_selecao(id_solicitacao)
	var nova_ordem: Array = resposta.get("nova_ordem", [])

	if nova_ordem.size() != topo.size():
		return {"sucesso": false, "motivo": "ordem_invalida"}

	for i in range(nova_ordem.size()):
		player.deck[i] = nova_ordem[i]

	return {"sucesso": true, "motivo": "", "nova_ordem": nova_ordem}

## Descarte de energias anexadas a um animal específico (efeito de
## ataque "DESCARTAR", ou custo de recuo). Energias são CardBaseResource,
## por isso usam o canal de CARTAS, não o de animais.
func solicitar_descarte_energia_animal(jogador_id: int, animal: AnimalInstance, quantidade: int) -> Dictionary:
	if animal == null or animal.attached_energies.is_empty():
		return {"sucesso": false, "motivo": "sem_energias_anexadas"}

	var escolhidas: Array = await _solicitar_cartas(jogador_id, animal.attached_energies, quantidade, "descarte_energia_animal")
	if escolhidas.size() != quantidade:
		return {"sucesso": false, "motivo": "selecao_incompleta"}

	var descartadas: Array[EffectResource] = EnergySystem.pagar_custo(animal, escolhidas)
	GameState.obter_descarte(jogador_id).append_array(descartadas)

	return {"sucesso": true, "motivo": "", "energias_descartadas": descartadas}

## Descarte de N cartas da própria mão.
func solicitar_descarte_mao(jogador_id: int, quantidade: int) -> Dictionary:
	var player: PlayerState = GameState.get_jogador_por_id(jogador_id)
	if player.mao.is_empty():
		return {"sucesso": false, "motivo": "mao_vazia"}

	var escolhidas: Array = await _solicitar_cartas(jogador_id, player.mao, quantidade, "descarte_mao")
	if escolhidas.size() != quantidade:
		return {"sucesso": false, "motivo": "selecao_incompleta"}

	for carta in escolhidas:
		player.mao.erase(carta)
		GameState.obter_descarte(jogador_id).append(carta)

	return {"sucesso": true, "motivo": "", "cartas_descartadas": escolhidas}

## Pede alvo no banco do oponente ("PUXAR" de ataque, ou cataclismos de
## emboscada) e já efetiva a troca via _puxar_banco_oponente.
func solicitar_selecao_banco_oponente(jogador_atacante_id: int, id_oponente: int, contexto: String = "puxar_banco", quantidade: int = 1) -> Dictionary:
	var validacao := RuleValidator.validar_trocar_ativo_oponente(id_oponente)
	if not validacao["sucesso"]:
		return validacao

	var banco_oponente: Array = GameState.obter_banco(id_oponente)
	var alvo: AnimalInstance = await solicitar_selecao_alvo_efeito(id_oponente, banco_oponente, contexto.to_lower())
	if alvo == null:
		return {"sucesso": false, "motivo": "banco_oponente_vazio_ou_cancelado"}

	return _puxar_banco_oponente({"id_oponente": id_oponente, "alvo_banco": alvo})

## Efeito de ataque "EXPULSAR"/"RECUAR" de OUTRA carta: força jogador_id
## a trocar o ativo atual por um do banco escolhido por ele. Diferente
## de _recuar() (sem custo de energia, sem limite de 1x/turno) e de
## _promover_ativo() (o alvo AQUI ainda tem ativo — não usa jogador_sem_ativo).
func solicitar_troca_forcada(jogador_id: int) -> Dictionary:
	var banco: Array = GameState.obter_banco(jogador_id)
	if banco.is_empty():
		print("ℹ️ [BattleManager] Troca forçada ignorada: Jogador %d não tem banco." % jogador_id)
		return {"sucesso": false, "motivo": "banco_vazio"}

	var substituto: AnimalInstance
	if banco.size() == 1:
		substituto = banco[0]
	else:
		var escolhidos: Array = await _solicitar_animais(jogador_id, banco, 1, "troca_forcada")
		if escolhidos.is_empty():
			return {"sucesso": false, "motivo": "selecao_cancelada"}
		substituto = escolhidos[0]

	return _trocar_ativo_forcado(jogador_id, substituto)

func _trocar_ativo_forcado(jogador_id: int, substituto: AnimalInstance) -> Dictionary:
	var atual: AnimalInstance = GameState.obter_ativo(jogador_id)
	if atual == null or substituto == null:
		return {"sucesso": false, "motivo": "estado_invalido"}

	GameState.obter_banco(jogador_id).erase(substituto)
	GameState.obter_banco(jogador_id).append(atual)

	if jogador_id == 0:
		GameState.ativo_j0 = substituto
	else:
		GameState.ativo_j1 = substituto

	print("🌀 [BattleManager] Troca forçada: '%s' entrou no lugar de '%s' (Jogador %d)." % [substituto.card.name, atual.card.name, jogador_id])
	return {"sucesso": true, "motivo": ""}

## Verifica se uma carta bate com os filtros de tipo/cor/estágio.
## "QUALQUER" funciona como coringa em qualquer um dos filtros.
## ⚠️ Ajuste "energia" abaixo se o seu CardBaseResource usar outro valor
## de super_type para cartas de energia — preciso confirmar isso.
func _carta_corresponde_filtros(carta: CardBaseResource, filtro_tipo: String, filtro_cor: String, filtro_estagio: String) -> bool:
	if filtro_tipo == "ENERGIA" and carta.super_type != "energia":
		return false

	if filtro_cor != "QUALQUER" and carta is EffectResource:
		if (carta as EffectResource).mec_filter_color.to_upper() != filtro_cor.to_upper():
			return false

	if filtro_estagio != "QUALQUER" and carta is CardResource:
		if (carta as CardResource).stage.to_upper() != filtro_estagio.to_upper():
			return false

	return true

## Pede ao jogador para escolher UM animal entre os candidatos — usada por
## efeitos cujo alvo é ambíguo (mec_target_zone = BANCO ou ATIVO_BANCO).
## Se houver só 1 candidato, resolve direto sem abrir popup nenhum.
func solicitar_selecao_alvo_efeito(jogador_id: int, candidatos: Array, contexto: String = "alvo_efeito") -> AnimalInstance:
	if candidatos.is_empty():
		return null
	if candidatos.size() == 1:
		return candidatos[0]

	var escolhidos: Array = await _solicitar_animais(jogador_id, candidatos, 1, contexto)
	return escolhidos[0] if not escolhidos.is_empty() else null

# ==================================================
# BANCO RESERVA — colocar animal bebê da mão
# ==================================================

## dados: {"indice_mao": int, "carta": CardBaseResource}
func _jogar_para_banco(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var indice_mao: int = dados.get("indice_mao", -1)
	var carta: CardBaseResource = dados.get("carta")

	var nome_carta: String = carta.name if carta != null else "Nula"
	print("🃏 [BattleManager] Tentando jogar para o banco: '%s' (Índice da mão: %d) | Jogador ID: %d" % [nome_carta, indice_mao, jogador.id])

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		print("⚠️ [BattleManager] Falha ao jogar no banco: índice da mão inválido (%d)." % indice_mao)
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta:
		print("⚠️ [BattleManager] Falha ao jogar no banco: carta no índice %d não corresponde à carta informada." % indice_mao)
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not RuleValidator.validar_banco(carta, jogador):
		print("⚠️ [BattleManager] Falha ao jogar no banco: validação de regra recusou a colocação.")
		return {"sucesso": false, "motivo": "colocacao_invalida"}

	jogador.mao.remove_at(indice_mao)

	var instancia := AnimalInstance.new(carta)
	instancia.entrou_este_turno = true # Marcação interna para a regra do EvolutionSystem
	GameState.obter_banco(jogador.id).append(instancia)

	print("🐾 [BattleManager] Animal '%s' baixado no banco com sucesso. Total no banco: %d" % [nome_carta, GameState.obter_banco(jogador.id).size()])
	return {"sucesso": true, "motivo": ""}

# ==================================================
# CRESCIMENTO — evoluir um animal em campo
# ==================================================

## dados: {"indice_mao": int, "carta_evolucao": CardResource, "instancia": AnimalInstance}
## A carta do estágio anterior não é descartada aqui — EvolutionSystem.crescer()
## já cuida de empilhá-la em instancia.pilha_evolucao (padrão Pokémon/
## Digimon TCG, confirmado com o time). Ela só vai pro descarte de
## fato se o animal for nocauteado (KnockoutSystem.processar_nocaute).
func _crescer(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var indice_mao: int = dados.get("indice_mao", -1)
	var carta_evolucao: CardResource = dados.get("carta_evolucao")
	var instancia: AnimalInstance = dados.get("instancia")

	var nome_evo: String = carta_evolucao.name if carta_evolucao != null else "Nula"
	var nome_alvo: String = instancia.card.name if (instancia != null and instancia.card != null) else "Nulo"
	print("🌱 [BattleManager] Tentando evoluir '%s' para '%s' (Índice da mão: %d) | Jogador ID: %d" % [nome_alvo, nome_evo, indice_mao, jogador.id])

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		print("⚠️ [BattleManager] Falha na evolução: índice da mão inválido (%d)." % indice_mao)
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta_evolucao:
		print("⚠️ [BattleManager] Falha na evolução: carta no índice %d não confere com a evolução esperada." % indice_mao)
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not GameState.obter_animais_em_campo(jogador.id).has(instancia):
		print("⚠️ [BattleManager] Falha na evolução: animal alvo '%s' não está no campo." % nome_alvo)
		return {"sucesso": false, "motivo": "animal_fora_de_campo"}

	if not RuleValidator.validar_evolucao(instancia, carta_evolucao):
		print("⚠️ [BattleManager] Falha na evolução: regra de evolução recusada pelo RuleValidator.")
		return {"sucesso": false, "motivo": "evolucao_invalida"}

	EvolutionSystem.crescer(instancia, carta_evolucao)
	jogador.mao.remove_at(indice_mao)

	print("✨ [BattleManager] Evolução concluída! '%s' agora é '%s'." % [nome_alvo, nome_evo])
	return {"sucesso": true, "motivo": ""}

# ==================================================
# ENERGIA — anexar força primordial (1x por turno)
# ==================================================

## dados: {"indice_mao": int, "carta": EffectResource, "animal": AnimalInstance}
func _anexar_energia(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var indice_mao: int = dados.get("indice_mao", -1)
	var carta: EffectResource = dados.get("carta")
	var animal: AnimalInstance = dados.get("animal")

	var nome_energia: String = carta.name if carta != null else "Nula"
	var nome_alvo: String = animal.card.name if (animal != null and animal.card != null) else "Nulo"
	print("⚡ [BattleManager] Tentando anexar energia '%s' em '%s' | Jogador ID: %d" % [nome_energia, nome_alvo, jogador.id])

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		print("⚠️ [BattleManager] Falha ao anexar energia: índice da mão inválido (%d)." % indice_mao)
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta:
		print("⚠️ [BattleManager] Falha ao anexar energia: carta na mão não confere.")
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not RuleValidator.validar_anexar_energia(jogador, animal, carta):
		print("⚠️ [BattleManager] Falha ao anexar energia: regra de anexação recusada.")
		return {"sucesso": false, "motivo": "anexacao_invalida"}

	EnergySystem.anexar_energia(animal, carta)
	jogador.mao.remove_at(indice_mao)
	GameState.energia_anexada_neste_turno = true

	print("🔋 [BattleManager] Energia '%s' anexada com sucesso em '%s'." % [nome_energia, nome_alvo])
	return {"sucesso": true, "motivo": ""}

# ==================================================
# COMIDA — distribuir pontos do pool pra um animal
# ==================================================

## dados: {"animal": AnimalInstance, "quantidade": int}
func _distribuir_comida(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var animal: AnimalInstance = dados.get("animal")
	var quantidade: int = dados.get("quantidade", 0)

	var nome_alvo: String = animal.card.name if (animal != null and animal.card != null) else "Nulo"
	print("🍖 [BattleManager] Tentando distribuir %d ponto(s) de comida para '%s' | Jogador ID: %d" % [quantidade, nome_alvo, jogador.id])

	if not RuleValidator.validar_distribuicao_comida(jogador, animal, quantidade):
		print("⚠️ [BattleManager] Falha ao distribuir comida: quantidade ou regra inválida.")
		return {"sucesso": false, "motivo": "distribuicao_invalida"}

	FoodSystem.distribuir_comida(jogador, animal, quantidade)

	print("🍖 [BattleManager] %d de comida fornecido(s) para '%s'." % [quantidade, nome_alvo])
	return {"sucesso": true, "motivo": ""}

# ==================================================
# RECUO — trocar o Ativo por um animal do Banco (1x por turno,
# pagando o custo de retreat_cost da carta do Ativo em energias
# descartadas)
# ==================================================

## dados: {"substituto": AnimalInstance, "energias_para_descarte": Array}
##
## "energias_para_descarte" é a escolha do JOGADOR de quais energias
## anexadas ao Ativo serão descartadas pra pagar o custo — a UI deve
## deixar o jogador selecionar isso quando o custo exigir mais de uma
## opção possível (ex: custo pede 1 incolor e o animal tem 2 energias
## de cores diferentes anexadas: qualquer uma serve, mas quem escolhe
## é o jogador).
func _recuar(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var animal_atual: AnimalInstance = GameState.obter_ativo(jogador.id)
	var substituto: AnimalInstance = dados.get("substituto")
	var energias_para_descarte: Array = dados.get("energias_para_descarte", [])

	var nome_atual: String = animal_atual.card.name if (animal_atual != null and animal_atual.card != null) else "Nulo"
	var nome_substituto: String = substituto.card.name if (substituto != null and substituto.card != null) else "Nulo"
	print("🏃 [BattleManager] Tentando recuar ativo '%s' por '%s' do banco | Jogador ID: %d" % [nome_atual, nome_substituto, jogador.id])

	if not RuleValidator.validar_recuo(jogador, energias_para_descarte):
		print("⚠️ [BattleManager] Falha ao recuar: validação do custo/condição de recuo falhou.")
		return {"sucesso": false, "motivo": "recuo_invalido"}

	if not RuleValidator.validar_recuo(jogador, energias_para_descarte):
		print("⚠️ [BattleManager] Falha ao recuar: substituto no banco inválido.")
		return {"sucesso": false, "motivo": "substituto_invalido"}

	# Paga o custo: descarta exatamente as energias que o jogador
	# escolheu (já validadas acima como suficientes pro custo).
	var descartadas: Array[EffectResource] = EnergySystem.pagar_custo(animal_atual, energias_para_descarte)
	GameState.obter_descarte(jogador.id).append_array(descartadas)

	# Trocar as posições
	GameState.obter_banco(jogador.id).erase(substituto)
	GameState.obter_banco(jogador.id).append(animal_atual)
	
	# Modificar a variável raiz no GameState
	if jogador.id == 0:
		GameState.ativo_j0 = substituto
	else:
		GameState.ativo_j1 = substituto

	GameState.recuo_realizado_neste_turno = true

	print("🔄 [BattleManager] Recuo efetuado! Novo Ativo: '%s'. Antigo Ativo '%s' movido para o banco." % [nome_substituto, nome_atual])
	return {"sucesso": true, "motivo": ""}

# ==================================================
# PROMOÇÃO FORÇADA — Ativo nocauteado precisa de substituto
# Diferente de "recuar": não custa nada, não tem limite de 1x/turno,
# e pode ser necessária no turno do ADVERSÁRIO (quando o ataque dele
# nocauteia seu Ativo). Por isso não usa GameState.jogador_ativo,
# recebe o jogador explicitamente em `dados`.
# ==================================================

## dados: {"jogador_id": int, "substituto": AnimalInstance}
func _promover_ativo(dados: Dictionary) -> Dictionary:
	var jogador_id: int = dados.get("jogador_id", -1)
	var substituto: AnimalInstance = dados.get("substituto")
	
	var nome_substituto: String = substituto.card.name if (substituto != null and substituto.card != null) else "Nulo"
	print("🚨 [BattleManager] Tentando promover '%s' do banco a novo Ativo | Jogador Solicitante ID: %d" % [nome_substituto, jogador_id])

	if GameState.jogador_sem_ativo != jogador_id:
		print("⚠️ [BattleManager] Promoção recusada: Jogador ID %d não precisa promover no momento." % jogador_id)
		return {"sucesso": false, "motivo": "nao_e_sua_vez_de_promover"}
	
	if jogador_id != 0 and jogador_id != 1:
		print("⚠️ [BattleManager] Promoção recusada: jogador_id inválido (%d)." % jogador_id)
		return {"sucesso": false, "motivo": "jogador_invalido"}

	if GameState.obter_ativo(jogador_id) != null:
		print("⚠️ [BattleManager] Promoção recusada: O jogador ID %d já possui um ativo na mesa." % jogador_id)
		return {"sucesso": false, "motivo": "ativo_ja_preenchido"}

	if substituto == null or not GameState.obter_banco(jogador_id).has(substituto):
		print("⚠️ [BattleManager] Promoção recusada: O animal substituto não está presente no banco.")
		return {"sucesso": false, "motivo": "substituto_invalido"}
	
	# Removendo do banco e atribuindo ao ativo
	GameState.obter_banco(jogador_id).erase(substituto)
	
	if jogador_id == 0:
		GameState.ativo_j0 = substituto
	else:
		GameState.ativo_j1 = substituto
		
	GameState.jogador_sem_ativo = -1
	
	print("🌟 [BattleManager] Promoção concluída! Jogador %d agora tem '%s' como Ativo." % [jogador_id, nome_substituto])

	if GameState.fase_atual == GameState.Fase.ATAQUE:
		TurnManager.fase_final()
	elif GameState.fase_atual == GameState.Fase.FINAL:
		TurnManager._encerrar_fase_final_e_passar_turno()
	
	return {"sucesso": true, "motivo": ""}
# ==================================================
# ATAQUE — encerra o turno, sempre (com sucesso ou falha por
# paralisia; só NÃO encerra se a declaração do ataque não for válida)
# ==================================================

## dados: {"ataque": CardResource}
func _atacar(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var adversario: PlayerState = GameState.get_jogador_adversario()
	var atacante: AnimalInstance = GameState.obter_ativo(jogador.id)
	var ataque: CardResource = dados.get("ataque")

	var nome_atacante: String = atacante.card.name if (atacante != null and atacante.card != null) else "Nulo"
	var nome_ataque: String = ataque.name if ataque != null else "Nulo"
	print("⚔️ [BattleManager] Tentando declarar ataque '%s' com '%s' | Atacante ID: %d" % [nome_ataque, nome_atacante, jogador.id])

	# 1. Validação de Regras e Custos (RuleValidator)
	var validacao := RuleValidator.validar_atacar(jogador.id)
	if not validacao["sucesso"]:
		print("⚠️ [BattleManager] Ataque recusado pelo RuleValidator: %s" % validacao["motivo"])
		return validacao

	# 2. Checagem de Restrição de Ação por Status (ex: ADORMECIDO, RECARREGANDO)
	if not ConditionSystem.pode_tentar_acao(atacante, "atacar"):
		print("⛔ [BattleManager] Atacante '%s' impedido de atacar devido a um status." % nome_atacante)
		return {"sucesso": false, "motivo": "acao_bloqueada_por_status"}

	# 3. Marca a flag para impedir múltiplos ataques no mesmo turno
	atacante.ja_atacou_este_turno = true

	# 4. Transição de Fase
	TurnManager.fase_ataque()

	# 5. Checagem de Paralisia (Teste da Moeda)
	if not ConditionSystem.rodar_moeda_paralisia(atacante):
		print("💫 [BattleManager] Atacante '%s' está paralisado e falhou na moeda! Ataque cancelado." % nome_atacante)
		ataque_falhou_paralisia.emit(atacante)
		TurnManager.fase_final()
		return {"sucesso": true, "motivo": "paralisado_falhou", "dano_causado": 0}

	var defensor: AnimalInstance = GameState.obter_ativo(adversario.id)
	var nome_defensor: String = defensor.card.name if (defensor != null and defensor.card != null) else "Nulo"
	var dano: int = 0

	# 6. Cálculo Consolidado e Aplicação Única de Dano (respeitando Imunidade/Proteção)
	if ConditionSystem.pode_receber_dano_direto(defensor):
		# CombatSystem chama AttackEffectResolver.calcular_dano_ataque() internamente,
		# resolvendo moedas, bônus condicionais e fraquezas em um único valor final.
		dano = CombatSystem.calcular_dano(atacante, defensor, ataque)
		print("💥 [BattleManager] Ataque validado! '%s' ataca '%s' causando %d de dano." % [nome_atacante, nome_defensor, dano])
		DamageSystem.aplicar_dano(defensor, dano)
	else:
		print("🛡️ [BattleManager] '%s' não sofreu dano devido a status de proteção/imunidade." % nome_defensor)

	# 7. Resolução de Efeitos Pós-Ataque (Apenas efeitos secundários: status, compras, descartes)
	await AttackEffectResolver.processar_efeito_pos_ataque(ataque, atacante, defensor, jogador.id)

	# 8. Notificação para UI
	ataque_executado.emit(atacante, defensor, ataque, dano)

	# 9. Processamento de Nocautes e Regras de Vitória
	var id_jogador_atual: int = GameState.jogador_ativo
	var id_adversario: int = 1 if id_jogador_atual == 0 else 0

	TurnManager.atualizar_sistema_de_nocautes(jogador, id_jogador_atual)
	TurnManager.atualizar_sistema_de_nocautes(adversario, id_adversario)

	if not GameState.partida_ativa or GameState.vencedor != null:
		print("🏆 [BattleManager] Vitória/Fim de Jogo detectado após o ataque.")
		return {"sucesso": true, "motivo": "fim_de_jogo", "dano_causado": dano}

	# Trava do jogo se alguém precisar promover um ativo do banco
	if GameState.jogador_sem_ativo != -1:
		var id_jogador_bloqueado: int = GameState.jogador_sem_ativo
		var banco: Array = GameState.obter_banco(id_jogador_bloqueado)

		if banco.is_empty():
			var resultado: WinConditionSystem.Resultado = (
				WinConditionSystem.Resultado.VITORIA_J1 if id_jogador_bloqueado == 0 
				else WinConditionSystem.Resultado.VITORIA_J0
			)
			TurnManager.verificar_e_notificar_fim_de_jogo(resultado, "Sem animais no banco para substituir o ativo!")
			return {"sucesso": true, "motivo": "fim_de_jogo", "dano_causado": dano}
			
	# 10. Encerramento do Turno
	print("🏁 [BattleManager] Ataque finalizado com sucesso. Encaminhando para fase_final().")
	TurnManager.fase_final()

	return {"sucesso": true, "motivo": "", "dano_causado": dano}

# ==================================================
# CATACLISMO — Executar efeito de carta de feitiço/evento
# ==================================================

## dados: {"carta": EffectResource, "contexto": Dictionary}
func _jogar_cataclismo(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var carta: EffectResource = dados.get("carta")
	var contexto: Dictionary = dados.get("contexto", {})

	var nome_carta: String = carta.name if carta != null else "Nula"
	print("☄️ [BattleManager] Tentando jogar Cataclismo: '%s' | Jogador ID: %d" % [nome_carta, jogador.id])

	# 1. Validação via RuleValidator
	var validacao: Dictionary = RuleValidator.validate_cataclysm(jogador, carta)
	if not validacao.get("sucesso", false):
		print("⚠️ [BattleManager] Falha ao jogar Cataclismo: %s" % validacao.get("motivo", "recusado_por_regra"))
		return validacao

	# 2. Resolução do Efeito via EffectCardResolver
	var resultado: Dictionary = EffectCardResolver.executar_carta_efeito(carta, jogador.id, contexto)

	# 3. Pós-processamento caso o efeito seja executado com sucesso
	if resultado.get("sucesso", false):
		# Remove da mão do jogador atual e move para o descarte
		var index: int = jogador.mao.find(carta)
		if index != -1:
			jogador.mao.remove_at(index)
		GameState.obter_descarte(jogador.id).append(carta)

		# Marca a flag de controle no GameState (limite de 1 Cataclismo por turno)
		GameState.cataclismo_jogado_neste_turno = true
		print("✅ [BattleManager] Cataclismo '%s' resolvido e enviado ao descarte." % nome_carta)
	else:
		print("❌ [BattleManager] Falha na resolução do Cataclismo '%s'. Motivo: %s" % [nome_carta, resultado.get("motivo", "erro_desconhecido")])

	return resultado

# ==================================================
# AÇÕES ESPECIAIS DISPARADAS POR EFEITOS
# ==================================================

## dados: {"jogador_id": int, "animal_alvo": AnimalInstance, "carta_energia": EffectResource}
func _energizar_por_efeito(dados: Dictionary) -> Dictionary:
	var jogador_id: int = dados.get("jogador_id", GameState.jogador_ativo)
	var player: PlayerState = GameState.get_jogador_por_id(jogador_id)
	var animal_alvo: AnimalInstance = dados.get("animal_alvo")
	var carta_energia: EffectResource = dados.get("carta_energia")

	var validacao := RuleValidator.validar_energizar_efeito(player, animal_alvo, carta_energia)
	if not validacao["sucesso"]:
		return validacao

	# Se a carta veio do deck, remove do deck; se veio da mão, remove da mão
	if player.deck.has(carta_energia):
		player.deck.erase(carta_energia)
	elif player.mao.has(carta_energia):
		player.mao.erase(carta_energia)

	EnergySystem.anexar_energia(animal_alvo, carta_energia)
	print("🔋 [BattleManager] Energia '%s' anexada via efeito em '%s'." % [carta_energia.name, animal_alvo.card.name])

	return {"sucesso": true, "motivo": ""}

## dados: {"id_oponente": int, "alvo_banco": AnimalInstance}
func _puxar_banco_oponente(dados: Dictionary) -> Dictionary:
	var id_oponente: int = dados.get("id_oponente")
	var alvo_banco: AnimalInstance = dados.get("alvo_banco")

	var validacao := RuleValidator.validar_trocar_ativo_oponente(id_oponente)
	if not validacao["sucesso"]:
		return validacao

	var ativo_atual: AnimalInstance = GameState.obter_ativo(id_oponente)
	if ativo_atual == null or alvo_banco == null:
		return {"sucesso": false, "motivo": "alvo_invalido"}

	# Realiza a troca no banco do oponente
	GameState.obter_banco(id_oponente).erase(alvo_banco)
	GameState.obter_banco(id_oponente).append(ativo_atual)

	if id_oponente == 0:
		GameState.ativo_j0 = alvo_banco
	else:
		GameState.ativo_j1 = alvo_banco

	print("🔄 [BattleManager] Efeito 'Puxar': '%s' foi movido para o ativo do oponente!" % alvo_banco.card.name)
	return {"sucesso": true, "motivo": ""}
# ==================================================
# AGENTES DE JOGADOR — cada jogador (humano ou IA) tem um agente
# responsável por decidir quando o motor precisa de uma escolha dele.
# Chamado DIRETO — elimina o broadcast de sinal que causava corrida
# entre AIController e mesa_jogador.gd reagindo ao mesmo evento.
# ==================================================
var _agentes: Dictionary = {} # { jogador_id: PlayerAgent }

func registrar_agente(jogador_id: int, agente: PlayerAgent) -> void:
	_agentes[jogador_id] = agente
	print("🎮 [BattleManager] Agente registrado para Jogador %d: %s" % [jogador_id, agente.get_script().get_global_name()])

func _obter_agente(jogador_id: int) -> PlayerAgent:
	if not _agentes.has(jogador_id):
		push_error("❌ [BattleManager] Nenhum agente registrado para Jogador %d!" % jogador_id)
		return null
	return _agentes[jogador_id]

## Chamado pelo TurnManager quando jogador_id fica sem Ativo. Substitui
## o antigo sinal 'substituicao_ativo_solicitada' — chamada direta e
## única ao agente responsável, sem broadcast.
func resolver_promocao_pendente(jogador_id: int) -> void:
	var agente: PlayerAgent = _obter_agente(jogador_id)
	if agente == null:
		return

	var banco: Array = GameState.obter_banco(jogador_id)
	if banco.is_empty():
		push_warning("⚠️ [BattleManager] resolver_promocao_pendente chamado com banco vazio (Jogador %d)." % jogador_id)
		return

	var substituto: AnimalInstance = await agente.decidir_promocao_ativo(banco)
	if substituto == null:
		push_warning("⚠️ [BattleManager] Agente do Jogador %d não retornou substituto válido." % jogador_id)
		return

	var res := _promover_ativo({"jogador_id": jogador_id, "substituto": substituto})
	if res.get("sucesso", false):
		TurnManager.notificar_ativo_substituido(jogador_id)
