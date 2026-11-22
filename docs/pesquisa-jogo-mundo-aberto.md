# Pesquisa: jogo de crime em mundo aberto (missões, perseguições e mapa)

Data: 22/11/2026 · Fase: **pesquisa** (nenhum código ainda)

Objetivo: reunir o que funciona no gênero "crime em mundo aberto" (GTA 6, GTA V,
Need for Speed, Mafia 3, etc.) e transformar isso em decisões para um jogo
**original**: cidade, personagens, nomes e arte nossos, usando mecânicas do
gênero como referência.

> Contexto: GTA 6 saiu em 19/11/2026 (PS5 / Xbox Series). A maior parte do que
> se sabe sobre o sistema de polícia vem de prévias e guias pré-lançamento;
> detalhes podem mudar conforme a comunidade testa o jogo final.

---

## 1. Perseguições e sistema de polícia

### 1.1 O que o GTA 6 mudou (referência mais atual do gênero)

| Mecânica | Como funciona | Por que importa |
|---|---|---|
| **Crime precisa ser visto** | A polícia só reage se uma testemunha (NPC) vê e denuncia, ou se um alarme dispara. Crime sem testemunha pode nem ser registrado. | Recompensa planejamento e furtividade. |
| **Estrelas 1–6 + "Heat" (calor)** | As estrelas medem *quão forte* a polícia está caçando; o Heat mede *o que a polícia sabe* sobre você e continua mesmo depois que as estrelas caem. | Fuga deixa de ser "esperar o cronômetro". |
| **Evidências separadas** | Roupa, veículo conhecido, arma vista, imagem de câmera (CCTV), parceiro. Cada uma é eliminada individualmente: trocar de roupa/cabelo, trocar/esconder o carro, largar a arma, destruir câmeras, separar-se do parceiro. | Cria mini-objetivos durante a fuga. |
| **Cor das estrelas** | Indicam se a polícia já sabe que *você* é o suspeito. | Feedback claro para o jogador. |
| **Sem radar de viaturas** | Os pontinhos de policiais no minimapa que facilitavam a fuga foram removidos. | Mais tensão; o jogador olha para o mundo, não para o mapa. |
| **Zona de busca** | Sair da área vermelha encerra a perseguição imediata; em nível máximo a busca cobre o mapa inteiro. | Escala clara de risco. |

### 1.2 Lições de outros jogos

- **GTA V – crítica clássica:** fugir era "esconde-esconde" com cones de visão
  e a polícia surgindo do nada cada vez mais; muitos acharam tedioso.
- **Need for Speed (Unbound / Most Wanted):** níveis de Heat numerados; a partir
  do nível ~3 a polícia fica bem mais agressiva e não desiste fácil; com Heat
  alto você é perseguido só de cruzar com uma viatura.
- **Bloqueios dinâmicos:** o mod *Automatic Roadblocks* (GTA V) cria bloqueios
  conforme a rua onde é colocado (sem peças prontas) e aumenta o nível conforme
  duração da perseguição, quantidade de bloqueios já usados e se o suspeito
  está atirando.
- **Driver 2:** bater numa viatura do bloqueio faz ela entrar na perseguição.
- **NFS High Stakes:** barreiras e helicóptero ajudando a localizar o jogador.
- **Police Chase Simulator (indie):** depois que o jogador escapa, os policiais
  *se dividem* para cobrir mais área. O dev destacou que a parte mais difícil
  foi integrar bloqueios com a IA da polícia **e** a IA do trânsito — resolveu
  com uma interface compartilhada entre os dois módulos.
- **Crítica pré-lançamento ao GTA:** a polícia escala rápido demais para força
  letal, independente do crime. Vale ter resposta proporcional.

### 1.3 Proposta para o nosso jogo

**Dois medidores:**

1. **Procurado (1–5 estrelas)** – intensidade da caçada agora.
2. **Ficha (Heat)** – o que a polícia sabe: `rosto`, `roupa`, `carro`, `arma`,
   `câmera`. Fica salvo por um tempo mesmo após fugir.

**Ciclo da perseguição:**

