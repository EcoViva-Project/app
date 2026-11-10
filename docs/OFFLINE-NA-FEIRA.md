# EcoViva — funcionar sem internet na feira

> Os arquivos `.apk` citados neste guia não ficam no repositório. Cada versão pode ser recompilada a partir da etiqueta correspondente (`feira-v4`, `feira-v6`, `feira-v7`), com `flutter build apk --release`.

Feira: quarta-feira, 11/11/2026. Celulares: Android.

> **Situação em 10/11 (terça), à noite: versão congelada.** A versão da feira é o **v7**, em `EcoViva-feira.apk` (cópia numerada `EcoViva-feira-v7.apk`). Você testou esse mesmo arquivo no celular da feira (Motorola Edge 60 Neo, Android 15) e aprovou: "testei a v7 e ta tudo otimo brilhando".
>
> O v7 tem o mapa leve, o seu ícone no lugar certo pela localização do celular, a foto de comprovação, o aviso de demonstração antiga, o impacto traduzido e a privacidade do perfil funcionando.
>
> Versões de volta, guardadas na mesma pasta: `EcoViva-feira-v6.apk` e `EcoViva-feira-v4.apk`.
>
> **Na quarta de manhã o próprio app lembra:** ao abrir, o Início avisa que os dados da demonstração são de outro dia. Toque em "Atualizar agora". Veja "No dia".

## As opções estudadas

| Opção | Como funciona | Vantagens | Desvantagens | Custo |
|---|---|---|---|---|
| **A. Banco no próprio celular** | As regras da API rodam dentro do app, sobre um banco SQLite gravado no aparelho | Não depende de rede, notebook nem roteador; abre instantâneo; cada celular é independente | Os dados ficam em cada aparelho (a comunidade não é compartilhada entre celulares); as regras passam a existir em dois lugares (servidor e app) e precisam ser mantidas iguais | Médio: portar as regras para o app (feito) |
| B. API no notebook, celulares no Wi-Fi local | O notebook roda a API e os celulares acessam pelo Wi-Fi de um roteador ou de um celular | Quase nenhum código novo; todos os celulares enxergam os mesmos dados | Um ponto único de falha (notebook, rede, firewall do Windows); o endereço do notebook muda a cada rede; ambiente de feira costuma ter Wi-Fi ruim | Baixo em código, alto em risco no dia |
| C. API embutida no celular | Empacotar o servidor Node dentro do app Android | Reaproveita o servidor inteiro | Pesado e frágil no Android; difícil de empacotar e testar | Alto; não cabe no prazo |
| D. Offline com sincronização | O app grava localmente e envia ao servidor quando houver rede | É o melhor para um produto real | Fila de envio, conflitos e muita lógica nova | Muito alto; fica como evolução futura |

## Recomendação: opção A

Para uma apresentação de poucos minutos, o que importa é o app abrir e responder sempre. A opção A tira da frente tudo o que costuma falhar em feira: Wi-Fi, notebook, endereço de rede.

O modo online continua existindo. A escolha é feita na hora de gerar o app:

| Modo | Como gerar | Para quê |
|---|---|---|
| Local (padrão) | `flutter build apk --release` | Feira e demonstrações: tudo no aparelho |
| Online | `flutter build apk --release --dart-define=ECO_MODE=online --dart-define=ECO_API_URL=http://<endereço>:3100/api` | Uso com o servidor `eco-backend` |

## Como o modo local funciona

