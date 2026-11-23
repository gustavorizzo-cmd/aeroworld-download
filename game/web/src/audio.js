// Sons sintetizados com WebAudio (nenhum arquivo de audio).
export class Audio {
  constructor() {
    this.ctx = null;
    this.mudo = false;
  }

  iniciar() {
    if (this.ctx) return;
    try {
      const C = window.AudioContext || window.webkitAudioContext;
      this.ctx = new C();
    } catch {
      return;
    }
    const c = this.ctx;
    this.mestre = c.createGain();
    this.mestre.gain.value = 0.6;
    this.mestre.connect(c.destination);

    this.motor = c.createOscillator();
    this.motor.type = 'sawtooth';
    const filtro = c.createBiquadFilter();
    filtro.type = 'lowpass';
    filtro.frequency.value = 420;
    this.motorGanho = c.createGain();
    this.motorGanho.gain.value = 0;
    this.motor.connect(filtro).connect(this.motorGanho).connect(this.mestre);
    this.motor.start();

    this.sirene = c.createOscillator();
    this.sirene.type = 'triangle';
    this.sireneGanho = c.createGain();
    this.sireneGanho.gain.value = 0;
    this.sirene.connect(this.sireneGanho).connect(this.mestre);
    this.sirene.start();

    const n = c.sampleRate * 0.5;
    this.ruido = c.createBuffer(1, n, c.sampleRate);
    const d = this.ruido.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n) ** 2;
  }

  alternarMudo() {
    this.mudo = !this.mudo;
    if (this.mestre) this.mestre.gain.value = this.mudo ? 0 : 0.6;
    return this.mudo;
  }

  atualizar(jogo) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const v = jogo.jogador.veiculo;
    if (v) {
      const rot = 45 + Math.abs(v.vF) * 3.4 + v.ctrl.acel * 18;
      this.motor.frequency.setTargetAtTime(rot, t, 0.05);
      this.motorGanho.gain.setTargetAtTime(v.vida > 0 ? 0.07 : 0, t, 0.1);
    } else this.motorGanho.gain.setTargetAtTime(0, t, 0.1);

    let perto = Infinity;
    for (const o of jogo.veiculos) {
      if (!o.sireneLigada) continue;
      const d = Math.hypot(o.x - jogo.jogador.px, o.z - jogo.jogador.pz);
      if (d < perto) perto = d;
    }
    const vol = perto < 140 ? 0.05 * (1 - perto / 140) : 0;
    this.sireneGanho.gain.setTargetAtTime(vol, t, 0.1);
    this.sirene.frequency.setTargetAtTime(Math.floor(t / 0.45) % 2 ? 640 : 860, t, 0.01);
  }

  tom(freq, dur, tipo = 'square', vol = 0.12, atraso = 0) {
    if (!this.ctx) return;
    const c = this.ctx, t = c.currentTime + atraso;
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = tipo;
    o.frequency.value = freq;
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(this.mestre);
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  batida(forca) {
    if (!this.ctx) return;
    const c = this.ctx;
    const s = c.createBufferSource();
    s.buffer = this.ruido;
    const g = c.createGain();
    g.gain.value = Math.min(1, forca / 18) * 0.5;
    const f = c.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.value = 900;
    s.connect(f).connect(g).connect(this.mestre);
    s.start();
  }

  // Estalo de ruido filtrado: frequencia de corte alta = seco; baixa = estrondo.
  estalo(dur, corte, vol) {
    if (!this.ctx) return;
    const c = this.ctx, t = c.currentTime;
    const s = c.createBufferSource();
    s.buffer = this.ruido;
    s.playbackRate.value = 0.5 / dur;
    const f = c.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.value = corte;
    const g = c.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f).connect(g).connect(this.mestre);
    s.start(t);
    s.stop(t + dur + 0.05);
  }

  tiro(tipo, vol = 1) {
    const p = { pistola: [0.22, 4200, 0.55], escopeta: [0.45, 1800, 0.8], submetralhadora: [0.14, 5000, 0.4] }[tipo] || [0.2, 4000, 0.5];
    this.estalo(p[0], p[1], p[2] * vol);
  }
  explosao() {
    this.estalo(1.6, 380, 1.0);
  }
  soco() {
    this.estalo(0.1, 600, 0.6);
  }
  vazio() {
    this.tom(900, 0.03, 'square', 0.08);
  }
  compra() {
    this.tom(880, 0.08, 'triangle', 0.12);
    this.tom(1320, 0.14, 'triangle', 0.12, 0.08);
  }
  notificacao() {
    this.tom(1046, 0.09, 'triangle', 0.12);
    this.tom(1318, 0.14, 'triangle', 0.12, 0.11);
  }

  porta() {
    this.tom(180, 0.08, 'square', 0.08);
  }
  buzina() {
    this.tom(392, 0.35, 'square', 0.09);
    this.tom(466, 0.35, 'square', 0.07);
  }
  alerta() {
    this.tom(520, 0.12, 'square', 0.1);
    this.tom(780, 0.18, 'square', 0.1, 0.12);
  }
  escapou() {
    [523, 659, 784].forEach((f, i) => this.tom(f, 0.25, 'triangle', 0.12, i * 0.1));
  }
  etapa() {
    this.tom(660, 0.15, 'triangle', 0.12);
    this.tom(990, 0.2, 'triangle', 0.1, 0.1);
  }
  missao() {
    [392, 523, 659, 784].forEach((f, i) => this.tom(f, 0.3, 'triangle', 0.13, i * 0.12));
  }
}