```
Crime → Testemunha/alarme? ──não──> nada acontece
            │ sim
            ▼
   Denúncia (tempo curto para impedir a ligação)
            ▼
   PERSEGUIÇÃO  (viaturas veem você)
            │ perdeu contato visual
            ▼
   BUSCA  (zona no mapa encolhe; polícia se divide)
            │ fora da zona + tempo
            ▼
   ESCAPOU  → estrelas zeram, Ficha continua
```

**Escalada proporcional por estrela:**

| ★ | Resposta |
|---|---|
| 1 | 1 viatura, tenta abordar/prender, não atira primeiro |
| 2 | 2–3 viaturas, manobra de bloqueio (PIT) |
| 3 | Bloqueios na rota prevista, tapete de pregos, policiais atiram |
| 4 | Helicóptero com holofote (cone de visão do alto), SUVs táticas |
| 5 | Busca no mapa todo, unidades especiais, pontes/saídas bloqueadas |

**Formas de despistar (cada uma resolve um item da Ficha):**
trocar de carro fora da vista · pintar o carro em oficina · trocar de roupa ·
usar máscara antes do crime · destruir câmeras · esconder-se (garagem, túnel,
estacionamento coberto) · entrar em casa segura.

**Detalhes técnicos importantes:**
- Visão da polícia = cone + raycast (linha de visada) + distância; helicóptero
  usa cone vertical maior.
- **Nada de spawn na frente do jogador:** viaturas surgem fora da câmera e
  chegam dirigindo.
- Bloqueios gerados a partir do grafo de ruas, prevendo a rota do jogador.
- Polícia e trânsito usam o mesmo sistema de navegação/rua (lição do indie).

---

## 2. Missões

### 2.1 O que a pesquisa diz

- **Missões principais claras e impossíveis de perder** para o público amplo;
  conteúdo opcional pode ser mais livre.
- **Missões secundárias dão vida ao mundo** (Nikolas Kolm, Witcher 3): um mundo
  que gira só em torno da história principal parece morto. Uma boa secundária
  contrasta em tom/ritmo com a principal sem quebrar a história.
- **"Seguir uma linha" vs. "chegar num ponto":** a crítica é que muitas missões
  de mundo aberto são lineares e não usam o mundo aberto. Red Faction: Guerrilla
  defende **liberdade como base**: dar o objetivo e deixar o jogador escolher
  o como.
- **Golpes do GTA V:** fase de planejamento → escolha de abordagem (discreta vs.
  explosiva) → escolha de equipe (mais barato = menos habilidoso, membros
  sobreviventes evoluem) → execução. A graça é a dúvida: "vai dar certo ou tudo
  vai desmoronar?". Crítica: às vezes o jogo muda as regras escondido para
  forçar perseguição "cinematográfica" — evitar.
- **GTA 6 (reviews):** quase tudo é ligado ao objetivo dos protagonistas de
  ganhar dinheiro, então até atividades paralelas parecem progresso; mistura de
  ação, tocaias e missões de planejamento; golpes com preparação mais elaborada;
  carros roubados e itens de valor como renda fora das missões. Críticos
  elogiaram muito os momentos calmos entre os personagens.
- **Diálogo vs. ordem livre:** se secundárias podem ser feitas a qualquer
  momento, o texto fica genérico. Travar algumas por capítulo permite que
  reflitam o arco do personagem.

### 2.2 Tipos de missão propostos

| Tipo | Exemplo | Mecânicas usadas |
|---|---|---|
| **Fuga / perseguição** | Buscar alguém e levá-lo para longe com polícia atrás | Direção, sistema de procurado |
| **Roubo de carro** | Roubar um carro específico sem arranhar e entregar | Direção cuidadosa, furtividade |
| **Entrega com tempo** | Levar pacote antes de X minutos | Conhecimento do mapa |
| **Tocaia / seguir** | Seguir um carro sem ser notado | Distância, cone de visão do alvo |
| **Assalto a loja** | Pequeno roubo, sem testemunhas = sem polícia | Testemunhas, câmeras, máscara |
| **Golpe grande** | Preparação (2–4 missões) + execução | Equipe, abordagem, rotas de fuga |
| **Corrida de rua** | Corridas ilegais | Direção, Heat se a polícia aparecer |

