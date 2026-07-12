# ==================================================
# Nome: HelperUI
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
#
# ==================================================================
# 📋 CHECKLIST OBRIGATÓRIO — ANTES DE CRIAR OU MEXER EM QUALQUER TELA
# ==================================================================
# Isso existe porque já perdemos tempo com os MESMOS 3 bugs de UI
# reaparecendo em lugares diferentes (mão, banco, ativo). Toda tela
# nova ou alterada que envolva cartas em Containers/Panels DEVE
# respeitar os 3 pontos abaixo. Se alguma dessas regras for quebrada,
# o sintoma quase sempre é: carta com tamanho errado, carta "brigando"
# com o layout, ou carta sumindo/pulando ao reorganizar a zona.
#
# 1) TODA carta nasce via HelperUI.instanciar_carta_escalada().
#    NUNCA chamar instanciar_carta() sozinho e escalar manualmente
#    depois (nem com call_deferred). A escala é calculada na hora,
#    matematicamente — não existe motivo pra escalar "depois do
#    layout" nunca mais.
#
# 2) TODO Container (HBoxContainer, GridContainer, VBoxContainer etc)
#    que exibe cartas recebe o ENVELOPE (resultado["envelope"]),
#    NUNCA o card_visual (resultado["visual"]) direto. O card_visual
#    só serve pra: (a) conectar sinais de input, (b) ser manipulado
#    em animações (scale, modulate). Quem vai para dentro da árvore
#    de um Container gerenciado é sempre o envelope.
#    Regra prática: se você está prestes a escrever
#    `algum_container.add_child(carta_visual)`, PARE — o certo é
#    `algum_container.add_child(resultado["envelope"])`.
#
# 3) TODA ação do jogador (jogar carta, atacar, recuar, usar
#    habilidade, prender) emite `acao_jogador_solicitada` e NADA MAIS.
#    A UI nunca decide se a ação é válida nem aplica o efeito —
#    quem decide é o manager (BattleManager/SetupManager/etc). Se
#    você está prestes a escrever uma condição tipo
#    `if jogador.comida_disponivel >= 1: aplica_efeito()` dentro de
#    um script de UI, PARE — isso é regra de jogo e pertence ao
#    Core, não à Mesa.
#
# Efeito colateral do padrão de envelope: qualquer função que busque
# "a carta" dentro de uma zona (pra animação, remoção, etc) precisa
# lembrar que o filho DIRETO da zona é o envelope — a carta real está
# um nível mais fundo (envelope.get_child(0)). Ver mesa_jogador.gd
# (_animar_ataque, animar_animal_nocauteado, _iniciar_arrasto_carta)
# pra exemplos de como isso é tratado corretamente.
# ==================================================================
class_name HelperUI
extends RefCounted

const CAMINHO_TEXTURA_VERSO := "res://Assets/Cards/verso_nome.jpg"
const TAMANHO_ORIGINAL_CARTA := Vector2(150, 233)


## Instancia a cena de carta correta pro tipo do recurso, aplicando a
## face (frente/verso) antes de inicializar. Os 4 tipos (Animal,
## Cataclismo/Vestígio, Território, Energia) suportam verso hoje.
##
## super_type -> cena:
##   "animal"                -> Card.tscn
##   "cataclismo","vestigio" -> CardEffect.tscn
##   "territorio"            -> CardTerritorio.tscn
##   "energia"               -> CardForcaPrimordial.tscn
##
## ⚠️ Uso direto desta função (sem passar por instanciar_carta_escalada)
## só é apropriado quando você vai controlar escala/posição por conta
## própria em seguida (ex: comprar_carta_animada, que ainda não segue
## o padrão de envelope — ver TODO em mesa_jogador.gd). Para qualquer
## carta que vai morar dentro de um Container gerenciado, use
## instanciar_carta_escalada() em vez desta.
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
	instancia.virada_para_baixo = face_para_baixo

	# IMPORTANTE: inicializar() só pode rodar depois de instancia estar
	# na árvore de cena — é o _ready() dela que carrega as referências
	# de nó (card_image, labels, sprites). Quem chama isso ainda vai
	# dar add_child() na instância retornada; call_deferred garante que
	# inicializar() só executa depois disso, mesmo no mesmo frame.
	instancia.call_deferred("inicializar", carta)
	return instancia


## Cria um Control só com a arte de verso, sem nenhum CardBaseResource
## anexado — usado pra pilha do deck (nunca deve expor qual carta é
## qual).
static func criar_verso_generico(tamanho: Vector2 = TAMANHO_ORIGINAL_CARTA) -> Control:
	var textura_rect := TextureRect.new()
	textura_rect.custom_minimum_size = tamanho
	textura_rect.size = tamanho
	textura_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	textura_rect.stretch_mode = TextureRect.STRETCH_SCALE

	if ResourceLoader.exists(CAMINHO_TEXTURA_VERSO):
		textura_rect.texture = load(CAMINHO_TEXTURA_VERSO)

	return textura_rect


