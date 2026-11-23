class_name Mapa
extends Node3D
## Cidade de Porto Brasa: grade de ruas N x N, quarteiroes de 60 x 60 m,
## bairros, colisores (caixas e circulos), grafo de ruas e GPS.

const N := 6
const ESP := 72.0
const MEIO := 2.5
const BORDA := 186.0  # borda externa da calcada
const LIM_MIN := Vector2(-250.0, -250.0)
const LIM_MAX := Vector2(236.0, 250.0)
const CEL := 20.0

const DISTRITOS := {
	"centro": {"nome": "Centro", "cor": "#a39d92", "mapa": "#5d6470"},
	"orla": {"nome": "Orla", "cor": "#d8c9a2", "mapa": "#7a6f55"},
	"porto": {"nome": "Porto", "cor": "#8d8a84", "mapa": "#4a5560"},
	"suburbio": {"nome": "Subúrbio", "cor": "#6f914a", "mapa": "#4f6b3e"},
}


class Caixa:
	var min_x: float
	var max_x: float
	var min_z: float
	var max_z: float
	var tipo: String

	func _init(a: float, b: float, c: float, d: float, t: String) -> void:
		min_x = a
		max_x = b
		min_z = c
		max_z = d
		tipo = t


var caixas: Array = []
var circulos: Array = []  # Vector3(x, z, raio)
var celulas := {}
var blocos: Array = []  # {bi, bj, c: Vector2, distrito}
var estacionados: Array = []  # {p: Vector2, h}
var poi := {}  # nome -> {p: Vector2, nome, h}
var lojas: Array = []  # mercados: {p: porta, id}
var rng := RandomNumberGenerator.new()
var fusao := Fusao.new()
var _mats := {}
var jogo


static func nodo_x(i: int) -> float:
	return (i - MEIO) * ESP


static func nodo_pos(n: Vector2i) -> Vector2:
	return Vector2(nodo_x(n.x), nodo_x(n.y))


static func distrito_do_bloco(bi: int, bj: int) -> String:
	if bi == 4:
		return "orla"
	if bi == 0 or (bi == 1 and bj >= 3):
		return "porto"
	if bj >= 3:
		return "suburbio"
	return "centro"


func sorte() -> float:
	return rng.randf()


# ------------------------------------------------------------------ consultas
func eh_rua(x: float, z: float) -> bool:
	if absf(x) > BORDA + 0.5 or absf(z) > BORDA + 0.5:
		return false
	var i := roundi(x / ESP + MEIO)
	var j := roundi(z / ESP + MEIO)
	if i >= 0 and i < N and absf(x - nodo_x(i)) < 4.0:
		return true
	if j >= 0 and j < N and absf(z - nodo_x(j)) < 4.0:
		return true
	return false


func altura_chao(x: float, z: float) -> float:
	if absf(x) <= BORDA and absf(z) <= BORDA:
		return 0.02 if eh_rua(x, z) else 0.17
	if x > BORDA:
		return 0.06
	return 0.0


func distrito(p: Vector2) -> String:
	var bi := roundi(p.x / ESP + 2.0)
	var bj := roundi(p.y / ESP + 2.0)
	if bi < 0 or bi > 4 or bj < 0 or bj > 4:
		return ""
	return distrito_do_bloco(bi, bj)


func nodo_mais_proximo(p: Vector2) -> Vector2i:
	return Vector2i(clampi(roundi(p.x / ESP + MEIO), 0, N - 1), clampi(roundi(p.y / ESP + MEIO), 0, N - 1))


func vizinhos(n: Vector2i) -> Array:
	var v := []
	if n.x > 0:
		v.append(Vector2i(n.x - 1, n.y))
	if n.x < N - 1:
		v.append(Vector2i(n.x + 1, n.y))
	if n.y > 0:
		v.append(Vector2i(n.x, n.y - 1))
	if n.y < N - 1:
		v.append(Vector2i(n.x, n.y + 1))
	return v


func rota(a: Vector2i, b: Vector2i) -> Array:
	var ant := {a: null}
	var fila := [a]
	while not fila.is_empty():
		var n: Vector2i = fila.pop_front()
		if n == b:
			break
		for v in vizinhos(n):
			if not ant.has(v):
				ant[v] = n
				fila.append(v)
	var caminho := []
	var atual = b
	while atual != null:
		caminho.push_front(atual)
		atual = ant.get(atual)
	return caminho


## Rota de GPS entre dois pontos (lista de Vector2).
func rota_gps(a: Vector2, b: Vector2) -> Array:
	var pts := [a]
	for n in rota(nodo_mais_proximo(a), nodo_mais_proximo(b)):
		pts.append(nodo_pos(n))
	pts.append(b)
	return pts


