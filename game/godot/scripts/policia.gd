class_name Policia
extends RefCounted
## Estrelas (forca da cacada) + Ficha (o que a policia sabe: carro e roupa),
## testemunhas, perseguicao -> busca -> fuga, prisao, bloqueios e helicoptero.

const UNIDADES := [0, 2, 3, 4, 5]  # viaturas por estrela (0..4)


class Obstaculo:
	var obj: Node3D
	var pos: Vector2
	var r: float
	var caido := false
	var voando = null
	var jogo

	func derrubar(v) -> void:
		caido = true
		voando = {"v": Vector3(v.vel.x * 0.8 + randf_range(-2, 2), 4.0 + v.velocidade() * 0.1, v.vel.y * 0.8 + randf_range(-2, 2)), "giro": randf_range(-8, 8)}
		v.vel *= 0.82
		v.dano(9.0)
		if v.motorista == "jogador":
			jogo.audio.batida(7.0)


var jogo
var estrelas := 0
var modo := "limpo"  # limpo | perseguicao | busca
var ultima := Vector2.ZERO
var zona = null  # {c: Vector2, r: float}
var sem_ver := 0.0
var fora_tempo := 0.0
var tempo_nivel := 0.0
var ficha := {"carro": null, "roupa": -1, "expira": 0.0}
var vendo := false
var t_visao := 0.0
var t_spawn := 0.0
var cd_batida := 0.0
var cd_bloqueio := 6.0
var prendendo := 0.0
var cd_ataque := 0.0
var cd_heli := 0.0
var carencia := 3.0  # segundos sem a policia agir (inicio do jogo e depois de preso)
var bloqueios: Array = []
var heli = null
var luz_heli: SpotLight3D


func _init(p_jogo) -> void:
	jogo = p_jogo
	# luz do helicoptero criada desde o inicio (adicionar luz depois recompila shaders)
	luz_heli = SpotLight3D.new()
	luz_heli.spot_range = 90.0
	luz_heli.spot_angle = 12.0
	luz_heli.light_energy = 0.0
	luz_heli.light_color = Color("#fff1c9")
	jogo.add_child(luz_heli)


func j():
	return jogo.jogador


func olhos() -> Array:
	return jogo.veiculos.filter(func(v): return v.policia and v.motorista == "ia" and not v.queimado)


func unidades() -> Array:
	return jogo.veiculos.filter(func(v): return v.ia != null and v.ia["tipo"] == "unidade")


func pode_ver(v, p: Vector2, alcance: float = 60.0) -> bool:
	var d: float = v.pos.distance_to(p)
	if d > alcance:
		return false
	if d > 12.0 and absf(U.ang_diff(v.h, U.heading_de(p - v.pos))) > 1.25:
		return false
	return jogo.mapa.tem_visao(v.pos, p)


func heli_ve() -> bool:
	return heli != null and not heli["saindo"] and heli["pos"].distance_to(j().posicao()) < 70.0


## A policia sabe que e voce? Depende do modo e da Ficha.
func reconhece(d: float) -> bool:
	var jj = j()
	if modo == "perseguicao":
		return true
	var busca := modo == "busca"
	if jj.veiculo:
		if ficha["carro"] != null and jj.veiculo == ficha["carro"]:
			return d < 50.0
		return busca and d < 12.0
	if ficha["roupa"] >= 0 and ficha["roupa"] == jj.roupa_id:
		return d < 20.0
	return busca and d < 8.0


func ficha_carro() -> bool:
	return ficha["carro"] != null


func ficha_roupa() -> bool:
	return ficha["roupa"] >= 0


func registrar(carro, roupa: int) -> void:
	if carro != null:
		ficha["carro"] = carro
	if roupa >= 0:
		ficha["roupa"] = roupa
	ficha["expira"] = jogo.tempo + 150.0


func limpar_ficha(qual: String) -> void:
	if qual == "carro" or qual == "tudo":
		ficha["carro"] = null
	if qual == "roupa" or qual == "tudo":
		ficha["roupa"] = -1


func aplicar(n: int, msg: String = "") -> void:
	var novo := mini(4, maxi(estrelas, n))
	if novo > estrelas:
		estrelas = novo
		tempo_nivel = 0.0
		if msg != "":
			jogo.hud.mensagem(msg, 3.0)
		jogo.audio.alerta()


func raio() -> float:
	return 45.0 + 25.0 * estrelas


func _perseguir_agora() -> void:
	modo = "perseguicao"
	sem_ver = 0.0
	ultima = j().posicao()


