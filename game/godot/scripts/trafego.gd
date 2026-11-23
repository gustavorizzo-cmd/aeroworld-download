class_name Trafego
extends RefCounted
## Transito: carros seguem a faixa da direita pelo grafo de ruas e freiam para obstaculos.

var jogo
var max_civis := 16
var max_patrulhas := 3
var timer := 0.0


func _init(p_jogo) -> void:
	jogo = p_jogo


## Faixa da direita entre dois cruzamentos (encurtada para a curva acontecer no cruzamento).
static func faixa(de: Vector2i, para: Vector2i, recuo: float = 7.0, lado: float = 2.0) -> Dictionary:
	var a := Mapa.nodo_pos(de)
	var b := Mapa.nodo_pos(para)
	var l := a.distance_to(b)
	var d := (b - a) / l
	var r := Vector2(-d.y, d.x)
	return {"ini": a + d * recuo + r * lado, "fim": b - d * recuo + r * lado, "d": d, "L": l - 2.0 * recuo}


static func escolher_proximo(mapa, de: Vector2i, atual: Vector2i) -> Vector2i:
	var opcoes := []
	for n in mapa.vizinhos(atual):
		if n != de:
			opcoes.append(n)
	return opcoes.pick_random() if not opcoes.is_empty() else de


## Converte um alvo em volante/acelerador. Devolve o erro de angulo.
static func dirigir_para(v, alvo: Vector2, vel_desejada: float, ganho: float = 2.2) -> float:
	var err := U.ang_diff(v.h, U.heading_de(alvo - v.pos))
	var vd := vel_desejada
	if absf(err) > 1.6 and v.v_f < 6.0:
		v.ctrl = {"acel": 0.0, "freio": 1.0, "virar": clampf(err * 2.0, -1.0, 1.0), "freio_mao": false}
		return err
	v.ctrl["virar"] = clampf(-err * ganho, -1.0, 1.0)
	vd *= 1.0 - minf(0.6, absf(err) * 0.5)
	var vf: float = v.v_f
	if vf < vd - 0.5:
		v.ctrl["acel"] = clampf((vd - vf) / 4.0, 0.35, 1.0)
		v.ctrl["freio"] = 0.0
	elif vf > vd + 1.0:
		v.ctrl["acel"] = 0.0
		v.ctrl["freio"] = clampf((vf - vd) / 6.0, 0.15, 1.0)
	else:
		v.ctrl["acel"] = 0.15
		v.ctrl["freio"] = 0.0
	v.ctrl["freio_mao"] = false
	return err


## Distancia livre a frente (outros carros, pedestres, jogador a pe).
static func espaco_livre(jogo, v, alcance: float = 16.0) -> float:
	var f := U.frente(v.h)
	var r := U.direita(v.h)
	var livre := alcance
	var pontos := []
	for o in jogo.veiculos:
		if o != v:
			pontos.append(Vector3(o.pos.x, o.pos.y, 2.3))
	if jogo.jogador.veiculo == null:
		pontos.append(Vector3(jogo.jogador.pos.x, jogo.jogador.pos.y, 1.6))
	for p in jogo.pedestres.lista:
		if not p.caido:
			pontos.append(Vector3(p.pos.x, p.pos.y, 1.4))
	for q in pontos:
		var rel: Vector2 = Vector2(q.x, q.y) - v.pos
		var fr: float = rel.dot(f)
		if fr <= 0.0 or fr > alcance:
			continue
		if absf(rel.dot(r)) < q.z:
			livre = minf(livre, fr)
	return livre


static func iniciar_ia(jogo, v, de: Vector2i, para: Vector2i) -> void:
	v.motorista = "ia"
	v.ia = {"tipo": "trafego", "de": de, "para": para, "prox": escolher_proximo(jogo.mapa, de, para), "preso": 0.0, "re": 0.0}


