// Utilidades gerais. Convencao de direcao (Three.js, Y para cima):
// heading = rotation.y; frente = (-sin h, -cos h) no plano XZ. Norte = -Z.
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const lerp = (a, b, t) => a + (b - a) * t;
export const rand = (a, b) => a + Math.random() * (b - a);
export const randi = (a, b) => Math.floor(rand(a, b + 1));
export const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

export function angDiff(a, b) {
  let d = b - a;
  while (d > Math.PI) d -= 2 * Math.PI;
  while (d < -Math.PI) d += 2 * Math.PI;
  return d;
}

export const frente = (h) => ({ x: -Math.sin(h), z: -Math.cos(h) });
export const direita = (h) => ({ x: Math.cos(h), z: -Math.sin(h) });
export const headingDe = (dx, dz) => Math.atan2(-dx, -dz);
export const dist2 = (ax, az, bx, bz) => (ax - bx) ** 2 + (az - bz) ** 2;
export const dist = (ax, az, bx, bz) => Math.sqrt(dist2(ax, az, bx, bz));

export function suavizar(atual, alvo, taxa, dt) {
  return atual + (alvo - atual) * (1 - Math.exp(-taxa * dt));
}

export function formatarDinheiro(v) {
  return 'R$ ' + Math.round(v).toLocaleString('pt-BR');
}

export const armazenamento = {
  ler(chave, padrao) {
    try {
      const v = localStorage.getItem(chave);
      return v ? JSON.parse(v) : padrao;
    } catch {
      return padrao;
    }
  },
  gravar(chave, valor) {
    try {
      localStorage.setItem(chave, JSON.stringify(valor));
    } catch {
      /* sem armazenamento: o jogo segue sem salvar */
    }
  },
};