### 2.3 Estrutura de uma missão (modelo de dados)

```
Missão
├─ id, título, capítulo, requisitos (missões anteriores, dinheiro)
├─ ponto de início (marcador no mapa)
├─ etapas[]               ← sequência de objetivos
│   ├─ tipo: ir_até | dirigir_até | seguir | roubar_veículo | fugir | esperar
│   ├─ alvo (posição / veículo / NPC)
│   ├─ condições de falha (veículo destruído, alvo fugiu, tempo esgotado)
│   └─ checkpoint (sim/não)
├─ abordagens opcionais (ex.: discreta / explosiva)
└─ recompensa (dinheiro, desbloqueio, reputação)
```

Regras: checkpoints frequentes, falha explicada na tela, objetivo sempre
indicado (marcador + GPS), e **nunca** trocar as regras escondido.

### 2.4 Progressão sugerida (protótipo)

- **Capítulo 1 (tutorial, 4–5 missões):** andar, roubar carro, dirigir,
  primeira fuga de 1–2★, casa segura.
- **Capítulo 2:** assaltos pequenos (testemunhas/câmeras), tocaia, corrida.
- **Capítulo 3:** primeiro golpe grande com preparação e escolha de abordagem.

---

## 3. Mapa

### 3.1 O que a pesquisa diz

- **Kevin Lynch (A Imagem da Cidade):** mapas mentais são feitos de **caminhos,
  limites, bairros, nós e marcos**. Breath of the Wild usou isso trocando
  realismo por legibilidade.
- **Densidade > tamanho:** focar em áreas limitadas e cheias de coisas é melhor
  que um mundo enorme e vazio. Teste: "o que acontece *entre* os marcos?".
- **Marcos perdem força em mapas muito grandes**; funcionam melhor perto de
  pontos de muito movimento (lição do GTA III).
- **Hierarquia de marcos:** grandes silhuetas visíveis de longe + marcos
  menores dentro de cada bairro + terreno legível (rio, morro) que canaliza
  o movimento.
- **Planejar antes da arte** (Nathan Cheever / Mafia 3): esboçar caminhos,
  marcos, bairros, infraestrutura, vida ambiente e territórios de facções antes
  de modelar. Tamanho do mapa depende de velocidade de deslocamento, densidade
  de encontros, recursos de produção e expectativa do jogador.
- **Cada bairro com identidade própria** (AC Syndicate, Dying Light 2).
- **Referência de escala:** o mapa do GTA 6 (Leonida) é ~2× o do GTA V, com
  seis regiões e uma cidade principal que ocupa só parte dele. Para um projeto
  pequeno, isso é impossível — e desnecessário.

### 3.2 Proposta de cidade original (exemplo)

Nome provisório: **Porto Brasa** — cidade litorânea fictícia, tom tropical.
Tamanho inicial pequeno e denso: ~2 km × 2 km (atravessar de carro em ~2 min).

```
            N
   ┌───────────────────────────────┐
   │  MORRO (favela/mirante)  ▲    │  ← marco: antena no topo
   │      ╲                        │
   │  CENTRO (prédios, banco)  ■   │  ← marco: torre espelhada
   │═══════ AVENIDA PRINCIPAL ═════│  ← caminho principal
   │  PORTO (contêineres) │ ORLA   │  ← marco: guindastes / roda-gigante
   │  INDUSTRIAL          │ praia  │
   │~~~~~~~~ RIO ~~~~ PONTE ~~~~~~~│  ← limite + nó (ponte = ponto de bloqueio)
   │  SUBÚRBIO (casas, oficina)    │
   └───────────────────────────────┘
```

| Bairro | Identidade | Uso no jogo |
|---|---|---|
| Centro | Prédios altos, ruas em grade | Banco (golpe), câmeras por toda parte |
| Orla | Praia, avenida larga, carros caros | Roubo de carro, corridas |
| Porto/Industrial | Contêineres, galpões | Esconderijos, tiroteios, entregas |
| Morro | Ruas estreitas e curvas | Fuga de carro difícil, bom para despistar a pé |
| Subúrbio | Casas, oficina de pintura | Casa segura, troca de visual |

