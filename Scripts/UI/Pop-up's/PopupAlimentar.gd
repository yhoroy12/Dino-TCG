class_name PopupAlimentar
extends Control

signal alimentacao_confirmada(animal: AnimalInstance, quantidade: int)
signal cancelado()

var _overlay_ref: Control = null
var _quant_atual: int = 1

func exibir(parent: Node, animal: AnimalInstance, max_comida: int) -> void:
	fechar()
	
	if max_comida <= 0:
		cancelado.emit()
		return

	_quant_atual = 1 # Reseta para 1 a cada exibição

	var refs := HelperUI.criar_popup_base(
		parent,
		"Alimentar %s" % animal.card.name,
		"Pool disponível: %d" % max_comida
	)
	_overlay_ref = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	var label_quant := Label.new()
	label_quant.text = str(_quant_atual)
	label_quant.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_quant.add_theme_font_size_override("font_size", 28)
	vbox.add_child(label_quant)

	var linha_botoes := HBoxContainer.new()
	linha_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(linha_botoes)

	var btn_menos := Button.new()
	btn_menos.text = " - "
	linha_botoes.add_child(btn_menos)

	var btn_mais := Button.new()
	btn_mais.text = " + "
	linha_botoes.add_child(btn_mais)

	btn_menos.pressed.connect(func():
		_quant_atual = maxi(1, _quant_atual - 1)
		label_quant.text = str(_quant_atual)
	)

	btn_mais.pressed.connect(func():
		_quant_atual = mini(max_comida, _quant_atual + 1)
		label_quant.text = str(_quant_atual)
	)

	var btn_confirmar := Button.new()
	btn_confirmar.text = "Confirmar"
	btn_confirmar.pressed.connect(func():
		print("[PopupAlimentar] Confirmando envio de %d de comida para %s" % [_quant_atual, animal.card.name])
		alimentacao_confirmada.emit(animal, _quant_atual)
		fechar()
	)
	vbox.add_child(btn_confirmar)

	var btn_cancelar := Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.pressed.connect(func():
		cancelado.emit()
		fechar()
	)
	vbox.add_child(btn_cancelar)

func fechar() -> void:
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	if not is_inside_tree():
		queue_free()
