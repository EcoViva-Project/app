# Pontos de coleta de resíduos e recicláveis — São José do Rio Preto (SP)

Levantamento feito em **09/11/2026** para o mapa do EcoViva. O arquivo de dados é
`pontos-de-coleta-rio-preto.json` (264 registros, UTF-8, um array de objetos).

Regra seguida: entra no JSON só o que uma fonte responsável lista hoje como ponto de entrega,
com endereço. Campo que a fonte não informa fica `null`. O que apareceu em algum lugar mas não
pôde ser confirmado está listado na seção 7, fora do JSON.

**Nada foi conferido por telefone nem no local.** "Confiança alta" quer dizer que duas fontes
independentes concordam, e não que alguém foi até lá (ver seção 5).

## 1. Resumo

| | |
|---|---|
| Registros no JSON | 264 |
| Linhas lidas nas fontes | 336 (14 da Prefeitura e 322 das demais); 5 saíram por acesso restrito, as outras viraram 266 locais depois de juntar duplicatas, e 2 ficaram sem coordenada |
| Coordenadas dentro do município | 264 de 264 (conferidas contra o polígono oficial do município no OpenStreetMap, não só contra a caixa de latitude/longitude) |
| Precisão "exata" | 198 |
| Precisão "rua" | 65 |
| Precisão "bairro" | 1 |

## 2. Método

1. **Coleta.** Cada fonte foi lida na forma mais direta que ela oferece: a página dos Pontos de
   Apoio da Prefeitura (texto e o mapa oficial embutido, em KML), as listas públicas que alimentam
   os localizadores das entidades de logística reversa (Green Eletron, Recicla Pilhas, Reciclus,
   LogMed, Reciclanip, Óleo do Bem), o site da Cooperlagos e a Overpass API do OpenStreetMap.
   Nenhuma página trouxe instruções dirigidas a robôs; nenhum dado pessoal foi enviado a serviço algum.
2. **Limpeza.** Fiquei só com as linhas de São José do Rio Preto-SP. Os localizadores devolvem
   também Rio Preto da Eva-AM, Formosa do Rio Preto-BA, Mirassol e Bady Bassitt; essas linhas saíram.
3. **Duplicatas.** O mesmo estabelecimento no mesmo endereço virou um registro só, com todos os
   materiais em `materiais`. Lojas diferentes dentro do mesmo shopping continuam separadas, porque
   cada uma tem o seu coletor (ver seção 5).
4. **Coordenadas.** Em ordem de preferência:
   - Pontos de Apoio: coordenada do mapa oficial da Prefeitura, conferida com os polígonos
     "Ponto de Apoio" do OpenStreetMap (todos a menos de 45 m).
   - Endereço consultado no Nominatim (1 requisição por segundo, User-Agent `EcoViva-estudo/1.0`).
     Quando o OpenStreetMap tem o número do imóvel, a coordenada é a dele ("exata").
   - Quando o OpenStreetMap não tem o número, usei a coordenada que o próprio localizador da fonte
     publica, mas só depois de conferir que ela cai na via do endereço (distância até o traçado da
     via no OpenStreetMap, no máximo 120 m, ou busca reversa no Nominatim). Coordenadas de fonte
     fora do município ou longe da via foram descartadas.
   - Escolas, mercados e entidades sem número mapeado: busca pelo nome no Nominatim, aceita apenas
     se o estabelecimento achado fica na via do endereço (18 casos). Três exceções, todas escolas
     municipais de nome inconfundível e ditas em `observacoes`: em duas a via do endereço não existe
     no OpenStreetMap, e uma fica a 266 m da estrada rural do endereço.
   - Sem nada disso: precisão "rua". O ponto fica no trecho da via mais próximo do centro do bairro
     informado, ou é estimado pelos números vizinhos de posição conhecida na mesma via (8 casos).
   - "bairro": centro do bairro (1 caso).
   O campo `observacoes` de cada registro termina dizendo de onde veio a coordenada.
5. **Validação.** O JSON abre sem erro, tem exatamente os 17 campos combinados em todos os
   registros, não tem caractere de acentuação quebrado e todas as coordenadas caem dentro do
   polígono do município.

### De onde vieram as coordenadas