Pontes e túneis viram **nós estratégicos**: em 5★ a polícia bloqueia as pontes.

### 3.3 Regras de construção do mapa

- Ruas como **grafo** (nós = cruzamentos, arestas = vias com mão/faixas) — serve
  para GPS, trânsito, polícia e bloqueios ao mesmo tempo.
- Divisão em blocos (chunks) para carregar só o que está perto.
- Cada bairro: pelo menos 1 marco grande, 3–5 pontos de interesse, 1 lugar para
  se esconder.
- Minimapa + mapa grande com marcadores de missão, casa segura e oficina.

---

## 4. Tecnologia (para decidir na próxima fase)

| Opção | Prós | Contras |
|---|---|---|
| **Navegador (Three.js + física cannon-es ou Rapier)** | Roda sem instalar, fácil de testar e publicar | Desempenho limitado; carro precisa de controle próprio |
| **Godot 4** | Grátis, leve, bom para 3D pequeno, exporta para Windows | Precisa instalar o editor |
| **Unity / Unreal** | Mais recursos prontos | Pesado, curva maior |

Referências: tutorial Three.js + Cannon.js de jogo de corrida; post sobre mundo
aberto de corrida com Three.js + Cannon.js; estudo de caso *Slow Roads*
(web.dev) sobre gerar estradas por blocos no navegador; sandbox 4x4 com Rapier.

Sugestão: **começar no navegador (Three.js)** com visual simples (low-poly) para
validar rápido a sensação de dirigir + polícia, e só depois pensar em engine
maior.

---

## 5. Escopo do primeiro protótipo (MVP)

1. Um bairro (Centro + um trecho da Orla) com grafo de ruas.
2. Personagem a pé + entrar/roubar/dirigir carro (câmera em 3ª pessoa).
3. Trânsito simples seguindo o grafo.
4. Polícia com estrelas 1–3, cone de visão, perseguição → busca → fuga.
5. Ficha (Heat) com 2 evidências: `carro` e `roupa`.
6. 3 missões: roubo de carro, entrega com tempo, fuga.
7. Minimapa com GPS.

---

## Fontes

