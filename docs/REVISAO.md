# EcoViva — revisão dos dois repositórios

> Revisão feita em 09/11/2026 sobre o código que estava na `main`. A maior parte dos itens foi tratada no ramo `polimento`; este arquivo fica como registro do ponto de partida.

Data: 09/11/2026. Base: `main` de `eco-backend` (commit `79c8b4e`) e de `eco-app` (commit `52747b3`).
Etapa só de leitura e diagnóstico: nenhum arquivo dos repositórios foi alterado, nada foi commitado.

## Como a revisão foi feita

- **Backend:** li `src/` inteiro e `test/helpers.js`; dos demais arquivos de teste li a lista de casos e busquei o que cada um cobre (não li cada teste linha a linha). `npm test` passou **56 de 56**. Para confirmar as suspeitas, subi a API com banco em memória e porta aleatória, usando um script fora dos repositórios; os itens marcados **confirmado (execução)** vêm daí.
- **App:** o Flutter não está instalado neste computador, então **nada do app foi executado**: nem o app, nem `flutter analyze`, nem `flutter test`. A revisão do app é por leitura. Eu li `main.dart`, `app/app.dart`, todos os serviços, o tema, os widgets comuns, os 4 testes, o `pubspec.yaml`, os manifestos Android e a pasta `web/`. As 17 páginas (cerca de 11.500 linhas) foram lidas inteiras por três revisores auxiliares (outras instâncias do Claude); eu reconferi no código cada trecho citado no corpo deste relatório. O que eles apontaram e eu não reconferi está no Anexo A, separado.
- **Graus de certeza:** *confirmado (execução)* = reproduzi rodando a API; *confirmado (leitura)* = está escrito assim no código, mas o efeito na tela não foi visto; *suspeita* = depende de rodar o app ou de algo que não pude medir.
- **Tamanho do trabalho:** P = minutos; M = 1 a 2 horas; G = meio dia ou mais.

## Resumo

O backend é pequeno, organizado e bem coberto por testes no caminho feliz. Os problemas dele estão na segurança da recuperação de senha e em regras de pontos que podem ser burladas. O app tem boa aparência e a estrutura é simples, mas várias telas ainda são meio protótipo: mostram números escritos à mão, caem em dados fictícios quando a API falha e têm dois fluxos quebrados (desafios e telas abertas sem dados). A documentação diz "Concluído" em pontos que o código não sustenta.

Os cinco achados mais importantes:

1. A recuperação de senha aceita tentativas ilimitadas do código de 6 dígitos e, fora do modo produção, devolve o código na própria resposta (S1, S2).
2. Pontos podem ser fabricados: um desafio é concluído com uma requisição e ações podem ser registradas sem limite; esses pontos compram recompensas (R1, R2).
3. Depois de entrar em um desafio, o app não oferece mais caminho para avançar as etapas, e o botão que parece fazer isso grava outra ação (A1).
4. Quando uma carga da API falha, o app mostra dados fictícios como se fossem do usuário (1.240 pontos, selos, notificações), e várias telas têm números fixos (A3, U1).
5. O APK de release não declara permissão de internet, e o endereço padrão da API aponta para `127.0.0.1`, que no celular é o próprio aparelho (A4, A5).

---

## Prioridade 1 — quebrado ou risco de segurança

### Segurança do backend

**S1. A recuperação de senha aceita tentativas ilimitadas do código** — confirmado (execução)
- Onde: `eco-backend/src/routes/auth.js:99` (código de 6 dígitos), `:116-151` (nenhum contador de tentativas), `src/config.js:38` (validade de 30 minutos); `src/app.js` não tem limitador de requisições.
- Problema: quem souber o e-mail de uma conta pede um código e testa os 900.000 valores possíveis dentro da validade. Nada bloqueia.
- Reprodução: 300 códigos errados seguidos e depois o certo; a resposta foi 200 "Senha redefinida com sucesso".
- Correção: contar tentativas por código e invalidar depois de 5; limitar requisições por IP e por e-mail em `/api/auth/*` (por exemplo com `express-rate-limit`); guardar o código com hash. Tamanho M.

**S2. Fora de `NODE_ENV=production`, qualquer pessoa troca a senha de qualquer conta e pode forjar tokens** — confirmado (execução no backend, leitura no app)
- Onde: `auth.js:109-112` (devolve `devCode`), `config.js:16` (o padrão é `development`), `config.js:3,18` (segredo JWT padrão `eco-dev-secret-change-me`, público no repositório); no app, `eco-app/lib/features/auth/presentation/pages/forgot_password_page.dart:48-55` mostra o código e preenche o campo sozinho.
- Problema: se a API for publicada sem definir `NODE_ENV=production` (uma demonstração em rede, uma hospedagem gratuita), basta saber o e-mail de alguém para receber o código na resposta. Com o segredo padrão, também dá para assinar um token de qualquer usuário.
- Correção: inverter o padrão. Devolver `devCode` só com uma variável explícita (por exemplo `EXPOSE_RESET_CODE=true`); quando `JWT_SECRET` não vier, gerar um segredo aleatório na inicialização em vez de usar um fixo; no app, usar `devCode` só em `kDebugMode`. Tamanho P a M. O envio real de e-mail continua pendente (G).

**S3. O segredo de exemplo do `.env.example` passa na validação de produção** — confirmado (execução)
- Onde: `eco-backend/.env.example:8` (`JWT_SECRET=change-me-to-a-long-random-string`, 33 caracteres), `src/config.js:20-29`, e o README manda copiar o arquivo (`README.md:48`).
- Problema: a validação só recusa o padrão de desenvolvimento e segredos com menos de 32 caracteres. Quem copia o exemplo e define produção sobe a API com um segredo que está no repositório.
- Correção: deixar `JWT_SECRET=` vazio no exemplo e recusar valores de exemplo conhecidos. Tamanho P.

**S4. `forgot-password` revela se o e-mail tem conta, mesmo em produção** — confirmado (execução)
- Onde: `auth.js:93-108`. E-mail existente devolve `{ message, expiresInMinutes }`; inexistente devolve só `{ message }`. O teste `test/auth.test.js:125` fixa esse comportamento.
- Correção: resposta idêntica nos dois casos. Tamanho P.

**S5. Login sem limite de tentativas** — confirmado (execução)
- Onde: `auth.js:59-74`. Fiz 30 tentativas erradas seguidas e o login certo funcionou logo depois. O próprio `README.md:294` admite a falta.
- Correção: o mesmo limitador de S1. Tamanho P.

