extends Node3D
## Porto Brasa: monta a cena, carrega os modelos, liga os sistemas e roda o laco do jogo.
## Este no e o "jogo" que os outros sistemas recebem.

const MODELOS := [
	"barreira", "camera_cctv", "carro_esportivo", "carro_sedan", "casa_suburbio", "cone", "conteiner",
	"galpao_porto", "helicoptero_policia", "hidrante", "lixeira", "loja", "oficina_pintura", "palmeira",
	"policial", "poste", "predio_centro", "protagonista", "rua_cruzamento", "rua_reta", "semaforo",
	"tapete_pregos", "viatura_policia",
]
const ARQUIVO_SALVO := "user://porto_brasa.cfg"

var modelos := {}
var mapa: Mapa
var jogador: Jogador
var veiculos: Array = []
var obstaculos: Array = []
var tapetes: Array = []
var pedestres: Pedestres
var trafego: Trafego
var policia: Policia
var missoes: Missoes
var hud: Hud
var interface: Interface
var audio: AudioJogo
var entrada: Entrada
var camera: CameraJogo
var armas: Armas
var celular: Celular
var loja_ui: LojaUI
var ui_aberta := ""  # "", "celular" ou "loja"
var cena_hospital := 0.0
var destino = null  # Vector2 marcado no GPS do celular
var marcador_destino: Node3D
var mensagens: Array = []  # {de, texto, lida}
var lojas_roubadas := {}  # id da loja -> tempo em que o caixa volta a ter dinheiro
var estat := {"prisoes": 0, "mortes": 0}
var toque := false  # tablet/celular
var controles_toque: ControlesToque
var sol: DirectionalLight3D
var tempo := 0.0
var dinheiro := 200.0
var pausado := true
var pronto := false
var prompt_atual := ""
var cena_prisao := 0.0
var modo_teste := ""
var _t_pintura := 0.0
var _pintou := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--teste"):
			modo_teste = a.get_slice("=", 1) if a.contains("=") else "basico"
	toque = OS.has_feature("mobile") or "--toque" in OS.get_cmdline_user_args()
	_ambiente()
	entrada = Entrada.new()
	entrada.modo_toque = toque
	add_child(entrada)
	audio = AudioJogo.new()
	add_child(audio)
	camera = CameraJogo.new()
	add_child(camera)
	camera.current = true
	camera.position = Vector3(160, 70, 0)
	camera.look_at(Vector3.ZERO)
	interface = Interface.new()
	add_child(interface)
	interface.jogar.connect(_comecar)
	interface.continuar.connect(_comecar)
	interface.recomecar.connect(func():
		missoes.recomecar()
		hud.mensagem("Missões reiniciadas.", 2.0)
		_comecar())
	interface.alternar_som.connect(_alternar_som)
	interface.sair.connect(func(): get_tree().quit())
	await _carregar()


func _ambiente() -> void:
	var adv := Visual.avancado()
	var env := Environment.new()
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color("#6f9fd0")
	mat_ceu.sky_horizon_color = Color("#d4e2ea")
	mat_ceu.ground_horizon_color = Color("#d4e2ea")
	mat_ceu.ground_bottom_color = Color("#6d6a55")
	mat_ceu.sun_angle_max = 25.0
	mat_ceu.sun_curve = 0.12
	ceu.sky_material = mat_ceu
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("#c9d9e4")
	env.fog_sky_affect = 0.1
	if adv:
		# Forward+ (Vulkan): luz do ceu, sombreamento de contato, brilho, reflexos
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.75
		env.ambient_light_energy = 0.7
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 0.95
		env.tonemap_white = 6.0
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 2.2
		env.ssao_detail = 0.6
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 1.1
		env.fog_density = 0.0014
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.06
		env.adjustment_saturation = 1.08
	else:
		# Compatibility (OpenGL): sem efeitos de tela, luz mais contida
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#b4c3d3")
		env.ambient_light_energy = 0.45
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 0.8
		env.fog_density = 0.0018
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.light_energy = 1.15 if adv else 0.78
	sol.light_color = Color("#ffe9cc")
	sol.shadow_enabled = true
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 160.0
	sol.shadow_bias = 0.04
	# borda suave sem ruido: desfoque comum (a sombra de tamanho fisico gera pontilhado)
	sol.shadow_blur = 1.6 if adv else 1.0
	sol.shadow_normal_bias = 1.4
	add_child(sol)
	# sol de fim de tarde: sombras mais longas
	sol.look_at_from_position(Vector3(85, 80, 40), Vector3.ZERO, Vector3.UP)