func _indexar(obj, a: float, b: float, c: float, d: float, lista: String) -> void:
	for cx in range(floori(a / CEL), floori(b / CEL) + 1):
		for cz in range(floori(c / CEL), floori(d / CEL) + 1):
			var k := Vector2i(cx, cz)
			if not celulas.has(k):
				celulas[k] = {"caixas": [], "circulos": []}
			celulas[k][lista].append(obj)


func proximos(p: Vector2, raio: float) -> Dictionary:
	var cs := {}
	var ci := {}
	for cx in range(floori((p.x - raio) / CEL), floori((p.x + raio) / CEL) + 1):
		for cz in range(floori((p.y - raio) / CEL), floori((p.y + raio) / CEL) + 1):
			var c = celulas.get(Vector2i(cx, cz))
			if c == null:
				continue
			for o in c["caixas"]:
				cs[o] = true
			for o in c["circulos"]:
				ci[o] = true
	return {"caixas": cs.keys(), "circulos": ci.keys()}


func add_caixa(a: float, b: float, c: float, d: float, tipo: String = "predio") -> Caixa:
	var k := Caixa.new(a, b, c, d, tipo)
	caixas.append(k)
	_indexar(k, a, b, c, d, "caixas")
	return k


func add_circulo(x: float, z: float, r: float) -> void:
	var c := Vector3(x, z, r)
	circulos.append(c)
	_indexar(c, x - r, x + r, z - r, z + r, "circulos")


## Linha de visao 2D: algum predio entre A e B?
func tem_visao(a: Vector2, b: Vector2) -> bool:
	var mn := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var mx := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	var d := b - a
	for c in caixas:
		if c.tipo != "predio":
			continue
		if c.max_x < mn.x or c.min_x > mx.x or c.max_z < mn.y or c.min_z > mx.y:
			continue
		var t0 := 0.0
		var t1 := 1.0
		var ok := true
		var testes := [[-d.x, a.x - c.min_x], [d.x, c.max_x - a.x], [-d.y, a.y - c.min_z], [d.y, c.max_z - a.y]]
		for par in testes:
			var pp: float = par[0]
			var q: float = par[1]
			if pp == 0.0:
				if q < 0.0:
					ok = false
					break
				continue
			var tt := q / pp
			if pp < 0.0:
				if tt > t1:
					ok = false
					break
				t0 = maxf(t0, tt)
			else:
				if tt < t0:
					ok = false
					break
				t1 = minf(t1, tt)
		if ok and t0 <= t1:
			return false
	return true


# ------------------------------------------------------------------ montagem
func material(cor: String) -> StandardMaterial3D:
	if not _mats.has(cor):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(cor)
		m.roughness = 0.95
		m.metallic_specular = 0.15
		_mats[cor] = m
	return _mats[cor]


func colocar(nome: String, x: float, z: float, rot: float = 0.0, op: Dictionary = {}) -> void:
	var y: float = op.get("y", altura_chao(x, z))
	var b := Basis(Vector3.UP, rot)
	if op.has("escala_y"):
		b = b * Basis.from_scale(Vector3(1.0, op["escala_y"], 1.0))
	var paleta := {}
	if op.has("paleta"):
		paleta[op["paleta"][0]] = fusao.material_paleta(nome, op["paleta"][0], Color(op["paleta"][1]))
	var a := fusao.adicionar(nome, Transform3D(b, Vector3(x, y, z)), paleta)
	if op.get("caixa", false):
		var m: float = op.get("margem", 0.15)
		add_caixa(a.position.x + m, a.end.x - m, a.position.z + m, a.end.z - m, op.get("tipo", "predio"))
	if op.has("raio"):
		add_circulo(x, z, op["raio"])


func caixa_chao(x: float, z: float, lx: float, lz: float, cor: String, y: float = 0.07, alt: float = 0.2) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(lx, alt, lz)
	var origem := Vector3(x, y, z)
	fusao.adicionar_arrays(bm.get_mesh_arrays(), material(cor), Transform3D(Basis.IDENTITY, origem), Fusao.pedaco_de(origem))


func construir(p_jogo) -> void:
	jogo = p_jogo
	rng.seed = 20261123
	for nome in jogo.modelos:
		fusao.preparar(nome, jogo.modelos[nome])
	_construir_ruas()
	for bi in 5:
		for bj in 5:
			_construir_bloco(bi, bj)
	_construir_praia()
	_construir_props()
	fusao.construir(self)

	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	chao.mesh = pm
	chao.material_override = material("#a19d6c")
	chao.position.y = -0.02
	add_child(chao)
	var agua := MeshInstance3D.new()
	var am := PlaneMesh.new()
	am.size = Vector2(800, 1400)
	agua.mesh = am
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color("#2c9db5")
	ma.roughness = 0.15
	ma.metallic = 0.2
	agua.material_override = ma
	agua.position = Vector3(BORDA + 46.0 + 400.0, 0.08, 0.0)
	add_child(agua)


