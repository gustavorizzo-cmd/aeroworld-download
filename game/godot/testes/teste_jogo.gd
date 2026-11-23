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
		"interacoes":
			await _interacoes()
		"visual":
			await _visual()
		"toque":
			await _toque()
		"placa":
			var a: Vector2 = jogo.mapa.poi["arsenal"]["p"]
			jogo.jogador.pos = a + Vector2(-4, -6)
			jogo.simular(0.5)
			jogo.camera.global_position = Vector3(a.x - 3.0, 4.0, a.y - 16.0)
			jogo.camera.look_at(Vector3(a.x, 5.0, a.y + 4.0), Vector3.UP)
			await foto("11_placa")
		"fotos":
			await _basico()
			await _perseguicao()
			await _interacoes()
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
		var max_estrelas: int = jogo.policia.estrelas
		var ficha_carro: bool = jogo.policia.ficha_carro()
		for i in 4:
			sim(2.0)
			estado("depois")
			max_estrelas = maxi(max_estrelas, jogo.policia.estrelas)
			ficha_carro = ficha_carro or jogo.policia.ficha_carro()
		checar(max_estrelas >= 1, "roubo com testemunha (vítima ou polícia) dá estrela")
		checar(ficha_carro, "o carro roubado entra na Ficha")
	else:
		print("  (sem carro com testemunha por perto; pulado)")

	# Prisao a pe
	if jogo.jogador.veiculo:
		jogo.jogador.veiculo.vel = Vector2.ZERO
		sim(0.5)
		jogo.jogador.sair()
	jogo.jogador.pos = Mapa.nodo_pos(Vector2i(3, 2)) + Vector2(5.0, 5.0)
	sim(0.2)
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
		var em_cena: bool = jogo.cena_prisao > 0.0 or jogo.cena_hospital > 0.0
		if em_cena and not estava_preso:
			prisoes += 1
			estado("PRESO/HOSPITAL #%d" % prisoes)
		estava_preso = em_cena
	estado("fim")
	checar(prisoes == 1, "preso (ou hospital) só uma vez, sem ciclo ao renascer")
	checar(p.estrelas == 0, "sem estrelas depois de renascer")


