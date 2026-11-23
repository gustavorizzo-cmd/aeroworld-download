import * as THREE from 'three';
import { frente, direita, dist, rand, clamp } from './util.js';

// Armas do jogador (inventario, tiro, soco), efeitos (rastro, clarao, impacto, explosao)
// e a policia atirando de volta com 3 estrelas ou mais.
export const TIPOS = {
  punho: { nome: 'Punhos', dano: 0, cadencia: 0.45, alcance: 1.8, preco: 0, precoMunicao: 0, pacote: 0, projeteis: 1, dispersao: 0, auto: false, tam: 0 },
  pistola: { nome: 'Pistola', dano: 34, cadencia: 0.3, alcance: 60, preco: 400, precoMunicao: 60, pacote: 36, projeteis: 1, dispersao: 0.012, auto: false, tam: 0.26 },
  escopeta: { nome: 'Escopeta', dano: 20, cadencia: 0.85, alcance: 26, preco: 900, precoMunicao: 90, pacote: 16, projeteis: 6, dispersao: 0.065, auto: false, tam: 0.62 },
  submetralhadora: { nome: 'Submetralhadora', dano: 16, cadencia: 0.09, alcance: 45, preco: 1500, precoMunicao: 120, pacote: 120, projeteis: 1, dispersao: 0.03, auto: true, tam: 0.5 },
};
export const ORDEM = ['punho', 'pistola', 'escopeta', 'submetralhadora'];

const basico = (cor, opacidade = 1) =>
  new THREE.MeshBasicMaterial({ color: cor, transparent: opacidade < 1, opacity: opacidade, depthWrite: opacidade >= 1 });

function cilindro(o, d, cx, cz, r, y0, y1) {
  const ox = o.x - cx, oz = o.z - cz;
  const a = d.x * d.x + d.z * d.z;
  if (a < 1e-8) return Infinity;
  const b = 2 * (ox * d.x + oz * d.z);
  const c = ox * ox + oz * oz - r * r;
  const disc = b * b - 4 * a * c;
  if (disc < 0) return Infinity;
  const s = Math.sqrt(disc);
  for (const t of [(-b - s) / (2 * a), (-b + s) / (2 * a)]) {
    const y = o.y + d.y * t;
    if (t > 0 && y >= y0 && y <= y1) return t;
  }
  return Infinity;
}

function caixa2d(o, d, k) {
  let t0 = -Infinity, t1 = Infinity;
  for (const [oo, dd, mn, mx] of [[o.x, d.x, k.minX, k.maxX], [o.z, d.z, k.minZ, k.maxZ]]) {
    if (Math.abs(dd) < 1e-8) {
      if (oo < mn || oo > mx) return Infinity;
      continue;
    }
    const ta = (mn - oo) / dd, tb = (mx - oo) / dd;
    t0 = Math.max(t0, Math.min(ta, tb));
    t1 = Math.min(t1, Math.max(ta, tb));
  }
  if (t1 < Math.max(t0, 0)) return Infinity;
  return t0 > 0 ? t0 : Infinity;
}

export class Armas {
  constructor(jogo) {
    this.jogo = jogo;
    this.inventario = { punho: 0 };
    this.atual = 'punho';
    this.mirando = false;
    this.mirarToque = false;
    this.cd = 0;
    this.cdCrime = 0;
    this.tirosPolicia = 0;
    this.efeitos = [];
    this.queimando = [];
    this.mats = {
      arma: new THREE.MeshStandardMaterial({ color: '#23262b', roughness: 0.5, metalness: 0.4 }),
      rastro: basico('#fff0a0', 0.8),
      clarao: basico('#ffd966'),
      poeira: basico('#d9d1bf', 0.7),
      fogo: basico('#ff8a26', 0.85),
      fumaca: new THREE.SpriteMaterial({ color: '#222222', transparent: true, opacity: 0.5, depthWrite: false }),
      queimado: new THREE.MeshStandardMaterial({ color: '#1b1a19', roughness: 0.9 }),
    };
    this.geoCaixa = new THREE.BoxGeometry(1, 1, 1);
    this.geoEsfera = new THREE.SphereGeometry(1, 10, 8);
  }