**S6. Trocar a senha não invalida os tokens já emitidos** — confirmado (execução)
- Onde: `src/middleware/auth.js:5-9,24-25` e `auth.js:144-148`. O token antigo continuou válido depois da redefinição; a validade é de 7 dias (`config.js:36`). Não existe rota para trocar a senha estando logado nem para encerrar sessões.
- Correção: coluna `token_version` (ou `password_changed_at`) em `users`, conferida no middleware. Tamanho M.

**S7. `npm run seed` apaga todos os usuários sem nenhuma trava** — confirmado (leitura)
- Onde: `src/seed.js:415-429`, script em `package.json:10`.
- Problema: rodado por engano com o banco real, apaga tudo.
- Correção: recusar quando `NODE_ENV=production` ou exigir `--force`. Tamanho P.

**S8. Cadastro e perfil aceitam dados inválidos** — confirmado (execução)
- `auth.js:21-46`: e-mail sem formato (`nao-e-email`) é aceito; nome só com espaços vira nome vazio; nome enviado como objeto é gravado como `[object Object]`; não há tamanho máximo.
- `src/routes/users.js:24-48`: nome de 5.000 caracteres aceito; `monthlyGoal: "Infinity"` é gravado e a API passa a devolver `monthlyGoal: null` e progresso 0; `weeklyGoal: 2.5` aceito; bairro vazio aceito.
- Correção: uma função única de validação (tipo texto, tamanho, formato de e-mail, metas inteiras entre 1 e 100). Tamanho M.

### Regras de negócio do backend

**R1. Um desafio é concluído com uma requisição, sem fazer nada** — confirmado (execução)
- Onde: `src/routes/challenges.js:87-89`. O número de etapas vem do cliente, sem teto e sem ligação com ações registradas; `days_left` não é conferido.
- Reprodução: entrar no desafio e enviar `{"steps": 9999}` em um desafio de 10 etapas com `daysLeft = 0`; resultado: concluído e +180 pontos. Pelo app, basta tocar "Registrar etapa de hoje" várias vezes seguidas (`detalhes_desafio_page.dart:59-63`).
- Por que importa: os pontos são trocados por recompensas de parceiros.
- Correção: no máximo uma etapa por dia por desafio (guardar a data da última) ou derivar as etapas das ações da categoria; recusar desafio vencido. Tamanho M.

**R2. Registro de ações sem limite e com quantidade fracionária** — confirmado (execução)
- Onde: `src/routes/actions.js:67`.
- Reprodução: `quantity: 2.5` gravou 37,5 pontos e quantidade 2,5 em colunas inteiras; 21 registros seguidos com quantidade 50 levaram a conta a 15.802,5 pontos e nível 5.
- Correção: exigir inteiro (P); teto diário por ação e por usuário (M).

**R3. Os pontos das conquistas aparecem na tela mas nunca são creditados, e a data do desbloqueio nunca é gravada** — confirmado (execução)
- Onde: `src/services/progress.js:109-193` (cada conquista tem `points` de 30 a 150), `:37-44,62-69` (o saldo só soma `action_records`), `:202` (`unlockedOn: isUnlocked ? null : null`).
- Efeito no app: `conquistas_page.dart:430` mostra "Concluído em Hoje" em toda conquista desbloqueada, para sempre.
- Reprodução: a primeira ação deu saldo 15 e o selo "Primeiros Passos" (+30) com `unlockedOn: null`.
- Correção: tabela `user_achievements` (usuário, selo, data) gravada no desbloqueio, com crédito dos pontos; ou tirar os pontos do texto. Tamanho M.

**R4. Os critérios das conquistas não correspondem às descrições** — confirmado (leitura; o último ponto por execução)
- `progress.js:126-133`: "4 dias seguidos" usa o total de dias ativos, não uma sequência.
- `:134-141`: "Participou de 1 desafio" só destrava com desafio concluído.
- `:169-176`: "Reduza 30% do consumo de água por 7 dias" destrava com 7 dias ativos de qualquer categoria.
- `:153-160`: "compostagem" conta qualquer ação de Alimentação.
- `:107,149-151`: "Falta apenas: X" mostra a primeira categoria que falta, mesmo quando faltam várias.
- Concluir um desafio grava um `action_record` (`challenges.js:99-111`) que conta como ação, dia ativo e categoria: um usuário sem nenhuma ação ganhou "Primeiros Passos" só por concluir um desafio. Selos destravados por desafio também não geram notificação (só `actions.js:110-121` notifica).
- Correção: calcular sequência real, separar "participou" de "concluiu", reescrever as descrições e marcar o registro de recompensa com um tipo próprio. Tamanho M.

**R5. Corpo inválido devolve erro 500** — confirmado (execução)
- Onde: `src/app.js:44-48`. JSON malformado e corpo acima de 1 MB devolvem 500 "Erro interno do servidor" e sujam o log; deveriam ser 400 e 413.
- Correção: respeitar `error.status` no tratador de erros. Tamanho P.

**R6. Mês e dia são calculados em UTC** — confirmado (leitura)
- Onde: `progress.js:21-23,48,56`. Uma ação registrada às 22h do dia 31 em Brasília entra como dia 1 do mês seguinte, o que afeta a meta mensal e os dias ativos. No app, `eco-app/lib/core/services/reward_service.dart:114-131` mostra a data do resgate sem converter para o horário local (o histórico de ações converte, em `action_history_service.dart:39`).
- Correção: definir o fuso no servidor e calcular por data local; `.toLocal()` no app. Tamanho P a M.

### App — fluxos quebrados

**A1. Depois de entrar em um desafio, não há como avançar as etapas** — confirmado (leitura)
- Onde: `eco-app/lib/features/desafios/presentation/pages/desafios_page.dart:539-550`. O botão "Registrar Ação de Hoje" do desafio em andamento abre `/registro-acao` sem `id`; `registro_acao_page.dart:25` assume a ação 1. O avanço de etapa (`addProgress`) só é chamado em `detalhes_desafio_page.dart:63`, e a única navegação com `id` para os detalhes está no card de desafio disponível (`desafios_page.dart:734-745`).
- Efeito: a conta de demonstração tem 2 desafios em andamento que não podem ser avançados. O botão grava "Fechar a torneira" (com quantidade inicial 2) enquanto a tela mostra o título do desafio.
- Correção: o card em andamento abre os detalhes com `id`, e o botão registra a etapa. Tamanho P a M.

