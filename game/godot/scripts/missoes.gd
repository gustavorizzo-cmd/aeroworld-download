class_name Missoes
extends RefCounted
## As 3 missoes da versao 0.1. Cada etapa tem texto, alvo (para o GPS) e uma checagem.

var jogo
var lista: Array = []
var feitas := 0
var ativa = null
var etapa := 0
var ctx := {}
var marcador: Node3D
var marcador_alvo: Node3D


func _init(p_jogo) -> void:
	jogo = p_jogo
	var poi: Dictionary = jogo.mapa.poi
	lista = [
		{
			"id": "carro_de_luxo", "nome": "Carro de Luxo", "recompensa": 800,
			"resumo": "Um cliente quer o esportivo vermelho que fica no estacionamento da Orla.",
			"inicio": poi["casa"]["p"] + Vector2(-7, -2), "inicio_nome": "Casa Segura",
			"etapas": [
				{"texto": "Roube o esportivo vermelho no estacionamento da Orla.", "dica": "Se alguém vir o roubo, vai ligar para a polícia."},
				{"texto": "Leve o esportivo até o Armazém 3, no Porto. Cuide da lataria!", "dica": ""},
			],
		},
		{
			"id": "entrega_expressa", "nome": "Entrega Expressa", "recompensa": 500,
			"resumo": "O dono do Mercado da Orla precisa de uma encomenda na Torre Brasa, rápido.",
			"inicio": poi["loja"]["p"], "inicio_nome": "Mercado da Orla",
			"etapas": [
				{"texto": "Leve a encomenda até a Torre Brasa, no Centro. Use o carro amarelo do mercado.", "dica": ""},
			],
		},
		{
			"id": "encontro_furado", "nome": "Encontro Furado", "recompensa": 1500,
			"resumo": "Um contato marcou um encontro no Porto. Parece fácil demais.",
			"inicio": poi["praca"]["p"], "inicio_nome": "Praça do Centro",
			"etapas": [
				{"texto": "Vá ao encontro no Porto, entre os contêineres.", "dica": ""},
				{"texto": "Era uma armadilha! Despiste a polícia.", "dica": "Saia da área de busca e fique fora da vista. Troque de carro longe das viaturas."},
				{"texto": "Volte para a casa segura, no Subúrbio.", "dica": ""},
			],
		},
	]
	marcador = _criar_marcador(Color("#ffcc33"))
	marcador_alvo = _criar_marcador(Color("#22d3ee"))


func _criar_marcador(cor: Color) -> Node3D:
	var g := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(cor, 0.35)
	var coluna := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.4
	cm.height = 40.0
	cm.cap_top = false
	cm.cap_bottom = false
	coluna.mesh = cm
	coluna.material_override = mat
	coluna.position.y = 20.0
	coluna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var anel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.6
	tm.outer_radius = 2.2
	anel.mesh = tm
	var ma := mat.duplicate()
	ma.albedo_color = Color(cor, 0.9)
	anel.material_override = ma
	anel.scale = Vector3(1, 0.15, 1)
	anel.position.y = 0.25
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(coluna)
	g.add_child(anel)
	g.visible = false
	jogo.add_child(g)
	return g


func disponivel():
	return lista[feitas] if feitas < lista.size() else null


## Alvo atual para o GPS: {p, inicio} ou null.
func alvo_atual():
	if ativa != null:
		var a = _alvo(ativa["id"], etapa)
		return {"p": a, "inicio": false} if a != null else null
	var m = disponivel()
	return {"p": m["inicio"], "inicio": true} if m != null else null


func iniciar(m: Dictionary) -> void:
	ativa = m
	etapa = 0
	ctx = {}
	_preparar(m["id"])
	jogo.hud.banner(m["nome"], m["resumo"], 3.5)
	jogo.audio.missao()
	_entrar_etapa()


func _entrar_etapa() -> void:
	var e: Dictionary = ativa["etapas"][etapa]
	_iniciar_etapa(ativa["id"], etapa)
	if e["dica"] != "":
		jogo.hud.mensagem(e["dica"], 4.0)


func concluir() -> void:
	var m: Dictionary = ativa
	_limpar(m["id"], true)
	jogo.dinheiro += m["recompensa"]
	feitas += 1
	ativa = null
	jogo.salvar()
	jogo.hud.cronometro(-1.0)
	jogo.hud.banner("Missão cumprida", "%s  +%s" % [m["nome"], U.dinheiro(m["recompensa"])], 3.5)
	jogo.audio.missao()
	var textos := {
		"carro_de_luxo": "Valeu pelo esportivo. O dono do Mercado da Orla precisa de um entregador. Passa lá.",
		"entrega_expressa": "Tem um contato querendo te conhecer. Me encontra na Praça do Centro.",
		"encontro_furado": "Aquilo foi armação. Fica esperto e se arma: o Arsenal do Porto vende de tudo. Por enquanto é só.",
	}
	jogo.nova_mensagem("Rui", textos.get(m["id"], "Bom trabalho."))
	if disponivel() == null:
		jogo.hud.mensagem("Você terminou todas as missões desta versão. Explore Porto Brasa!", 5.0)


func falhar(motivo: String) -> void:
	if ativa == null:
		return
	_limpar(ativa["id"], false)
	ativa = null
	jogo.hud.cronometro(-1.0)
	jogo.hud.banner("Missão falhou", motivo, 3.5)