## Aplica o "modo verso" num componente de carta já em cena: troca a
## textura do TextureRect principal pro verso e esconde os elementos
## de conteúdo (labels, sprites, arte central etc.). Quem chama
## continua responsável por re-renderizar a frente de verdade quando
## virar pra cima de novo — isso aqui só cuida da parte comum (antes
## duplicada em cada script de carta).
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


## Encolhe um card_visual pra caber dentro de um retângulo alvo,
## preservando a proporção original da carta — mesma técnica do
## deck_builder.gd (_aplicar_escala_grid), generalizada pra qualquer
## tamanho de slot. Usa a MENOR escala entre largura/altura, pra
## nunca estourar em nenhuma das duas direções.
##
## Chamar depois do card_visual já estar na árvore de cena (depois
## do add_child).
##
## ⚠️ Use isso só se você já tiver um motivo pra não usar
## instanciar_carta_escalada() (ver checklist no topo do arquivo).
## Pra qualquer carta nova indo pra dentro de um Container, prefira
## sempre a função de baixo.
static func aplicar_escala_carta(card_visual: Control, tamanho_alvo: Vector2) -> void:
	var escala_largura: float = tamanho_alvo.x / TAMANHO_ORIGINAL_CARTA.x
	var escala_altura: float = tamanho_alvo.y / TAMANHO_ORIGINAL_CARTA.y
	var escala: float = minf(escala_largura, escala_altura)

	card_visual.pivot_offset = Vector2.ZERO
	card_visual.scale = Vector2(escala, escala)
	card_visual.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_visual.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_visual.size = TAMANHO_ORIGINAL_CARTA


## Instancia uma carta JÁ escalada e embrulhada num "slot_envelope" —
## mesmo padrão comprovado no deck_builder.gd (_aplicar_escala_grid).
##
## Por que o envelope existe: um Container (HBoxContainer, GridContainer
## etc.) faz sort dos filhos DIRETOS dele, sobrescrevendo o tamanho
## deles. Se o card_visual (que tem seu próprio _ready()/inicializar()
## mexendo no próprio tamanho) for filho direto do Container, os dois
## ficam brigando pelo tamanho e a escala nunca gruda de verdade. O
## envelope é um Control vazio, sem lógica própria nenhuma — só ELE
## vai como filho direto do Container (com custom_minimum_size já no
## tamanho final desejado), e o card_visual fica livre dentro dele,
## sem ninguém mais mexendo no tamanho/escala depois da gente.
##
## ⭐ ESTA É A FUNÇÃO PADRÃO pra qualquer carta que vai morar dentro de
## um Container/Panel gerenciado. Ver checklist no topo do arquivo.
##
## Retorna {"envelope": Control, "visual": Control} — "envelope" é o
## que deve ser adicionado ao Container-pai; "visual" é a carta em si,
## pra quem precisar conectar input nela ou animá-la.
static func instanciar_carta_escalada(carta: CardBaseResource, tamanho_alvo: Vector2, face_para_baixo: bool = false) -> Dictionary:
	var carta_visual: Control = instanciar_carta(carta, face_para_baixo)
	if carta_visual == null:
		return {}

	var escala_largura: float = tamanho_alvo.x / TAMANHO_ORIGINAL_CARTA.x
	var escala_altura: float = tamanho_alvo.y / TAMANHO_ORIGINAL_CARTA.y
	var escala: float = minf(escala_largura, escala_altura)

	# custom_minimum_size do envelope usa o tamanho REAL depois de
	# escalar, não o tamanho_alvo bruto — importante quando tamanho_alvo
	# usa um valor "sentinela" grande numa dimensão só pra dizer "essa
	# dimensão não limita, só a outra importa" (é o caso da mão: altura
	# fixa, largura livre).
	var tamanho_final: Vector2 = TAMANHO_ORIGINAL_CARTA * escala

	var slot_envelope := Control.new()
	slot_envelope.custom_minimum_size = tamanho_final
	slot_envelope.add_child(carta_visual)

	carta_visual.pivot_offset = Vector2.ZERO
	carta_visual.scale = Vector2(escala, escala)
	carta_visual.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	carta_visual.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	carta_visual.size = TAMANHO_ORIGINAL_CARTA
	carta_visual.position = Vector2.ZERO

	return {"envelope": slot_envelope, "visual": carta_visual}


## Cria um pop-up modal simples: fundo escurecido bloqueando clique
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
