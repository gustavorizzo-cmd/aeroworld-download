class_name CameraJogo
extends Camera3D
## Camera em 3a pessoa. Mouse (capturado) ou analogico direito giram; volta para tras
## do jogador quando ele se move.

var yaw := 0.0
var pitch := 0.3
var distancia := 6.0
var t_arraste := -10.0
var alvo := Vector3.ZERO
var pos_suave := Vector3(0, 10, 10)
var mapa
var mira_pitch := 0.0  # para cima > 0 (modo mira)
var tremor := 0.0
var _olhar_suave := Vector3.ZERO


## Tremor de camera (batidas, explosoes); decai sozinho.
func tremer(forca: float) -> void:
	tremor = minf(1.0, maxf(tremor, forca))


func _aplicar_tremor(dt: float) -> void:
	if tremor <= 0.001:
		return
	position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * tremor * 0.25
	tremor = maxf(0.0, tremor - dt * 2.5)


func atualizar(dt: float, jogo, entrada) -> void:
	var jj = jogo.jogador
	var a: Vector2 = entrada.consumir_arraste()
	var joy: Vector2 = entrada.camera_joy()
	if jogo.ui_aberta != "":
		a = Vector2.ZERO
		joy = Vector2.ZERO
	if jogo.armas.mirando:
		_mirar(dt, jogo, a, joy)
		return
	mira_pitch = U.suavizar(mira_pitch, 0.0, 6.0, dt)
	if a.length() > 0.0 or joy.length() > 0.0:
		yaw -= a.x * 0.004 + joy.x * dt * 2.6
		pitch = clampf(pitch + a.y * 0.003 + joy.y * dt * 1.6, 0.05, 1.2)
		t_arraste = jogo.tempo
	var livre: bool = jogo.tempo - t_arraste > 1.6
	var v = jj.veiculo
	var alvo_dist := 5.5
	var alvo_pitch := -1.0
	if v:
		alvo = Vector3(v.pos.x, v.y + 1.3, v.pos.y)
		var vel: float = v.velocidade()
		if livre and (vel > 1.5 or jogo.tempo - t_arraste > 3.0):
			yaw += U.ang_diff(yaw, v.h) * minf(1.0, dt * 3.2)
			alvo_pitch = 0.26
		alvo_dist = 8.5 + minf(vel, 40.0) * 0.09
	else:
		alvo = Vector3(jj.pos.x, jj.y + 1.55, jj.pos.y)
		if livre and jj.vel > 0.5:
			yaw += U.ang_diff(yaw, jj.h) * minf(1.0, dt * 1.6)
		if livre:
			alvo_pitch = 0.3
	if alvo_pitch >= 0.0:
		pitch = U.suavizar(pitch, alvo_pitch, 2.0, dt)
	distancia = U.suavizar(distancia, alvo_dist, 4.0, dt)

	# se houver predio entre o alvo e a camera, chega mais perto
	var atras := Vector2(sin(yaw), cos(yaw))
	var centro := Vector2(alvo.x, alvo.z)
	var d := distancia
	while d > 2.0 and not mapa.tem_visao(centro, centro + atras * d):
		d -= 0.5
	var cp := cos(pitch)
	var desejada := Vector3(alvo.x + atras.x * cp * d, alvo.y + sin(pitch) * d, alvo.z + atras.y * cp * d)
	pos_suave = pos_suave.lerp(desejada, 1.0 - exp(-(9.0 if v else 12.0) * dt))
	position = pos_suave
	var f := U.frente(yaw)
	var olhar := Vector3(alvo.x + f.x * 2.0, alvo.y, alvo.z + f.y * 2.0)
	# o ponto olhado tambem e suavizado: menos tranco nas batidas e curvas
	_olhar_suave = olhar if _olhar_suave == Vector3.ZERO else _olhar_suave.lerp(olhar, 1.0 - exp(-16.0 * dt))
	_aplicar_tremor(dt)
	if position.distance_to(_olhar_suave) > 0.1:
		look_at(_olhar_suave, Vector3.UP)
	var fov_alvo := 62.0 + (minf(v.velocidade(), 40.0) * 0.3 if v else 0.0)
	fov = U.suavizar(fov, fov_alvo, 3.0, dt)


## Camera por cima do ombro direito; o centro da tela e para onde o tiro vai.
func _mirar(dt: float, jogo, a: Vector2, joy: Vector2) -> void:
	var jj = jogo.jogador
	yaw -= a.x * 0.003 + joy.x * dt * 2.0
	mira_pitch = clampf(mira_pitch - a.y * 0.003 - joy.y * dt * 1.4, -0.6, 0.7)
	t_arraste = jogo.tempo
	alvo = Vector3(jj.pos.x, jj.y + 1.55, jj.pos.y)
	var f3 := Vector3(-sin(yaw) * cos(mira_pitch), sin(mira_pitch), -cos(yaw) * cos(mira_pitch))
	var dir := U.direita(yaw)
	var desejada := alvo + Vector3(dir.x, 0, dir.y) * 0.75 - f3 * 2.4 + Vector3(0, 0.15, 0)
	pos_suave = pos_suave.lerp(desejada, 1.0 - exp(-20.0 * dt))
	position = pos_suave
	look_at(position + f3, Vector3.UP)
	fov = U.suavizar(fov, 50.0, 10.0, dt)
	pitch = 0.3
