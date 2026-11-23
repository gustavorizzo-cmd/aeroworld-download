class_name Jogador
extends RefCounted
## Personagem a pe; entra, sai e rouba carros; troca de roupa; vida, colete, mira e soco.

const ROUPAS := [
	{"camisa": "#e2553a", "calca": "#2d3a55", "nome": "camisa coral"},
	{"camisa": "#2f9e8f", "calca": "#3b3b3f", "nome": "camisa verde-água"},
	{"camisa": "#f2d24b", "calca": "#1f2a44", "nome": "camisa amarela"},
	{"camisa": "#f4f4f0", "calca": "#6b4f33", "nome": "camisa branca"},
	{"camisa": "#5c4aa8", "calca": "#2d2d30", "nome": "camisa roxa"},
	{"camisa": "#1d1f24", "calca": "#7d8a99", "nome": "camisa preta"},
]

var jogo
var obj: Node3D
var roupa_id := 0
var mat_camisa: Array = []
var mat_calca: Array = []
var membros: Array = []
var anim: AnimHumano
var queda := 0.0  # 0 em pe, 1 deitado (suavizado)
var pos := Vector2.ZERO
var h := 0.0
var y := 0.17
var vel := 0.0
var fase := 0.0
var veiculo = null
var caido := 0.0
var vida := 100.0
var colete := 0.0
var t_soco := 0.0


func _init(p_jogo, x: float, z: float) -> void:
	jogo = p_jogo
	obj = jogo.instanciar("protagonista")
	mat_camisa = Veiculo.pintar(obj, "Roupa_Camisa", Color(ROUPAS[0]["camisa"]))
	mat_calca = Veiculo.pintar(obj, "Roupa_Calca", Color(ROUPAS[0]["calca"]))
	for n in ["braco_esq", "braco_dir", "perna_esq", "perna_dir"]:
		var no: Node3D = obj.find_child(n, true, false)
		if no:
			no.rotation_order = EULER_ORDER_XYZ
		membros.append(no)
	anim = AnimHumano.new(obj)
	pos = Vector2(x, z)
	jogo.add_child(obj)


func posicao() -> Vector2:
	return veiculo.pos if veiculo else pos


func velocidade() -> float:
	return veiculo.velocidade() if veiculo else vel


func heading() -> float:
	return veiculo.h if veiculo else h


func vestir(id: int) -> Dictionary:
	roupa_id = id
	for m in mat_camisa:
		m.albedo_color = Color(ROUPAS[id]["camisa"])
	for m in mat_calca:
		m.albedo_color = Color(ROUPAS[id]["calca"])
	return ROUPAS[id]


func trocar_roupa() -> Dictionary:
	var id := roupa_id
	while id == roupa_id:
		id = randi() % ROUPAS.size()
	return vestir(id)


func ferir(dano: float) -> void:
	if jogo.cena_prisao > 0.0 or jogo.cena_hospital > 0.0 or vida <= 0.0:
		return
	var absorvido := minf(colete, dano)
	colete -= absorvido
	vida = maxf(0.0, vida - (dano - absorvido))
	jogo.hud.dano()
	if vida <= 0.0:
		jogo.morreu()


func curar(qtd: float) -> void:
	vida = minf(100.0, vida + qtd)


func socar() -> void:
	t_soco = 0.25


func veiculo_proximo():
	var melhor = null
	var md := 3.4 * 3.4
	for v in jogo.veiculos:
		if v.queimado:
			continue
		var d: float = v.pos.distance_squared_to(pos)
		if d < md:
			md = d
			melhor = v
	return melhor


func entrar(v) -> void:
	if not v.do_jogador:
		if v.motorista == "ia":
			var vitima = jogo.pedestres.motorista_expulso(v)
			jogo.crime("roubo_carro", v.pos, 3 if v.policia else 1, {"carro": v, "vitima": vitima})
		else:
			var alarme: bool = not v.missao and not v.policia and randf() < 0.25
			jogo.crime("roubo_carro", v.pos, 2 if v.policia else 1, {"carro": v, "alarme": alarme})
			if alarme:
				jogo.hud.mensagem("O alarme do carro disparou!", 2.5)
	v.ia = null
	v.estatico = false
	v.motorista = "jogador"
	v.do_jogador = true
	veiculo = v
	obj.visible = false
	jogo.audio.porta()


