# ♻️ EcoViva — App

![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.7+-0175C2?logo=dart&logoColor=white)
![Material 3](https://img.shields.io/badge/Material-3-757575?logo=materialdesign&logoColor=white)
![go_router](https://img.shields.io/badge/go__router-16-4A90E2)
![License](https://img.shields.io/badge/license-academic-lightgrey)

Aplicativo **Flutter** (Android, iOS e web) do **EcoViva**: um clube de hábitos
sustentáveis para o bairro. A pessoa registra ações ecológicas, acumula
eco-pontos, sobe de nível, desbloqueia selos, participa de desafios coletivos e
compartilha dicas na comunidade.

- **API (Node/Express):** https://github.com/EcoViva-Project/backend
- **App:** https://github.com/EcoViva-Project/app

> O app precisa da API rodando para autenticar e carregar os dados.

---

## 📱 Telas

O app tem **16 rotas** (5 abas fixas + telas empilhadas + autenticação),
organizadas com `go_router` e `StatefulShellRoute`.

### Autenticação
| Rota | Tela | O que faz |
| --- | --- | --- |
| `/login` | Login | E-mail e senha; redireciona para `/inicio` |
| `/registro` | Registro | Nome, e-mail, senha e bairro |
| `/esqueci-senha` | Esqueci a senha | Solicita código de 6 dígitos e redefine a senha |

### Abas principais
| Rota | Tela | O que faz |
| --- | --- | --- |
| `/inicio` | Início | Saudação, eco-pontos, nível, meta de hábitos do mês, atividade da semana, desafio coletivo em destaque, categorias e atalho para registrar ação |
| `/acoes` | Ações | Catálogo local com 6 ações, busca, filtros por categoria, ordenação (relevância/pontos/A-Z), cards com pontos/litros, botão **Registrar** e envio de **sugestão** de ação |
| `/desafios` | Desafios | Desafios semanais e coletivos, progresso, participantes, dias restantes e ação de entrar |
| `/comunidade` | Comunidade | Feed de publicações (criar, curtir, comentar, excluir a própria), ações coletivas do bairro e campanhas |
| `/perfil` | Perfil | Dados da conta, estatísticas, metas, bairro, privacidade e atalhos |

### Telas empilhadas
| Rota | Tela | O que faz |
| --- | --- | --- |
| `/registro-acao` | Registro de ação | Quantidade (1–50) e observações antes de confirmar |
| `/confirmacao-registro` | Confirmação | Pontos ganhos, litros economizados e novos selos |
| `/meu-historico` | Meu histórico | Lista de ações registradas |
| `/detalhes-desafio` | Detalhes do desafio | Descrição, progresso, passos e recompensa |
| `/progresso` | Progresso | Eco-pontos, ações, dias ativos, atividade da semana, ações por categoria e desafios em andamento |
| `/conquistas` | Conquistas | 10 selos com filtros **Todas / Desbloqueadas / Em progresso** |
| `/preferencias` | Preferências | Notificações push, lembretes, resumo semanal, metas, ranking e compartilhamento |
| `/notificacoes` | Notificações | Lista, marcar como lida, marcar todas, excluir e navegar para a tela relacionada |

---

## 🧰 Tecnologias

| Pacote | Versão | Uso |
| --- | --- | --- |
| **Flutter** | Dart `^3.7.0` | UI multiplataforma |
| **go_router** | `^16.2.1` | Rotas, shell com abas e redirect de autenticação |
| **http** | `^1.6.0` | Cliente HTTP da API |
| **shared_preferences** | `^2.5.6` | Persistência do token e do usuário |
| **cupertino_icons** | `^1.0.8` | Ícones |
| **flutter_lints** | `^5.0.0` | Regras de lint (dev) |
| **flutter_test** | SDK | Testes de widget/unidade (dev) |

**Fonte:** Plus Jakarta Sans (400/500/600/700), embarcada em `assets/fonts/`.
**Tema:** Material 3, paleta verde-sálvia/creme definida em
`lib/core/theme/app_colors.dart` (baseada no design system em
`design-reference/design-system/DESIGN.md`).

> `provider` está declarado no `pubspec.yaml`, mas o código atual usa
> `ChangeNotifier` + `AnimatedBuilder` diretamente.

---

## 🏗️ Arquitetura

- **Feature-first:** cada domínio em `lib/features/<feature>/presentation/pages`.
- **Serviços singleton** (`ChangeNotifier`) em `lib/core/services`: auth,
  sessão, progresso, conquistas, histórico, desafios, comunidade,
  notificações.
- **`ApiClient`** único, com `baseUrl` vinda de `ECO_API_URL` e token Bearer
  injetado em todas as requisições.
- **`AuthService`** hidrata os demais serviços após login e limpa tudo no logout.
- **Navegação:** `GoRouter` com `redirect` — rotas protegidas caem em `/login`
  quando não há token.

```txt
eco-app/
├── assets/
│   ├── fonts/PlusJakartaSans/
│   └── images/                 # logo e ícone da folha
├── lib/
│   ├── app/app.dart            # rotas, shell de abas e redirect
│   ├── core/
│   │   ├── services/           # api_client, auth, sessão, progresso, etc.
│   │   ├── theme/              # cores, tipografia e ThemeData
│   │   └── widgets/            # header de página, círculo de status
│   ├── features/               # 14 features (auth, inicio, acoes, ...)
│   └── main.dart
├── test/                       # 3 arquivos de teste
├── web/                        # suporte web (manifest + ícones)
├── dart-define.example.json
├── pubspec.yaml
└── README.md
```

---

## 🚀 Como rodar

### Pré-requisitos
- **Flutter 3.29+** (Dart `^3.7`)
- API do EcoViva rodando (`https://github.com/EcoViva-Project/backend`)

### Passos

```bash
flutter pub get

# apontando para a API local
flutter run --dart-define=ECO_API_URL=http://127.0.0.1:3000/api
```

Ou use o arquivo de exemplo:

```bash
cp dart-define.example.json dart-define.json
flutter run --dart-define-from-file=dart-define.json
```

### URLs por plataforma

| Onde roda | `ECO_API_URL` |
| --- | --- |
| Desktop/web/iOS Simulator | `http://127.0.0.1:3000/api` |
| Emulador Android | `http://10.0.2.2:3000/api` |
| Celular físico | `http://<IP-da-máquina>:3000/api` (mesma rede Wi-Fi) |

### Conta de demonstração

Depois de rodar `npm run seed` na API:

| Campo | Valor |
| --- | --- |
| E-mail | `clara@eco.app` |
| Senha | `eco1234` |

### Configuração

| Variável | Obrigatória | Default | Descrição |
| --- | --- | --- | --- |
| `ECO_API_URL` | não | `http://127.0.0.1:3000/api` | Base URL da API, via `--dart-define` |

O app não usa arquivo `.env` (Flutter não lê `.env` nativamente).
`dart-define.example.json` é apenas um template para
`--dart-define-from-file`; `dart-define.json` é ignorado pelo Git.

---

## 🧪 Testes e qualidade

```bash
flutter test      # 3 arquivos: navegação de notificações,
                  # progresso/conquistas e responsividade
flutter analyze   # análise estática
```

Os testes usam `SharedPreferences.setMockInitialValues` e o helper
`AuthService.debugSignIn()` para montar o app sem a API.

---

## 📦 Build

```bash
# Web
flutter build web --dart-define=ECO_API_URL=https://api.exemplo.com/api
# saída em build/web

# Android (APK)
flutter build apk --release --dart-define=ECO_API_URL=https://api.exemplo.com/api
```

---

## ⚠️ Limitações e próximos passos

- Depende 100% da API; não há modo offline nem cache de respostas.
- O catálogo de ações é **embutido no app** (`acoes_page.dart`), não vem de
  `GET /api/actions`. Os IDs (1–6) precisam coincidir com o seed do backend para
  que o registro funcione.
- Token salvo em `shared_preferences` (não é armazenamento seguro/criptografado).
- Apenas tema claro e interface em PT-BR.
- Sem CI/CD, testes de integração ou golden tests.
- `provider` declarado sem uso; `cupertino_icons` idem.
- Sugestões de ação são apenas um diálogo local (não persistem no backend).
- Melhorias naturais: `flutter_secure_storage`, modo offline, i18n,
  acessibilidade (semântica/contraste) e testes E2E.

---

## 👨‍💻 Créditos

Projeto acadêmico/comunitário **EcoViva** — app em Flutter com Material 3 e
design system próprio (verde-sálvia, creme e dourado).
