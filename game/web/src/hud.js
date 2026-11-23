import { BORDA, N, nodoX, DISTRITOS } from './mapa.js';
import { formatarDinheiro, dist } from './util.js';

const $ = (id) => document.getElementById(id);
const MUNDO = { minX: -230, maxX: 260, minZ: -230, maxZ: 230 }; // area desenhada no mapa
const ESCALA = 2; // px por metro na imagem base

export class Hud {
  constructor(jogo) {
    this.jogo = jogo;
    this.el = {
      estrelas: [...document.querySelectorAll('#estrelas .estrela')],
      estrelasBox: $('estrelas'),
      fichaCarro: $('ficha-carro'),
      fichaRoupa: $('ficha-roupa'),
      dinheiro: $('dinheiro'),
      objTitulo: $('obj-titulo'),
      objTexto: $('obj-texto'),
      cronometro: $('cronometro'),
      msgs: $('mensagens'),
      prompt: $('prompt'),
      velo: $('velocimetro'),
      veloNum: $('velo-num'),
      lataria: $('lataria-barra'),
      prisao: $('prisao'),
      prisaoBarra: $('prisao-barra'),
      ligacao: $('ligacao'),
      banner: $('banner'),
      bannerTit: $('banner-titulo'),
      bannerSub: $('banner-sub'),
      distrito: $('distrito'),
      busca: $('aviso-busca'),
      mapaGrande: $('mapa-grande'),
    };
    this.mini = $('minimapa');
    this.ctx = this.mini.getContext('2d');
    this.grande = $('mapa-canvas');
    this.ctxG = this.grande.getContext('2d');
    this.base = this.desenharBase();
    this.distritoAtual = null;
    this.tBanner = 0;
  }

  // ---------- mapa base (desenhado uma vez)
  desenharBase() {
    const mapa = this.jogo.mapa;
    const w = (MUNDO.maxX - MUNDO.minX) * ESCALA, h = (MUNDO.maxZ - MUNDO.minZ) * ESCALA;
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    const g = c.getContext('2d');
    const X = (x) => (x - MUNDO.minX) * ESCALA, Z = (z) => (z - MUNDO.minZ) * ESCALA;
    g.fillStyle = '#3d4636';
    g.fillRect(0, 0, w, h);
    g.fillStyle = '#c9b27c';
    g.fillRect(X(BORDA), 0, X(BORDA + 46) - X(BORDA), h);
    g.fillStyle = '#1f6f86';
    g.fillRect(X(BORDA + 46), 0, w - X(BORDA + 46), h);
    for (const b of mapa.blocos) {
      g.fillStyle = DISTRITOS[b.distrito].mapa;
      g.fillRect(X(b.cx - 30), Z(b.cz - 30), 60 * ESCALA, 60 * ESCALA);
    }
    g.fillStyle = '#2a2f36';
    for (const k of mapa.caixas) {
      if (k.tipo !== 'predio') continue;
      g.fillRect(X(k.minX), Z(k.minZ), (k.maxX - k.minX) * ESCALA, (k.maxZ - k.minZ) * ESCALA);
    }
    g.strokeStyle = '#d9d4c7';
    g.lineWidth = 8 * ESCALA;
    g.lineCap = 'square';
    for (let i = 0; i < N; i++) {
      g.beginPath();
      g.moveTo(X(nodoX(i)), Z(nodoX(0)));
      g.lineTo(X(nodoX(i)), Z(nodoX(N - 1)));
      g.moveTo(X(nodoX(0)), Z(nodoX(i)));
      g.lineTo(X(nodoX(N - 1)), Z(nodoX(i)));
      g.stroke();
    }
    return c;
  }

  // ---------- mensagens
  mensagem(texto, seg = 2.5) {
    const d = document.createElement('div');
    d.className = 'msg';
    d.textContent = texto;
    this.el.msgs.appendChild(d);
    while (this.el.msgs.children.length > 3) this.el.msgs.firstChild.remove();
    setTimeout(() => d.classList.add('sai'), seg * 1000);
    setTimeout(() => d.remove(), seg * 1000 + 400);
  }

  dica(texto) {
    if (this._ultimaDica === texto && performance.now() - this._tDica < 4000) return;
    this._ultimaDica = texto;
    this._tDica = performance.now();
    this.mensagem(texto, 2.5);
  }

  banner(titulo, sub, seg = 3) {
    this.el.bannerTit.textContent = titulo;
    this.el.bannerSub.textContent = sub || '';
    this.el.banner.hidden = false;
    this.el.banner.classList.remove('sai');
    this.tBanner = seg;
  }

  cronometro(seg) {
    const c = this.el.cronometro;
    if (seg === null || seg === undefined) {
      c.hidden = true;
      return;
    }
    c.hidden = false;
    const s = Math.max(0, Math.ceil(seg));
    c.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
    c.classList.toggle('urgente', s <= 15);
  }

  alternarMapa() {
    this.el.mapaGrande.hidden = !this.el.mapaGrande.hidden;
  }

