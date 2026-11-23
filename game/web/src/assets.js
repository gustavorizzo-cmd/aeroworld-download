import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import MODELOS from 'modelos-embutidos';

const modelos = {};

function base64ParaBuffer(b64) {
  const bin = atob(b64);
  const u8 = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  return u8.buffer;
}

export async function carregarModelos(progresso) {
  const loader = new GLTFLoader();
  const nomes = Object.keys(MODELOS);
  let n = 0;
  for (const nome of nomes) {
    const gltf = await loader.parseAsync(base64ParaBuffer(MODELOS[nome]), '');
    gltf.scene.traverse((o) => {
      if (o.isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
        const m = o.material;
        if (m && m.emissiveIntensity !== undefined && m.emissive && m.emissive.getHex() !== 0) {
          m.emissiveIntensity = Math.min(m.emissiveIntensity, 2.5);
        }
      }
    });
    modelos[nome] = gltf.scene;
    n++;
    progresso?.(n / nomes.length, nome);
    await new Promise((r) => setTimeout(r, 0));
  }
}

export function instanciar(nome) {
  const m = modelos[nome];
  if (!m) throw new Error('Modelo inexistente: ' + nome);
  return m.clone(true);
}

// Clona os materiais cujo nome comeca com `prefixo` e aplica a cor.
// Devolve a lista de materiais clonados (para trocar a cor depois).
export function pintar(obj, prefixo, cor) {
  const cache = new Map();
  obj.traverse((o) => {
    if (!o.isMesh) return;
    const trocar = (m) => {
      if (!m.name.startsWith(prefixo)) return m;
      if (!cache.has(m)) {
        const c = m.clone();
        c.color.set(cor);
        cache.set(m, c);
      }
      return cache.get(m);
    };
    o.material = Array.isArray(o.material) ? o.material.map(trocar) : trocar(o.material);
  });
  return [...cache.values()];
}

// Paleta compartilhada: varios objetos estaticos usam o mesmo material clonado por cor,
// o que mantem poucas chamadas de desenho depois da fusao.
const paleta = new Map();
export function pintarComPaleta(obj, prefixo, cor) {
  obj.traverse((o) => {
    if (!o.isMesh) return;
    const trocar = (m) => {
      if (!m.name.startsWith(prefixo)) return m;
      const chave = m.name + '|' + cor;
      if (!paleta.has(chave)) {
        const c = m.clone();
        c.color.set(cor);
        paleta.set(chave, c);
      }
      return paleta.get(chave);
    };
    o.material = Array.isArray(o.material) ? o.material.map(trocar) : trocar(o.material);
  });
}

// Junta toda a geometria estatica em uma malha por material.
export class Fusao {
  constructor() {
    this.grupos = new Map();
  }

  adicionar(obj) {
    obj.updateMatrixWorld(true);
    obj.traverse((o) => {
      if (!o.isMesh) return;
      const g = o.geometry.clone();
      for (const nome of Object.keys(g.attributes)) {
        if (nome !== 'position' && nome !== 'normal') g.deleteAttribute(nome);
      }
      if (!g.index) {
        const n = g.attributes.position.count;
        const idx = new (n > 65535 ? Uint32Array : Uint16Array)(n);
        for (let i = 0; i < n; i++) idx[i] = i;
        g.setIndex(new THREE.BufferAttribute(idx, 1));
      }
      g.applyMatrix4(o.matrixWorld);
      const m = o.material;
      if (!this.grupos.has(m)) this.grupos.set(m, []);
      this.grupos.get(m).push(g);
    });
  }

  construir(cena, sombra = true) {
    const grupo = new THREE.Group();
    for (const [m, geos] of this.grupos) {
      // indices de 16 bits nao bastam depois da fusao: converte tudo para 32 bits
      for (const g of geos) {
        if (!(g.index.array instanceof Uint32Array)) g.setIndex(new THREE.BufferAttribute(Uint32Array.from(g.index.array), 1));
      }
      const fundida = mergeGeometries(geos, false);
      if (!fundida) continue;
      fundida.computeBoundingSphere();
      const malha = new THREE.Mesh(fundida, m);
      malha.castShadow = sombra;
      malha.receiveShadow = true;
      malha.matrixAutoUpdate = false;
      grupo.add(malha);
    }
    cena.add(grupo);
    this.grupos.clear();
    return grupo;
  }
}
