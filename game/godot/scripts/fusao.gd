class_name Fusao
extends RefCounted
## Junta a geometria estatica da cidade em poucas malhas (uma por material e por
## pedaco de 120 m), para a cena ter poucas chamadas de desenho.

const TAM_PEDACO := 120.0


class Grupo:
	var mat: Material
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var i := PackedInt32Array()


var cache := {}  # nome do modelo -> lista de superficies {arrays, mat, xform}
var caixas := {}  # nome do modelo -> AABB local
var grupos := {}
var _paleta := {}


static func pedaco_de(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / TAM_PEDACO), floori(p.z / TAM_PEDACO))


func preparar(nome: String, cena: PackedScene) -> void:
	var inst := cena.instantiate()
	var lista := []
	_visitar(inst, Transform3D.IDENTITY, lista)
	var caixa := AABB()
	var primeiro := true
	for e in lista:
		_ajustar_material(e["mat"])
		var a: AABB = e["xform"] * (e["aabb"] as AABB)
		caixa = a if primeiro else caixa.merge(a)
		primeiro = false
	inst.free()
	cache[nome] = lista
	caixas[nome] = caixa


## Luzes emissivas mais contidas; no semaforo estatico so o vermelho fica aceso.
static func _ajustar_material(m: Material) -> void:
	if not (m is BaseMaterial3D) or m.has_meta("ajustado"):
		return
	var b: BaseMaterial3D = m
	b.set_meta("ajustado", true)
	if b.emission_enabled:
		b.emission_energy_multiplier = minf(b.emission_energy_multiplier, 1.6)
		if b.resource_name in ["Luz_Amarela", "Luz_Verde"]:
			b.emission_energy_multiplier = 0.08
			b.albedo_color = b.albedo_color.darkened(0.6)
	if b.resource_name in ["Calcada", "Asfalto", "Meio_Fio", "Concreto", "Concreto_Escuro", "Faixa_Branca"]:
		b.metallic_specular = 0.15
	if b.resource_name.begins_with("Vidro"):
		b.metallic = minf(b.metallic, 0.3)
		b.roughness = maxf(b.roughness, 0.25)


func _visitar(no: Node, acc: Transform3D, lista: Array) -> void:
	var t := acc
	if no is Node3D:
		t = acc * (no as Node3D).transform
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		var mesh: Mesh = (no as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			lista.append({"arrays": mesh.surface_get_arrays(s), "mat": mesh.surface_get_material(s), "xform": t, "aabb": mesh.get_aabb()})
	for c in no.get_children():
		_visitar(c, t, lista)


## Material de paleta: copia do material original com outra cor (compartilhado por cor).
func material_paleta(nome: String, prefixo: String, cor: Color) -> Material:
	var chave := "%s|%s" % [prefixo, cor.to_html()]
	if _paleta.has(chave):
		return _paleta[chave]
	for e in cache[nome]:
		var m: Material = e["mat"]
		if m and m.resource_name.begins_with(prefixo):
			var d: BaseMaterial3D = m.duplicate()
			d.albedo_color = cor
			_paleta[chave] = d
			return d
	return null


func adicionar(nome: String, xform: Transform3D, paleta: Dictionary = {}) -> AABB:
	var pedaco := pedaco_de(xform.origin)
	for e in cache[nome]:
		var mat: Material = e["mat"]
		if mat:
			for pref in paleta:
				if mat.resource_name.begins_with(pref):
					mat = paleta[pref]
		adicionar_arrays(e["arrays"], mat, xform * (e["xform"] as Transform3D), pedaco)
	return xform * (caixas[nome] as AABB)


func adicionar_arrays(arr: Array, mat: Material, t: Transform3D, pedaco: Vector2i) -> void:
	var v: PackedVector3Array = t * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var nb := Transform3D(t.basis.inverse().transposed(), Vector3.ZERO)
	var n: PackedVector3Array = nb * (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)
	var chave := "%d,%d,%d" % [pedaco.x, pedaco.y, mat.get_instance_id() if mat else 0]
	if not grupos.has(chave):
		var novo := Grupo.new()
		novo.mat = mat
		grupos[chave] = novo
	var g: Grupo = grupos[chave]
	var base := g.v.size()
	var idx = arr[Mesh.ARRAY_INDEX]
	var local := PackedInt32Array()
	if idx == null or (idx as PackedInt32Array).is_empty():
		local.resize(v.size())
		for k in v.size():
			local[k] = base + k
	else:
		var orig: PackedInt32Array = idx
		local.resize(orig.size())
		for k in orig.size():
			local[k] = orig[k] + base
	g.v.append_array(v)
	g.n.append_array(n)
	g.i.append_array(local)


func construir(pai: Node3D) -> void:
	for chave in grupos:
		var g: Grupo = grupos[chave]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_INDEX] = g.i
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(0, g.mat)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		pai.add_child(mi)
	grupos.clear()
