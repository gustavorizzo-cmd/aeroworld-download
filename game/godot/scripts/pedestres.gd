class_name Pedestres
extends RefCounted
## Pedestres andam em volta dos quarteiroes, fogem do perigo e servem de testemunhas.

const H := 31.0  # meia-volta do quarteirao na linha da calcada
const PER := 8.0 * H
const CAMISAS := ["#d9534f", "#5bc0de", "#f0ad4e", "#5cb85c", "#9b59b6", "#ecf0f1", "#34495e", "#e67e22", "#16a085", "#c0392b"]
const CALCAS := ["#2c3e50", "#3b3b3f", "#6b4f33", "#7d8a99", "#1f2a44", "#8e7f6a"]


class Ped:
	var obj: Node3D
	var icone: Sprite3D
	var pos := Vector2.ZERO
	var h := 0.0
	var y := 0.17
	var estado := "andando"
	var vel := 1.5
	var fase := 0.0
	var membros: Array = []
	var anim: AnimHumano
	var bloco = null
	var s := 0.0
	var dir := 1.0
	var timer := 0.0
	var caido := false
	var vy := 0.0
	var vxz := Vector2.ZERO
	var fuga_de := Vector2.ZERO
	var denuncia = null
	var crime = null
	var denuncia_depois := false
	var temporario := false


var jogo
var lista: Array = []
var max_ped := 34
var timer := 0.0
var _tex_icone: ImageTexture
var _mats := {}


func _init(p_jogo) -> void:
	jogo = p_jogo
	_tex_icone = _textura_icone()


static func _textura_icone() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 64:
		for yy in 64:
			var d := Vector2(x - 31.5, yy - 31.5).length()
			if d < 25.0:
				img.set_pixel(x, yy, Color("#ffcc33"))
			elif d < 29.0:
				img.set_pixel(x, yy, Color("#1b1b1b"))
	img.fill_rect(Rect2i(28, 14, 8, 24), Color("#1b1b1b"))
	img.fill_rect(Rect2i(28, 42, 8, 8), Color("#1b1b1b"))
	return ImageTexture.create_from_image(img)


static func pos_perimetro(s: float) -> Dictionary:
	s = fposmod(s, PER)
	var lado := int(s / (2.0 * H))
	var u := s - lado * 2.0 * H - H
	match lado:
		0:
			return {"p": Vector2(u, -H), "d": Vector2(1, 0)}
		1:
			return {"p": Vector2(H, u), "d": Vector2(0, 1)}
		2:
			return {"p": Vector2(-u, H), "d": Vector2(-1, 0)}
	return {"p": Vector2(-H, -u), "d": Vector2(0, -1)}


static func param_mais_proximo(v: Vector2) -> float:
	var cx := clampf(v.x, -H, H)
	var cz := clampf(v.y, -H, H)
	var cand := [
		Vector2(cx + H, (v.y + H) ** 2 + (v.x - cx) ** 2),
		Vector2(2.0 * H + cz + H, (v.x - H) ** 2 + (v.y - cz) ** 2),
		Vector2(4.0 * H + (H - cx), (v.y - H) ** 2 + (v.x - cx) ** 2),
		Vector2(6.0 * H + (H - cz), (v.x + H) ** 2 + (v.y - cz) ** 2),
	]
	var m: Vector2 = cand[0]
	for c in cand:
		if c.y < m.y:
			m = c
	return m.x


func _pintar(obj: Node3D, prefixo: String, cor: String) -> void:
	var chave := prefixo + cor
	for mi in Veiculo.malhas(obj, []):
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(si)
			if m and m.resource_name.begins_with(prefixo):
				if not _mats.has(chave):
					var d: BaseMaterial3D = m.duplicate()
					d.albedo_color = Color(cor)
					_mats[chave] = d
				mi.set_surface_override_material(si, _mats[chave])


