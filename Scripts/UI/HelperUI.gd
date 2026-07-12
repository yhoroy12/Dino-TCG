# ==================================================
# Nome: Helper
# Categoria: UI (utilitário)
# Responsável por construir elementos de UI genéricos e
# reutilizáveis em código (sem depender de cena/tscn própria).
#
# NÃO decide regra, NÃO lê GameState/PlayerState, NÃO conecta
# a sinais de gameplay. Só monta Controls e devolve referências
# pra quem chamou ligar os sinais que fizerem sentido pro
# contexto (ex: pressed de um botão).
#
# static func, sem estado — mesmo espírito dos Systems (Core),
# mas na camada de UI: uma "calculadora" de nós visuais.
# ==================================================
class_name HelperUI
extends RefCounted


## Instancia a cena de carta correta pro tipo do recurso, já aplicando
## a face (frente/verso) antes de inicializar.
##
## super_type -> cena:
##   "animal"              -> Card.tscn        (suporta verso)
##   "cataclismo","vestigio" -> CardEffect.tscn (suporta verso)
##   "territorio"          -> CardTerritorio.tscn (NÃO suporta verso ainda)
##   "energia"              -> CardForcaPrimordial.tscn (NÃO suporta verso ainda)
##
## Pros dois últimos, se face_para_baixo for true, devolve um verso
## GENÉRICO (sem o recurso real anexado) em vez da carta de verdade —
## virada_para_baixo/definir_face(), like Card.gd/card_effecct.gd já têm.
## Isso evita vazar informação escondida do oponente.

const CAMINHO_TEXTURA_VERSO = "res://Assets/Cards/verso_nome.jpg"

static func instanciar_carta(carta: CardBaseResource, face_para_baixo: bool = false) -> Control:
	if carta == null:
		push_error("HelperUI.instanciar_carta: recurso nulo.")
		return null

	var super_type := str(carta.get("super_type")).strip_edges().to_lower()
	var cena: PackedScene

	match super_type:
		"animal":
			cena = preload("res://Scenes/Components/card/Card.tscn")
		"cataclismo", "vestigio":
			cena = preload("res://Scenes/Components/card/CardEffect.tscn")
		"territorio":
			cena = preload("res://Scenes/Components/card/CardTerritorio.tscn")
		"energia":
			cena = preload("res://Scenes/Components/card/CardForcaPrimordial.tscn")
		_:
			push_warning("HelperUI.instanciar_carta: super_type desconhecido '%s', usando Card.tscn." % super_type)
			cena = preload("res://Scenes/Components/card/Card.tscn")

	var instancia: Control = cena.instantiate()
	if face_para_baixo:
		instancia.virada_para_baixo = true
	instancia.inicializar(carta)
	return instancia

## Cria um Control só com a arte de verso, sem nenhum CardBaseResource
## anexado — usado pra pilha do deck (nunca deve expor qual carta é
## qual) e como fallback de segurança em instanciar_carta().
static func criar_verso_generico(tamanho: Vector2 = Vector2(150, 233)) -> Control:
	var textura_rect := TextureRect.new()
	textura_rect.custom_minimum_size = tamanho
	textura_rect.size = tamanho
	textura_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	textura_rect.stretch_mode = TextureRect.STRETCH_SCALE

	const CAMINHO_VERSO := "res://Assets/Cards/verso_nome.jpg"
	if ResourceLoader.exists(CAMINHO_VERSO):
		textura_rect.texture = load(CAMINHO_VERSO)

	return textura_rect


## (overlay) + painel central com título, subtítulo e um VBox pronto
## pra receber botões.
##
## parent: nó ao qual o pop-up será anexado (normalmente a própria
## cena que está chamando, via `self`). Quem chama é responsável por
## remover o pop-up depois (overlay.queue_free()) — este helper não
## guarda referência nenhuma.
##
## Retorna um Dictionary com "overlay" (o Control raiz, use pra
## remover o pop-up depois), "painel" e "vbox" (pra adicionar botões
## e outros controles extras).
static func criar_popup_base(parent: Node, titulo: String, subtitulo: String) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_top = 0.5
	painel.anchor_right = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -180
	painel.offset_top = -100
	painel.offset_right = 180
	painel.offset_bottom = 100

	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 24)
	margem.add_theme_constant_override("margin_right", 24)
	margem.add_theme_constant_override("margin_top", 20)
	margem.add_theme_constant_override("margin_bottom", 20)
	painel.add_child(margem)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margem.add_child(vbox)

	var label_titulo := Label.new()
	label_titulo.text = titulo
	label_titulo.add_theme_font_size_override("font_size", 26)
	label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label_titulo)

	var label_subtitulo := Label.new()
	label_subtitulo.text = subtitulo
	label_subtitulo.add_theme_font_size_override("font_size", 15)
	label_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label_subtitulo)

	overlay.add_child(painel)
	parent.add_child(overlay)

	return {"overlay": overlay, "painel": painel, "vbox": vbox}
	
	## Aplica o "modo verso" num componente de carta já em cena: troca a
## textura do TextureRect principal pro verso e esconde os elementos
## de conteúdo (labels, sprites, arte central etc.).
## Quem chama continua responsável por re-renderizar a frente de
## verdade quando virar pra cima de novo — isso aqui só cuida da
## parte comum (antes duplicada em cada script de carta).
static func aplicar_verso(textura_alvo: TextureRect, elementos_frente: Array) -> void:
	if textura_alvo and ResourceLoader.exists(CAMINHO_TEXTURA_VERSO):
		textura_alvo.texture = load(CAMINHO_TEXTURA_VERSO)
	for elemento in elementos_frente:
		if elemento is CanvasItem:
			elemento.hide()


## Desfaz o verso, mostrando de novo os elementos de conteúdo.
## A textura de frente em si fica a cargo de _renderizar_frente() de
## cada script (é específica demais pra generalizar aqui).
static func remover_verso(elementos_frente: Array) -> void:
	for elemento in elementos_frente:
		if elemento is CanvasItem:
			elemento.show()