# ------------------------------------------------------------------ crimes
func crime(tipo: String, p: Vector2, n_estrelas: int, op: Dictionary = {}) -> void:
	var jj = j()
	var carro = op["carro"] if op.has("carro") else jj.veiculo
	var a_pe: bool = jj.veiculo == null
	var d := {"tipo": tipo, "p": p, "estrelas": n_estrelas, "carro": carro, "roupa": jj.roupa_id if a_pe else -1}

	var viu := heli_ve()
	for v in olhos():
		if pode_ver(v, p, 55.0):
			viu = true
			break
	if viu:
		registrar(d["carro"], d["roupa"])
		aplicar(n_estrelas, "A polícia viu! Mais estrelas." if estrelas > 0 else "A polícia viu o crime!")
		_perseguir_agora()
		return
	if op.get("so_policia", false):
		return
	if op.get("alarme", false):
		denuncia(d)
		return
	if op.get("vitima") != null:
		op["vitima"].crime = d
		jogo.hud.mensagem("O motorista vai chamar a polícia! Fuja ou chegue perto para impedir.", 3.5)
		return
	var t = jogo.pedestres.testemunha(p)
	if t != null:
		jogo.pedestres.ligar(t, d)
		jogo.hud.mensagem("Uma testemunha viu! Chegue perto dela para impedir a ligação.", 3.5)
	elif estrelas == 0:
		jogo.hud.mensagem("Ninguém viu.", 1.5)
	jogo.pedestres.panico(p, 18.0)


func vitima_vai_ligar(pd) -> void:
	if pd.crime != null:
		jogo.pedestres.ligar(pd, pd.crime)


func denuncia(d) -> void:
	if d == null:
		return
	registrar(d["carro"], d["roupa"])
	var ja := estrelas > 0
	aplicar(d["estrelas"], "Denúncia! A polícia está a caminho.")
	if not ja or modo == "limpo":
		modo = "busca"
		zona = {"c": d["p"], "r": raio()}
		sem_ver = 10.0
		fora_tempo = 0.0


func denuncia_cancelada(intimidado: bool) -> void:
	if intimidado:
		jogo.hud.mensagem("Você assustou a testemunha. Ela não ligou.", 2.5)


func evento_batida(a, b, forca: float) -> void:
	var meu = a if a.motorista == "jogador" else (b if b.motorista == "jogador" else null)
	if meu == null:
		return
	var outro = b if meu == a else a
	# quem bateu em quem? compara a velocidade de cada carro na direcao do outro
	var dir: Vector2 = (outro.pos - meu.pos).normalized()
	var culpa_minha: bool = meu.vel.dot(dir) > -outro.vel.dot(dir) + 1.0
	if not culpa_minha or carencia > 0.0:
		return
	if outro.policia and outro.motorista == "ia" and cd_batida <= 0.0:
		cd_batida = 4.0
		registrar(meu, -1)
		if estrelas == 0:
			aplicar(1, "Você bateu numa viatura!")
		else:
			aplicar(estrelas + 1, "Você bateu numa viatura! Mais uma estrela.")
		_perseguir_agora()
	elif not outro.policia and forca > 10.0 and cd_batida <= 0.0:
		cd_batida = 2.0
		crime("batida", meu.pos, 1, {"so_policia": true})


