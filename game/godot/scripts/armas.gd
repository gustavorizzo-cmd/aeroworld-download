class_name Armas
extends RefCounted
## Armas do jogador (inventario, tiro, soco), efeitos (rastro, clarao, impacto, explosao)
## e a policia atirando de volta com 3 estrelas ou mais.

const TIPOS := {
	"punho": {"nome": "Punhos", "dano": 0.0, "cadencia": 0.45, "alcance": 1.8, "preco": 0, "preco_municao": 0, "pacote": 0, "projeteis": 1, "dispersao": 0.0, "auto": false, "tam": 0.0},
	"pistola": {"nome": "Pistola", "dano": 34.0, "cadencia": 0.3, "alcance": 60.0, "preco": 400, "preco_municao": 60, "pacote": 36, "projeteis": 1, "dispersao": 0.012, "auto": false, "tam": 0.26},
	"escopeta": {"nome": "Escopeta", "dano": 20.0, "cadencia": 0.85, "alcance": 26.0, "preco": 900, "preco_municao": 90, "pacote": 16, "projeteis": 6, "dispersao": 0.065, "auto": false, "tam": 0.62},
	"submetralhadora": {"nome": "Submetralhadora", "dano": 16.0, "cadencia": 0.09, "alcance": 45.0, "preco": 1500, "preco_municao": 120, "pacote": 120, "projeteis": 1, "dispersao": 0.03, "auto": true, "tam": 0.5},
}
const ORDEM := ["punho", "pistola", "escopeta", "submetralhadora"]

var jogo
var inventario := {"punho": 0}  # arma -> municao
var atual := "punho"
var mirando := false
var cd := 0.0
var cd_crime := 0.0
var tiros_policia := 0  # contador (testes)
var efeitos: Array = []  # {no: Node3D, vida: float, total: float, tipo: String}
var queimando: Array = []  # carros prestes a explodir {v, t, fumaca}
var arma_mao: MeshInstance3D
var _mats := {}


func _init(p_jogo) -> void:
	jogo = p_jogo


func _mat(nome: String, cor: Color, sem_luz: bool = true) -> StandardMaterial3D:
	if not _mats.has(nome):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		if sem_luz:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if cor.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[nome] = m
	return _mats[nome]


## Coloca uma arma simples na mao direita do personagem.
func preparar_modelo(jogador) -> void:
	var braco: Node3D = jogador.membros[1]
	arma_mao = MeshInstance3D.new()
	arma_mao.mesh = BoxMesh.new()
	arma_mao.material_override = _mat("arma", Color("#23262b"), false)
	braco.add_child(arma_mao)
	_atualizar_modelo()


func _atualizar_modelo() -> void:
	if arma_mao == null:
		return
	var tam: float = TIPOS[atual]["tam"]
	arma_mao.visible = tam > 0.0
	if tam > 0.0:
		(arma_mao.mesh as BoxMesh).size = Vector3(0.07, tam, 0.11)
		arma_mao.position = Vector3(0.0, -0.7 - tam * 0.5, -0.02)


# ------------------------------------------------------------------ inventario
func tem(arma: String) -> bool:
	return inventario.has(arma)


func municao() -> int:
	return inventario.get(atual, 0)


func dar(arma: String, balas: int) -> void:
	inventario[arma] = inventario.get(arma, 0) + balas
	selecionar(arma)


func selecionar(arma: String) -> void:
	if tem(arma):
		atual = arma
		_atualizar_modelo()


func trocar(passo: int) -> void:
	var i := ORDEM.find(atual)
	for k in ORDEM.size():
		i = (i + passo + ORDEM.size()) % ORDEM.size()
		if tem(ORDEM[i]):
			selecionar(ORDEM[i])
			return


func confiscar() -> void:
	inventario = {"punho": 0}
	selecionar("punho")


func armado() -> bool:
	return atual != "punho"


