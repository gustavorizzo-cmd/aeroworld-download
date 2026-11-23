// Colisoes simples: carros = 2 circulos; predios = caixas alinhadas; postes = circulos.
import { LIMITES } from './mapa.js';
import { clamp, dist2 } from './util.js';

function empurrarCirculo(cx, cz, r, caixa) {
  const px = clamp(cx, caixa.minX, caixa.maxX);
  const pz = clamp(cz, caixa.minZ, caixa.maxZ);
  let dx = cx - px, dz = cz - pz;
  const d2 = dx * dx + dz * dz;
  if (d2 >= r * r) return null;
  if (d2 > 1e-8) {
    const d = Math.sqrt(d2);
    return { nx: dx / d, nz: dz / d, pen: r - d };
  }
  // centro dentro da caixa: sai pelo lado mais proximo
  const op = [
    { nx: -1, nz: 0, pen: cx - caixa.minX + r },
    { nx: 1, nz: 0, pen: caixa.maxX - cx + r },
    { nx: 0, nz: -1, pen: cz - caixa.minZ + r },
    { nx: 0, nz: 1, pen: caixa.maxZ - cz + r },
  ];
  return op.reduce((a, b) => (b.pen < a.pen ? b : a));
}

function impacto(jogo, v, nx, nz, e = 0.25) {
  const vn = v.vx * nx + v.vz * nz;
  if (vn >= 0) return 0;
  v.vx -= (1 + e) * vn * nx;
  v.vz -= (1 + e) * vn * nz;
  const forca = -vn;
  if (forca > 5) {
    v.dano(forca);
    if (v.motorista === 'jogador') jogo.audio.batida(forca);
  }
  return forca;
}

// Usado tambem pelo pedestre/jogador a pe: empurra um circulo para fora do mundo solido.
export function resolverCirculoNoMundo(mapa, obj, r) {
  const { caixas, circulos } = mapa.proximos(obj.x, obj.z, r + 2);
  for (const c of caixas) {
    const p = empurrarCirculo(obj.x, obj.z, r, c);
    if (p) {
      obj.x += p.nx * p.pen;
      obj.z += p.nz * p.pen;
    }
  }
  for (const c of circulos) {
    const dx = obj.x - c.x, dz = obj.z - c.z;
    const rr = r + c.r;
    const d2 = dx * dx + dz * dz;
    if (d2 < rr * rr && d2 > 1e-8) {
      const d = Math.sqrt(d2);
      obj.x += (dx / d) * (rr - d);
      obj.z += (dz / d) * (rr - d);
    }
  }
  obj.x = clamp(obj.x, LIMITES.minX, LIMITES.maxX);
  obj.z = clamp(obj.z, LIMITES.minZ, LIMITES.maxZ);
}

function colisaoMundo(jogo, v) {
  const { caixas, circulos } = jogo.mapa.proximos(v.x, v.z, 4);
  for (let k = 0; k < 2; k++) {
    const cs = v.circulos()[k];
    for (const c of caixas) {
      const p = empurrarCirculo(cs.x, cs.z, cs.r, c);
      if (p) {
        v.x += p.nx * p.pen;
        v.z += p.nz * p.pen;
        cs.x += p.nx * p.pen;
        cs.z += p.nz * p.pen;
        impacto(jogo, v, p.nx, p.nz, 0.2);
      }
    }
    for (const c of circulos) {
      const dx = cs.x - c.x, dz = cs.z - c.z;
      const rr = cs.r + c.r;
      const d2 = dx * dx + dz * dz;
      if (d2 < rr * rr && d2 > 1e-8) {
        const d = Math.sqrt(d2);
        const nx = dx / d, nz = dz / d;
        v.x += nx * (rr - d);
        v.z += nz * (rr - d);
        impacto(jogo, v, nx, nz, 0.3);
      }
    }
    // obstaculos derrubaveis (cavaletes, cones, viaturas paradas nao entram aqui)
    for (const o of jogo.obstaculos) {
      if (o.caido) continue;
      const dx = cs.x - o.x, dz = cs.z - o.z;
      const rr = cs.r + o.r;
      if (dx * dx + dz * dz < rr * rr) o.derrubar(v);
    }
  }
  const x0 = v.x, z0 = v.z;
  v.x = clamp(v.x, LIMITES.minX, LIMITES.maxX);
  v.z = clamp(v.z, LIMITES.minZ, LIMITES.maxZ);
  if (v.x !== x0) v.vx = 0;
  if (v.z !== z0) v.vz = 0;
}

function colisaoPar(jogo, a, b) {
  const ca = a.circulos(), cb = b.circulos();
  for (const pa of ca) {
    for (const pb of cb) {
      const dx = pb.x - pa.x, dz = pb.z - pa.z;
      const rr = pa.r + pb.r;
      const d2 = dx * dx + dz * dz;
      if (d2 >= rr * rr || d2 < 1e-8) continue;
      const d = Math.sqrt(d2);
      const nx = dx / d, nz = dz / d;
      const pen = rr - d;
      const ma = a.t.massa * (a.motorista ? 1 : 1.6), mb = b.t.massa * (b.motorista ? 1 : 1.6);
      const s = ma + mb;
      a.x -= nx * pen * (mb / s);
      a.z -= nz * pen * (mb / s);
      b.x += nx * pen * (ma / s);
      b.z += nz * pen * (ma / s);
      const rel = (b.vx - a.vx) * nx + (b.vz - a.vz) * nz;
      if (rel < 0) {
        const j = (-(1.3) * rel) / (1 / ma + 1 / mb);
        a.vx -= (j / ma) * nx;
        a.vz -= (j / ma) * nz;
        b.vx += (j / mb) * nx;
        b.vz += (j / mb) * nz;
        const forca = -rel;
        if (forca > 4) {
          a.dano(forca * 0.8);
          b.dano(forca * 0.8);
          jogo.eventoBatida(a, b, forca);
        }
      }
      return;
    }
  }
}

export function passoFisica(jogo, dt) {
  const vs = jogo.veiculos;
  for (const v of vs) {
    if (!v.estatico) v.atualizar(dt);
  }
  for (let i = 0; i < vs.length; i++) {
    const a = vs[i];
    for (let j = i + 1; j < vs.length; j++) {
      const b = vs[j];
      if (dist2(a.x, a.z, b.x, b.z) < 36) colisaoPar(jogo, a, b);
    }
  }
  for (const v of vs) {
    if (!v.estatico || v.motorista) colisaoMundo(jogo, v);
    // tapetes de pregos
    for (const t of jogo.tapetes) {
      if (!v.pneus && Math.abs(v.x - t.x) < t.lx && Math.abs(v.z - t.z) < t.lz && v.velocidade > 2) {
        v.pneus = true;
        if (v.motorista === 'jogador') {
          jogo.hud.mensagem('Pneus furados! O carro ficou lento e escorregadio.', 3);
          jogo.audio.batida(8);
        }
      }
    }
    v.sincronizar();
  }
}