**A2. Telas abertas sem dados mostram sucesso falso ou gravam a ação errada** — confirmado (leitura)
- `confirmacao_registro_page.dart:14-15`: mostra "+15 pontos" e "~24 litros" sem nenhum registro.
- `registro_acao_page.dart:25-29`: grava a ação 1 com os valores padrão.
- `detalhes_desafio_page.dart:103-128`: mostra um desafio inventado ("Semana Sem Descarte Único", +120 pts, 3 de 5 etapas) e o botão "Entrar no desafio" não faz nada (`:43-45`).
- Como chegar: o botão "Detalhes" da tela inicial abre a rota sem dados (`inicio/presentation/pages/home_page.dart:558-560`); na web, recarregar a página ou abrir o endereço direto (as rotas dependem de `state.extra`, `lib/app/app.dart:158-186`).
- Correção: rotas com o identificador no caminho (`/detalhes-desafio/:id`, `/registro-acao/:id`) e redirecionamento quando faltar dado. Tamanho M.

**A3. Quando uma carga da API falha, o app mostra dados fictícios como se fossem do usuário** — confirmado (leitura)
- `lib/core/services/auth_service.dart:166-173` engole o erro de cada serviço na carga inicial.
- `user_progress_service.dart:18-23,38-52`: 1.240 pontos, 42 ações, 12 dias ativos, 28 litros.
- `achievement_service.dart:94,127-232`: quatro selos "desbloqueados" em outubro.
- `notification_service.dart:45-86`: cinco notificações inventadas ("Mariana comentou na sua ação").
- `reward_service.dart:145-197`: vitrine fictícia.
- `auth_service.dart:30-35`: nome "Clara Mendes".
- `progresso_page.dart:379-402`: três ações que o usuário não fez quando o histórico está vazio.
- Causa: esses dados existem para os testes passarem (`test/progress_achievements_test.dart:32-37`, `test/notification_navigation_test.dart:42-68`, `test/rewards_test.dart:14-16`).
- Correção: os serviços começam vazios, com estados de carregando e erro; os dados fictícios vão para os testes, com um cliente HTTP falso injetado no `ApiClient`. Tamanho G.

**A4. O APK de release não terá acesso à rede** — confirmado (leitura dos manifestos; não executado)
- Onde: `eco-app/android/app/src/main/AndroidManifest.xml` não declara `android.permission.INTERNET`; só os manifestos de `debug` e `profile` declaram.
- Correção: adicionar a permissão no manifesto principal. Tamanho P.
- No mesmo arquivo: `android:label="eco_app"` (nome que aparece no celular). Em `android/app/build.gradle.kts`: identificador `com.example.eco_app` e release assinado com a chave de debug.
- Suspeita ligada: como o manifesto não tem `usesCleartextTraffic`, endereços `http://` podem ser bloqueados em Android recente. Precisa ser testado no aparelho.

**A5. O endereço padrão da API não serve fora do computador de quem desenvolveu** — confirmado (leitura)
- Onde: `lib/core/services/api_client.dart:24-27` e `dart-define.example.json`: `http://127.0.0.1:3000/api`.
- Problema: no celular, 127.0.0.1 é o próprio aparelho, então o app sem configuração não alcança a API.
- Correção: aqui, subir a API em `PORT=3100` e rodar o app com `--dart-define=ECO_API_URL=http://127.0.0.1:3100/api`; documentar isso e mostrar um aviso claro quando não conectar. Tamanho P.

**A6. Cliente HTTP frágil** — confirmado (leitura)
- `api_client.dart:75-83`: nenhuma requisição tem tempo limite. `lib/main.dart:7-12` espera a carga inicial terminar antes de desenhar a primeira tela, então rede lenta significa tela em branco.
- `api_client.dart:85`: `jsonDecode` fica fora do `try`. Uma resposta que não seja JSON lança `FormatException`, e várias telas só tratam `ApiException` (`comunidade_page.dart:972,1072,1672`, `perfil_page.dart:724`, `preferencias_page.dart:40,51,62`).
- `auth_service.dart:42-51`: qualquer erro ao validar a sessão, inclusive falta de rede, apaga o login salvo.
- `api_client.dart:90-94`: o erro 401 não tem tratamento global. Com o token vencido (7 dias) o usuário continua "logado" e todas as telas falham.
- Correção: tempo limite de 10 a 15 segundos, converter todo erro em `ApiException`, no 401 sair da conta e ir para o login, só apagar a sessão em 401, e uma tela de abertura com indicador. Tamanho M.

**A7. `setState` depois de `await` sem checar se a tela ainda existe** — confirmado (leitura)
- `forgot_password_page.dart:49,58,60,62,87,89`. Reprodução prevista: pedir o código com rede lenta e voltar antes da resposta.
- `comunidade_page.dart:1666-1671`: ao enviar comentário, o campo é limpo antes do envio (o texto se perde se der erro) e `setSheetState` roda depois do `await` mesmo que a folha tenha sido fechada.
- Correção: `if (!mounted) return;` nos pontos citados; na folha de comentários, um widget próprio com estado de envio. Tamanho P a M.

**A8. O login já vem preenchido com a conta de demonstração** — confirmado (leitura)
- Onde: `login_page.dart:18-19` (e-mail e senha no código) e `:184` (credenciais escritas na tela).
- Correção: preencher só em `kDebugMode` ou trocar por um botão "Usar conta de demonstração" controlado por configuração. Tamanho P.

---

## Prioridade 2 — experiência de uso

**U1. Telas com números escritos à mão** — confirmado (leitura)
- Progresso: gráfico semanal `progresso_page.dart:11`, "4 dias seguidos" `:219`, "18 ações" `:243`, percentuais por categoria `:274-309`, dois desafios inventados `:338-351`. A etiqueta "Demonstração" (`:133`) admite isso.
- Início: cartão "Desafio Coletivo da Semana" inteiro (`home_page.dart:414-551`: "Restam 2 dias", "Semana Sem Descarte Único"), "4 dias ativos" e "4 dias seguidos" `:655,682`, semana com "Hoje" sempre na quarta posição `:703-711`, dica do dia fixa `:763-771`.
- Comunidade: distâncias `comunidade_page.dart:136`, "128 vizinhos ativos" e "1.840 ações coletivas" `:408,416`, meta coletiva "380 de 500 ações", "76% alcançado", "84 vizinhos já contribuíram" `:559,567,598`.
- Ações: "Hoje: +1.420 ações" `acoes_page.dart:244`, "Meta Diária: 1/3" `:417`, "432 vizinhos registraram hoje" `:34`.
- Perfil: "+140 na semana" `perfil_page.dart:54`, "5 ações por semana" `:131` (o valor real existe em `weeklyGoal`).
- Conquistas: "Nível Semente" fixo `conquistas_page.dart:237`.
- Início e Confirmação chamam de "impacto acumulado" o saldo que diminui ao resgatar (`home_page.dart:117,132`, `confirmacao_registro_page.dart:149,157`); o acumulado é `pointsEarned`.
- Correção: gráfico, categorias, sequência e últimas ações saem dos registros que o app já tem; o desafio da semana sai do `ChallengeService`; o que não tiver fonte (estatísticas do bairro, meta coletiva) precisa de rota nova ou deve sair da tela. Tamanho M por tela; G para as partes que pedem rota nova.