func criar(p: Vector2 = Vector2.ZERO) -> Ped:
	var pd := Ped.new()
	pd.obj = jogo.instanciar("protagonista")
	_pintar(pd.obj, "Roupa_Camisa", CAMISAS.pick_random())
	_pintar(pd.obj, "Roupa_Calca", CALCAS.pick_random())
	pd.icone = Sprite3D.new()
	pd.icone.texture = _tex_icone
	pd.icone.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pd.icone.no_depth_test = true
	pd.icone.pixel_size = 0.7 / 64.0
	pd.icone.position.y = 2.4
	pd.icone.visible = false
	pd.obj.add_child(pd.icone)
	pd.anim = AnimHumano.new(pd.obj)
	pd.pos = p
	pd.vel = randf_range(1.2, 1.7)
	pd.fase = randf() * 6.0
	pd.dir = 1.0 if randf() < 0.5 else -1.0
	jogo.add_child(pd.obj)
	lista.append(pd)
	return pd


func colocar_no_bloco(pd: Ped, bloco: Dictionary, s: float) -> void:
	pd.bloco = bloco
	pd.s = s
	pd.pos = bloco["c"] + pos_perimetro(s)["p"]
	pd.estado = "andando"
	pd.caido = false
	pd.obj.rotation = Vector3.ZERO
	pd.icone.visible = false


func bloco_mais_proximo(p: Vector2) -> Dictionary:
	var m: Dictionary = jogo.mapa.blocos[0]
	var md := INF
	for b in jogo.mapa.blocos:
		var d: float = b["c"].distance_squared_to(p)
		if d < md:
			md = d
			m = b
	return m


func reposicionar(pd: Ped) -> void:
	var p: Vector2 = jogo.jogador.posicao()
	var perto := []
	for b in jogo.mapa.blocos:
		if b["c"].distance_to(p) < 140.0:
			perto.append(b)
	if perto.is_empty():
		perto = jogo.mapa.blocos
	for tentativa in 12:
		var b: Dictionary = perto.pick_random()
		var s := randf() * PER
		var q: Vector2 = b["c"] + pos_perimetro(s)["p"]
		if q.distance_to(p) > 45.0:
			colocar_no_bloco(pd, b, s)
			return


## Motorista expulso do carro: foge e depois liga para a policia.
func motorista_expulso(v) -> Ped:
	var pd := criar(v.pos - U.direita(v.h) * 1.8)
	fugir(pd, v.pos, 2.2)
	pd.denuncia_depois = true
	pd.temporario = true
	return pd


func fugir(pd: Ped, de: Vector2, tempo: float = 5.0) -> void:
	if pd.caido:
		return
	pd.estado = "fugindo"
	pd.fuga_de = de
	pd.timer = tempo
	pd.icone.visible = false


func panico(p: Vector2, raio: float) -> void:
	for pd in lista:
		if pd.caido or pd.estado == "ligando":
			continue
		if pd.pos.distance_to(p) < raio:
			fugir(pd, p, randf_range(4.0, 7.0))


## Quem viu? O pedestre mais proximo com visao do local.
func testemunha(p: Vector2, alcance: float = 40.0):
	var m = null
	var md := alcance * alcance
	for pd in lista:
		if pd.caido or pd.estado == "ligando":
			continue
		var d: float = pd.pos.distance_squared_to(p)
		if d < md and jogo.mapa.tem_visao(pd.pos, p):
			md = d
			m = pd
	return m


func ligar(pd: Ped, denuncia) -> void:
	pd.estado = "ligando"
	pd.timer = 5.0
	pd.denuncia = denuncia
	pd.icone.visible = true


## Derruba o pedestre (atropelado, baleado, socado). Ele levanta e some depois.
func derrubar(pd: Ped, impulso: Vector2, vy: float) -> void:
	if pd.caido:
		return
	pd.caido = true
	pd.estado = "caido"
	pd.icone.visible = false
	pd.vxz = impulso
	pd.vy = vy
	pd.timer = 12.0
	pd.denuncia = null
	panico(pd.pos, 25.0)


func atropelar(pd: Ped, v) -> void:
	derrubar(pd, v.vel * 0.7, 3.0 + v.velocidade() * 0.15)
	if v.motorista == "jogador":
		jogo.crime("atropelamento", pd.pos, 2, {"carro": v})
		jogo.audio.batida(6.0)


func _voltar(pd: Ped) -> void:
	pd.estado = "voltando"
	pd.bloco = bloco_mais_proximo(pd.pos)
	pd.s = param_mais_proximo(pd.pos - pd.bloco["c"])