| Origem | Registros | Precisão |
|---|---|---|
| Nominatim, com o número do imóvel achado no OpenStreetMap | 96 | exata |
| Localizador da própria fonte, conferido com a via no OpenStreetMap | 60 | exata |
| Estabelecimento achado pelo nome no OpenStreetMap | 21 | exata |
| Mapa oficial dos Pontos de Apoio (Prefeitura) | 14 | exata |
| Shopping Iguatemi (polígono do shopping no OpenStreetMap) | 5 | exata |
| Link de mapa publicado no site da Cooperlagos | 2 | exata |
| Trecho da via mais próximo do centro do bairro | 36 | rua |
| Ponto da via devolvido pelo Nominatim | 19 | rua |
| Estimada pelos números vizinhos na mesma via | 8 | rua |
| Ponto do Recicla Pilhas (localizador pouco preciso) | 2 | rua |
| Centro do bairro | 1 | bairro |

## 3. Fontes consultadas (todas em 09/11/2026)

| Fonte | Endereço | O que rendeu |
|---|---|---|
| Prefeitura — Pontos de Apoio | https://www.riopreto.sp.gov.br/pontodeapoio | 14 Pontos de Apoio abertos, materiais aceitos, horário; página atualizada em 26/01/2026 |
| Prefeitura — mapa oficial dos Pontos de Apoio | Google My Maps embutido na página acima | coordenadas dos 14 pontos (o mapa ainda mostra pontos fechados) |
| Prefeitura — Secretaria do Meio Ambiente e Urbanismo | https://www.riopreto.sp.gov.br/secretarias/meio-ambiente | coleta seletiva (Cooperlagos e ARES), pneus, telefones |
| Prefeitura — Secretaria de Serviços Gerais | https://www.riopreto.sp.gov.br/secretarias/servicos-gerais | Coordenação do Programa de Reciclagem (sem endereços) |
| Cooperlagos | https://cooperlagosrp.com.br/ | 2 endereços, telefone, horário |
| Green Eletron — eletroeletrônicos | https://greeneletron.org.br/onde-descartar/ | 23 pontos (9 da Green Eletron e 14 marcados como ABREE) |
| Green Eletron — Recicla Pilhas | https://sistema.reciclelog.com.br/info/green | 55 linhas de pilhas e baterias |
| Reciclus — lâmpadas | https://reciclus.org.br/onde-descartar/ | 17 pontos |
| LogMed — medicamentos | https://logmed.org.br/onde-descartar | 82 linhas (1 descartada, 2 repetidas) |
| Reciclanip — pneus | https://www.reciclanip.org.br/pontos-de-coleta/coleta-no-brasil/ | 5 pontos |
| Óleo do Bem — óleo de cozinha | https://oleodobem.com/#coleta | 139 pontos na cidade |
| OpenStreetMap — Overpass API | https://overpass-api.de/ | polígonos dos Pontos de Apoio, traçado das vias, limite do município; quase nenhum ponto de reciclagem próprio |
| OpenStreetMap — Nominatim | https://nominatim.openstreetmap.org/ | geocodificação |

Consultadas sem resultado aproveitável:

- **ABREE** (https://abree.org.br/pontos-de-recebimento): o localizador exige cadastro e login. Os 14
  pontos ABREE da cidade vieram pelo localizador da Green Eletron, que os lista marcados como ABREE.
  Pode haver pontos ABREE que só aparecem no site da própria ABREE.
- **CETESB**, lista de PEVs de embalagens (PDF de 2020): o servidor recusou o acesso (HTTP 403).
- **Portal da Prefeitura**, busca de notícias: não há busca aberta a programas; li só as páginas acima.
- **Buscas na web** por vidro, tampinhas, lacres, medicamentos em UBS e eletrônicos municipais: não
  trouxeram nenhum ponto com endereço em Rio Preto.
- **Descarte Consciente**: não consultado em detalhe; o LogMed é o programa setorial e já lista as
  mesmas redes de farmácia.

## 4. Contagens

### Por tipo

| tipo | registros |
|---|---|
| oleo_cozinha | 118 |
| medicamentos | 51 |
| entrega_voluntaria | 43 |
| ecoponto_municipal | 14 |
| eletronicos | 13 |
| pilhas_baterias | 11 |
| lampadas | 9 |
| pneus | 3 |
| cooperativa | 2 |
| vidro | 0 |
| outros | 0 |

### Por material aceito (um registro pode aceitar vários)

| material | pontos |
|---|---|
| óleo de cozinha usado | 119 |
| medicamentos vencidos ou em desuso (e embalagens) | 79 |
| pilhas e baterias portáteis | 53 |
| eletroeletrônicos de pequeno porte | 24 (mais a sede da Cooperlagos) |
| lâmpadas fluorescentes | 17 |
| papel, plástico, metal e vidro | 15 (14 Pontos de Apoio e a sede da Cooperlagos) |
| entulho, podas, móveis, eletrodomésticos, madeira | 14 (Pontos de Apoio) |
| pneus inservíveis | 5 |

### Por confiança e por precisão

| confianca | registros | | precisao_coordenada | registros |
|---|---|---|---|---|
| alta | 127 | | exata | 198 |
| media | 135 | | rua | 65 |
| baixa | 2 | | bairro | 1 |

Campos vazios (`null`): `horario` em 243 registros, `telefone` em 150, `cep` em 26, `bairro` em 9.
As fontes simplesmente não publicam esses dados; só a Prefeitura, a Cooperlagos e parte do
localizador da Green Eletron informam horário.

## 5. Como ler os campos

- **`tipo`**: quando o local recebe um material só, o tipo é o do material. Quando recebe mais de um
  (por exemplo, farmácia com coletor de pilhas e de medicamentos), o tipo é `entrega_voluntaria` e a
  lista completa está em `materiais`. Para filtrar "onde descarto pilha", use `materiais`, não `tipo`.
- **`confianca`**:
  - `alta` — o estabelecimento aparece em duas fontes independentes: dois programas diferentes, ou um
    programa mais o OpenStreetMap (que tem o mesmo estabelecimento mapeado naquele endereço), ou, no
    caso dos Pontos de Apoio, a página da Prefeitura, o mapa oficial e o OpenStreetMap. Dos 127
    registros, 14 são Pontos de Apoio, 39 estão em duas fontes ou programas e 74 têm um programa mais
    o OpenStreetMap. Nesses 74, o OpenStreetMap confirma que o estabelecimento existe ali, não que ele
    recebe o material.
  - `media` — consta hoje na lista de uma única entidade responsável. Green Eletron (eletrônicos),
    Recicla Pilhas e os pontos marcados ABREE contam como uma entidade só, porque vêm do mesmo sistema.
  - `baixa` — há contradição ou falta identificação (2 registros, seção 8).
- **`precisao_coordenada`**: `exata` é no imóvel ou no lote; `rua` é na via certa, mas a posição ao
  longo dela pode estar errada (em avenidas longas, algumas centenas de metros); `bairro` é só o
  centro do bairro.
- **`responsavel`**: a entidade que responde pelo ponto (Prefeitura, programa de logística reversa ou
  cooperativa), não uma pessoa. Nomes de pessoas que as fontes publicam foram deixados de fora.
- **Shoppings**: 18 registros dividem 5 endereços (Riopreto Shopping 7, Iguatemi 5, Plaza Avenida 2,
  Cidade Norte 2 e um centro comercial na Av. José da Silva Sé com 2) e por isso têm coordenadas
  idênticas. Outros dois pares coincidem por estarem só no nível da rua. No mapa convém agrupar os
  marcadores.
- **Óleo de cozinha em escolas**: 91 dos 119 pontos de óleo ficam em escolas, creches e cursos. O
  programa os lista como pontos de coleta abertos, mas na prática funcionam em horário de aula e
  atendem sobretudo a comunidade escolar. O texto "instituição de ensino" em `observacoes` permite
  separá-los, se o app quiser mostrar só mercados, entidades e órgãos públicos.

## 6. Onde a cobertura ficou fraca

- **Vidro**: não achei nenhum ponto exclusivo de vidro. O material é aceito nos 14 Pontos de Apoio e
  na Cooperlagos, e por isso o tipo `vidro` ficou sem registros.
- **Cooperativas**: só a Cooperlagos tem endereço publicado. A Prefeitura cita uma segunda entidade
  (ARES), só com telefone.
- **Pneus**: 5 endereços (3 lojas, mais as duas unidades da Cooperlagos); um sexto ponto da
  Reciclanip ficou sem coordenada.
- **Eletrodomésticos grandes**: só os Pontos de Apoio declaram receber. Os coletores das lojas
  aceitam aparelhos de até 50 cm x 70 cm.
- **Lâmpadas**: a Reciclus cobre lâmpadas fluorescentes, em supermercados e lojas de material elétrico.
- **Medicamentos em unidades de saúde**: o site da Prefeitura não informa se UBS e farmácias
  municipais recebem medicamentos vencidos; só entraram farmácias privadas do LogMed.
- **Tampinhas, lacres, esponjas, cápsulas de café, isopor**: nenhuma fonte com endereço em Rio Preto.
- **Horários**: quase não há (ver seção 4).
- **OpenStreetMap como fonte de pontos**: a cidade tem só duas marcações `amenity=recycling`, sem
  detalhes; o OpenStreetMap serviu para conferir e localizar, não para descobrir pontos.

## 7. O que apareceu e não entrou no JSON

### Fechados ou fora da lista atual da Prefeitura

| Local | Situação |
|---|---|
| Ponto de Apoio Jardim Yolanda (Marginal Fernando M. Pierre, 500) | "fechado por tempo indeterminado", segundo a página oficial |
| Ponto de Apoio Jardim Conceição (Rua Cedral, 700) | "fechado em definitivo em 6/5/2024" |
| Fazenda Ambiental / Centro de Tratamento de Resíduos Verdes (Fazenda Iboruna) | "passa por melhorias e será reaberta" |
| Jardim Antunes (Rua Cosme e Damião com Rua Alberto Ricci) | está no mapa oficial e no OpenStreetMap, mas não na lista atual da página |
| Parque da Cidadania (Av. Américo Agrelli, 70) | está no mapa oficial, mas não na lista atual da página |

### Sem endereço publicado

- **ARES — Associação Riopretense de Educação e Saúde**: a Secretaria do Meio Ambiente a cita como
  entidade de catadores da coleta seletiva, com o telefone (17) 3224-0733, sem endereço.
- **Central de Reciclagem** (Coordenação do Programa de Reciclagem, Serviços Gerais): só o telefone
  (17) 3251-5122.

### Sem coordenada possível

- **JR Pneus** (Reciclanip) — Estrada Municipal José Domingues Netto, 7, CEP 15087-000. A estrada
  existe no OpenStreetMap, mas sem número nem bairro não há como posicionar.
- **Escola Municipal Carmen Nelita A. Vetorazzo** (Óleo do Bem) — Estrada Municipal Valdomiro Lopes
  da Silva, s/n, Fazenda Vista Alegre (zona rural). Mesma situação.

### Acesso restrito (lista do Óleo do Bem)

Pontos internos de empresa ou de condomínio residencial, deixados de fora por não atenderem o público:
Condomínio Reserva dos Guyras (Av. JK, 1890); Nutrirmais Refeições / Restaurante Rodobens e Rodobens
Veículos Comerciais Cirasa (Av. Mário Andreazza, 867); Rodobens Administradora de Consórcios
(Av. Murchid Homsi, 1404); Fibra Óptica (Av. Murchid Homsi, 2300).

### Só em fonte antiga ou só no OpenStreetMap

- Makro, Av. Floriano André Cabrera, 955: citado num texto da Green Eletron de 08/02/2022; não está
  mais no localizador.
- SESI, Av. Abílio Appoloni, 500 (Jardim Conceição): citado como ponto de óleo numa notícia de
  2021/2022; não está na lista atual do Óleo do Bem. O SESI da Av. Duque de Caxias está e entrou.
- Pão de Açúcar como ponto de entrega de embalagens (lista da CETESB de 2020, que não consegui abrir):
  as três lojas entraram só como pontos de pilhas.
- Endereços antigos da Cooperlagos (Av. Dr. Cenobelino de Barros Serra; Rua Independência, 3582), que
  aparecem em diretórios e documentos antigos.
- OpenStreetMap: "Fabrica Vadoco" (`amenity=recycling`, sem nenhum detalhe); "Ferro Velho São Paullo"
  (ferro-velho, fora do escopo); uma construção `amenity=waste_disposal` sem nome.

### Erros das próprias fontes

- LogMed: uma farmácia cadastrada como Rio Preto tem CEP e coordenada de São José dos Campos; ignorada.
- LogMed: a coordenada da Droga Raia do Shopping Iguatemi cai na região de Campinas; descartada.
- Green Eletron: a coordenada da Tramontina Store veio sem a vírgula decimal; descartada.
- Reciclus: duas lojas vêm com a coordenada genérica do centro da cidade; descartadas.
- Recicla Pilhas: as coordenadas caem na via certa, mas longe do imóvel (de 570 m a 1,4 km em sete
  dos casos que pude comparar com o número mapeado no OpenStreetMap); onde ele era a única
  referência, tratei como precisão de rua.
- Reciclanip: quatro dos cinco telefones estão com dígitos a mais ou são de preenchimento; ficaram `null`.

## 8. Registros com confiança baixa (estão no JSON)

- `ponto-de-coleta-de-pilhas-r-sao-paulo-951`: o Recicla Pilhas lista o posto com o nome de uma
  pessoa física, sem identificar o estabelecimento. O nome foi omitido.
- `cooperlagos-ponto-na-av-alfredo-antonio-de-oliveira`: o Óleo do Bem lista a Cooperlagos na
  Av. Alfredo Antônio de Oliveira, 1841 (Jardim Marajó), endereço que o site da cooperativa não cita.

## 9. Ressalvas

- **Verificado**: que cada ponto consta hoje na fonte indicada em `fonte_url`; que a via do endereço
  existe no OpenStreetMap (as exceções estão assinaladas em `observacoes`); que a coordenada cai nessa
  via e dentro do município; para 127 registros, que uma segunda fonte independente tem o mesmo
  estabelecimento ali.
- **Só o que a fonte afirma**: que o local recebe de fato o material, o horário, o telefone, e que a
  loja continua aberta. Redes de varejo fecham lojas sem que o localizador seja atualizado.
- **Endereços dos Pontos de Apoio**: a página da Prefeitura e o mapa da própria Prefeitura divergem em
  sete deles (por exemplo, Santo Antônio: "R. Kazutoshi Sakakibara, 953" na página e "Av. Orlando
  Canuto da Silva, 3.200" no mapa; o ponto fica a 33 m de uma via e a 22 m da outra). O JSON traz o
  endereço da página, com a redação arrumada ("/" virou "esquina com"), e cita o do mapa em
  `observacoes`. As coordenadas são as do mapa e conferem com o OpenStreetMap. O Castelinho é o único
  em que o OpenStreetMap não tem uma das ruas do endereço; ali a conferência foi pelo polígono do ponto.
- **Óleo nos Pontos de Apoio**: o Óleo do Bem lista 10 dos 14 Pontos de Apoio como pontos de óleo, mas
  a Prefeitura não cita óleo entre os materiais aceitos. Por isso o óleo não foi posto em `materiais`
  desses pontos, só mencionado em `observacoes`.
- **Junções feitas por inferência** (ditas em `observacoes`): Drogaria São Paulo da Rua Bernardino de
  Campos (3600 numa fonte, 3610 na outra); Droga Raia "Jardim Vivendas" (Av. José Munia, s/n, numa fonte;
  Av. Benedito Rodrigues Lisboa, 1920, na outra; a coordenada fica na esquina das duas avenidas); Leroy
  Merlin (números 404 e 501); "BIG" e Sam's Club no mesmo endereço.
- **Coordenadas de origem Google**: as dos 14 Pontos de Apoio vêm do mapa que a Prefeitura publica no
  Google My Maps; as 2 da Cooperlagos, do link de mapa do site dela.

## 10. Atribuição do OpenStreetMap

Parte das coordenadas, os nomes de vias e de bairros e toda a conferência de limites vêm do
OpenStreetMap, consultado pelo Nominatim e pela Overpass API.

> © colaboradores do OpenStreetMap. Dados disponíveis sob a Open Database License (ODbL) 1.0.
> https://www.openstreetmap.org/copyright

O app deve mostrar esse crédito onde o mapa ou a lista de pontos aparecer (por exemplo, "Dados de
localização © colaboradores do OpenStreetMap"). Se o JSON for publicado ou redistribuído, a parte
derivada do OpenStreetMap continua sob a ODbL, com atribuição e compartilhamento pela mesma licença.