func recomecar() -> void:
	if ativa != null:
		falhar("Missões reiniciadas.")
	feitas = 0
	jogo.salvar()


func atualizar(dt: float) -> void:
	var jj = jogo.jogador
	if ativa == null:
		var m = disponivel()
		marcador_alvo.visible = false
		if m == null:
			marcador.visible = false
			return
		marcador.visible = true
		marcador.position = U.v3(m["inicio"])
		if jj.posicao().distance_to(m["inicio"]) < 3.5 and jj.velocidade() < 4.0 and jogo.policia.estrelas == 0:
			marcador.visible = false
			iniciar(m)
		return
	marcador.visible = false
	var r := _checar(ativa["id"], etapa, dt)
	if ativa == null:
		return
	var a = alvo_atual()
	marcador_alvo.visible = a != null
	if a != null:
		marcador_alvo.position = U.v3(a["p"])
	if r == "ok":
		etapa += 1
		if etapa >= ativa["etapas"].size():
			concluir()
		else:
			jogo.audio.etapa()
			_entrar_etapa()
	elif r.begins_with("falha:"):
		falhar(r.substr(6))


func texto_objetivo() -> Array:
	if ativa != null:
		return [ativa["nome"], ativa["etapas"][etapa]["texto"]]
	var m = disponivel()
	if m != null:
		return ["Próxima missão", "%s: vá até o marcador amarelo (%s)." % [m["nome"], m["inicio_nome"]]]
	return ["Mundo livre", "Todas as missões feitas. Explore a cidade."]


# ------------------------------------------------------------------ roteiro de cada missao
func _poi(nome: String) -> Vector2:
	return jogo.mapa.poi[nome]["p"]


func _preparar(id: String) -> void:
	match id:
		"carro_de_luxo":
			var e: Dictionary = jogo.mapa.poi["esportivo"]
			ctx["carro"] = Veiculo.new(jogo, "esportivo", e["p"].x, e["p"].y, e["h"], "#d7261e")
			ctx["carro"].missao = true
		"entrega_expressa":
			var p := _poi("loja") + Vector2(3.5, 6.5)
			ctx["carro"] = Veiculo.new(jogo, "sedan", p.x, p.y, PI, "#e0b53a")
			ctx["carro"].do_jogador = true  # carro do mercado: pegar nao e crime
			ctx["carro"].missao = true
			ctx["prazo"] = 95.0


func _limpar(id: String, ok: bool) -> void:
	var carro = ctx.get("carro")
	if carro == null or not carro.ativo:
		return
	match id:
		"carro_de_luxo":
			if ok or carro.motorista != "jogador":
				if carro.motorista == "jogador":
					jogo.jogador.sair()
				carro.remover()
			else:
				carro.missao = false
		"entrega_expressa":
			if carro.motorista != "jogador":
				carro.remover()
			else:
				carro.missao = false


func _iniciar_etapa(id: String, n: int) -> void:
	if id == "encontro_furado" and n == 1:
		var p = jogo.policia
		var jj = jogo.jogador
		p.aplicar(3, "Era uma armadilha! A polícia cercou o Porto!")
		p._perseguir_agora()
		p.registrar(jj.veiculo, -1 if jj.veiculo else jj.roupa_id)
		p.spawn_unidade()
		p.spawn_unidade()


func _alvo(id: String, n: int):
	var jj = jogo.jogador
	match id:
		"carro_de_luxo":
			if n == 0 or jj.veiculo != ctx["carro"]:
				return ctx["carro"].pos
			return _poi("galpao")
		"entrega_expressa":
			return _poi("torre")
		"encontro_furado":
			if n == 0:
				return _poi("encontro")
			if n == 1:
				return null
			return _poi("casa")
	return null


func _checar(id: String, n: int, dt: float) -> String:
	var jj = jogo.jogador
	var p: Vector2 = jj.posicao()
	match id:
		"carro_de_luxo":
			var carro = ctx["carro"]
			if n == 0:
				if carro.vida <= 0.0:
					return "falha:O esportivo foi destruído."
				return "ok" if jj.veiculo == carro else ""
			if carro.vida < 50.0:
				return "falha:O esportivo ficou amassado demais. O cliente desistiu."
			if jj.veiculo != carro:
				return ""
			if carro.pos.distance_to(_poi("galpao")) < 6.0 and carro.velocidade() < 3.0:
				if jogo.policia.estrelas > 0:
					jogo.hud.dica("Despiste a polícia antes de entregar o carro.")
					return ""
				return "ok"
		"entrega_expressa":
			ctx["prazo"] -= dt
			jogo.hud.cronometro(ctx["prazo"])
			if ctx["prazo"] <= 0.0:
				return "falha:Tempo esgotado. A encomenda chegou atrasada."
			if p.distance_to(_poi("torre")) < 7.0 and jj.velocidade() < 4.0:
				return "ok"
		"encontro_furado":
			if n == 0:
				return "ok" if p.distance_to(_poi("encontro")) < 7.0 else ""
			if n == 1:
				return "ok" if jogo.policia.estrelas == 0 else ""
			return "ok" if p.distance_to(_poi("casa")) < 5.0 else ""
	return ""
