class_name Hud
extends CanvasLayer
## HUD: objetivo, dinheiro, estrelas, Ficha, minimapa com GPS, mapa grande,
## velocimetro/lataria, mensagens, avisos de testemunha e de prisao.

const MUNDO_MIN := Vector2(-380.0, -380.0)  # margem larga: o minimapa nunca le fora da imagem
const MUNDO_MAX := Vector2(400.0, 380.0)
const ESCALA := 1.5  # px por metro na imagem base

const COR_PAINEL := Color(0.063, 0.086, 0.114, 0.78)
const COR_TEXTO := Color("#f6efe3")
const COR_SUAVE := Color("#b9c0c7")
const COR_OURO := Color("#ffcc33")
const COR_BRASA := Color("#ff6a2b")
const COR_MAR := Color("#22d3ee")
const COR_VERM := Color("#ff2a3a")
const COR_AZUL := Color("#3a74ff")
const COR_ROXO := Color("#b07cff")
const COR_LOJA := Color("#7be38a")
const COR_ARSENAL := Color("#ff6b6b")

var jogo
var raiz: Control
var obj_titulo: Label
var obj_texto: Label
var cronometro_lbl: Label
var dinheiro_lbl: Label
var estrelas_ctl: Control
var chip_carro: PanelContainer
var chip_roupa: PanelContainer
var aviso_busca: PanelContainer
var aviso_busca_lbl: Label
var mini: Control
var distrito_lbl: Label
var velo: PanelContainer
var velo_num: Label
var lataria_fill: ColorRect
var msgs: VBoxContainer
var ligacao: PanelContainer
var ligacao_lbl: Label
var prisao: PanelContainer
var prisao_fill: ColorRect
var banner_box: VBoxContainer
var banner_tit: Label
var banner_sub: Label
var prompt: PanelContainer
var prompt_lbl: Label
var mapa_grande: Control
var mapa_canvas: Control
var base_tex: ImageTexture
var fonte: Font
var distrito_atual := ""
var t_banner := 0.0
var _ultima_dica := ""
var _t_dica := -10.0
var historico: Array = []  # usado pelos testes
var barra_vida: ColorRect
var barra_colete: ColorRect
var arma_painel: PanelContainer
var arma_lbl: Label
var mira_ctl: Control
var flash: ColorRect


func _init(p_jogo) -> void:
	jogo = p_jogo
	layer = 5


func _ready() -> void:
	fonte = ThemeDB.fallback_font
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_montar()
	base_tex = _desenhar_base()
	raiz.visible = false


