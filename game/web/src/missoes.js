import * as THREE from 'three';
import { Veiculo } from './veiculo.js';
import { dist, armazenamento, formatarDinheiro } from './util.js';

// Cada missao: inicio (poi), etapas com texto, alvo (para o GPS) e checar() -> 'ok' | 'falha:motivo' | null
function definirMissoes(jogo) {
  const poi = jogo.mapa.poi;
  const j = () => jogo.jogador;
  const parado = (x, z, r) => dist(j().px, j().pz, x, z) < r && j().velocidade < 4;

  return [
    {
      id: 'carro_de_luxo',
      nome: 'Carro de Luxo',
      resumo: 'Um cliente quer o esportivo vermelho que fica no estacionamento da Orla.',
      inicio: { x: poi.casa.x - 7, z: poi.casa.z - 2, nome: 'Casa Segura' },
      recompensa: 800,
      preparar(ctx) {
        const e = poi.esportivo;
        ctx.carro = new Veiculo(jogo, 'esportivo', e.x, e.z, e.h, '#d7261e');
        ctx.carro.missao = true;
      },
      limpar(ctx, ok) {
        if (!ctx.carro) return;
        if (ok || ctx.carro.motorista !== 'jogador') {
          if (ctx.carro.motorista === 'jogador') jogo.jogador.sair();
          ctx.carro.remover();
        } else ctx.carro.missao = false;
      },
      etapas: [
        {
          texto: 'Roube o esportivo vermelho no estacionamento da Orla.',
          dica: 'Se alguém vir o roubo, vai ligar para a polícia.',
          alvo: (ctx) => ctx.carro,
          checar: (ctx) => (ctx.carro.vida <= 0 ? 'falha:O esportivo foi destruído.' : j().veiculo === ctx.carro ? 'ok' : null),
        },
        {
          texto: 'Leve o esportivo até o Armazém 3, no Porto. Cuide da lataria!',
          alvo: (ctx) => (j().veiculo === ctx.carro ? poi.galpao : ctx.carro),
          checar: (ctx) => {
            if (ctx.carro.vida < 50) return 'falha:O esportivo ficou amassado demais. O cliente desistiu.';
            if (j().veiculo !== ctx.carro) return null;
            if (dist(ctx.carro.x, ctx.carro.z, poi.galpao.x, poi.galpao.z) < 6 && ctx.carro.velocidade < 3) {
              if (jogo.policia.estrelas > 0) {
                jogo.hud.dica('Despiste a polícia antes de entregar o carro.');
                return null;
              }
              return 'ok';
            }
            return null;
          },
        },
      ],
    },
    {
      id: 'entrega_expressa',
      nome: 'Entrega Expressa',
      resumo: 'O dono do Mercado da Orla precisa de uma encomenda na Torre Brasa, rápido.',
      inicio: poi.loja,
      recompensa: 500,
      preparar(ctx) {
        // carro de entrega do proprio mercado: pegar nao e crime
        ctx.carro = new Veiculo(jogo, 'sedan', poi.loja.x + 3.5, poi.loja.z + 6.5, Math.PI, '#e0b53a');
        ctx.carro.doJogador = true;
        ctx.carro.missao = true;
        ctx.prazo = 95;
      },
      limpar(ctx) {
        if (ctx.carro && ctx.carro.motorista !== 'jogador') ctx.carro.remover();
        else if (ctx.carro) ctx.carro.missao = false;
      },
      etapas: [
        {
          texto: 'Leve a encomenda até a Torre Brasa, no Centro. Use o carro amarelo do mercado.',
          alvo: () => poi.torre,
          checar: (ctx, dt) => {
            ctx.prazo -= dt;
            jogo.hud.cronometro(ctx.prazo);
            if (ctx.prazo <= 0) return 'falha:Tempo esgotado. A encomenda chegou atrasada.';
            return parado(poi.torre.x, poi.torre.z, 7) ? 'ok' : null;
          },
        },
      ],
    },
    {
      id: 'encontro_furado',
      nome: 'Encontro Furado',
      resumo: 'Um contato marcou um encontro no Porto. Parece fácil demais.',
      inicio: poi.praca,
      recompensa: 1500,
      etapas: [
        {
          texto: 'Vá ao encontro no Porto, entre os contêineres.',
          alvo: () => poi.encontro,
          checar: () => (dist(j().px, j().pz, poi.encontro.x, poi.encontro.z) < 7 ? 'ok' : null),
        },
        {
          texto: 'Era uma armadilha! Despiste a polícia.',
          dica: 'Saia da área de busca e fique fora da vista. Troque de carro longe das viaturas.',
          alvo: () => null,
          iniciar: () => {
            const p = jogo.policia;
            p.aplicar(3, 'Era uma armadilha! A polícia cercou o Porto!');
            p.modo = 'perseguicao';
            p.semVer = 0;
            p.ultima = { x: j().px, z: j().pz };
            p.registrar({ carro: j().veiculo, roupa: j().veiculo ? null : j().roupaId });
            p.spawnUnidade();
            p.spawnUnidade();
          },
          checar: () => (jogo.policia.estrelas === 0 ? 'ok' : null),
        },
        {
          texto: 'Volte para a casa segura, no Subúrbio.',
          alvo: () => poi.casa,
          checar: () => (dist(j().px, j().pz, poi.casa.x, poi.casa.z) < 5 ? 'ok' : null),
        },
      ],
    },
  ];
}

