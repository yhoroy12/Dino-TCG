# ==================================================
# Nome: CoinFlipPanel
# Categoria: UI
# Responsável pela interface de cara ou coroa.
# ==================================================

class_name CoinFlipPanel
extends Control

signal moeda_lancada()
signal ordem_escolhida(quer_jogar_primeiro: bool)

var _overlay_ref: Control = null

func exibir_sorteio_moeda(parent: Node) -> void:
	_limpar()
	var refs := HelperUI.criar_popup_base(
		parent,
		"Sorteio",
		"Clique para lançar a moeda e ver quem começa."
	)
	_overlay_ref = refs["overlay"]
	
	var botao := Button.new()
	botao.text = "Lançar Moeda"
	botao.pressed.connect(func():
		moeda_lancada.emit()
		fechar()
	)
	refs["vbox"].add_child(botao)

func exibir_escolha_ordem(parent: Node, tempo_limite: float = 15.0) -> void:
	_limpar()
	var refs := HelperUI.criar_popup_base(
		parent,
		"Você venceu o sorteio!",
		"Escolha se quer jogar primeiro ou deixar o oponente começar."
	)
	_overlay_ref = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	var btn_primeiro := Button.new()
	btn_primeiro.text = "Jogar Primeiro"
	btn_primeiro.pressed.connect(func():
		ordem_escolhida.emit(true)
		fechar()
	)
	vbox.add_child(btn_primeiro)

	var btn_segundo := Button.new()
	btn_segundo.text = "Deixar Oponente Começar"
	btn_segundo.pressed.connect(func():
		ordem_escolhida.emit(false)
		fechar()
	)
	vbox.add_child(btn_segundo)

	var local_overlay := _overlay_ref
	# 🟢 CORRIGIDO: Usa o timer da árvore do parent para evitar crash
	await parent.get_tree().create_timer(tempo_limite).timeout
	if is_instance_valid(local_overlay) and _overlay_ref == local_overlay:
		ordem_escolhida.emit(true)
		fechar()

func exibir_resultado_derrota(parent: Node, vencedor_id: int, duracao: float = 3.0) -> void:
	_limpar()
	var refs := HelperUI.criar_popup_base(
		parent,
		"Jogador %d venceu o sorteio!" % vencedor_id,
		"O oponente decidiu jogar primeiro."
	)
	_overlay_ref = refs["overlay"]

	var local_overlay := _overlay_ref
	# 🟢 CORRIGIDO: Usa o timer da árvore do parent para evitar crash
	await parent.get_tree().create_timer(duracao).timeout
	if is_instance_valid(local_overlay) and _overlay_ref == local_overlay:
		fechar()

func fechar() -> void:
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	# 🟢 CORRIGIDO: Libera a si mesmo caso não esteja na árvore
	if not is_inside_tree():
		queue_free()

func _limpar() -> void:
	fechar()
