# Porto Brasa — projeto Godot 4

Versão 0.1 do jogo portada para a **Godot 4.4** (GDScript), com as mesmas
mecânicas da versão de navegador e os mesmos modelos do Blender.

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
PB_FOTOS=/tmp/fotos godot --path game/godot -- --teste=fotos  # tudo + capturas de tela
```

Cada teste imprime `[ok]` ou `[FALHOU]` por item e um `RESULTADO` no final.
