# Porto Brasa — projeto Godot 4

Versão 0.2 do jogo na **Godot 4.4** (GDScript), com os modelos do Blender.
Tem tudo da v0.1 (que também existe na versão de navegador) e mais:

- **Mercado:** entre com E nas lojas "MERCADO" (ícone M verde no mapa).
  Água de coco, pastel e kit médico recuperam a vida. Armado, dá para
  **assaltar o caixa**: rende R$ 250 a 600, mas a câmera grava e vêm 2 estrelas.
- **Arsenal do Porto** (ícone A vermelho): pistola, escopeta, submetralhadora,
  munição e colete.
- **Armas:** botão direito mira por cima do ombro, esquerdo atira, Q ou rodinha
  trocam de arma, 1 a 4 escolhem. Atirar em público assusta as pessoas e gera
  denúncia. Acertar pessoas dá 3 estrelas. Atirar na polícia dá pelo menos 3
  estrelas. Carros destruídos pegam fogo e explodem.
- **A polícia atira de volta** com 3 estrelas ou mais, e nesse nível demora mais
  para prender.
- **Vida e colete:** barras verde e azul embaixo do minimapa. Se a vida zerar,
  você vai para o hospital (paga 10% e perde as estrelas). Preso, você perde
  as armas.
- **Celular (Tab):**
  - **Contatos:** Rui passa o próximo trabalho; **Táxi** (R$ 40) leva você a
    pé pela cidade; **Mecânico** (R$ 100) traz seu carro consertado;
    **Advogado** limpa a Ficha (R$ 300) ou tira 1 estrela durante a busca (R$ 800).
  - **Mensagens** do Rui, **GPS** com destino em roxo no mapa e **Carteira**.

## Abrir e jogar

1. Baixe a Godot 4.4 ou mais nova (versão padrão, não a .NET) em
   <https://godotengine.org/download>. É um único executável, sem instalação.
2. Abra a Godot, clique em **Importar**, escolha `game/godot/project.godot` e
   depois **Importar e Editar**. Na primeira vez ela importa os modelos, o que
   leva alguns segundos.
3. Aperte **F5** (ou o botão ▶ no canto superior direito).

O projeto usa o renderizador **Compatibility** (OpenGL), que roda em quase
qualquer PC e também permite exportar para navegador e celular depois.

## Controles

| Ação | Teclado e mouse | Controle (Xbox/PS) |
|---|---|---|
| Andar / dirigir | W A S D ou setas | analógico esquerdo, gatilhos aceleram e freiam |
| Câmera | mouse | analógico direito |
| Entrar, sair ou roubar carro | E | Y / △ |
| Correr (a pé) | Shift | A / ✕ |
| Freio de mão | Espaço | RB / R1 |
| Mirar · atirar | botão direito · botão esquerdo | LB · RB |
| Trocar de arma | Q, rodinha ou 1 a 4 | direcional ← → |
| Celular | Tab | direcional ↑ |
| Mapa · buzina · pausa · som | M · H · Esc · N | Back · L3 · Start |

O progresso (dinheiro, missões, roupa) fica salvo em
`user://porto_brasa.cfg`.

## Gerar o .exe para Windows

1. Na Godot: **Editor → Gerenciar Modelos de Exportação → Baixar e Instalar**.
2. **Projeto → Exportar…**: o preset **Windows** já está configurado e gera
   `game/builds/PortoBrasa.exe`, um arquivo único com tudo embutido.

## Estrutura

```
project.godot          configuração (janela 1280x720, Compatibility, MSAA)
cenas/principal.tscn   cena principal: só um Node3D com principal.gd
modelos/*.glb          os 23 modelos de ../assets/modelos
scripts/
  principal.gd         monta a cena, carrega modelos, laço do jogo, oficina e casa segura
  mapa.gd              cidade, bairros, colisores, grafo de ruas e GPS
  fusao.gd             junta a geometria estática em poucas malhas (desempenho)
  veiculo.gd           carros e física arcade
  fisica.gd            colisões (carros, prédios, postes, cavaletes, pregos)
  jogador.gd           personagem a pé, entrar/sair/roubar, roupas
  trafego.gd           IA do trânsito
  pedestres.gd         pedestres, fuga, atropelamento, testemunhas
  policia.gd           estrelas, Ficha, perseguição, busca, bloqueios, helicóptero
  missoes.gd           as 3 missões
  armas.gd             armas, tiros, efeitos, explosões, polícia atirando
  celular.gd           celular: contatos, mensagens, GPS, carteira
  loja_ui.gd           telas do Mercado e do Arsenal
  hud.gd               HUD, minimapa e mapa grande
  interface.gd         tela inicial e pausa
  camera_jogo.gd       câmera em 3ª pessoa
  audio_jogo.gd        sons sintetizados (sem arquivos)
  entrada.gd           teclado, mouse e controle
testes/teste_jogo.gd   testes automáticos
```

A cidade, o HUD e os menus são montados por código. Assim o projeto fica
pequeno e fácil de ler, e dá para trocar qualquer número direto no script: por
exemplo, a velocidade dos carros fica em `TIPOS`, em `veiculo.gd`. Ao rodar o
jogo, a aba **Remoto** da árvore de cenas mostra tudo o que foi criado.

## Testes automáticos

```bash
godot --headless --path game/godot -- --teste=basico       # missões, oficina, roupa, testemunha, prisão
godot --headless --path game/godot -- --teste=perseguicao  # 4 estrelas, helicóptero, bloqueio, pregos
godot --headless --path game/godot -- --teste=interacoes   # celular, táxi, Arsenal, tiros, hospital, assalto
godot --headless --path game/godot -- --teste=renascer     # sem prisão em ciclo ao renascer
PB_FOTOS=/tmp/fotos godot --path game/godot -- --teste=fotos  # tudo + capturas de tela
```

Cada teste imprime `[ok]` ou `[FALHOU]` por item e um `RESULTADO` no final.
