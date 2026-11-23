import { instanciar, pintar } from './assets.js';
import { frente, direita, headingDe, angDiff, suavizar, dist2 } from './util.js';
import { resolverCirculoNoMundo } from './fisica.js';

export const ROUPAS = [
  { camisa: '#e2553a', calca: '#2d3a55', nome: 'camisa coral' },
  { camisa: '#2f9e8f', calca: '#3b3b3f', nome: 'camisa verde-água' },
  { camisa: '#f2d24b', calca: '#1f2a44', nome: 'camisa amarela' },
  { camisa: '#f4f4f0', calca: '#6b4f33', nome: 'camisa branca' },
  { camisa: '#5c4aa8', calca: '#2d2d30', nome: 'camisa roxa' },
  { camisa: '#1d1f24', calca: '#7d8a99', nome: 'camisa preta' },
];

export class Jogador {
  constructor(jogo, x, z) {
    this.jogo = jogo;
    this.obj = instanciar('protagonista');
    this.roupaId = 0;
    this.matCamisa = pintar(this.obj, 'Roupa_Camisa', ROUPAS[0].camisa);
    this.matCalca = pintar(this.obj, 'Roupa_Calca', ROUPAS[0].calca);
    this.membros = ['braco_esq', 'braco_dir', 'perna_esq', 'perna_dir'].map((n) => this.obj.getObjectByName(n));
    this.x = x;
    this.z = z;
    this.h = 0;
    this.y = 0.17;
    this.vel = 0;
    this.fase = 0;
    this.veiculo = null;
    this.caido = 0;
    this.vida = 100;
    this.colete = 0;
    this.tSoco = 0;
    jogo.cena.add(this.obj);
  }

  get px() {
    return this.veiculo ? this.veiculo.x : this.x;
  }
  get pz() {
    return this.veiculo ? this.veiculo.z : this.z;
  }
  get velocidade() {
    return this.veiculo ? this.veiculo.velocidade : this.vel;
  }

  vestir(id) {
    this.roupaId = id;
    this.matCamisa.forEach((m) => m.color.set(ROUPAS[id].camisa));
    this.matCalca.forEach((m) => m.color.set(ROUPAS[id].calca));
    return ROUPAS[id];
  }

  trocarRoupa() {
    let id;
    do id = Math.floor(Math.random() * ROUPAS.length);
    while (id === this.roupaId);
    return this.vestir(id);
  }

  ferir(dano) {
    const jogo = this.jogo;
    if (jogo.cenaPrisao || jogo.cenaHospital || this.vida <= 0) return;
    const absorvido = Math.min(this.colete, dano);
    this.colete -= absorvido;
    this.vida = Math.max(0, this.vida - (dano - absorvido));
    jogo.hud.dano();
    if (this.vida <= 0) jogo.morreu();
  }

  curar(qtd) {
    this.vida = Math.min(100, this.vida + qtd);
  }

  socar() {
    this.tSoco = 0.25;
  }

  veiculoProximo() {
    let melhor = null, md = 3.4 * 3.4;
    for (const v of this.jogo.veiculos) {
      if (v.voando || v.queimado) continue;
      const d = dist2(v.x, v.z, this.x, this.z);
      if (d < md) {
        md = d;
        melhor = v;
      }
    }
    return melhor;
  }

  entrar(v) {
    const jogo = this.jogo;
    if (!v.doJogador) {
      if (v.motorista === 'ia') {
        const vitima = jogo.pedestres.motoristaExpulso(v);
        jogo.crime('roubo_carro', v.x, v.z, v.policia ? 3 : 1, { carro: v, vitima });
      } else {
        const alarme = !v.missao && !v.policia && Math.random() < 0.25;
        jogo.crime('roubo_carro', v.x, v.z, v.policia ? 2 : 1, { carro: v, alarme });
        if (alarme) jogo.hud.mensagem('O alarme do carro disparou!', 2.5);
      }
    }
    v.ia = null;
    v.estatico = false;
    v.motorista = 'jogador';
    v.doJogador = true;
    this.veiculo = v;
    this.obj.visible = false;
    jogo.audio.porta();
  }

  sair(forcar = false) {
    const v = this.veiculo;
    if (!v || (v.velocidade > 5 && !forcar)) return;
    const e = direita(v.h);
    this.x = v.x - e.x * 1.7;
    this.z = v.z - e.z * 1.7;
    this.h = v.h;
    resolverCirculoNoMundo(this.jogo.mapa, this, 0.35);
    v.motorista = null;
    v.ctrl = { acel: 0, freio: 1, virar: 0, freioMao: false };
    this.veiculo = null;
    this.obj.visible = true;
    this.jogo.audio.porta();
  }