  // Arma simples na mao direita do personagem
  prepararModelo(jogador) {
    const braco = jogador.membros[1];
    this.armaMao = new THREE.Mesh(this.geoCaixa, this.mats.arma);
    this.armaMao.castShadow = true;
    if (braco) braco.add(this.armaMao);
    this.atualizarModelo();
  }

  atualizarModelo() {
    if (!this.armaMao) return;
    const tam = TIPOS[this.atual].tam;
    this.armaMao.visible = tam > 0;
    if (tam > 0) {
      this.armaMao.scale.set(0.07, tam, 0.11);
      this.armaMao.position.set(0, -0.7 - tam * 0.5, -0.02);
    }
  }

  // ---------------------------------------------------------------- inventario
  tem(a) {
    return a in this.inventario;
  }
  municao() {
    return this.inventario[this.atual] || 0;
  }
  armado() {
    return this.atual !== 'punho';
  }
  dar(a, balas) {
    this.inventario[a] = (this.inventario[a] || 0) + balas;
    this.selecionar(a);
  }
  selecionar(a) {
    if (this.tem(a)) {
      this.atual = a;
      this.atualizarModelo();
    }
  }
  trocar(passo) {
    let i = ORDEM.indexOf(this.atual);
    for (let k = 0; k < ORDEM.length; k++) {
      i = (i + passo + ORDEM.length) % ORDEM.length;
      if (this.tem(ORDEM[i])) return this.selecionar(ORDEM[i]);
    }
  }
  confiscar() {
    this.inventario = { punho: 0 };
    this.selecionar('punho');
    this.mirarToque = false;
  }

  // ---------------------------------------------------------------- quadro a quadro
  atualizar(dt, entrada, podeAgir) {
    const jogo = this.jogo, j = jogo.jogador;
    this.cd -= dt;
    this.cdCrime -= dt;
    const aPe = !j.veiculo && j.caido <= 0;
    if (podeAgir && entrada.apertou('ToqueMirar')) this.mirarToque = !this.mirarToque;
    if (!aPe) this.mirarToque = false;
    this.mirando = podeAgir && aPe && (entrada.tem('Mouse2') || this.mirarToque);
    if (podeAgir && aPe) {
      if (entrada.apertou('KeyQ', 'WheelDown')) this.trocar(1);
      if (entrada.apertou('WheelUp')) this.trocar(-1);
      ORDEM.forEach((a, k) => {
        if (entrada.apertou('Digit' + (k + 1))) this.selecionar(a);
      });
      const t = TIPOS[this.atual];
      const gatilho = entrada.apertou('Mouse0') || (t.auto && entrada.atirando());
      if (gatilho && this.cd <= 0) {
        this.cd = t.cadencia;
        if (this.atual === 'punho') this.soco();
        else if (this.municao() <= 0) {
          jogo.audio.vazio();
          jogo.hud.dica('Sem munição. Compre mais no Arsenal do Porto.');
        } else {
          this.inventario[this.atual]--;
          this.disparar();
        }
      }
    }
    if (this.armaMao) this.armaMao.visible = aPe && TIPOS[this.atual].tam > 0;
    this.atualizarEfeitos(dt);
    this.atualizarQueimando(dt);
    this.policiaAtira(dt);
  }

