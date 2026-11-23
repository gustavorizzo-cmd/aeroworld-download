class_name ControlesToque
extends CanvasLayer
## Controles de toque (tablet/celular): joystick a esquerda, arrastar a direita gira a
## camera e botoes redondos que mudam conforme a situacao (a pe ou no carro).

const COR_BASE := Color(0.063, 0.086, 0.114, 0.45)
const COR_BORDA := Color(1, 1, 1, 0.3)
const COR_TEXTO := Color("#f6efe3")
const COR_TEXTO_ESCURO := Color("#10161d")

var jogo
var entrada
var raiz: Control
var joy_centro := Vector2.ZERO
var joy_raio := 72.0
var joy_dedo := -1
var joy_vetor := Vector2.ZERO
var cam_dedo := -1
var botoes: Array = []  # {nome, rotulo, pos, raio, cor, modo: "toque"|"segurar"|"alternar", acao, quando, dedo}
var fonte: Font


func _init(p_jogo) -> void:
	jogo = p_jogo
	layer = 12


func _ready() -> void:
	fonte = ThemeDB.fallback_font
	entrada = jogo.entrada
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.draw.connect(_desenhar)
	add_child(raiz)
	get_viewport().size_changed.connect(_posicionar)
	_posicionar()


func _posicionar() -> void:
	var tam := raiz.get_viewport_rect().size
	var m := 22.0
	joy_centro = Vector2(m + joy_raio + 18.0, tam.y - m - joy_raio - 18.0)
	var r := 38.0
	var g := r * 2.0 + 14.0  # espaco entre botoes
	var base := Vector2(tam.x - m - 56.0, tam.y - m - 56.0)
	botoes = [
		{"nome": "atirar", "rotulo": "ATIRAR", "pos": base, "raio": 52.0, "cor": Color("#ff2a3a"), "modo": "segurar", "acao": "atirar", "quando": "a_pe"},
		{"nome": "freio", "rotulo": "FREIO", "pos": base, "raio": 52.0, "cor": Color("#f6efe3"), "modo": "segurar", "acao": "freio_mao", "quando": "carro"},
		{"nome": "e", "rotulo": "E", "pos": base + Vector2(-g - 16.0, 8.0), "raio": r, "cor": Color("#ff6a2b"), "modo": "toque", "acao": "acao", "quando": "sempre"},
		{"nome": "mirar", "rotulo": "MIRAR", "pos": base + Vector2(-2.0 * g - 16.0, 8.0), "raio": r, "cor": Color("#f6efe3"), "modo": "alternar", "acao": "", "quando": "a_pe"},
		{"nome": "arma", "rotulo": "ARMA", "pos": base + Vector2(-g * 0.5 - 8.0, -g - 8.0), "raio": r * 0.85, "cor": COR_BASE, "modo": "toque", "acao": "arma_prox", "quando": "a_pe"},
		{"nome": "buzina", "rotulo": "BUZINA", "pos": base + Vector2(-g * 0.5 - 8.0, -g - 8.0), "raio": r * 0.85, "cor": COR_BASE, "modo": "toque", "acao": "buzina", "quando": "carro"},
		{"nome": "celular", "rotulo": "CELULAR", "pos": base + Vector2(-g * 1.5 - 16.0, -g - 8.0), "raio": r * 0.85, "cor": COR_BASE, "modo": "toque", "acao": "celular", "quando": "sempre"},
		{"nome": "mapa", "rotulo": "MAPA", "pos": Vector2(tam.x - 150.0, 190.0), "raio": 26.0, "cor": COR_BASE, "modo": "toque", "acao": "mapa", "quando": "sempre"},
		{"nome": "pausa", "rotulo": "II", "pos": Vector2(tam.x - 80.0, 190.0), "raio": 26.0, "cor": COR_BASE, "modo": "toque", "acao": "pausa", "quando": "sempre"},
	]
	for b in botoes:
		b["dedo"] = -1


func _visivel(b: Dictionary) -> bool:
	var a_pe: bool = jogo.jogador == null or jogo.jogador.veiculo == null
	match b["quando"]:
		"a_pe":
			return a_pe
		"carro":
			return not a_pe
	return true