  atualizar(dt, entrada, yawCamera) {
    const jogo = this.jogo;
    const livre = !jogo.uiAberta;
    const ex = livre ? entrada.eixos() : { x: 0, y: 0 };
    if (livre && entrada.apertou('KeyE', 'KeyF') && !jogo.policia.prendendo) {
      if (this.veiculo) this.sair();
      else {
        const v = this.veiculoProximo();
        if (v) this.entrar(v);
      }
    }
    if (livre && entrada.apertou('KeyH') && this.veiculo) jogo.audio.buzina();
    if (this.vida < 40 && this.vida > 0) this.vida = Math.min(40, this.vida + 1.5 * dt);

    if (this.veiculo) {
      const v = this.veiculo;
      v.ctrl.acel = ex.y > 0 ? ex.y : 0;
      v.ctrl.freio = ex.y < 0 ? -ex.y : 0;
      v.ctrl.virar = ex.x;
      v.ctrl.freioMao = livre && entrada.freioMao();
      return;
    }

    // ---- a pe
    const mirando = jogo.armas.mirando;
    if (this.caido > 0) {
      this.caido -= dt;
      this.obj.rotation.x = -Math.PI / 2;
    } else {
      this.obj.rotation.x = 0;
      const f = frente(yawCamera), r = direita(yawCamera);
      const dx = f.x * ex.y + r.x * ex.x;
      const dz = f.z * ex.y + r.z * ex.x;
      const mag = Math.min(1, Math.hypot(dx, dz));
      const corre = entrada.correr() && !mirando;
      const alvoVel = mag > 0.1 ? (mirando ? 3 : corre ? 7.5 : 4.2) * mag : 0;
      this.vel = suavizar(this.vel, alvoVel, 10, dt);
      if (mirando) this.h += angDiff(this.h, yawCamera) * Math.min(1, dt * 18);
      else if (mag > 0.1) this.h += angDiff(this.h, headingDe(dx, dz)) * Math.min(1, dt * 12);
      if (mirando && mag > 0.1) {
        // anda de lado mirando
        this.x += (dx / mag) * this.vel * dt;
        this.z += (dz / mag) * this.vel * dt;
      } else {
        const fw = frente(this.h);
        this.x += fw.x * this.vel * dt;
        this.z += fw.z * this.vel * dt;
      }
    }
    resolverCirculoNoMundo(jogo.mapa, this, 0.35);
    for (const v of jogo.veiculos) {
      if (dist2(v.x, v.z, this.x, this.z) > 16) continue;
      for (const c of v.circulos()) {
        const dx = this.x - c.x, dz = this.z - c.z;
        const rr = c.r + 0.35;
        const d2 = dx * dx + dz * dz;
        if (d2 < rr * rr && d2 > 1e-6) {
          const d = Math.sqrt(d2);
          this.x += (dx / d) * (rr - d);
          this.z += (dz / d) * (rr - d);
          if (v.velocidade > 9 && this.caido <= 0) {
            this.caido = 1.6;
            this.ferir(v.velocidade * 1.5);
            jogo.hud.mensagem('Você foi atropelado!', 1.5);
          }
        }
      }
    }
    this.y = suavizar(this.y, jogo.mapa.alturaChao(this.x, this.z), 15, dt);

    // animacao procedural
    const amp = Math.min(1, this.vel / 7) * 0.95;
    this.fase += this.vel * dt * 1.9;
    const s = Math.sin(this.fase) * amp;
    const [be, bd, pe, pd] = this.membros;
    this.tSoco = Math.max(0, this.tSoco - dt);
    let rotBe = s, rotBd = -s;
    if (mirando && jogo.armas.armado()) {
      const mira = jogo.cam.miraPitch;
      rotBd = Math.PI / 2 + mira;
      rotBe = Math.PI / 2 - 0.3 + mira;
    } else if (this.tSoco > 0) {
      rotBd = (Math.PI / 2) * (this.tSoco / 0.25);
    }
    if (be) be.rotation.x = rotBe;
    if (bd) bd.rotation.x = rotBd;
    if (pe) pe.rotation.x = -s;
    if (pd) pd.rotation.x = s;
    this.obj.position.set(this.x, this.y, this.z);
    this.obj.rotation.y = this.h;
  }
}