**U2. O catálogo de ações é fixo no app, e os pontos mostrados são calculados no app** — confirmado (leitura)
- Onde: `acoes_page.dart:20-133`. Nenhum serviço chama `GET /actions`. A confirmação mostra pontos calculados localmente (`registro_acao_page.dart:75-76,104`) e ignora o que o servidor devolveu.
- Problema: os identificadores 1 a 6 só coincidem com o banco porque o seed insere nessa ordem. Mudar o catálogo no servidor faz o app mostrar um valor e creditar outro.
- Correção: um serviço de catálogo com `GET /actions`, e a confirmação usando `record.points` da resposta. Tamanho M a G.

**U3. Falta carregamento, erro e "tentar de novo"; as listas não recarregam** — confirmado (leitura)
- Erros engolidos: `desafios_page.dart:23`, `recompensas_page.dart:30`, `comunidade_page.dart:74-76`, `detalhes_desafio_page.dart:33-38`.
- Depois do login, só três telas buscam dados de novo, e apenas uma vez, quando são criadas: Comunidade (`comunidade_page.dart:53`), Desafios (`desafios_page.dart:23`) e Recompensas (`recompensas_page.dart:30`). Como as abas ficam vivas, Comunidade e Desafios não recarregam mais até o app reiniciar. As notificações são buscadas depois de registrar ação (`registro_acao_page.dart:99`, sem tratamento de erro). Histórico, conquistas, progresso e a própria tela de notificações nunca recarregam; nenhuma tela tem "puxar para atualizar".
- Concluir um desafio cria registro e notificação no servidor, e o app não busca nenhum dos dois; `AuthService.refreshProgress` (`auth_service.dart:154-157`) não é chamado em lugar nenhum.
- `AchievementService` não avisa as telas quando muda (`achievement_service.dart:52,119-121`); Conquistas e Perfil escutam outro serviço (`conquistas_page.dart:31-32`, `perfil_page.dart:36-37`).
- Correção: cada serviço com estado carregando/erro e um componente comum de erro com botão; recarregar ao abrir a tela; `AchievementService` como `ChangeNotifier`. Tamanho M a G.

**U4. Notificações** — confirmado (leitura)
- O diálogo diz "serão removidas desta sessão" (`notificacoes_page.dart:515`), mas a ação apaga no servidor (`notification_service.dart:174-179`).
- Marcar, remover e limpar disparam a requisição e ignoram a falha (`notification_service.dart:133-135,157,167-169,178`): sem rede a tela mostra como feito e tudo volta depois.
- "Marcar como não lida" só vale na memória (`notification_service.dart:139-149`); a API não tem essa rota.
- A categoria `sistema` aparece como "Lembrete" e leva para Ações (`notificacoes_page.dart:584-585,597-598`), mas o servidor a usa para "Resgate confirmado!", "Ação registrada!" e boas-vindas.
- Excluir uma notificação só por gesto de deslizar, sem confirmação nem desfazer (`:134-152`).
- No servidor, toda ação registrada gera uma notificação (`actions.js:103-108`), e `unreadCount` só conta as 100 mais recentes (`src/routes/notifications.js:10-20`).
- Correção: corrigir o texto (P), desfazer a mudança local quando a requisição falhar (M), o servidor informar o destino de cada notificação (M).

**U5. Preferências** — confirmado (leitura e execução)
- "Resumo semanal" só muda na memória e se perde ao sair da tela (`preferencias_page.dart:18,156-158`).
- As opções salvas não mudam nada: com `notificationsEnabled: false` o servidor continuou criando notificações (execução). `weekly_goal` é gravado e nunca usado; a meta mensal, que é a que conta, não pode ser alterada pelo app.
- Rótulo e chave não combinam: "Compartilhar progresso" grava `privacyProfile` e "Aparecer no ranking" grava `privacyLocation` (`:31-32,235,246`). Não existe ranking no app.
- Se o salvamento falhar, o interruptor fica na posição nova (`:133-136`).
- O bairro é texto livre no cadastro (`register_page.dart:21-23`) e lista fixa de quatro opções em Preferências (`preferencias_page.dart:70-76`).
- Correção: esconder ou marcar como "em breve" o que não funciona (P); decidir entre meta semanal e mensal (M); desfazer a mudança no erro (P).

**U6. Comunidade** — confirmado (leitura)
- Os comentários perdem autor e data: a página guarda só o texto (`comunidade_page.dart:68-69`), embora a API envie nome, iniciais e tempo.
- Curtida: dois toques rápidos disparam duas requisições e a resposta do servidor não é usada pela página (`:1064-1079`); a divergência entre tela e servidor é suspeita.
- Nova publicação: o diálogo fecha antes do envio, e um texto recusado pelo servidor se perde (`:936-977`).
- "Participar" das iniciativas só altera uma lista na memória (`:800-804`); "Compartilhar publicação" copia texto.
- Não existe excluir a própria publicação, embora a API tenha a rota e o README diga que existe. A API também não informa de quem é a publicação (ver Contrato).
- A página mantém uma cópia própria das publicações em vez de escutar o `CommunityService` (`:41-72`).
- Correção: usar o serviço como fonte única e mostrar autor e data dos comentários (M); travar a curtida durante a requisição (P); validar e enviar dentro do diálogo (M); excluir publicação com `isMine` vindo da API (M).

**U7. Recompensas** — confirmado (leitura)
- A tela não tem botão de voltar: usa o cabeçalho das abas (`recompensas_page.dart:44-49`) e é aberta fora da barra inferior.
- Não dá para ver os detalhes de uma recompensa que ainda não se pode resgatar (`:465`); o botão diz "Faltam pts" sem dizer quantos (`:475`); o botão da folha de detalhes ignora o saldo (`:710-716`).
- Busca e filtros ficam guardados no serviço e o campo nasce vazio (`:25` e `reward_service.dart:204-206`): ao reabrir, a lista continua filtrada.
- A proteção contra resgate duplo existe só na tela; `RewardService.redeem` não confere se já há um resgate em andamento (`reward_service.dart:309-317`). Duplicação real é suspeita.
- No servidor o resgate está correto: dois pedidos simultâneos com estoque 1 deram 201 e 409, com estoque final 0 (execução).
- Correção: seta de voltar (P); cartão clicável e botão da folha desabilitado sem saldo (P); limpar os filtros ao abrir (P); guarda no serviço (P).