  // ---------------------------------------------------------------- tiro
  disparar() {
    const jogo = this.jogo, j = jogo.jogador;
    const t = TIPOS[this.atual];
    const cam = jogo.camera;
    cam.updateMatrixWorld();
    const origem = cam.getWorldPosition(new THREE.Vector3());
    let fr = cam.getWorldDirection(new THREE.Vector3());
    const dirX = new THREE.Vector3().setFromMatrixColumn(cam.matrixWorld, 0);
    const dirY = new THREE.Vector3().setFromMatrixColumn(cam.matrixWorld, 1);
    const fh = frente(j.h);
    const boca = new THREE.Vector3(j.x + fh.x * 0.8, j.y + 1.45, j.z + fh.z * 0.8);
    const pular = origem.distanceTo(boca) - 0.3;
    if (jogo.toque) fr = this.miraAssistida(origem, fr, t.alcance + pular) || fr;
    let acertou = false;
    for (let i = 0; i < t.projeteis; i++) {
      const disp = t.dispersao * (this.mirando ? 0.5 : 1.6);
      const d = fr.clone().addScaledVector(dirX, rand(-disp, disp)).addScaledVector(dirY, rand(-disp, disp)).normalize();
      const hit = this.raio(origem, d, t.alcance + pular, pular);
      this.rastro(boca, hit.ponto);
      this.impacto(hit.ponto, hit.tipo);
      if (!['nada', 'parede', 'chao'].includes(hit.tipo)) {
        acertou = true;
        this.aplicarDano(hit, t.dano, d);
      }
    }
    this.clarao(boca);
    jogo.audio.tiro(this.atual);
    jogo.pedestres.panico(j.x, j.z, 40);
    if (this.cdCrime <= 0 && !acertou) {
      this.cdCrime = 5;
      jogo.crime('disparo', j.x, j.z, 1, {});
    }
  }

  // No toque: puxa o tiro para o alvo mais proximo do centro da tela (ate ~20 graus)
  miraAssistida(origem, fr, alcance) {
    const jogo = this.jogo;
    let melhor = null, mAng = 0.35;
    const testar = (x, y, z) => {
      const v = new THREE.Vector3(x, y, z).sub(origem);
      const d = v.length();
      if (d > alcance || d < 1) return;
      const ang = v.normalize().angleTo(fr);
      if (ang < mAng && jogo.mapa.temVisao(jogo.jogador.x, jogo.jogador.z, x, z)) {
        mAng = ang;
        melhor = v.clone();
      }
    };
    for (const p of jogo.pedestres.lista) if (!p.caido) testar(p.x, p.y + 1.1, p.z);
    for (const v of jogo.veiculos) if (!v.queimado && v.policia && v.motorista === 'ia') testar(v.x, v.y + 0.9, v.z);
    return melhor;
  }

  // Raio 3D contra pedestres, carros, helicoptero, predios e chao. Ignora o que esta antes de `minimo`.
  raio(o, d, alcance, minimo = 0) {
    const jogo = this.jogo;
    let melhor = alcance, res = { tipo: 'nada', alvo: null };
    for (const p of jogo.pedestres.lista) {
      if (p.caido) continue;
      const t = cilindro(o, d, p.x, p.z, 0.45, p.y, p.y + 1.85);
      if (t > minimo && t < melhor) {
        melhor = t;
        res = { tipo: 'pedestre', alvo: p };
      }
    }
    for (const v of jogo.veiculos) {
      if (v === jogo.jogador.veiculo || v.queimado) continue;
      for (const c of v.circulos()) {
        const t = cilindro(o, d, c.x, c.z, c.r, v.y, v.y + 1.5);
        if (t > minimo && t < melhor) {
          melhor = t;
          res = { tipo: 'veiculo', alvo: v };
        }
      }
    }
    const h = jogo.policia.heli;
    if (h) {
      const oc = new THREE.Vector3(o.x - h.x, o.y - (h.y + 1.5), o.z - h.z);
      const b = oc.dot(d), c = oc.lengthSq() - 2.6 * 2.6, disc = b * b - c;
      if (disc > 0) {
        const t = -b - Math.sqrt(disc);
        if (t > minimo && t < melhor) {
          melhor = t;
          res = { tipo: 'heli', alvo: null };
        }
      }
    }
    for (const k of jogo.mapa.caixas) {
      if (k.tipo !== 'predio') continue;
      const t = caixa2d(o, d, k);
      if (t > minimo && t < melhor) {
        melhor = t;
        res = { tipo: 'parede', alvo: null };
      }
    }
    if (d.y < -0.001) {
      const t = (o.y - 0.05) / -d.y;
      if (t > minimo && t < melhor) {
        melhor = t;
        res = { tipo: 'chao', alvo: null };
      }
    }
    res.ponto = o.clone().addScaledVector(d, melhor);
    return res;
  }

