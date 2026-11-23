extends RefCounted
## Testes automaticos. Rodar (sem janela):
##   godot --headless --path game/godot -- --teste=basico
##   godot --headless --path game/godot -- --teste=perseguicao
## Com janela e fotos (PB_FOTOS = pasta de saida):
##   PB_FOTOS=/tmp/fotos godot --path game/godot -- --teste=fotos

var jogo
var fotos := ""
var falhas: Array = []


func rodar(p_jogo) -> void:
	jogo = p_jogo
	fotos = OS.get_environment("PB_FOTOS")
	if jogo.modo_teste == "fotos":
		jogo.camera.position = Vector3(160, 70, 60)
		jogo.camera.look_at(Vector3.ZERO)
		await foto("00_inicio")
	jogo.interface.inicio.visible = false
	jogo.hud.raiz.visible = true
	match jogo.modo_teste:
		"basico":
			await _basico()
		"perseguicao":
			await _perseguicao()
		"parado":
			_parado()
		"renascer":
			_renascer()
		"fotos":
			await _basico()
			await _perseguicao()
	print("RESULTADO: ", "OK" if falhas.is_empty() else "FALHAS: " + ", ".join(falhas))


func checar(cond: bool, nome: String) -> void:
	print(("  [ok] " if cond else "  [FALHOU] ") + nome)
	if not cond:
		falhas.append(nome)


func estado(rot: String) -> void:
	var jj = jogo.jogador
	var v = jj.veiculo
	var p = jogo.policia
	var m = jogo.missoes
	var lig := 0
	for pd in jogo.pedestres.lista:
		if pd.estado == "ligando":
			lig += 1
	var pos: Vector2 = jj.posicao()
	print("%-20s pos=(%.0f,%.0f) carro=%s vida=%s est=%d modo=%s ficha=[carro:%s roupa:%s] missao=%s etapa=%d feitas=%d din=%d lig=%d" % [
		rot, pos.x, pos.y, v.tipo if v else "-", str(int(v.vida)) if v else "-", p.estrelas, p.modo,
		p.ficha_carro(), p.ficha_roupa(), m.ativa["nome"] if m.ativa else "-", m.etapa, m.feitas, int(jogo.dinheiro), lig])
	for t in jogo.hud.historico:
		print("    > ", t)
	jogo.hud.historico.clear()


func sim(seg: float) -> void:
	jogo.simular(seg)


func apertar(acao: String) -> void:
	jogo.entrada.apertar(acao)
	jogo.simular(1.0 / 30.0)


func ir(p: Vector2) -> void:
	var jj = jogo.jogador
	if jj.veiculo:
		jj.veiculo.pos = p
		jj.veiculo.vel = Vector2.ZERO
	else:
		jj.pos = p


func foto(nome: String) -> void:
	if fotos == "" or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await jogo.get_tree().process_frame
	var img: Image = jogo.get_viewport().get_texture().get_image()
	if img:
		img.save_png(fotos.path_join(nome + ".png"))
		print("    foto: ", nome)


