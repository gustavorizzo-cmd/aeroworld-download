class_name Veiculo
extends RefCounted
## Carro com fisica arcade (derrapagem, freio de mao, lataria, pneus furados).

const TIPOS := {
	"sedan": {"modelo": "carro_sedan", "prefixo": "Pintura_Sedan", "vmax": 30.0, "acel": 9.0, "re": 8.0, "grip": 7.0, "esterco": 0.62, "raio": 0.95, "meio": 1.3, "massa": 1.0, "entre": 2.7},
	"esportivo": {"modelo": "carro_esportivo", "prefixo": "Pintura_Esportivo", "vmax": 44.0, "acel": 15.0, "re": 9.0, "grip": 8.0, "esterco": 0.6, "raio": 1.0, "meio": 1.35, "massa": 1.0, "entre": 2.9},
	"viatura": {"modelo": "viatura_policia", "prefixo": "Pintura_Viatura", "vmax": 37.0, "acel": 13.0, "re": 9.0, "grip": 8.0, "esterco": 0.62, "raio": 0.95, "meio": 1.35, "massa": 1.25, "entre": 2.7},
}
const CORES := ["#2f6db5", "#c8c8c4", "#2b2b2e", "#8a1f24", "#e0b53a", "#3d7a4f", "#e8e6df", "#5b4c8a", "#c4672f", "#1d4a6b"]

static var _proximo_id := 1

var jogo
var id := 0
var tipo := ""
var t: Dictionary
var obj: Node3D
var rodas: Array = []
var pinturas: Array = []
var sirenes: Array = []
var cor := Color.WHITE
var pos := Vector2.ZERO
var h := 0.0
var y := 0.0
var vel := Vector2.ZERO
var v_f := 0.0
var steer := 0.0
var giro := 0.0
var vida := 100.0
var pneus := false
var motorista := ""  # "jogador", "ia" ou ""
var ia = null  # Dictionary com o estado da IA
var policia := false
var ctrl := {"acel": 0.0, "freio": 0.0, "virar": 0.0, "freio_mao": false}
var ativo := true
var missao := false
var fixo := false
var do_jogador := false
var estatico := false
var sirene_ligada := false
var derrapando := false
var queimado := false
var ia_queimando := false
var cd_tiro := 0.0
var inclina := Vector2.ZERO  # (pitch, roll) suavizados: o carro "senta" na freada e deita na curva
var _vf_antes := 0.0
var lanternas: Array = []
var fumaca_pneu: CPUParticles3D


func _init(p_jogo, p_tipo: String, x: float, z: float, p_h: float, p_cor = null) -> void:
	jogo = p_jogo
	id = _proximo_id
	_proximo_id += 1
	tipo = p_tipo
	t = TIPOS[tipo]
	obj = jogo.instanciar(t["modelo"])
	policia = tipo == "viatura"
	if p_cor != null:
		cor = Color(p_cor)
		pinturas = Veiculo.pintar(obj, t["prefixo"], cor)
	for n in ["roda_diant_esq", "roda_diant_dir", "roda_tras_esq", "roda_tras_dir"]:
		rodas.append(obj.find_child(n, true, false))
	pos = Vector2(x, z)
	h = p_h
	y = jogo.mapa.altura_chao(x, z)
	if policia:
		_preparar_sirenes()
	_preparar_lanternas()
	jogo.add_child(obj)
	jogo.veiculos.append(self)
	sincronizar()


static func malhas(no: Node, lista: Array = []) -> Array:
	if no is MeshInstance3D:
		lista.append(no)
	for c in no.get_children():
		malhas(c, lista)
	return lista


## Troca a cor dos materiais cujo nome comeca com `prefixo` (copia so para este objeto).
static func pintar(no: Node, prefixo: String, p_cor: Color) -> Array:
	var feitos := {}
	for mi in malhas(no, []):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m == null or not m.resource_name.begins_with(prefixo):
				continue
			if not feitos.has(m):
				var d: BaseMaterial3D = m.duplicate()
				d.albedo_color = p_cor
				feitos[m] = d
			mi.set_surface_override_material(s, feitos[m])
	return feitos.values()


func _preparar_sirenes() -> void:
	for nome in ["sirene_vermelha", "sirene_azul"]:
		var no := obj.find_child(nome, true, false)
		if no == null:
			continue
		var mats := []
		for mi in malhas(no, []):
			for s in mi.mesh.get_surface_count():
				var d: BaseMaterial3D = mi.mesh.surface_get_material(s).duplicate()
				mi.set_surface_override_material(s, d)
				mats.append(d)
		sirenes.append(mats)
	ligar_sirene(false, 0.0)


func _preparar_lanternas() -> void:
	var feitos := {}
	for mi in malhas(obj, []):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s)
			if m == null:
				m = mi.mesh.surface_get_material(s)
			if m == null or m.resource_name != "Lanterna":
				continue
			if not feitos.has(m):
				feitos[m] = m.duplicate()
			mi.set_surface_override_material(s, feitos[m])
	lanternas = feitos.values()