- As telas e os serviços do app são os mesmos nos dois modos. Só muda o "transporte": no modo local, cada chamada que iria para a rede é atendida por uma API escrita em Dart dentro do app (`lib/core/local/local_api.dart`), com as mesmas rotas e os mesmos formatos da API do servidor.
- Os dados ficam em um banco **SQLite** no aparelho (`ecoviva.db`, na pasta de dados do app), com as mesmas tabelas do servidor. Tudo persiste ao fechar e abrir o app.
- Se o SQLite não abrir em algum aparelho, o app passa sozinho a gravar no armazenamento simples do Android, para a apresentação não parar.
- Na primeira abertura o app cria a conta de demonstração, com cerca de nove semanas de histórico gerado pelas próprias regras (teto semanal, limites, desafios, conquistas, cupons). O histórico é relativo ao dia em que o app é aberto pela primeira vez.
- Junto com ela são criados 18 moradores fictícios em bairros reais de São José do Rio Preto, com duas semanas de ações. É deles que saem os números da comunidade (vizinhos ativos, ações de hoje e da semana, meta coletiva, ranking). Esses números sobem quando você registra uma ação na frente do visitante.
- Os 264 pontos de coleta reais de Rio Preto vão embutidos no app, com distância calculada a partir da região do bairro do usuário.
- O fundo do mapa da comunidade (ruas principais, rios e lagos) vai pronto dentro do app, em imagens desenhadas pelo próprio projeto com os dados do OpenStreetMap. Nada é baixado na hora. Por cima das imagens o app coloca os nomes dos bairros, os pontos de coleta e os vizinhos.
- A política do OpenStreetMap não permite embutir as imagens deles para uso sem internet. Por isso as imagens são desenho do projeto, feito a partir dos dados (que podem ser usados com o crédito). O crédito "© colaboradores do OpenStreetMap" aparece na tela.
- **Restaurar a demonstração:** Perfil → "Restaurar demonstração" apaga os dados do aparelho e recria tudo. Use entre uma apresentação e outra.

Conta de demonstração: `clara@eco.app`, senha `eco1234`. Na tela de entrada há um botão que entra direto com ela. Código dos parceiros para conferir cupons: `1234`.

O que **não** funciona no modo local, por definição:
- a comunidade não é compartilhada entre celulares (cada aparelho tem as próprias publicações);
- uma conta criada em um celular não existe nos outros;
- não há envio de e-mail (na recuperação de senha, o código aparece na própria tela).

## Plano B: dispensado

Em 09/11 você decidiu que não precisa de plano extra no computador. A feira depende só do celular com o app instalado.

A pasta `plano-b` (o app numa janela do computador) chegou a ficar pronta e foi testada neste computador, mas **não faz parte do plano da feira e não é mais atualizada**: ela tem a versão antiga do mapa. Pode ser apagada.

A opção de rodar a API no notebook com os celulares no Wi-Fi (opção B da tabela) também fica de fora: exige rede estável e o endereço do notebook muda de uma rede para outra.

## Passo a passo: instalar nos celulares

1. O arquivo é `EcoViva-feira.apk`.
2. Passe o arquivo para o celular: cabo USB (copiar para a pasta Download), ou enviar para você mesmo por um aplicativo de mensagens, e-mail ou Google Drive, ou "Compartilhar por proximidade".
3. No celular, abra o arquivo (aplicativo "Arquivos" → Download → `EcoViva-feira.apk`).
4. O Android vai avisar que a instalação de fontes desconhecidas está bloqueada. Toque em **Configurações**, ative **Permitir desta fonte** e volte.
5. Toque em **Instalar**. Se o Play Protect perguntar, escolha **Instalar mesmo assim** (o app não está na loja, por isso o aviso).
6. Abra o **EcoViva**.

## Teste que só você pode fazer (em cada celular)

Com o celular em **modo avião**:

1. Abrir o app e entrar com a conta de demonstração.
2. Tela inicial: conferir o saldo e a barra "Pontos de ações nesta semana" (o valor depende do dia; veja a tabela abaixo).
3. Ações → registrar "Apagar luzes em cômodos vazios": deve dar +5 pontos. Na terça e na quarta, destrava também a conquista "Guardião da Energia", com bônus de 80 pontos.
4. Registrar "Compostagem": deve dar +25 pontos. Na quarta, entram só 20 e aparece o aviso de que o teto da semana foi atingido.
5. Desafios → abrir "Desafio da compostagem" e entrar; conferir que a etapa do dia conta ao registrar a ação.
6. Comunidade → conferir os números do bairro e abrir o mapa; publicar, curtir e comentar.
7. Recompensas → resgatar um cupom do restaurante, abrir o cupom e conferir com o código `1234`.
8. **Fechar o app por completo e abrir de novo:** tudo deve continuar lá.
9. Perfil → "Restaurar demonstração": o app volta ao estado inicial.

Se algo falhar, anote em qual passo e em qual celular (marca e versão do Android).

### O que muda conforme o dia

A demonstração é criada em relação ao dia em que o app é aberto pela primeira vez, ou em que você toca em "Restaurar demonstração". Como cada ação tem limite por dia, a semana da Clara só chega perto do teto a partir da quarta. Isso é a regra funcionando, não um defeito.

