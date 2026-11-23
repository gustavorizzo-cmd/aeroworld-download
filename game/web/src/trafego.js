import { Veiculo, CORES_CARRO } from './veiculo.js';
import { nodoPos, N } from './mapa.js';
import { angDiff, headingDe, clamp, dist, dist2, frente, direita, pick, rand, lerp } from './util.js';

// Faixa da direita entre dois cruzamentos (encurtada para a curva acontecer no cruzamento)
export function faixa(de, para, recuo = 7, lado = 2) {
  const A = nodoPos(de), B = nodoPos(para);
  const L = Math.hypot(B.x - A.x, B.z - A.z);
  const d = { x: (B.x - A.x) / L, z: (B.z - A.z) / L };
  const r = { x: -d.z, z: d.x };
  return {
    ini: { x: A.x + d.x * recuo + r.x * lado, z: A.z + d.z * recuo + r.z * lado },
    fim: { x: B.x - d.x * recuo + r.x * lado, z: B.z - d.z * recuo + r.z * lado },
    d,
    L: L - 2 * recuo,
  };
}

export function escolherProximo(mapa, de, atual) {
  const opcoes = mapa.vizinhos(atual).filter((n) => !(n.i === de.i && n.j === de.j));
  return opcoes.length ? pick(opcoes) : de;
}

// Converte um alvo em comandos de volante/acelerador.
export function dirigirPara(v, ax, az, velDesejada, ganho = 2.2) {
  const err = angDiff(v.h, headingDe(ax - v.x, az - v.z));
  let vd = velDesejada;
  if (Math.abs(err) > 1.6 && v.vF < 6) {
    // alvo atras: da re girando
    v.ctrl.acel = 0;
    v.ctrl.freio = 1;
    v.ctrl.virar = clamp(err * 2, -1, 1);
    return err;
  }
  v.ctrl.virar = clamp(-err * ganho, -1, 1);
  vd *= 1 - Math.min(0.6, Math.abs(err) * 0.5);
  if (v.vF < vd - 0.5) {
    v.ctrl.acel = clamp((vd - v.vF) / 4, 0.35, 1);
    v.ctrl.freio = 0;
  } else if (v.vF > vd + 1) {
    v.ctrl.acel = 0;
    v.ctrl.freio = clamp((v.vF - vd) / 6, 0.15, 1);
  } else {
    v.ctrl.acel = 0.15;
    v.ctrl.freio = 0;
  }
  v.ctrl.freioMao = false;
  return err;
}

// Distancia livre a frente (outros carros, pedestres, jogador a pe)
export function espacoLivre(jogo, v, alcance = 16) {
  const f = frente(v.h), r = direita(v.h);
  let livre = alcance;
  const testar = (x, z, larg) => {
    const rx = x - v.x, rz = z - v.z;
    const fr = rx * f.x + rz * f.z;
    if (fr <= 0 || fr > alcance) return;
    if (Math.abs(rx * r.x + rz * r.z) < larg) livre = Math.min(livre, fr);
  };
  for (const o of jogo.veiculos) if (o !== v) testar(o.x, o.z, 2.3);
  if (!jogo.jogador.veiculo) testar(jogo.jogador.x, jogo.jogador.z, 1.6);
  for (const p of jogo.pedestres.lista) if (!p.caido) testar(p.x, p.z, 1.4);
  return livre;
}

export function iniciarIATrafego(jogo, v, de, para) {
  v.motorista = 'ia';
  v.ia = { tipo: 'trafego', de, para, prox: escolherProximo(jogo.mapa, de, para), preso: 0, re: 0 };
}

