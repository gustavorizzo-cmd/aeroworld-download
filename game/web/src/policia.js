import * as THREE from 'three';
import { Veiculo } from './veiculo.js';
import { instanciar } from './assets.js';
import { dirigirPara, iniciarIATrafego } from './trafego.js';
import { nodoPos, nodoX, N } from './mapa.js';
import { angDiff, headingDe, dist, frente, clamp, pick, rand } from './util.js';

// Unidades por estrela (0..4). Com 3+ estrelas ha bloqueios; com 4 ha helicoptero.
const UNIDADES = [0, 2, 3, 4, 5];

export class Policia {
  constructor(jogo) {
    this.jogo = jogo;
    this.estrelas = 0;
    this.modo = 'limpo'; // limpo | perseguicao | busca
    this.ultima = { x: 0, z: 0 };
    this.zona = null;
    this.semVer = 0;
    this.foraTempo = 0;
    this.tempoNivel = 0;
    this.ficha = { carro: null, roupa: null, expira: 0 };
    this.vendo = false;
    this.tVisao = 0;
    this.tSpawn = 0;
    this.cdBatida = 0;
    this.cdBloqueio = 6;
    this.prendendo = 0;
    this.carencia = 3; // segundos sem a policia agir (inicio do jogo e depois de preso)
    this.bloqueios = [];
    this.heli = null;
    // luz do helicoptero criada desde o inicio (adicionar luz depois recompila todos os shaders)
    this.luzHeli = new THREE.SpotLight(0xfff1c9, 0, 90, 0.2, 0.5, 1);
    this.alvoLuz = new THREE.Object3D();
    this.luzHeli.target = this.alvoLuz;
    jogo.cena.add(this.luzHeli, this.alvoLuz);
  }

  get j() {
    return this.jogo.jogador;
  }

  olhos() {
    return this.jogo.veiculos.filter((v) => v.policia && v.motorista === 'ia');
  }

  unidades() {
    return this.jogo.veiculos.filter((v) => v.ia && v.ia.tipo === 'unidade');
  }

  podeVer(v, x, z, alcance = 60) {
    const d = dist(v.x, v.z, x, z);
    if (d > alcance) return false;
    if (d > 12 && Math.abs(angDiff(v.h, headingDe(x - v.x, z - v.z))) > 1.25) return false;
    return this.jogo.mapa.temVisao(v.x, v.z, x, z);
  }

  heliVe() {
    const h = this.heli;
    return h && !h.saindo && dist(h.x, h.z, this.j.px, this.j.pz) < 70;
  }

  // A policia sabe que e voce? Depende do modo e da Ficha.
  reconhece(d) {
    const j = this.j;
    if (this.modo === 'perseguicao') return true;
    const busca = this.modo === 'busca';
    if (j.veiculo) {
      if (this.ficha.carro && j.veiculo === this.ficha.carro) return d < 50;
      return busca && d < 12;
    }
    if (this.ficha.roupa !== null && this.ficha.roupa === j.roupaId) return d < 20;
    return busca && d < 8;
  }

  fichaAtiva() {
    return { carro: !!this.ficha.carro, roupa: this.ficha.roupa !== null };
  }

  registrar(d) {
    if (d.carro) this.ficha.carro = d.carro;
    if (d.roupa !== null && d.roupa !== undefined) this.ficha.roupa = d.roupa;
    this.ficha.expira = this.jogo.tempo + 150;
  }

  limparFicha(qual) {
    if (qual === 'carro' || qual === 'tudo') this.ficha.carro = null;
    if (qual === 'roupa' || qual === 'tudo') this.ficha.roupa = null;
  }

  aplicar(n, msg) {
    const novo = Math.min(4, Math.max(this.estrelas, n));
    if (novo > this.estrelas) {
      this.estrelas = novo;
      this.tempoNivel = 0;
      if (msg) this.jogo.hud.mensagem(msg, 3);
      this.jogo.audio.alerta();
    }
  }

  raio() {
    return 45 + 25 * this.estrelas;
  }