# ------------------------------------------------------------------ ciclo
func atualizar(dt: float) -> void:
	var jj = j()
	var p: Vector2 = jj.posicao()
	cd_batida -= dt
	cd_bloqueio -= dt
	cd_ataque -= dt
	cd_heli -= dt

	if carencia > 0.0:
		carencia -= dt
		vendo = false
	t_visao -= dt
	if carencia <= 0.0 and t_visao <= 0.0:
		t_visao = 0.15
		vendo = false
		for v in olhos():
			var d: float = v.pos.distance_to(p)
			if d < 60.0 and reconhece(d) and pode_ver(v, p):
				vendo = true
				break
		if not vendo and heli_ve() and modo != "limpo":
			vendo = true

	if vendo:
		if estrelas == 0:
			aplicar(1, "A polícia reconheceu você pela Ficha!")
		elif modo == "busca":
			jogo.hud.mensagem("A polícia te achou!", 1.8)
		_perseguir_agora()
		fora_tempo = 0.0
		registrar(jj.veiculo, -1 if jj.veiculo else jj.roupa_id)
	elif estrelas > 0:
		sem_ver += dt
		if modo == "perseguicao" and sem_ver > 2.5:
			modo = "busca"
			zona = {"c": ultima, "r": raio()}
			jogo.hud.mensagem("Perderam você de vista. Saia da área de busca!", 3.0)
		if modo == "busca" and zona != null:
			zona["r"] = raio()
			var fora: bool = p.distance_to(zona["c"]) > zona["r"]
			fora_tempo = fora_tempo + dt if fora else maxf(0.0, fora_tempo - dt * 0.5)
			if fora_tempo > 5.0 + 2.0 * estrelas:
				escapou()

	if modo == "perseguicao" and estrelas > 0:
		tempo_nivel += dt
		if estrelas == 1 and tempo_nivel > 25.0 and jj.veiculo:
			aplicar(2, "Você está fugindo: 2 estrelas!")
		elif estrelas == 2 and tempo_nivel > 50.0:
			aplicar(3, "Perseguição pesada: bloqueios nas ruas!")

	if estrelas == 0 and (ficha_carro() or ficha_roupa()) and jogo.tempo > ficha["expira"]:
		limpar_ficha("tudo")
		jogo.hud.mensagem("Sua Ficha esfriou. A polícia esqueceu você.", 2.5)

	_gerenciar_unidades(dt)
	_conduzir_unidades(dt)
	_atualizar_bloqueios(dt)
	_atualizar_heli(dt)
	_atualizar_prisao(dt)
	for v in jogo.veiculos:
		if v.policia:
			v.ligar_sirene(v.ia != null and (v.ia["tipo"] == "unidade" or v.ia["tipo"] == "bloqueio"), jogo.tempo)


func escapou() -> void:
	jogo.hud.mensagem("Você despistou a polícia! A Ficha continua por um tempo.", 3.5)
	jogo.audio.escapou()
	estrelas = 0
	modo = "limpo"
	zona = null
	prendendo = 0.0
	vendo = false
	t_visao = 0.0
	carencia = maxf(carencia, 2.0)
	ficha["expira"] = jogo.tempo + 150.0
	dispensar()


func limpar() -> void:
	estrelas = 0
	modo = "limpo"
	zona = null
	prendendo = 0.0
	vendo = false
	t_visao = 0.0
	sem_ver = 0.0
	carencia = 6.0
	limpar_ficha("tudo")
	dispensar()
	for b in bloqueios.duplicate():
		_remover_bloqueio(b)


func dispensar() -> void:
	for v in unidades():
		var n: Vector2i = jogo.mapa.nodo_mais_proximo(v.pos)
		Trafego.iniciar_ia(jogo, v, n, jogo.mapa.vizinhos(n).pick_random())
	if heli != null:
		heli["saindo"] = true


## O jogador atacou a policia (tiro em viatura ou helicoptero).
func atacada(msg: String) -> void:
	if cd_ataque > 0.0 or carencia > 0.0:
		return
	cd_ataque = 6.0
	var jj = j()
	registrar(jj.veiculo, -1 if jj.veiculo else jj.roupa_id)
	aplicar(3 if estrelas < 3 else estrelas + 1, msg)
	_perseguir_agora()


func dano_heli(dano: float) -> void:
	if heli == null or heli["saindo"]:
		return
	heli["vida"] -= dano * 0.35
	if heli["vida"] <= 0.0:
		var pos3 := Vector3(heli["pos"].x, heli["y"], heli["pos"].y)
		jogo.audio.tocar("explosao")
		jogo.hud.mensagem("Você derrubou o helicóptero! Outro vai demorar a chegar.", 3.0)
		_remover_heli()
		cd_heli = 60.0
		jogo.armas.explosao_visual(pos3)


# ------------------------------------------------------------------ unidades
func recrutar(v) -> void:
	v.motorista = "ia"
	v.ia = {"tipo": "unidade", "rota": [], "t_rota": 0.0, "alvo_busca": null, "preso": 0.0, "re": 0.0, "re_virar": 1.0}


func spawn_unidade() -> void:
	var jj = j()
	var p: Vector2 = jj.posicao()
	var f := U.frente(jj.heading())
	var cand := []
	for i in Mapa.N:
		for k in Mapa.N:
			var q := Mapa.nodo_pos(Vector2i(i, k))
			var d := q.distance_to(p)
			if d < 85.0 or d > 175.0:
				continue
			cand.append(q)
			if (q - p).dot(f) < 0.0:  # atras do jogador: peso maior
				cand.append(q)
				cand.append(q)
	if cand.is_empty():
		return
	var q: Vector2 = cand.pick_random()
	for v in jogo.veiculos:
		if v.pos.distance_to(q) < 9.0:
			return
	var nova := Veiculo.new(jogo, "viatura", q.x, q.y, U.heading_de(p - q))
	recrutar(nova)


