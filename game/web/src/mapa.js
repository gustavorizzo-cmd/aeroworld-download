import * as THREE from 'three';
import { instanciar, pintarComPaleta, Fusao } from './assets.js';
import { headingDe } from './util.js';

// ---------------------------------------------------------------------------
// Grade de ruas: N x N cruzamentos a cada ESP metros. Blocos de 60 x 60 m.
// ---------------------------------------------------------------------------
export const N = 6;
export const ESP = 72;
const MEIO = (N - 1) / 2;
export const BORDA = MEIO * ESP + 6; // borda externa da calcada (186 m)
export const LIMITES = { minX: -250, maxX: 236, minZ: -250, maxZ: 250 };
export const nodoX = (i) => (i - MEIO) * ESP;
export const nodoPos = (n) => ({ x: nodoX(n.i), z: nodoX(n.j) });

function mulberry32(a) {
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const DISTRITOS = {
  centro: { nome: 'Centro', cor: '#b8b2a7', mapa: '#5d6470' },
  orla: { nome: 'Orla', cor: '#d8c9a2', mapa: '#7a6f55' },
  porto: { nome: 'Porto', cor: '#8d8a84', mapa: '#4a5560' },
  suburbio: { nome: 'Subúrbio', cor: '#86a85f', mapa: '#4f6b3e' },
};

function distritoDoBloco(bi, bj) {
  if (bi === 4) return 'orla';
  if (bi === 0 || (bi === 1 && bj >= 3)) return 'porto';
  if (bj >= 3) return 'suburbio';
  return 'centro';
}

export class Mapa {
  constructor(cena) {
    this.cena = cena;
    this.caixas = []; // {minX,maxX,minZ,maxZ,tipo}
    this.circulos = []; // {x,z,r}
    this.celulas = new Map();
    this.blocos = [];
    this.estacionados = []; // {x,z,h,modelo,cor}
    this.poi = {};
    this.rng = mulberry32(20261123);
    this.fusao = new Fusao();
    this.construir();
  }

  r() {
    return this.rng();
  }

  // ------------------------------------------------------------------ consulta
  ehRua(x, z) {
    if (Math.abs(x) > BORDA + 0.5 || Math.abs(z) > BORDA + 0.5) return false;
    const i = Math.round(x / ESP + MEIO);
    const j = Math.round(z / ESP + MEIO);
    if (i >= 0 && i < N && Math.abs(x - nodoX(i)) < 4) return true;
    if (j >= 0 && j < N && Math.abs(z - nodoX(j)) < 4) return true;
    return false;
  }

  alturaChao(x, z) {
    if (Math.abs(x) <= BORDA && Math.abs(z) <= BORDA) return this.ehRua(x, z) ? 0.02 : 0.17;
    if (x > BORDA) return 0.06;
    return 0.0;
  }

  distrito(x, z) {
    const bi = Math.round(x / ESP + 2);
    const bj = Math.round(z / ESP + 2);
    if (bi < 0 || bi > 4 || bj < 0 || bj > 4) return null;
    return distritoDoBloco(bi, bj);
  }

  nodoMaisProximo(x, z) {
    const c = (v) => Math.max(0, Math.min(N - 1, Math.round(v / ESP + MEIO)));
    return { i: c(x), j: c(z) };
  }

  vizinhos(n) {
    const v = [];
    if (n.i > 0) v.push({ i: n.i - 1, j: n.j });
    if (n.i < N - 1) v.push({ i: n.i + 1, j: n.j });
    if (n.j > 0) v.push({ i: n.i, j: n.j - 1 });
    if (n.j < N - 1) v.push({ i: n.i, j: n.j + 1 });
    return v;
  }

  rota(a, b) {
    const k = (n) => n.i + ',' + n.j;
    const ant = new Map([[k(a), null]]);
    const fila = [a];
    while (fila.length) {
      const n = fila.shift();
      if (n.i === b.i && n.j === b.j) break;
      for (const v of this.vizinhos(n)) {
        if (!ant.has(k(v))) {
          ant.set(k(v), n);
          fila.push(v);
        }
      }
    }
    const caminho = [];
    let n = b;
    while (n) {
      caminho.unshift(n);
      n = ant.get(k(n));
    }
    return caminho;
  }

  // Rota de GPS entre dois pontos quaisquer (lista de pontos x,z).
  rotaGPS(ax, az, bx, bz) {
    const a = this.nodoMaisProximo(ax, az);
    const b = this.nodoMaisProximo(bx, bz);
    const pts = [{ x: ax, z: az }];
    for (const n of this.rota(a, b)) pts.push(nodoPos(n));
    pts.push({ x: bx, z: bz });
    return pts;
  }

  _chave(cx, cz) {
    return cx * 10007 + cz;
  }

  _indexar(obj, minX, maxX, minZ, maxZ, lista) {
    const C = 20;
    for (let cx = Math.floor(minX / C); cx <= Math.floor(maxX / C); cx++) {
      for (let cz = Math.floor(minZ / C); cz <= Math.floor(maxZ / C); cz++) {
        const k = this._chave(cx, cz);
        if (!this.celulas.has(k)) this.celulas.set(k, { caixas: [], circulos: [] });
        this.celulas.get(k)[lista].push(obj);
      }
    }
  }

  // Colisores proximos de (x,z) num raio.
  proximos(x, z, raio) {
    const C = 20;
    const caixas = new Set();
    const circulos = new Set();
    for (let cx = Math.floor((x - raio) / C); cx <= Math.floor((x + raio) / C); cx++) {
      for (let cz = Math.floor((z - raio) / C); cz <= Math.floor((z + raio) / C); cz++) {
        const c = this.celulas.get(this._chave(cx, cz));
        if (!c) continue;
        c.caixas.forEach((o) => caixas.add(o));
        c.circulos.forEach((o) => circulos.add(o));
      }
    }
    return { caixas, circulos };
  }

  addCaixa(minX, maxX, minZ, maxZ, tipo = 'predio') {
    const c = { minX, maxX, minZ, maxZ, tipo };
    this.caixas.push(c);
    this._indexar(c, minX, maxX, minZ, maxZ, 'caixas');
    return c;
  }

  addCirculo(x, z, r) {
    const c = { x, z, r };
    this.circulos.push(c);
    this._indexar(c, x - r, x + r, z - r, z + r, 'circulos');
    return c;
  }

  // Linha de visao 2D: algum predio entre A e B?
  temVisao(ax, az, bx, bz) {
    const minX = Math.min(ax, bx), maxX = Math.max(ax, bx);
    const minZ = Math.min(az, bz), maxZ = Math.max(az, bz);
    const dx = bx - ax, dz = bz - az;
    for (const c of this.caixas) {
      if (c.tipo !== 'predio') continue;
      if (c.maxX < minX || c.minX > maxX || c.maxZ < minZ || c.minZ > maxZ) continue;
      let t0 = 0, t1 = 1;
      const testa = (p, q) => {
        if (p === 0) return q >= 0;
        const t = q / p;
        if (p < 0) {
          if (t > t1) return false;
          if (t > t0) t0 = t;
        } else {
          if (t < t0) return false;
          if (t < t1) t1 = t;
        }
        return true;
      };
      if (testa(-dx, ax - c.minX) && testa(dx, c.maxX - ax) && testa(-dz, az - c.minZ) && testa(dz, c.maxZ - az)) {
        if (t0 <= t1) return false;
      }
    }
    return true;
  }

  // ------------------------------------------------------------------ montagem
  colocar(nome, x, z, rot = 0, op = {}) {
    const o = instanciar(nome);
    o.position.set(x, op.y ?? this.alturaChao(x, z), z);
    o.rotation.y = rot;
    if (op.escalaY) o.scale.y = op.escalaY;
    if (op.paleta) pintarComPaleta(o, op.paleta[0], op.paleta[1]);
    this.fusao.adicionar(o);
    if (op.caixa) {
      const b = new THREE.Box3().setFromObject(o);
      const m = op.margem ?? 0.15;
      this.addCaixa(b.min.x + m, b.max.x - m, b.min.z + m, b.max.z - m, op.tipo || 'predio');
    }
    if (op.raio) this.addCirculo(x, z, op.raio);
    return o;
  }

  caixaChao(x, z, lx, lz, cor, y = 0.07, alt = 0.2) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(lx, alt, lz), this.material(cor));
    m.position.set(x, y, z);
    this.fusao.adicionar(m);
  }

  material(cor, rough = 0.95) {
    this._mats = this._mats || new Map();
    if (!this._mats.has(cor)) this._mats.set(cor, new THREE.MeshStandardMaterial({ color: cor, roughness: rough }));
    return this._mats.get(cor);
  }

  construir() {
    this.construirRuas();
    for (let bi = 0; bi < 5; bi++) {
      for (let bj = 0; bj < 5; bj++) this.construirBloco(bi, bj);
    }
    this.construirOrlaEPraia();
    this.construirPropsDeRua();
    this.fusao.construir(this.cena);

    // chao fora da cidade e agua
    const chao = new THREE.Mesh(new THREE.PlaneGeometry(1400, 1400), this.material('#a19d6c'));
    chao.rotation.x = -Math.PI / 2;
    chao.position.y = -0.02;
    chao.receiveShadow = true;
    this.cena.add(chao);
    const agua = new THREE.Mesh(
      new THREE.PlaneGeometry(800, 1400),
      new THREE.MeshStandardMaterial({ color: '#2c9db5', roughness: 0.18, metalness: 0.15 })
    );
    agua.rotation.x = -Math.PI / 2;
    agua.position.set(BORDA + 46 + 400, 0.08, 0);
    this.cena.add(agua);
    this.agua = agua;
  }

  construirRuas() {
    for (let i = 0; i < N; i++) {
      for (let j = 0; j < N; j++) {
        const x = nodoX(i), z = nodoX(j);
        this.colocar('rua_cruzamento', x, z, 0, { y: 0 });
        for (let k = 1; k <= 5; k++) {
          if (j < N - 1) this.colocar('rua_reta', x, z + k * 12, 0, { y: 0 });
          if (i < N - 1) this.colocar('rua_reta', x + k * 12, z, Math.PI / 2, { y: 0 });
        }
      }
    }
  }

  construirBloco(bi, bj) {
    const cx = (bi - 2) * ESP, cz = (bj - 2) * ESP;
    const d = distritoDoBloco(bi, bj);
    this.blocos.push({ bi, bj, cx, cz, distrito: d });
    this.caixaChao(cx, cz, 60, 60, DISTRITOS[d].cor);
    const r = () => this.r();

    if (d === 'centro') {
      const lugares = [[-17, -16, 0], [17, -16, 0], [-17, 16, Math.PI], [17, 16, Math.PI]];
      const lojaIdx = Math.floor(r() * 5); // as vezes nenhum (indice 4)
      lugares.forEach(([x, z, rot], idx) => {
        if (idx === lojaIdx) {
          this.colocar('loja', cx + x, cz + z + (z < 0 ? -9 : 9), rot, { caixa: true });
        } else {
          this.colocar('predio_centro', cx + x, cz + z, rot, { caixa: true, escalaY: 0.5 + r() * 0.75 });
        }
      });
      this.colocar('palmeira', cx - 3, cz, r() * 6, { raio: 0.35 });
      this.colocar('palmeira', cx + 4, cz + 2, r() * 6, { raio: 0.35 });
      this.colocar('lixeira', cx, cz + 4, 0, { raio: 0.3 });
      if (bi === 2 && bj === 0) this.poi.torre = { x: cx + 17, z: cz - 16 - 9.5, nome: 'Torre Brasa' };
      if (bi === 1 && bj === 1) this.poi.praca = { x: cx, z: cz - 6, nome: 'Praça do Centro' };
    }

    if (d === 'orla') {
      const leste = -Math.PI / 2; // frente para +X (avenida da orla)
      if (bj === 1) {
        this.colocar('oficina_pintura', cx + 20, cz, leste, { caixa: true });
        this.poi.oficina = { x: cx + 29, z: cz - 1.5, nome: 'Oficina de Pintura' };
      } else {
        this.colocar('loja', cx + 20, cz - 14, leste, { caixa: true });
        if (bj === 3) this.poi.loja = { x: cx + 26.5, z: cz - 12, nome: 'Mercado da Orla' };
      }
      if (bj === 3) {
        // estacionamento com o esportivo da missao 1
        this.caixaChao(cx + 14, cz + 16, 26, 18, '#5a5a5e', 0.072, 0.2);
        this.poi.esportivo = { x: cx + 14, z: cz + 16, h: Math.PI / 2 };
      } else {
        this.colocar('casa_suburbio', cx + 20, cz + 14, leste, { caixa: true, paleta: ['Pintura_Casa', '#f2c9a0'] });
      }
      this.colocar('predio_centro', cx - 16, cz - 12, Math.PI / 2, { caixa: true, escalaY: 0.35 + r() * 0.3 });
      this.colocar('palmeira', cx - 10, cz + 14, r() * 6, { raio: 0.35 });
      this.colocar('palmeira', cx - 20, cz + 18, r() * 6, { raio: 0.35 });
    }

    if (d === 'porto') {
      this.colocar('galpao_porto', cx, cz - 5, 0, { caixa: true, paleta: ['Pintura_Galpao', ['#9aa3a8', '#b59a6a', '#8fa08a'][bj % 3]] });
      if (bi === 0 && bj === 3) this.poi.galpao = { x: cx - 7, z: cz - 5 - 10.4 - 5, nome: 'Armazém 3' };
      if (bi === 0 && bj === 1) this.poi.encontro = { x: cx + 8, z: cz + 22, nome: 'Encontro no Porto' };
      const cores = ['#1f5f8b', '#b8362b', '#2f7d4a', '#d08a22', '#6a6f75'];
      for (let x = -22; x <= 22; x += 4.4) {
        if (bi === 0 && bj === 1 && Math.abs(x - 8) < 7) continue;
        if (r() < 0.25) continue;
        const alt = r() < 0.4 ? 2 : 1;
        for (let h = 0; h < alt; h++) {
          this.colocar('conteiner', cx + x, cz + 21, h * 0.04, {
            y: 0.17 + h * 2.59, paleta: ['Pintura_Conteiner', cores[Math.floor(r() * cores.length)]],
          });
        }
        this.addCaixa(cx + x - 1.3, cx + x + 1.3, cz + 21 - 3.1, cz + 21 + 3.1);
      }
    }

    if (d === 'suburbio') {
      const cores = ['#e9d6a6', '#bfe0d2', '#f2b8a0', '#d6d0f0', '#f4efe4'];
      for (const x of [-18, 0, 18]) {
        for (const [z, rot] of [[-15, 0], [15, Math.PI]]) {
          const casaSegura = bi === 3 && bj === 3 && x === 0 && z === -15;
          this.colocar('casa_suburbio', cx + x, cz + z, rot, {
            caixa: true, paleta: ['Pintura_Casa', casaSegura ? '#7fb3d5' : cores[Math.floor(r() * cores.length)]],
          });
          if (casaSegura) this.poi.casa = { x: cx + x - 1.6, z: cz + z - 6.4, nome: 'Casa Segura' };
          if (!casaSegura && r() < 0.35) {
            const fz = z < 0 ? -24 : 24;
            this.estacionados.push({ x: cx + x + 3.2, z: cz + fz, h: z < 0 ? Math.PI / 2 : -Math.PI / 2 });
          }
        }
      }
      if (r() < 0.6) this.colocar('palmeira', cx + 9, cz, r() * 6, { raio: 0.35 });
    }
  }

  construirOrlaEPraia() {
    // faixa de areia ao leste da avenida da orla
    this.caixaChao(BORDA + 30, 0, 60, 2 * BORDA + 60, '#e8d3a0', 0.0, 0.12);
    for (let z = -BORDA + 6; z <= BORDA; z += 13) {
      this.colocar('palmeira', BORDA + 2.5 + this.r() * 2, z, this.r() * 6, { raio: 0.35, y: 0.06 });
      if (this.r() < 0.5) this.colocar('palmeira', BORDA + 16 + this.r() * 18, z + 5, this.r() * 6, { raio: 0.35, y: 0.06 });
    }
  }

  construirPropsDeRua() {
    const r = () => this.r();
    for (let i = 0; i < N; i++) {
      for (let j = 0; j < N; j++) {
        const x = nodoX(i), z = nodoX(j);
        // semaforos em dois cantos
        this.colocar('semaforo', x + 5, z + 5, Math.PI, { raio: 0.25 });
        this.colocar('semaforo', x - 5, z - 5, 0, { raio: 0.25 });
        // postes nos trechos
        [15, 39, 63].forEach((s, k) => {
          const lado = k % 2 === 0 ? 1 : -1;
          if (j < N - 1) {
            const px = x + lado * 5.4, pz = z + s;
            this.colocar('poste', px, pz, headingDe(-lado, 0), { raio: 0.25 });
          }
          if (i < N - 1) {
            const px = x + s, pz = z + lado * 5.4;
            this.colocar('poste', px, pz, headingDe(0, -lado), { raio: 0.25 });
          }
        });
        if (j < N - 1 && r() < 0.5) this.colocar('hidrante', x - 5.3, z + 27, 0, { raio: 0.25 });
        if (i < N - 1 && r() < 0.5) this.colocar('lixeira', x + 50, z + 5.4, 0, { raio: 0.3 });
      }
    }
  }
}