func _basico() -> void:
	var poi: Dictionary = jogo.mapa.poi
	jogo.missoes.feitas = 0
	estado("inicio")
	checar(jogo.veiculos.size() > 10, "trânsito e carros estacionados criados")
	checar(jogo.pedestres.lista.size() > 20, "pedestres criados")
	checar(jogo.mapa.caixas.size() > 100, "colisores dos prédios criados")

	# dirigir o proprio carro
	var meu = null
	for v in jogo.veiculos:
		if v.do_jogador:
			meu = v
	ir(meu.pos + Vector2(-1.5, 1.8))
	sim(0.2)
	apertar("acao")
	checar(jogo.jogador.veiculo == meu, "entra no próprio carro com E")
	jogo.entrada.segurar("frente", true)
	var vmax := 0.0
	for i in 25:
		sim(0.1)
		vmax = maxf(vmax, meu.velocidade())
	jogo.entrada.segurar("direita", true)
	sim(0.6)
	jogo.entrada.segurar("direita", false)
	sim(1.0)
	estado("dirigindo")
	checar(vmax * 3.6 > 60.0, "carro acelera (>60 km/h)")
	await foto("01_dirigindo")
	jogo.entrada.segurar("frente", false)
	jogo.entrada.segurar("tras", true)
	for i in 40:
		sim(0.05)
		if meu.v_f < 0.5:
			break
	jogo.entrada.segurar("tras", false)
	sim(0.5)
	apertar("acao")
	checar(jogo.jogador.veiculo == null, "sai do carro")

	# Missao 1
	var m1: Dictionary = jogo.missoes.lista[0]
	ir(m1["inicio"])
	sim(0.5)
	estado("m1 inicio")
	checar(jogo.missoes.ativa != null and jogo.missoes.ativa["id"] == "carro_de_luxo", "missão 1 começa no marcador")
	var carro = jogo.missoes.ctx["carro"]
	ir(carro.pos + Vector2(2.2, 0))
	sim(0.3)
	apertar("acao")
	sim(0.5)
	estado("m1 roubou")
	checar(jogo.jogador.veiculo == carro, "rouba o esportivo")
	sim(5.0)
	await foto("02_esportivo")
	ir(poi["galpao"]["p"])
	sim(1.0)
	if jogo.policia.estrelas > 0:
		jogo.policia.escapou()
		sim(1.0)
	estado("m1 galpao")
	checar(jogo.missoes.feitas == 1, "missão 1 cumprida")

	# Missao 2
	ir(poi["loja"]["p"])
	sim(0.5)
	estado("m2 inicio")
	var c2 = jogo.missoes.ctx["carro"]
	ir(c2.pos + Vector2(-2.0, 0))
	sim(0.3)
	apertar("acao")
	sim(0.3)
	checar(jogo.jogador.veiculo == c2, "entra no carro do mercado")
	checar(jogo.policia.estrelas == 0, "carro do mercado não é crime")
	ir(poi["torre"]["p"])
	sim(1.0)
	estado("m2 entregou")
	checar(jogo.missoes.feitas == 2, "missão 2 cumprida")

	# Missao 3
	jogo.jogador.sair()
	sim(0.3)
	ir(poi["praca"]["p"])
	sim(0.5)
	ir(poi["encontro"]["p"])
	sim(0.5)
	estado("m3 encontro")
	checar(jogo.policia.estrelas == 3, "armadilha dá 3 estrelas")
	sim(4.0)
	await foto("03_armadilha")
	estado("m3 +4s")
	jogo.policia.escapou()
	sim(0.5)
	ir(poi["casa"]["p"])
	sim(0.5)
	estado("m3 casa")
	checar(jogo.missoes.feitas == 3, "missão 3 cumprida")

	# Oficina limpa a Ficha do carro
	ir(meu.pos + Vector2(-1.6, 1.6))
	sim(0.2)
	apertar("acao")
	sim(0.2)
	jogo.policia.registrar(jogo.jogador.veiculo, 2)
	ir(poi["oficina"]["p"])
	sim(3.0)
	estado("oficina")
	checar(not jogo.policia.ficha_carro(), "oficina tira o carro da Ficha")
	# Casa segura limpa a Ficha da roupa
	jogo.jogador.sair()
	sim(0.2)
	jogo.policia.registrar(null, jogo.jogador.roupa_id)
	ir(poi["casa"]["p"])
	sim(0.2)
	apertar("acao")
	sim(0.2)
	estado("casa roupa")
	checar(not jogo.policia.ficha_roupa(), "troca de roupa tira a roupa da Ficha")

	# Testemunha: roubar carro do transito com pedestre olhando
	var alvo = null
	for v in jogo.veiculos:
		if v.ia == null or v.ia["tipo"] != "trafego" or v.policia:
			continue
		for pd in jogo.pedestres.lista:
			if pd.estado == "andando" and pd.pos.distance_to(v.pos) < 25.0 and jogo.mapa.tem_visao(pd.pos, v.pos):
				alvo = v
				break
		if alvo:
			break
	if alvo:
		jogo.jogador.pos = alvo.pos + Vector2(2, 0)
		apertar("acao")
		estado("roubou trânsito")
		for i in 4:
			sim(2.0)
			estado("depois")
		checar(jogo.policia.estrelas >= 1, "denúncia da vítima dá estrela")
		checar(jogo.policia.ficha_carro(), "denúncia põe o carro na Ficha")
	else:
		print("  (sem carro com testemunha por perto; pulado)")

	# Prisao a pe
	if jogo.jogador.veiculo:
		jogo.jogador.veiculo.vel = Vector2.ZERO
		sim(0.5)
		jogo.jogador.sair()
	jogo.policia.aplicar(1)
	jogo.policia._perseguir_agora()
	jogo.policia.spawn_unidade()
	var preso := false
	for i in 30:
		sim(1.0)
		if jogo.cena_prisao > 0.0 or jogo.policia.estrelas == 0:
			preso = true
			break
	estado("prisão")
	checar(preso, "polícia prende o jogador parado")
	sim(3.0)