**Polícia / perseguições**
- [Engadget – Heat system do GTA 6](https://engadget.com/2320983/gta-6s-cops-will-remember-you-thanks-to-the-heat-system/)
- [Engadget – o que as estrelas do GTA 6 indicam](https://www.engadget.com/2322564/gta-6-wanted-level-star-system-details/)
- [GamesRadar – 6 estrelas, rosto, roupa e carro](https://www.gamesradar.com/games/grand-theft-auto/gta-6-wanted-system-goes-up-to-6-stars-and-lets-police-track-your-face-your-clothes-and-your-car/)
- [IBTimes – apagar evidências e esconder veículos](https://www.ibtimes.co.uk/gta-6-revolutionary-police-system-crime-evasion-1818769)
- [AllThingsHow – como o Heat sobe e desce](https://allthings.how/gta-6-wanted-system-explained-how-heat-builds-and-how-you-lose-it/)
- [GTABase – guia do sistema de polícia](https://www.gtabase.com/articles/gta-6/gta-6-wanted-level-explained-police-system-guide)
- [Push Square – sistema de procurado](https://www.pushsquare.com/news/2026/08/im-obsessed-with-gta-6s-next-gen-wanted-system)
- [GTABase – crítica ao sistema antigo](https://www.gtabase.com/articles/gta-6/gta-6-needs-to-reinvent-the-series-outdated-wanted-system)
- [Gameranx – perseguições tediosas do GTA V](https://gameranx.com/features/id/17567/article/are-the-painfully-tedious-chase-mechanics-of-gta-5-intentional/)
- [Game Rant – Heat no NFS Unbound](https://gamerant.com/need-for-speed-unbound-police-mechanics-explained-heat-levels/)
- [Automatic Roadblocks (GitHub)](https://github.com/yoep/AutomaticRoadblock)
- [Police Chase Simulator – devlog bloqueios](https://gamesalutes.itch.io/police-chase-simulator/devlog/557757/deep-dive-on-the-road-blocks-feature)
- [Police Chase Simulator – "a polícia vai te achar"](https://gamesalutes.itch.io/police-chase-simulator/devlog/525363/police-will-find-you-v0028)
- [Wikipedia – NFS III Hot Pursuit](https://www.wikipedia.com/wiki/Need_for_Speed_3)

**Missões**
- [Game Informer – Side Quest Syndrome](https://gameinformer.com/b/features/archive/2017/02/09/side-quest-syndrome-designing-the-road-less-travelled.aspx)
- [Game Developer – liberdade no design de missões (Red Faction)](https://www.gamedeveloper.com/design/embracing-the-chaos-freedom-as-the-cornerstone-for-open-world-mission-design)
- [Game Developer – narrativa em mundo aberto](https://gamedeveloper.com/design/narrative-design-on-open-worlds-should-we-ditch-missions-)
- [Game Developer – side quests (Chris Avellone)](https://www.gamedeveloper.com/design/designing-side-quests-study-these-7-games-and-some-chris-avellone-pointers-)
- [Destructoid – design de missões em mundo aberto](https://www.destructoid.com/?p=84008)
- [TechRadar – consistência de personagens](https://techradar.com/gaming/consoles-pc/from-starfield-to-ghost-of-tsushima-open-world-games-struggle-to-keep-their-characters-consistent)
- [GameSpot – como fizeram os golpes do GTA V](https://www.gamespot.com/features/grand-theft-auto-v-the-making-of-a-great-heist-sequence-6407826/)
- [Shamus Young – crítica aos golpes do GTA V](https://www.shamusyoung.com/twentysidedtale/?p=43611)
- [GTA Wiki – golpes do GTA V](https://gta.wiki/w/Heists_in_GTA_V)
- [Vice – review GTA 6](https://www.vice.com/en/article/gta-6-review/)
- [TechRadar – review GTA 6](https://www.techradar.com/gaming/gta-6-review)
- [Dot Esports – resumo das reviews](https://dotesports.com/gta/news/gta-6-review-roundup)
- [Gaming Trend – review GTA 6](https://gamingtrend.com/reviews/grand-theft-auto-vi-review/)

**Mapa**
- [Game Developer – realismo e legibilidade (Lynch / BotW)](https://gamedeveloper.com/design/realism-and-legibility-in-open-world-level-design)
- [Game Developer – lição de design do GTA III](https://gamedeveloper.com/design/design-lesson-101-i-grand-theft-auto-iii-i-)
- [Game Developer – desenho urbano e cidades de jogo](https://www.gamedeveloper.com/design/urban-design-and-the-creation-of-videogame-cities)
- [Game Developer – level design de mundo aberto (Pascal Luban)](https://gamedeveloper.com/design/open-world-level-design-the-full-vision-part-3-5-)
- [80.lv – decisões por trás de cidades críveis](https://80.lv/articles/hidden-design-decisions-behind-believable-open-world-cities)
- [80.lv – por que mundos maiores nem sempre são melhores](https://80.lv/articles/veteran-game-world-designer-explains-why-bigger-game-worlds-aren-t-always-better)
- [Medium/MY.GAMES – diversidade de pontos de interesse](https://medium.com/my-games-company/how-to-make-an-exciting-open-world-the-pois-diversity-rule-90de6d748eac)
- [PC Guide – mapa do GTA 6 ~2× o do GTA V](https://www.pcguide.com/news/major-new-gta-6-details-revealed-including-12-new-screenshots-animal-species-weather-systems-and-more/)

**Tecnologia**
- [Three.js forum – mundo aberto com Three.js + Cannon.js](https://discourse.threejs.org/t/open-world-racing-setup-with-three-js-and-cannon-js/90085)
- [Three.js forum – tutorial jogo de corrida com Cannon.js](https://discourse.threejs.org/t/tutorial-on-using-three-js-with-physics-library-cannon-js-to-create-a-car-racing-game/5279)
- [Three.js forum – 4x4 com Rapier](https://discourse.threejs.org/t/4x4-builder-off-road-vehicle-configurator/20428.md)
- [web.dev – estudo de caso Slow Roads](https://web.dev/case-studies/slow-roads)
