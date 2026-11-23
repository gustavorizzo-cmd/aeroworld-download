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
	_ambiente()
	entrada = Entrada.new()
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
	var env := Environment.new()
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color("#8fbbe3")
	mat_ceu.sky_horizon_color = Color("#d9e7f0")
	mat_ceu.ground_horizon_color = Color("#d9e7f0")
	mat_ceu.ground_bottom_color = Color("#8a8466")
	ceu.sky_material = mat_ceu
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b4c3d3")
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("#c9dbe8")
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.light_energy = 0.78
	sol.light_color = Color("#fff0d6")
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 140.0
	sol.shadow_bias = 0.04
	add_child(sol)
	sol.look_at_from_position(Vector3(60, 110, 35), Vector3.ZERO, Vector3.UP)


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
	c.save(ARQUIVO_SALVO)


func crime(tipo: String, p: Vector2, estrelas: int, op: Dictionary = {}) -> void:
	policia.crime(tipo, p, estrelas, op)


func evento_batida(a, b, forca: float) -> void:
	policia.evento_batida(a, b, forca)


func preso() -> void:
	if cena_prisao > 0.0:
		return
	cena_prisao = 2.6
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
	if modo_teste == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pausar() -> void:
	if pausado or interface.inicio.visible:
		return
	pausado = true
	interface.mostrar_pausa(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _alternar_som() -> void:
	interface.botao_som.text = "Som: desligado" if audio.alternar_mudo() else "Som: ligado"


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pronto and modo_teste == "":
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
	tempo += dt
	if not _prisao(dt):
		_servicos(dt)
		jogador.atualizar(dt, entrada, camera.yaw)
	else:
		prompt_atual = ""
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
	if entrada.apertou("pausa"):
		if pausado and not interface.inicio.visible:
			_comecar()
		else:
			_pausar()
	if entrada.apertou("mapa") and not pausado:
		hud.alternar_mapa()
	if entrada.apertou("som"):
		_alternar_som()
	if not pausado:
		passo(dt)
	elif interface.inicio.visible:
		var t := Time.get_ticks_msec() / 1000.0
		camera.position = Vector3(cos(t * 0.05) * 160.0, 70.0, sin(t * 0.05) * 160.0)
		camera.look_at(Vector3.ZERO)
	entrada.fim_do_quadro()