| Dia em que a demonstração é criada | Semana começa em | "Apagar luzes" | "Compostagem" |
|---|---|---|---|
| Segunda, 09/11 | 50 de 400 | +5, sem conquista | +25, sem aviso do teto |
| Terça, 10/11 | 265 de 400 | +5 e conquista (+80) | +25, sem aviso do teto |
| **Quarta, 11/11 (feira)** | **375 de 400** | **+5 e conquista (+80)** | **+20 de 25 e aviso do teto** |

Na quarta, o resultado é o mesmo em qualquer horário: conferi das 7h às 21h, em teste automático (`eco-app/test/demo_por_dia_test.dart`).

Para ensaiar o roteiro completo antes de quarta, se quiser: nas configurações do celular, desligue a data automática, mude a data para 11/11/2026 e toque em "Restaurar demonstração". Ao terminar, volte a data para automática e restaure de novo. Eu não testei esse caminho em um celular.

## Reteste do mapa (feito em 09/11: aprovado)

Instale o `EcoViva-feira.apk` novo por cima do que já está no celular (os dados continuam lá) e confira:

1. Comunidade → abrir o mapa: a tela entra sem engasgo e o mapa aparece em até cerca de um segundo.
2. Arrastar o mapa com um dedo, devagar e rápido: o mapa acompanha o dedo.
3. Ampliar e afastar com dois dedos e com os botões + e −: sem travar.
4. Tocar em um grupo de pontos, em um ponto de coleta e em um vizinho: abre a ficha de cada um.
5. Ligar "Mostrar pontos em escolas" e repetir o arrastar.

O que mudou no mapa, para você saber o que olhar:
- o desenho das ruas e dos rios é o mesmo; agora ele vem em imagens prontas;
- ao ampliar bem (zoom máximo), as ruas ficam um pouco mais suaves nas bordas, porque a imagem do último nível é ampliada;
- tocar e segurar um marcador não mostra mais a etiqueta flutuante; o toque normal abre a ficha como antes.

O que eu medi aqui, no computador, com a tela do tamanho da do celular (não é o celular):

| | Antes | Depois |
|---|---|---|
| Arrastar | 19 quadros por segundo | 57 a 58 |
| Ampliar e afastar | 32 quadros por segundo | 60 (o máximo do teste) |
| Pior quadro ao arrastar | 117 ms | 33 ms |

Só o seu teste no aparelho diz se ficou bom de verdade. Se ainda engasgar, diga em qual dos passos.

## Teste do APK v5: localização no mapa (coberto pelo teste do v6)

Instale `EcoViva-teste-v5.apk` por cima do app que já está no celular. Os dados continuam lá.

1. **Primeira vez no mapa** (Comunidade → mapa): aparece uma explicação curta, "Mostrar onde você está?". Toque em "Usar minha localização". O Android pede a permissão: escolha "Durante o uso do app". Aparece "Localizando…" e o marcador "Você" vai para onde você está.
2. **Fechar o mapa e abrir de novo:** sem pergunta, o marcador se acerta sozinho.
3. **Tocar no marcador "Você":** abre uma ficha dizendo de onde vem a posição, com as opções.
4. **"Ajustar no mapa":** toque num ponto do mapa; o marcador vai para lá. Feche o app e abra: o ponto continua.
5. **"Usar minha localização"** na ficha: volta para a posição do celular.
6. **Sem sinal:** desligue a localização do celular (ou teste num lugar fechado) e abra o mapa. Em cerca de 10 segundos aparece uma frase explicando; o marcador fica na região do bairro e o mapa segue funcionando.
7. **Comunidade:** os pontos de coleta mais próximos mudam de ordem e a frase passa a dizer "a partir da sua localização".
8. **Bairro:** Perfil → editar → em "Bairro" digite "Jd Nazareth": aparece "Vamos usar o bairro Jardim Nazareth no mapa.". Digite um bairro inventado: aparece o aviso de que não foi encontrado.
9. **Fluidez:** arraste e amplie o mapa com o marcador "Você" na tela. Deve continuar como no v4.

Sobre a conta que você criou com o seu nome: ao abrir o v5, o app refaz a posição pelo bairro. Se o bairro digitado não for reconhecido, o mapa mostra um aviso com "Editar perfil" e "Usar minha localização".

