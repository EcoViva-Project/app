# EcoViva — App

Aplicativo Flutter do EcoViva, um clube de hábitos sustentáveis para o bairro. A pessoa registra ações ecológicas (fechar a torneira, separar resíduos, ir de bicicleta, participar de um mutirão), ganha pontos, sobe de nível, cumpre desafios, vê o que acontece na comunidade e no mapa do bairro e troca os pontos por cupons de parceiros. O projeto é acadêmico e a cidade usada nos dados é São José do Rio Preto (SP).

O app roda em dois modos, escolhidos na hora de gerar o aplicativo. No **modo local**, o padrão, ele funciona sozinho no aparelho, sem internet. No **modo online**, ele fala com a API do `eco-backend` (repositório `EcoViva-Project/backend`).

- App: https://github.com/EcoViva-Project/app
- API: https://github.com/EcoViva-Project/backend

## Os dois modos

O modo é definido por `--dart-define` na compilação (`lib/core/services/api_client.dart`). As telas e os serviços são os mesmos nos dois; só muda o transporte das requisições.

| | Local (padrão) | Online |
| --- | --- | --- |
| Variável | `ECO_MODE=local` (ou nenhuma) | `ECO_MODE=online` |
| Quem responde | Uma API escrita em Dart dentro do app (`lib/core/local/`) | O `eco-backend`, pela rede |
| Rede | Não usa | Necessária |
| Endereço da API | não se aplica | `ECO_API_URL`, padrão `http://127.0.0.1:3100/api` |
| Quando usar | Demonstrações, feiras, uso sem internet | Quando o servidor estiver disponível e atualizado |

Para gerar:

```bash
# Modo local
flutter run
flutter build apk --release

# Modo online
flutter run --dart-define=ECO_MODE=online --dart-define=ECO_API_URL=http://<endereço>:3100/api
flutter build apk --release --dart-define=ECO_MODE=online --dart-define=ECO_API_URL=http://<endereço>:3100/api
```

O emulador Android enxerga o computador em `10.0.2.2`; um celular físico precisa do IP do computador na mesma rede.

### O que acontece no modo local

- Os dados ficam no aparelho, em SQLite (`ecoviva.db`, via `sqflite`). Quando o SQLite não está disponível, como no navegador, o app grava em `shared_preferences`. Se o SQLite falhar em um aparelho, o app troca sozinho para essa reserva.
- Os dados persistem ao fechar e abrir o app.
- Na primeira abertura o app cria a conta de demonstração, com cerca de nove semanas de histórico (63 dias) gerado pelas próprias regras. O histórico é relativo ao dia da primeira abertura.
- A tela de entrada tem um botão que entra direto com essa conta. Os dados dela estão em `lib/core/local/local_seed.dart` (`clara@eco.app`, senha `eco1234`).
- Em Perfil, a opção **Restaurar demonstração** apaga os dados do aparelho e recria tudo. Ela só aparece no modo local.
- Para conferir um cupom no resgate, o código dos parceiros na demonstração é `1234`; a tela do cupom informa isso no modo local.
- Na recuperação de senha não há envio de e-mail. O código de 6 dígitos aparece na própria tela.

## Telas e rotas

As rotas estão em `lib/app/app.dart`. Sem sessão, qualquer rota protegida leva a `/login`; com sessão, as rotas de autenticação levam a `/inicio`. Um endereço desconhecido mostra uma tela "Não encontramos esta tela".

| Rota | Tela | O que faz |
| --- | --- | --- |
| `/abrindo` | Abertura | Aparece enquanto a sessão salva é conferida |
| `/login` | Login | Entrar com e-mail e senha; no modo local, botão para entrar com a conta de demonstração |
| `/registro` | Cadastro | Dados da conta e endereço, com sugestão de bairro e validação do CEP |
| `/esqueci-senha` | Esqueci a senha | Pede um código de 6 dígitos e define a nova senha |
| `/inicio` | Início (aba) | Saldo, nível, barra do teto semanal, meta da semana, desafios, atalhos e bloco "Sua comunidade" |
| `/acoes` | Ações (aba) | Catálogo de ações com busca, filtro por categoria (aceita `?categoria=`) e ordenação |
| `/desafios` | Desafios (aba) | Desafios disponíveis e em andamento |
| `/comunidade` | Comunidade (aba) | Números do bairro, meta coletiva, ranking da semana, pontos de coleta e feed de publicações |
| `/perfil` | Perfil (aba) | Conta, edição de dados, atalhos, Restaurar demonstração (modo local) e sair |
| `/registro-acao/:id` | Registro de ação | Confirma a quantidade e registra a ação |
| `/confirmacao-registro` | Confirmação | Resultado do registro: pontos, conquistas e aviso de teto |
| `/meu-historico` | Histórico | Ações registradas |
| `/detalhes-desafio/:id` | Detalhes do desafio | Descrição, progresso e prazo |
| `/progresso` | Progresso | Pontos, ações e atividade da semana |
| `/conquistas` | Conquistas | As 10 conquistas, com progresso e data de desbloqueio |
| `/preferencias` | Preferências | Notificações no app, privacidade (perfil visível, aparecer no mapa), meta semanal e endereço; "Lembretes diários" aparece desativado, marcado "Em breve" |
| `/notificacoes` | Notificações | Lista, marcar como lida e excluir |
| `/recompensas` | Recompensas | Catálogo de cupons, resgate e "Meus cupons" (disponíveis, usados e vencidos) |
| `/mapa` | Mapa da comunidade | Pontos de coleta e vizinhos no mapa, com filtros e opção de ver como lista; aberto a partir de Comunidade |

