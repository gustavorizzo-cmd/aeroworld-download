class_name AnimHumano
extends RefCounted
## Animacao procedural do corpo com joelhos e cotovelos.
## Calcula a pose-alvo de cada articulacao (parado, andando, correndo, mirando,
## soco, telefone) e aproxima suavemente, para as transicoes ficarem fluidas.

var tronco: Node3D
var cabeca: Node3D
var braco: Array = [null, null]  # esq, dir
var antebraco: Array = [null, null]
var perna: Array = [null, null]
var canela: Array = [null, null]
var fase := 0.0
var t := 0.0
var bob := 0.0  # deslocamento vertical do corpo (devolvido a quem chama)
var _alvo := {}


func _init(obj: Node3D) -> void:
	tronco = obj.find_child("tronco", true, false)
	cabeca = obj.find_child("cabeca", true, false)
	for i in 2:
		var lado: String = ["esq", "dir"][i]
		braco[i] = obj.find_child("braco_" + lado, true, false)
		antebraco[i] = obj.find_child("antebraco_" + lado, true, false)
		perna[i] = obj.find_child("perna_" + lado, true, false)
		canela[i] = obj.find_child("canela_" + lado, true, false)
	t = randf() * 10.0


## vel: m/s no chao. op: mirando, mira_pitch, soco (0..1), ligando, parado_rigido.
## Devolve o "bob" (sobe e desce do corpo) para somar na altura.
func atualizar(dt: float, vel: float, op: Dictionary = {}) -> float:
	t += dt
	var andar := clampf(vel / 1.4, 0.0, 1.0)
	var corrida := clampf((vel - 4.2) / 3.0, 0.0, 1.0)
	var passada := lerpf(1.3, 2.4, corrida)
	fase += vel / passada * PI * dt
	var s := sin(fase)
	var c := cos(fase)

	# pernas: coxa balanca, joelho dobra quando a perna vem para a frente
	var a_coxa := lerpf(0.42, 0.9, corrida) * andar
	var k_joelho := lerpf(0.75, 1.65, corrida) * andar
	var base_joelho := 0.08 * andar + 0.05 * corrida
	_alvo["perna0"] = Vector3(a_coxa * s, 0, 0)
	_alvo["perna1"] = Vector3(-a_coxa * s, 0, 0)
	_alvo["canela0"] = Vector3(-(k_joelho * maxf(0.0, c) + base_joelho), 0, 0)
	_alvo["canela1"] = Vector3(-(k_joelho * maxf(0.0, -c) + base_joelho), 0, 0)

	# bracos: opostos as pernas; cotovelo mais dobrado na corrida
	var respira := sin(t * 1.7) * (1.0 - andar)
	var a_braco := lerpf(0.32, 0.75, corrida) * andar
	var cotovelo := lerpf(0.12, lerpf(0.32, 1.45, corrida), andar)
	_alvo["braco0"] = Vector3(-a_braco * s + respira * 0.02, 0, -0.07)
	_alvo["braco1"] = Vector3(a_braco * s + respira * 0.02, 0, 0.07)
	_alvo["antebraco0"] = Vector3(cotovelo + 0.12 * maxf(0.0, -s) * andar, 0, 0)
	_alvo["antebraco1"] = Vector3(cotovelo + 0.12 * maxf(0.0, s) * andar, 0, 0)

	# tronco inclina para a frente na corrida, gira com a passada, respira parado
	var lean := -(0.04 * andar + 0.16 * corrida) + respira * 0.018
	var giro := 0.1 * s * andar
	_alvo["tronco"] = Vector3(lean, giro, 0)
	_alvo["cabeca"] = Vector3(-lean * 0.7, -giro * 0.8 + sin(t * 0.37) * 0.06 * (1.0 - andar), 0)

	# poses especiais por cima do movimento
	var taxa := 14.0
	if op.get("mirando", false):
		var p: float = op.get("mira_pitch", 0.0)
		_alvo["braco1"] = Vector3(PI / 2.0 + p, 0, 0.02)
		_alvo["antebraco1"] = Vector3(0.0, 0, 0)
		_alvo["braco0"] = Vector3(PI / 2.0 - 0.2 + p, 0, 0.5)
		_alvo["antebraco0"] = Vector3(0.35, 0, 0)
		_alvo["tronco"] = Vector3(lean * 0.5, 0.18, 0)
		_alvo["cabeca"] = Vector3(-p * 0.5, -0.15, 0)
		taxa = 24.0
	var soco: float = op.get("soco", 0.0)
	if soco > 0.0:
		_alvo["braco1"] = Vector3(PI / 2.0 * soco, 0, 0.1)
		_alvo["antebraco1"] = Vector3(0.9 * (1.0 - soco), 0, 0)
		_alvo["tronco"] = Vector3(lean, -0.25 * soco, 0)
		taxa = 30.0
	if op.get("ligando", false):
		_alvo["braco1"] = Vector3(0.45, 0, 0.3)
		_alvo["antebraco1"] = Vector3(2.35, 0, 0)

	var k := 1.0 - exp(-taxa * dt)
	_aplicar(tronco, "tronco", k)
	_aplicar(cabeca, "cabeca", k)
	for i in 2:
		_aplicar(braco[i], "braco%d" % i, k)
		_aplicar(antebraco[i], "antebraco%d" % i, k)
		_aplicar(perna[i], "perna%d" % i, k)
		_aplicar(canela[i], "canela%d" % i, k)

	# o corpo desce quando as pernas estao abertas e sobe quando passam
	var alvo_bob := (absf(c) - 1.0) * (0.035 + 0.05 * corrida) * andar
	bob = lerpf(bob, alvo_bob, 1.0 - exp(-20.0 * dt))
	return bob


func _aplicar(no: Node3D, chave: String, k: float) -> void:
	if no == null or not _alvo.has(chave):
		return
	no.rotation = no.rotation.lerp(_alvo[chave], k)
