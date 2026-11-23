class_name Interface
extends CanvasLayer
## Tela inicial (com carregamento) e menu de pausa.

signal jogar
signal continuar
signal recomecar
signal alternar_som
signal alternar_graficos
signal sair

const COR_NOITE := Color("#10161d")
const COR_TEXTO := Color("#f6efe3")
const COR_SUAVE := Color("#b9c0c7")
const COR_BRASA := Color("#ff6a2b")
const COR_OURO := Color("#ffcc33")

var inicio: Control
var pausa: Control
var carga_lbl: Label
var carga_fill: ColorRect
var botao_jogar: Button
var botao_som: Button
var botao_graficos: Button
var fonte_titulo: SystemFont


func _ready() -> void:
	layer = 20
	fonte_titulo = SystemFont.new()
	fonte_titulo.font_names = PackedStringArray(["Bungee", "Impact", "Arial Black", "Franklin Gothic Heavy", "DejaVu Sans"])
	fonte_titulo.font_weight = 900
	inicio = _tela()
	_montar_inicio()
	pausa = _tela()
	_montar_pausa()
	pausa.visible = false


func _tela() -> Control:
	var t := Control.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(COR_NOITE, 0.35))
	grad.set_color(1, Color(COR_NOITE, 0.95))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	fundo.texture = gt
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	t.add_child(fundo)
	add_child(t)
	return t


func _rotulo(texto: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	return l


func _titulo(texto: String, tam: int, cor: Color, sombra: Color) -> Label:
	var l := _rotulo(texto, tam, cor)
	l.add_theme_font_override("font", fonte_titulo)
	l.add_theme_color_override("font_shadow_color", sombra)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 5)
	return l


func _botao(texto: String, principal: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", 20 if principal else 16)
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(10)
		s.content_margin_left = 28
		s.content_margin_right = 28
		s.content_margin_top = 12
		s.content_margin_bottom = 12
		if principal:
			s.bg_color = COR_BRASA.lightened(0.12) if estado == "hover" else (COR_BRASA.darkened(0.15) if estado == "pressed" else COR_BRASA)
			if estado == "disabled":
				s.bg_color = Color("#5d646c")
			s.shadow_color = Color("#9a3510")
			s.shadow_offset = Vector2(0, 4)
		else:
			s.bg_color = Color(1, 1, 1, 0.12) if estado == "hover" else Color(1, 1, 1, 0.04)
			s.set_border_width_all(2)
			s.border_color = Color(1, 1, 1, 0.18)
		if estado == "focus":
			s.set_border_width_all(3)
			s.border_color = COR_OURO
		b.add_theme_stylebox_override(estado, s)
	var cor_txt := COR_NOITE if principal else COR_TEXTO
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, cor_txt)
	b.add_theme_color_override("font_disabled_color", COR_TEXTO)
	return b


func _coluna(t: Control) -> VBoxContainer:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(centro)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(680, 0)
	vb.add_theme_constant_override("separation", 18)
	centro.add_child(vb)
	return vb


