import { TIPOS, ORDEM } from './armas.js';
import { Veiculo } from './veiculo.js';
import { faixa } from './trafego.js';
import { formatarDinheiro, dist, headingDe } from './util.js';

// Celular: contatos (Rui, taxi, mecanico, advogado), mensagens, GPS com destino e carteira.
// O mundo continua rodando com o celular aberto.
export const PRECO_TAXI = 40;
export const PRECO_MECANICO = 100;
export const PRECO_FICHA = 300;
export const PRECO_ESTRELA = 800;

const $ = (id) => document.getElementById(id);

export class Celular {
  constructor(jogo) {
    this.jogo = jogo;
    this.el = $('celular');
    this.titulo = $('cel-titulo');
    this.conteudo = $('cel-conteudo');
    this.status = $('cel-status');
    this.hora = $('cel-hora');
    this.pagina = 'inicio';
    $('cel-voltar').addEventListener('click', () => this.voltar());
    $('cel-fechar').addEventListener('click', () => this.fechar());
  }

  aberto() {
    return !this.el.hidden;
  }

  alternar() {
    if (this.aberto()) this.fechar();
    else this.abrir();
  }

  abrir() {
    this.el.hidden = false;
    this.status.textContent = '';
    this.jogo.abrirUi('celular');
    this.ir('inicio');
  }

  fechar() {
    this.el.hidden = true;
    this.jogo.fecharUi();
  }

  voltar() {
    if (this.pagina === 'inicio') this.fechar();
    else this.ir(this.pagina === 'taxi' ? 'contatos' : 'inicio');
  }

  atualizarHora() {
    const min = Math.floor(this.jogo.tempo * 2) % (24 * 60);
    this.hora.textContent = `${String((Math.floor(min / 60) + 8) % 24).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}`;
  }