  // ------------------------------------------------------------------ crimes
  crime(tipo, x, z, estrelas, op = {}) {
    const jogo = this.jogo, j = this.j;
    const carro = op.carro !== undefined ? op.carro : j.veiculo;
    const aPe = !j.veiculo;
    const d = { tipo, x, z, estrelas, carro, roupa: aPe ? j.roupaId : null };

    const viu = this.olhos().some((v) => this.podeVer(v, x, z, 55)) || this.heliVe();
    if (viu) {
      this.registrar(d);
      this.aplicar(estrelas, this.estrelas ? 'A polícia viu! Mais estrelas.' : 'A polícia viu o crime!');
      this.modo = 'perseguicao';
      this.semVer = 0;
      this.ultima = { x: j.px, z: j.pz };
      return;
    }
    if (op.soPolicia) return;
    if (op.alarme) {
      this.denuncia(d);
      return;
    }
    if (op.vitima) {
      op.vitima.crime = d;
      jogo.hud.mensagem('O motorista vai chamar a polícia! Fuja ou chegue perto para impedir.', 3.5);
      return;
    }
    const t = jogo.pedestres.testemunha(x, z);
    if (t) {
      jogo.pedestres.ligar(t, d);
      jogo.hud.mensagem('Uma testemunha viu! Chegue perto dela para impedir a ligação.', 3.5);
    } else if (this.estrelas === 0) {
      jogo.hud.mensagem('Ninguém viu.', 1.5);
    }
    jogo.pedestres.panico(x, z, 18);
  }

  vitimaVaiLigar(p) {
    if (p.crime) this.jogo.pedestres.ligar(p, p.crime);
  }

  denuncia(d) {
    if (!d) return;
    this.registrar(d);
    const jaProcurado = this.estrelas > 0;
    this.aplicar(d.estrelas, 'Denúncia! A polícia está a caminho.');
    if (!jaProcurado || this.modo === 'limpo') {
      this.modo = 'busca';
      this.zona = { x: d.x, z: d.z, r: this.raio() };
      this.semVer = 10;
      this.foraTempo = 0;
    }
  }

  denunciaCancelada(intimidado) {
    if (intimidado) this.jogo.hud.mensagem('Você assustou a testemunha. Ela não ligou.', 2.5);
  }

  eventoBatida(a, b, forca) {
    const j = this.j;
    const meu = a.motorista === 'jogador' ? a : b.motorista === 'jogador' ? b : null;
    if (!meu) return;
    const outro = meu === a ? b : a;
    // quem bateu em quem? compara a velocidade de cada carro na direcao do outro
    const dl = Math.hypot(outro.x - meu.x, outro.z - meu.z) || 1;
    const dx = (outro.x - meu.x) / dl, dz = (outro.z - meu.z) / dl;
    const culpaMinha = meu.vx * dx + meu.vz * dz > -(outro.vx * dx + outro.vz * dz) + 1;
    if (!culpaMinha || this.carencia > 0) return;
    if (outro.policia && outro.motorista === 'ia' && this.cdBatida <= 0) {
      this.cdBatida = 4;
      this.registrar({ carro: meu, roupa: null });
      if (this.estrelas === 0) this.aplicar(1, 'Você bateu numa viatura!');
      else this.aplicar(this.estrelas + 1, 'Você bateu numa viatura! Mais uma estrela.');
      this.modo = 'perseguicao';
      this.semVer = 0;
      this.ultima = { x: j.px, z: j.pz };
    } else if (!outro.policia && forca > 10 && this.cdBatida <= 0) {
      this.cdBatida = 2;
      this.crime('batida', meu.x, meu.z, 1, { soPolicia: true });
    }
  }