# ------------------------------------------------------------------ quadro a quadro
func atualizar(dt: float, entrada, pode_agir: bool) -> void:
	cd -= dt
	cd_crime -= dt
	var jj = jogo.jogador
	var a_pe: bool = jj.veiculo == null and jj.caido <= 0.0
	mirando = pode_agir and a_pe and entrada.segurando("mirar")
	if pode_agir and a_pe:
		if entrada.apertou("arma_prox"):
			trocar(1)
		if entrada.apertou("arma_ant"):
			trocar(-1)
		for k in 4:
			if entrada.apertou("arma_%d" % (k + 1)) and tem(ORDEM[k]):
				selecionar(ORDEM[k])
		var t: Dictionary = TIPOS[atual]
		var gatilho: bool = entrada.apertou("atirar") or (t["auto"] and entrada.segurando("atirar"))
		if gatilho and cd <= 0.0:
			cd = t["cadencia"]
			if atual == "punho":
				_soco()
			elif municao() <= 0:
				jogo.audio.tocar("vazio")
				jogo.hud.dica("Sem munição. Compre mais no Arsenal do Porto.")
			else:
				inventario[atual] -= 1
				_disparar()
	if arma_mao:
		arma_mao.visible = a_pe and TIPOS[atual]["tam"] > 0.0
	_atualizar_efeitos(dt)
	_atualizar_queimando(dt)
	_policia_atira(dt)


# ------------------------------------------------------------------ tiro
func _disparar() -> void:
	var t: Dictionary = TIPOS[atual]
	var cam: Camera3D = jogo.camera
	var origem := cam.global_position
	var frente := -cam.global_basis.z
	var jj = jogo.jogador
	var boca := Vector3(jj.pos.x, jj.y + 1.45, jj.pos.y) + Vector3(U.frente(jj.h).x, 0, U.frente(jj.h).y) * 0.8
	var pular := origem.distance_to(boca) - 0.3
	var acertou_alguem := false
	for i in t["projeteis"]:
		var disp: float = t["dispersao"] * (0.5 if mirando else 1.6)
		var dir := (frente + cam.global_basis.x * randf_range(-disp, disp) + cam.global_basis.y * randf_range(-disp, disp)).normalized()
		var hit := raio(origem, dir, t["alcance"] + pular, pular)
		var fim: Vector3 = hit["ponto"]
		_rastro(boca, fim)
		_impacto(fim, hit["tipo"])
		if hit["tipo"] != "nada" and hit["tipo"] != "parede" and hit["tipo"] != "chao":
			acertou_alguem = true
			_aplicar_dano(hit, t["dano"], dir)
	_clarao(boca)
	jogo.audio.tiro(atual)
	jogo.pedestres.panico(jj.pos, 40.0)
	if cd_crime <= 0.0 and not acertou_alguem:
		cd_crime = 5.0
		jogo.crime("disparo", jj.pos, 1, {})


## Raio 3D contra pedestres, carros, helicoptero, predios e chao.
## Devolve {tipo, alvo, ponto}. Ignora tudo antes de `minimo` (atras do jogador).
func raio(o: Vector3, d: Vector3, alcance: float, minimo: float = 0.0) -> Dictionary:
	var melhor := alcance
	var res := {"tipo": "nada", "alvo": null}
	var o2 := Vector2(o.x, o.z)
	var d2 := Vector2(d.x, d.z)
	for pd in jogo.pedestres.lista:
		if pd.caido:
			continue
		var t := _cilindro(o, d, pd.pos, 0.45, pd.y, pd.y + 1.85)
		if t > minimo and t < melhor:
			melhor = t
			res = {"tipo": "pedestre", "alvo": pd}
	for v in jogo.veiculos:
		if v == jogo.jogador.veiculo or v.queimado:
			continue
		for c in v.circulos():
			var t := _cilindro(o, d, Vector2(c.x, c.y), c.z, v.y, v.y + 1.5)
			if t > minimo and t < melhor:
				melhor = t
				res = {"tipo": "veiculo", "alvo": v}
	var heli = jogo.policia.heli
	if heli != null:
		var centro := Vector3(heli["pos"].x, heli["y"] + 1.5, heli["pos"].y)
		var oc := o - centro
		var b := oc.dot(d)
		var cc := oc.length_squared() - 2.6 * 2.6
		var disc := b * b - cc
		if disc > 0.0:
			var t := -b - sqrt(disc)
			if t > minimo and t < melhor:
				melhor = t
				res = {"tipo": "heli", "alvo": null}
	# predios (altos: basta o teste no plano do chao)
	for k in jogo.mapa.caixas:
		if k.tipo != "predio":
			continue
		var t := _caixa2d(o2, d2, k)
		if t > minimo and t < melhor:
			melhor = t
			res = {"tipo": "parede", "alvo": null}
	if d.y < -0.001:
		var t := (o.y - 0.05) / -d.y
		if t > minimo and t < melhor:
			melhor = t
			res = {"tipo": "chao", "alvo": null}
	res["ponto"] = o + d * melhor
	return res