**U8. Registro de ação e confirmação** — confirmado (leitura)
- A quantidade começa em 2 e vai de 1 a 10 (`registro_acao_page.dart:21,343,368`); a API aceita até 50 e o README fala em 1 a 50.
- Os campos de data e de foto não fazem nada (`:285`, `:459`).
- O texto de "litros de água poupados" aparece em toda ação, mesmo nas que têm 0 litros (`:54-56`; no histórico, `meu_historico_page.dart:411-414`).
- "Registrar outra ação" leva ao histórico (`confirmacao_registro_page.dart:243-248`).
- A confirmação é empilhada sobre o formulário (`registro_acao_page.dart:102-105`): voltar retorna ao formulário preenchido, e um novo toque registra de novo (suspeita quanto à frequência).
- "Sugerir ação" mostra "Sugestão enviada para a equipe" sem enviar nada (`acoes_page.dart:720-727`).
- Os selos novos devolvidos pela API não aparecem na confirmação.
- Correção: quantidade inicial 1, esconder data, foto e litros quando não se aplicam, corrigir o destino do botão, trocar `push` por `pushReplacement`. Tamanho P cada.

**U9. Perfil e cabeçalhos** — confirmado (leitura)
- O avatar do cabeçalho mostra a letra "C" para qualquer usuário em Ações, Desafios, Comunidade e Perfil (`acoes_page.dart:191`, `desafios_page.dart:48`, `comunidade_page.dart:83-87`, `perfil_page.dart:27-35`; o padrão está em `lib/core/widgets/app_page_header.dart:20`).
- Nome e bairro ficam copiados no estado da tela de Perfil e desatualizam quando mudam em Preferências (`perfil_page.dart:20-21`); a tela inicial também não reage à troca de nome (`home_page.dart:16-17`).
- Editar perfil: nome vazio é ignorado em silêncio, o diálogo fecha antes do envio e os campos não são liberados nos caminhos de erro (`perfil_page.dart:708-733`).
- E-mail de ajuda com nome de outro projeto: `contato@cidadesustentavel.app` (`:737`). "Versão 1.0 • Feira de Tecnologia" fixo (`:154`).
- "Editar dados pessoais" usa `GestureDetector` com texto de 11 px (`:276-299`).
- Correção: o cabeçalho ler as iniciais do `AuthService` sozinho (P); ler nome e bairro direto do serviço (P); diálogo de edição com validação e envio dentro dele (M).

**U10. Telas de autenticação** — confirmado (leitura)
- A validação de e-mail só confere se há "@" (`login_page.dart:103-104`), e o servidor não valida formato (S8).
- O validador do código aceita 4 caracteres; o código tem sempre 6 dígitos (`forgot_password_page.dart:226`).
- "Usar outro e-mail" não limpa código nem senha (`:290-294`); não há "reenviar código" nem confirmação da nova senha.
- Correção: validadores únicos compartilhados entre as três telas. Tamanho P.

**U11. Desafios não têm prazo de verdade** — confirmado (leitura)
- `eco-backend/src/db.js:93-94`: `days_left` e `participants` são números fixos na tabela. O prazo nunca diminui e o desafio nunca vence.
- No app, os rótulos de dia são fixos (`desafios_page.dart:524`: "Seg, Ter, Qua, Hoje, Sex"), sem relação com o dia real.
- Desafios concluídos somem das duas listas (`challenge_service.dart:73-79`).
- Correção: datas de início e fim no desafio, com dias restantes calculados; seção "Concluídos"; rótulos numerados. Tamanho M.

**U12. Acessibilidade** — confirmado (leitura), com contraste calculado e não medido em tela
- Contraste: texto branco sobre o verde principal `#718B68` dá cerca de 3,8:1, e esse verde como texto sobre o fundo creme dá cerca de 3,5:1; o mínimo recomendado para texto normal é 4,5:1. O verde escuro `#455A3B` já existente resolveria.
- Texto pequeno: `labelSm` tem 11 px (`lib/core/theme/app_text_styles.dart:75-81`) e é usado como texto corrido; o selo de notificações usa 9 px (`app_page_header.dart:128`).
- Botões feitos com `GestureDetector`, sem foco nem efeito de toque: `conquistas_page.dart:322`, `comunidade_page.dart:644`, `perfil_page.dart:276`.
- Alvos de toque abaixo de 48: `acoes_page.dart:347-348` (lista com altura 40) e `:942-943` (botão com mínimo 36).
- O avatar do cabeçalho é anunciado como botão mas, por padrão, não faz nada (`app_page_header.dart:148`).
- O app não configura idioma (`lib/app/app.dart:221-226`, sem `flutter_localizations`): os textos embutidos do Material (menu de copiar e colar, rótulos para leitor de tela) ficam em inglês.
- O `ROADMAP.md` do app marca Acessibilidade como "Concluído".
- Correção: trocar a cor do texto pequeno (P), tamanho mínimo de 12 px (P), `InkWell` ou botões de verdade (P), idioma `pt_BR` (P).

**U13. Dados de demonstração dependem do dia em que o seed roda** — confirmado (execução)
- Onde: `src/seed.js:383-409`. Simulando o seed no dia 20, o mês fica com 22 ações (a meta de 17 aparece estourada) e 11 dias ativos; no dia 2 às 7h da manhã, ficam 9 dias ativos e 7 registros com data no futuro. A documentação promete "12 dias ativos, 14 no mês".
- `seed.js:635,644`: `iso(horas / 24, 12)` não funciona com fração de dia; a publicação "de 3 horas atrás" sai com data de ontem às 12:15.
- Correção: gerar as datas relativas a "agora" com aritmética em milissegundos. Tamanho P.

**U14. Textos e nomes inconsistentes** — confirmado (leitura)
- Tratamento só no feminino: "Bem-vinda ao Eco!" (`auth.js:52`), níveis "Guardiã…" (`progress.js:25-31`, repetidos em `user_progress_service.dart:99-105`), "Escolha como quer ser lembrada" (`perfil_page.dart:117`).
- Três nomes para o produto: EcoViva, "Eco" e "Cidade Sustentável" (`package.json:5`, `perfil_page.dart:737`).
- Mensagem técnica para o usuário final: "Verifique se a API está ativa." (`api_client.dart:80-82`).
- Correção: tamanho P.

---

## Prioridade 3 — limpeza e documentação

