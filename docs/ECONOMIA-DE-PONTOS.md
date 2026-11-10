# EcoViva — economia de pontos

Versão curta para a feira (09/11/2026). Todos os números abaixo são decisões que tomei e podem ser mudados; a última seção diz onde.

## A regra em seis linhas

1. Cada ação vale pontos conforme o **esforço** de quem faz e o **impacto ambiental**.
2. Cada ação tem um **limite por dia** (ou por semana), porque o registro é declarado pela própria pessoa.
3. Existe um **teto de 400 pontos de ações por semana**. Passou do teto, a ação continua sendo registrada, mas sem pontos.
4. **Bônus** de desafio concluído e de conquista são prêmios únicos e **não entram no teto**.
5. Os pontos compram **cupons de parceiros**. O preço segue o valor do benefício: **50 pontos para cada R$ 1**.
6. O **nível** sobe com os pontos ganhos e não cai quando a pessoa gasta pontos.

## Como era e por que mudou

| Problema encontrado | Efeito |
|---|---|
| Fechar a torneira valia 15 pontos e um mutirão de limpeza valia 60 | Duas horas de trabalho coletivo valiam o mesmo que escovar os dentes quatro vezes |
| Um registro aceitava quantidade até 50, sem limite por dia | Um toque rendia 750 pontos |
| Um desafio podia ser concluído tocando várias vezes no mesmo botão | Bônus de 100 a 180 pontos sem fazer nada |
| Um café grátis custava 150 pontos | Bastavam 10 escovações de dentes |
| Os pontos das conquistas apareciam na tela e nunca eram creditados | Promessa não cumprida |

## Quanto vale cada ação

Esforço e impacto vão de 1 a 5. Os pontos crescem com os dois, e as ações coletivas valem mais.

| Ação | Esforço | Impacto | Antes | Agora | Limite |
|---|---|---|---|---|---|
| Fechar a torneira ao escovar os dentes | 1 | 1 (12 litros por vez) | 15 | **5** | 2 por dia |
| Apagar luzes em cômodos vazios | 1 | 1 | 20 | **5** | 1 por dia |
| Separar resíduos secos e orgânicos | 2 | 2 | 30 | **15** | 1 por dia |
| Compostagem de resíduos orgânicos | 3 | 3 | 35 | **25** | 1 por dia |
| Deslocamento a pé ou de bicicleta (até 5 km) | 3 | 4 | 40 | **30** | 2 por dia |
| Mutirão de limpeza de praça (cerca de 2 horas, em grupo) | 5 | 4 | 60 | **100** | 1 por semana |

O que ficou caro demais antes: os hábitos de um gesto (torneira, luzes). O que ficou barato demais: o mutirão. Agora um mutirão vale 20 torneiras, e um trajeto de bicicleta vale 6.

## Quanto cada tipo de usuário ganha por semana

| Perfil | O que faz | Pontos por semana |
|---|---|---|
| **Casual** | 3 dias na semana, com torneira (2x) e separação de resíduos; um trajeto a pé | cerca de **105** |
| **Regular** | 5 dias, com torneira (2x), luzes e resíduos todo dia; compostagem 2 vezes; 3 trajetos | cerca de **290** |
| **Dedicado** | 7 dias, tudo no limite, mais um mutirão | 905 pelas ações, **400 pelo teto** |

Conta do usuário regular: torneira 10 × 5 = 50; luzes 5 × 5 = 25; resíduos 15 × 5 = 75; compostagem 25 × 2 = 50; trajetos 30 × 3 = 90. Total 290.

## O teto semanal

- **Valor: 400 pontos por semana.** Fica cerca de 40% acima do usuário regular, que portanto nunca é barrado. Só o uso muito intenso encosta no teto.
- **O que conta:** só os pontos das ações do dia a dia.
- **O que não conta:** bônus de desafio concluído e bônus de conquista. São prêmios únicos e limitados (ver abaixo), e cortar um bônus pela metade frustraria quem acabou de concluir um desafio.
- **Ao atingir:** a ação continua sendo registrada. Ela entra no histórico, conta para desafios, conquistas, litros poupados e sequência de dias; só não soma pontos. Se a ação passa do teto por pouco, entra a parte que cabe (por exemplo, 20 dos 25 pontos).
- **Quando zera:** toda segunda-feira, à 00:00 no horário de Brasília.
- **No app:** uma barra "Pontos de ações nesta semana" mostra quanto já entrou, quanto falta e quando zera; ao atingir, aparece um aviso e uma notificação.