static func conduzir_na_faixa(jogo, v, dt: float, vel_base: float = 11.0) -> void:
	var ia: Dictionary = v.ia
	var f := faixa(ia["de"], ia["para"])
	var d: Vector2 = f["d"]
	var ini: Vector2 = f["ini"]
	var fim: Vector2 = f["fim"]
	var comp: float = f["L"]
	var t: float = (v.pos - ini).dot(d) / comp
	var restante: float = (1.0 - t) * comp
	var look: float = 5.0 + v.velocidade() * 0.45
	var f2 := faixa(ia["para"], ia["prox"])
	var ini2: Vector2 = f2["ini"]
	var alvo: Vector2
	if restante > look:
		alvo = ini + d * (t * comp + look)
	else:
		var ponte := fim.distance_to(ini2) + 0.01
		alvo = fim.lerp(ini2, clampf((look - restante) / ponte, 0.0, 1.0))
	if restante < 2.0 or t > 1.0:
		ia["de"] = ia["para"]
		ia["para"] = ia["prox"]
		ia["prox"] = escolher_proximo(jogo.mapa, ia["de"], ia["para"])
	var vd := vel_base
	var d2: Vector2 = f2["d"]
	if d.dot(d2) < 0.7 and restante < 18.0:
		vd = 5.5
	vd = minf(vd, maxf(0.0, (espaco_livre(jogo, v) - 6.0) * 1.1))

	if ia["re"] > 0.0:
		ia["re"] -= dt
		v.ctrl = {"acel": 0.0, "freio": 1.0, "virar": -signf(U.ang_diff(v.h, U.heading_de(alvo - v.pos))), "freio_mao": false}
		return
	dirigir_para(v, alvo, vd)
	if vd > 3.0 and v.velocidade() < 0.6:
		ia["preso"] += dt
	else:
		ia["preso"] = maxf(0.0, ia["preso"] - dt)
	if ia["preso"] > 3.0:
		ia["preso"] = 0.0
		ia["re"] = 1.4


func spawnar(de_policia: bool = false):
	var p: Vector2 = jogo.jogador.posicao()
	for tentativa in 20:
		var de := Vector2i(randi() % Mapa.N, randi() % Mapa.N)
		var para: Vector2i = jogo.mapa.vizinhos(de).pick_random()
		var f := faixa(de, para)
		var d: Vector2 = f["d"]
		var pos: Vector2 = f["ini"] + d * f["L"] * randf_range(0.15, 0.7)
		var dist := pos.distance_to(p)
		if dist < 70.0 or dist > 175.0:
			continue
		var livre := true
		for o in jogo.veiculos:
			if o.pos.distance_squared_to(pos) < 144.0:
				livre = false
				break
		if not livre:
			continue
		var tipo := "viatura" if de_policia else ("esportivo" if randf() < 0.12 else "sedan")
		var v := Veiculo.new(jogo, tipo, pos.x, pos.y, U.heading_de(d), null if de_policia else Veiculo.CORES.pick_random())
		iniciar_ia(jogo, v, de, para)
		v.v_f = 8.0
		v.vel = d * 8.0
		return v
	return null


func atualizar(dt: float) -> void:
	var p: Vector2 = jogo.jogador.posicao()
	timer -= dt
	if timer <= 0.0:
		timer = 0.5
		var civis := 0
		var patrulhas := 0
		for v in jogo.veiculos:
			if v.ia != null and v.ia["tipo"] == "trafego":
				if v.policia:
					patrulhas += 1
				else:
					civis += 1
		if civis < max_civis:
			spawnar(false)
		if patrulhas < max_patrulhas and jogo.policia.estrelas == 0:
			spawnar(true)
		for v in jogo.veiculos.duplicate():
			if v.missao or v.motorista == "jogador" or v.estatico or v.fixo:
				continue
			if v.ia != null and v.ia["tipo"] == "unidade":
				continue
			if v.pos.distance_to(p) > 240.0:
				v.remover()
	for v in jogo.veiculos:
		if v.ia != null and v.ia["tipo"] == "trafego":
			conduzir_na_faixa(jogo, v, dt, 12.0 if v.policia else 11.0)
