class_name HumanAgent
extends PlayerAgent
# Precisa da mesa só pra instanciar popup como filho dela (add_child).
# Não lê nem decide regra nenhuma — só abre UI e devolve a escolha.

var mesa: Node = null

func _init(p_jogador_id: int, p_mesa: Node) -> void:
	super._init(p_jogador_id)
	mesa = p_mesa

func decidir_promocao_ativo(banco_disponivel: Array) -> AnimalInstance:
	if banco_disponivel.is_empty():
		return null

	var popup := PopupPromocao.new()
	mesa.add_child(popup)

	var estado := {"concluido": false, "resultado": null}

	popup.promocao_confirmada.connect(func(_id: int, substituto: AnimalInstance):
		estado["resultado"] = substituto
		estado["concluido"] = true
	)

	popup.exibir(mesa, jogador_id, banco_disponivel)

	while not estado["concluido"]:
		await mesa.get_tree().process_frame

	return estado["resultado"]

func decidir_selecao_cartas(elegiveis: Array, quantidade: int, contexto: String) -> Array:
	print("🔬 [DEBUG] decidir_selecao_cartas chamado | elegiveis.size() = %d | contexto = %s" % [elegiveis.size(), contexto])
	var cartas_tipadas: Array[CardBaseResource] = []
	cartas_tipadas.assign(elegiveis)
	print("🔬 [DEBUG] cartas_tipadas.size() após assign() = %d" % cartas_tipadas.size())
	var estado := {"concluido": false, "resultado": []}

	if contexto == "descarte_energia_animal":
		var popup := PopupDescarteEnergia.new()
		mesa.add_child(popup)
		popup.energias_selecionadas.connect(func(escolhidas: Array[CardBaseResource]):
			estado["resultado"] = escolhidas
			estado["concluido"] = true
		)
		popup.cancelado.connect(func():
			estado["concluido"] = true
		)
		popup.exibir(mesa, "Escolha %d energia(s):" % quantidade, cartas_tipadas, quantidade)
	else:
		mesa.solicitar_selecao_cartas_zona(
			"Seleção",
			"Selecione %d carta(s)" % quantidade,
			cartas_tipadas,
			quantidade,
			func(cartas_escolhidas: Array[CardBaseResource]):
				print("🔬 [DEBUG] callback recebido dentro do HumanAgent! %d cartas" % cartas_escolhidas.size())
				estado["resultado"] = cartas_escolhidas
				estado["concluido"] = true
		)

	while not estado["concluido"]:
		await mesa.get_tree().process_frame
	print("🔬 [DEBUG] decidir_selecao_cartas retornando com %d carta(s)" % estado["resultado"].size())
	return estado["resultado"]
	
