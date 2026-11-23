class_name Celular
extends CanvasLayer
## Celular (Tab): contatos (taxi, mecanico, advogado, contato das missoes),
## mensagens, GPS com destino e carteira. O mundo continua rodando.

const COR_TELA := Color("#121a22")
const COR_TEXTO := Color("#f6efe3")
const COR_SUAVE := Color("#9aa4ae")
const COR_OURO := Color("#ffcc33")
const COR_BRASA := Color("#ff6a2b")
const COR_ROXO := Color("#b07cff")
const PRECO_TAXI := 40
const PRECO_MECANICO := 100
const PRECO_FICHA := 300
const PRECO_ESTRELA := 800

var jogo
var raiz: Control
var titulo: Label
var relogio: Label
var conteudo: VBoxContainer
var status: Label
var pagina := "inicio"


func _init(p_jogo) -> void:
	jogo = p_jogo
	layer = 14


func _ready() -> void:
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	raiz.offset_left = -340
	raiz.offset_top = -560
	raiz.offset_right = -24
	raiz.offset_bottom = -20
	var corpo := PanelContainer.new()
	corpo.set_anchors_preset(Control.PRESET_FULL_RECT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#05080b")
	s.set_corner_radius_all(30)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	corpo.add_theme_stylebox_override("panel", s)
	raiz.add_child(corpo)
	var tela := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = COR_TELA
	st.set_corner_radius_all(20)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 12
	tela.add_theme_stylebox_override("panel", st)
	corpo.add_child(tela)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	tela.add_child(vb)
	var barra := HBoxContainer.new()
	relogio = _rotulo("", 13, COR_SUAVE)
	relogio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(relogio)
	barra.add_child(_rotulo("BrasaNet  ▂▄▆", 13, COR_SUAVE))
	vb.add_child(barra)
	titulo = _rotulo("", 24, COR_TEXTO)
	vb.add_child(titulo)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conteudo = VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation", 6)
	rolagem.add_child(conteudo)
	vb.add_child(rolagem)
	status = _rotulo("", 14, COR_OURO)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(status)
	vb.add_child(_rotulo("Tab fecha · Esc volta", 12, COR_SUAVE))
	add_child(raiz)
	raiz.visible = false


func _rotulo(t: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	return l


func _botao(texto: String, acao: Callable, cor: Color = COR_TEXTO) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 16)
	for estado in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(10)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 9
		s.content_margin_bottom = 9
		s.bg_color = Color(1, 1, 1, 0.13) if estado in ["hover", "focus"] else Color(1, 1, 1, 0.05)
		if estado == "focus":
			s.set_border_width_all(2)
			s.border_color = COR_OURO
		b.add_theme_stylebox_override(estado, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, cor)
	b.pressed.connect(acao)
	conteudo.add_child(b)
	return b


func aberto() -> bool:
	return raiz.visible


func alternar() -> void:
	if raiz.visible:
		fechar()
	else:
		abrir()


func abrir() -> void:
	raiz.visible = true
	status.text = ""
	jogo.abrir_ui("celular")
	ir("inicio")


func fechar() -> void:
	raiz.visible = false
	jogo.fechar_ui()


func voltar() -> void:
	if pagina == "inicio":
		fechar()
	elif pagina == "taxi":
		ir("contatos")
	else:
		ir("inicio")


func _process(_delta: float) -> void:
	if raiz.visible:
		var minutos := int(jogo.tempo * 2.0) % (24 * 60)
		relogio.text = "%02d:%02d" % [(minutos / 60 + 8) % 24, minutos % 60]


func ir(p: String) -> void:
	pagina = p
	for c in conteudo.get_children():
		c.queue_free()
	var primeiro: Button = null
	match p:
		"inicio":
			titulo.text = "Porto Brasa"
			var novas := 0
			for m in jogo.mensagens:
				if not m["lida"]:
					novas += 1
			primeiro = _botao("Contatos", ir.bind("contatos"))
			_botao("Mensagens" + (" (%d novas)" % novas if novas > 0 else ""), ir.bind("mensagens"))
			_botao("GPS", ir.bind("gps"))
			_botao("Carteira", ir.bind("carteira"))
		"contatos":
			titulo.text = "Contatos"
			primeiro = _botao("Rui (trabalhos)\nPedir o próximo trabalho", pedir_trabalho)
			_botao("Táxi Brasa\nLeva você a pé pela cidade · R$ %d" % PRECO_TAXI, ir.bind("taxi"))
			_botao("Mecânico Zé\nTraz seu carro consertado · R$ %d" % PRECO_MECANICO, mecanico)
			_botao("Dr. Brito, advogado\nLimpa a Ficha (R$ %d) ou baixa 1 estrela na busca (R$ %d)" % [PRECO_FICHA, PRECO_ESTRELA], advogado)
			_botao("← Voltar", voltar, COR_SUAVE)
		"taxi":
			titulo.text = "Táxi Brasa"
			for nome in _lugares():
				var b := _botao(nome, taxi.bind(nome))
				if primeiro == null:
					primeiro = b
			_botao("← Voltar", voltar, COR_SUAVE)
		"mensagens":
			titulo.text = "Mensagens"
			if jogo.mensagens.is_empty():
				conteudo.add_child(_rotulo("Nenhuma mensagem.", 15, COR_SUAVE))
			for i in range(jogo.mensagens.size() - 1, -1, -1):
				var m: Dictionary = jogo.mensagens[i]
				var l := _rotulo("%s%s\n%s" % ["● " if not m["lida"] else "", m["de"], m["texto"]], 15, COR_TEXTO)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(250, 0)
				conteudo.add_child(l)
				conteudo.add_child(HSeparator.new())
				m["lida"] = true
			primeiro = _botao("← Voltar", voltar, COR_SUAVE)
		"gps":
			titulo.text = "GPS"
			for nome in _lugares():
				var b := _botao(nome, marcar.bind(nome))
				if primeiro == null:
					primeiro = b
			_botao("Mercado mais próximo", marcar.bind("Mercado mais próximo"))
			if jogo.destino != null:
				_botao("Remover destino", marcar.bind(""), COR_SUAVE)
			_botao("← Voltar", voltar, COR_SUAVE)
		"carteira":
			titulo.text = "Carteira"
			var jj = jogo.jogador
			var linhas := [
				"Dinheiro: %s" % U.dinheiro(jogo.dinheiro),
				"Vida: %d/100   Colete: %d/100" % [int(jj.vida), int(jj.colete)],
				"Missões feitas: %d de %d" % [jogo.missoes.feitas, jogo.missoes.lista.size()],
				"Prisões: %d   Hospital: %d" % [jogo.estat["prisoes"], jogo.estat["mortes"]],
				"",
				"Armas:",
			]
			for arma in Armas.ORDEM:
				if arma != "punho" and jogo.armas.tem(arma):
					linhas.append("  %s · %d balas" % [Armas.TIPOS[arma]["nome"], jogo.armas.inventario[arma]])
			if linhas[-1] == "Armas:":
				linhas.append("  nenhuma (compre no Arsenal do Porto)")
			for t in linhas:
				conteudo.add_child(_rotulo(t, 15, COR_TEXTO))
			primeiro = _botao("← Voltar", voltar, COR_SUAVE)
	if primeiro:
		primeiro.call_deferred("grab_focus")


func _lugares() -> Dictionary:
	var poi: Dictionary = jogo.mapa.poi
	return {
		"Casa Segura": poi["casa"]["p"],
		"Mercado da Orla": poi["loja"]["p"] + Vector2(0, 3),
		"Arsenal do Porto": poi["arsenal"]["p"],
		"Oficina de Pintura": poi["oficina"]["p"],
		"Torre Brasa (Centro)": poi["torre"]["p"],
		"Praça do Centro": poi["praca"]["p"],
	}


func _status(t: String) -> String:
	status.text = t
	return t


# ------------------------------------------------------------------ acoes (tambem usadas pelos testes)
func pedir_trabalho() -> String:
	var m = jogo.missoes.disponivel()
	if jogo.missoes.ativa != null:
		return _status("Rui: \"Termina o que você começou: %s.\"" % jogo.missoes.ativa["nome"])
	if m == null:
		return _status("Rui: \"Por enquanto é só. Aproveita a cidade.\"")
	jogo.destino = m["inicio"]
	return _status("Rui: \"Tem serviço: %s. Marquei no seu GPS.\"" % m["nome"])


func marcar(nome: String) -> String:
	if nome == "":
		jogo.destino = null
		ir("gps")
		return _status("Destino removido.")
	if nome == "Mercado mais próximo":
		var p: Vector2 = jogo.jogador.posicao()
		var melhor = null
		for l in jogo.mapa.lojas:
			if melhor == null or l["p"].distance_to(p) < melhor.distance_to(p):
				melhor = l["p"]
		jogo.destino = melhor
	else:
		jogo.destino = _lugares()[nome]
	fechar()
	jogo.hud.mensagem("Destino marcado no GPS: %s." % nome, 2.5)
	return "ok"


func taxi(nome: String) -> String:
	if jogo.policia.estrelas > 0:
		return _status("O taxista não pega quem está sendo procurado.")
	if jogo.jogador.veiculo != null:
		return _status("Saia do carro para pegar o táxi.")
	if jogo.dinheiro < PRECO_TAXI:
		return _status("Dinheiro insuficiente.")
	jogo.dinheiro -= PRECO_TAXI
	var destino: Vector2 = _lugares()[nome]
	fechar()
	jogo.viajar(destino, "Táxi: você chegou em %s." % nome)
	return "ok"


func mecanico() -> String:
	if jogo.dinheiro < PRECO_MECANICO:
		return _status("Dinheiro insuficiente.")
	var antigo = null
	for v in jogo.veiculos:
		if v.do_jogador and not v.missao and v != jogo.jogador.veiculo:
			antigo = v
	var cor: Color = Color("#2f6db5") if antigo == null else antigo.cor
	if antigo != null:
		antigo.remover()
	var p: Vector2 = jogo.jogador.posicao()
	var n: Vector2i = jogo.mapa.nodo_mais_proximo(p)
	var melhor := Vector2.ZERO
	var h := 0.0
	var md := INF
	for viz in jogo.mapa.vizinhos(n):
		var f := Trafego.faixa(n, viz)
		for k in [0.2, 0.5, 0.8]:
			var q: Vector2 = f["ini"] + f["d"] * f["L"] * k
			var d := q.distance_to(p)
			if d > 8.0 and d < md:
				md = d
				melhor = q
				h = U.heading_de(f["d"])
	var v := Veiculo.new(jogo, "sedan", melhor.x, melhor.y, h, cor)
	v.do_jogador = true
	v.fixo = true
	jogo.dinheiro -= PRECO_MECANICO
	jogo.destino = melhor
	jogo.audio.tocar("compra")
	return _status("Zé: \"Deixei seu carro consertado na rua. Tá no GPS.\"")


func advogado() -> String:
	var p = jogo.policia
	if p.modo == "perseguicao":
		return _status("Dr. Brito: \"Com a polícia na sua cola não dá. Despiste primeiro.\"")
	if p.estrelas > 0:
		if jogo.dinheiro < PRECO_ESTRELA:
			return _status("Dr. Brito: \"Isso custa R$ %d.\"" % PRECO_ESTRELA)
		jogo.dinheiro -= PRECO_ESTRELA
		p.estrelas -= 1
		if p.estrelas == 0:
			p.escapou()
		return _status("Dr. Brito: \"Mexi uns pauzinhos. Uma estrela a menos.\"")
	if p.ficha_carro() or p.ficha_roupa():
		if jogo.dinheiro < PRECO_FICHA:
			return _status("Dr. Brito: \"Isso custa R$ %d.\"" % PRECO_FICHA)
		jogo.dinheiro -= PRECO_FICHA
		p.limpar_ficha("tudo")
		return _status("Dr. Brito: \"Sua Ficha está limpa.\"")
	return _status("Dr. Brito: \"Você está limpo. Me ligue se precisar.\"")
