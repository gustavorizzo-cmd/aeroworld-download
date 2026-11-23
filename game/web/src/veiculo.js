import { instanciar, pintar } from './assets.js';
import { frente, direita, suavizar, clamp } from './util.js';

export const TIPOS = {
  sedan: { modelo: 'carro_sedan', prefixo: 'Pintura_Sedan', vmax: 30, acel: 9, re: 8, grip: 7, esterco: 0.62, raio: 0.95, meio: 1.3, massa: 1.0, entre: 2.7 },
  esportivo: { modelo: 'carro_esportivo', prefixo: 'Pintura_Esportivo', vmax: 44, acel: 15, re: 9, grip: 8, esterco: 0.6, raio: 1.0, meio: 1.35, massa: 1.0, entre: 2.9 },
  viatura: { modelo: 'viatura_policia', prefixo: 'Pintura_Viatura', vmax: 37, acel: 13, re: 9, grip: 8, esterco: 0.62, raio: 0.95, meio: 1.35, massa: 1.25, entre: 2.7 },
};

export const CORES_CARRO = ['#2f6db5', '#c8c8c4', '#2b2b2e', '#8a1f24', '#e0b53a', '#3d7a4f', '#e8e6df', '#5b4c8a', '#c4672f', '#1d4a6b'];

let proximoId = 1;

export class Veiculo {
  constructor(jogo, tipo, x, z, h, cor) {
    this.jogo = jogo;
    this.id = proximoId++;
    this.tipo = tipo;
    this.t = TIPOS[tipo];
    this.obj = instanciar(this.t.modelo);
    this.cor = cor || null;
    this.pinturas = cor ? pintar(this.obj, this.t.prefixo, cor) : [];
    this.rodas = ['roda_diant_esq', 'roda_diant_dir', 'roda_tras_esq', 'roda_tras_dir'].map((n) => {
      const r = this.obj.getObjectByName(n);
      if (r) r.rotation.order = 'YXZ';
      return r;
    });
    this.x = x;
    this.z = z;
    this.h = h;
    this.y = jogo.mapa.alturaChao(x, z);
    this.vx = 0;
    this.vz = 0;
    this.vF = 0;
    this.steer = 0;
    this.giro = 0;
    this.vida = 100;
    this.pneus = false;
    this.motorista = null; // 'jogador' | 'ia' | null
    this.ia = null;
    this.policia = tipo === 'viatura';
    this.ctrl = { acel: 0, freio: 0, virar: 0, freioMao: false };
    this.ativo = true;
    this.missao = false;
    this.fumaca = 0;
    this.queimado = false;
    this.iaQueimando = false;
    this.cdTiro = 0;
    if (this.policia) this.prepararSirenes();
    jogo.cena.add(this.obj);
    jogo.veiculos.push(this);
    this.sincronizar();
  }

  prepararSirenes() {
    this.sirenes = [];
    for (const nome of ['sirene_vermelha', 'sirene_azul']) {
      const no = this.obj.getObjectByName(nome);
      if (!no) continue;
      const mats = [];
      no.traverse((o) => {
        if (o.isMesh) {
          o.material = o.material.clone();
          mats.push(o.material);
        }
      });
      this.sirenes.push(mats);
    }
    this.ligarSirene(false, 0);
  }

  ligarSirene(ligada, t) {
    if (!this.sirenes) return;
    this.sireneLigada = ligada;
    const fase = Math.floor(t * 6) % 2;
    this.sirenes.forEach((mats, i) => {
      const forca = ligada ? (i === fase ? 6 : 0.15) : 0.25;
      mats.forEach((m) => (m.emissiveIntensity = forca));
    });
  }

  repintar(cor) {
    this.cor = cor;
    if (this.pinturas.length) this.pinturas.forEach((m) => m.color.set(cor));
    else this.pinturas = pintar(this.obj, this.t.prefixo, cor);
  }

  get velocidade() {
    return Math.hypot(this.vx, this.vz);
  }

  circulos() {
    const f = frente(this.h);
    const m = this.t.meio;
    return [
      { x: this.x + f.x * m, z: this.z + f.z * m, r: this.t.raio },
      { x: this.x - f.x * m, z: this.z - f.z * m, r: this.t.raio },
    ];
  }

  dano(forca) {
    const antes = this.vida;
    this.vida = Math.max(0, this.vida - (forca - 5) * 1.7);
    if (antes > 0 && this.vida <= 0) this.jogo.armas.incendiar(this);
  }

  atualizar(dt) {
    const c = this.ctrl;
    const t = this.t;
    const f = frente(this.h);
    const r = direita(this.h);
    let vF = this.vx * f.x + this.vz * f.z;
    let vR = this.vx * r.x + this.vz * r.z;
    const morto = this.vida <= 0;
    const vmax = t.vmax * (this.pneus ? 0.5 : 1) * (this.vida < 30 ? 0.75 : 1);

    if (c.acel > 0 && !morto && vF < vmax) {
      vF += t.acel * c.acel * (1 - Math.max(0, vF) / vmax * 0.55) * dt;
    }
    if (c.freio > 0) {
      if (vF > 0.4) vF -= 24 * c.freio * dt;
      else if (!morto && vF > -t.re) vF -= t.acel * 0.6 * c.freio * dt;
    }
    if (c.acel <= 0 && c.freio <= 0) {
      vF -= vF * 0.45 * dt;
      vF -= Math.sign(vF) * Math.min(Math.abs(vF), 0.8 * dt);
    }
    let grip = t.grip * (this.pneus ? 0.4 : 1);
    if (c.freioMao) {
      grip = 1.1;
      vF -= vF * 0.9 * dt;
    }
    vR *= Math.exp(-grip * dt);

    const alvo = clamp(c.virar, -1, 1) * t.esterco / (1 + Math.abs(vF) * 0.045);
    this.steer = suavizar(this.steer, alvo, 9, dt);
    let yaw = (vF / t.entre) * Math.tan(this.steer);
    if (c.freioMao) yaw *= 1.6;
    if (this.pneus) yaw += Math.sin(performance.now() / 180) * 0.12 * Math.min(1, Math.abs(vF) / 10);
    this.h -= yaw * dt;

    const f2 = frente(this.h);
    const r2 = direita(this.h);
    this.vx = f2.x * vF + r2.x * vR;
    this.vz = f2.z * vF + r2.z * vR;
    this.x += this.vx * dt;
    this.z += this.vz * dt;
    this.vF = vF;
    this.derrapando = Math.abs(vR) > 4;
    this.giro -= (vF / 0.36) * dt;
    this.y = suavizar(this.y, this.jogo.mapa.alturaChao(this.x, this.z), 14, dt);
  }

  sincronizar() {
    this.obj.position.set(this.x, this.y, this.z);
    this.obj.rotation.y = this.h;
    this.rodas.forEach((r, i) => {
      if (!r) return;
      r.rotation.x = this.giro;
      if (i < 2) r.rotation.y = -this.steer;
    });
  }

  remover() {
    this.ativo = false;
    this.jogo.cena.remove(this.obj);
    const i = this.jogo.veiculos.indexOf(this);
    if (i >= 0) this.jogo.veiculos.splice(i, 1);
  }
}