Por que não 500: com os limites por ação, 500 só seria atingido por quem pedala para o trabalho todos os dias e ainda faz todo o resto. Com 400 o teto cumpre o papel de limitar o custo dos parceiros e o abuso, sem punir o uso normal. É uma escolha; trocar o número é uma linha de código.

## Bônus

| Origem | Pontos | Quantas vezes |
|---|---|---|
| Desafio "Semana sem desperdício de água" (7 dias com ação de Água) | 100 | uma vez por conclusão |
| Desafio "Transporte ativo no bairro" (5 trajetos em 7 dias) | 100 | uma vez por conclusão |
| Desafio "Mutirão da praça central" (1 mutirão em 14 dias) | 60 | uma vez por conclusão |
| Desafio "Desafio da compostagem" (10 dias em 14) | 150 | uma vez por conclusão |
| Dez conquistas (30 a 150 cada) | 770 no total | uma vez cada |

Os desafios não têm mais botão de "registrar etapa": avançam sozinhos quando a pessoa registra uma ação da categoria do desafio, no máximo uma etapa por dia nos desafios contados em dias. Cada desafio tem prazo próprio, contado a partir do dia em que a pessoa entra; vencido, pode ser recomeçado do zero.

As conquistas agora creditam de verdade os pontos que mostram e guardam a data do desbloqueio. Os critérios foram alinhados com as descrições (por exemplo, "4 dias seguidos" passou a exigir uma sequência de fato).

## Níveis

Os nomes ficaram sem gênero e seguem a ideia de uma planta crescendo.

| Nível | Pontos ganhos | Tempo de um usuário regular |
|---|---|---|
| 1. Semente | 0 a 299 | início |
| 2. Broto | 300 a 999 | cerca de 1 semana |
| 3. Muda | 1.000 a 2.499 | cerca de 1 mês |
| 4. Árvore | 2.500 a 5.999 | cerca de 2 meses |
| 5. Floresta | 6.000 ou mais | cerca de 5 meses |

## Preço dos cupons

A loja de recompensas já existia. O que mudou: cada recompensa virou um **cupom** com valor do benefício, validade, limite por pessoa e três estados (disponível, usado, vencido), e o parceiro confere o cupom digitando o código dele no celular do cliente.

**Regra de preço:** pontos = valor do benefício em reais × 50. Itens digitais (sem custo por unidade para o parceiro) têm 20% de desconto. Descontos percentuais são precificados pelo benefício médio.

| Faixa | Valor do benefício | Pontos | Tempo de um usuário regular |
|---|---|---|---|
| 1. Primeira recompensa | até R$ 5 | até 250 | menos de 1 semana |
| 2. Do dia a dia | R$ 6 a R$ 15 | 300 a 750 | 1 a 3 semanas |
| 3. Intermediária | R$ 16 a R$ 40 | 800 a 2.000 | 3 a 7 semanas |
| 4. Grande | R$ 41 a R$ 80 | 2.050 a 4.000 | 2 a 3 meses |
| 5. Especial | acima de R$ 80 | acima de 4.000 | mais de 3 meses |

Catálogo de demonstração:

| Cupom | Parceiro | Benefício | Pontos | Semanas (regular) | Limite por pessoa em 30 dias |
|---|---|---|---|---|---|
| 15% de desconto no combo | Café Raízes | R$ 4 | 200 | 0,7 | 2 |
| 20% de desconto no almoço executivo | Restaurante Sabor da Terra | R$ 7 | 350 | 1,2 | 2 |
| Café especial grátis | Café Raízes | R$ 9 | 450 | 1,6 | 2 |
| Sobremesa da casa grátis | Restaurante Sabor da Terra | R$ 12 | 600 | 2,1 | 2 |
| Skin Guardião da Floresta (digital) | Floresta Games | R$ 20 | 800 | 2,8 | 1 |
| Kit de sacolas reutilizáveis | Mercado Verde | R$ 30 | 1.500 | 5,2 | 1 |
| Prato do dia vegetariano grátis | Restaurante Sabor da Terra | R$ 32 | 1.600 | 5,5 | 1 |
| Passe de temporada (digital) | Floresta Games | R$ 40 | 1.600 | 5,5 | 1 |
| Camisa oficial EcoViva | Bike Urbana | R$ 50 | 2.500 | 8,6 | 1 |
| Cesta de hortifrúti orgânico | Mercado Verde | R$ 60 | 3.000 | 10,3 | 1 |
| Revisão básica de bicicleta | Bike Urbana | R$ 60 | 3.000 | 10,3 | 1 |
| Limpeza ecológica residencial | EcoClean Serviços | R$ 160 | 8.000 | 27,6 | 1 |

