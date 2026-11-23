import { TIPOS } from './armas.js';
import { formatarDinheiro } from './util.js';

// Tela do Mercado (comida, kit medico, assalto ao caixa) e do Arsenal (armas, municao, colete).
// O mundo para enquanto a tela esta aberta.
export const MERCADO = [
  { id: 'coco', nome: 'Água de coco', desc: '+20 de vida', preco: 5, cura: 20 },
  { id: 'pastel', nome: 'Pastel e caldo de cana', desc: '+50 de vida', preco: 15, cura: 50 },
  { id: 'kit', nome: 'Kit de primeiros socorros', desc: 'vida cheia', preco: 60, cura: 100 },
];

const $ = (id) => document.getElementById(id);

export class Loja {
  constructor(jogo) {
    this.jogo = jogo;
    this.el = $('loja');
    this.titulo = $('loja-titulo');
    this.sub = $('loja-sub');
    this.lista = $('loja-lista');
    this.status = $('loja-status');
    this.din = $('loja-dinheiro');
    this.tipo = '';
    this.id = -1;
    $('loja-sair').addEventListener('click', () => this.fechar());
  }

  aberta() {
    return !this.el.hidden;
  }

  abrir(tipo, id = -1) {
    this.tipo = tipo;
    this.id = id;
    this.status.textContent = '';
    this.montar();
    this.el.hidden = false;
    this.jogo.abrirUi('loja');
  }

  fechar() {
    this.el.hidden = true;
    this.jogo.fecharUi();
  }

  botao(texto, acao, classe = '') {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'item ' + classe;
    b.innerHTML = texto;
    b.addEventListener('click', acao);
    this.lista.appendChild(b);
    return b;
  }

  montar() {
    const jogo = this.jogo, j = jogo.jogador;
    this.lista.textContent = '';
    this.din.textContent = formatarDinheiro(jogo.dinheiro);
    if (this.tipo === 'mercado') {
      this.titulo.textContent = 'Mercado';
      this.sub.textContent = `Vida: ${Math.round(j.vida)}/100. Comida recupera a vida.`;
      for (const it of MERCADO) {
        this.botao(`<span>${it.nome}</span><small>${it.desc}</small><b>${formatarDinheiro(it.preco)}</b>`, () => this.comprar(it.id));
      }
      if (jogo.armas.armado()) {
        this.botao('<span>Assaltar o caixa</span><small>crime: a câmera grava</small><b>R$ 250 a 600</b>', () => this.assaltar(), 'perigo');
      }
    } else {
      this.titulo.textContent = 'Arsenal do Porto';
      this.sub.textContent = `Colete: ${Math.round(j.colete)}/100. Armas ficam com você até ser preso.`;
      for (const a of ['pistola', 'escopeta', 'submetralhadora']) {
        const t = TIPOS[a];
        if (jogo.armas.tem(a)) {
          this.botao(`<span>Munição de ${t.nome.toLowerCase()}</span><small>+${t.pacote} balas</small><b>${formatarDinheiro(t.precoMunicao)}</b>`, () => this.comprar(a));
        } else {
          this.botao(`<span>${t.nome}</span><small>${t.pacote} balas</small><b>${formatarDinheiro(t.preco)}</b>`, () => this.comprar(a));
        }
      }
      this.botao('<span>Colete à prova de balas</span><small>colete 100</small><b>R$ 250</b>', () => this.comprar('colete'));
    }
    const primeiro = this.lista.querySelector('button');
    if (primeiro) setTimeout(() => primeiro.focus({ preventScroll: true }), 0);
  }

  // Compra um item; devolve o texto do resultado (usado tambem pelos testes).
  comprar(id) {
    const jogo = this.jogo, j = jogo.jogador;
    let preco = 0, feito = '';
    const it = MERCADO.find((m) => m.id === id);
    if (it) {
      preco = it.preco;
      if (j.vida >= 100) return this.msg('Sua vida já está cheia.');
      if (jogo.dinheiro < preco) return this.msg('Dinheiro insuficiente.');
      j.curar(it.cura);
      feito = `Vida: ${Math.round(j.vida)}/100.`;
    } else if (id === 'colete') {
      preco = 250;
      if (j.colete >= 100) return this.msg('Seu colete já está inteiro.');
      if (jogo.dinheiro < preco) return this.msg('Dinheiro insuficiente.');
      j.colete = 100;
      feito = 'Colete vestido.';
    } else {
      const t = TIPOS[id];
      const tem = jogo.armas.tem(id);
      preco = tem ? t.precoMunicao : t.preco;
      if (jogo.dinheiro < preco) return this.msg('Dinheiro insuficiente.');
      jogo.armas.dar(id, t.pacote);
      feito = tem
        ? `+${t.pacote} balas de ${t.nome.toLowerCase()}.`
        : `${t.nome} comprada. ${jogo.toque ? 'Toque em Mirar e depois em Atirar.' : 'Botão direito mira, esquerdo atira.'}`;
    }
    jogo.dinheiro -= preco;
    jogo.audio.compra();
    jogo.salvar();
    this.montar();
    return this.msg(feito);
  }

  assaltar() {
    const r = this.jogo.assaltarLoja(this.id);
    this.fechar();
    return r;
  }

  msg(t) {
    this.status.textContent = t;
    return t;
  }
}