As cinco abas (Início, Ações, Desafios, Comunidade, Perfil) formam uma barra inferior com `StatefulShellRoute`. As rotas com `:id` recebem o identificador pelo endereço, então funcionam ao recarregar a página na web.

## Regras implementadas no modo local

O raciocínio dos números está em `ECONOMIA-DE-PONTOS.md`, e o plano para o uso sem internet em `OFFLINE-NA-FEIRA.md`; o estado do trabalho está em `PROGRESSO.md`. Esses três arquivos ficam na pasta acima dos repositórios e não fazem parte deste. Os valores abaixo vêm do código: `lib/core/local/economy.dart` (teto, preço, níveis), `local_seed.dart` (ações, desafios, cupons) e `local_api.dart` (as regras em si).

**Pontos e limites por ação.** O registro é autodeclarado, por isso cada ação tem um limite.

| Ação | Pontos | Limite |
| --- | --- | --- |
| Fechar a torneira ao escovar os dentes | 5 | 2 por dia |
| Apagar luzes em cômodos vazios | 5 | 1 por dia |
| Separar resíduos secos e orgânicos | 15 | 1 por dia |
| Compostagem de resíduos orgânicos | 25 | 1 por dia |
| Deslocamento a pé ou de bicicleta | 30 | 2 por dia |
| Mutirão de limpeza de praça pública | 100 | 1 por semana |

**Teto semanal.** São 400 pontos de ações por semana. Passando do teto, a ação continua registrada (histórico, desafios, conquistas), mas sem pontos; se ela passa por pouco, entra a parte que cabe. A semana vai de segunda a domingo e zera na segunda, 00:00 no horário de Brasília. Bônus de desafio e de conquista não entram no teto.

**Níveis.** Seguem os pontos ganhos e não caem quando a pessoa gasta pontos: Semente (0), Broto (300), Muda (1.000), Árvore (2.500) e Floresta (6.000).

**Desafios.** São quatro: "Semana sem desperdício de água", "Transporte ativo no bairro", "Mutirão da praça central" e "Desafio da compostagem". Eles avançam sozinhos quando a pessoa registra uma ação da categoria; nos desafios contados em dias, vale no máximo uma etapa por dia. Cada desafio tem prazo próprio (7 ou 14 dias) contado a partir da entrada, e um desafio vencido pode ser recomeçado. Concluir credita o bônus uma vez.

**Conquistas.** São 10, com pontos de bônus creditados uma única vez e data de desbloqueio gravada.

**Cupons.** O catálogo de demonstração tem 12 cupons de 6 parceiros. O preço segue o valor do benefício, a 50 pontos por R$ 1, e os itens digitais têm desconto. Cada cupom tem validade, limite de resgates por pessoa em 30 dias, estoque e três estados (disponível, usado, vencido). O parceiro confere o cupom digitando o código dele.

**Dados do bairro.** Os números da comunidade são calculados dos registros no banco do aparelho. A demonstração cria 18 moradores fictícios em bairros reais de Rio Preto, com duas semanas de ações geradas pelas mesmas regras. Deles saem os vizinhos ativos, as ações de hoje e da semana, a meta coletiva (400 ações da comunidade por semana), o ranking da semana (cinco primeiros) e a contagem de vizinhos que registraram cada ação hoje. Esses números sobem quando a pessoa registra uma ação.

**Endereço e posição aproximada.** O cadastro e o perfil pedem CEP, rua, número, bairro (com sugestão entre 525 bairros do OpenStreetMap), cidade e UF. No mapa, a pessoa é posicionada na região do bairro, com um deslocamento fixo de até cerca de 350 m, nunca no endereço. Em Preferências ela pode desligar "Aparecer no mapa da comunidade".