func ativo() -> bool:
	return visible and jogo.pronto and not jogo.pausado and jogo.ui_aberta == ""


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not ativo():
		_soltar_tudo()
		return
	var idx: int = event.index
	var p: Vector2 = event.position
	if event is InputEventScreenTouch and event.pressed:
		# botoes primeiro
		for b in botoes:
			if _visivel(b) and p.distance_to(b["pos"]) <= b["raio"] + 10.0:
				b["dedo"] = idx
				_apertar(b)
				get_viewport().set_input_as_handled()
				raiz.queue_redraw()
				return
		if p.distance_to(joy_centro) <= joy_raio * 1.7 and p.x < raiz.size.x * 0.5:
			joy_dedo = idx
			_mover_joy(p)
		elif p.x > raiz.size.x * 0.35:
			cam_dedo = idx
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		for b in botoes:
			if b["dedo"] == idx:
				b["dedo"] = -1
				if b["modo"] == "segurar":
					entrada.segurar(b["acao"], false)
		if idx == joy_dedo:
			joy_dedo = -1
			joy_vetor = Vector2.ZERO
			entrada.toque_eixo = Vector2.ZERO
		if idx == cam_dedo:
			cam_dedo = -1
		raiz.queue_redraw()
	elif event is InputEventScreenDrag:
		if idx == joy_dedo:
			_mover_joy(p)
		elif idx == cam_dedo:
			entrada.arraste += event.relative * 1.1
		get_viewport().set_input_as_handled()


func _apertar(b: Dictionary) -> void:
	match b["modo"]:
		"toque":
			entrada.apertar(b["acao"])
		"segurar":
			entrada.apertar(b["acao"])
			entrada.segurar(b["acao"], true)
		"alternar":
			jogo.armas.mirar_toque = not jogo.armas.mirar_toque


func _mover_joy(p: Vector2) -> void:
	var d := p - joy_centro
	if d.length() > joy_raio:
		d = d.normalized() * joy_raio
	joy_vetor = d / joy_raio
	entrada.toque_eixo = joy_vetor
	raiz.queue_redraw()


func _soltar_tudo() -> void:
	if joy_dedo >= 0 or cam_dedo >= 0:
		joy_dedo = -1
		cam_dedo = -1
		joy_vetor = Vector2.ZERO
		entrada.toque_eixo = Vector2.ZERO
	for b in botoes:
		if b["dedo"] >= 0:
			b["dedo"] = -1
			if b["modo"] == "segurar":
				entrada.segurar(b["acao"], false)


func _process(_delta: float) -> void:
	var mostrar: bool = jogo.pronto and not jogo.pausado and jogo.ui_aberta == "" and not jogo.interface.inicio.visible
	if raiz.visible != mostrar:
		raiz.visible = mostrar
		if not mostrar:
			_soltar_tudo()
	if raiz.visible:
		raiz.queue_redraw()


func _desenhar() -> void:
	# joystick
	raiz.draw_circle(joy_centro, joy_raio, COR_BASE)
	raiz.draw_arc(joy_centro, joy_raio, 0, TAU, 48, COR_BORDA, 2.0, true)
	raiz.draw_circle(joy_centro + joy_vetor * joy_raio, joy_raio * 0.45, Color(0.96, 0.94, 0.89, 0.8))
	# botoes
	for b in botoes:
		if not _visivel(b):
			continue
		var cor: Color = b["cor"]
		if b["nome"] == "mirar" and jogo.armas.mirar_toque:
			cor = Color("#ffcc33")
		if b["dedo"] >= 0:
			cor = cor.lightened(0.25)
		var pos: Vector2 = b["pos"]
		var r: float = b["raio"]
		raiz.draw_circle(pos + Vector2(0, 4), r, Color(0, 0, 0, 0.35))
		raiz.draw_circle(pos, r, cor)
		raiz.draw_arc(pos, r, 0, TAU, 40, COR_BORDA, 1.5, true)
		var claro: bool = cor.get_luminance() > 0.55
		var tam_fonte := 24 if b["rotulo"].length() <= 2 else (15 if b["rotulo"].length() <= 5 else 12)
		raiz.draw_string(fonte, pos + Vector2(-r, tam_fonte * 0.35), b["rotulo"], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, tam_fonte, COR_TEXTO_ESCURO if claro else COR_TEXTO)