**L1. Código repetido entre páginas grandes** — confirmado (leitura) no geral; a lista detalhada de linhas está no Anexo A
- O mesmo cartão branco com sombra, a pílula de categoria, o selo de pontos, a barra de progresso, o título de seção, o estado vazio e o botão principal com indicador são refeitos à mão em quase todas as páginas. `lib/core/widgets/` só tem 2 arquivos.
- Exemplos reconferidos: três métodos de salvar quase iguais em `preferencias_page.dart:37-67`; `_dayCircle` em `home_page.dart:790-829` refaz o `DayStatusCircle` que o próprio arquivo importa; botões estilizados à mão em `confirmacao_registro_page.dart:225-236` e `desafios_page.dart:551-552`.
- Correção: extrair cerca de dez componentes para `lib/core/widgets/`. Tamanho G, mas pode ser feito página a página.

**L2. Tema incompleto** — confirmado (leitura)
- `lib/core/theme/app_theme.dart:37-59` não define tema de botões, campos, diálogos nem folhas, por isso cada página repete o estilo.
- `app_colors.dart` tem duas paletas (`:5-32` e `:35-43`) com dois verdes "principais".
- `app_text_styles.dart:11,19,27` usa `letterSpacing: -0.02`, que no Flutter é medido em pixels e não em proporção; na prática não tem efeito.
- Correção: tamanho M.

**L3. Dependências e código sem uso** — confirmado (leitura)
- `provider` (`pubspec.yaml:14`) e `cupertino_icons` (`:12`) não são importados em `lib/` nem em `test/`.
- `pubspec.yaml:25-29` empacota a pasta inteira de fontes como recurso: 1,7 MB, quando as quatro variações usadas somam 384 KB.
- Sem uso no app: `AuthService.refreshProgress`, o parâmetro `showProfileAvatar` (`app_page_header.dart:19,32`), `NotificationService.add`. Usados só pelos testes: `ActionHistoryService.addRecord` e `AuthService.debugSignIn`.
- `main.dart:9` carrega a sessão, e `auth_service.dart:41` carrega de novo. O app chama `/progress` e depois `/progress/achievements`, embora a primeira rota já devolva as conquistas.
- Correção: tamanho P.

**L4. Consultas ineficientes no backend** — confirmado (leitura)
- `src/services/serializers.js:151-163`: três consultas por publicação; o feed de 100 publicações faz 301 consultas e embute todos os comentários de cada uma.
- `actions.js:73-125`: `getSummary` e `getAchievements` rodam várias vezes por registro.
- `actions.js:17` e `rewards.js:37-39`: carregam tudo e filtram em JavaScript. É aceitável no tamanho atual.
- Sem paginação em feed, notificações e histórico.
- Correção: uma consulta com agregação para o feed, e paginação. Tamanho M.

**L5. Banco de dados** — confirmado (leitura)
- Não há migrações: `src/db.js` só usa `CREATE TABLE IF NOT EXISTS`, então mudar uma coluna não se aplica a um banco existente.
- Sem restrições para pontos e estoque não negativos; `password_resets` nunca é limpo e guarda o código em texto puro; o nome do autor é copiado para publicações e comentários, e trocar o nome não atualiza os antigos.
- Correção: tabela de versão do esquema com migrações numeradas. Tamanho M.

---

## Contrato entre app e API

Conferi cada chamada de `eco-app/lib/core/services/` contra `eco-backend/src/routes/` e `src/services/serializers.js`. Rotas, métodos e nomes de campos **batem em todas as chamadas que o app faz**. As divergências são estas:

| # | App | API | Divergência |
|---|---|---|---|
| C1 | `acoes_page.dart:20-133` (catálogo fixo) | `GET /actions`, `GET /actions/:id` | O app não usa o catálogo da API; depende dos ids 1 a 6 do seed. |
| C2 | `registro_acao_page.dart:75-76,104` | `POST /actions/:id/records` devolve `record` e `newAchievements` | O app ignora `record.points`, `record.liters` e `newAchievements` e mostra valores calculados localmente. |
| C3 | `registro_acao_page.dart:368` (máximo 10) | `actions.js:67` (máximo 50) | Limites diferentes para a quantidade. |
| C4 | `achievement_service.dart:44` lê `unlockedOn` | `progress.js:202` envia sempre `null` | A tela cai em "Concluído em Hoje". |
| C5 | `achievement_service.dart:40` mostra `points` | `progress.js` nunca credita | Pontos exibidos e não pagos (R3). |
| C6 | `community_service.dart:31-70` | `serializers.js:151-176` | A publicação não traz o dono (`authorId` ou `isMine`); o app não tem como oferecer "excluir". |
| C7 | — | `DELETE /community/posts/:id`, `GET /community/posts/:id/comments` | Rotas sem uso no app. |
| C8 | `notification_service.dart:139-149` | — | "Marcar como não lida" não existe na API. |
| C9 | `notification_service.dart` lê `timeLabel` | `serializers.js:59-72` calcula no servidor | O texto "Há 10 min" fica congelado até a próxima carga; `createdAt` é enviado e ignorado. O mesmo vale para publicações e comentários. |
| C10 | `notificacoes_page.dart:584-598` | categorias `sistema`, `conquista`, `desafio`, `comunidade` | O app trata `sistema` como "Lembrete" que leva a Ações; o servidor usa `sistema` para resgate, ação registrada e boas-vindas. |
| C11 | `preferencias_page.dart:31-32,235,246` | `users.js:62-67` | "Compartilhar progresso" e "Aparecer no ranking" usam `privacyProfile` e `privacyLocation`; "Resumo semanal" não tem campo. |
| C12 | `preferencias_page.dart:50` envia `weeklyGoal` | `users.js:45-48` grava, nada lê | Meta semanal sem efeito; `monthlyGoal` nunca é enviado pelo app. |
| C13 | `reward_service.dart:114-131` | `dateTime` em UTC | A data do resgate é mostrada sem converter para o horário local. |
| C14 | `reward_service.dart:217-250` filtra localmente | `GET /rewards?category=&search=&sort=` | Parâmetros da API sem uso; também `GET /rewards/:id` e os campos `partnerDescription`, `partnerIcon`, `status`. |
| C15 | `action_history_service.dart:64` | `records.js:11` (padrão 100, máximo 500) | O histórico e os totais de "Meu histórico" param nos 100 registros mais recentes. |
| C16 | `forgot_password_page.dart:48` lê `devCode` | `auth.js:105-112` | `expiresInMinutes` é ignorado; `devCode` é usado em qualquer tipo de build (S2). |
| C17 | `user_progress_service.dart:99-105` | `progress.js:25-31` | Tabela de níveis duplicada nos dois lados. |
| C18 | — | `GET /users/me` | Rota sem uso (o app usa `/auth/me` e `/progress`). |