func _gerenciar_unidades(dt: float) -> void:
	if unidades().size() < UNIDADES[estrelas]:
		t_spawn -= dt
		if t_spawn <= 0.0:
			t_spawn = 2.2
			var p: Vector2 = j().posicao()
			var patrulha = null
			for v in jogo.veiculos:
				if v.policia and v.ia != null and v.ia["tipo"] == "trafego" and v.pos.distance_to(p) < 170.0:
					patrulha = v
					break
			if patrulha != null:
				recrutar(patrulha)
			else:
				spawn_unidade()
	if estrelas >= 4 and (heli == null or heli["saindo"]) and cd_heli <= 0.0:
		_criar_heli()


func _alvo_por_rota(v, alvo: Vector2, dt: float) -> Vector2:
	var ia: Dictionary = v.ia
	ia["t_rota"] -= dt
	if ia["rota"].is_empty() or ia["t_rota"] <= 0.0:
		ia["t_rota"] = 1.0
		var pts: Array = jogo.mapa.rota_gps(v.pos, alvo).slice(1)
		if pts.size() >= 3:
			var a: Vector2 = pts[0]
			var b: Vector2 = pts[1]
			if v.pos.distance_to(b) < a.distance_to(b):
				pts.pop_front()
		ia["rota"] = pts
	var rota: Array = ia["rota"]
	while rota.size() > 1 and v.pos.distance_to(rota[0]) < 8.0:
		rota.pop_front()
	return rota[0] if not rota.is_empty() else alvo


func _ponto_na_zona() -> Vector2:
	var nos := []
	for i in Mapa.N:
		for k in Mapa.N:
			var q := Mapa.nodo_pos(Vector2i(i, k))
			if q.distance_to(zona["c"]) < zona["r"] + 10.0:
				nos.append(q)
	return nos.pick_random() if not nos.is_empty() else zona["c"]


func _conduzir_unidades(dt: float) -> void:
	var jj = j()
	var p: Vector2 = jj.posicao()
	for v in unidades():
		var ia: Dictionary = v.ia
		if ia["re"] > 0.0:
			ia["re"] -= dt
			v.ctrl = {"acel": 0.0, "freio": 1.0, "virar": ia["re_virar"], "freio_mao": false}
			continue
		var alvo: Vector2
		var vd: float
		var d: float = v.pos.distance_to(p)
		if modo == "perseguicao":
			if d < 90.0 and jogo.mapa.tem_visao(v.pos, p):
				var lead := clampf(d / 25.0, 0.0, 1.2)
				alvo = p + (jj.veiculo.vel * lead if jj.veiculo else Vector2.ZERO)
				vd = v.t["vmax"]
				if estrelas == 1 and d < 14.0:
					vd = maxf(4.0, jj.velocidade() + 1.5)
				if jj.veiculo == null:
					vd = minf(vd, maxf(0.0, (d - 5.0) * 1.2))
			else:
				alvo = _alvo_por_rota(v, p, dt)
				vd = v.t["vmax"] * 0.8
		elif modo == "busca" and zona != null:
			if ia["alvo_busca"] == null or v.pos.distance_to(ia["alvo_busca"]) < 10.0:
				ia["alvo_busca"] = _ponto_na_zona()
				ia["rota"] = []
			alvo = _alvo_por_rota(v, ia["alvo_busca"], dt)
			vd = 14.0
		else:
			continue
		Trafego.dirigir_para(v, alvo, vd, 2.6)
		if v.ctrl["acel"] > 0.3 and v.velocidade() < 1.0:
			ia["preso"] += dt
		else:
			ia["preso"] = maxf(0.0, ia["preso"] - dt)
		if ia["preso"] > 1.5:
			ia["preso"] = 0.0
			ia["re"] = 1.1
			ia["re_virar"] = -signf(v.ctrl["virar"]) if v.ctrl["virar"] != 0.0 else -1.0


