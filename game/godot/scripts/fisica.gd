class_name Fisica
extends RefCounted
## Colisoes simples: carros = 2 circulos; predios = caixas alinhadas; postes = circulos.


## Devolve Vector3(nx, nz, penetracao); penetracao <= 0 quando nao ha contato.
static func empurrar(c: Vector2, r: float, k) -> Vector3:
	var px := clampf(c.x, k.min_x, k.max_x)
	var pz := clampf(c.y, k.min_z, k.max_z)
	var dx := c.x - px
	var dz := c.y - pz
	var d2 := dx * dx + dz * dz
	if d2 >= r * r:
		return Vector3.ZERO
	if d2 > 1e-8:
		var d := sqrt(d2)
		return Vector3(dx / d, dz / d, r - d)
	var op := [
		Vector3(-1, 0, c.x - k.min_x + r), Vector3(1, 0, k.max_x - c.x + r),
		Vector3(0, -1, c.y - k.min_z + r), Vector3(0, 1, k.max_z - c.y + r),
	]
	var m: Vector3 = op[0]
	for o in op:
		if o.z < m.z:
			m = o
	return m


static func impacto(jogo, v, n: Vector2, e: float) -> float:
	var vn: float = v.vel.dot(n)
	if vn >= 0.0:
		return 0.0
	v.vel -= n * (1.0 + e) * vn
	var forca := -vn
	if forca > 5.0:
		v.dano(forca)
		if v.motorista == "jogador":
			jogo.audio.batida(forca)
	return forca


## Empurra um circulo (pedestre, jogador a pe) para fora do mundo solido.
static func resolver_circulo(mapa, p: Vector2, r: float) -> Vector2:
	var prox: Dictionary = mapa.proximos(p, r + 2.0)
	for k in prox["caixas"]:
		var e := empurrar(p, r, k)
		if e.z > 0.0:
			p += Vector2(e.x, e.y) * e.z
	for c in prox["circulos"]:
		var d := p - Vector2(c.x, c.y)
		var rr: float = r + c.z
		var d2 := d.length_squared()
		if d2 < rr * rr and d2 > 1e-8:
			var dl := sqrt(d2)
			p += d / dl * (rr - dl)
	return p.clamp(Mapa.LIM_MIN, Mapa.LIM_MAX)


static func _colisao_mundo(jogo, v) -> void:
	var prox: Dictionary = jogo.mapa.proximos(v.pos, 4.0)
	for idx in 2:
		var cs: Vector3 = v.circulos()[idx]
		var c := Vector2(cs.x, cs.y)
		for k in prox["caixas"]:
			var e := empurrar(c, cs.z, k)
			if e.z > 0.0:
				var n := Vector2(e.x, e.y)
				v.pos += n * e.z
				c += n * e.z
				impacto(jogo, v, n, 0.2)
		for cc in prox["circulos"]:
			var d := c - Vector2(cc.x, cc.y)
			var rr: float = cs.z + cc.z
			var d2 := d.length_squared()
			if d2 < rr * rr and d2 > 1e-8:
				var dl := sqrt(d2)
				var n := d / dl
				v.pos += n * (rr - dl)
				impacto(jogo, v, n, 0.3)
		for o in jogo.obstaculos:
			if o.caido:
				continue
			var rr2: float = cs.z + o.r
			if c.distance_squared_to(o.pos) < rr2 * rr2:
				o.derrubar(v)
	var antes: Vector2 = v.pos
	v.pos = v.pos.clamp(Mapa.LIM_MIN, Mapa.LIM_MAX)
	if v.pos.x != antes.x:
		v.vel.x = 0.0
	if v.pos.y != antes.y:
		v.vel.y = 0.0


static func _colisao_par(jogo, a, b) -> void:
	for pa in a.circulos():
		for pb in b.circulos():
			var d := Vector2(pb.x - pa.x, pb.y - pa.y)
			var rr: float = pa.z + pb.z
			var d2 := d.length_squared()
			if d2 >= rr * rr or d2 < 1e-8:
				continue
			var dl := sqrt(d2)
			var n := d / dl
			var pen := rr - dl
			var ma: float = a.t["massa"] * (1.0 if a.motorista != "" else 1.6)
			var mb: float = b.t["massa"] * (1.0 if b.motorista != "" else 1.6)
			var s := ma + mb
			a.pos -= n * pen * (mb / s)
			b.pos += n * pen * (ma / s)
			var rel: float = (b.vel - a.vel).dot(n)
			if rel < 0.0:
				var j := (-1.3 * rel) / (1.0 / ma + 1.0 / mb)
				a.vel -= n * (j / ma)
				b.vel += n * (j / mb)
				var forca := -rel
				if forca > 4.0:
					a.dano(forca * 0.8)
					b.dano(forca * 0.8)
					jogo.evento_batida(a, b, forca)
			return


static func passo(jogo, dt: float) -> void:
	var vs: Array = jogo.veiculos
	for v in vs:
		if not v.estatico:
			v.atualizar(dt)
	for i in vs.size():
		var a = vs[i]
		for j in range(i + 1, vs.size()):
			var b = vs[j]
			if a.pos.distance_squared_to(b.pos) < 36.0:
				_colisao_par(jogo, a, b)
	for v in vs:
		if not v.estatico or v.motorista != "":
			_colisao_mundo(jogo, v)
		for tp in jogo.tapetes:
			var dp: Vector2 = v.pos - tp["p"]
			if not v.pneus and absf(dp.x) < tp["lx"] and absf(dp.y) < tp["lz"] and v.velocidade() > 2.0:
				v.pneus = true
				if v.motorista == "jogador":
					jogo.hud.mensagem("Pneus furados! O carro ficou lento e escorregadio.", 3.0)
					jogo.audio.batida(8.0)
		v.sincronizar()