func _construir_ruas() -> void:
	for i in N:
		for j in N:
			var x := nodo_x(i)
			var z := nodo_x(j)
			colocar("rua_cruzamento", x, z, 0.0, {"y": 0.0})
			for k in range(1, 6):
				if j < N - 1:
					colocar("rua_reta", x, z + k * 12.0, 0.0, {"y": 0.0})
				if i < N - 1:
					colocar("rua_reta", x + k * 12.0, z, PI / 2.0, {"y": 0.0})


func _construir_bloco(bi: int, bj: int) -> void:
	var cx := (bi - 2) * ESP
	var cz := (bj - 2) * ESP
	var d := distrito_do_bloco(bi, bj)
	blocos.append({"bi": bi, "bj": bj, "c": Vector2(cx, cz), "distrito": d})
	caixa_chao(cx, cz, 60.0, 60.0, DISTRITOS[d]["cor"])

	if d == "centro":
		var lugares := [[-17.0, -16.0, 0.0], [17.0, -16.0, 0.0], [-17.0, 16.0, PI], [17.0, 16.0, PI]]
		var loja_idx := int(sorte() * 5.0)  # as vezes nenhuma (indice 4)
		for idx in lugares.size():
			var l: Array = lugares[idx]
			var x: float = l[0]
			var z: float = l[1]
			if idx == loja_idx:
				colocar("loja", cx + x, cz + z + (-9.0 if z < 0.0 else 9.0), l[2], {"caixa": true})
				_registrar_loja(cx + x, cz + z + (-9.0 if z < 0.0 else 9.0), l[2])
			else:
				colocar("predio_centro", cx + x, cz + z, l[2], {"caixa": true, "escala_y": 0.5 + sorte() * 0.75})
		colocar("palmeira", cx - 3.0, cz, sorte() * 6.0, {"raio": 0.35})
		colocar("palmeira", cx + 4.0, cz + 2.0, sorte() * 6.0, {"raio": 0.35})
		colocar("lixeira", cx, cz + 4.0, 0.0, {"raio": 0.3})
		if bi == 2 and bj == 0:
			poi["torre"] = {"p": Vector2(cx + 17.0, cz - 25.5), "nome": "Torre Brasa"}
		if bi == 1 and bj == 1:
			poi["praca"] = {"p": Vector2(cx, cz - 6.0), "nome": "Praça do Centro"}

	elif d == "orla":
		var leste := -PI / 2.0  # frente para +X (avenida da orla)
		if bj == 1:
			colocar("oficina_pintura", cx + 20.0, cz, leste, {"caixa": true})
			poi["oficina"] = {"p": Vector2(cx + 29.0, cz - 1.5), "nome": "Oficina de Pintura"}
		else:
			colocar("loja", cx + 20.0, cz - 14.0, leste, {"caixa": true})
			_registrar_loja(cx + 20.0, cz - 14.0, leste)
			if bj == 3:
				poi["loja"] = {"p": Vector2(cx + 26.5, cz - 12.0), "nome": "Mercado da Orla"}
		if bj == 3:
			caixa_chao(cx + 14.0, cz + 16.0, 26.0, 18.0, "#5a5a5e", 0.072, 0.2)
			poi["esportivo"] = {"p": Vector2(cx + 14.0, cz + 16.0), "h": PI / 2.0, "nome": "Estacionamento"}
		else:
			colocar("casa_suburbio", cx + 20.0, cz + 14.0, leste, {"caixa": true, "paleta": ["Pintura_Casa", "#f2c9a0"]})
		colocar("predio_centro", cx - 16.0, cz - 12.0, PI / 2.0, {"caixa": true, "escala_y": 0.35 + sorte() * 0.3})
		colocar("palmeira", cx - 10.0, cz + 14.0, sorte() * 6.0, {"raio": 0.35})
		colocar("palmeira", cx - 20.0, cz + 18.0, sorte() * 6.0, {"raio": 0.35})

	elif d == "porto":
		var cor_galpao: String = ["#9aa3a8", "#b59a6a", "#8fa08a"][bj % 3]
		colocar("galpao_porto", cx, cz - 5.0, 0.0, {"caixa": true, "paleta": ["Pintura_Galpao", cor_galpao]})
		if bi == 0 and bj == 3:
			poi["galpao"] = {"p": Vector2(cx - 7.0, cz - 20.4), "nome": "Armazém 3"}
		if bi == 0 and bj == 2:
			poi["arsenal"] = {"p": Vector2(cx + 7.0, cz - 20.0), "nome": "Arsenal do Porto"}
			_placa("ARSENAL DO PORTO", Vector3(cx + 7.0, 5.2, cz - 15.85), PI, Color("#ff5a4a"))
		if bi == 0 and bj == 1:
			poi["encontro"] = {"p": Vector2(cx + 8.0, cz + 22.0), "nome": "Encontro no Porto"}
		var cores := ["#1f5f8b", "#b8362b", "#2f7d4a", "#d08a22", "#6a6f75"]
		var x := -22.0
		while x <= 22.0:
			var pular := (bi == 0 and bj == 1 and absf(x - 8.0) < 7.0) or sorte() < 0.25
			if not pular:
				var alt := 2 if sorte() < 0.4 else 1
				for hh in alt:
					colocar("conteiner", cx + x, cz + 21.0, hh * 0.04, {"y": 0.17 + hh * 2.59, "paleta": ["Pintura_Conteiner", cores[int(sorte() * cores.size())]]})
				add_caixa(cx + x - 1.3, cx + x + 1.3, cz + 17.9, cz + 24.1)
			x += 4.4

	elif d == "suburbio":
		var cores := ["#e9d6a6", "#bfe0d2", "#f2b8a0", "#d6d0f0", "#f4efe4"]
		for x in [-18.0, 0.0, 18.0]:
			for zr in [[-15.0, 0.0], [15.0, PI]]:
				var z: float = zr[0]
				var segura: bool = bi == 3 and bj == 3 and x == 0.0 and z == -15.0
				var cor: String = "#7fb3d5" if segura else cores[int(sorte() * cores.size())]
				colocar("casa_suburbio", cx + x, cz + z, zr[1], {"caixa": true, "paleta": ["Pintura_Casa", cor]})
				if segura:
					poi["casa"] = {"p": Vector2(cx + x - 1.6, cz + z - 6.4), "nome": "Casa Segura"}
				elif sorte() < 0.35:
					var fz := -24.0 if z < 0.0 else 24.0
					estacionados.append({"p": Vector2(cx + x + 3.2, cz + fz), "h": PI / 2.0 if z < 0.0 else -PI / 2.0})
		if sorte() < 0.6:
			colocar("palmeira", cx + 9.0, cz, sorte() * 6.0, {"raio": 0.35})