  // ------------------------------------------------------------------ ciclo
  atualizar(dt) {
    const jogo = this.jogo, j = this.j;
    const px = j.px, pz = j.pz;
    this.cdBatida -= dt;
    this.cdBloqueio -= dt;

    if (this.carencia > 0) {
      this.carencia -= dt;
      this.vendo = false;
    }
    this.tVisao -= dt;
    if (this.carencia <= 0 && this.tVisao <= 0) {
      this.tVisao = 0.15;
      this.vendo = false;
      for (const v of this.olhos()) {
        const d = dist(v.x, v.z, px, pz);
        if (d < 60 && this.reconhece(d) && this.podeVer(v, px, pz)) {
          this.vendo = true;
          break;
        }
      }
      if (!this.vendo && this.heliVe() && (this.modo !== 'limpo')) this.vendo = true;
    }

    if (this.vendo) {
      if (this.estrelas === 0) this.aplicar(1, 'A polícia reconheceu você pela Ficha!');
      else if (this.modo === 'busca') jogo.hud.mensagem('A polícia te achou!', 1.8);
      this.modo = 'perseguicao';
      this.semVer = 0;
      this.foraTempo = 0;
      this.ultima = { x: px, z: pz };
      this.registrar({ carro: j.veiculo, roupa: j.veiculo ? null : j.roupaId });
    } else if (this.estrelas > 0) {
      this.semVer += dt;
      if (this.modo === 'perseguicao' && this.semVer > 2.5) {
        this.modo = 'busca';
        this.zona = { x: this.ultima.x, z: this.ultima.z, r: this.raio() };
        jogo.hud.mensagem('Perderam você de vista. Saia da área de busca!', 3);
      }
      if (this.modo === 'busca') {
        this.zona.r = this.raio();
        const fora = dist(px, pz, this.zona.x, this.zona.z) > this.zona.r;
        this.foraTempo = fora ? this.foraTempo + dt : Math.max(0, this.foraTempo - dt * 0.5);
        if (this.foraTempo > 5 + 2 * this.estrelas) this.escapou();
      }
    }

    if (this.modo === 'perseguicao' && this.estrelas > 0) {
      this.tempoNivel += dt;
      if (this.estrelas === 1 && this.tempoNivel > 25 && j.veiculo) this.aplicar(2, 'Você está fugindo: 2 estrelas!');
      else if (this.estrelas === 2 && this.tempoNivel > 50) this.aplicar(3, 'Perseguição pesada: bloqueios nas ruas!');
    }

    if (this.estrelas === 0 && (this.ficha.carro || this.ficha.roupa !== null) && jogo.tempo > this.ficha.expira) {
      this.limparFicha('tudo');
      jogo.hud.mensagem('Sua Ficha esfriou. A polícia esqueceu você.', 2.5);
    }

    this.gerenciarUnidades(dt);
    this.conduzirUnidades(dt);
    this.atualizarBloqueios(dt);
    this.atualizarHeli(dt);
    this.atualizarPrisao(dt);
    for (const v of jogo.veiculos) {
      if (v.policia) v.ligarSirene(!!v.ia && (v.ia.tipo === 'unidade' || v.ia.tipo === 'bloqueio'), jogo.tempo);
    }
  }

  escapou() {
    this.jogo.hud.mensagem('Você despistou a polícia! A Ficha continua por um tempo.', 3.5);
    this.jogo.audio.escapou();
    this.estrelas = 0;
    this.modo = 'limpo';
    this.zona = null;
    this.prendendo = 0;
    this.ficha.expira = this.jogo.tempo + 150;
    this.dispensar();
  }

  limpar() {
    this.estrelas = 0;
    this.modo = 'limpo';
    this.zona = null;
    this.prendendo = 0;
    this.vendo = false;
    this.tVisao = 0;
    this.semVer = 0;
    this.carencia = 6;
    this.limparFicha('tudo');
    this.dispensar();
    for (const b of [...this.bloqueios]) this.removerBloqueio(b);
  }

  dispensar() {
    const mapa = this.jogo.mapa;
    for (const v of this.unidades()) {
      const n = mapa.nodoMaisProximo(v.x, v.z);
      iniciarIATrafego(this.jogo, v, n, pick(mapa.vizinhos(n)));
    }
    if (this.heli) this.heli.saindo = true;
  }

  // ------------------------------------------------------------------ unidades
  recrutar(v) {
    v.motorista = 'ia';
    v.ia = { tipo: 'unidade', rota: null, tRota: 0, alvoBusca: null, preso: 0, re: 0 };
  }

  spawnUnidade() {
    const jogo = this.jogo, j = this.j;
    const f = frente(j.veiculo ? j.veiculo.h : j.h);
    const cand = [];
    for (let i = 0; i < N; i++) {
      for (let k = 0; k < N; k++) {
        const p = nodoPos({ i, j: k });
        const d = dist(p.x, p.z, j.px, j.pz);
        if (d < 85 || d > 175) continue;
        const atras = (p.x - j.px) * f.x + (p.z - j.pz) * f.z < 0;
        cand.push({ p, peso: atras ? 3 : 1 });
      }
    }
    if (!cand.length) return;
    const pesados = cand.flatMap((c) => Array(c.peso).fill(c.p));
    const p = pick(pesados);
    if (jogo.veiculos.some((v) => dist(v.x, v.z, p.x, p.z) < 9)) return;
    const v = new Veiculo(jogo, 'viatura', p.x, p.z, headingDe(j.px - p.x, j.pz - p.z));
    this.recrutar(v);
  }