O que saber antes:
- A posição exata fica só no aparelho e só você a vê. Os vizinhos continuam vendo a região do bairro.
- O GPS funciona sem internet, mas a primeira leitura pode demorar, e dentro de um pavilhão pode não vir. Por isso existe o ajuste tocando no mapa.
- Fora de São José do Rio Preto o app avisa que você está fora da área do mapa e mantém a região do bairro.
- Isto **não foi testado em aparelho**: os testes automáticos usam uma localização simulada.

## Teste do APK v6: foto de comprovação (feito: aprovado em 10/11)

Instale `EcoViva-teste-v6.apk` por cima do app que já está no celular.

**O v6 contém tudo do v5.** Se você não testou o v5, pode ir direto para o v6 e testar as duas coisas de uma vez: faça primeiro os passos 1 a 9 do "Teste do APK v5" (localização) e depois os passos abaixo (foto). Se algo falhar, diga se foi na parte da localização ou na da foto: se só a foto der problema, a versão da feira pode ser o v5.

1. Ações → escolha uma ação → **"Tirar foto"**: abre a câmera do celular, sem pedir permissão. Tire a foto e confirme; aparece a prévia na tela de registro. Registre: a confirmação mostra a miniatura e o selo "Com comprovação".
2. Em outra ação, **"Escolher da galeria"**.
3. Registre uma ação **sem foto**: tudo igual a antes.
4. **Meu histórico:** os registros com foto têm o selo; tocar nele abre a foto em tela cheia, com pinça para ampliar e botão de fechar.
5. **Feche o app e abra de novo:** as fotos continuam.
6. **Pontos:** a foto não muda os pontos de nenhuma ação.
7. Perfil → **"Restaurar demonstração":** as fotos que você tirou somem e o histórico volta com 3 registros de "Foto de exemplo".
8. O histórico continua rolando liso com várias fotos.

O que saber antes:
- A foto fica só neste celular. Ninguém confere a imagem nesta versão, e a tela diz isso. Conferência por outra pessoa e análise da imagem ficam como próximo passo.
- A foto é reduzida ao salvar, para não encher o armazenamento.
- Isto **não foi testado em aparelho**: os testes automáticos usam uma câmera simulada.

Se o v6 der qualquer problema, a versão da feira fica sendo o v5 (ou o v4, se o v5 também não agradar).

## Teste do APK v7 (feito: aprovado em 10/11)

Instale `EcoViva-teste-v7.apk` por cima do app que já está no celular. O v7 é o v6 mais quatro coisas. Nada do mapa, da câmera, da localização nem das regras de pontos foi mexido.

### O que mudou e como ver

1. **Aviso de demonstração antiga.** Abra o app na conta de demonstração. No Início aparece um aviso de que os dados da demonstração são de outro dia (o banco que está no celular ainda não guarda a data, então o aviso vem sem ela). Toque em "Atualizar agora" e confirme em "Restaurar". O app continua no Início, já na conta de demonstração, com os números de hoje e sem o aviso. Feche o app e abra de novo: o aviso não volta.
2. **Posição mantida ao restaurar.** No mapa, toque em "Você" → "Ajustar no mapa" → toque num ponto. Vá em Perfil → "Restaurar demonstração" e entre de novo. No mapa, o "Você" continua no ponto que você marcou, e a explicação da localização não aparece outra vez.
3. **Impacto traduzido.** No Início, o cartão "Água poupada" ganha uma linha, como "≈ 76 garrafões de 20 L". No Progresso há um cartão "Água poupada" com a frase completa: garrafões e dias de água para uma pessoa.
4. **Privacidade do perfil.** Em Perfil → Preferências → Privacidade, os dois textos agora dizem exatamente o que cada chave faz. Para ver funcionando é preciso duas contas no mesmo celular: na conta de demonstração, publique algo na Comunidade e desligue "Perfil visível para a comunidade"; saia, crie outra conta e abra a Comunidade. A publicação aparece como "Alguém do bairro", e no ranking a conta de demonstração também. Entrando de novo na conta de demonstração, ela se vê com o próprio nome.

### Passada rápida no que já funcionava

5. Registrar uma ação **com foto**; conferir o selo na confirmação e no histórico.
6. Abrir o **mapa**: arrastar, ampliar, tocar em um ponto de coleta; "Você" no lugar certo.
7. **Recompensas:** resgatar um cupom e conferir com o código `1234`.
8. Fechar o app por completo e abrir: tudo continua lá.