## Mercado, celular, armas, policia atirando, hospital, assalto, advogado, explosao.
func _interacoes() -> void:
	var p = jogo.policia
	var jj = jogo.jogador
	var poi: Dictionary = jogo.mapa.poi
	if jj.veiculo:
		jj.veiculo.vel = Vector2.ZERO
		jj.sair(true)
	p.limpar()
	sim(7.0)
	jogo.dinheiro = 6000.0
	jj.vida = 100.0
	jj.colete = 0.0
	jogo.armas.confiscar()

	# celular
	jogo.celular.abrir()
	checar(jogo.ui_aberta == "celular", "celular abre")
	await foto("07_celular")
	jogo.missoes.feitas = 3
	var r: String = jogo.celular.pedir_trabalho()
	print("    ", r)
	jogo.celular.ir("carteira")
	jogo.celular.fechar()
	checar(jogo.ui_aberta == "", "celular fecha")
	jogo.celular.taxi("Arsenal do Porto")
	sim(0.5)
	checar(jj.pos.distance_to(poi["arsenal"]["p"]) < 3.0, "táxi leva ao Arsenal")
	checar(int(jogo.dinheiro) == 5960, "táxi cobra R$ 40")

	# arsenal
	apertar("acao")
	checar(jogo.ui_aberta == "loja", "entra no Arsenal com E")
	print("    ", jogo.loja_ui.comprar("pistola"))
	print("    ", jogo.loja_ui.comprar("submetralhadora"))
	print("    ", jogo.loja_ui.comprar("colete"))
	await foto("08_arsenal")
	jogo.loja_ui.fechar()
	checar(jogo.armas.tem("pistola") and jogo.armas.tem("submetralhadora"), "compra pistola e submetralhadora")
	checar(jj.colete >= 100.0, "compra colete")
	jogo.armas.selecionar("pistola")
	var balas: int = jogo.armas.municao()
	jj.h = PI
	jogo.camera.yaw = PI
	jogo.entrada.segurar("mirar", true)
	sim(0.8)
	await foto("10_mirando")
	jogo.entrada.segurar("mirar", false)

	# atirar num pedestre
	var alvo = null
	for pd in jogo.pedestres.lista:
		if not pd.caido and pd.estado == "andando":
			alvo = pd
			break
	# na mesma calcada, 7 m atras do pedestre (fora da rua)
	jj.pos = alvo.bloco["c"] + Pedestres.pos_perimetro(alvo.s - 7.0 * alvo.dir)["p"]
	jj.caido = 0.0
	jj.h = U.heading_de(alvo.pos - jj.pos)
	jj.obj.position = Vector3(jj.pos.x, jj.y, jj.pos.y)
	var olho := Vector3(jj.pos.x, jj.y + 1.7, jj.pos.y) - Vector3(U.frente(jj.h).x, 0, U.frente(jj.h).y) * 2.0
	jogo.camera.global_position = olho
	jogo.camera.look_at(Vector3(alvo.pos.x, alvo.y + 1.1, alvo.pos.y), Vector3.UP)
	var caidos_antes := 0
	for pd in jogo.pedestres.lista:
		if pd.caido:
			caidos_antes += 1
	jogo.entrada.apertar("atirar")
	jogo.simular(1.0 / 30.0)  # a arma usa a camera antes de ela se mover neste passo
	estado("tiro no pedestre")
	var caidos := 0
	for pd in jogo.pedestres.lista:
		if pd.caido:
			caidos += 1
	checar(caidos > caidos_antes, "tiro derruba o pedestre")
	checar(jogo.armas.municao() == balas - 1, "tiro gasta munição")
	sim(6.0)
	estado("depois do tiro")

	# policia atira de volta com 3 estrelas (numa esquina, a vista)
	p.limpar()
	jj.pos = Mapa.nodo_pos(Vector2i(2, 2)) + Vector2(5.0, 5.0)
	sim(7.0)
	p.aplicar(3)
	p._perseguir_agora()
	p.registrar(null, jj.roupa_id)  # a policia conhece a roupa: reconhece de mais longe
	p.spawn_unidade()
	p.spawn_unidade()
	var antes: float = jj.vida + jj.colete
	var tiros_antes: int = jogo.armas.tiros_policia
	for i in 45:
		sim(1.0)
		if jogo.cena_prisao > 0.0 or jj.vida + jj.colete < antes:
			break
	estado("polícia atirou: %d tiros, dano %.0f" % [jogo.armas.tiros_policia - tiros_antes, antes - jj.vida - jj.colete])
	checar(jogo.armas.tiros_policia > tiros_antes, "polícia atira no jogador com 3 estrelas")

	# hospital
	if jogo.cena_prisao > 0.0:
		sim(3.0)
	jj.ferir(1000.0)
	checar(jogo.cena_hospital > 0.0, "vida zerada leva ao hospital")
	sim(3.5)
	estado("hospital")
	checar(jj.vida >= 100.0 and p.estrelas == 0, "volta da casa segura com vida cheia e sem estrelas")
	sim(7.0)

	# assalto ao mercado
	if not jogo.armas.tem("pistola"):
		jogo.armas.dar("pistola", 36)
	jogo.armas.selecionar("pistola")
	var loja: Dictionary = jogo.mapa.lojas[0]
	jj.pos = loja["p"]
	sim(0.3)
	apertar("acao")
	checar(jogo.ui_aberta == "loja", "entra no Mercado com E")
	jj.vida = 50.0
	print("    ", jogo.loja_ui.comprar("pastel"))
	checar(jj.vida >= 99.0, "pastel recupera vida")
	await foto("09_mercado")
	var din: float = jogo.dinheiro
	jogo.loja_ui.assaltar()
	estado("assalto")
	checar(jogo.dinheiro > din and p.estrelas == 2, "assalto dá dinheiro e 2 estrelas (câmera)")

	# advogado baixa estrela durante a busca
	p.modo = "busca"
	print("    ", jogo.celular.advogado())
	checar(p.estrelas == 1, "advogado baixa 1 estrela na busca")

	# explosao de carro
	var carro = null
	for v in jogo.veiculos:
		if not v.policia and v.motorista != "jogador" and not v.queimado:
			carro = v
			break
	carro.vida = 3.0
	carro.dano(30.0)
	sim(4.5)
	checar(carro.queimado, "carro destruído pega fogo e explode")

	# mecanico traz o carro
	print("    ", jogo.celular.mecanico())
	var tem_carro := false
	for v in jogo.veiculos:
		if v.do_jogador and v.pos.distance_to(jj.pos) < 60.0:
			tem_carro = true
	checar(tem_carro, "mecânico deixa o carro perto")

	# preso perde as armas
	p.aplicar(1)
	jogo.preso()
	checar(not jogo.armas.tem("pistola"), "preso perde as armas")
	sim(3.0)