  gerenciarUnidades(dt) {
    const alvo = UNIDADES[this.estrelas];
    const atuais = this.unidades();
    if (atuais.length < alvo) {
      this.tSpawn -= dt;
      if (this.tSpawn <= 0) {
        this.tSpawn = 2.2;
        const j = this.j;
        const patrulha = this.jogo.veiculos.find(
          (v) => v.policia && v.ia && v.ia.tipo === 'trafego' && dist(v.x, v.z, j.px, j.pz) < 170
        );
        if (patrulha) this.recrutar(patrulha);
        else this.spawnUnidade();
      }
    }
    if (this.estrelas >= 4 && (!this.heli || this.heli.saindo)) this.criarHeli();
  }

  alvoPorRota(v, tx, tz, dt) {
    const ia = v.ia;
    ia.tRota -= dt;
    if (!ia.rota || ia.tRota <= 0) {
      ia.tRota = 1;
      const pts = this.jogo.mapa.rotaGPS(v.x, v.z, tx, tz).slice(1);
      if (pts.length >= 3) {
        const a = pts[0], b = pts[1];
        if (dist(v.x, v.z, b.x, b.z) < dist(a.x, a.z, b.x, b.z)) pts.shift();
      }
      ia.rota = pts;
    }
    while (ia.rota.length > 1 && dist(v.x, v.z, ia.rota[0].x, ia.rota[0].z) < 8) ia.rota.shift();
    return ia.rota[0] || { x: tx, z: tz };
  }

  pontoNaZona() {
    const z = this.zona;
    const nos = [];
    for (let i = 0; i < N; i++) {
      for (let k = 0; k < N; k++) {
        const p = nodoPos({ i, j: k });
        if (dist(p.x, p.z, z.x, z.z) < z.r + 10) nos.push(p);
      }
    }
    return nos.length ? pick(nos) : { x: z.x, z: z.z };
  }

  conduzirUnidades(dt) {
    const j = this.j;
    const px = j.px, pz = j.pz;
    for (const v of this.unidades()) {
      const ia = v.ia;
      if (ia.re > 0) {
        ia.re -= dt;
        v.ctrl = { acel: 0, freio: 1, virar: ia.reVirar, freioMao: false };
        continue;
      }
      let alvo, vd;
      const d = dist(v.x, v.z, px, pz);
      if (this.modo === 'perseguicao') {
        const direto = d < 90 && this.jogo.mapa.temVisao(v.x, v.z, px, pz);
        if (direto) {
          const lead = clamp(d / 25, 0, 1.2);
          const vj = j.veiculo;
          alvo = { x: px + (vj ? vj.vx * lead : 0), z: pz + (vj ? vj.vz * lead : 0) };
          vd = v.t.vmax;
          if (this.estrelas === 1 && d < 14) vd = Math.max(4, j.velocidade + 1.5);
          if (!vj) vd = Math.min(vd, Math.max(0, (d - 5) * 1.2));
        } else {
          alvo = this.alvoPorRota(v, px, pz, dt);
          vd = v.t.vmax * 0.8;
        }
      } else if (this.modo === 'busca' && this.zona) {
        if (!ia.alvoBusca || dist(v.x, v.z, ia.alvoBusca.x, ia.alvoBusca.z) < 10) {
          ia.alvoBusca = this.pontoNaZona();
          ia.rota = null;
        }
        alvo = this.alvoPorRota(v, ia.alvoBusca.x, ia.alvoBusca.z, dt);
        vd = 14;
      } else continue;
      dirigirPara(v, alvo.x, alvo.z, vd, 2.6);
      if (v.ctrl.acel > 0.3 && v.velocidade < 1) ia.preso += dt;
      else ia.preso = Math.max(0, ia.preso - dt);
      if (ia.preso > 1.5) {
        ia.preso = 0;
        ia.re = 1.1;
        ia.reVirar = -Math.sign(v.ctrl.virar || 1);
      }
    }
  }

