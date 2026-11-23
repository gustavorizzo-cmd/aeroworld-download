class_name Entrada
extends Node
## Acoes de teclado e controle (criadas em codigo: aparecem em Projeto > Mapa de Entrada
## so durante o jogo). Tambem guarda o movimento do mouse para a camera.

const TECLAS := {
	"frente": [KEY_W, KEY_UP],
	"tras": [KEY_S, KEY_DOWN],
	"esquerda": [KEY_A, KEY_LEFT],
	"direita": [KEY_D, KEY_RIGHT],
	"acao": [KEY_E, KEY_F],
	"freio_mao": [KEY_SPACE],
	"correr": [KEY_SHIFT],
	"mapa": [KEY_M],
	"pausa": [KEY_ESCAPE, KEY_P],
	"buzina": [KEY_H],
	"som": [KEY_N],
}

var apertadas := {}
var forcadas := {}  # usado pelos testes automaticos
var arraste := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for acao in TECLAS:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.2)
		for k in TECLAS[acao]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(acao, e)
	_eixo("frente", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_eixo("tras", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_eixo("frente", JOY_AXIS_LEFT_Y, -1.0)
	_eixo("tras", JOY_AXIS_LEFT_Y, 1.0)
	_eixo("esquerda", JOY_AXIS_LEFT_X, -1.0)
	_eixo("direita", JOY_AXIS_LEFT_X, 1.0)
	_botao("acao", JOY_BUTTON_Y)
	_botao("freio_mao", JOY_BUTTON_RIGHT_SHOULDER)
	_botao("correr", JOY_BUTTON_A)
	_botao("mapa", JOY_BUTTON_BACK)
	_botao("pausa", JOY_BUTTON_START)
	_botao("buzina", JOY_BUTTON_LEFT_STICK)


func _eixo(acao: String, eixo: JoyAxis, valor: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = eixo
	e.axis_value = valor
	InputMap.action_add_event(acao, e)


func _botao(acao: String, botao: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = botao
	InputMap.action_add_event(acao, e)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			arraste += event.relative
		return
	for acao in TECLAS:
		if event.is_action_pressed(acao, false):
			apertadas[acao] = true


func forca(acao: String) -> float:
	return maxf(Input.get_action_strength(acao), forcadas.get(acao, 0.0))


## x = direita, y = frente (-1..1)
func eixos() -> Vector2:
	var v := Vector2(forca("direita") - forca("esquerda"), forca("frente") - forca("tras"))
	return v.limit_length(1.0) if v.length() > 1.0 else v


func apertou(acao: String) -> bool:
	return apertadas.has(acao)


func segurando(acao: String) -> bool:
	return forca(acao) > 0.5


func camera_joy() -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	return v if v.length() > 0.2 else Vector2.ZERO


func consumir_arraste() -> Vector2:
	var a := arraste
	arraste = Vector2.ZERO
	return a


func fim_do_quadro() -> void:
	apertadas.clear()


# ---- para testes automaticos
func apertar(acao: String) -> void:
	apertadas[acao] = true


func segurar(acao: String, ligado: bool) -> void:
	if ligado:
		forcadas[acao] = 1.0
	else:
		forcadas.erase(acao)
