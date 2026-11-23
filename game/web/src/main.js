import * as THREE from 'three';
import { carregarModelos } from './assets.js';
import { Mapa } from './mapa.js';
import { Veiculo, CORES_CARRO } from './veiculo.js';
import { Jogador } from './jogador.js';
import { Pedestres } from './pedestres.js';
import { Trafego } from './trafego.js';
import { Policia } from './policia.js';
import { Missoes } from './missoes.js';
import { Hud } from './hud.js';
import { CameraJogo } from './camera.js';
import { Audio } from './audio.js';
import { Entrada } from './entrada.js';
import { passoFisica } from './fisica.js';
import { Armas } from './armas.js';
import { Loja } from './loja.js';
import { Celular } from './celular.js';
import { dist, pick, armazenamento, formatarDinheiro } from './util.js';

const $ = (id) => document.getElementById(id);
const movel = matchMedia('(pointer: coarse)').matches;

async function iniciar() {
  const canvas = $('jogo');
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: !movel, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, movel ? 1.5 : 1.75));
  renderer.setSize(innerWidth, innerHeight);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;

  const cena = new THREE.Scene();
  const ceu = new THREE.Color('#cfe2ee');
  cena.background = ceu;
  cena.fog = new THREE.Fog(ceu, 140, 430);
  const camera = new THREE.PerspectiveCamera(62, innerWidth / innerHeight, 0.3, 900);
  camera.position.set(60, 60, 60);

  cena.add(new THREE.HemisphereLight('#dceaf7', '#8a7d5a', 1.35));
  const sol = new THREE.DirectionalLight('#fff0d6', 2.6);
  sol.castShadow = true;
  sol.shadow.mapSize.set(movel ? 1024 : 2048, movel ? 1024 : 2048);
  const sc = sol.shadow.camera;
  sc.left = sc.bottom = -75;
  sc.right = sc.top = 75;
  sc.near = 1;
  sc.far = 260;
  sol.shadow.bias = -0.0004;
  sol.shadow.normalBias = 0.04;
  cena.add(sol, sol.target);

  addEventListener('resize', () => {
    renderer.setSize(innerWidth, innerHeight);
    camera.aspect = innerWidth / innerHeight;
    camera.updateProjectionMatrix();
  });

  // ---- carregamento
  const barra = $('carga-barra'), cargaTxt = $('carga-texto');
  await carregarModelos((p, nome) => {
    barra.style.width = Math.round(p * 80) + '%';
    cargaTxt.textContent = `Carregando modelos… ${nome.replace(/_/g, ' ')}`;
  });
  cargaTxt.textContent = 'Montando a cidade…';
  await new Promise((r) => setTimeout(r, 30));

  const salvo = armazenamento.ler('pb_jogo', {});
  const jogo = {
    cena, camera, renderer,
    veiculos: [], obstaculos: [], tapetes: [],
    tempo: 0, dinheiro: salvo.dinheiro ?? 200, pausado: true, promptAtual: '',
    toque: movel, uiAberta: '', cenaHospital: 0, destino: null, mensagens: [],
    lojasRoubadas: {}, estat: { prisoes: 0, mortes: 0 },
    audio: new Audio(),
    crime(tipo, x, z, estrelas, op) {
      this.policia.crime(tipo, x, z, estrelas, op);
    },
    eventoBatida(a, b, forca) {
      this.policia.eventoBatida(a, b, forca);
    },
    salvar() {
      armazenamento.gravar('pb_jogo', {
        dinheiro: this.dinheiro, roupa: this.jogador.roupaId,
        armas: this.armas.inventario, colete: this.jogador.colete,
      });
    },
    novaMensagem(de, texto, avisar = true) {
      this.mensagens.push({ de, texto, lida: false });
      if (avisar) {
        this.hud.mensagem(`Nova mensagem de ${de} (${this.toque ? 'botão Celular' : 'Tab abre o celular'}).`, 3);
        this.audio.notificacao();
      }
    },
    abrirUi(nome) {
      if (this.uiAberta === 'celular' && nome === 'loja') this.celular.el.hidden = true;
      this.uiAberta = nome;
      this.entrada.limpar();
      this.entrada.destravar();
    },
    fecharUi() {
      this.uiAberta = '';
      this.entrada.limpar();
      if (!this.pausado && !this.testando) this.entrada.travar();
    },
    // Viagem rapida (taxi): tela escura rapida e o jogador aparece no destino.
    viajar(x, z, msg) {
      const f = $('flash');
      f.classList.remove('viagem');
      void f.offsetWidth;
      f.classList.add('viagem');
      this.jogador.x = x;
      this.jogador.z = z;
      this.jogador.h = 0;
      this.cam.yaw = 0;
      this.cam.pos.set(x, 6, z + 6);
      this.hud.mensagem(msg, 2.5);
    },
    assaltarLoja(id) {
      if ((this.lojasRoubadas[id] ?? -1) > this.tempo) {
        this.hud.mensagem('O caixa está vazio. Volte mais tarde.', 2.5);
        return 'vazio';
      }
      const valor = 250 + Math.floor(Math.random() * 351);
      this.dinheiro += valor;
      this.lojasRoubadas[id] = this.tempo + 180;
      const porta = this.mapa.lojas[id] || this.jogador;
      this.hud.mensagem(`Você levou ${formatarDinheiro(valor)} do caixa. A câmera de segurança gravou tudo!`, 3.5);
      this.audio.alerta();
      this.pedestres.panico(porta.x, porta.z, 30);
      // a camera denuncia na hora: a policia sabe a roupa e onde foi
      this.policia.denuncia({ tipo: 'assalto', x: porta.x, z: porta.z, estrelas: 2, carro: null, roupa: this.jogador.roupaId });
      return 'roubou';
    },
    morreu() {
      if (this.cenaHospital || this.cenaPrisao) return;
      this.cenaHospital = 3;
      this.estat.mortes++;
      const conta = Math.round(this.dinheiro * 0.1);
      this.dinheiro -= conta;
      this.hud.banner('Hospitalizado', `Conta do hospital: ${formatarDinheiro(conta)}. Você acorda na casa segura.`, 3);
      this.missoes.falhar('Você foi parar no hospital.');
      this.audio.alerta();
    },
    preso() {
      if (this.cenaPrisao || this.cenaHospital) return;
      this.cenaPrisao = 2.6;
      this.estat.prisoes++;
      const tinhaArmas = Object.keys(this.armas.inventario).length > 1;
      this.armas.confiscar();
      if (tinhaArmas) this.hud.mensagem('Suas armas foram confiscadas.', 3);
      const multa = Math.round(this.dinheiro * 0.15);
      this.dinheiro -= multa;
      this.hud.banner('Preso', `Fiança de ${formatarDinheiro(multa)}. Você volta para a casa segura.`, 2.6);
      this.missoes.falhar('Você foi preso.');
      this.audio.alerta();
    },
  };
  window.PB = jogo; // atalho para depuracao no console

  jogo.mapa = new Mapa(cena);
  barra.style.width = '92%';
  const poi = jogo.mapa.poi;
  jogo.hud = new Hud(jogo);
  jogo.jogador = new Jogador(jogo, poi.casa.x, poi.casa.z);
  jogo.jogador.h = 0;
  if (salvo.roupa) jogo.jogador.vestir(salvo.roupa % 6);
  jogo.pedestres = new Pedestres(jogo);
  jogo.trafego = new Trafego(jogo);
  jogo.policia = new Policia(jogo);
  jogo.missoes = new Missoes(jogo);
  const entrada = new Entrada(canvas);
  const cam = new CameraJogo(camera, jogo.mapa);
  cam.yaw = 0;
  jogo.entrada = entrada;
  jogo.cam = cam;
  jogo.armas = new Armas(jogo);
  jogo.armas.prepararModelo(jogo.jogador);
  for (const [a, balas] of Object.entries(salvo.armas || {})) jogo.armas.inventario[a] = balas;
  jogo.jogador.colete = salvo.colete || 0;
  jogo.loja = new Loja(jogo);
  jogo.celular = new Celular(jogo);
  if (jogo.missoes.feitas === 0) {
    jogo.novaMensagem('Rui', `Bem-vindo de volta a Porto Brasa. Tem trabalho pra você: vai até o marcador amarelo do lado da casa. Se precisar, me chama no celular (${movel ? 'botão Celular' : 'tecla Tab'}).`, false);
  }
  // marcador roxo do destino do GPS
  const marcadorDestino = new THREE.Mesh(
    new THREE.CylinderGeometry(1.4, 1.4, 40, 20, 1, true),
    new THREE.MeshBasicMaterial({ color: '#b07cff', transparent: true, opacity: 0.35, depthWrite: false, side: THREE.DoubleSide })
  );
  marcadorDestino.visible = false;
  cena.add(marcadorDestino);

  // carros estacionados (roubar e crime) + o carro da casa segura (e seu)
  for (const e of jogo.mapa.estacionados) {
    const v = new Veiculo(jogo, 'sedan', e.x, e.z, e.h, pick(CORES_CARRO));
    v.fixo = true;
  }
  const meu = new Veiculo(jogo, 'sedan', poi.casa.x + 6.6, poi.casa.z - 3, Math.PI / 2, '#2f6db5');
  meu.fixo = true;
  meu.doJogador = true;
  for (let i = 0; i < 10; i++) jogo.trafego.spawnar(false);
  for (let i = 0; i < 2; i++) jogo.trafego.spawnar(true);
  for (let i = 0; i < 26; i++) jogo.pedestres.reposicionar(jogo.pedestres.criar(0, 0));

  // ---- servicos: oficina de pintura e casa segura
  let tPintura = 0, pintou = false;
  function servicos(dt) {
    const j = jogo.jogador, p = jogo.policia;
    jogo.promptAtual = '';
    const v = j.veiculo;
    if (v) {
      const naOficina = dist(v.x, v.z, poi.oficina.x, poi.oficina.z) < 6;
      if (!naOficina) {
        pintou = false;
        tPintura = 0;
      } else if (!pintou) {
        if (p.modo === 'perseguicao') jogo.promptAtual = 'Despiste a polícia antes de pintar o carro';
        else if (jogo.dinheiro < 150) jogo.promptAtual = 'A pintura custa R$ 150';
        else if (v.velocidade < 2) {
          tPintura += dt;
          jogo.promptAtual = 'Pintando e consertando… ' + Math.ceil(2 - tPintura);
          if (tPintura > 2) {
            pintou = true;
            v.repintar(pick(CORES_CARRO.filter((c) => c !== v.cor)));
            v.vida = 100;
            v.pneus = false;
            jogo.dinheiro -= 150;
            if (p.ficha.carro === v) p.limparFicha('carro');
            jogo.hud.mensagem('Carro pintado e consertado (R$ 150). A polícia não reconhece mais este carro.', 3.5);
            jogo.audio.etapa();
          }
        } else jogo.promptAtual = 'Pare para pintar o carro (R$ 150)';
      }
      if (!jogo.promptAtual && v.velocidade < 4) jogo.promptAtual = 'E  sair do carro';
      return;
    }
    for (const l of jogo.mapa.lojas) {
      if (dist(j.x, j.z, l.x, l.z) < 2.4) return entradaLoja('mercado', l.id, 'Mercado');
    }
    if (dist(j.x, j.z, poi.arsenal.x, poi.arsenal.z) < 2.6) return entradaLoja('arsenal', -1, 'Arsenal do Porto');
    const naCasa = dist(j.x, j.z, poi.casa.x, poi.casa.z) < 2.6;
    if (naCasa) {
      if (p.modo === 'perseguicao') jogo.promptAtual = 'Não dá para entrar com a polícia olhando';
      else {
        jogo.promptAtual = 'E  trocar de roupa e salvar';
        if (entrada.apertou('KeyE', 'KeyF')) {
          entrada.apertadas.delete('KeyE');
          entrada.apertadas.delete('KeyF');
          const r = j.trocarRoupa();
          p.limparFicha('roupa');
          jogo.salvar();
          jogo.hud.mensagem(`Você vestiu uma ${r.nome}. A polícia não reconhece mais sua roupa. Jogo salvo.`, 3.5);
          jogo.audio.etapa();
        }
      }
      return;
    }
    const perto = j.veiculoProximo();
    if (perto) jogo.promptAtual = perto.doJogador ? 'E  entrar no carro' : perto.motorista === 'ia' ? 'E  roubar o carro (crime)' : 'E  roubar o carro (crime)';
  }

  function entradaLoja(tipo, id, nome) {
    if (jogo.policia.estrelas > 0) {
      jogo.promptAtual = `O ${nome} não atende quem está sendo procurado`;
      return;
    }
    jogo.promptAtual = `E  entrar no ${nome}`;
    if (entrada.apertou('KeyE', 'KeyF')) {
      entrada.apertadas.delete('KeyE');
      entrada.apertadas.delete('KeyF');
      jogo.loja.abrir(tipo, id);
    }
  }

  function hospital(dt) {
    if (!jogo.cenaHospital) return false;
    jogo.cenaHospital -= dt;
    const j = jogo.jogador;
    j.obj.rotation.x = -Math.PI / 2;
    if (jogo.cenaHospital <= 0) {
      jogo.cenaHospital = 0;
      if (j.veiculo) j.sair(true);
      j.x = poi.casa.x;
      j.z = poi.casa.z;
      j.h = 0;
      j.vida = 100;
      j.caido = 0;
      j.obj.rotation.x = 0;
      jogo.policia.limpar();
      jogo.salvar();
    }
    return true;
  }

  function prisao(dt) {
    if (!jogo.cenaPrisao) return false;
    jogo.cenaPrisao -= dt;
    if (jogo.cenaPrisao <= 0) {
      jogo.cenaPrisao = 0;
      const j = jogo.jogador;
      if (j.veiculo) {
        const v = j.veiculo;
        j.veiculo = null;
        v.motorista = null;
        v.ctrl = { acel: 0, freio: 1, virar: 0, freioMao: false };
        j.obj.visible = true;
      }
      j.x = poi.casa.x;
      j.z = poi.casa.z;
      j.h = 0;
      jogo.policia.limpar();
      jogo.salvar();
    }
    return true;
  }

  // ---- interface: inicio, pausa, toque
  const telaInicio = $('inicio'), botaoJogar = $('jogar'), telaPausa = $('pausa');
  barra.style.width = '100%';
  cargaTxt.textContent = 'Pronto.';
  $('carga').hidden = true;
  botaoJogar.disabled = false;
  botaoJogar.textContent = 'Jogar';
  const comecar = () => {
    jogo.audio.iniciar();
    telaInicio.hidden = true;
    telaPausa.hidden = true;
    jogo.pausado = false;
    $('hud').hidden = false;
    if (movel) $('toque').hidden = false;
    canvas.focus();
    if (!jogo.uiAberta && !jogo.testando) entrada.travar();
  };
  botaoJogar.addEventListener('click', comecar);
  $('continuar').addEventListener('click', comecar);
  $('recomecar').addEventListener('click', () => {
    jogo.missoes.recomecar();
    jogo.hud.mensagem('Missões reiniciadas.', 2);
    comecar();
  });
  const btnSom = $('som');
  btnSom.addEventListener('click', () => {
    btnSom.textContent = jogo.audio.alternarMudo() ? 'Som: desligado' : 'Som: ligado';
  });
  const pausar = () => {
    if (jogo.pausado || !telaInicio.hidden) return;
    if (jogo.uiAberta === 'celular') jogo.celular.fechar();
    else if (jogo.uiAberta === 'loja') jogo.loja.fechar();
    jogo.pausado = true;
    telaPausa.hidden = false;
    entrada.destravar();
  };
  // Esc do navegador solta o mouse: pausa (a menos que tenha sido para abrir uma tela)
  entrada.aoPerderTrava = () => {
    if (!jogo.uiAberta && !jogo.pausado) pausar();
  };
  $('btn-pausa').addEventListener('click', pausar);
  $('btn-mapa').addEventListener('click', () => jogo.hud.alternarMapa());
  $('fechar-mapa').addEventListener('click', () => jogo.hud.alternarMapa());
  entrada.ligarToque($('joystick'), $('joystick-pino'), [
    [$('t-entrar'), 'KeyE', null],
    [$('t-freio'), null, 'freioMao'],
    [$('t-buzina'), 'KeyH', null],
    [$('t-mirar'), 'ToqueMirar', null],
    [$('t-atirar'), 'Mouse0', 'atirar'],
    [$('t-arma'), 'KeyQ', null],
    [$('t-celular'), 'Tab', null],
  ]);
  $('btn-celular').addEventListener('click', () => !jogo.pausado && jogo.celular.alternar());
  document.addEventListener('visibilitychange', () => document.hidden && pausar());

  // ---- laco principal
  function passo(dt) {
    if (jogo.uiAberta === 'loja') return; // dentro da loja o mundo para
    jogo.tempo += dt;
    const cena = prisao(dt) || hospital(dt);
    if (!cena) {
      if (!jogo.uiAberta) servicos(dt);
      else jogo.promptAtual = '';
      jogo.jogador.atualizar(dt, entrada, cam.yaw);
    } else jogo.promptAtual = '';
    jogo.armas.atualizar(dt, entrada, !cena && !jogo.uiAberta);
    if (jogo.destino && dist(jogo.jogador.px, jogo.jogador.pz, jogo.destino.x, jogo.destino.z) < 8) {
      jogo.destino = null;
      jogo.hud.mensagem('Você chegou ao destino.', 2);
    }
    marcadorDestino.visible = !!jogo.destino;
    if (jogo.destino) marcadorDestino.position.set(jogo.destino.x, 20, jogo.destino.z);
    if (jogo.celular.aberto()) jogo.celular.atualizarHora();
    jogo.trafego.atualizar(dt);
    jogo.policia.atualizar(dt);
    passoFisica(jogo, dt);
    jogo.pedestres.atualizar(dt);
    jogo.missoes.atualizar(dt);
    jogo.hud.atualizar(dt);
    jogo.audio.atualizar(jogo);
    cam.atualizar(dt, jogo, entrada);
  }
  // Para testes automatizados: roda `seg` segundos de jogo sem esperar o relogio.
  jogo.simular = (seg, dt = 1 / 30) => {
    for (let t = 0; t < seg; t += dt) {
      passo(dt);
      entrada.fimDoQuadro();
    }
  };

  let antes = performance.now();
  function quadro(agora) {
    requestAnimationFrame(quadro);
    const dt = Math.min(0.05, (agora - antes) / 1000);
    antes = agora;

    if (entrada.apertou('Escape', 'KeyP')) {
      if (jogo.uiAberta === 'celular') jogo.celular.voltar();
      else if (jogo.uiAberta === 'loja') jogo.loja.fechar();
      else if (jogo.pausado && telaInicio.hidden) comecar();
      else pausar();
    } else if (entrada.apertou('Tab') && !jogo.pausado && jogo.uiAberta !== 'loja') {
      jogo.celular.alternar();
    } else if (entrada.apertou('KeyE') && jogo.uiAberta === 'loja') {
      jogo.loja.fechar();
    }
    if (entrada.apertou('KeyM') && !jogo.uiAberta) jogo.hud.alternarMapa();
    if (entrada.apertou('KeyN')) btnSom.click();

    if (!jogo.pausado) passo(dt);
    else if (telaInicio.hidden === false) {
      // camera passeando atras da tela de inicio
      const t = agora / 1000;
      camera.position.set(Math.cos(t * 0.05) * 160, 70, Math.sin(t * 0.05) * 160);
      camera.lookAt(0, 0, 0);
    }
    const j = jogo.jogador;
    sol.position.set(j.px + 60, 110, j.pz + 35);
    sol.target.position.set(j.px, 0, j.pz);
    entrada.fimDoQuadro();
    renderer.render(cena, camera);
  }
  requestAnimationFrame(quadro);
}

iniciar().catch((e) => {
  console.error(e);
  const t = document.getElementById('carga-texto');
  if (t) t.textContent = 'Não foi possível iniciar o jogo: ' + e.message;
});