func _fumaca_pneus() -> void:
	fumaca_pneu = CPUParticles3D.new()
	fumaca_pneu.amount = 40
	fumaca_pneu.lifetime = 1.4
	fumaca_pneu.emitting = false
	fumaca_pneu.local_coords = false
	fumaca_pneu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fumaca_pneu.emission_box_extents = Vector3(0.8, 0.05, 0.2)
	fumaca_pneu.direction = Vector3.UP
	fumaca_pneu.spread = 35.0
	fumaca_pneu.initial_velocity_min = 0.6
	fumaca_pneu.initial_velocity_max = 1.6
	fumaca_pneu.gravity = Vector3(0, 0.4, 0)
	fumaca_pneu.scale_amount_min = 0.7
	fumaca_pneu.scale_amount_max = 1.6
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.4))
	curva.add_point(Vector2(1, 1.6))
	fumaca_pneu.scale_amount_curve = curva
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.85, 0.85, 0.5))
	grad.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	fumaca_pneu.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Visual.textura_fumaca()
	q.material = m
	fumaca_pneu.mesh = q
	obj.add_child(fumaca_pneu)
	fumaca_pneu.position = Vector3(0, 0.15, t["meio"])


func ligar_sirene(ligada: bool, tempo: float) -> void:
	if sirenes.is_empty():
		return
	sirene_ligada = ligada
	var fase := int(tempo * 6.0) % 2
	for i in sirenes.size():
		var forca := (6.0 if i == fase else 0.15) if ligada else 0.25
		for m in sirenes[i]:
			m.emission_energy_multiplier = forca


func repintar(p_cor: Color) -> void:
	cor = p_cor
	if pinturas.is_empty():
		pinturas = Veiculo.pintar(obj, t["prefixo"], p_cor)
	else:
		for m in pinturas:
			m.albedo_color = p_cor


func velocidade() -> float:
	return vel.length()


func circulos() -> Array:
	var f := U.frente(h)
	var m: float = t["meio"]
	var r: float = t["raio"]
	return [Vector3(pos.x + f.x * m, pos.y + f.y * m, r), Vector3(pos.x - f.x * m, pos.y - f.y * m, r)]


func dano(forca: float) -> void:
	var antes := vida
	vida = maxf(0.0, vida - (forca - 5.0) * 1.7)
	if antes > 0.0 and vida <= 0.0:
		jogo.armas.incendiar(self)


func atualizar(dt: float) -> void:
	var f := U.frente(h)
	var r := U.direita(h)
	var vf := vel.dot(f)
	var vr := vel.dot(r)
	var morto := vida <= 0.0
	var vmax: float = t["vmax"] * (0.5 if pneus else 1.0) * (0.75 if vida < 30.0 else 1.0)
	var acel: float = ctrl["acel"]
	var freio: float = ctrl["freio"]
	var freio_mao: bool = ctrl["freio_mao"]

	if acel > 0.0 and not morto and vf < vmax:
		vf += t["acel"] * acel * (1.0 - maxf(0.0, vf) / vmax * 0.55) * dt
	if freio > 0.0:
		if vf > 0.4:
			vf -= 24.0 * freio * dt
		elif not morto and vf > -t["re"]:
			vf -= t["acel"] * 0.6 * freio * dt
	if acel <= 0.0 and freio <= 0.0:
		vf -= vf * 0.45 * dt
		vf -= signf(vf) * minf(absf(vf), 0.8 * dt)
	var grip: float = t["grip"] * (0.4 if pneus else 1.0)
	if freio_mao:
		grip = 1.1
		vf -= vf * 0.9 * dt
	vr *= exp(-grip * dt)

	var alvo: float = clampf(ctrl["virar"], -1.0, 1.0) * t["esterco"] / (1.0 + absf(vf) * 0.045)
	steer = U.suavizar(steer, alvo, 9.0, dt)
	var yaw: float = vf / t["entre"] * tan(steer)
	if freio_mao:
		yaw *= 1.6
	if pneus:
		yaw += sin(Time.get_ticks_msec() / 180.0) * 0.12 * minf(1.0, absf(vf) / 10.0)
	h -= yaw * dt

	vel = U.frente(h) * vf + U.direita(h) * vr
	pos += vel * dt
	# inclinacao da carroceria: frente desce na freada, sobe na aceleracao; deita na curva
	var acel_long := (vf - _vf_antes) / maxf(dt, 0.001)
	_vf_antes = vf
	var alvo_inc := Vector2(clampf(acel_long * 0.0045, -0.055, 0.045), clampf(vf * yaw * 0.0042, -0.075, 0.075))
	inclina = inclina.lerp(alvo_inc, 1.0 - exp(-6.0 * dt))
	v_f = vf
	derrapando = absf(vr) > 4.0
	giro -= vf / 0.36 * dt
	y = U.suavizar(y, jogo.mapa.altura_chao(pos.x, pos.y), 14.0, dt)


func sincronizar() -> void:
	obj.position = Vector3(pos.x, y, pos.y)
	obj.rotation = Vector3(inclina.x, h, inclina.y)
	# luz de freio: acende ao frear ou dar re
	if not lanternas.is_empty():
		var freando: bool = ctrl["freio"] > 0.05 and not queimado
		for m in lanternas:
			m.emission_energy_multiplier = 3.5 if freando else 0.8
	# fumaca dos pneus so no carro do jogador (derrapagem ou freio de mao em velocidade)
	if motorista == "jogador":
		if fumaca_pneu == null:
			_fumaca_pneus()
		fumaca_pneu.emitting = (derrapando or (ctrl["freio_mao"] and absf(v_f) > 7.0)) and velocidade() > 5.0
	elif fumaca_pneu != null:
		fumaca_pneu.emitting = false
	for i in rodas.size():
		var roda: Node3D = rodas[i]
		if roda:
			roda.rotation = Vector3(giro, -steer if i < 2 else 0.0, 0.0)


func remover() -> void:
	ativo = false
	obj.queue_free()
	jogo.veiculos.erase(self)