---

## Documentação que não bate com o código

**Backend**
- `.agents/TECHNOLOGIES.md:13` fala em 50 testes; são 56. A linha `:6` cita Node 22.16.0 (aqui é 24.20.0) e a `:17` omite `NODE_ENV` e `CORS_ORIGIN`.
- `.agents/ROADMAP.md:42` diz que o app "consome todos os módulos"; o catálogo de ações e as rotas de C7, C14 e C18 não são consumidos, e o próprio `README.md:143-145` diz isso.
- `.agents/ROADMAP.md:43,45` marca "Validação/tratamento de erros" e "Configuração e segurança" como concluídos; ver S1 a S8 e R5. O `README.md:294` é mais honesto.
- `.agents/ARCHITECTURE.md:122` promete "12 dias ativos, 14 no mês" no seed; depende do dia (U13).
- `README.md:279-280` lista os arquivos de teste e esquece `config.test.js` e `cors.test.js`.
- `package.json:5` chama o projeto de "Cidade Sustentável (Eco)"; não há campo `engines`, embora o README exija Node 22.9 ou mais novo.

**App**
- `README.md:9` diz "Android, iOS e web"; não existe pasta `ios/`.
- `README.md:40` diz que a Comunidade permite "excluir a própria" publicação; não existe no app.
- `README.md:46` diz quantidade de 1 a 50; o app limita a 10. A linha `:47` diz que a confirmação mostra novos selos; não mostra.
- `README.md:117` pede Flutter 3.29 ou mais novo; o `pubspec.lock:432-434` exige Flutter 3.44 ou mais novo e Dart 3.13 ou mais novo.
- `.agents/TECHNOLOGIES.md:8,14` cita `go_router ^16.3.0` e `cupertino_icons ^1.0.9`; o `pubspec.yaml` declara `^16.2.1` e `^1.0.8` (as versões citadas são as do `pubspec.lock`).
- `.agents/ARCHITECTURE.md:65` diz que "tudo que é do usuário vem da API"; ver A3 e U1. A linha `:70` diz que as preferências são persistidas; "Resumo semanal" não é.
- `.agents/ROADMAP.md:65,74` marca "Tratamento de erros/carregamento" e "Acessibilidade" como concluídos; ver U3 e U12.
- `.agents/agents/big-pickle.md:19` ainda manda "manter dados locais demonstrativos", e a linha `:14` lista `provider` como parte da pilha.
- `.agents/DESIGN_REFERENCE.md:26` foi revisto em 03/11 e não tem a tela de Recompensas. A pasta `design-reference` não veio com o repositório.
- `.agents/DEVELOPMENT_WORKFLOW.md:17-25` traz caminhos, navegador e aparelho do computador anterior.

---

## Lacunas de teste

**Backend** (56 testes, todos passando). Não há teste para:
- limite de tentativas e código vencido na recuperação de senha;
- token antigo depois da troca de senha;
- JSON inválido e corpo grande;
- quantidade fracionária e `steps` exagerado (o teste atual de desafio trata "limitar à meta" como comportamento certo);
- virada de mês e de dia no fuso do Brasil;
- CORS com lista restrita aplicada no `app.js` (só há o caso do curinga);
- o seed (não é exercitado por nenhum teste);
- mais de 100 notificações;
- dois resgates simultâneos (testei à mão e funciona).

**App** (4 arquivos; não executados aqui)
- Três dos quatro arquivos dependem dos dados fictícios embutidos nos serviços (A3).
- Não há teste para a leitura das respostas da API (`fromApi`), para login e cadastro, registro de ação, comunidade ou desafios.
- `ApiClient` usa as funções globais do pacote `http` (`api_client.dart:47-73`), o que impede trocar o cliente por um falso nos testes.
- O teste de responsividade roda sem dados (o feed vem vazio), então não exercita os cartões que só aparecem com conteúdo.

---

## Ordem de trabalho sugerida

1. **Preparar o ambiente (meio dia).** Instalar o Flutter (3.44 ou mais novo, conforme o `pubspec.lock`), rodar `flutter analyze` e `flutter test` para ter o ponto de partida do app, subir a API na porta 3100, definir nome e e-mail dos commits e criar um branch de trabalho em cada repositório.
2. **Segurança do backend (cerca de 1 dia).** S1 a S8 e R5, cada correção com seu teste. É o que mais pesa se o projeto for demonstrado em rede.
3. **Regras de pontos (cerca de 1 dia).** R1 a R4 e R6: etapas de desafio, quantidade inteira e teto, conquistas com data e pontos, fuso horário.
4. **Fluxos quebrados do app (cerca de 1 dia).** A1, A2 e A4 a A8: desafios, rotas com identificador, permissão de internet, endereço da API, cliente HTTP e login.
5. **Dados reais no lugar dos fictícios (2 a 3 dias).** A3 e U1 a U3: serviços com carregando e erro, catálogo de ações pela API, Progresso e Início calculados dos registros, testes com cliente falso.
6. **Polimento das telas (2 dias).** U4 a U14: notificações, preferências, comunidade, recompensas, perfil, acessibilidade.
7. **Limpeza e documentação (1 a 2 dias).** L1 a L5: componentes compartilhados, tema, dependências, e atualização dos `README.md` e de `.agents/`.

As etapas 2 e 3 mexem só no backend e as etapas 4 a 6 mexem quase só no app; dá para alternar. A etapa 5 é a que mais muda a cara do app para quem avalia.

---

## Anexo A — apontado pelos revisores auxiliares e não reconferido por mim

Os itens abaixo vieram da leitura completa das páginas pelos revisores auxiliares. Não reli esses trechos; trate como lista de verificação para quando o app estiver rodando. Tudo o que reconferi (cerca de 90 trechos) batia com o que eles relataram.

**Estado e ciclo de vida**
- Controladores de texto descartados enquanto o diálogo ainda anima a saída: `acoes_page.dart:716,727`, `comunidade_page.dart:945,1654`, `perfil_page.dart:732-733`.
- `context.pop()` sem conferir se há rota para voltar: `registro_acao_page.dart:540`, `detalhes_desafio_page.dart:138`.
- A tela de detalhes do desafio guarda uma cópia e não escuta o `ChallengeService` (`detalhes_desafio_page.dart:22,31`); Progresso só escuta `UserProgressService` (`progresso_page.dart:61-65`).
- `perfil_page.dart:810-818`: uso do `context` externo depois de `await` e área de transferência sem `try/catch`. Sair da conta sem tratamento de erro (`:889-893`).
- `conquistas_page.dart:189,260`: divisão por zero se a lista de conquistas vier vazia.