func _perseguicao() -> void:
	jogo.policia.limpar()
	var meu = null
	for v in jogo.veiculos:
		if v.do_jogador and v.ativo and v.tipo == "sedan":
			meu = v
	jogo.jogador.pos = meu.pos + Vector2(-1.5, 1.8)
	sim(0.2)
	apertar("acao")
	meu.pos = Vector2(-34, 170)
	meu.h = 0.0
	meu.vel = Vector2(0, -20)
	var p = jogo.policia
	p.aplicar(4)
	p._perseguir_agora()
	p.cd_bloqueio = 0.0
	jogo.entrada.segurar("frente", true)
	for i in 12:
		sim(0.5)
		estado("4 estrelas")
	jogo.entrada.segurar("frente", false)
	checar(p.heli != null, "helicóptero aparece com 4 estrelas")
	checar(p.bloqueios.size() > 0, "bloqueio policial criado")
	await foto("04_perseguicao")
	if p.bloqueios.size() > 0:
		var b: Dictionary = p.bloqueios[0]
		meu.pos = b["p"] + Vector2(2, 45)
		meu.h = 0.0
		meu.vel = Vector2.ZERO
		meu.pneus = false
		meu.vida = 100.0
		sim(0.3)
		await foto("05_bloqueio")
		meu.vel = Vector2(0, -25)
		jogo.entrada.segurar("frente", true)
		sim(2.0)
		jogo.entrada.segurar("frente", false)
		estado("passou bloqueio")
		checar(meu.pneus, "tapete de pregos fura os pneus")
	jogo.hud.alternar_mapa()
	await foto("06_mapa")
	jogo.hud.alternar_mapa()


## Reproduz "a policia me prende quando eu nasco": fica parado no inicio e depois anda a pe.
func _parado() -> void:
	for i in 24:
		sim(2.5)
		var p = jogo.policia
		var perto := 99999.0
		for v in jogo.veiculos:
			if v.policia:
				perto = minf(perto, v.pos.distance_to(jogo.jogador.posicao()))
		estado("t=%.0f viatura a %.0f m prend=%.1f" % [jogo.tempo, perto, p.prendendo])


## Bug relatado: depois de preso, ao renascer na casa segura a policia prendia de novo.
func _renascer() -> void:
	var p = jogo.policia
	var meu = null
	for v in jogo.veiculos:
		if v.do_jogador:
			meu = v
	jogo.jogador.pos = meu.pos + Vector2(-1.5, 1.8)
	sim(0.2)
	apertar("acao")
	meu.pos = Vector2(-34, 120)
	meu.vel = Vector2.ZERO
	p.aplicar(2)
	p._perseguir_agora()
	p.spawn_unidade()
	p.spawn_unidade()
	var prisoes := 0
	var estava_preso := false
	for i in 120:
		sim(0.5)
		if jogo.cena_prisao > 0.0 and not estava_preso:
			prisoes += 1
			estado("PRESO #%d" % prisoes)
		estava_preso = jogo.cena_prisao > 0.0
	estado("fim")
	checar(prisoes == 1, "preso só uma vez (sem prisão em ciclo ao renascer)")
	checar(p.estrelas == 0, "sem estrelas depois de renascer")