## A porta do mercado fica na frente, do lado direito da fachada.
func _registrar_loja(x: float, z: float, rot: float) -> void:
	var c := Vector2(x, z)
	lojas.append({"p": c + U.frente(rot) * 5.6 + U.direita(rot) * 3.7, "id": lojas.size()})


## Letreiro 3D (texto + fundo) numa fachada.
func _placa(texto: String, p: Vector3, rot: float, cor: Color) -> void:
	var fundo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.2, 1.0, 0.2)
	fundo.mesh = bm
	fundo.material_override = material("#1b1d22")
	fundo.position = p
	fundo.rotation.y = rot
	add_child(fundo)
	var l := Label3D.new()
	l.text = texto
	l.font_size = 120
	l.pixel_size = 0.0058
	l.modulate = cor
	l.outline_size = 0
	l.double_sided = false
	l.position = p + Basis(Vector3.UP, rot) * Vector3(0, 0, 0.12)
	l.rotation.y = rot
	add_child(l)


func _construir_praia() -> void:
	caixa_chao(BORDA + 30.0, 0.0, 60.0, 2.0 * BORDA + 60.0, "#e8d3a0", 0.0, 0.12)
	var z := -BORDA + 6.0
	while z <= BORDA:
		colocar("palmeira", BORDA + 2.5 + sorte() * 2.0, z, sorte() * 6.0, {"raio": 0.35, "y": 0.06})
		if sorte() < 0.5:
			colocar("palmeira", BORDA + 16.0 + sorte() * 18.0, z + 5.0, sorte() * 6.0, {"raio": 0.35, "y": 0.06})
		z += 13.0


func _construir_props() -> void:
	for i in N:
		for j in N:
			var x := nodo_x(i)
			var z := nodo_x(j)
			colocar("semaforo", x + 5.0, z + 5.0, PI, {"raio": 0.25})
			colocar("semaforo", x - 5.0, z - 5.0, 0.0, {"raio": 0.25})
			var trechos := [15.0, 39.0, 63.0]
			for k in trechos.size():
				var s: float = trechos[k]
				var lado := 1.0 if k % 2 == 0 else -1.0
				if j < N - 1:
					colocar("poste", x + lado * 5.4, z + s, U.heading_de(Vector2(-lado, 0.0)), {"raio": 0.25})
				if i < N - 1:
					colocar("poste", x + s, z + lado * 5.4, U.heading_de(Vector2(0.0, -lado)), {"raio": 0.25})
			if j < N - 1 and sorte() < 0.5:
				colocar("hidrante", x - 5.3, z + 27.0, 0.0, {"raio": 0.25})
			if i < N - 1 and sorte() < 0.5:
				colocar("lixeira", x + 50.0, z + 5.4, 0.0, {"raio": 0.3})
