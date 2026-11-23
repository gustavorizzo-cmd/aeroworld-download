import * as THREE from 'three';
import { instanciar, pintarComPaleta } from './assets.js';
import { headingDe, angDiff, dist, dist2, pick, rand, clamp, direita } from './util.js';
import { resolverCirculoNoMundo } from './fisica.js';

const H = 31; // meia-volta do quarteirao na linha da calcada
const PER = 8 * H;
const CAMISAS = ['#d9534f', '#5bc0de', '#f0ad4e', '#5cb85c', '#9b59b6', '#ecf0f1', '#34495e', '#e67e22', '#16a085', '#c0392b'];
const CALCAS = ['#2c3e50', '#3b3b3f', '#6b4f33', '#7d8a99', '#1f2a44', '#8e7f6a'];

function posPerimetro(s) {
  s = ((s % PER) + PER) % PER;
  const lado = Math.floor(s / (2 * H));
  const u = s - lado * 2 * H - H;
  if (lado === 0) return { x: u, z: -H, dx: 1, dz: 0 };
  if (lado === 1) return { x: H, z: u, dx: 0, dz: 1 };
  if (lado === 2) return { x: -u, z: H, dx: -1, dz: 0 };
  return { x: -H, z: -u, dx: 0, dz: -1 };
}

function paramMaisProximo(x, z) {
  const c = (v) => clamp(v, -H, H);
  const cand = [
    { s: c(x) + H, d: (z + H) ** 2 + (x - c(x)) ** 2 },
    { s: 2 * H + c(z) + H, d: (x - H) ** 2 + (z - c(z)) ** 2 },
    { s: 4 * H + (H - c(x)), d: (z - H) ** 2 + (x - c(x)) ** 2 },
    { s: 6 * H + (H - c(z)), d: (x + H) ** 2 + (z - c(z)) ** 2 },
  ];
  return cand.reduce((a, b) => (b.d < a.d ? b : a)).s;
}

function iconeTelefone() {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 64;
  const g = cv.getContext('2d');
  g.fillStyle = '#ffcc33';
  g.beginPath();
  g.arc(32, 32, 28, 0, Math.PI * 2);
  g.fill();
  g.lineWidth = 4;
  g.strokeStyle = '#1b1b1b';
  g.stroke();
  g.fillStyle = '#1b1b1b';
  g.font = 'bold 42px sans-serif';
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.fillText('!', 32, 34);
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  return new THREE.SpriteMaterial({ map: tex, depthTest: false });
}

export class Pedestres {
  constructor(jogo) {
    this.jogo = jogo;
    this.lista = [];
    this.max = 34;
    this.matIcone = iconeTelefone();
    this.timer = 0;
  }

  criar(x, z, estado = 'andando') {
    const obj = instanciar('protagonista');
    pintarComPaleta(obj, 'Roupa_Camisa', pick(CAMISAS));
    pintarComPaleta(obj, 'Roupa_Calca', pick(CALCAS));
    const icone = new THREE.Sprite(this.matIcone);
    icone.scale.set(0.7, 0.7, 0.7);
    icone.position.y = 2.4;
    icone.visible = false;
    obj.add(icone);
    const p = {
      obj, icone, x, z, h: 0, y: 0.17, estado, vel: rand(1.2, 1.7), fase: Math.random() * 6,
      membros: ['braco_esq', 'braco_dir', 'perna_esq', 'perna_dir'].map((n) => obj.getObjectByName(n)),
      bloco: null, s: 0, dir: Math.random() < 0.5 ? 1 : -1, timer: 0, caido: false, vy: 0, vx: 0, vz: 0,
    };
    this.jogo.cena.add(obj);
    this.lista.push(p);
    return p;
  }

  colocarNoBloco(p, bloco, s) {
    p.bloco = bloco;
    p.s = s;
    const q = posPerimetro(s);
    p.x = bloco.cx + q.x;
    p.z = bloco.cz + q.z;
    p.estado = 'andando';
    p.caido = false;
    p.obj.rotation.set(0, 0, 0);
    p.icone.visible = false;
  }