export class Missoes {
  constructor(jogo) {
    this.jogo = jogo;
    this.lista = definirMissoes(jogo);
    this.feitas = Math.min(armazenamento.ler('pb_missoes', 0), this.lista.length);
    this.ativa = null;
    this.etapa = 0;
    this.ctx = {};
    this.marcador = this.criarMarcador('#ffcc33');
    this.marcadorAlvo = this.criarMarcador('#22d3ee');
  }

  criarMarcador(cor) {
    const g = new THREE.Group();
    const mat = new THREE.MeshBasicMaterial({ color: cor, transparent: true, opacity: 0.35, depthWrite: false });
    const coluna = new THREE.Mesh(new THREE.CylinderGeometry(1.4, 1.4, 40, 20, 1, true), mat);
    coluna.position.y = 20;
    const anel = new THREE.Mesh(
      new THREE.RingGeometry(1.6, 2.2, 32),
      new THREE.MeshBasicMaterial({ color: cor, transparent: true, opacity: 0.9, side: THREE.DoubleSide, depthWrite: false })
    );
    anel.rotation.x = -Math.PI / 2;
    anel.position.y = 0.25;
    g.add(coluna, anel);
    g.visible = false;
    this.jogo.cena.add(g);
    return g;
  }

  disponivel() {
    return this.feitas < this.lista.length ? this.lista[this.feitas] : null;
  }

  alvoAtual() {
    if (this.ativa) {
      const e = this.ativa.etapas[this.etapa];
      const a = e.alvo(this.ctx);
      return a ? { x: a.x, z: a.z } : null;
    }
    const m = this.disponivel();
    return m ? { x: m.inicio.x, z: m.inicio.z, inicio: true } : null;
  }

  iniciar(m) {
    this.ativa = m;
    this.etapa = 0;
    this.ctx = {};
    m.preparar?.(this.ctx);
    this.jogo.hud.banner(m.nome, m.resumo, 3.5);
    this.jogo.audio.missao();
    this.entrarEtapa();
  }

  entrarEtapa() {
    const e = this.ativa.etapas[this.etapa];
    e.iniciar?.(this.ctx);
    if (e.dica) this.jogo.hud.mensagem(e.dica, 4);
  }

  concluir() {
    const m = this.ativa;
    m.limpar?.(this.ctx, true);
    this.jogo.dinheiro += m.recompensa;
    this.feitas++;
    armazenamento.gravar('pb_missoes', this.feitas);
    this.jogo.salvar();
    this.ativa = null;
    this.jogo.hud.cronometro(null);
    this.jogo.hud.banner('Missão cumprida', `${m.nome}  +${formatarDinheiro(m.recompensa)}`, 3.5);
    this.jogo.audio.missao();
    if (!this.disponivel()) {
      setTimeout(() => this.jogo.hud.mensagem('Você terminou todas as missões desta versão. Explore Porto Brasa!', 5), 3800);
    }
  }

  falhar(motivo) {
    if (!this.ativa) return;
    const m = this.ativa;
    m.limpar?.(this.ctx, false);
    this.ativa = null;
    this.jogo.hud.cronometro(null);
    this.jogo.hud.banner('Missão falhou', motivo, 3.5);
  }

  recomecar() {
    if (this.ativa) this.falhar('Missões reiniciadas.');
    this.feitas = 0;
    armazenamento.gravar('pb_missoes', 0);
  }

  atualizar(dt) {
    const j = this.jogo.jogador;
    if (!this.ativa) {
      const m = this.disponivel();
      if (m) {
        this.marcador.visible = true;
        this.marcador.position.set(m.inicio.x, 0, m.inicio.z);
        if (dist(j.px, j.pz, m.inicio.x, m.inicio.z) < 3.5 && j.velocidade < 4 && this.jogo.policia.estrelas === 0) {
          this.marcador.visible = false;
          this.iniciar(m);
        }
      } else this.marcador.visible = false;
      this.marcadorAlvo.visible = false;
      return;
    }
    this.marcador.visible = false;
    const e = this.ativa.etapas[this.etapa];
    const r = e.checar(this.ctx, dt);
    const a = this.alvoAtual();
    this.marcadorAlvo.visible = !!a;
    if (a) this.marcadorAlvo.position.set(a.x, 0, a.z);
    if (r === 'ok') {
      this.etapa++;
      if (this.etapa >= this.ativa.etapas.length) this.concluir();
      else {
        this.jogo.audio.etapa();
        this.entrarEtapa();
      }
    } else if (typeof r === 'string' && r.startsWith('falha:')) {
      this.falhar(r.slice(6));
    }
  }

  textoObjetivo() {
    if (this.ativa) return { titulo: this.ativa.nome, texto: this.ativa.etapas[this.etapa].texto };
    const m = this.disponivel();
    if (m) return { titulo: 'Próxima missão', texto: `${m.nome}: vá até o marcador amarelo (${m.inicio.nome}).` };
    return { titulo: 'Mundo livre', texto: 'Todas as missões feitas. Explore a cidade.' };
  }
}