Os cupons valem 30 dias depois do resgate (45 ou 60 nos serviços e nos itens digitais). O estoque de cada um é definido pelo parceiro.

## Quanto isso custa para os parceiros

- No máximo **R$ 8 por usuário por semana** (400 pontos ÷ 50), cerca de R$ 35 por mês, e só para quem bate o teto toda semana.
- O usuário regular gera cerca de R$ 5,80 por semana em benefícios.
- Os bônus somam no máximo 1.180 pontos por pessoa (R$ 23,60), uma única vez.
- O limite por pessoa e o estoque de cada cupom impedem que poucos usuários levem tudo.

## Meta coletiva e ranking

- **Meta coletiva da semana:** 400 ações registradas por toda a comunidade, de segunda a domingo. Conta ações (não pontos), para valorizar a participação de quem faz hábitos simples. Na demonstração, com 19 moradores, a comunidade chega à quarta-feira à tarde com cerca de 40% da meta, no ritmo de fechar no domingo.
- **Ranking da semana:** ordena as pessoas pelos pontos de ações da semana e mostra os cinco primeiros, com o nome abreviado ("Marina L."). Como todos têm o mesmo teto de 400 pontos, ninguém dispara: o ranking premia constância, não exagero.
- Os dois são calculados sobre os registros de todos os usuários. Na demonstração, os outros moradores são fictícios, mas as contas são reais: ao registrar uma ação, a meta e o ranking mudam na hora.

## Proteções contra abuso

- Limite por ação (por dia ou por semana) e quantidade sempre inteira.
- Teto semanal de pontos.
- Desafios avançam só com ações registradas, uma etapa por dia nos desafios por dias, e têm prazo.
- Cada cupom só pode ser usado uma vez, tem validade e precisa do código do parceiro para ser dado como usado.
- O que ainda depende de confiança: a pessoa declarar que fez a ação. Ideias para reduzir isso (foto, confirmação por outro morador, leitura de código no local) estão em `IDEIAS.md`.

## Onde mudar os números

As regras existem em dois lugares, o app (modo local) e a API do servidor (modo online). Para os dois continuarem iguais, mude o número nos dois.

| O quê | No app (`eco-app`) | Na API (`eco-backend`) |
|---|---|---|
| Teto semanal | `lib/core/local/economy.dart` (`weeklyCap`) | variável `WEEKLY_POINTS_CAP` do arquivo `.env` (padrão 400) |
| Pontos por real, faixas de nível | `lib/core/local/economy.dart` | `src/services/economy.js` |
| Pontos, limites e textos das ações; desafios; parceiros e cupons; meta coletiva | `lib/core/local/local_seed.dart` | `src/seed.js` |
| Regras (limites, teto, desafios, conquistas, resgate) | `lib/core/local/local_api.dart` | `src/services/` (`actions.js`, `challenges.js`, `progress.js`, `rewards.js`) |
| Testes que travam essas regras | `test/local_api_test.dart` | `test/local-api.test.js` |

## Situação

- **App no modo local (o da feira):** tudo acima está implementado e coberto por testes automáticos (90 passando).
- **API do servidor (`eco-backend`):** as mesmas regras foram portadas em 09/11, com os mesmos casos de teste, e passaram por uma revisão independente (137 testes passando). O modo online passa a se comportar como o modo local.
- **Demonstração e dia da semana:** como cada ação tem limite por dia, a conta de demonstração só chega perto do teto a partir da quarta-feira (na segunda começa em 50 de 400, na terça em 265 e na quarta em 375). Na feira, quarta, o roteiro do teto funciona em qualquer horário.
