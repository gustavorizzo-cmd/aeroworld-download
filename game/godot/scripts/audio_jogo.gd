class_name AudioJogo
extends Node
## Sons sintetizados (nenhum arquivo de audio): motor e sirene em tempo real,
## efeitos curtos gerados uma vez como AudioStreamWAV.

const TAXA := 22050

var mudo := false
var gerador: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var fase_motor := 0.0
var fase_sirene := 0.0
var filtro := 0.0
var freq_motor := 50.0
var vol_motor := 0.0
var alvo_motor := 0.0
var vol_sirene := 0.0
var alvo_sirene := 0.0
var t_audio := 0.0
var efeitos := {}
var tocadores: Array = []
var proximo := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gerador = AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = TAXA
	g.buffer_length = 0.15
	gerador.stream = g
	add_child(gerador)
	gerador.play()
	playback = gerador.get_stream_playback()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		tocadores.append(p)
	efeitos["porta"] = _tons([[180.0, 0.08, 0.0, "q", 0.25]])
	efeitos["buzina"] = _tons([[392.0, 0.35, 0.0, "q", 0.22], [466.0, 0.35, 0.0, "q", 0.18]])
	efeitos["alerta"] = _tons([[520.0, 0.12, 0.0, "q", 0.25], [780.0, 0.18, 0.12, "q", 0.25]])
	efeitos["escapou"] = _tons([[523.0, 0.25, 0.0, "t", 0.35], [659.0, 0.25, 0.1, "t", 0.35], [784.0, 0.3, 0.2, "t", 0.35]])
	efeitos["etapa"] = _tons([[660.0, 0.15, 0.0, "t", 0.35], [990.0, 0.2, 0.1, "t", 0.3]])
	efeitos["missao"] = _tons([[392.0, 0.3, 0.0, "t", 0.35], [523.0, 0.3, 0.12, "t", 0.35], [659.0, 0.3, 0.24, "t", 0.35], [784.0, 0.4, 0.36, "t", 0.35]])
	efeitos["batida"] = _ruido(0.45)


func _onda(tipo: String, fase: float) -> float:
	var f := fposmod(fase, 1.0)
	if tipo == "q":
		return 1.0 if f < 0.5 else -1.0
	if tipo == "t":
		return 4.0 * absf(f - 0.5) - 1.0
	return 2.0 * f - 1.0


func _wav(amostras: PackedFloat32Array) -> AudioStreamWAV:
	var dados := PackedByteArray()
	dados.resize(amostras.size() * 2)
	for i in amostras.size():
		dados.encode_s16(i * 2, int(clampf(amostras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	return w


func _tons(notas: Array) -> AudioStreamWAV:
	var fim := 0.0
	for n in notas:
		fim = maxf(fim, n[1] + n[2])
	var a := PackedFloat32Array()
	a.resize(int(fim * TAXA) + 1)
	for n in notas:
		var ini := int(n[2] * TAXA)
		var dur := int(n[1] * TAXA)
		for i in dur:
			var env := pow(0.001, float(i) / dur)
			a[ini + i] += _onda(n[3], float(i) * n[0] / TAXA) * n[4] * env
	return _wav(a)


func _ruido(dur: float) -> AudioStreamWAV:
	var a := PackedFloat32Array()
	var n := int(dur * TAXA)
	a.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf_range(-1.0, 1.0) - lp) * 0.25
		a[i] = lp * pow(1.0 - float(i) / n, 2.0) * 1.6
	return _wav(a)


func tocar(nome: String, volume: float = 1.0) -> void:
	if mudo or not efeitos.has(nome):
		return
	var p: AudioStreamPlayer = tocadores[proximo]
	proximo = (proximo + 1) % tocadores.size()
	p.stream = efeitos[nome]
	p.volume_db = linear_to_db(clampf(volume, 0.05, 1.0))
	p.play()


func alternar_mudo() -> bool:
	mudo = not mudo
	AudioServer.set_bus_mute(0, mudo)
	return mudo


func batida(forca: float) -> void:
	tocar("batida", forca / 18.0)


func porta() -> void:
	tocar("porta")


func buzina() -> void:
	tocar("buzina")


func alerta() -> void:
	tocar("alerta")


func escapou() -> void:
	tocar("escapou")


func etapa() -> void:
	tocar("etapa")


func missao() -> void:
	tocar("missao")


func atualizar(jogo) -> void:
	var v = jogo.jogador.veiculo
	if v != null:
		freq_motor = 45.0 + absf(v.v_f) * 3.4 + v.ctrl["acel"] * 18.0
		alvo_motor = 0.12 if v.vida > 0.0 else 0.0
	else:
		alvo_motor = 0.0
	var perto := INF
	var p: Vector2 = jogo.jogador.posicao()
	for o in jogo.veiculos:
		if o.sirene_ligada:
			perto = minf(perto, o.pos.distance_to(p))
	alvo_sirene = 0.09 * (1.0 - perto / 140.0) if perto < 140.0 else 0.0


func _process(_delta: float) -> void:
	if playback == null:
		return
	var n := playback.get_frames_available()
	for i in n:
		t_audio += 1.0 / TAXA
		vol_motor += (alvo_motor - vol_motor) * 0.0008
		vol_sirene += (alvo_sirene - vol_sirene) * 0.0008
		fase_motor += freq_motor / TAXA
		var bruto := _onda("s", fase_motor)
		filtro += (bruto - filtro) * 0.12
		var fs := 640.0 if int(t_audio / 0.45) % 2 == 0 else 860.0
		fase_sirene += fs / TAXA
		var s := filtro * vol_motor + _onda("t", fase_sirene) * vol_sirene
		playback.push_frame(Vector2(s, s))