func _carregar() -> void:
	for i in MODELOS.size():
		var nome: String = MODELOS[i]
		modelos[nome] = load("res://modelos/%s.glb" % nome)
		interface.progresso(0.8 * (i + 1) / MODELOS.size(), "Carregando modelos… " + nome.replace("_", " "))
		await get_tree().process_frame
	interface.progresso(0.85, "Montando a cidade…")
	await get_tree().process_frame

	var salvo := ConfigFile.new()
	salvo.load(ARQUIVO_SALVO)
	dinheiro = salvo.get_value("jogo", "dinheiro", 200.0)

	mapa = Mapa.new()
	add_child(mapa)
	mapa.construir(self)
	camera.mapa = mapa
	hud = Hud.new(self)
	add_child(hud)
	var casa: Vector2 = mapa.poi["casa"]["p"]
	jogador = Jogador.new(self, casa.x, casa.y)
	jogador.vestir(salvo.get_value("jogo", "roupa", 0))
	pedestres = Pedestres.new(self)
	trafego = Trafego.new(self)
	policia = Policia.new(self)
	missoes = Missoes.new(self)
	missoes.feitas = mini(salvo.get_value("jogo", "missoes", 0), missoes.lista.size())
	armas = Armas.new(self)
	armas.preparar_modelo(jogador)
	var inv: Dictionary = salvo.get_value("jogo", "armas", {"punho": 0})
	for arma in inv:
		armas.inventario[arma] = inv[arma]
	jogador.colete = salvo.get_value("jogo", "colete", 0.0)
	celular = Celular.new(self)
	add_child(celular)
	loja_ui = LojaUI.new(self)
	add_child(loja_ui)
	marcador_destino = missoes._criar_marcador(Color("#b07cff"))
	if toque:
		hud.layout_toque()
		controles_toque = ControlesToque.new(self)
		add_child(controles_toque)
		# tablet: menos coisas na cidade e sem suavizacao de serrilhado, para rodar liso
		pedestres.max_ped = 22
		trafego.max_civis = 11
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		sol.directional_shadow_max_distance = 90.0
		sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if missoes.feitas == 0:
		nova_mensagem("Rui", "Bem-vindo de volta a Porto Brasa. Tem trabalho pra você: vai até o marcador amarelo do lado da casa. Se precisar, me chama no celular (Tab).", false)

	# carros estacionados (pegar e crime) e o carro da casa segura (e seu)
	for e in mapa.estacionados:
		var v := Veiculo.new(self, "sedan", e["p"].x, e["p"].y, e["h"], Veiculo.CORES.pick_random())
		v.fixo = true
	var meu := Veiculo.new(self, "sedan", casa.x + 6.6, casa.y - 3.0, PI / 2.0, "#2f6db5")
	meu.fixo = true
	meu.do_jogador = true
	for i in 10:
		trafego.spawnar(false)
	for i in 2:
		trafego.spawnar(true)
	for i in 26:
		pedestres.reposicionar(pedestres.criar())

	pronto = true
	interface.pronto()
	if modo_teste != "":
		var teste = load("res://testes/teste_jogo.gd").new()
		await teste.rodar(self)
		get_tree().quit()


func instanciar(nome: String) -> Node3D:
	return modelos[nome].instantiate()