static func _cilindro(o: Vector3, d: Vector3, c: Vector2, r: float, y0: float, y1: float) -> float:
	var ox := o.x - c.x
	var oz := o.z - c.y
	var a := d.x * d.x + d.z * d.z
	if a < 1e-8:
		return INF
	var b := 2.0 * (ox * d.x + oz * d.z)
	var cc := ox * ox + oz * oz - r * r
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return INF
	var s := sqrt(disc)
	for t in [(-b - s) / (2.0 * a), (-b + s) / (2.0 * a)]:
		var y: float = o.y + d.y * t
		if t > 0.0 and y >= y0 and y <= y1:
			return t
	return INF


static func _caixa2d(o: Vector2, d: Vector2, k) -> float:
	var t0 := -INF
	var t1 := INF
	for eixo in 2:
		var oo: float = o.x if eixo == 0 else o.y
		var dd: float = d.x if eixo == 0 else d.y
		var mn: float = k.min_x if eixo == 0 else k.min_z
		var mx: float = k.max_x if eixo == 0 else k.max_z
		if absf(dd) < 1e-8:
			if oo < mn or oo > mx:
				return INF
			continue
		var ta := (mn - oo) / dd
		var tb := (mx - oo) / dd
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t1 < maxf(t0, 0.0):
		return INF
	return t0 if t0 > 0.0 else INF


func _aplicar_dano(hit: Dictionary, dano: float, dir: Vector3) -> void:
	var jj = jogo.jogador
	match hit["tipo"]:
		"pedestre":
			var pd = hit["alvo"]
			jogo.pedestres.derrubar(pd, Vector2(dir.x, dir.z) * 4.0, 2.0)
			if cd_crime <= 0.0:
				cd_crime = 3.0
				jogo.crime("tiro_pedestre", pd.pos, 3, {})
		"veiculo":
			var v = hit["alvo"]
			v.vida = maxf(0.0, v.vida - dano * 0.6)
			if v.policia and v.motorista == "ia":
				jogo.policia.atacada("Você atirou na polícia!")
			elif v.motorista == "ia" and v.ia != null and v.ia["tipo"] == "trafego":
				v.ia["preso"] = 0.0
			if v.vida <= 0.0:
				incendiar(v)
		"heli":
			jogo.policia.atacada("Você atirou no helicóptero!")
			jogo.policia.dano_heli(dano)


func _soco() -> void:
	var jj = jogo.jogador
	var f := U.frente(jj.h)
	jj.socar()
	for pd in jogo.pedestres.lista:
		if pd.caido:
			continue
		var rel: Vector2 = pd.pos - jj.pos
		if rel.length() < 1.8 and rel.normalized().dot(f) > 0.4:
			jogo.pedestres.derrubar(pd, f * 3.0, 1.5)
			jogo.audio.tocar("soco")
			jogo.crime("agressao", pd.pos, 1, {})
			return


# ------------------------------------------------------------------ policia atira
func _policia_atira(dt: float) -> void:
	var p = jogo.policia
	if p.estrelas < 3 or p.modo != "perseguicao" or p.carencia > 0.0 or jogo.cena_prisao > 0.0 or jogo.cena_hospital > 0.0:
		return
	var jj = jogo.jogador
	var alvo: Vector2 = jj.posicao()
	for v in p.olhos():
		if v.queimado:
			continue
		v.cd_tiro -= dt
		if v.cd_tiro > 0.0:
			continue
		var d: float = v.pos.distance_to(alvo)
		if d > 32.0 or not jogo.mapa.tem_visao(v.pos, alvo):
			v.cd_tiro = 0.5
			continue
		v.cd_tiro = randf_range(0.8, 1.5)
		tiros_policia += 1
		var chance := clampf(0.6 - d / 60.0 - jj.velocidade() * 0.012, 0.08, 0.6)
		var de := Vector3(v.pos.x, v.y + 1.3, v.pos.y)
		var para := Vector3(alvo.x, 1.2, alvo.y)
		if randf() < chance:
			jj.ferir(randf_range(6.0, 11.0) * (0.5 if jj.veiculo else 1.0))
		else:
			para += Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 1.0), randf_range(-1.5, 1.5))
		_rastro(de, para)
		_clarao(de)
		jogo.audio.tiro("pistola", 0.5)


# ------------------------------------------------------------------ carros queimando
func incendiar(v) -> void:
	if v.queimado or v.ia_queimando:
		return
	v.ia_queimando = true
	var fumaca := _fumaca()
	v.obj.add_child(fumaca)
	fumaca.position = Vector3(0, 1.2, -1.4)
	queimando.append({"v": v, "t": 4.0, "fumaca": fumaca})
	if v.motorista == "jogador":
		jogo.hud.mensagem("O carro está pegando fogo! Saia antes que exploda (E).", 3.0)


