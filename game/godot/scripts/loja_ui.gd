class_name LojaUI
extends CanvasLayer
## Tela de compra do Mercado (comida, kit medico, assalto ao caixa) e do Arsenal
## (armas, municao, colete). O mundo fica parado enquanto a tela esta aberta.

const COR_PAINEL := Color(0.063, 0.086, 0.114, 0.94)
const COR_TEXTO := Color("#f6efe3")
const COR_SUAVE := Color("#b9c0c7")
const COR_OURO := Color("#ffcc33")
const COR_BRASA := Color("#ff6a2b")
const COR_VERDE := Color("#8ee07a")
const COR_VERM := Color("#ff4a55")

const MERCADO := [
	{"id": "coco", "nome": "Água de coco", "desc": "+20 de vida", "preco": 5},
	{"id": "pastel", "nome": "Pastel e caldo de cana", "desc": "+50 de vida", "preco": 15},
	{"id": "kit", "nome": "Kit de primeiros socorros", "desc": "Vida cheia", "preco": 60},
]

var jogo
var tipo := ""
var loja_id := -1
var raiz: Control
var titulo: Label
var subtitulo: Label
var lista: VBoxContainer
var status: Label
var dinheiro_lbl: Label


func _init(p_jogo) -> void:
	jogo = p_jogo
	layer = 15


func _ready() -> void:
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.45)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)
	var painel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = COR_PAINEL
	s.set_corner_radius_all(14)
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, 0.16)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	painel.add_theme_stylebox_override("panel", s)
	painel.custom_minimum_size = Vector2(560, 0)
	centro.add_child(painel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	painel.add_child(vb)
	var topo := HBoxContainer.new()
	titulo = _rotulo("", 30, COR_TEXTO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dinheiro_lbl = _rotulo("", 24, COR_VERDE)
	topo.add_child(titulo)
	topo.add_child(dinheiro_lbl)
	vb.add_child(topo)
	subtitulo = _rotulo("", 15, COR_SUAVE)
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(subtitulo)
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	vb.add_child(lista)
	status = _rotulo("", 16, COR_OURO)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(status)
	vb.add_child(_rotulo("Esc ou E para sair", 13, COR_SUAVE))
	add_child(raiz)
	raiz.visible = false


func _rotulo(t: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	return l


func _botao(texto: String, cor: Color, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	for estado in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 9
		s.content_margin_bottom = 9
		s.bg_color = Color(1, 1, 1, 0.12) if estado in ["hover", "focus"] else Color(1, 1, 1, 0.05)
		if estado == "focus":
			s.set_border_width_all(2)
			s.border_color = COR_OURO
		b.add_theme_stylebox_override(estado, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, cor)
	b.pressed.connect(acao)
	return b


func aberta() -> bool:
	return raiz.visible


func abrir(p_tipo: String, id: int = -1) -> void:
	tipo = p_tipo
	loja_id = id
	status.text = ""
	_montar()
	raiz.visible = true
	jogo.abrir_ui("loja")


func fechar() -> void:
	raiz.visible = false
	jogo.fechar_ui()


func _montar() -> void:
	for c in lista.get_children():
		c.queue_free()
	dinheiro_lbl.text = U.dinheiro(jogo.dinheiro)
	var primeiro: Button = null
	if tipo == "mercado":
		titulo.text = "MERCADO"
		subtitulo.text = "Vida: %d/100. Comida recupera a vida." % int(jogo.jogador.vida)
		for item in MERCADO:
			var b := _botao("%s  ·  %s  ·  %s" % [item["nome"], item["desc"], U.dinheiro(item["preco"])], COR_TEXTO, comprar.bind(item["id"]))
			lista.add_child(b)
			if primeiro == null:
				primeiro = b
		if jogo.armas.armado():
			lista.add_child(_botao("Assaltar o caixa (crime: a câmera grava)", COR_VERM, assaltar))
	else:
		titulo.text = "ARSENAL DO PORTO"
		subtitulo.text = "Colete: %d/100. Armas compradas ficam com você até ser preso." % int(jogo.jogador.colete)
		for arma in ["pistola", "escopeta", "submetralhadora"]:
			var t: Dictionary = Armas.TIPOS[arma]
			var texto: String
			if jogo.armas.tem(arma):
				texto = "Munição de %s  ·  +%d  ·  %s" % [t["nome"].to_lower(), t["pacote"], U.dinheiro(t["preco_municao"])]
			else:
				texto = "%s  ·  %d balas  ·  %s" % [t["nome"], t["pacote"], U.dinheiro(t["preco"])]
			var b := _botao(texto, COR_TEXTO, comprar.bind(arma))
			lista.add_child(b)
			if primeiro == null:
				primeiro = b
		lista.add_child(_botao("Colete à prova de balas  ·  colete 100  ·  R$ 250", COR_TEXTO, comprar.bind("colete")))
	lista.add_child(_botao("Sair", COR_SUAVE, fechar))
	if primeiro:
		primeiro.call_deferred("grab_focus")


## Compra um item pelo id. Devolve o texto de resultado (usado tambem pelos testes).
func comprar(id: String) -> String:
	var jj = jogo.jogador
	var preco := 0
	var feito := ""
	match id:
		"coco", "pastel", "kit":
			for item in MERCADO:
				if item["id"] == id:
					preco = item["preco"]
			if jj.vida >= 100.0:
				return _status("Sua vida já está cheia.")
			if jogo.dinheiro < preco:
				return _status("Dinheiro insuficiente.")
			jj.curar({"coco": 20.0, "pastel": 50.0, "kit": 100.0}[id])
			feito = "Vida: %d/100." % int(jj.vida)
		"colete":
			preco = 250
			if jj.colete >= 100.0:
				return _status("Seu colete já está inteiro.")
			if jogo.dinheiro < preco:
				return _status("Dinheiro insuficiente.")
			jj.colete = 100.0
			feito = "Colete vestido."
		_:
			var t: Dictionary = Armas.TIPOS[id]
			var tem: bool = jogo.armas.tem(id)
			preco = t["preco_municao"] if tem else t["preco"]
			if jogo.dinheiro < preco:
				return _status("Dinheiro insuficiente.")
			jogo.armas.dar(id, t["pacote"])
			feito = ("+%d balas de %s." % [t["pacote"], t["nome"].to_lower()]) if tem else ("%s comprada. Botão direito mira, esquerdo atira." % t["nome"])
	jogo.dinheiro -= preco
	jogo.audio.tocar("compra")
	jogo.salvar()
	_montar()
	return _status(feito)


func assaltar() -> String:
	var resultado: String = jogo.assaltar_loja(loja_id)
	fechar()
	return resultado


func _status(t: String) -> String:
	status.text = t
	return t
