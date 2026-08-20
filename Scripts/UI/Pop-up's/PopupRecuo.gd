class_name PopupRecuo
extends Control

# 🟢 CORRIGIDO: Typo do parâmetro arrumado (substitutu -> substituto)
signal recuo_confirmado(substituto: AnimalInstance, energias_descarte: Array)
signal erro_selecao(mensagem: String)

var _overlay_ref: Control = null

func exibir(parent: Node, ativo: AnimalInstance, substituto: AnimalInstance, custo: int) -> void:
	fechar()
	if ativo == null or ativo.attached_energies.size() < custo:
		erro_selecao.emit("Energia insuficiente pra recuar")
		return

	var refs := HelperUI.criar_popup_base(
		parent,
		"Pagar custo de recuo",
		"Escolha %d energia(s) pra descartar" % custo
	)
	_overlay_ref = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	var label_alerta := Label.new()
	label_alerta.add_theme_color_override("font_color", Color.RED)
	label_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_alerta.hide()
	vbox.add_child(label_alerta)

	var botoes_energia: Array[Dictionary] = []

	for energia in ativo.attached_energies:
		var btn := Button.new()
		btn.text = str(energia.name)
		btn.toggle_mode = true
		vbox.add_child(btn)
		botoes_energia.append({"botao": btn, "energia": energia})

	var btn_confirmar := Button.new()
	btn_confirmar.text = "Confirmar Recuo"
	btn_confirmar.pressed.connect(func():
		var selecionadas: Array = []
		for item in botoes_energia:
			if item["botao"].button_pressed:
				selecionadas.append(item["energia"])

		if selecionadas.size() != custo:
			label_alerta.text = "Selecione exatamente %d energia(s)!" % custo
			label_alerta.show()
			erro_selecao.emit("Selecione exatamente %d energia(s)" % custo)
			return

		recuo_confirmado.emit(substituto, selecionadas)
		fechar()
	)
	vbox.add_child(btn_confirmar)

func fechar() -> void:
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	if not is_inside_tree():
		queue_free()