## Fotos para conferir o visual e a animacao (rodar com janela, Forward+ se houver Vulkan).
func _visual() -> void:
	var jj = jogo.jogador
	var poi: Dictionary = jogo.mapa.poi
	jogo.policia.carencia = 9999.0
	print("    renderizador: ", RenderingServer.get_current_rendering_method())
	# calcada do Suburbio, andando para o norte
	jj.pos = poi["casa"]["p"] + Vector2(10.0, -14.0)
	jj.h = 0.0
	jogo.camera.yaw = 0.0
	sim(1.0)
	jogo.entrada.segurar("frente", true)
	sim(1.15)
	await foto("v1_andando")
	_camera_lado(jj, 3.2)
	await foto("v2_andando_lado")
	jogo.entrada.segurar("correr", true)
	sim(1.0)
	_camera_lado(jj, 3.6)
	await foto("v3_correndo_lado")
	jogo.entrada.segurar("correr", false)
	jogo.entrada.segurar("frente", false)
	sim(1.5)
	_camera_lado(jj, 3.0)
	await foto("v4_parado_lado")
	# carro na curva
	var meu = null
	for v in jogo.veiculos:
		if v.do_jogador and not v.missao:
			meu = v
	jj.pos = meu.pos + Vector2(-1.5, 1.8)
	sim(0.2)
	apertar("acao")
	meu.pos = Mapa.nodo_pos(Vector2i(3, 4)) + Vector2(2.0, 40.0)
	meu.h = 0.0
	meu.vel = Vector2(0, -22)
	jogo.entrada.segurar("frente", true)
	sim(1.0)
	jogo.entrada.segurar("direita", true)
	sim(0.45)
	await foto("v5_curva")
	jogo.entrada.segurar("direita", false)
	jogo.entrada.segurar("frente", false)
	jogo.entrada.segurar("freio_mao", true)
	sim(0.4)
	await foto("v6_freio_de_mao")
	jogo.entrada.segurar("freio_mao", false)
	# vista da rua do Centro
	jogo.camera.global_position = Vector3(36.0 + 3.0, 2.2, 60.0)
	jogo.camera.look_at(Vector3(36.0 - 1.0, 4.0, -40.0), Vector3.UP)
	await foto("v7_rua_centro")
	jogo.camera.global_position = Vector3(150.0, 30.0, 120.0)
	jogo.camera.look_at(Vector3(60.0, 0.0, 20.0), Vector3.UP)
	await foto("v8_cidade")