func atualizar(dt: float) -> void:
	var pj: Vector2 = jogo.jogador.posicao()
	timer -= dt
	if timer <= 0.0:
		timer = 0.7
		var permanentes := 0
		for pd in lista:
			if not pd.temporario:
				permanentes += 1
		if permanentes < max_ped:
			reposicionar(criar())

	for pd in lista.duplicate():
		var d: float = pd.pos.distance_to(pj)
		if d > 170.0 and pd.estado != "ligando":
			if pd.temporario:
				remover(pd)
			else:
				reposicionar(pd)
			continue

		var vel := 0.0
		if pd.caido:
			pd.timer -= dt
			pd.vy -= 20.0 * dt
			pd.pos += pd.vxz * dt
			pd.y += pd.vy * dt
			var chao: float = jogo.mapa.altura_chao(pd.pos.x, pd.pos.y)
			if pd.y <= chao:
				pd.y = chao
				pd.vy = 0.0
				pd.vxz *= 0.8
			pd.obj.rotation.x = maxf(-PI / 2.0, pd.obj.rotation.x - dt * 8.0)
			pd.pos = Fisica.resolver_circulo(jogo.mapa, pd.pos, 0.3)
			if pd.timer <= 0.0:
				if pd.temporario:
					remover(pd)
					continue
				reposicionar(pd)
		elif pd.estado == "andando" and pd.bloco != null:
			pd.s += pd.dir * pd.vel * dt
			var q := pos_perimetro(pd.s)
			pd.pos = pd.bloco["c"] + q["p"]
			pd.h = U.heading_de(q["d"] * pd.dir)
			vel = pd.vel
		elif pd.estado == "fugindo":
			pd.timer -= dt
			pd.h += U.ang_diff(pd.h, U.heading_de(pd.pos - pd.fuga_de)) * minf(1.0, dt * 6.0)
			vel = 5.5
			pd.pos += U.frente(pd.h) * vel * dt
			pd.pos = Fisica.resolver_circulo(jogo.mapa, pd.pos, 0.3)
			if pd.timer <= 0.0:
				if pd.denuncia_depois:
					pd.denuncia_depois = false
					jogo.policia.vitima_vai_ligar(pd)
				else:
					_voltar(pd)
		elif pd.estado == "voltando":
			var alvo: Vector2 = pd.bloco["c"] + pos_perimetro(pd.s)["p"]
			if pd.pos.distance_to(alvo) < 0.6:
				pd.estado = "andando"
			else:
				pd.h = U.heading_de(alvo - pd.pos)
				vel = pd.vel
				pd.pos += U.frente(pd.h) * vel * dt
				pd.pos = Fisica.resolver_circulo(jogo.mapa, pd.pos, 0.3)
		elif pd.estado == "ligando":
			pd.timer -= dt
			pd.h = U.heading_de(pj - pd.pos) + PI
			if d < 3.2:
				pd.icone.visible = false
				pd.denuncia = null
				fugir(pd, pj, 6.0)
				jogo.policia.denuncia_cancelada(true)
			elif pd.timer <= 0.0:
				pd.icone.visible = false
				jogo.policia.denuncia(pd.denuncia)
				pd.denuncia = null
				_voltar(pd)

		if not pd.caido:
			for v in jogo.veiculos:
				if v.pos.distance_squared_to(pd.pos) > 12.0:
					continue
				for c in v.circulos():
					var dd: Vector2 = pd.pos - Vector2(c.x, c.y)
					var rr: float = c.z + 0.3
					var d2 := dd.length_squared()
					if d2 < rr * rr and d2 > 1e-6:
						if v.velocidade() > 4.0:
							atropelar(pd, v)
							break
						var dl := sqrt(d2)
						pd.pos += dd / dl * (rr - dl)
				if pd.caido:
					break

		if not pd.caido:
			pd.y = jogo.mapa.altura_chao(pd.pos.x, pd.pos.y)
		var bob := 0.0
		if not pd.caido and pd.pos.distance_squared_to(pj) < 90.0 * 90.0:
			bob = pd.anim.atualizar(dt, vel, {"ligando": pd.estado == "ligando"})
		pd.obj.position = Vector3(pd.pos.x, pd.y + bob, pd.pos.y)
		pd.obj.rotation.y = pd.h


func remover(pd: Ped) -> void:
	pd.obj.queue_free()
	lista.erase(pd)