# ------------------------------------------------------------------ prisao
func _atualizar_prisao(dt: float) -> void:
	var jj = j()
	if estrelas == 0 or modo != "perseguicao" or carencia > 0.0 or jogo.cena_prisao > 0.0 or jogo.cena_hospital > 0.0:
		prendendo = maxf(0.0, prendendo - dt * 2.0)
		return
	var lento: bool = jj.velocidade() < (2.0 if jj.veiculo else 3.5)
	var raio_p := 7.5 if jj.veiculo else 6.5
	var perto := false
	for v in olhos():
		if v.pos.distance_to(jj.posicao()) < raio_p and v.velocidade() < 4.0:
			perto = true
			break
	if lento and perto:
		prendendo += dt
	else:
		prendendo = maxf(0.0, prendendo - dt * 1.5)
	if prendendo > limite_prisao():
		jogo.preso()


## Com 3+ estrelas a policia atira mais e demora mais para prender.
func limite_prisao() -> float:
	return 2.5 if estrelas < 3 else 4.0


# ------------------------------------------------------------------ bloqueios
func _criar_bloqueio() -> bool:
	var jj = j()
	var v = jj.veiculo
	var p: Vector2 = jj.posicao()
	var f := U.frente(v.h)
	var n: Vector2i = jogo.mapa.nodo_mais_proximo(p)
	var eixo_z := absf(f.y) > absf(f.x)
	var s := signf(f.y if eixo_z else f.x)
	var ao_longo := p.y if eixo_z else p.x
	var lateral := Mapa.nodo_x(n.x) if eixo_z else Mapa.nodo_x(n.y)
	if absf((p.x if eixo_z else p.y) - lateral) > 5.0:
		return false
	var melhor = null
	for k in Mapa.N:
		var c := Mapa.nodo_x(k)
		var adiante := s * (c - ao_longo)
		if adiante > 70.0 and (melhor == null or adiante < s * (melhor - ao_longo)):
			melhor = c
	if melhor == null:
		return false
	var base: float = melhor - s * 20.0
	var rot := 0.0 if eixo_z else PI / 2.0
	var ponto := func(al: float, lat: float) -> Vector2: return Vector2(lateral + lat, al) if eixo_z else Vector2(al, lateral + lat)
	var b := {"objs": [], "obstaculos": [], "tapetes": [], "viatura": null, "p": ponto.call(base, 0.0)}

	for lat in [-2.8, 0.0, 2.8]:
		var q: Vector2 = ponto.call(base, lat)
		var o: Node3D = jogo.instanciar("barreira")
		o.position = Vector3(q.x, 0.02, q.y)
		o.rotation.y = rot
		jogo.add_child(o)
		b["objs"].append(o)
		b["obstaculos"].append(_obstaculo(o, q, 1.35))
	for lat in [-3.4, 3.4]:
		var q: Vector2 = ponto.call(base + s * 1.5, lat)
		var o: Node3D = jogo.instanciar("cone")
		o.position = Vector3(q.x, 0.02, q.y)
		jogo.add_child(o)
		b["objs"].append(o)
		b["obstaculos"].append(_obstaculo(o, q, 0.4))
	var pv: Vector2 = ponto.call(base + s * 6.0, 0.5)
	var via := Veiculo.new(jogo, "viatura", pv.x, pv.y, (PI / 2.0 if eixo_z else 0.0) + randf_range(-0.3, 0.3))
	via.estatico = true
	via.motorista = "ia"
	via.ia = {"tipo": "bloqueio"}
	b["viatura"] = via
	var pp: Vector2 = ponto.call(base + s * 4.0, -4.6)
	var pol: Node3D = jogo.instanciar("policial")
	pol.position = Vector3(pp.x, 0.17, pp.y)
	pol.rotation.y = U.heading_de(p - pp)
	jogo.add_child(pol)
	b["objs"].append(pol)
	if estrelas >= 3:
		for lat in [-2.0, 2.0]:
			var q: Vector2 = ponto.call(base - s * 22.0, lat)
			var o: Node3D = jogo.instanciar("tapete_pregos")
			o.position = Vector3(q.x, 0.02, q.y)
			o.rotation.y = rot
			jogo.add_child(o)
			b["objs"].append(o)
			var tp := {"p": q, "lx": 1.6 if eixo_z else 1.1, "lz": 1.1 if eixo_z else 1.6}
			jogo.tapetes.append(tp)
			b["tapetes"].append(tp)
	bloqueios.append(b)
	jogo.hud.mensagem("Bloqueio policial à frente! Desvie pela calçada.", 3.0)
	return true