# ------------------------------------------------------------------ construcao
func estilo(cor: Color = COR_PAINEL, raio: int = 10, borda: Color = Color(1, 1, 1, 0.14)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(raio)
	s.set_border_width_all(1)
	s.border_color = borda
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


func painel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", estilo())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func rotulo(texto: String, tam: int, cor: Color = COR_TEXTO, contorno: bool = false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	if contorno:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ancorar(c: Control, preset: int, ox: float, oy: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = ox
	c.offset_top = oy
	c.offset_right = ox
	c.offset_bottom = oy


func _montar() -> void:
	# objetivo (canto superior esquerdo)
	var obj := painel()
	_ancorar(obj, Control.PRESET_TOP_LEFT, 14, 12)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	obj_titulo = rotulo("PRÓXIMA MISSÃO", 13, COR_OURO)
	obj_texto = rotulo("", 16)
	obj_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_texto.custom_minimum_size = Vector2(340, 0)
	cronometro_lbl = rotulo("", 28)
	cronometro_lbl.visible = false
	vb.add_child(obj_titulo)
	vb.add_child(obj_texto)
	vb.add_child(cronometro_lbl)
	obj.add_child(vb)
	raiz.add_child(obj)

	# canto superior direito
	var canto := VBoxContainer.new()
	canto.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	canto.offset_left = -14
	canto.offset_right = -14
	canto.offset_top = 10
	canto.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	canto.add_theme_constant_override("separation", 6)
	canto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dinheiro_lbl = rotulo("R$ 0", 32, Color("#8ee07a"), true)
	dinheiro_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
	estrelas_ctl = Control.new()
	estrelas_ctl.custom_minimum_size = Vector2(4 * 34, 32)
	estrelas_ctl.size_flags_horizontal = Control.SIZE_SHRINK_END
	estrelas_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	estrelas_ctl.draw.connect(_desenhar_estrelas)
	var ficha := HBoxContainer.new()
	ficha.size_flags_horizontal = Control.SIZE_SHRINK_END
	ficha.add_theme_constant_override("separation", 6)
	ficha.add_child(rotulo("FICHA", 12, COR_SUAVE, true))
	chip_carro = _chip("CARRO")
	chip_roupa = _chip("ROUPA")
	ficha.add_child(chip_carro)
	ficha.add_child(chip_roupa)
	aviso_busca = painel()
	aviso_busca.size_flags_horizontal = Control.SIZE_SHRINK_END
	aviso_busca_lbl = rotulo("", 15)
	aviso_busca.add_child(aviso_busca_lbl)
	aviso_busca.visible = false
	canto.add_child(dinheiro_lbl)
	canto.add_child(estrelas_ctl)
	canto.add_child(ficha)
	canto.add_child(aviso_busca)
	raiz.add_child(canto)

	# minimapa (canto inferior esquerdo)
	mini = Control.new()
	mini.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mini.offset_left = 14
	mini.offset_right = 14 + 250
	mini.offset_top = -26 - 180
	mini.offset_bottom = -26
	mini.clip_contents = true
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.draw.connect(_desenhar_mini)
	raiz.add_child(mini)
	# barras de vida (verde) e colete (azul) embaixo do minimapa
	for i in 2:
		var fundo_b := ColorRect.new()
		fundo_b.color = Color(0, 0, 0, 0.55)
		fundo_b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		fundo_b.offset_left = 14 + i * 126
		fundo_b.offset_right = 14 + i * 126 + 124
		fundo_b.offset_top = -21
		fundo_b.offset_bottom = -14
		fundo_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var barra := ColorRect.new()
		barra.color = Color("#5ec26a") if i == 0 else Color("#4aa3ff")
		barra.size = Vector2(124, 7)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fundo_b.add_child(barra)
		raiz.add_child(fundo_b)
		if i == 0:
			barra_vida = barra
		else:
			barra_colete = barra
	distrito_lbl = rotulo("", 26, COR_TEXTO, true)
	_ancorar(distrito_lbl, Control.PRESET_BOTTOM_LEFT, 280, -56)
	distrito_lbl.modulate.a = 0.0
	raiz.add_child(distrito_lbl)

	# velocimetro (canto inferior direito)
	velo = painel()
	velo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	velo.offset_left = -14
	velo.offset_right = -14
	velo.offset_top = -14
	velo.offset_bottom = -14
	velo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	velo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var vv := VBoxContainer.new()
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_END
	velo_num = rotulo("0", 46)
	linha.add_child(velo_num)
	linha.add_child(rotulo(" KM/H", 14, COR_SUAVE))
	vv.add_child(linha)
	vv.add_child(rotulo("LATARIA", 12, COR_SUAVE))
	var fundo := ColorRect.new()
	fundo.color = Color(1, 1, 1, 0.12)
	fundo.custom_minimum_size = Vector2(150, 6)
	lataria_fill = ColorRect.new()
	lataria_fill.color = Color("#8ee07a")
	lataria_fill.size = Vector2(150, 6)
	fundo.add_child(lataria_fill)
	vv.add_child(fundo)
	velo.add_child(vv)
	velo.visible = false
	raiz.add_child(velo)

	# arma (a pe, no lugar do velocimetro)
	arma_painel = painel()
	arma_painel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	arma_painel.offset_left = -14
	arma_painel.offset_right = -14
	arma_painel.offset_top = -14
	arma_painel.offset_bottom = -14
	arma_painel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	arma_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	arma_lbl = rotulo("", 20)
	arma_painel.add_child(arma_lbl)
	raiz.add_child(arma_painel)

	# mira no centro da tela
	mira_ctl = Control.new()
	mira_ctl.set_anchors_preset(Control.PRESET_CENTER)
	mira_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mira_ctl.draw.connect(_desenhar_mira)
	raiz.add_child(mira_ctl)

	# clarao vermelho ao levar dano
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.85, 0.05, 0.05, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(flash)

	# mensagens (topo, centro)
	msgs = VBoxContainer.new()
	msgs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msgs.offset_left = -270
	msgs.offset_right = 270
	msgs.offset_top = 14
	msgs.alignment = BoxContainer.ALIGNMENT_BEGIN
	msgs.add_theme_constant_override("separation", 6)
	msgs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(msgs)

	# avisos centrais
	ligacao = painel()
	ligacao.add_theme_stylebox_override("panel", estilo(COR_PAINEL, 10, Color(1, 0.8, 0.2, 0.6)))
	ligacao_lbl = rotulo("", 20, COR_OURO)
	ligacao.add_child(ligacao_lbl)
	_centralizar(ligacao, 0.34)
	ligacao.visible = false
	raiz.add_child(ligacao)
	prisao = painel()
	prisao.add_theme_stylebox_override("panel", estilo(COR_PAINEL, 10, COR_VERM))
	var pv := VBoxContainer.new()
	pv.add_child(rotulo("Sendo preso… pare de resistir ou fuja!", 18))
	var pf := ColorRect.new()
	pf.color = Color(1, 1, 1, 0.12)
	pf.custom_minimum_size = Vector2(280, 6)
	prisao_fill = ColorRect.new()
	prisao_fill.color = COR_VERM
	prisao_fill.size = Vector2(0, 6)
	pf.add_child(prisao_fill)
	pv.add_child(pf)
	prisao.add_child(pv)
	_centralizar(prisao, 0.42)
	prisao.visible = false
	raiz.add_child(prisao)

	banner_box = VBoxContainer.new()
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_tit = rotulo("", 52, COR_OURO, true)
	banner_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = rotulo("", 19, COR_TEXTO, true)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.custom_minimum_size = Vector2(620, 0)
	banner_box.add_child(banner_tit)
	banner_box.add_child(banner_sub)
	_centralizar(banner_box, 0.2)
	banner_box.visible = false
	raiz.add_child(banner_box)

	prompt = painel()
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -34 - 40
	prompt.offset_bottom = -34
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_lbl = rotulo("", 19)
	prompt.add_child(prompt_lbl)
	prompt.visible = false
	raiz.add_child(prompt)

	# mapa grande
	mapa_grande = Control.new()
	mapa_grande.set_anchors_preset(Control.PRESET_FULL_RECT)
	mapa_grande.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo_mapa := ColorRect.new()
	fundo_mapa.color = Color(0.063, 0.086, 0.114, 0.94)
	fundo_mapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa_grande.add_child(fundo_mapa)
	mapa_canvas = Control.new()
	mapa_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	mapa_canvas.offset_left = 20
	mapa_canvas.offset_right = -20
	mapa_canvas.offset_top = 56
	mapa_canvas.offset_bottom = -20
	mapa_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa_canvas.draw.connect(_desenhar_grande)
	mapa_grande.add_child(mapa_canvas)
	var cab := HBoxContainer.new()
	_ancorar(cab, Control.PRESET_TOP_LEFT, 20, 14)
	cab.add_theme_constant_override("separation", 18)
	cab.add_child(rotulo("PORTO BRASA", 24))
	for item in [["Você", COR_BRASA], ["Nova missão", COR_OURO], ["Objetivo", COR_MAR], ["Casa segura", Color("#7fd1ff")], ["Oficina de pintura", Color("#ffb057")], ["Área de busca", COR_VERM], ["Mercado", COR_LOJA], ["Arsenal", COR_ARSENAL], ["Destino", COR_ROXO]]:
		cab.add_child(rotulo("●  " + item[0], 15, item[1]))
	cab.add_child(rotulo("M fecha", 15, COR_SUAVE))
	mapa_grande.add_child(cab)
	mapa_grande.visible = false
	raiz.add_child(mapa_grande)


func _centralizar(c: Control, y_rel: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = y_rel
	c.anchor_bottom = y_rel
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _chip(texto: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := estilo(COR_PAINEL, 12)
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.content_margin_left = 10
	s.content_margin_right = 10
	p.add_theme_stylebox_override("panel", s)
	var l := rotulo(texto, 14, Color(1, 1, 1, 0.35))
	p.add_child(l)
	p.set_meta("estilo", s)
	p.set_meta("rotulo", l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _estado_chip(p: PanelContainer, estado: String) -> void:
	var s: StyleBoxFlat = p.get_meta("estilo")
	var l: Label = p.get_meta("rotulo")
	match estado:
		"perigo":
			var pulso := 0.5 + 0.5 * sin(jogo.tempo * 7.0)
			s.bg_color = Color("#b3121f").lerp(Color("#5a0910"), pulso)
			s.border_color = COR_VERM
			l.add_theme_color_override("font_color", Color.WHITE)
		"conhecido":
			s.bg_color = COR_PAINEL
			s.border_color = Color(1, 0.8, 0.2, 0.5)
			l.add_theme_color_override("font_color", COR_OURO)
		_:
			s.bg_color = COR_PAINEL
			s.border_color = Color(1, 1, 1, 0.14)
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))


# ------------------------------------------------------------------ mapa base
func _desenhar_base() -> ImageTexture:
	var mapa = jogo.mapa
	var tam := ((MUNDO_MAX - MUNDO_MIN) * ESCALA).ceil()
	var img := Image.create(int(tam.x), int(tam.y), false, Image.FORMAT_RGBA8)
	img.fill(Color("#3d4636"))
	var px := func(x: float) -> int: return int((x - MUNDO_MIN.x) * ESCALA)
	var pz := func(z: float) -> int: return int((z - MUNDO_MIN.y) * ESCALA)
	var ret := func(x0: float, z0: float, x1: float, z1: float) -> Rect2i: return Rect2i(px.call(x0), pz.call(z0), px.call(x1) - px.call(x0), pz.call(z1) - pz.call(z0))
	img.fill_rect(ret.call(Mapa.BORDA, MUNDO_MIN.y, Mapa.BORDA + 46.0, MUNDO_MAX.y), Color("#c9b27c"))
	img.fill_rect(ret.call(Mapa.BORDA + 46.0, MUNDO_MIN.y, MUNDO_MAX.x, MUNDO_MAX.y), Color("#1f6f86"))
	var b0 := Mapa.nodo_x(0) - 6.0
	var b1 := Mapa.nodo_x(Mapa.N - 1) + 6.0
	img.fill_rect(ret.call(b0, b0, b1, b1), Color("#d9d4c7"))
	for b in mapa.blocos:
		var c: Vector2 = b["c"]
		img.fill_rect(ret.call(c.x - 30.0, c.y - 30.0, c.x + 30.0, c.y + 30.0), Color(Mapa.DISTRITOS[b["distrito"]]["mapa"]))
	for k in mapa.caixas:
		if k.tipo == "predio":
			img.fill_rect(ret.call(k.min_x, k.min_z, k.max_x, k.max_z), Color("#2a2f36"))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ API
func mensagem(texto: String, seg: float = 2.5) -> void:
	historico.append(texto)
	var p := painel()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := rotulo(texto, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(minf(texto.length() * 8.5, 500.0), 0)
	p.add_child(l)
	msgs.add_child(p)
	while msgs.get_child_count() > 3:
		var velho := msgs.get_child(0)
		msgs.remove_child(velho)
		velho.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(seg)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func dica(texto: String) -> void:
	var agora: float = jogo.tempo
	if texto == _ultima_dica and agora - _t_dica < 4.0:
		return
	_ultima_dica = texto
	_t_dica = agora
	mensagem(texto, 2.5)


func banner(titulo: String, sub: String, seg: float = 3.0) -> void:
	historico.append("[BANNER] %s | %s" % [titulo, sub])
	banner_tit.text = titulo
	banner_sub.text = sub
	banner_box.modulate.a = 1.0
	banner_box.visible = true
	t_banner = seg


func cronometro(seg: float) -> void:
	if seg < 0.0:
		cronometro_lbl.visible = false
		return
	cronometro_lbl.visible = true
	var s := int(ceil(maxf(0.0, seg)))
	cronometro_lbl.text = "%d:%02d" % [s / 60, s % 60]
	cronometro_lbl.add_theme_color_override("font_color", COR_VERM if s <= 15 else COR_TEXTO)


func dano() -> void:
	flash.color.a = 0.35
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5)


func _desenhar_mira() -> void:
	var c := Color(1, 1, 1, 0.9)
	var mirando: bool = jogo.armas.mirando
	var abre := 4.0 if mirando else 9.0
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		mira_ctl.draw_line(d * abre, d * (abre + 7.0), Color(0, 0, 0, 0.6), 4.0)
		mira_ctl.draw_line(d * abre, d * (abre + 7.0), c, 2.0)
	mira_ctl.draw_circle(Vector2.ZERO, 1.6, c)


func alternar_mapa() -> void:
	mapa_grande.visible = not mapa_grande.visible


# ------------------------------------------------------------------ quadro a quadro
func atualizar(dt: float) -> void:
	var jj = jogo.jogador
	var p = jogo.policia
	var pos: Vector2 = jj.posicao()

	estrelas_ctl.queue_redraw()
	aviso_busca.visible = p.modo == "busca"
	if p.modo == "busca" and p.zona != null:
		var fora: bool = pos.distance_to(p.zona["c"]) > p.zona["r"]
		aviso_busca_lbl.text = ("Fora da área de busca: %d s para despistar" % maxi(0, ceili(5.0 + 2.0 * p.estrelas - p.fora_tempo))) if fora else "Procurando você: saia do círculo no mapa"

	var carro_atual: bool = jj.veiculo != null and p.ficha["carro"] == jj.veiculo
	var roupa_atual: bool = jj.veiculo == null and p.ficha["roupa"] == jj.roupa_id
	_estado_chip(chip_carro, ("perigo" if carro_atual else "conhecido") if p.ficha_carro() else "limpo")
	_estado_chip(chip_roupa, ("perigo" if roupa_atual else "conhecido") if p.ficha_roupa() else "limpo")

	dinheiro_lbl.text = U.dinheiro(jogo.dinheiro)
	var o: Array = jogo.missoes.texto_objetivo()
	obj_titulo.text = String(o[0]).to_upper()
	obj_texto.text = o[1]

	if jj.veiculo != null:
		velo.visible = true
		velo_num.text = str(int(round(jj.veiculo.velocidade() * 3.6)))
		var vida: float = jj.veiculo.vida
		lataria_fill.size.x = 150.0 * vida / 100.0
		lataria_fill.color = COR_VERM if vida < 35.0 else (COR_OURO if vida < 65.0 else Color("#8ee07a"))
	else:
		velo.visible = false

	barra_vida.size.x = 124.0 * jj.vida / 100.0
	barra_colete.size.x = 124.0 * jj.colete / 100.0
	var a_pe: bool = jj.veiculo == null
	var armas = jogo.armas
	arma_painel.visible = a_pe
	if a_pe:
		var t: Dictionary = Armas.TIPOS[armas.atual]
		arma_lbl.text = t["nome"].to_upper() + ("" if armas.atual == "punho" else "   %d" % armas.municao())
	mira_ctl.visible = a_pe and (armas.armado() or armas.mirando) and jogo.ui_aberta == ""
	if mira_ctl.visible:
		mira_ctl.queue_redraw()

	prisao.visible = p.prendendo > 0.05
	prisao_fill.size.x = minf(1.0, p.prendendo / p.limite_prisao()) * 280.0

	var lig = null
	for pd in jogo.pedestres.lista:
		if pd.estado == "ligando":
			lig = pd
			break
	ligacao.visible = lig != null
	if lig != null:
		ligacao_lbl.text = "Testemunha ligando para a polícia… %d s" % ceili(lig.timer)

	prompt.visible = jogo.prompt_atual != ""
	prompt_lbl.text = jogo.prompt_atual

	var d: String = jogo.mapa.distrito(pos)
	if d != "" and d != distrito_atual:
		distrito_atual = d
		distrito_lbl.text = Mapa.DISTRITOS[d]["nome"]
		var tw := distrito_lbl.create_tween()
		tw.tween_property(distrito_lbl, "modulate:a", 1.0, 0.3)
		tw.tween_interval(2.2)
		tw.tween_property(distrito_lbl, "modulate:a", 0.0, 0.6)

	if t_banner > 0.0:
		t_banner -= dt
		if t_banner <= 0.0:
			var tw2 := banner_box.create_tween()
			tw2.tween_property(banner_box, "modulate:a", 0.0, 0.4)
			tw2.tween_callback(func(): banner_box.visible = t_banner > 0.0)

	mini.queue_redraw()
	if mapa_grande.visible:
		mapa_canvas.queue_redraw()


# ------------------------------------------------------------------ desenho
func _estrela(c: Vector2, r1: float, r2: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := r1 if i % 2 == 0 else r2
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _desenhar_estrelas() -> void:
	var p = jogo.policia
	var pisca: bool = p.modo == "perseguicao" and int(jogo.tempo * 4.0) % 2 == 0
	for i in 4:
		var c := Vector2(17 + i * 34, 16)
		var pts := _estrela(c, 14.0, 6.0)
		var ativa: bool = i < p.estrelas
		var cor := Color(1, 1, 1, 0.12)
		if ativa:
			if p.modo == "perseguicao":
				cor = COR_AZUL if pisca else COR_VERM
			elif p.modo == "busca":
				cor = Color("#8d96a0")
			else:
				cor = COR_TEXTO
		estrelas_ctl.draw_colored_polygon(pts, cor)
		var contorno := pts.duplicate()
		contorno.append(pts[0])
		estrelas_ctl.draw_polyline(contorno, Color(0, 0, 0, 0.8) if ativa else Color(1, 1, 1, 0.45), 1.5, true)


func _sobrepor(ctl: Control, conv: Callable, s: float, raio_px: float) -> void:
	var jj = jogo.jogador
	var p = jogo.policia
	var pos: Vector2 = jj.posicao()
	var alterna := int(jogo.tempo * 2.0) % 2 == 0
	if p.zona != null and p.modo == "busca":
		var c: Vector2 = conv.call(p.zona["c"])
		var r: float = p.zona["r"] * s
		ctl.draw_circle(c, r, Color(1, 0.16, 0.23, 0.18) if alterna else Color(0.18, 0.42, 1, 0.18))
		ctl.draw_arc(c, r, 0, TAU, 64, COR_VERM if alterna else COR_AZUL, 2.0, true)
	var alvo = jogo.missoes.alvo_atual()
	if alvo != null:
		var cor := COR_OURO if alvo["inicio"] else COR_MAR
		var pts := PackedVector2Array()
		for q in jogo.mapa.rota_gps(pos, alvo["p"]):
			pts.append(conv.call(q))
		ctl.draw_polyline(pts, cor, maxf(3.0, 4.0 * s), true)
		var pa: Vector2 = conv.call(alvo["p"])
		ctl.draw_circle(pa, maxf(5.0, 6.0 * s) + 2.0, Color("#10161d"))
		ctl.draw_circle(pa, maxf(5.0, 6.0 * s), cor)
	if jogo.destino != null:
		var pts2 := PackedVector2Array()
		for q in jogo.mapa.rota_gps(pos, jogo.destino):
			pts2.append(conv.call(q))
		ctl.draw_polyline(pts2, COR_ROXO, maxf(3.0, 4.0 * s), true)
		ctl.draw_circle(conv.call(jogo.destino), maxf(5.0, 6.0 * s), COR_ROXO)
	var poi: Dictionary = jogo.mapa.poi
	var icones := [[poi["casa"]["p"], "C", Color("#7fd1ff")], [poi["oficina"]["p"], "P", Color("#ffb057")], [poi["arsenal"]["p"], "A", COR_ARSENAL]]
	for l in jogo.mapa.lojas:
		icones.append([l["p"], "M", COR_LOJA])
	for item in icones:
		var q: Vector2 = conv.call(item[0])
		ctl.draw_circle(q, raio_px, item[2])
		ctl.draw_string(fonte, q + Vector2(-raio_px, raio_px * 0.45), item[1], HORIZONTAL_ALIGNMENT_CENTER, raio_px * 2.0, int(raio_px * 1.4), Color("#10161d"))
	# viaturas so aparecem se estiverem perto (sem radar de policia)
	for v in jogo.veiculos:
		if not v.policia or v.ia == null or v.ia["tipo"] == "trafego":
			continue
		if v.pos.distance_to(pos) > 45.0:
			continue
		var q: Vector2 = conv.call(v.pos)
		ctl.draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), COR_VERM if int(jogo.tempo * 6.0) % 2 == 0 else COR_AZUL)
	var c2: Vector2 = conv.call(pos)
	var seta := PackedVector2Array()
	for v in [Vector2(0, -9), Vector2(6, 7), Vector2(0, 3), Vector2(-6, 7)]:
		seta.append(c2 + v.rotated(-jj.heading()))
	ctl.draw_colored_polygon(seta, COR_BRASA)
	var contorno := seta.duplicate()
	contorno.append(seta[0])
	ctl.draw_polyline(contorno, Color.WHITE, 2.0, true)


func _desenhar_mini() -> void:
	var tam := mini.size
	var pos: Vector2 = jogo.jogador.posicao()
	var alcance := 110.0 if jogo.jogador.veiculo else 70.0
	var s := tam.x / 2.0 / alcance
	var meia := tam / 2.0 / s
	mini.draw_rect(Rect2(Vector2.ZERO, tam), Color("#3d4636"))
	mini.draw_texture_rect_region(base_tex, Rect2(Vector2.ZERO, tam), Rect2((pos - meia - MUNDO_MIN) * ESCALA, meia * 2.0 * ESCALA))
	var conv := func(w: Vector2) -> Vector2: return (w - pos) * s + tam / 2.0
	_sobrepor(mini, conv, s, 8.0)
	mini.draw_rect(Rect2(Vector2.ONE, tam - Vector2(2, 2)), Color(1, 1, 1, 0.85), false, 2.0)
	mini.draw_string(fonte, Vector2(tam.x / 2.0 - 5.0, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COR_TEXTO)


func _desenhar_grande() -> void:
	var tam := mapa_canvas.size
	var mn := Vector2(-230, -230)
	var mx := Vector2(260, 230)
	var s := minf(tam.x / (mx.x - mn.x), tam.y / (mx.y - mn.y))
	var origem := (tam - (mx - mn) * s) / 2.0
	mapa_canvas.draw_texture_rect_region(base_tex, Rect2(origem, (mx - mn) * s), Rect2((mn - MUNDO_MIN) * ESCALA, (mx - mn) * ESCALA))
	var conv := func(w: Vector2) -> Vector2: return origem + (w - mn) * s
	_sobrepor(mapa_canvas, conv, s, 9.0)
	for item in [["CENTRO", Vector2(0, -72)], ["ORLA", Vector2(144, -144)], ["PORTO", Vector2(-144, 0)], ["SUBÚRBIO", Vector2(36, 144)]]:
		var q: Vector2 = conv.call(item[1])
		mapa_canvas.draw_string(fonte, q - Vector2(60, 0), item[0], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 1, 1, 0.9))
