# ufla-normas

Extensão do Quarto que gera em PDF o trabalho acadêmico (TCC, monografia,
dissertação, tese, relatório de estágio) nas normas da **Universidade Federal
de Lavras (UFLA)**: *Manual de normalização e estrutura de trabalhos
acadêmicos*, 6. ed. (2025).

Você preenche o cabeçalho YAML e escreve em Markdown. A extensão monta capa,
folha de rosto, ficha catalográfica, folha de aprovação, resumo, abstract,
indicadores de impacto, listas e sumário, e formata citações e referências
pela ABNT como o manual pede. Não é preciso saber LaTeX.

Versão atual: **2.0.0**. Quem vem da 1.x deve ler
[Migrar da versão 1.x](#migrar-da-versão-1x).

## Sumário

- [Começar](#começar)
- [Escreva aqui: o cabeçalho YAML](#escreva-aqui-o-cabeçalho-yaml)
- [Tipos de trabalho](#tipos-de-trabalho)
- [Citações: escrevo isto, sai aquilo](#citações-escrevo-isto-sai-aquilo)
- [O arquivo de referências (.bib)](#o-arquivo-de-referências-bib)
- [Figuras, tabelas, quadros, apêndices e listas](#figuras-tabelas-quadros-apêndices-e-listas)
- [Formato de artigos](#formato-de-artigos)
- [Trabalho em outro idioma](#trabalho-em-outro-idioma)
- [Mensagens da extensão e o que fazer](#mensagens-da-extensão-e-o-que-fazer)
- [Migrar da versão 1.x](#migrar-da-versão-1x)
- [In English](#in-english)
- [Licença e créditos](#licença-e-créditos)

## Começar

### Requisitos

- [Quarto](https://quarto.org) 1.4 ou mais novo.
- Uma distribuição LaTeX com **LuaLaTeX** e a fonte **TeX Gyre Termes**
  (equivalente à Times):
  - **TinyTeX** (o LaTeX que o Quarto instala com `quarto install tinytex`):
    rode uma vez `tlmgr install tex-gyre`.
  - **MiKTeX**: instala os pacotes que faltarem na primeira renderização
    (deixe a instalação automática ligada).
  - **TeX Live** completo: já tem tudo.

### Criar o trabalho

Numa pasta vazia, no terminal:

```bash
quarto use template bonijoao/ufla-normas
```

O comando cria:

- `<nome-da-pasta>.qmd`: o seu trabalho, já com exemplos de tudo;
- `referencias.bib`: uma referência de exemplo de cada tipo comum;
- `imgs/grafico-exemplo.png`: a figura do exemplo;
- `_extensions/`: a extensão (não mexa).

Abra o `.qmd`, troque os textos entre aspas no cabeçalho e renderize (botão
**Render** no RStudio/Positron, ou `quarto render <nome-da-pasta>.qmd`). O
exemplo mostra um único aviso no terminal, o lembrete da versão final:

```
[ufla-normas] AVISO: Lembrete para a versão final: dissertações e teses precisam de folha de aprovação (defesa:), ficha catalográfica e indicadores de impacto.
```

É de propósito: o modelo não traz data de defesa, banca, ficha nem
indicadores de exemplo, para que nenhum dado inventado vá parar no PDF
entregue. Esses campos estão comentados no cabeçalho; preencha-os depois da
defesa (veja [Versão final](#versão-final)). Depois apague o texto de
exemplo e escreva o seu.

### Já tenho um .qmd

Instale só a extensão na pasta do trabalho:

```bash
quarto add bonijoao/ufla-normas
```

e use o formato no cabeçalho:

```yaml
format:
  ufla-normas-pdf: default
```

Para atualizar depois, rode `quarto add bonijoao/ufla-normas` de novo. Para
ficar na versão antiga: `quarto add bonijoao/ufla-normas@v1.0.0`.

## Escreva aqui: o cabeçalho YAML

Cabeçalho mínimo:

```yaml
---
tipo: dissertacao
title: "Título do trabalho"
author: "Nome Completo do Autor"
ano: "2026"
curso: "Agronomia/Fitotecnia"
orientador: "Prof. Dr. Nome do Orientador"
abstract: |
  Resumo em um parágrafo, de 150 a 500 palavras.
keywords: [Palavra um, Palavra dois, Palavra três]
abstract-en: |
  Abstract in one paragraph.
keywords-en: [Word one, Word two, Word three]
bibliography: referencias.bib
format:
  ufla-normas-pdf: default
---
```

Os nomes dos campos não têm acento (`genero`, `titulo-traduzido`). Campo com
nome errado gera aviso com sugestão (veja [mensagens](#mensagens-da-extensão-e-o-que-fazer)).

### Identificação

| Campo | Para que serve | Exemplo |
|---|---|---|
| `tipo` | Tipo de trabalho; define a nota descritiva (veja [Tipos](#tipos-de-trabalho)) | `dissertacao` |
| `title` | Título (a capa põe em maiúsculas) | `"Modelagem da produtividade do café"` |
| `subtitle` | Subtítulo, se houver | `"um estudo no sul de Minas"` |
| `author` | Nome completo | `"Ana Paula Souza"` |
| `ano` | Ano de depósito | `"2026"` |
| `curso` | Curso de graduação ou programa de pós-graduação | `"Agronomia/Fitotecnia"` |
| `area-concentracao` | Área de concentração (opcional) | `"Produção Vegetal"` |
| `orientador` ou `orientadora` | Nome; `orientadora` já escreve "Orientadora" | `"Prof. Dr. Nome"` |
| `orientador-genero` | `f` ou `m`, para escolher o rótulo usando `orientador` | `f` |
| `coorientador` ou `coorientadora` | Opcional | `"Profa. Dra. Nome"` |
| `coorientador-genero` | `f` ou `m` | `m` |
| `genero` | `f` ou `m`: "apresentada"/"apresentado" na nota descritiva. O `tipo` já escolhe; use só para mudar | `m` |
| `tipo-trabalho` | Texto livre que troca o nome do trabalho na nota descritiva (ex.: formatos alternativos) | `"Produto técnico"` |
| `titulo-pretendido` | Troca o título obtido (ex.: "Mestra") | `"Mestra"` |
| `instituicao` | Padrão: `Universidade Federal de Lavras` | |
| `cidade` | Padrão: `Lavras-MG` | |

### Resumos

| Campo | Para que serve |
|---|---|
| `abstract` | Resumo em português, um parágrafo, 150 a 500 palavras |
| `keywords` | Palavras-chave: `[Café, Produtividade, Regressão]` |
| `abstract-en` | Abstract em inglês |
| `keywords-en` | Keywords |

### Versão final

Nada disto bloqueia o rascunho. Em dissertação e tese, enquanto faltar algum,
o terminal mostra um lembrete; o PDF sai normalmente.

No modelo do `quarto use template`, estes campos vêm **comentados** (com `#`
no começo da linha), sem valores de exemplo. Depois da defesa, apague o `#`
de cada linha e preencha com os dados reais:

- `defesa` e `banca-*`: a data e os membros da banca;
- `ficha-catalografica: true` e `fc-*`: copie da ficha que o sistema da
  [Biblioteca Universitária](https://bibliotecauniversitaria.ufla.br/) gera;
  não invente esses valores;
- `indicadores-impacto-texto` e `impact-indicators-texto`: o texto pedido
  pela Resolução PRPG n. 012/2024.

Com tudo preenchido, o lembrete some.

| Campo | Para que serve |
|---|---|
| `defesa` | Data da defesa; com ela sai a folha de aprovação. Ex.: `"20 de março de 2026"` |
| `banca-um-nome`, `banca-um-inst` … `banca-quatro-nome`, `banca-quatro-inst` | Membros da banca e instituição (até quatro) |
| `ficha-catalografica` | `true` para incluir a ficha |
| `fc-autor-sobrenome`, `fc-autores`, `fc-tipo`, `fc-catalogacao`, `fc-classificacao`, `fc-ilust` | Dados da ficha, como a Biblioteca Universitária fornece |
| `indicadores-impacto-texto` | Página INDICADORES DE IMPACTO (Resolução PRPG n. 012/2024) |
| `impact-indicators-texto` | Página IMPACT INDICATORS |

### Elementos opcionais

| Campo | Para que serve |
|---|---|
| `errata` | Página ERRATA |
| `dedicatoria` | Dedicatória (sem título) |
| `agradecimentos` | Página AGRADECIMENTOS |
| `epigrafe`, `epigrafe-autor` | Epígrafe e sua autoria |
| `lof`, `lot`, `loq` | `true` para LISTA DE FIGURAS, DE TABELAS, DE QUADROS |
| `siglas` | LISTA DE ABREVIATURAS E SIGLAS ([exemplo](#siglas-símbolos-e-glossário)) |
| `simbolos` | LISTA DE SÍMBOLOS |
| `glossario` | GLOSSÁRIO, depois das referências |
| `frente-verso` | `true` para impressão em frente e verso |

### Outras opções

| Campo | Para que serve |
|---|---|
| `bibliography` | Seu arquivo `.bib` (ou uma lista de arquivos), em qualquer pasta |
| `lang` | Idioma do texto: `pt-BR` (padrão), `en`, `es` ([outro idioma](#trabalho-em-outro-idioma)) |
| `titulo-traduzido` | Título em português, quando `lang` não é português |
| `formato` | `texto-integral` (padrão) ou `artigos` ([formato de artigos](#formato-de-artigos)) |

As opções comuns do Quarto (`execute`, `fig-width`, `include-in-header`,
`keep-tex` etc.) continuam funcionando.

## Tipos de trabalho

O `tipo` escolhe a nota descritiva da folha de rosto e da folha de aprovação,
como no Quadro 3.1 do manual. Exemplo com `tipo: dissertacao` e
`curso: "Agronomia/Fitotecnia"`:

> Dissertação apresentada à Universidade Federal de Lavras, como parte das
> exigências do Programa de Pós-Graduação em Agronomia/Fitotecnia, para a
> obtenção do título de Mestre.

| `tipo` | Começo da nota | Antes do curso | Título |
|---|---|---|---|
| `tcc` | Trabalho de conclusão de curso apresentado | Curso de | Bacharel |
| `monografia` | Monografia apresentada | Curso de | Bacharel |
| `monografia-licenciatura` | Monografia apresentada | Curso de | Licenciado |
| `especializacao` | Monografia apresentada | Curso de Pós-Graduação Lato Sensu em | Especialista |
| `dissertacao` | Dissertação apresentada | Programa de Pós-Graduação em | Mestre |
| `dissertacao-profissional` | Dissertação apresentada | Programa de Pós-Graduação do Mestrado Profissional em | Mestre |
| `tese` | Tese apresentada | Programa de Pós-Graduação em | Doutor |
| `relatorio-estagio` | Relatório de estágio supervisionado apresentado | Curso de | Bacharel |

Com `area-concentracao`, a nota ganha ", área de concentração em ...".
`dissertacao`, `dissertacao-profissional` e `tese` são stricto sensu: são
esses que recebem o lembrete da versão final.

Formatos alternativos (produto técnico, software etc.) usam o formato padrão:
escolha o `tipo` do nível e troque o nome com `tipo-trabalho` (e, se
preciso, `genero`).

## Citações: escrevo isto, sai aquilo

O manual usa só o sistema autor-data. Cite com a chave da referência no
`.bib` (o texto depois de `@article{`, `@book{` etc.). Resultados reais da
extensão:

| Escrevo | Sai no PDF |
|---|---|
| `[@silva_metodos_2023]` (4 ou mais autores) | (Silva et al., 2023) |
| `@souza_modelagem_2024` | Souza (2024) |
| `[@souza_modelagem_2024, p. 45]` | (Souza, 2024, p. 45) |
| `@souza_modelagem_2024 [p. 45]` | Souza (2024, p. 45) |
| `[ver @souza_modelagem_2024, p. 45]` | (ver Souza, 2024, p. 45) |
| `Souza [-@souza_modelagem_2024]` | Souza (2024) |
| `@costa_redes_2022` (2 autores) | Costa e Ferreira (2022) |
| `[@souza_modelagem_2024; @costa_redes_2022]` | (Costa; Ferreira, 2022; Souza, 2024) |
| `[@silva_a_2020; @silva_b_2020]` (mesmo autor e ano) | (Silva, 2020a, 2020b) |
| `[@silva_sd]` (sem ano) | (Silva, [s.d.]) |
| `[@chave_que_nao_existe]` | **[chave_que_nao_existe?]** em vermelho, com aviso no terminal |

Citação direta com mais de três linhas: comece cada linha com `>`. Sai com
recuo de 4 cm, letra menor, espaçamento simples e sem aspas.

```markdown
> Texto citado com mais de três linhas, sem aspas ...
> [@souza_modelagem_2024, p. 12].
```

A lista REFERÊNCIAS entra sozinha depois do último capítulo (e antes de
glossário, apêndices e anexos), só com as obras citadas, em ordem
alfabética. Você não precisa escrever um título "Referências"; se
escrever, ele não sai repetido (a extensão põe a lista no lugar dele). Para
pôr a lista num ponto exato, use:

```markdown
::: {#refs}
:::
```

Na lista, as entradas seguem a NBR 6023, por exemplo:

```
SOUZA, Ana Paula. Modelagem da produtividade do café. 2024. Dissertação
(Mestrado em Estatística e Experimentação Agropecuária) – Universidade
Federal de Lavras, Lavras, 2024.

INSTITUTO BRASILEIRO DE GEOGRAFIA E ESTATÍSTICA. Censo Demográfico 2022.
IBGE, 2023. Disponível em: https://www.ibge.gov.br/... Acesso em: 20 out. 2026.
```

## O arquivo de referências (.bib)

Qualquer `.bib` em BibTeX ou BibLaTeX funciona, com acentos normais (UTF-8).
O arquivo pode estar em qualquer pasta e o caminho pode ter espaço, acento ou
`_`:

```yaml
bibliography: referencias.bib
# ou vários:
bibliography:
  - referencias.bib
  - "capitulo 2/refs_extra.bib"
```

Não é preciso pôr `\textbf{}` nem `{\'e}` nos títulos: a extensão limpa
esses comandos e põe o negrito onde a ABNT manda. Instituição como autor vai
entre chaves duplas, para não virar "sobrenome, nome":
`author = {{Empresa Brasileira de Pesquisa Agropecuária}}`.

O `referencias.bib` do modelo tem um exemplo de cada tipo: livro, capítulo,
artigo, dissertação, tese, trabalho em evento, página da internet, lei,
norma técnica e conjunto de dados. Para tipos raros (partitura, documento
tridimensional etc.), use `@misc` com `howpublished` ou `note`.

Para "Disponível em ... Acesso em ...", preencha `url` e `urldate`
(`urldate = {2026-10-20}`). Em dissertação e tese, `type` define o texto do
nível: `type = {Dissertação (Mestrado em Estatística)}`. Sem `type`, sai
"Dissertação (Mestrado)" para `@mastersthesis` e "Tese (Doutorado)" para
`@phdthesis`.

### Exportar do seu gerenciador

- **Zotero**: clique com o botão direito na coleção → *Exportar coleção…* →
  formato *BibTeX* ou *BibLaTeX* → salve como `referencias.bib` na pasta do
  trabalho. Com o complemento [Better BibTeX](https://retorque.re/zotero-better-bibtex/),
  marque *Manter atualizado* (*Keep updated*): o `.bib` se atualiza sozinho
  quando você adiciona referências.
- **Mendeley Reference Manager**: selecione as referências → *Export…* (ou
  clique com o botão direito → *Export*) → *BibTeX (\*.bib)*.
- **Google Acadêmico**: clique em *Citar* (as aspas) abaixo do resultado →
  *BibTeX* → copie o texto e cole no fim do seu `referencias.bib`. Confira os
  dados: o Google costuma deixar o nome do periódico ou da instituição
  incompleto.
- **JabRef**: o arquivo do JabRef já é um `.bib`. Salve-o na pasta do
  trabalho, com codificação UTF-8.

## Figuras, tabelas, quadros, apêndices e listas

Tudo em Markdown. Título vai acima e fonte abaixo, em letra menor, como no
manual. Figuras, tabelas e quadros são numerados em sequência no trabalho
todo (Figura 1, Figura 2…).

### Figura

```markdown
![Produtividade média do cafeeiro.](imgs/grafico.png){#fig-produtividade fonte="Elaboração própria (2026)" width=80%}

A @fig-produtividade mostra ...      → "A Figura 1 mostra ..."
```

Em célula de código R ou Python, use `fig-fonte`:

````markdown
```{r}
#| label: fig-pontos
#| fig-cap: "Pontos"
#| fig-fonte: "Dados simulados (2026)"
plot(1:3)
```
````

### Tabela

```markdown
| Espaçamento | Produtividade |
|---|---:|
| 3,5 × 0,5 | 34,1 |

: Produtividade por espaçamento. {#tbl-espacamento fonte="Elaboração própria (2026)"}
```

Em célula de código, `tbl-cap` e `tbl-fonte`.

### Quadro

Quadro (texto em células) é um bloco `::: {#qdr-...}`. O título vem em
`quadro=` ou na última linha do bloco:

```markdown
::: {#qdr-conceitos quadro="Conceitos usados" fonte="Elaboração própria (2026)"}

| Conceito | Definição |
|---|---|
| Bienalidade | Alternância de safras altas e baixas |

:::

O @qdr-conceitos resume ...     → "O Quadro 1 resume ..."
```

Citações dentro de `fonte="..."` funcionam: `fonte="Adaptado de @costa_redes_2022"`
sai "Fonte: Adaptado de Costa e Ferreira (2022)."

### Apêndices e anexos

```markdown
# Roteiro da entrevista {#apx-roteiro .apendice}     → APÊNDICE A – ROTEIRO DA ENTREVISTA
# Lei de criação {.anexo}                            → ANEXO A – LEI DE CRIAÇÃO

Veja o @apx-roteiro.                                 → "Veja o Apêndice A."
```

Use título de nível 1 (`#`). Cada um abre página nova, entra no sumário e
fica sem número de seção; as subdivisões (`##`) ficam fora do sumário. As
referências sempre vêm antes deles.

### Siglas, símbolos e glossário

```yaml
siglas:                 # sai em ordem alfabética
  UFLA: Universidade Federal de Lavras
  ABNT: Associação Brasileira de Normas Técnicas
simbolos:               # sai na ordem escrita
  - "$\\alpha$": Nível de significância
  - "$\\beta$": Coeficiente angular
glossario:              # sai em ordem alfabética, depois das referências
  Bienalidade: Alternância de safras altas e baixas no cafeeiro.
```

### Caixas de destaque e outros recursos do Quarto

Caixas (`::: {.callout-tip}`), notas de rodapé, equações, código R/Python e
`include-in-header` funcionam normalmente.

## Formato de artigos

Para dissertação ou tese em formato de artigos (manual, Figura 3.23), use
`formato: artigos` e divida o texto em partes com títulos de nível 1:

```markdown
---
formato: artigos
---

# Primeira parte {.parte}

# Introdução
Texto da introdução geral [@silva_estatistica_2020].

# Segunda parte – Artigos {.parte}

# Modelagem da produtividade do café {.artigo nota="Artigo redigido conforme a NBR 6022 (ABNT, 2018)."}

## Introdução
Texto do artigo [@souza_modelagem_2024].

## Material e métodos
...

# Redes neurais e preços {.artigo csl="periodico.csl"}

## Introdução
...

# Terceira parte {.parte}

# Considerações finais
...

# Questionário aplicado {.apendice}
```

O que acontece:

- Cada `.parte` abre uma página com o título em maiúsculas. Título vazio
  (`# {.parte}`) recebe o nome sozinho: PRIMEIRA PARTE, SEGUNDA PARTE –
  ARTIGOS (quando tem artigos), TERCEIRA PARTE. `nota="..."` no título da
  parte vira nota de rodapé.
- Cada `.artigo` vira "ARTIGO 1 – TÍTULO". `nota="..."` vira nota de rodapé
  no título (por exemplo, a norma do periódico). As seções do artigo
  (`##`) são numeradas de novo a partir de 1 em cada artigo.
- No sumário entram as partes, os capítulos da primeira e da terceira parte
  e "ARTIGO n – TÍTULO", sem as seções internas dos artigos.
- **Onde ficam as referências:**
  - cada artigo tem sua lista REFERÊNCIAS no fim do artigo (ou onde você
    puser `::: {#refs}` dentro dele), só com o que o artigo cita;
  - a primeira parte, se tiver citações, ganha sua lista no fim dela;
  - o que é citado na terceira parte vai para a lista geral, antes dos
    apêndices e anexos.
- `csl="arquivo.csl"` no título de um artigo usa o estilo do periódico só
  naquele artigo (baixe o `.csl` em [zotero.org/styles](https://www.zotero.org/styles)
  e ponha na pasta do `.qmd`). Sem `csl=`, vale a ABNT.

## Trabalho em outro idioma

Para um trabalho redigido em inglês ou espanhol:

```yaml
lang: en                 # ou es
titulo-traduzido: "Título do trabalho em português"
```

- Capa, folha de rosto, ficha, folha de aprovação, resumos, listas e
  sumário continuam em português, como o manual manda.
- Na folha de aprovação, o título traduzido aparece entre parênteses abaixo
  do título original.
- Da INTRODUÇÃO em diante, rótulos e referências seguem o idioma do texto:

| | `pt` | `en` | `es` |
|---|---|---|---|
| Figura | Figura 1 | Figure 1 | Figura 1 |
| Tabela | Tabela 1 | Table 1 | Tabla 1 |
| Quadro | Quadro 1 | Chart 1 | Cuadro 1 |
| Fonte | Fonte: | Source: | Fuente: |
| Referências | REFERÊNCIAS | REFERENCES | REFERENCIAS |
| Apêndice | APÊNDICE A – | APPENDIX A – | APÉNDICE A – |
| Anexo | ANEXO A – | ANNEX A – | ANEXO A – |
| Glossário | GLOSSÁRIO | GLOSSARY | GLOSARIO |
| Acesso | Disponível em: … Acesso em: 20 out. 2026. | Available at: … Accessed on: 20 Oct. 2026. | Disponible en: … Consultado el: … |
| Artigos | ARTIGO 1 – | ARTICLE 1 – | ARTÍCULO 1 – |

Outros idiomas (`lang: fr`, por exemplo) geram aviso e ficam com os
rótulos em português.

## Mensagens da extensão e o que fazer

As mensagens aparecem no terminal (ou na aba *Background Jobs* do RStudio) e
começam com `[ufla-normas]`. **ERRO** para a renderização; **AVISO** deixa o
PDF sair.

### Erros

| Mensagem | O que fazer |
|---|---|
| `Não encontrei o arquivo de referências "refs.bib". Procurei em: C:\...\minha-pasta. Confira o nome e se ele está na mesma pasta do .qmd.` | Confira o nome do arquivo em `bibliography:` (maiúsculas, extensão `.bib`) e a pasta. O caminho é relativo à pasta do `.qmd`. |
| `tipo: "dissertação" não existe. Você quis dizer "dissertacao"? Use um destes: tcc, monografia, monografia-licenciatura, especializacao, dissertacao, dissertacao-profissional, tese, relatorio-estagio.` | Escreva o `tipo` sem acento, como na lista. |
| `Não encontrei o arquivo de estilo "periodico.csl" do artigo "...". Procurei em: .... Confira o nome e se ele está na mesma pasta do .qmd.` | Ponha o `.csl` na pasta do `.qmd` ou corrija o `csl=` do artigo. |

### Avisos

| Mensagem | O que fazer |
|---|---|
| `Campo "orientdor" desconhecido — você quis dizer "orientador"?` | Corrija o nome do campo. |
| `Campo "x" não é usado pela extensão.` | O campo não existe; veja a [lista de campos](#escreva-aqui-o-cabeçalho-yaml). |
| `Falta preencher "curso" (aparece como [preencha: curso] no PDF).` | Preencha o campo. Vale para `title`, `author`, `ano`, `curso` e `orientador`. |
| `genero: "x" não é válido; use f (feminino) ou m (masculino).` | Use `f` ou `m` (também em `orientador-genero` e `coorientador-genero`). |
| `tipo-trabalho "Projeto final" sem tipo: — a nota descritiva usará "Programa de Pós-Graduação em" e o título "Mestre". Defina tipo: para escolher o nível (ex.: tipo: tcc).` | Acrescente `tipo:` com o nível do seu curso. |
| `O resumo tem 42 palavras; o manual pede de 150 a 500.` (ou `O abstract tem ...`) | Ajuste o tamanho do resumo ou do abstract. |
| `A folha de aprovação está sem membros da banca (banca-um-nome, banca-um-inst, banca-dois-nome, ...).` | Preencha a banca ou tire `defesa:` até a defesa. |
| `Lembrete para a versão final: dissertações e teses precisam de folha de aprovação (defesa:), ficha catalográfica e indicadores de impacto.` | Só um lembrete no rascunho. Na versão final, preencha `defesa` e a banca, `ficha-catalografica: true` e `indicadores-impacto-texto`. |
| `Citação não encontrada: @souza2042 (você quis dizer @souza2024?)` | A chave não está no `.bib`. Corrija a chave ou exporte a referência de novo. No PDF ela aparece como **[souza2042?]** em vermelho. |
| `2 chave(s) sem entrada na bibliografia: @a, @b` | Resumo das citações não encontradas. |
| `O texto cita @silva2020, mas não há "bibliography:" no YAML.` | Acrescente `bibliography: referencias.bib`. |
| `lang: "fr" não é suportado; os rótulos do texto (Figura, Fonte, APÊNDICE, REFERÊNCIAS...) ficam em português. Idiomas com rótulos próprios: pt, en, es.` | Use `pt-BR`, `en` ou `es`. |
| `Trabalho em outro idioma: preencha "titulo-traduzido" (o manual exige o título em português na folha de aprovação).` | Acrescente `titulo-traduzido`. |
| `formato: "artigo" não é válido. Você quis dizer "artigos"? Use um destes: texto-integral, artigos. O trabalho segue como texto-integral.` | Corrija o valor de `formato`. |
| `formato: artigos — use # Primeira parte {.parte}, # Segunda parte – Artigos {.parte} e # Terceira parte {.parte} para dividir o trabalho (manual, Figura 3.23). ...` | Acrescente os títulos `{.parte}`. |
| `formato: artigos, mas nenhum título tem a classe {.artigo} ...` | Marque o título de cada artigo com `{.artigo}`. |
| `Há títulos {.parte} ou {.artigo}, mas o formato é "texto-integral": eles ficaram como capítulos comuns. Para o formato de artigos, use formato: artigos no YAML.` | Acrescente `formato: artigos` ou tire as classes. |
| `"Título": partes e artigos usam título de nível 1 (# Título {.artigo}); este ficou como seção comum.` | Use `#`, não `##`, no título da parte ou do artigo. |
| `"Título": apêndices e anexos usam título de nível 1 (# Título {.apendice}); este ficou como seção comum.` | Use `#` no título do apêndice ou anexo. |
| `Esta versão do Quarto não permite aplicar fig-fonte/tbl-fonte de células de código; use fonte="..." na figura ou tabela.` | Atualize o Quarto, ou escreva a figura/tabela em Markdown com `fonte=`. |

### Problemas do LaTeX

| Sintoma | O que fazer |
|---|---|
| Erro dizendo que a fonte `TeX Gyre Termes` não foi encontrada | TinyTeX: `tlmgr install tex-gyre`. MiKTeX: abra o *MiKTeX Console* e ligue a instalação automática de pacotes. |
| O PDF sai, mas uma citação aparece como **[chave?]** em vermelho | Veja o aviso `Citação não encontrada` no terminal. |

## Migrar da versão 1.x

Documentos da 1.x continuam renderizando. Para aproveitar a 2.0:

1. Troque `tipo-trabalho` + `titulo-pretendido` por `tipo:` (veja
   [Tipos](#tipos-de-trabalho)). Os campos antigos ainda funcionam e têm
   prioridade sobre o `tipo`.
2. Em `bibliography:`, deixe só o seu `.bib`. O
   `_extensions/bonijoao/ufla-normas/referencias.bib` não é mais necessário
   (o arquivo continua lá para não quebrar documentos antigos).
3. Tire `\textbf{}` dos títulos no `.bib`; não faz mais diferença.
4. Troque `Fonte: ...` escrito à mão abaixo de figuras e tabelas por
   `fonte="..."` no elemento, e `\apendice{Título}` por
   `# Título {.apendice}`. O comando `\apendice{}` ainda funciona.
5. Se usou `\subfigure{}` em LaTeX, troque por subfiguras do Quarto
   (`layout-ncol`); o pacote `subfigure` foi substituído por `subcaption`.
6. Figuras, tabelas e quadros agora são numerados em sequência (Figura 1,
   2…), e não por capítulo (Figura 1.1). O manual (3.2.9) aceita os dois.
7. O motor passou de `pdflatex` para `lualatex` com TeX Gyre Termes. No
   TinyTeX, rode `tlmgr install tex-gyre`; o MiKTeX instala sozinho.

Veja o [CHANGELOG](CHANGELOG.md) para a lista completa.

## In English

`ufla-normas` is a Quarto PDF format for theses, dissertations and
undergraduate monographs at the Universidade Federal de Lavras (UFLA,
Brazil). It follows the university's *Manual de normalização e estrutura de
trabalhos acadêmicos*, 6th edition (2025).

Start a new project with `quarto use template bonijoao/ufla-normas`, or add
the format to an existing one with `quarto add bonijoao/ufla-normas` and
`format: ufla-normas-pdf`. You need Quarto 1.4 or later and LuaLaTeX with the
TeX Gyre Termes font (TinyTeX: `tlmgr install tex-gyre`).

From the YAML header it builds the cover, title page, cataloguing record,
approval page, abstracts, impact indicators, lists and table of contents.
`tipo:` selects one of the eight work types of the manual. Citations and
references use citeproc with a bundled ABNT style; any BibTeX or BibLaTeX
file works. Figures, tables and *quadros* take a `fonte="..."` attribute,
appendices are `# Title {.apendice}`, and `formato: artigos` builds the
article-based thesis layout with one reference list per article. Works
written in English or Spanish (`lang: en`, `lang: es`) keep the pre-textual
pages in Portuguese and use the text language from the introduction on. The
extension checks the YAML and prints its warnings in Portuguese.

The rest of this README is in Portuguese, since the format is meant for UFLA
students.

## Licença e créditos

- O código da extensão é distribuído sob a licença MIT; veja
  [LICENSE](LICENSE).
- O estilo de citação `ufla-abnt.csl` é derivado de
  `associacao-brasileira-de-normas-tecnicas.csl`, do repositório
  [citation-style-language/styles](https://github.com/citation-style-language/styles),
  e segue a licença [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
  Os autores e colaboradores do estilo original estão listados no próprio
  arquivo.
- O logotipo da UFLA (`logoUFLA.pdf`) pertence à Universidade Federal de
  Lavras.

Referência normativa: UNIVERSIDADE FEDERAL DE LAVRAS. Biblioteca
Universitária. **Manual de normalização e estrutura de trabalhos
acadêmicos**. 6. ed. Lavras: UFLA, 2025.
