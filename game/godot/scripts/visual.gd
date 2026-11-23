class_name Visual
extends RefCounted
## Realismo: texturas de detalhe geradas por codigo (ruido) aplicadas em projecao
## triplanar no mundo (nao precisa de UV), verniz nos carros e vidros que refletem.

static var _tex := {}


static func avancado() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Textura de ruido sem emendas. normal=true gera mapa de relevo.
static func ruido(chave: String, freq: float, oitavas: int, normal: bool, forca: float, tipo: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> NoiseTexture2D:
	if _tex.has(chave):
		return _tex[chave]
	var n := FastNoiseLite.new()
	n.noise_type = tipo
	n.frequency = freq
	n.fractal_octaves = oitavas
	n.seed = hash(chave)
	if tipo == FastNoiseLite.TYPE_CELLULAR:
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = forca
	else:
		var g := Gradient.new()
		g.set_color(0, Color(1.0 - forca, 1.0 - forca, 1.0 - forca))
		g.set_color(1, Color.WHITE)
		t.color_ramp = g
	_tex[chave] = t
	return t


## Disco macio (centro opaco, borda transparente) para fumaca e poeira.
static func textura_fumaca() -> GradientTexture2D:
	if _tex.has("fumaca"):
		return _tex["fumaca"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_tex["fumaca"] = t
	return t


static func _triplanar(m: BaseMaterial3D, escala: float) -> void:
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * escala
	m.uv1_triplanar_sharpness = 4.0


## Aplica detalhe conforme o tipo de superficie.
static func detalhar(m: BaseMaterial3D, tipo: String) -> void:
	if m == null or m.has_meta("detalhado"):
		return
	m.set_meta("detalhado", true)
	match tipo:
		"asfalto":
			_triplanar(m, 0.35)
			m.albedo_texture = ruido("asfalto", 0.06, 5, false, 0.28)
			m.normal_enabled = true
			m.normal_texture = ruido("asfalto_n", 0.25, 3, true, 3.0)
			m.normal_scale = 0.5
			m.roughness = 0.92
		"calcada":
			_triplanar(m, 0.5)
			m.albedo_texture = ruido("calcada", 0.035, 1, false, 0.22, FastNoiseLite.TYPE_CELLULAR)
			m.normal_enabled = true
			m.normal_texture = ruido("calcada_n", 0.035, 1, true, 6.0, FastNoiseLite.TYPE_CELLULAR)
			m.normal_scale = 0.6
		"concreto":
			_triplanar(m, 0.3)
			m.albedo_texture = ruido("concreto", 0.02, 4, false, 0.18)
			m.normal_enabled = true
			m.normal_texture = ruido("concreto_n", 0.15, 3, true, 2.0)
			m.normal_scale = 0.35
		"grama":
			_triplanar(m, 0.25)
			m.albedo_texture = ruido("grama", 0.03, 5, false, 0.35)
			m.normal_enabled = true
			m.normal_texture = ruido("grama_n", 0.3, 2, true, 4.0)
			m.normal_scale = 0.4
			m.roughness = 1.0
		"areia":
			_triplanar(m, 0.2)
			m.albedo_texture = ruido("areia", 0.015, 4, false, 0.15)
			m.normal_enabled = true
			m.normal_texture = ruido("areia_n", 0.08, 3, true, 2.5)
			m.normal_scale = 0.5
		"agua":
			_triplanar(m, 0.06)
			m.normal_enabled = true
			m.normal_texture = ruido("agua_n", 0.04, 3, true, 5.0)
			m.normal_scale = 0.8
			m.roughness = 0.04
			m.metallic = 0.15
			m.metallic_specular = 0.7
		"metal":
			_triplanar(m, 0.5)
			m.normal_enabled = true
			m.normal_texture = ruido("metal_n", 0.4, 2, true, 1.2)
			m.normal_scale = 0.25


## Ajusta os materiais importados do Blender pelo nome.
static func ajustar_importado(b: BaseMaterial3D) -> void:
	var nome := b.resource_name
	var adv := avancado()
	match nome:
		"Asfalto":
			detalhar(b, "asfalto")
		"Calcada":
			detalhar(b, "calcada")
		"Meio_Fio", "Concreto", "Concreto_Escuro":
			detalhar(b, "concreto")
		"Pintura_Galpao", "Pintura_Conteiner", "Metal", "Metal_Escuro":
			detalhar(b, "metal")
	if nome.begins_with("Pintura_") and nome in ["Pintura_Sedan", "Pintura_Esportivo", "Pintura_Viatura", "Pintura_Helicoptero"]:
		# pintura de carro: metalica com verniz
		b.metallic = 0.45
		b.roughness = 0.32
		b.clearcoat_enabled = true
		b.clearcoat = 0.8
		b.clearcoat_roughness = 0.08
	if nome.begins_with("Vidro"):
		if adv:
			b.metallic = 0.75
			b.roughness = 0.05
		else:
			b.metallic = minf(b.metallic, 0.3)
			b.roughness = maxf(b.roughness, 0.25)
	if nome in ["Aro", "Cromado"]:
		b.metallic = 0.9
		b.roughness = 0.2
	if nome == "Pneu":
		b.roughness = 0.95