func _montar_inicio() -> void:
	var vb := _coluna(inicio)
	vb.add_child(_rotulo("VERSÃO 0.3 · PROTÓTIPO JOGÁVEL · GODOT", 15, COR_OURO))
	var tit := VBoxContainer.new()
	tit.add_theme_constant_override("separation", -18)
	tit.add_child(_titulo("PORTO", 92, COR_TEXTO, COR_BRASA))
	tit.add_child(_titulo("BRASA", 92, COR_BRASA, Color("#7a2a0b")))
	vb.add_child(tit)
	var desc := _rotulo("Uma cidade litorânea, três serviços e uma polícia que lembra de você. Crimes só viram estrelas se alguém vir. Troque de carro, pinte a lataria ou mude de roupa para limpar sua Ficha.", 18, COR_SUAVE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	var painel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.063, 0.086, 0.114, 0.78)
	s.set_corner_radius_all(10)
	s.set_border_width_all(1)
	s.border_color = Color(1, 1, 1, 0.14)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	painel.add_theme_stylebox_override("panel", s)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 34)
	grade.add_theme_constant_override("v_separation", 6)
	var linhas := [
		["W A S D / setas", "andar e dirigir"], ["E", "entrar, sair, roubar carro"],
		["Shift", "correr a pé"], ["Espaço", "freio de mão"],
		["Mouse", "girar a câmera"], ["M · H · Esc", "mapa · buzina · pausa"],
		["Botão direito", "mirar (com arma)"], ["Botão esquerdo", "atirar / socar"],
		["Q ou rodinha", "trocar de arma"], ["Tab", "celular"],
		["Controle", "gatilhos aceleram, Y entra, LB mira, RB atira"], ["N", "liga/desliga o som"],
	]
	if OS.has_feature("mobile") or "--toque" in OS.get_cmdline_user_args():
		linhas = [
			["Círculo à esquerda", "andar e dirigir (no fundo, corre)"], ["Arrastar à direita", "girar a câmera"],
			["E", "entrar, sair, roubar, lojas"], ["FREIO", "freio de mão (no carro)"],
			["MIRAR", "liga/desliga a mira"], ["ATIRAR", "atirar / socar"],
			["ARMA", "trocar de arma"], ["CELULAR", "contatos, GPS, táxi"],
			["MAPA · II", "mapa grande · pausa"], ["Voltar", "pausa / fecha o celular"],
		]
	for linha in linhas:
		var l := _rotulo("%s   %s" % [linha[0], linha[1]], 16, COR_TEXTO)
		grade.add_child(l)
	painel.add_child(grade)
	vb.add_child(painel)

	carga_lbl = _rotulo("Carregando…", 15, COR_SUAVE)
	vb.add_child(carga_lbl)
	var trilho := ColorRect.new()
	trilho.color = Color(1, 1, 1, 0.12)
	trilho.custom_minimum_size = Vector2(680, 6)
	carga_fill = ColorRect.new()
	carga_fill.color = COR_BRASA
	carga_fill.size = Vector2(0, 6)
	trilho.add_child(carga_fill)
	vb.add_child(trilho)
	var acoes := HBoxContainer.new()
	botao_jogar = _botao("CARREGANDO…", true)
	botao_jogar.disabled = true
	botao_jogar.pressed.connect(func(): jogar.emit())
	acoes.add_child(botao_jogar)
	vb.add_child(acoes)


func _montar_pausa() -> void:
	var vb := _coluna(pausa)
	vb.add_child(_titulo("PAUSA", 80, COR_TEXTO, COR_BRASA))
	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", 12)
	var b1 := _botao("CONTINUAR", true)
	b1.pressed.connect(func(): continuar.emit())
	botao_som = _botao("Som: ligado", false)
	botao_som.pressed.connect(func(): alternar_som.emit())
	botao_graficos = _botao("Gráficos: Alto", false)
	botao_graficos.pressed.connect(func(): alternar_graficos.emit())
	var b3 := _botao("Recomeçar missões", false)
	b3.pressed.connect(func(): recomecar.emit())
	var b4 := _botao("Sair do jogo", false)
	b4.pressed.connect(func(): sair.emit())
	for b in [b1, botao_som, botao_graficos, b3, b4]:
		acoes.add_child(b)
	vb.add_child(acoes)
	pausa.set_meta("primeiro", b1)


func progresso(fracao: float, texto: String) -> void:
	carga_fill.size.x = 680.0 * clampf(fracao, 0.0, 1.0)
	carga_lbl.text = texto


func pronto() -> void:
	progresso(1.0, "Pronto.")
	botao_jogar.disabled = false
	botao_jogar.text = "JOGAR"
	botao_jogar.grab_focus()


func mostrar_pausa(sim: bool) -> void:
	pausa.visible = sim
	if sim:
		(pausa.get_meta("primeiro") as Button).grab_focus()