**Pontos de coleta.** São 264 pontos de Rio Preto embutidos no app. A distância é calculada a partir da região do bairro da pessoa, e a lista mostra os mais próximos primeiro.

## Localização, foto de comprovação e privacidade

- **Sua posição no mapa.** Com a permissão de localização (pedida só com o app em uso), o marcador "Você" fica onde o celular está; funciona sem internet, pelo GPS. A posição exata fica guardada só no aparelho (`lib/core/services/my_location_service.dart`): nunca vai para a API nem aparece para outras pessoas, que continuam vendo a região do bairro. Sem permissão, sem sinal ou fora da área do mapa, vale a região do bairro, e dá para ajustar tocando no mapa ("Você" → "Ajustar no mapa"). "Restaurar demonstração" mantém essa posição.
- **Bairro.** O reconhecimento aceita abreviações e pequenas diferenças ("Jd." por "Jardim"). Bairro não reconhecido deixa a pessoa sem posição, e o app avisa no cadastro, no perfil e no mapa.
- **Foto de comprovação.** Ao registrar uma ação é possível tirar uma foto ou escolher uma da galeria. A foto fica só no aparelho, reduzida, e o registro ganha o selo "Com comprovação" na confirmação e no histórico. Ela não muda os pontos e não é conferida por ninguém nesta versão. Só existe no modo local.
- **Privacidade.** Com "Perfil visível para a comunidade" desligado, os outros veem a pessoa como "Alguém do bairro" em publicações, comentários, notificações, ranking e mapa. Com "Aparecer no mapa da comunidade" desligado, a pessoa sai do mapa dos vizinhos e o bairro dela não aparece no ranking.
- **Demonstração do dia.** A demonstração guarda o dia em que foi criada. Se os dados forem de outro dia, o Início avisa a conta de demonstração e oferece atualizar.
- **Impacto traduzido.** Os litros poupados aparecem também em garrafões de 20 litros e em dias de água para uma pessoa (110 litros por dia).

Componentes nativos: `geolocator` (localização), `image_picker` (câmera e galeria), `path_provider` e `sqflite`. No Android o app declara as permissões de internet e de localização. A câmera é aberta pelo aplicativo de câmera do aparelho, sem permissão própria.

## Mapa e dados geográficos

