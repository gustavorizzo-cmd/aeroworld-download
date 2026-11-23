# Porto Brasa — versão 0.1 (protótipo jogável)

Jogo de mundo aberto feito com os modelos de [`assets/`](assets/README.md),
seguindo o escopo do protótipo definido na
[pesquisa](../docs/pesquisa-jogo-mundo-aberto.md). Existe em duas versões com
as mesmas mecânicas:

| Versão | Pasta | Para quê |
|---|---|---|
| **Godot 4** (principal, v0.2) | [`godot/`](godot/README.md) | onde o jogo cresce: tem também mercado, celular, armas, vida e hospital |
| Navegador (Three.js, v0.1) | `web/` | demo rápida: abre com dois cliques ou por link |

## Como jogar no navegador

Abra **`web/dist/porto_brasa.html`** no navegador (Chrome, Edge ou Firefox), com
dois cliques. O arquivo é único e já traz o Three.js e todos os modelos, então
funciona sem internet. Só as fontes vêm do Google Fonts; sem internet o jogo usa
as fontes do sistema.

| Ação | Teclado | Toque |
|---|---|---|
| Andar / dirigir | W A S D ou setas | joystick à esquerda |
| Entrar, sair ou roubar carro | E | botão **E** |
| Correr (a pé) | Shift | empurrar o joystick até o fim |
| Freio de mão | Espaço | botão **Freio** |
| Girar a câmera | arrastar o mouse | arrastar no lado direito |
| Mapa · buzina · pausa · som | M · H · P/Esc · N | botões **Mapa** e **Pausa** |

O progresso (dinheiro, missões e roupa) é salvo no navegador.

## O que tem nesta versão

- **Cidade:** 5 × 5 quarteirões com Centro, Orla (praia), Porto e Subúrbio, ruas
  em grade, semáforos, postes e palmeiras.
- **A pé e de carro:** 3 carros com física arcade (derrapagem no freio de mão,
  lataria que amassa, pneus que furam). Pegar um carro que não é seu é crime.
- **Trânsito e pedestres:** carros seguem as faixas pelo grafo de ruas e param
  para obstáculos. Pedestres andam pelas calçadas, fogem de perigo e servem de
  testemunhas.
- **Polícia em duas camadas (como na pesquisa):**
  - *Estrelas (1–4)*: a força da caçada. 1★ tentam te parar; 2★ batem no
    carro; 3★ montam bloqueios com tapete de pregos; 4★ chega o helicóptero.
  - *Ficha*: o que a polícia sabe (carro e roupa). Continua por 2,5 minutos
    depois da fuga. Se uma viatura reconhecer seu carro ou roupa, você ganha
    estrela de novo.
  - Crime só conta se alguém **vir**: uma viatura vê na hora; um pedestre liga
    em 5 s (chegue perto para impedir); alarme de carro denuncia na hora.
  - *Perseguição → busca → fuga*: perdendo contato, aparece um círculo de busca
    no mapa. Saia dele e fique fora de vista para despistar. Sem radar de
    viaturas no minimapa: elas só aparecem quando estão perto.
  - Ficar parado perto de uma viatura com estrelas = **preso** (multa de 15% e
    volta para a casa segura).
- **Limpar a Ficha:** trocar de carro longe das viaturas, **pintar o carro** na
  Oficina de Pintura (R$ 150, também conserta) ou **trocar de roupa** na Casa
  Segura (tecla E na porta).
- **3 missões:** *Carro de Luxo* (roubo e entrega sem amassar), *Entrega
  Expressa* (tempo de 95 s) e *Encontro Furado* (armadilha com 3★: fuja e volte
  para casa).
- **HUD:** objetivo, estrelas, Ficha, dinheiro, velocímetro com lataria,
  minimapa com GPS, mapa grande (M), avisos de testemunha e de prisão.
- **Som** sintetizado (motor, sirene, batidas), sem arquivos de áudio.

## Código

```
web/
  build.mjs          gera dist/ (esbuild + modelos .glb embutidos em base64)
  src/
    main.js          inicialização, laço do jogo, oficina e casa segura
    mapa.js          cidade, bairros, colisores, grafo de ruas e GPS
    veiculo.js       carros e física arcade
    fisica.js        colisões (carros, prédios, postes, cavaletes, pregos)
    jogador.js       personagem a pé, entrar/sair/roubar carro, roupas
    trafego.js       IA do trânsito (faixas, curvas, freio por obstáculo)
    pedestres.js     pedestres, fuga, atropelamento e testemunhas
    policia.js       estrelas, Ficha, visão, perseguição, busca, bloqueios, helicóptero
    missoes.js       as 3 missões e os marcadores
    hud.js           HUD, minimapa e mapa grande
    camera.js        câmera em 3ª pessoa
    audio.js         sons com WebAudio
    entrada.js       teclado, mouse e toque
    pagina.html      HTML e CSS da interface
```

Para mudar o código e gerar de novo:

```bash
cd game/web
npm install
npm run build      # cria dist/porto_brasa.html (~2 MB)
```

No console do navegador, `PB` dá acesso ao estado do jogo. Por exemplo,
`PB.policia.aplicar(3)` dá 3 estrelas e `PB.simular(5)` avança 5 segundos.
Isso serve para testes.

## Limitações conhecidas desta versão

- Sem armas nem combate a pé (a pesquisa deixou isso fora do protótipo).
- Semáforos são decorativos e o trânsito não respeita sinal.
- Pedestres não atravessam a rua; ficam em volta dos quarteirões.
- A polícia não entra nos pátios internos dos quarteirões, e esconder-se lá
  funciona bem demais.
- Sem ciclo de dia e noite.