  blocoMaisProximo(x, z) {
    let m = null, md = Infinity;
    for (const b of this.jogo.mapa.blocos) {
      const d = dist2(b.cx, b.cz, x, z);
      if (d < md) {
        md = d;
        m = b;
      }
    }
    return m;
  }

  reposicionar(p) {
    const jogo = this.jogo;
    const px = jogo.jogador.px, pz = jogo.jogador.pz;
    const perto = jogo.mapa.blocos.filter((b) => dist(b.cx, b.cz, px, pz) < 140);
    for (let t = 0; t < 12; t++) {
      const b = pick(perto.length ? perto : jogo.mapa.blocos);
      const s = Math.random() * PER;
      const q = posPerimetro(s);
      if (dist(b.cx + q.x, b.cz + q.z, px, pz) > 45) {
        this.colocarNoBloco(p, b, s);
        return;
      }
    }
  }

  // Motorista expulso do carro: foge e depois liga para a policia.
  motoristaExpulso(v) {
    const e = direita(v.h);
    const p = this.criar(v.x - e.x * 1.8, v.z - e.z * 1.8);
    this.fugir(p, v.x, v.z, 2.2);
    p.denunciaDepois = true;
    p.temporario = true;
    return p;
  }

  fugir(p, x, z, tempo = 5) {
    if (p.caido) return;
    p.estado = 'fugindo';
    p.fugaDe = { x, z };
    p.timer = tempo;
    p.icone.visible = false;
  }

  panico(x, z, raio) {
    for (const p of this.lista) {
      if (p.caido || p.estado === 'ligando') continue;
      if (dist2(p.x, p.z, x, z) < raio * raio) this.fugir(p, x, z, rand(4, 7));
    }
  }

  // Quem viu? Devolve o pedestre mais proximo com visao do local.
  testemunha(x, z, alcance = 40) {
    let m = null, md = alcance * alcance;
    for (const p of this.lista) {
      if (p.caido || p.estado === 'ligando') continue;
      const d = dist2(p.x, p.z, x, z);
      if (d < md && this.jogo.mapa.temVisao(p.x, p.z, x, z)) {
        md = d;
        m = p;
      }
    }
    return m;
  }

  ligar(p, denuncia) {
    p.estado = 'ligando';
    p.timer = 5;
    p.denuncia = denuncia;
    p.icone.visible = true;
  }

  // Derruba o pedestre (atropelado, baleado, socado). Ele some depois.
  derrubar(p, vx, vz, vy) {
    if (p.caido) return;
    p.caido = true;
    p.estado = 'caido';
    p.icone.visible = false;
    p.vx = vx;
    p.vz = vz;
    p.vy = vy;
    p.timer = 12;
    p.denuncia = null;
    this.panico(p.x, p.z, 25);
  }

  atropelar(p, v) {
    this.derrubar(p, v.vx * 0.7, v.vz * 0.7, 3 + v.velocidade * 0.15);
    if (v.motorista === 'jogador') {
      this.jogo.crime('atropelamento', p.x, p.z, 2, { carro: v });
      this.jogo.audio.batida(6);
    }
  }