  aplicarDano(hit, dano, d) {
    const jogo = this.jogo;
    if (hit.tipo === 'pedestre') {
      const p = hit.alvo;
      jogo.pedestres.derrubar(p, d.x * 4, d.z * 4, 2);
      if (this.cdCrime <= 0) {
        this.cdCrime = 3;
        jogo.crime('tiro_pedestre', p.x, p.z, 3, {});
      }
    } else if (hit.tipo === 'veiculo') {
      const v = hit.alvo;
      v.vida = Math.max(0, v.vida - dano * 0.6);
      if (v.policia && v.motorista === 'ia') jogo.policia.atacada('Você atirou na polícia!');
      if (v.vida <= 0) this.incendiar(v);
    } else if (hit.tipo === 'heli') {
      jogo.policia.atacada('Você atirou no helicóptero!');
      jogo.policia.danoHeli(dano);
    }
  }

  soco() {
    const jogo = this.jogo, j = jogo.jogador;
    const f = frente(j.h);
    j.socar();
    for (const p of jogo.pedestres.lista) {
      if (p.caido) continue;
      const rx = p.x - j.x, rz = p.z - j.z, d = Math.hypot(rx, rz);
      if (d < 1.8 && (rx * f.x + rz * f.z) / (d || 1) > 0.4) {
        jogo.pedestres.derrubar(p, f.x * 3, f.z * 3, 1.5);
        jogo.audio.soco();
        jogo.crime('agressao', p.x, p.z, 1, {});
        return;
      }
    }
  }

  // ---------------------------------------------------------------- policia atira
  policiaAtira(dt) {
    const jogo = this.jogo, p = jogo.policia, j = jogo.jogador;
    if (p.estrelas < 3 || p.modo !== 'perseguicao' || p.carencia > 0 || jogo.cenaPrisao || jogo.cenaHospital) return;
    for (const v of p.olhos()) {
      v.cdTiro = (v.cdTiro || 0) - dt;
      if (v.cdTiro > 0) continue;
      const d = dist(v.x, v.z, j.px, j.pz);
      if (d > 32 || !jogo.mapa.temVisao(v.x, v.z, j.px, j.pz)) {
        v.cdTiro = 0.5;
        continue;
      }
      v.cdTiro = rand(0.8, 1.5);
      this.tirosPolicia++;
      const chance = clamp(0.6 - d / 60 - j.velocidade * 0.012, 0.08, 0.6);
      const de = new THREE.Vector3(v.x, v.y + 1.3, v.z);
      const para = new THREE.Vector3(j.px, 1.2, j.pz);
      if (Math.random() < chance) j.ferir(rand(6, 11) * (j.veiculo ? 0.5 : 1));
      else para.add(new THREE.Vector3(rand(-1.5, 1.5), rand(-0.6, 1), rand(-1.5, 1.5)));
      this.rastro(de, para);
      this.clarao(de);
      jogo.audio.tiro('pistola', 0.5);
    }
  }

  // ---------------------------------------------------------------- carros queimando
  incendiar(v) {
    if (v.queimado || v.iaQueimando) return;
    v.iaQueimando = true;
    this.queimando.push({ v, t: 4, prox: 0 });
    if (v.motorista === 'jogador') this.jogo.hud.mensagem('O carro está pegando fogo! Saia antes que exploda (E).', 3);
  }

  atualizarQueimando(dt) {
    for (const q of [...this.queimando]) {
      q.t -= dt;
      q.prox -= dt;
      if (q.prox <= 0 && q.v.ativo) {
        q.prox = 0.12;
        this.fumaca(q.v.x, q.v.y + 1.3, q.v.z);
      }
      if (q.t <= 0) {
        this.queimando.splice(this.queimando.indexOf(q), 1);
        if (q.v.ativo) this.explodir(q.v);
      }
    }
  }