func sair(forcar: bool = false) -> void:
	var v = veiculo
	if v == null or (v.velocidade() > 5.0 and not forcar):
		return
	pos = v.pos - U.direita(v.h) * 1.7
	h = v.h
	pos = Fisica.resolver_circulo(jogo.mapa, pos, 0.35)
	v.motorista = ""
	v.ctrl = {"acel": 0.0, "freio": 1.0, "virar": 0.0, "freio_mao": false}
	veiculo = null
	obj.visible = true
	jogo.audio.porta()


func atualizar(dt: float, entrada, yaw_camera: float) -> void:
	var livre: bool = jogo.ui_aberta == ""
	var ex: Vector2 = entrada.eixos() if livre else Vector2.ZERO
	if livre and entrada.apertou("acao") and jogo.policia.prendendo <= 0.0:
		if veiculo:
			sair()
		else:
			var v = veiculo_proximo()
			if v:
				entrar(v)
	if livre and entrada.apertou("buzina") and veiculo:
		jogo.audio.buzina()
	if vida < 40.0 and vida > 0.0:
		vida = minf(40.0, vida + 1.5 * dt)

	if veiculo:
		veiculo.ctrl["acel"] = maxf(ex.y, 0.0)
		veiculo.ctrl["freio"] = maxf(-ex.y, 0.0)
		veiculo.ctrl["virar"] = ex.x
		veiculo.ctrl["freio_mao"] = livre and entrada.segurando("freio_mao")
		return

	# ---- a pe
	var mirando: bool = jogo.armas.mirando
	if caido > 0.0:
		caido -= dt
	else:
		var dir := U.frente(yaw_camera) * ex.y + U.direita(yaw_camera) * ex.x
		var mag := minf(1.0, dir.length())
		var alvo_vel := 0.0
		if mag > 0.1:
			var corre: bool = entrada.segurando("correr") and not mirando
			alvo_vel = (3.0 if mirando else (7.5 if corre else 4.2)) * mag
		if mirando:
			h += U.ang_diff(h, yaw_camera) * minf(1.0, dt * 18.0)
		elif mag > 0.1:
			h += U.ang_diff(h, U.heading_de(dir)) * minf(1.0, dt * 12.0)
		vel = U.suavizar(vel, alvo_vel, 10.0, dt)
		var mov := dir.normalized() if mag > 0.1 else Vector2.ZERO
		pos += (mov if mirando else U.frente(h)) * vel * dt
	pos = Fisica.resolver_circulo(jogo.mapa, pos, 0.35)
	for v in jogo.veiculos:
		if v.pos.distance_squared_to(pos) > 16.0:
			continue
		for c in v.circulos():
			var d := pos - Vector2(c.x, c.y)
			var rr: float = c.z + 0.35
			var d2 := d.length_squared()
			if d2 < rr * rr and d2 > 1e-6:
				var dl := sqrt(d2)
				pos += d / dl * (rr - dl)
				if v.velocidade() > 9.0 and caido <= 0.0:
					caido = 1.6
					ferir(v.velocidade() * 1.5)
					jogo.hud.mensagem("Você foi atropelado!", 1.5)
	y = U.suavizar(y, jogo.mapa.altura_chao(pos.x, pos.y), 15.0, dt)

	# animacao procedural (joelhos, cotovelos, tronco) com transicoes suaves
	t_soco = maxf(0.0, t_soco - dt)
	var armado: bool = jogo.armas.armado()
	var b := anim.atualizar(dt, vel if caido <= 0.0 else 0.0, {
		"mirando": mirando and armado,
		"mira_pitch": jogo.camera.mira_pitch,
		"soco": t_soco / 0.25 if t_soco > 0.0 else 0.0,
	})
	# cair e levantar sem "pulo" de pose
	queda = U.suavizar(queda, 1.0 if (caido > 0.0 or jogo.cena_hospital > 0.0) else 0.0, 7.0, dt)
	obj.position = Vector3(pos.x, y + b, pos.y)
	obj.rotation = Vector3(-PI / 2.0 * queda, h, 0.0)
