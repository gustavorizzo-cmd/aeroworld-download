class_name Jogador
extends RefCounted
## Personagem a pe; entra, sai e rouba carros; troca de roupa.

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
var pos := Vector2.ZERO
var h := 0.0
var y := 0.17
var vel := 0.0
var fase := 0.0
var veiculo = null
var caido := 0.0


func _init(p_jogo, x: float, z: float) -> void:
	jogo = p_jogo
	obj = jogo.instanciar("protagonista")
	mat_camisa = Veiculo.pintar(obj, "Roupa_Camisa", Color(ROUPAS[0]["camisa"]))
	mat_calca = Veiculo.pintar(obj, "Roupa_Calca", Color(ROUPAS[0]["calca"]))
	for n in ["braco_esq", "braco_dir", "perna_esq", "perna_dir"]:
		membros.append(obj.find_child(n, true, false))
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


func veiculo_proximo():
	var melhor = null
	var md := 3.4 * 3.4
	for v in jogo.veiculos:
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


func sair() -> void:
	var v = veiculo
	if v == null or v.velocidade() > 5.0:
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
	var ex: Vector2 = entrada.eixos()
	if entrada.apertou("acao") and jogo.policia.prendendo <= 0.0:
		if veiculo:
			sair()
		else:
			var v = veiculo_proximo()
			if v:
				entrar(v)
	if entrada.apertou("buzina") and veiculo:
		jogo.audio.buzina()

	if veiculo:
		veiculo.ctrl["acel"] = maxf(ex.y, 0.0)
		veiculo.ctrl["freio"] = maxf(-ex.y, 0.0)
		veiculo.ctrl["virar"] = ex.x
		veiculo.ctrl["freio_mao"] = entrada.segurando("freio_mao")
		return

	# ---- a pe
	if caido > 0.0:
		caido -= dt
		obj.rotation.x = -PI / 2.0
	else:
		obj.rotation.x = 0.0
		var dir := U.frente(yaw_camera) * ex.y + U.direita(yaw_camera) * ex.x
		var mag := minf(1.0, dir.length())
		var alvo_vel := 0.0
		if mag > 0.1:
			alvo_vel = (7.5 if entrada.segurando("correr") else 4.2) * mag
			h += U.ang_diff(h, U.heading_de(dir)) * minf(1.0, dt * 12.0)
		vel = U.suavizar(vel, alvo_vel, 10.0, dt)
		pos += U.frente(h) * vel * dt
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
					jogo.hud.mensagem("Você foi atropelado!", 1.5)
	y = U.suavizar(y, jogo.mapa.altura_chao(pos.x, pos.y), 15.0, dt)

	var amp := minf(1.0, vel / 7.0) * 0.95
	fase += vel * dt * 1.9
	var s := sin(fase) * amp
	var giros := [s, -s, -s, s]
	for i in membros.size():
		if membros[i]:
			membros[i].rotation.x = giros[i]
	obj.position = Vector3(pos.x, y, pos.y)
	obj.rotation.y = h