O que saber antes:
- O aviso do Início só aparece para a conta de demonstração, quando os dados são de outro dia. "Agora não" esconde o aviso até o app ser aberto de novo.
- Com o v7, **na quarta de manhã o próprio app lembra**: ao abrir, o Início mostra "Os dados de demonstração são de 10/11" e o botão "Atualizar agora" faz a restauração.
- Para guardar a data da demonstração entrou uma tabela nova no banco do aparelho, criada na abertura do app, do mesmo jeito que a tabela das fotos (que já funcionou no seu celular). Nada do que existe é alterado.
- A conta dos garrafões é exata (litros divididos por 20). A dos dias usa 110 litros por pessoa por dia, quantidade que a ONU considera suficiente; a tela diz isso.
- Os vizinhos fictícios da demonstração têm o perfil visível, então o que aparece no roteiro não muda.
- Isto **não foi testado em aparelho**.

Se o v7 der qualquer problema, a versão da feira continua sendo o v6.

## No dia

### Antes de sair de casa

- Celular carregado e, se possível, um carregador portátil.
- Confira que o app instalado é o da feira (v7): no Início, o cartão "Água poupada" tem a linha dos garrafões.

### Ao chegar, antes da primeira apresentação

1. **Localização do celular ligada** (o ícone de localização do Android). Modo avião pode ficar ligado: o GPS funciona sem internet.
2. **Abra o app na conta de demonstração.** O Início avisa que os dados da demonstração são de outro dia: toque em **"Atualizar agora"** e confirme em "Restaurar". Isso recria os dados com a data de hoje e deixa a semana em 375 de 400 pontos, que é o que faz o aviso do teto aparecer no roteiro. As fotos tiradas antes são apagadas; a posição no mapa é mantida. (Se o aviso não aparecer, os dados já são de hoje.)
3. **Abra o mapa uma vez.** Se o marcador "Você" não for para o lugar certo em cerca de 10 segundos (em pavilhão fechado o GPS pode não vir), toque no marcador "Você" → "Ajustar no mapa" → toque no ponto onde vocês estão. Fica guardado, inclusive depois de restaurar a demonstração.
4. Deixe o celular em modo avião, para nenhuma notificação atrapalhar.

### Roteiro de três minutos

1. **Início:** mostrar o saldo, o nível, a barra "Pontos de ações nesta semana" (375 de 400) e a água poupada em garrafões.
2. **Registrar "Apagar luzes em cômodos vazios" com foto:** "Tirar foto" de um interruptor ou de uma lâmpada, registrar. A confirmação mostra a foto com o selo "Com comprovação", +5 pontos e a conquista "Guardião da Energia" (+80).
3. **Registrar "Compostagem":** entram só 20 dos 25 pontos e aparece o aviso de que o teto da semana foi atingido. É aqui que se explica o limite semanal.
4. **Desafios:** mostrar um desafio avançando sozinho com as ações registradas.
5. **Comunidade:** números do bairro, meta coletiva e ranking. Abrir o **mapa**: mostrar o "Você" no lugar certo, tocar em um ponto de coleta e mostrar a distância. Dizer que os vizinhos só veem a região do bairro, nunca o endereço.
6. **Recompensas:** resgatar um cupom do restaurante, abrir o cupom e conferir com o código do parceiro (`1234`).
7. Se sobrar tempo: **Meu histórico** (tocar no selo e abrir a foto) e **Perfil → Preferências → Privacidade**.

### Entre uma apresentação e outra

- Para repetir o roteiro inteiro (conquista e teto), é preciso restaurar: **Perfil → "Restaurar demonstração"**. A posição no mapa continua onde estava.
- Se o tempo for curto, dá para apresentar sem restaurar: tudo funciona, só a conquista e o aviso do teto não se repetem.

### Se algo der errado

| O que acontecer | O que fazer |
|---|---|
| O marcador "Você" não sai da região do bairro | Tocar nele → "Ajustar no mapa" → tocar no ponto certo |
| A câmera não abrir ou a foto não aparecer | Registrar a ação sem foto; todo o resto do roteiro funciona igual |
| A barra da semana não estiver em 375 de 400 | Perfil → "Restaurar demonstração" (os dados eram de outro dia) |
| O app se comportar de forma estranha | Fechar por completo e abrir de novo; os dados ficam guardados |
| Nada resolver | Instalar por cima o `EcoViva-feira-v6.apk` (leve a pasta `apk` no próprio celular ou num pendrive) |