  botao(titulo, sub, acao) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'cel-item';
    b.innerHTML = `<span>${titulo}</span>${sub ? `<small>${sub}</small>` : ''}`;
    b.addEventListener('click', acao);
    this.conteudo.appendChild(b);
    return b;
  }

  texto(t, classe = 'cel-texto') {
    const p = document.createElement('p');
    p.className = classe;
    p.textContent = t;
    this.conteudo.appendChild(p);
  }

  lugares() {
    const poi = this.jogo.mapa.poi;
    return {
      'Casa Segura': poi.casa,
      'Mercado da Orla': { x: poi.loja.x, z: poi.loja.z + 3 },
      'Arsenal do Porto': poi.arsenal,
      'Oficina de Pintura': poi.oficina,
      'Torre Brasa (Centro)': poi.torre,
      'Praça do Centro': poi.praca,
    };
  }

  ir(p) {
    const jogo = this.jogo;
    this.pagina = p;
    this.conteudo.textContent = '';
    this.atualizarHora();
    if (p === 'inicio') {
      this.titulo.textContent = 'Porto Brasa';
      const novas = jogo.mensagens.filter((m) => !m.lida).length;
      this.botao('Contatos', 'Rui, táxi, mecânico, advogado', () => this.ir('contatos'));
      this.botao('Mensagens', novas ? `${novas} nova${novas > 1 ? 's' : ''}` : 'nenhuma nova', () => this.ir('mensagens'));
      this.botao('GPS', 'marcar destino no mapa', () => this.ir('gps'));
      this.botao('Carteira', 'dinheiro, armas, vida', () => this.ir('carteira'));
    } else if (p === 'contatos') {
      this.titulo.textContent = 'Contatos';
      this.botao('Rui', 'pedir o próximo trabalho', () => this.pedirTrabalho());
      this.botao('Táxi Brasa', `leva você a pé pela cidade · R$ ${PRECO_TAXI}`, () => this.ir('taxi'));
      this.botao('Mecânico Zé', `traz seu carro consertado · R$ ${PRECO_MECANICO}`, () => this.mecanico());
      this.botao('Dr. Brito, advogado', `limpa a Ficha (R$ ${PRECO_FICHA}) ou tira 1 estrela na busca (R$ ${PRECO_ESTRELA})`, () => this.advogado());
    } else if (p === 'taxi') {
      this.titulo.textContent = 'Táxi Brasa';
      for (const nome of Object.keys(this.lugares())) this.botao(nome, `R$ ${PRECO_TAXI}`, () => this.taxi(nome));
    } else if (p === 'mensagens') {
      this.titulo.textContent = 'Mensagens';
      if (!jogo.mensagens.length) this.texto('Nenhuma mensagem.');
      for (const m of [...jogo.mensagens].reverse()) {
        this.texto(`${m.lida ? '' : '● '}${m.de}`, 'cel-de');
        this.texto(m.texto);
        m.lida = true;
      }
    } else if (p === 'gps') {
      this.titulo.textContent = 'GPS';
      for (const nome of Object.keys(this.lugares())) this.botao(nome, '', () => this.marcar(nome));
      this.botao('Mercado mais próximo', '', () => this.marcar('Mercado mais próximo'));
      if (jogo.destino) this.botao('Remover destino', '', () => this.marcar(''));
    } else if (p === 'carteira') {
      this.titulo.textContent = 'Carteira';
      const j = jogo.jogador;
      this.texto(`Dinheiro: ${formatarDinheiro(jogo.dinheiro)}`);
      this.texto(`Vida: ${Math.round(j.vida)}/100 · Colete: ${Math.round(j.colete)}/100`);
      this.texto(`Missões feitas: ${jogo.missoes.feitas} de ${jogo.missoes.lista.length}`);
      this.texto(`Prisões: ${jogo.estat.prisoes} · Hospital: ${jogo.estat.mortes}`);
      const armas = ORDEM.filter((a) => a !== 'punho' && jogo.armas.tem(a));
      this.texto('Armas:', 'cel-de');
      if (!armas.length) this.texto('nenhuma (compre no Arsenal do Porto)');
      for (const a of armas) this.texto(`${TIPOS[a].nome} · ${jogo.armas.inventario[a]} balas`);
    }
    const primeiro = this.conteudo.querySelector('button');
    if (primeiro) setTimeout(() => primeiro.focus({ preventScroll: true }), 0);
  }

  msg(t) {
    this.status.textContent = t;
    return t;
  }

  // ---------------------------------------------------------------- acoes (tambem usadas pelos testes)
  pedirTrabalho() {
    const m = this.jogo.missoes;
    if (m.ativa) return this.msg(`Rui: "Termina o que você começou: ${m.ativa.nome}."`);
    const d = m.disponivel();
    if (!d) return this.msg('Rui: "Por enquanto é só. Aproveita a cidade."');
    this.jogo.destino = { x: d.inicio.x, z: d.inicio.z };
    return this.msg(`Rui: "Tem serviço: ${d.nome}. Marquei no seu GPS."`);
  }

  marcar(nome) {
    const jogo = this.jogo;
    if (!nome) {
      jogo.destino = null;
      this.ir('gps');
      return this.msg('Destino removido.');
    }
    if (nome === 'Mercado mais próximo') {
      const j = jogo.jogador;
      let melhor = null;
      for (const l of jogo.mapa.lojas) if (!melhor || dist(l.x, l.z, j.px, j.pz) < dist(melhor.x, melhor.z, j.px, j.pz)) melhor = l;
      jogo.destino = { x: melhor.x, z: melhor.z };
    } else {
      const l = this.lugares()[nome];
      jogo.destino = { x: l.x, z: l.z };
    }
    this.fechar();
    jogo.hud.mensagem(`Destino marcado no GPS: ${nome}.`, 2.5);
    return 'ok';
  }

  taxi(nome) {
    const jogo = this.jogo;
    if (jogo.policia.estrelas > 0) return this.msg('O taxista não pega quem está sendo procurado.');
    if (jogo.jogador.veiculo) return this.msg('Saia do carro para pegar o táxi.');
    if (jogo.dinheiro < PRECO_TAXI) return this.msg('Dinheiro insuficiente.');
    jogo.dinheiro -= PRECO_TAXI;
    const l = this.lugares()[nome];
    this.fechar();
    jogo.viajar(l.x, l.z, `Táxi: você chegou em ${nome}.`);
    return 'ok';
  }

  mecanico() {
    const jogo = this.jogo, j = jogo.jogador;
    if (jogo.dinheiro < PRECO_MECANICO) return this.msg('Dinheiro insuficiente.');
    const antigo = jogo.veiculos.find((v) => v.doJogador && !v.missao && v !== j.veiculo);
    const cor = antigo?.cor || '#2f6db5';
    if (antigo) antigo.remover();
    const n = jogo.mapa.nodoMaisProximo(j.px, j.pz);
    let melhor = null, md = Infinity;
    for (const viz of jogo.mapa.vizinhos(n)) {
      const f = faixa(n, viz);
      for (const k of [0.2, 0.5, 0.8]) {
        const x = f.ini.x + f.d.x * f.L * k, z = f.ini.z + f.d.z * f.L * k;
        const d = dist(x, z, j.px, j.pz);
        if (d > 8 && d < md) {
          md = d;
          melhor = { x, z, h: headingDe(f.d.x, f.d.z) };
        }
      }
    }
    const v = new Veiculo(jogo, 'sedan', melhor.x, melhor.z, melhor.h, cor);
    v.doJogador = true;
    v.fixo = true;
    jogo.dinheiro -= PRECO_MECANICO;
    jogo.destino = { x: melhor.x, z: melhor.z };
    jogo.audio.compra();
    return this.msg('Zé: "Deixei seu carro consertado na rua. Tá no GPS."');
  }

  advogado() {
    const jogo = this.jogo, p = jogo.policia;
    if (p.modo === 'perseguicao') return this.msg('Dr. Brito: "Com a polícia na sua cola não dá. Despiste primeiro."');
    if (p.estrelas > 0) {
      if (jogo.dinheiro < PRECO_ESTRELA) return this.msg(`Dr. Brito: "Isso custa R$ ${PRECO_ESTRELA}."`);
      jogo.dinheiro -= PRECO_ESTRELA;
      p.estrelas -= 1;
      if (p.estrelas === 0) p.escapou();
      return this.msg('Dr. Brito: "Mexi uns pauzinhos. Uma estrela a menos."');
    }
    const f = p.fichaAtiva();
    if (f.carro || f.roupa) {
      if (jogo.dinheiro < PRECO_FICHA) return this.msg(`Dr. Brito: "Isso custa R$ ${PRECO_FICHA}."`);
      jogo.dinheiro -= PRECO_FICHA;
      p.limparFicha('tudo');
      return this.msg('Dr. Brito: "Sua Ficha está limpa."');
    }
    return this.msg('Dr. Brito: "Você está limpo. Me ligue se precisar."');
  }
}