  // ------------------------------------------------------------------ prisao
  atualizarPrisao(dt) {
    const j = this.j;
    if (this.estrelas === 0 || this.modo !== 'perseguicao' || this.carencia > 0 || this.jogo.cenaPrisao) {
      this.prendendo = Math.max(0, this.prendendo - dt * 2);
      return;
    }
    const lento = j.velocidade < (j.veiculo ? 2 : 3.5);
    const raio = j.veiculo ? 7.5 : 6.5;
    const perto = this.olhos().some((v) => dist(v.x, v.z, j.px, j.pz) < raio && v.velocidade < 4);
    if (lento && perto) this.prendendo += dt;
    else this.prendendo = Math.max(0, this.prendendo - dt * 1.5);
    if (this.prendendo > 2.5) this.jogo.preso();
  }

  // ------------------------------------------------------------------ bloqueios
  criarBloqueio() {
    const jogo = this.jogo, j = this.j;
    const v = j.veiculo;
    const f = frente(v.h);
    const n = jogo.mapa.nodoMaisProximo(j.px, j.pz);
    const eixoZ = Math.abs(f.z) > Math.abs(f.x);
    const s = Math.sign(eixoZ ? f.z : f.x);
    const pos = eixoZ ? j.pz : j.px;
    const lateral = eixoZ ? nodoX(n.i) : nodoX(n.j);
    if (Math.abs((eixoZ ? j.px : j.pz) - lateral) > 5) return false;
    let melhor = null;
    for (let k = 0; k < N; k++) {
      const c = nodoX(k);
      const frenteDist = s * (c - pos);
      if (frenteDist > 70 && (melhor === null || frenteDist < s * (melhor - pos))) melhor = c;
    }
    if (melhor === null) return false;
    const ponto = (al, lat) => (eixoZ ? { x: lateral + lat, z: al } : { x: al, z: lateral + lat });
    const base = melhor - s * 20;
    const rotBarreira = eixoZ ? 0 : Math.PI / 2;
    const b = { objs: [], obstaculos: [], tapetes: [], viatura: null, ...ponto(base, 0) };

    for (const lat of [-2.8, 0, 2.8]) {
      const p = ponto(base, lat);
      const o = instanciar('barreira');
      o.position.set(p.x, 0.02, p.z);
      o.rotation.y = rotBarreira;
      jogo.cena.add(o);
      const obs = this.obstaculo(o, p.x, p.z, 1.35);
      b.objs.push(o);
      b.obstaculos.push(obs);
    }
    for (const lat of [-3.4, 3.4]) {
      const p = ponto(base + s * 1.5, lat);
      const o = instanciar('cone');
      o.position.set(p.x, 0.02, p.z);
      jogo.cena.add(o);
      b.objs.push(o);
      b.obstaculos.push(this.obstaculo(o, p.x, p.z, 0.4));
    }
    const pv = ponto(base + s * 6, 0.5);
    const via = new Veiculo(jogo, 'viatura', pv.x, pv.z, (eixoZ ? Math.PI / 2 : 0) + rand(-0.3, 0.3));
    via.estatico = true;
    via.motorista = 'ia';
    via.ia = { tipo: 'bloqueio' };
    b.viatura = via;
    const pp = ponto(base + s * 4, -4.6);
    const pol = instanciar('policial');
    pol.position.set(pp.x, 0.17, pp.z);
    pol.rotation.y = headingDe(j.px - pp.x, j.pz - pp.z);
    jogo.cena.add(pol);
    b.objs.push(pol);
    if (this.estrelas >= 3) {
      for (const lat of [-2, 2]) {
        const p = ponto(base - s * 22, lat);
        const o = instanciar('tapete_pregos');
        o.position.set(p.x, 0.02, p.z);
        o.rotation.y = rotBarreira;
        jogo.cena.add(o);
        b.objs.push(o);
        const t = eixoZ ? { x: p.x, z: p.z, lx: 1.6, lz: 1.1 } : { x: p.x, z: p.z, lx: 1.1, lz: 1.6 };
        jogo.tapetes.push(t);
        b.tapetes.push(t);
      }
    }
    this.bloqueios.push(b);
    jogo.hud.mensagem('Bloqueio policial à frente! Desvie pela calçada.', 3);
    return true;
  }

  obstaculo(obj, x, z, r) {
    const jogo = this.jogo;
    const o = {
      obj, x, z, r, caido: false, voando: null,
      derrubar(v) {
        o.caido = true;
        o.voando = { vx: v.vx * 0.8 + rand(-2, 2), vy: 4 + v.velocidade * 0.1, vz: v.vz * 0.8 + rand(-2, 2), giro: rand(-8, 8) };
        v.vx *= 0.82;
        v.vz *= 0.82;
        v.dano(9);
        if (v.motorista === 'jogador') jogo.audio.batida(7);
      },
    };
    jogo.obstaculos.push(o);
    return o;
  }