  // ---------- quadro a quadro
  atualizar(dt) {
    const jogo = this.jogo, j = jogo.jogador, p = jogo.policia;

    // estrelas
    const pisca = p.modo === 'perseguicao' && Math.floor(jogo.tempo * 4) % 2 === 0;
    this.el.estrelas.forEach((e, i) => {
      e.classList.toggle('ativa', i < p.estrelas);
      e.classList.toggle('alt', i < p.estrelas && pisca);
    });
    this.el.estrelasBox.dataset.modo = p.modo;
    this.el.busca.hidden = p.modo !== 'busca';
    if (p.modo === 'busca' && p.zona) {
      const fora = dist(j.px, j.pz, p.zona.x, p.zona.z) > p.zona.r;
      this.el.busca.textContent = fora
        ? `Fora da área de busca: ${Math.max(0, Math.ceil(5 + 2 * p.estrelas - p.foraTempo))} s para despistar`
        : 'Procurando você: saia do círculo no mapa';
    }

    // ficha
    const f = p.fichaAtiva();
    const carroAtual = j.veiculo && p.ficha.carro === j.veiculo;
    const roupaAtual = !j.veiculo && p.ficha.roupa === j.roupaId;
    this.el.fichaCarro.dataset.estado = f.carro ? (carroAtual ? 'perigo' : 'conhecido') : 'limpo';
    this.el.fichaRoupa.dataset.estado = f.roupa ? (p.ficha.roupa === j.roupaId ? (roupaAtual ? 'perigo' : 'conhecido') : 'conhecido') : 'limpo';

    this.el.dinheiro.textContent = formatarDinheiro(jogo.dinheiro);
    const o = jogo.missoes.textoObjetivo();
    this.el.objTitulo.textContent = o.titulo;
    this.el.objTexto.textContent = o.texto;

    // velocimetro
    if (j.veiculo) {
      this.el.velo.hidden = false;
      this.el.veloNum.textContent = Math.round(j.veiculo.velocidade * 3.6);
      this.el.lataria.style.width = j.veiculo.vida + '%';
      this.el.lataria.dataset.estado = j.veiculo.vida < 35 ? 'ruim' : j.veiculo.vida < 65 ? 'medio' : 'bom';
    } else this.el.velo.hidden = true;

    // prisao
    this.el.prisao.hidden = p.prendendo <= 0.05;
    this.el.prisaoBarra.style.width = Math.min(100, (p.prendendo / 2.5) * 100) + '%';

    // testemunha ligando
    const lig = jogo.pedestres.lista.find((x) => x.estado === 'ligando');
    this.el.ligacao.hidden = !lig;
    if (lig) this.el.ligacao.textContent = `Testemunha ligando para a polícia… ${Math.ceil(lig.timer)} s`;

    // prompt de acao
    this.el.prompt.textContent = jogo.promptAtual || '';
    this.el.prompt.hidden = !jogo.promptAtual;

    // distrito
    const d = jogo.mapa.distrito(j.px, j.pz);
    if (d && d !== this.distritoAtual) {
      this.distritoAtual = d;
      this.el.distrito.textContent = DISTRITOS[d].nome;
      this.el.distrito.classList.remove('mostra');
      void this.el.distrito.offsetWidth;
      this.el.distrito.classList.add('mostra');
    }

    if (this.tBanner > 0) {
      this.tBanner -= dt;
      if (this.tBanner <= 0) {
        this.el.banner.classList.add('sai');
        setTimeout(() => (this.el.banner.hidden = this.tBanner <= 0), 400);
      }
    }

    this.desenharMini();
    if (!this.el.mapaGrande.hidden) this.desenharGrande();
  }