export function conduzirNaFaixa(jogo, v, dt, velBase = 11) {
  const ia = v.ia;
  const f = faixa(ia.de, ia.para);
  const t = ((v.x - f.ini.x) * f.d.x + (v.z - f.ini.z) * f.d.z) / f.L;
  const restante = (1 - t) * f.L;
  const look = 5 + v.velocidade * 0.45;
  const f2 = faixa(ia.para, ia.prox);
  let ax, az;
  if (restante > look) {
    const s = t * f.L + look;
    ax = f.ini.x + f.d.x * s;
    az = f.ini.z + f.d.z * s;
  } else {
    const ponte = dist(f.fim.x, f.fim.z, f2.ini.x, f2.ini.z) + 0.01;
    const k = clamp((look - restante) / ponte, 0, 1);
    ax = lerp(f.fim.x, f2.ini.x, k);
    az = lerp(f.fim.z, f2.ini.z, k);
  }
  if (restante < 2 || t > 1) {
    ia.de = ia.para;
    ia.para = ia.prox;
    ia.prox = escolherProximo(jogo.mapa, ia.de, ia.para);
  }
  let vd = velBase;
  const curva = f.d.x * f2.d.x + f.d.z * f2.d.z;
  if (curva < 0.7 && restante < 18) vd = 5.5;
  const livre = espacoLivre(jogo, v);
  vd = Math.min(vd, Math.max(0, (livre - 6) * 1.1));

  if (ia.re > 0) {
    ia.re -= dt;
    v.ctrl = { acel: 0, freio: 1, virar: -Math.sign(angDiff(v.h, headingDe(ax - v.x, az - v.z))), freioMao: false };
    return;
  }
  dirigirPara(v, ax, az, vd);
  if (vd > 3 && v.velocidade < 0.6) ia.preso += dt;
  else ia.preso = Math.max(0, ia.preso - dt);
  if (ia.preso > 3) {
    ia.preso = 0;
    ia.re = 1.4;
  }
}

export class Trafego {
  constructor(jogo) {
    this.jogo = jogo;
    this.maxCivis = 16;
    this.maxPatrulhas = 3;
    this.timer = 0;
  }

  spawnar(policia = false) {
    const jogo = this.jogo;
    const p = { x: jogo.jogador.px, z: jogo.jogador.pz };
    for (let tent = 0; tent < 20; tent++) {
      const de = { i: Math.floor(Math.random() * N), j: Math.floor(Math.random() * N) };
      const para = pick(jogo.mapa.vizinhos(de));
      const f = faixa(de, para);
      const t = rand(0.15, 0.7);
      const x = f.ini.x + f.d.x * f.L * t, z = f.ini.z + f.d.z * f.L * t;
      const d = dist(x, z, p.x, p.z);
      if (d < 70 || d > 175) continue;
      if (jogo.veiculos.some((o) => dist2(o.x, o.z, x, z) < 144)) continue;
      const tipo = policia ? 'viatura' : Math.random() < 0.12 ? 'esportivo' : 'sedan';
      const v = new Veiculo(jogo, tipo, x, z, headingDe(f.d.x, f.d.z), policia ? null : pick(CORES_CARRO));
      iniciarIATrafego(jogo, v, de, para);
      v.vF = 8;
      v.vx = f.d.x * 8;
      v.vz = f.d.z * 8;
      return v;
    }
    return null;
  }

  atualizar(dt) {
    const jogo = this.jogo;
    const px = jogo.jogador.px, pz = jogo.jogador.pz;
    this.timer -= dt;
    if (this.timer <= 0) {
      this.timer = 0.5;
      const civis = jogo.veiculos.filter((v) => v.ia && v.ia.tipo === 'trafego' && !v.policia).length;
      const patrulhas = jogo.veiculos.filter((v) => v.policia && v.ia && v.ia.tipo === 'trafego').length;
      if (civis < this.maxCivis) this.spawnar(false);
      if (patrulhas < this.maxPatrulhas && jogo.policia.estrelas === 0) this.spawnar(true);
      // remove o que ficou longe
      for (const v of [...jogo.veiculos]) {
        if (v.missao || v.motorista === 'jogador' || v.estatico || v.fixo) continue;
        if (v.ia && v.ia.tipo === 'unidade') continue;
        if (dist(v.x, v.z, px, pz) > 240) v.remover();
      }
    }
    for (const v of jogo.veiculos) {
      if (v.ia && v.ia.tipo === 'trafego') conduzirNaFaixa(jogo, v, dt, v.policia ? 12 : 11);
    }
  }
}