func _atualizar_queimando(dt: float) -> void:
	for q in queimando.duplicate():
		q["t"] -= dt
		if q["t"] <= 0.0:
			queimando.erase(q)
			explodir(q["v"])


func explodir(v) -> void:
	v.queimado = true
	v.vida = 0.0
	v.vel *= 0.3
	var queimado := _mat("queimado", Color("#1b1a19"), false)
	for mi in Veiculo.malhas(v.obj, []):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, queimado)
	explosao_visual(Vector3(v.pos.x, v.y + 1.0, v.pos.y))
	jogo.audio.tocar("explosao")
	jogo.pedestres.panico(v.pos, 45.0)
	var jj = jogo.jogador
	if v.motorista == "jogador":
		jj.ferir(70.0)
		jj.sair(true)
	elif jj.posicao().distance_to(v.pos) < 7.0:
		jj.ferir(55.0 * (1.0 - jj.posicao().distance_to(v.pos) / 7.0))
	for pd in jogo.pedestres.lista:
		if not pd.caido and pd.pos.distance_to(v.pos) < 6.0:
			jogo.pedestres.derrubar(pd, (pd.pos - v.pos).normalized() * 8.0, 6.0)
	for o in jogo.veiculos:
		if o != v and not o.queimado and o.pos.distance_to(v.pos) < 6.0:
			o.vida = maxf(0.0, o.vida - 45.0)
			o.vel += (o.pos - v.pos).normalized() * 6.0
			if o.vida <= 0.0:
				incendiar(o)
	if v.policia and v.ia != null and v.ia["tipo"] == "unidade":
		v.ia = null
		v.motorista = ""
	if v.motorista == "ia":
		v.ia = null
		v.motorista = ""


func explosao_visual(centro: Vector3) -> void:
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	bola.mesh = esfera
	bola.material_override = _mat("fogo", Color(1.0, 0.55, 0.15, 0.85))
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jogo.add_child(bola)
	bola.global_position = centro
	efeitos.append({"no": bola, "vida": 0.7, "total": 0.7, "tipo": "explosao"})


# ------------------------------------------------------------------ efeitos
func _rastro(de: Vector3, para: Vector3) -> void:
	var comp := de.distance_to(para)
	if comp < 0.1:
		return
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.03, 0.03, comp)
	mi.mesh = m
	mi.material_override = _mat("rastro", Color(1.0, 0.92, 0.55, 0.8))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jogo.add_child(mi)
	mi.global_position = (de + para) * 0.5
	if absf((para - de).normalized().dot(Vector3.UP)) < 0.99:
		mi.look_at(para, Vector3.UP)
	efeitos.append({"no": mi, "vida": 0.06, "total": 0.06, "tipo": "rastro"})


func _clarao(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.28
	mi.mesh = s
	mi.material_override = _mat("clarao", Color(1.0, 0.85, 0.4))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jogo.add_child(mi)
	mi.global_position = p
	efeitos.append({"no": mi, "vida": 0.05, "total": 0.05, "tipo": "clarao"})


func _impacto(p: Vector3, tipo: String) -> void:
	if tipo == "nada":
		return
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	mi.mesh = s
	mi.material_override = _mat("poeira", Color(0.85, 0.82, 0.75, 0.7))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jogo.add_child(mi)
	mi.global_position = p
	efeitos.append({"no": mi, "vida": 0.35, "total": 0.35, "tipo": "impacto"})


func _fumaca() -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 24
	f.lifetime = 1.6
	f.direction = Vector3.UP
	f.spread = 18.0
	f.initial_velocity_min = 1.5
	f.initial_velocity_max = 3.0
	f.gravity = Vector3(0, 0.6, 0)
	f.scale_amount_min = 0.6
	f.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.12, 0.12, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	f.mesh = q
	return f


func _atualizar_efeitos(dt: float) -> void:
	for e in efeitos.duplicate():
		e["vida"] -= dt
		var no: Node3D = e["no"]
		var k: float = 1.0 - e["vida"] / e["total"]
		if e["tipo"] == "explosao":
			no.scale = Vector3.ONE * (1.0 + k * 4.5)
		elif e["tipo"] == "impacto":
			no.scale = Vector3.ONE * (1.0 + k * 2.0)
		if e["vida"] <= 0.0:
			no.queue_free()
			efeitos.erase(e)