  explodir(v) {
    const jogo = this.jogo, j = jogo.jogador;
    v.queimado = true;
    v.vida = 0;
    v.vx *= 0.3;
    v.vz *= 0.3;
    v.obj.traverse((o) => {
      if (o.isMesh) o.material = this.mats.queimado;
    });
    this.explosaoVisual(v.x, v.y + 1, v.z);
    jogo.audio.explosao();
    jogo.pedestres.panico(v.x, v.z, 45);
    if (v.motorista === 'jogador') {
      j.ferir(70);
      j.sair(true);
    } else if (dist(j.px, j.pz, v.x, v.z) < 7) {
      j.ferir(55 * (1 - dist(j.px, j.pz, v.x, v.z) / 7));
    }
    for (const p of jogo.pedestres.lista) {
      const d = dist(p.x, p.z, v.x, v.z);
      if (!p.caido && d < 6) jogo.pedestres.derrubar(p, ((p.x - v.x) / (d || 1)) * 8, ((p.z - v.z) / (d || 1)) * 8, 6);
    }
    for (const o of jogo.veiculos) {
      const d = dist(o.x, o.z, v.x, v.z);
      if (o !== v && !o.queimado && d < 6) {
        o.vida = Math.max(0, o.vida - 45);
        o.vx += ((o.x - v.x) / (d || 1)) * 6;
        o.vz += ((o.z - v.z) / (d || 1)) * 6;
        if (o.vida <= 0) this.incendiar(o);
      }
    }
    if (v.motorista === 'ia') {
      v.ia = null;
      v.motorista = null;
    }
  }

  // ---------------------------------------------------------------- efeitos
  efeito(obj, vida, tipo) {
    this.jogo.cena.add(obj);
    this.efeitos.push({ obj, vida, total: vida, tipo });
  }

  explosaoVisual(x, y, z) {
    const m = new THREE.Mesh(this.geoEsfera, this.mats.fogo);
    m.position.set(x, y, z);
    this.efeito(m, 0.7, 'explosao');
    for (let i = 0; i < 6; i++) this.fumaca(x + rand(-1, 1), y + rand(0, 1), z + rand(-1, 1));
  }

  rastro(de, para) {
    const comp = de.distanceTo(para);
    if (comp < 0.1) return;
    const m = new THREE.Mesh(this.geoCaixa, this.mats.rastro);
    m.scale.set(0.03, 0.03, comp);
    m.position.copy(de).add(para).multiplyScalar(0.5);
    m.lookAt(para);
    this.efeito(m, 0.06, 'rastro');
  }

  clarao(p) {
    const m = new THREE.Mesh(this.geoEsfera, this.mats.clarao);
    m.scale.setScalar(0.14);
    m.position.copy(p);
    this.efeito(m, 0.05, 'clarao');
  }

  impacto(p, tipo) {
    if (tipo === 'nada') return;
    const m = new THREE.Mesh(this.geoEsfera, this.mats.poeira);
    m.scale.setScalar(0.12);
    m.position.copy(p);
    this.efeito(m, 0.35, 'impacto');
  }

  fumaca(x, y, z) {
    const s = new THREE.Sprite(this.mats.fumaca);
    s.position.set(x, y, z);
    s.scale.setScalar(0.8);
    this.efeito(s, 1.6, 'fumaca');
  }

  atualizarEfeitos(dt) {
    for (const e of [...this.efeitos]) {
      e.vida -= dt;
      const k = 1 - e.vida / e.total;
      if (e.tipo === 'explosao') e.obj.scale.setScalar(1 + k * 4.5);
      else if (e.tipo === 'impacto') e.obj.scale.setScalar(0.12 * (1 + k * 2));
      else if (e.tipo === 'fumaca') {
        e.obj.position.y += dt * 2.2;
        e.obj.scale.setScalar(0.8 + k * 1.6);
      }
      if (e.vida <= 0) {
        this.jogo.cena.remove(e.obj);
        this.efeitos.splice(this.efeitos.indexOf(e), 1);
      }
    }
  }
}

export { direita };