func salvar() -> void:
	var c := ConfigFile.new()
	c.set_value("jogo", "dinheiro", dinheiro)
	c.set_value("jogo", "roupa", jogador.roupa_id)
	c.set_value("jogo", "missoes", missoes.feitas)
	c.set_value("jogo", "armas", armas.inventario)
	c.set_value("jogo", "colete", jogador.colete)
	c.save(ARQUIVO_SALVO)


func nova_mensagem(de: String, texto: String, avisar: bool = true) -> void:
	mensagens.append({"de": de, "texto": texto, "lida": false})
	if avisar:
		hud.mensagem("Nova mensagem de %s (Tab abre o celular)." % de, 3.0)
		audio.tocar("notificacao")


func abrir_ui(nome: String) -> void:
	if ui_aberta == "celular" and nome == "loja":
		celular.raiz.visible = false
	ui_aberta = nome
	entrada.apertadas.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func fechar_ui() -> void:
	ui_aberta = ""
	entrada.apertadas.clear()
	entrada.consumir_arraste()
	if modo_teste == "" and not pausado and not toque:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Viagem rapida (taxi): tela escura rapida e o jogador aparece no destino.
func viajar(p: Vector2, msg: String) -> void:
	hud.flash.color = Color(0, 0, 0, 1)
	var tw := hud.flash.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(hud.flash, "color:a", 0.0, 0.6)
	tw.tween_callback(func(): hud.flash.color = Color(0.85, 0.05, 0.05, 0.0))
	jogador.pos = p
	jogador.h = 0.0
	camera.yaw = 0.0
	camera.pos_suave = Vector3(p.x, 6, p.y + 6)
	hud.mensagem(msg, 2.5)


func assaltar_loja(id: int) -> String:
	if lojas_roubadas.get(id, -1.0) > tempo:
		hud.mensagem("O caixa está vazio. Volte mais tarde.", 2.5)
		return "vazio"
	var valor := randi_range(250, 600)
	dinheiro += valor
	lojas_roubadas[id] = tempo + 180.0
	var porta: Vector2 = mapa.lojas[id]["p"] if id >= 0 else jogador.pos
	hud.mensagem("Você levou %s do caixa. A câmera de segurança gravou tudo!" % U.dinheiro(valor), 3.5)
	audio.tocar("alerta")
	pedestres.panico(porta, 30.0)
	# a camera denuncia na hora: a policia sabe a roupa e onde foi
	policia.denuncia({"tipo": "assalto", "p": porta, "estrelas": 2, "carro": null, "roupa": jogador.roupa_id})
	return "roubou"


func morreu() -> void:
	if cena_hospital > 0.0 or cena_prisao > 0.0:
		return
	cena_hospital = 3.0
	estat["mortes"] += 1
	var conta := roundf(dinheiro * 0.1)
	dinheiro -= conta
	hud.banner("Hospitalizado", "Conta do hospital: %s. Você acorda na casa segura." % U.dinheiro(conta), 3.0)
	missoes.falhar("Você foi parar no hospital.")
	audio.alerta()


func _hospital(dt: float) -> bool:
	if cena_hospital <= 0.0:
		return false
	cena_hospital -= dt
	if cena_hospital <= 0.0:
		cena_hospital = 0.0
		if jogador.veiculo != null:
			jogador.sair(true)
		jogador.pos = mapa.poi["casa"]["p"]
		jogador.h = 0.0
		jogador.vida = 100.0
		jogador.caido = 0.0
		jogador.queda = 0.0
		policia.limpar()
		salvar()
	return true


func crime(tipo: String, p: Vector2, estrelas: int, op: Dictionary = {}) -> void:
	policia.crime(tipo, p, estrelas, op)


func evento_batida(a, b, forca: float) -> void:
	policia.evento_batida(a, b, forca)