- **Origem.** O mapa-base (vias principais, rios e corpos d'água) e a lista de bairros vêm do OpenStreetMap. Os dados são licenciados sob a ODbL, e a tela do mapa mostra o crédito "© colaboradores do OpenStreetMap".
- **Por que o mapa é desenho do projeto.** A política da OSMF não permite usar as imagens (tiles) do OpenStreetMap para funcionar sem internet. Por isso o projeto não baixa imagens: ele desenha as suas, a partir dos dados, com o estilo e o código daqui. As imagens (quadros de 512 px, zoom 11 a 16, cerca de 7 MB) ficam em `assets/map/tiles/` e o `flutter_map` só as posiciona.
- **Por que imagens, e não linhas.** A primeira versão desenhava as vias como linhas a cada quadro e travava no celular. Com as imagens prontas, arrastar e ampliar ficam leves. Rótulos de bairro, pontos de coleta e vizinhos continuam sendo desenhados pelo app por cima.
- **Pontos de coleta.** Vêm de fontes públicas, listadas em cada ponto no arquivo de dados.

Para regerar os arquivos, com Node.js instalado:

```bash
# Dados do mapa-base (baixa da Overpass API) -> tool/dados/mapa_base_rio_preto.json
node tool/gerar_mapa_base.js

# Imagens do mapa-base, desenhadas a partir desses dados -> assets/map/tiles/
flutter test test/capturas/gerar_mapa_tiles.dart

# Bairros e pontos de coleta -> lib/core/local/data/*.dart
node tool/gerar_dados_locais.js [pasta-de-dados]
```

O segundo script lê `bairros-rio-preto.json` e `pontos-de-coleta-rio-preto.json`. Por padrão ele procura uma pasta `dados` ao lado do repositório; essa pasta não faz parte do repositório. Os arquivos em `lib/core/local/data/` são gerados e não devem ser editados à mão.

## Arquitetura

- **Organização por feature:** cada tela fica em `lib/features/<feature>/presentation/pages`, com seus widgets em `presentation/widgets`. Widgets compartilhados estão em `lib/core/widgets`, o tema em `lib/core/theme` (Material 3, fonte Plus Jakarta Sans).
- **Serviços:** `lib/core/services` tem um serviço `ChangeNotifier` por assunto (autenticação, sessão, progresso, ações, histórico, conquistas, desafios, comunidade, notificações, recompensas). As telas os observam diretamente. O `AuthService` carrega os demais após o login e limpa tudo ao sair.
- **`ApiClient`:** cliente único, com transporte trocável. `HttpTransport` fala com o servidor (tempo limite de 12 s, mensagens de erro em português, sessão vencida tratada); `LocalTransport` entrega a requisição à `LocalApi`, que reproduz as rotas e os formatos da API do servidor.
- **API local (`lib/core/local/`):** `local_api.dart` (rotas e regras), `local_store.dart` e `sqlite_store.dart` (armazenamento), `local_seed.dart` (dados de demonstração), `economy.dart` (constantes e calendário), `places.dart` (bairros e posição aproximada) e `data/` (dados geográficos gerados).
- **Navegação:** `go_router`, com redirecionamento conforme a sessão.

## Como rodar, testar e conferir

Pré-requisito: Flutter 3.44 ou mais novo (Dart 3.13 ou mais novo), conforme o `pubspec.lock`.

```bash
flutter pub get
flutter run                      # modo local
flutter analyze                  # análise estática
flutter test                     # testes automáticos
flutter test test/capturas/gerar_capturas.dart   # imagens das telas em build/capturas/
```

Os testes usam a API local com banco em memória e um relógio fixo (`test/support/local_app.dart`), então passam pelas mesmas regras e serviços do app.

| Arquivo | O que cobre |
| --- | --- |
| `test/local_api_test.dart` | Regras da API local: calendário e níveis, conta de demonstração, limites e teto semanal, desafios, cupons, cadastro e recuperação de senha, estatísticas do bairro, mapa, pontos de coleta, persistência e restauração |
| `test/services_test.dart` | Serviços: login, registro de ação, resgate de cupom, comunidade, notificações, sessão recusada, edição de perfil, restauração |
| `test/acoes_inicio_cadastro_test.dart` | Telas Ações, Início e Cadastro, incluindo bairro, CEP e telas pequenas |
| `test/comunidade_page_test.dart` | Tela Comunidade: números do bairro, pontos de coleta, feed e telas pequenas |
| `test/mapa_page_test.dart` | Tela do mapa: filtros, marcadores, lista e telas pequenas |
| `test/perfil_notificacoes_test.dart` | Notificações, conquistas, perfil e preferências |
| `test/recompensas_page_test.dart` | Resgate e conferência do cupom, "Meus cupons" e telas pequenas |
| `test/responsividade_test.dart` | Rotas abertas em vários tamanhos de tela, telas de autenticação e redirecionamento sem sessão |

`test/support/local_app.dart` é apoio dos testes. Em `test/capturas/`, `gerar_capturas.dart` e `gerar_icones.dart` são ferramentas, não testes: o primeiro gera imagens PNG das telas com os dados da demonstração, para conferir o visual sem aparelho; o segundo regrava os ícones do Android a partir de `web/icons/Icon-512.png`. `gerar_mapa_tiles.dart` desenha as imagens do mapa e `gerar_fotos_exemplo.dart`, as fotos de exemplo da demonstração.

## Limitações conhecidas

- No modo local, os dados não são compartilhados entre aparelhos: cada celular tem as próprias publicações, e uma conta criada em um aparelho não existe nos outros.
- Não há envio de e-mail. Na recuperação de senha do modo local, o código aparece na tela.
- O registro de ações é autodeclarado. A foto de comprovação é opcional e não é conferida. Os limites por ação e o teto semanal reduzem o abuso, mas não o eliminam.
- Os vizinhos, o ranking e a meta coletiva da demonstração vêm de moradores fictícios.
- Os pontos de coleta vêm de fontes públicas e não foram confirmados no local.
- O mapa cobre apenas a área urbana de São José do Rio Preto.
- "Lembretes diários" ainda não existe (a opção aparece desativada).
- Só há interface em português do Brasil e tema claro.
- iOS não está configurado: não existe a pasta `ios/`. O app foi preparado para Android e web.
- O `eco-backend` segue as mesmas regras do modo local, mas a foto de comprovação e a posição exata no mapa só existem no app.

Outros documentos do projeto (economia de pontos, guia para apresentar sem internet, origem dos pontos de coleta, ideias) estão na pasta `docs/`.

## Créditos

Projeto acadêmico EcoViva. Dados de mapa e de bairros: © colaboradores do OpenStreetMap, licença ODbL.