func _obstaculo(obj: Node3D, p: Vector2, r: float) -> Obstaculo:
	var o := Obstaculo.new()
	o.obj = obj
	o.pos = p
	o.r = r
	o.jogo = jogo
	jogo.obstaculos.append(o)
	return o


func _remover_bloqueio(b: Dictionary) -> void:
	for o in b["objs"]:
		o.queue_free()
	for o in b["obstaculos"]:
		jogo.obstaculos.erase(o)
	for tp in b["tapetes"]:
		jogo.tapetes.erase(tp)
	if b["viatura"] != null and b["viatura"].motorista != "jogador" and b["viatura"].ativo:
		b["viatura"].remover()
	bloqueios.erase(b)


func _atualizar_bloqueios(dt: float) -> void:
	var jj = j()
	if estrelas >= 3 and modo == "perseguicao" and jj.veiculo != null and jj.velocidade() > 8.0 and cd_bloqueio <= 0.0 and bloqueios.size() < 2:
		cd_bloqueio = 26.0 if _criar_bloqueio() else 2.0
	for b in bloqueios.duplicate():
		var d: float = b["p"].distance_to(jj.posicao())
		if d > 200.0 or (estrelas == 0 and d > 80.0):
			_remover_bloqueio(b)
	for o in jogo.obstaculos:
		if o.voando == null:
			continue
		var vo: Dictionary = o.voando
		var vv: Vector3 = vo["v"]
		vv.y -= 20.0 * dt
		vo["v"] = vv
		o.obj.position += vv * dt
		o.obj.rotation.x += vo["giro"] * dt
		o.obj.rotation.z += vo["giro"] * 0.6 * dt
		if o.obj.position.y <= 0.02 and vv.y < 0.0:
			o.obj.position.y = 0.02
			o.voando = null


# ------------------------------------------------------------------ helicoptero
func _criar_heli() -> void:
	if heli != null:
		_remover_heli()
	var p: Vector2 = j().posicao()
	var obj: Node3D = jogo.instanciar("helicoptero_policia")
	jogo.add_child(obj)
	heli = {"obj": obj, "pos": p + Vector2(90, 90), "y": 45.0, "h": 0.0, "saindo": false, "vida": 100.0,
		"rotor": obj.find_child("rotor_principal", true, false), "cauda": obj.find_child("rotor_cauda", true, false)}
	jogo.hud.mensagem("Helicóptero da polícia no ar!", 3.0)


func _remover_heli() -> void:
	heli["obj"].queue_free()
	luz_heli.light_energy = 0.0
	heli = null


func _atualizar_heli(dt: float) -> void:
	if heli == null:
		return
	var jj = j()
	var p: Vector2 = jj.posicao()
	if estrelas < 4:
		heli["saindo"] = true
	var hp: Vector2 = heli["pos"]
	var alvo: Vector2
	var ty: float
	if heli["saindo"]:
		alvo = hp + (hp - p) * 2.0
		ty = 60.0
	else:
		var vv: Vector2 = jj.veiculo.vel if jj.veiculo else Vector2.ZERO
		alvo = p - vv * 0.6 + Vector2(10, 10)
		ty = 28.0
	var d := alvo - hp
	var passo := minf(d.length(), 24.0 * dt)
	if d.length() > 0.01:
		hp += d.normalized() * passo
	heli["pos"] = hp
	heli["y"] += (ty - heli["y"]) * minf(1.0, dt)
	heli["h"] += U.ang_diff(heli["h"], U.heading_de(p - hp)) * minf(1.0, dt * 2.0)
	var obj: Node3D = heli["obj"]
	obj.position = Vector3(hp.x, heli["y"], hp.y)
	obj.rotation = Vector3(-clampf(passo / maxf(dt, 0.001) / 24.0, 0.0, 1.0) * 0.18, heli["h"], 0.0)
	if heli["rotor"]:
		heli["rotor"].rotation.y += dt * 30.0
	if heli["cauda"]:
		heli["cauda"].rotation.x += dt * 40.0
	luz_heli.light_energy = 0.0 if heli["saindo"] else 6.0
	var origem := Vector3(hp.x, heli["y"] - 1.0, hp.y)
	var destino := Vector3(p.x, 0.0, p.y)
	if origem.distance_to(destino) > 0.5:
		luz_heli.look_at_from_position(origem, destino, Vector3.FORWARD if absf(origem.x - destino.x) < 0.01 and absf(origem.z - destino.z) < 0.01 else Vector3.UP)
	if heli["saindo"] and hp.distance_to(p) > 260.0:
		_remover_heli()