func preso() -> void:
	if cena_prisao > 0.0 or cena_hospital > 0.0:
		return
	cena_prisao = 2.6
	estat["prisoes"] += 1
	var tinha_armas := armas.inventario.size() > 1
	armas.confiscar()
	if tinha_armas:
		hud.mensagem("Suas armas foram confiscadas.", 3.0)
	var multa := roundf(dinheiro * 0.15)
	dinheiro -= multa
	hud.banner("Preso", "Fiança de %s. Você volta para a casa segura." % U.dinheiro(multa), 2.6)
	missoes.falhar("Você foi preso.")
	audio.alerta()


# ------------------------------------------------------------------ menus
func _comecar() -> void:
	interface.inicio.visible = false
	interface.mostrar_pausa(false)
	hud.raiz.visible = true
	pausado = false
	if modo_teste == "" and not toque:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pausar() -> void:
	if pausado or interface.inicio.visible:
		return
	if ui_aberta == "celular":
		celular.fechar()
	elif ui_aberta == "loja":
		loja_ui.fechar()
	pausado = true
	interface.mostrar_pausa(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _alternar_som() -> void:
	interface.botao_som.text = "Som: desligado" if audio.alternar_mudo() else "Som: ligado"


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pronto and modo_teste == "":
		_pausar()
	# botao "voltar" do Android: fecha o celular/loja ou pausa
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and pronto:
		if ui_aberta == "celular":
			celular.voltar()
		elif ui_aberta == "loja":
			loja_ui.fechar()
		elif not pausado:
			_pausar()


# ------------------------------------------------------------------ servicos
func _servicos(dt: float) -> void:
	prompt_atual = ""
	var v = jogador.veiculo
	var poi := mapa.poi
	if v != null:
		var na_oficina: bool = v.pos.distance_to(poi["oficina"]["p"]) < 6.0
		if not na_oficina:
			_pintou = false
			_t_pintura = 0.0
		elif not _pintou:
			if policia.modo == "perseguicao":
				prompt_atual = "Despiste a polícia antes de pintar o carro"
			elif dinheiro < 150.0:
				prompt_atual = "A pintura custa R$ 150"
			elif v.velocidade() < 2.0:
				_t_pintura += dt
				prompt_atual = "Pintando e consertando… %d" % ceili(2.0 - _t_pintura)
				if _t_pintura > 2.0:
					_pintou = true
					var cores := Veiculo.CORES.filter(func(c): return Color(c) != v.cor)
					v.repintar(Color(cores.pick_random()))
					v.vida = 100.0
					v.pneus = false
					dinheiro -= 150.0
					if policia.ficha["carro"] == v:
						policia.limpar_ficha("carro")
					hud.mensagem("Carro pintado e consertado (R$ 150). A polícia não reconhece mais este carro.", 3.5)
					audio.etapa()
			else:
				prompt_atual = "Pare para pintar o carro (R$ 150)"
		if prompt_atual == "" and v.velocidade() < 4.0:
			prompt_atual = "E   sair do carro"
		return
	for l in mapa.lojas:
		if jogador.pos.distance_to(l["p"]) < 2.4:
			_entrada_loja("mercado", l["id"], "Mercado")
			return
	if jogador.pos.distance_to(poi["arsenal"]["p"]) < 2.6:
		_entrada_loja("arsenal", -1, "Arsenal do Porto")
		return
	if jogador.pos.distance_to(poi["casa"]["p"]) < 2.6:
		if policia.modo == "perseguicao":
			prompt_atual = "Não dá para entrar com a polícia olhando"
		else:
			prompt_atual = "E   trocar de roupa e salvar"
			if entrada.apertou("acao"):
				entrada.apertadas.erase("acao")
				var r: Dictionary = jogador.trocar_roupa()
				policia.limpar_ficha("roupa")
				salvar()
				hud.mensagem("Você vestiu uma %s. A polícia não reconhece mais sua roupa. Jogo salvo." % r["nome"], 3.5)
				audio.etapa()
		return
	var perto = jogador.veiculo_proximo()
	if perto != null:
		prompt_atual = "E   entrar no carro" if perto.do_jogador else "E   roubar o carro (crime)"


func _entrada_loja(tipo: String, id: int, nome: String) -> void:
	if policia.estrelas > 0:
		prompt_atual = "O %s não atende quem está sendo procurado" % nome
		return
	prompt_atual = "E   entrar no %s" % nome
	if entrada.apertou("acao"):
		entrada.apertadas.erase("acao")
		loja_ui.abrir(tipo, id)


func _prisao(dt: float) -> bool:
	if cena_prisao <= 0.0:
		return false
	cena_prisao -= dt
	if cena_prisao <= 0.0:
		cena_prisao = 0.0
		if jogador.veiculo != null:
			var v = jogador.veiculo
			jogador.veiculo = null
			v.motorista = ""
			v.ctrl = {"acel": 0.0, "freio": 1.0, "virar": 0.0, "freio_mao": false}
			jogador.obj.visible = true
		jogador.pos = mapa.poi["casa"]["p"]
		jogador.h = 0.0
		policia.limpar()
		salvar()
	return true


# ------------------------------------------------------------------ laco
func passo(dt: float) -> void:
	if ui_aberta == "loja":
		return  # dentro da loja o mundo para
	tempo += dt
	var cena := _prisao(dt) or _hospital(dt)
	if not cena:
		if ui_aberta == "":
			_servicos(dt)
		else:
			prompt_atual = ""
		jogador.atualizar(dt, entrada, camera.yaw)
	else:
		prompt_atual = ""
	armas.atualizar(dt, entrada, not cena and ui_aberta == "")
	if mapa.mat_agua:
		mapa.mat_agua.uv1_offset += Vector3(dt * 0.012, 0.0, dt * 0.007)
	if destino != null and jogador.posicao().distance_to(destino) < 8.0:
		destino = null
		hud.mensagem("Você chegou ao destino.", 2.0)
	marcador_destino.visible = destino != null
	if destino != null:
		marcador_destino.position = U.v3(destino)
	trafego.atualizar(dt)
	policia.atualizar(dt)
	Fisica.passo(self, dt)
	pedestres.atualizar(dt)
	missoes.atualizar(dt)
	hud.atualizar(dt)
	audio.atualizar(self)
	camera.atualizar(dt, self, entrada)


## Para testes: roda `seg` segundos de jogo sem esperar o relogio.
func simular(seg: float, dt: float = 1.0 / 30.0) -> void:
	var t := 0.0
	while t < seg:
		passo(dt)
		entrada.fim_do_quadro()
		t += dt


func _process(delta: float) -> void:
	if not pronto:
		return
	if modo_teste != "":
		return
	var dt := minf(delta, 0.05)
	atalhos()
	if not pausado:
		passo(dt)
	elif interface.inicio.visible:
		var t := Time.get_ticks_msec() / 1000.0
		camera.position = Vector3(cos(t * 0.05) * 160.0, 70.0, sin(t * 0.05) * 160.0)
		camera.look_at(Vector3.ZERO)
	entrada.fim_do_quadro()


## Teclas e botoes de interface (pausa, celular, mapa, som). Tambem usado pelos testes.
func atalhos() -> void:
	if entrada.apertou("pausa"):
		if ui_aberta == "celular":
			celular.voltar()
		elif ui_aberta == "loja":
			loja_ui.fechar()
		elif pausado and not interface.inicio.visible:
			_comecar()
		else:
			_pausar()
	elif entrada.apertou("celular") and not pausado and ui_aberta != "loja":
		celular.alternar()
	elif entrada.apertou("acao") and ui_aberta == "loja":
		loja_ui.fechar()
	if entrada.apertou("mapa") and not pausado and ui_aberta == "":
		hud.alternar_mapa()
	if entrada.apertou("som"):
		_alternar_som()