  atualizar(dt) {
    const jogo = this.jogo;
    const px = jogo.jogador.px, pz = jogo.jogador.pz;

    this.timer -= dt;
    if (this.timer <= 0) {
      this.timer = 0.7;
      const permanentes = this.lista.filter((p) => !p.temporario).length;
      if (permanentes < this.max) {
        const p = this.criar(0, 0);
        this.reposicionar(p);
      }
    }

    for (const p of [...this.lista]) {
      const d = dist(p.x, p.z, px, pz);
      if (d > 170 && p.estado !== 'ligando') {
        if (p.temporario) this.remover(p);
        else this.reposicionar(p);
        continue;
      }

      let vel = 0;
      if (p.caido) {
        p.timer -= dt;
        p.vy -= 20 * dt;
        p.x += p.vx * dt;
        p.z += p.vz * dt;
        p.y += p.vy * dt;
        const chao = jogo.mapa.alturaChao(p.x, p.z);
        if (p.y <= chao) {
          p.y = chao;
          p.vy = 0;
          p.vx *= 0.8;
          p.vz *= 0.8;
        }
        p.obj.rotation.x = Math.max(-Math.PI / 2, p.obj.rotation.x - dt * 8);
        resolverCirculoNoMundo(jogo.mapa, p, 0.3);
        if (p.timer <= 0) {
          if (p.temporario) this.remover(p);
          else this.reposicionar(p);
        }
      } else if (p.estado === 'andando' && p.bloco) {
        p.s += p.dir * p.vel * dt;
        const q = posPerimetro(p.s);
        p.x = p.bloco.cx + q.x;
        p.z = p.bloco.cz + q.z;
        p.h = headingDe(q.dx * p.dir, q.dz * p.dir);
        vel = p.vel;
      } else if (p.estado === 'fugindo') {
        p.timer -= dt;
        const ang = headingDe(p.x - p.fugaDe.x, p.z - p.fugaDe.z);
        p.h += angDiff(p.h, ang) * Math.min(1, dt * 6);
        vel = 5.5;
        p.x += -Math.sin(p.h) * vel * dt;
        p.z += -Math.cos(p.h) * vel * dt;
        resolverCirculoNoMundo(jogo.mapa, p, 0.3);
        if (p.timer <= 0) {
          if (p.denunciaDepois) {
            p.denunciaDepois = false;
            jogo.policia.vitimaVaiLigar(p);
          } else {
            p.estado = 'voltando';
            p.bloco = this.blocoMaisProximo(p.x, p.z);
            p.s = paramMaisProximo(p.x - p.bloco.cx, p.z - p.bloco.cz);
          }
        }
      } else if (p.estado === 'voltando') {
        const q = posPerimetro(p.s);
        const tx = p.bloco.cx + q.x, tz = p.bloco.cz + q.z;
        if (dist(p.x, p.z, tx, tz) < 0.6) p.estado = 'andando';
        else {
          p.h = headingDe(tx - p.x, tz - p.z);
          vel = p.vel;
          p.x += -Math.sin(p.h) * vel * dt;
          p.z += -Math.cos(p.h) * vel * dt;
          resolverCirculoNoMundo(jogo.mapa, p, 0.3);
        }
      } else if (p.estado === 'ligando') {
        p.timer -= dt;
        p.h = headingDe(px - p.x, pz - p.z) + Math.PI;
        if (d < 3.2) {
          p.icone.visible = false;
          p.denuncia = null;
          this.fugir(p, px, pz, 6);
          jogo.policia.denunciaCancelada(true);
        } else if (p.timer <= 0) {
          p.icone.visible = false;
          jogo.policia.denuncia(p.denuncia);
          p.denuncia = null;
          p.estado = 'voltando';
          p.bloco = this.blocoMaisProximo(p.x, p.z);
          p.s = paramMaisProximo(p.x - p.bloco.cx, p.z - p.bloco.cz);
        }
      }

      // carros
      if (!p.caido) {
        for (const v of jogo.veiculos) {
          if (dist2(v.x, v.z, p.x, p.z) > 12) continue;
          for (const c of v.circulos()) {
            const dx = p.x - c.x, dz = p.z - c.z;
            const rr = c.r + 0.3;
            const d2 = dx * dx + dz * dz;
            if (d2 < rr * rr && d2 > 1e-6) {
              if (v.velocidade > 4) {
                this.atropelar(p, v);
                break;
              }
              const dd = Math.sqrt(d2);
              p.x += (dx / dd) * (rr - dd);
              p.z += (dz / dd) * (rr - dd);
            }
          }
          if (p.caido) break;
        }
      }

      if (!p.caido) p.y = jogo.mapa.alturaChao(p.x, p.z);
      const amp = Math.min(1, vel / 6) * 0.9;
      p.fase += vel * dt * 2;
      const s = Math.sin(p.fase) * amp;
      const [be, bd, pe, pd] = p.membros;
      if (be) be.rotation.x = p.estado === 'ligando' ? -2.4 : s;
      if (bd) bd.rotation.x = -s;
      if (pe) pe.rotation.x = -s;
      if (pd) pd.rotation.x = s;
      p.obj.position.set(p.x, p.y, p.z);
      p.obj.rotation.y = p.h;
    }
  }

  remover(p) {
    this.jogo.cena.remove(p.obj);
    const i = this.lista.indexOf(p);
    if (i >= 0) this.lista.splice(i, 1);
  }
}
