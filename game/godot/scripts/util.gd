class_name U
extends RefCounted
## Utilidades. Posicoes no plano do chao usam Vector2(x, z).
## heading = rotation.y; frente = (-sin h, -cos h). Norte = -Z.


static func frente(h: float) -> Vector2:
	return Vector2(-sin(h), -cos(h))


static func direita(h: float) -> Vector2:
	return Vector2(cos(h), -sin(h))


static func heading_de(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


static func ang_diff(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)


static func suavizar(atual: float, alvo: float, taxa: float, dt: float) -> float:
	return atual + (alvo - atual) * (1.0 - exp(-taxa * dt))


static func v3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func dinheiro(v: float) -> String:
	var s := str(int(round(absf(v))))
	var r := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		r = s[i] + r
		c += 1
		if c % 3 == 0 and i > 0:
			r = "." + r
	return ("-" if v < 0.0 else "") + "R$ " + r