func _camera_lado(jj, d: float) -> void:
	var lado := U.direita(jj.h)
	var p := Vector3(jj.pos.x, jj.y + 1.1, jj.pos.y)
	jogo.camera.global_position = p + Vector3(lado.x, 0.0, lado.y) * d + Vector3(0, 0.3, 0)
	jogo.camera.look_at(p, Vector3.UP)


## Controles de toque (rodar com -- --teste=toque --toque). Simula dedos na tela.
func _toque() -> void:
	var ct = jogo.controles_toque
	checar(ct != null, "controles de toque criados")
	jogo.pausado = false  # os controles so funcionam com o jogo rodando (o tempo segue no simular)
	jogo.policia.carencia = 9999.0
	await jogo.get_tree().process_frame
	var jj = jogo.jogador
	var meu = null
	for v in jogo.veiculos:
		if v.do_jogador:
			meu = v
	jj.pos = meu.pos + Vector2(-1.5, 1.8)
	sim(0.2)
	await foto("t1_a_pe")
	await _tocar(_botao(ct, "e"))
	sim(0.1)
	checar(jj.veiculo == meu, "botão E entra no carro")
	# joystick para cima por 2 s
	await _dedo(1, ct.joy_centro, true)
	await _arrastar(1, ct.joy_centro + Vector2(0, -80))
	sim(2.0)
	checar(meu.velocidade() * 3.6 > 30.0, "joystick acelera o carro (%d km/h)" % int(meu.velocidade() * 3.6))
	await foto("t2_carro")
	await _dedo(1, ct.joy_centro, false)
	jogo.entrada.segurar("tras", true)
	sim(2.0)
	jogo.entrada.segurar("tras", false)
	meu.vel = Vector2.ZERO
	sim(0.3)
	await _tocar(_botao(ct, "e"))
	sim(0.2)
	checar(jj.veiculo == null, "botão E sai do carro")
	# arma: Mirar liga, Atirar gasta bala
	jogo.armas.dar("pistola", 36)
	await _tocar(_botao(ct, "mirar"))
	sim(0.3)
	checar(jogo.armas.mirando, "botão Mirar liga a mira")
	await foto("t3_mirando")
	var balas: int = jogo.armas.municao()
	await _tocar(_botao(ct, "atirar"))
	sim(0.1)
	checar(jogo.armas.municao() == balas - 1, "botão Atirar dispara")
	await _tocar(_botao(ct, "mirar"))
	sim(0.1)
	checar(not jogo.armas.mirando, "botão Mirar desliga a mira")
	# camera: arrastar no lado direito
	var yaw0: float = jogo.camera.yaw
	var tam: Vector2 = ct.raiz.get_viewport_rect().size
	await _dedo(2, Vector2(tam.x * 0.6, tam.y * 0.35), true)
	await _arrastar(2, Vector2(tam.x * 0.6 + 120, tam.y * 0.35))
	sim(0.1)
	await _dedo(2, Vector2(tam.x * 0.6 + 120, tam.y * 0.35), false)
	checar(absf(jogo.camera.yaw - yaw0) > 0.1, "arrastar o dedo gira a câmera")
	# celular
	await _tocar(_botao(ct, "celular"))
	jogo.atalhos()
	checar(jogo.ui_aberta == "celular", "botão Celular abre o celular")
	await foto("t4_celular")
	jogo.celular.fechar()


func _botao(ct, nome: String) -> Vector2:
	for b in ct.botoes:
		if b["nome"] == nome:
			return b["pos"]
	return Vector2.ZERO


func _dedo(indice: int, p: Vector2, apertado: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = indice
	e.position = p
	e.pressed = apertado
	Input.parse_input_event(e)
	await jogo.get_tree().process_frame


func _arrastar(indice: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = indice
	e.position = p
	e.relative = Vector2(120, 0) if indice == 2 else Vector2.ZERO
	Input.parse_input_event(e)
	await jogo.get_tree().process_frame


func _tocar(p: Vector2) -> void:
	await _dedo(0, p, true)
	await _dedo(0, p, false)