  sobrepor(g, X, Z, s, raioPx) {
    const jogo = this.jogo, j = jogo.jogador, p = jogo.policia;
    // area de busca
    if (p.zona && p.modo === 'busca') {
      g.beginPath();
      g.arc(X(p.zona.x), Z(p.zona.z), p.zona.r * s, 0, Math.PI * 2);
      const t = Math.floor(jogo.tempo * 2) % 2;
      g.fillStyle = t ? 'rgba(255,42,58,0.18)' : 'rgba(47,107,255,0.18)';
      g.fill();
      g.lineWidth = 2;
      g.strokeStyle = t ? '#ff2a3a' : '#2f6bff';
      g.stroke();
    }
    // GPS
    const alvo = jogo.missoes.alvoAtual();
    if (alvo) {
      const pts = jogo.mapa.rotaGPS(j.px, j.pz, alvo.x, alvo.z);
      g.beginPath();
      pts.forEach((q, i) => (i ? g.lineTo(X(q.x), Z(q.z)) : g.moveTo(X(q.x), Z(q.z))));
      g.lineWidth = Math.max(3, 4 * s);
      g.strokeStyle = alvo.inicio ? '#ffcc33' : '#22d3ee';
      g.lineJoin = 'round';
      g.stroke();
      g.beginPath();
      g.arc(X(alvo.x), Z(alvo.z), Math.max(5, 6 * s), 0, Math.PI * 2);
      g.fillStyle = alvo.inicio ? '#ffcc33' : '#22d3ee';
      g.fill();
      g.lineWidth = 2;
      g.strokeStyle = '#10161d';
      g.stroke();
    }
    // pontos fixos
    const poi = jogo.mapa.poi;
    const icone = (q, letra, cor) => {
      const x = X(q.x), z = Z(q.z);
      g.beginPath();
      g.arc(x, z, raioPx, 0, Math.PI * 2);
      g.fillStyle = cor;
      g.fill();
      g.fillStyle = '#10161d';
      g.font = `700 ${Math.round(raioPx * 1.3)}px "Barlow Condensed", system-ui, sans-serif`;
      g.textAlign = 'center';
      g.textBaseline = 'middle';
      g.fillText(letra, x, z + 0.5);
    };
    icone(poi.casa, 'C', '#7fd1ff');
    icone(poi.oficina, 'P', '#ffb057');
    // viaturas so aparecem se estiverem perto e a vista (sem radar de policia)
    for (const v of jogo.veiculos) {
      if (!v.policia || !v.ia || v.ia.tipo === 'trafego') continue;
      if (dist(v.x, v.z, j.px, j.pz) > 45) continue;
      g.fillStyle = Math.floor(jogo.tempo * 6) % 2 ? '#ff2a3a' : '#2f6bff';
      g.fillRect(X(v.x) - 3, Z(v.z) - 3, 6, 6);
    }
    // jogador
    const h = j.veiculo ? j.veiculo.h : j.h;
    g.save();
    g.translate(X(j.px), Z(j.pz));
    g.rotate(-h);
    g.beginPath();
    g.moveTo(0, -9);
    g.lineTo(6, 7);
    g.lineTo(0, 3);
    g.lineTo(-6, 7);
    g.closePath();
    g.fillStyle = '#ff6a2b';
    g.fill();
    g.lineWidth = 2;
    g.strokeStyle = '#fff';
    g.stroke();
    g.restore();
  }

  desenharMini() {
    const g = this.ctx, j = this.jogo.jogador;
    const tam = this.mini.width;
    const alcance = j.veiculo ? 110 : 70; // metros do centro a borda
    const s = tam / 2 / alcance;
    g.save();
    g.clearRect(0, 0, tam, tam);
    g.beginPath();
    g.arc(tam / 2, tam / 2, tam / 2 - 1, 0, Math.PI * 2);
    g.clip();
    const sx = (j.px - alcance - MUNDO.minX) * ESCALA, sz = (j.pz - alcance - MUNDO.minZ) * ESCALA;
    g.fillStyle = '#3d4636';
    g.fillRect(0, 0, tam, tam);
    g.drawImage(this.base, sx, sz, alcance * 2 * ESCALA, alcance * 2 * ESCALA, 0, 0, tam, tam);
    const X = (x) => (x - j.px) * s + tam / 2, Z = (z) => (z - j.pz) * s + tam / 2;
    this.sobrepor(g, X, Z, s, 8);
    g.restore();
    g.beginPath();
    g.arc(tam / 2, tam / 2, tam / 2 - 1.5, 0, Math.PI * 2);
    g.lineWidth = 3;
    g.strokeStyle = 'rgba(246,239,227,0.85)';
    g.stroke();
    g.fillStyle = '#f6efe3';
    g.font = '700 13px "Barlow Condensed", system-ui, sans-serif';
    g.textAlign = 'center';
    g.fillText('N', tam / 2, 14);
  }

  desenharGrande() {
    const c = this.grande, g = this.ctxG;
    const r = c.getBoundingClientRect();
    const dpr = Math.min(2, devicePixelRatio || 1);
    if (c.width !== Math.round(r.width * dpr)) {
      c.width = Math.round(r.width * dpr);
      c.height = Math.round(r.height * dpr);
    }
    const w = c.width, h = c.height;
    const s = Math.min(w / (MUNDO.maxX - MUNDO.minX), h / (MUNDO.maxZ - MUNDO.minZ));
    const ox = (w - (MUNDO.maxX - MUNDO.minX) * s) / 2, oz = (h - (MUNDO.maxZ - MUNDO.minZ) * s) / 2;
    g.fillStyle = '#10161d';
    g.fillRect(0, 0, w, h);
    g.drawImage(this.base, ox, oz, (MUNDO.maxX - MUNDO.minX) * s, (MUNDO.maxZ - MUNDO.minZ) * s);
    const X = (x) => ox + (x - MUNDO.minX) * s, Z = (z) => oz + (z - MUNDO.minZ) * s;
    this.sobrepor(g, X, Z, s, 9 * dpr);
    g.font = `700 ${Math.round(15 * dpr)}px "Barlow Condensed", system-ui, sans-serif`;
    g.textAlign = 'center';
    g.fillStyle = 'rgba(246,239,227,0.9)';
    const rot = { centro: [0, -72], orla: [144, -144], porto: [-144, 0], suburbio: [36, 144] };
    for (const [k, [x, z]] of Object.entries(rot)) g.fillText(DISTRITOS[k].nome.toUpperCase(), X(x), Z(z));
  }
}