  removerBloqueio(b) {
    const jogo = this.jogo;
    b.objs.forEach((o) => jogo.cena.remove(o));
    jogo.obstaculos = jogo.obstaculos.filter((o) => !b.obstaculos.includes(o));
    jogo.tapetes = jogo.tapetes.filter((t) => !b.tapetes.includes(t));
    if (b.viatura && b.viatura.motorista !== 'jogador') b.viatura.remover();
    this.bloqueios = this.bloqueios.filter((x) => x !== b);
  }

  atualizarBloqueios(dt) {
    const j = this.j;
    if (this.estrelas >= 3 && this.modo === 'perseguicao' && j.veiculo && j.velocidade > 8 && this.cdBloqueio <= 0 && this.bloqueios.length < 2) {
      this.cdBloqueio = this.criarBloqueio() ? 26 : 2;
    }
    for (const b of [...this.bloqueios]) {
      const d = dist(b.x, b.z, j.px, j.pz);
      if (d > 200 || (this.estrelas === 0 && d > 80)) this.removerBloqueio(b);
    }
    for (const o of this.jogo.obstaculos) {
      const v = o.voando;
      if (!v) continue;
      v.vy -= 20 * dt;
      o.obj.position.x += v.vx * dt;
      o.obj.position.z += v.vz * dt;
      o.obj.position.y += v.vy * dt;
      o.obj.rotation.x += v.giro * dt;
      o.obj.rotation.z += v.giro * 0.6 * dt;
      if (o.obj.position.y <= 0.02 && v.vy < 0) {
        o.obj.position.y = 0.02;
        o.voando = null;
      }
    }
  }

  // ------------------------------------------------------------------ helicoptero
  criarHeli() {
    const jogo = this.jogo, j = this.j;
    if (this.heli) this.removerHeli();
    const obj = instanciar('helicoptero_policia');
    this.heli = {
      obj, luz: this.luzHeli, alvoLuz: this.alvoLuz, x: j.px + 90, z: j.pz + 90, y: 45, h: 0, saindo: false,
      rotor: obj.getObjectByName('rotor_principal'), cauda: obj.getObjectByName('rotor_cauda'),
    };
    jogo.cena.add(obj);
    jogo.hud.mensagem('Helicóptero da polícia no ar!', 3);
  }

  removerHeli() {
    const h = this.heli;
    if (!h) return;
    this.jogo.cena.remove(h.obj);
    this.luzHeli.intensity = 0;
    this.heli = null;
  }

  atualizarHeli(dt) {
    const h = this.heli;
    if (!h) return;
    const j = this.j;
    if (this.estrelas < 4) h.saindo = true;
    let tx, tz, ty;
    if (h.saindo) {
      tx = h.x + (h.x - j.px) * 2;
      tz = h.z + (h.z - j.pz) * 2;
      ty = 60;
    } else {
      const v = j.veiculo;
      tx = j.px - (v ? v.vx : 0) * 0.6 + 10;
      tz = j.pz - (v ? v.vz : 0) * 0.6 + 10;
      ty = 28;
    }
    const dx = tx - h.x, dz = tz - h.z;
    const d = Math.hypot(dx, dz);
    const passo = Math.min(d, 24 * dt);
    if (d > 0.01) {
      h.x += (dx / d) * passo;
      h.z += (dz / d) * passo;
    }
    h.y += (ty - h.y) * Math.min(1, dt);
    h.h += angDiff(h.h, headingDe(j.px - h.x, j.pz - h.z)) * Math.min(1, dt * 2);
    h.obj.position.set(h.x, h.y, h.z);
    h.obj.rotation.set(-clamp(passo / dt / 24, 0, 1) * 0.18, h.h, 0, 'YXZ');
    if (h.rotor) h.rotor.rotation.y += dt * 30;
    if (h.cauda) h.cauda.rotation.x += dt * 40;
    h.luz.position.set(h.x, h.y - 1, h.z);
    h.alvoLuz.position.set(j.px, 0, j.pz);
    h.luz.intensity = h.saindo ? 0 : 90;
    if (h.saindo && dist(h.x, h.z, j.px, j.pz) > 260) this.removerHeli();
  }
}