**Navegação**
- `meu_historico_page.dart:68`: voltar sempre vai para Ações, mesmo vindo do Perfil.
- `progresso_page.dart:358`: "Ver histórico" usa `go` e perde o caminho de volta.
- `desafios_page.dart:732-746`: o botão "Participar" só abre os detalhes; o texto de prazo produz "1 dias".

**Layout (suspeitas de estouro em tela pequena ou fonte grande)**
- Linhas sem `Flexible`: `meu_historico_page.dart:332-373`, `comunidade_page.dart:1061-1121`, `registro_acao_page.dart:181-229`.
- Folhas e diálogos sem rolagem: `comunidade_page.dart:1168-1179,1288-1300,1422-1443`, `notificacoes_page.dart:312-408`, `recompensas_page.dart:596-740,752-806`, `perfil_page.dart:666-693`.
- Alturas fixas: lista de comentários com 180 (`comunidade_page.dart:1559-1560`), campo de busca com 48 (`acoes_page.dart:275`), filtros com 40 (`notificacoes_page.dart:104-105`, `recompensas_page.dart:103-104`).
- Selo de nível cortado com reticências em telas estreitas (`home_page.dart:161-197`).
- Espaço em branco fixo no fim das listas (`bottom: 88`, `96` ou `100`) em Início, Ações, Desafios, Comunidade e Recompensas.

**Acessibilidade**
- Botões só de ícone sem dica: `acoes_page.dart:575-581`, `registro_acao_page.dart:149-155`, `comunidade_page.dart:1634-1643`.
- Avatares decorativos que parecem botão: `meu_historico_page.dart:77-86`, `conquistas_page.dart:68-79`, `progresso_page.dart:92-103`.
- Textos de 9 e 10 px: `comunidade_page.dart:385,457,529,685,694,1047,1395,1472`, `home_page.dart:509,523,538`, `perfil_page.dart:362`, `notificacoes_page.dart:275,293`, `progresso_page.dart:570,611`.
- Indicador de carregamento branco sobre botão desabilitado claro: `login_page.dart:147-164`, `register_page.dart:201-218`, `forgot_password_page.dart:188-205,265-282`, `registro_acao_page.dart:508-518`, `detalhes_desafio_page.dart:449-452`.
- Telas de autenticação sem `autofillHints` e `textInputAction` no cadastro e na recuperação; faixa de erro sem anúncio para leitor de tela (`login_page.dart:241-279`).
- Cartões de categoria da tela inicial parecem botões e não fazem nada (`home_page.dart:629-636`, `:831-832`).

**Conteúdo fixo adicional**
- `detalhes_desafio_page.dart:184-185,364-378,424`: instruções sobre descartáveis e selo "Guardião sem Descarte" para qualquer desafio.
- `desafios_page.dart:211,331,411,547`: "Ritmo da Semana", "14kg de CO₂" e ícone de reciclagem para todo desafio.
- `comunidade_page.dart:1151-1166,1331-1347,1440`: endereços e horários escolhidos pelo nome, uma terceira iniciativa só na folha "Ver todas", promessa de registro de entrega pela cooperativa.
- `detalhes_desafio_page.dart:514-535`: "Compartilhar" copia texto e avisa "Link do desafio copiado!".

**Limpeza**
- `withOpacity`, que deve gerar aviso no analisador com o Flutter exigido: dezenas de ocorrências nas páginas.
- Funções que só repassam: `meu_historico_page.dart:47`, `home_page.dart:934-946`, `progresso_page.dart:742-755`; nome do mês copiado em `progresso_page.dart:22-38` e `meu_historico_page.dart:29-45`.
- `notificacoes_page.dart:190`: as duas cores da condição são o mesmo branco.
- Trechos repetidos candidatos a `lib/core/widgets/`, com as linhas indicadas pelos revisores:
  - cartão branco com sombra: `acoes_page.dart:786-796`, `registro_acao_page.dart:167-177`, `confirmacao_registro_page.dart:74-84`, `desafios_page.dart:362-372,592-602`, `detalhes_desafio_page.dart:166-176,250-260,329-340`, `meu_historico_page.dart:287-297`, `comunidade_page.dart:323-336,717-730,981-993`, `perfil_page.dart:201-214,323-335`, `progresso_page.dart:450-462,502-515`, `conquistas_page.dart:374-387,449-462`, `preferencias_page.dart:292-305`;
  - cartão de estatística: `comunidade_page.dart:427-466`, `home_page.dart:235-293,295-353`, `perfil_page.dart:314-369`, `progresso_page.dart:443-495`;
  - pílula de categoria ou de pontos: `acoes_page.dart:215-242,827-843,888-904`, `registro_acao_page.dart:184-228`, `desafios_page.dart:390-406,445-472,615-631,651-678`, `conquistas_page.dart:623-641`, `recompensas_page.dart:488-503`, `home_page.dart:42-78,162-196,394-424,663-690`;
  - barra de progresso arredondada: `desafios_page.dart:506-516`, `detalhes_desafio_page.dart:306-316`, `conquistas_page.dart:269-279,534-544`, `progresso_page.dart:659-667,726-736`, `comunidade_page.dart:576-586`, `home_page.dart:209-220`, `perfil_page.dart:455-465`;
  - barra superior com "Voltar": `registro_acao_page.dart:134-157`, `confirmacao_registro_page.dart:19-33`, `detalhes_desafio_page.dart:132-156`, `meu_historico_page.dart:59-88`, `register_page.dart:71-86`, `forgot_password_page.dart:99-114`, `conquistas_page.dart:45-67`, `notificacoes_page.dart:24-44`, `preferencias_page.dart:82-102`, `progresso_page.dart:69-91`;
  - botão principal com indicador: `login_page.dart:144-167`, `register_page.dart:198-221`, `forgot_password_page.dart:185-208,262-285`, `registro_acao_page.dart:504-534`, `detalhes_desafio_page.dart:436-485`;
  - campos de e-mail e de senha das três telas de autenticação: `login_page.dart:91-132`, `register_page.dart:132-181`, `forgot_password_page.dart:168-183,233-260`;
  - estado vazio: `acoes_page.dart:436-468`, `meu_historico_page.dart:150-213`, `notificacoes_page.dart:411-456`, `recompensas_page.dart:563-585`;
  - esqueleto de diálogo e de folha inferior: `comunidade_page.dart:905-916,1168-1223,1288-1323,1410-1421,1493-1543`, `perfil_page.dart:654-665,742-753,832-843,865-876`, `notificacoes_page.dart:312-317`, `preferencias_page.dart:396-401`, `recompensas_page.dart:589-595`.
