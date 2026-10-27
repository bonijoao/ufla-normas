# ufla-normas

Extensão Quarto para produção de trabalhos acadêmicos (TCC, monografia,
dissertação, tese) conforme as normas da **Universidade Federal de Lavras (UFLA)**,
Manual de Normalização e Estrutura de Trabalhos Acadêmicos, **6ª edição (2025)**.

## Requisitos

- [Quarto](https://quarto.org) ≥ 1.4
- Distribuição LaTeX com pdflatex (ex.: TeX Live, MiKTeX)
- Pacotes LaTeX: `pslatex`, `mathptmx`, `titlesec`, `fancyhdr`, `geometry`,
  `caption`, `enumitem`, `float`, `alphalph`, `footmisc`, `setspace`

## Instalação

No terminal:

```bash
quarto add bonijoao/ufla-normas
```

Ou, para usar localmente sem instalar:

```bash
git clone https://github.com/bonijoao/ufla-normas
cd ufla-normas
quarto render template.qmd
```

## Uso mínimo

Crie um arquivo `.qmd` com o seguinte cabeçalho YAML mínimo:

```yaml
---
title: "TÍTULO DO TRABALHO"
author: "Nome Completo do Autor"
ano: "2025"
abstract: |
  Texto do resumo em parágrafo único, 150–500 palavras.
keywords: [palavra1, palavra2, palavra3]
abstract-en: |
  Abstract text in a single paragraph.
keywords-en: [keyword1, keyword2, keyword3]
tipo-trabalho: "Dissertação"
titulo-pretendido: "Mestre"
curso: "Agronomia/Fitotecnia"
orientador: "Prof. Dr. Nome do Orientador"
cidade: "Lavras-MG"
bibliography: referencias.bib
format:
  ufla-normas-pdf: default
---
```

## Referência completa de campos

### Campos obrigatórios

| Campo | Descrição | Exemplo |
|-------|-----------|---------|
| `title` | Título em maiúsculas | `"TÍTULO DO TRABALHO"` |
| `author` | Nome completo do autor | `"João da Silva"` |
| `ano` | Ano de depósito (4 dígitos) | `"2025"` |
| `abstract` | Resumo em PT | texto em bloco `\|` |
| `keywords` | Palavras-chave em PT | `[p1, p2, p3]` |
| `abstract-en` | Abstract em inglês | texto em bloco `\|` |
| `keywords-en` | Keywords em inglês | `[k1, k2, k3]` |
| `tipo-trabalho` | Natureza do trabalho | `"Dissertação"` |
| `titulo-pretendido` | Título acadêmico | `"Mestre"` |
| `orientador` | Nome do orientador | `"Prof. Dr. X"` |
| `cidade` | Cidade e UF | `"Lavras-MG"` |
| `bibliography` | Arquivo .bib | `referencias.bib` |

### Campos opcionais

| Campo | Descrição | Padrão |
|-------|-----------|--------|
| `subtitle` | Subtítulo (sem negrito) | — |
| `curso` | Curso ou programa | — |
| `area-concentracao` | Área de concentração | — |
| `coorientador` | Coorientador | — |
| `instituicao` | Instituição | `"Universidade Federal de Lavras"` |
| `frente-verso` | Impressão frente e verso | `false` |
| `ficha-catalografica` | Incluir ficha catalográfica | `false` |
| `indicadores-impacto` | Incluir indicadores de impacto | `true` |
| `dedicatoria` | Texto da dedicatória | — |
| `agradecimentos` | Texto dos agradecimentos | — |
| `epigrafe` / `epigrafe-autor` | Epígrafe e autoria | — |
| `lof` | Incluir lista de figuras | `false` |
| `lot` | Incluir lista de tabelas | `false` |
| `defesa` | Data de defesa (gera folha de aprovação) | — |
| `banca-um-nome` / `banca-um-inst` | 1º membro da banca | — |
| `banca-dois-nome` / `banca-dois-inst` | 2º membro da banca | — |
| `banca-tres-nome` / `banca-tres-inst` | 3º membro da banca | — |
| `banca-quatro-nome` / `banca-quatro-inst` | 4º membro da banca | — |

### Campos da ficha catalográfica (quando `ficha-catalografica: true`)

| Campo | Descrição |
|-------|-----------|
| `fc-autor-sobrenome` | Autor no formato "Sobrenome, Nome" |
| `fc-autores` | Autores após a barra "/" |
| `fc-tipo` | Tipo do trabalho (ex.: "Dissertação (mestrado)") |
| `fc-catalogacao` | Termos de catalogação gerados pela biblioteca |
| `fc-classificacao` | Número CDD (ex.: "808.066") |
| `fc-ilust` | Indicação de ilustrações (ex.: "il.") |

## Referências bibliográficas

### O arquivo `.bib`

As referências são gerenciadas por um arquivo de texto com extensão `.bib` (formato
BibTeX). Cada fonte — artigo, livro, dissertação, etc. — é registrada como uma entrada
identificada por uma **chave única** que você usa nas citações do texto.

O arquivo `.bib` deve estar **na mesma pasta que o seu `.qmd`**. Declare-o no YAML:

```yaml
bibliography: referencias.bib
```

Para usar mais de um arquivo (ex.: seu `.bib` + o da extensão):

```yaml
bibliography:
  - referencias.bib
  - _extensions/bonijoao/ufla-normas/referencias.bib
```

> **Dica:** Crie o arquivo `referencias.bib` antes de renderizar. Se o arquivo
> declarado em `bibliography:` não existir, o PDF será gerado com citações exibidas
> como `[?]` e sem seção de referências.

### Criando o arquivo `.bib`

Crie um arquivo de texto chamado `referencias.bib` na pasta do seu trabalho. Cada
entrada segue o padrão abaixo — os campos variam conforme o tipo de documento.

#### Artigo de periódico (`@article`)

```bibtex
@article{Silva2020exemplo,
  author  = {Silva, João and Souza, Maria},
  title   = {Título do artigo em letras minúsculas},
  journal = {Revista Brasileira de Ciências},
  year    = {2020},
  volume  = {15},
  number  = {3},
  pages   = {100--115},
  doi     = {10.0000/exemplo},
}
```

#### Livro (`@book`)

```bibtex
@book{Franca2021livro,
  author    = {França, Júnia Lessa and Vasconcellos, Ana Cristina de},
  title     = {Manual para normalização de publicações técnico-científicas},
  edition   = {9},
  address   = {Belo Horizonte},
  publisher = {Editora UFMG},
  year      = {2021},
}
```

#### Capítulo de livro (`@incollection`)

```bibtex
@incollection{Autor2022capitulo,
  author    = {Autor, Nome do},
  title     = {Título do capítulo},
  booktitle = {Título do livro},
  editor    = {Editor, Nome do},
  address   = {Cidade},
  publisher = {Editora},
  year      = {2022},
  pages     = {50--75},
}
```

#### Dissertação de mestrado (`@mastersthesis`)

```bibtex
@mastersthesis{Sobrenome2024dis,
  author  = {Sobrenome, Nome},
  title   = {Título da dissertação},
  school  = {Universidade Federal de Lavras},
  address = {Lavras},
  year    = {2024},
  type    = {Dissertação (mestrado em Agronomia/Fitotecnia)},
}
```

#### Tese de doutorado (`@phdthesis`)

```bibtex
@phdthesis{Sobrenome2023tese,
  author  = {Sobrenome, Nome},
  title   = {Título da tese},
  school  = {Universidade Federal de Lavras},
  address = {Lavras},
  year    = {2023},
  type    = {Tese (doutorado em Agronomia/Fitotecnia)},
}
```

#### Documento online / site (`@misc`)

```bibtex
@misc{IBGE2023pop,
  author       = {{Instituto Brasileiro de Geografia e Estatística}},
  title        = {Censo Demográfico 2022},
  year         = {2023},
  url          = {https://www.ibge.gov.br/censo2022},
  urlaccessdate = {14 jun. 2026},
}
```

> **Nota:** Nomes de instituições como autores devem ficar entre `{{ }}` duplas para
> que o BibTeX não interprete vírgulas internas como separador de campos.

#### Manual / relatório técnico (`@manual`)

```bibtex
@manual{UFLA2025normas,
  address      = {Lavras},
  author       = {{Universidade Federal de Lavras}},
  organization = {Biblioteca Universitária},
  title        = {Manual de normalização e estrutura de trabalhos acadêmicos},
  year         = {2025},
  edition      = {6},
}
```

### Chave de citação

A chave (ex.: `Silva2020exemplo`) é definida por você e deve ser **única** no arquivo.
Por convenção use `SobrenomeAnopalavra`. Evite acentos, espaços e caracteres especiais.

### Gerenciadores de referências (recomendado)

Em vez de editar o `.bib` manualmente, use um gerenciador que exporta diretamente:

- **[Zotero](https://www.zotero.org)** (gratuito) + plugin
  [Better BibTeX](https://retorque.re/zotero-better-bibtex/): exporta e sincroniza o
  `.bib` automaticamente conforme você adiciona fontes.
- **[JabRef](https://www.jabref.org)** (gratuito): editor visual de arquivos `.bib`.

### Citações no texto

O sistema **autor-data** é o único aceito pela UFLA. Use a sintaxe padrão do Quarto:

```markdown
Citação inline:       @Silva2020exemplo afirma que...
Citação parentética:  ... (texto) [@Silva2020exemplo].
Com página:           [@Silva2020exemplo, p. 45]
Múltiplos autores:    [@Silva2020exemplo; @Franca2021livro]
Quatro ou mais autores: aparecem automaticamente como "Autor et al."
```

**Citação longa** (mais de 3 linhas): use bloco de citação Markdown (`>`):

```markdown
> Texto longo com mais de três linhas que deve ser recuado 4 cm,
> em fonte 11pt e espaçamento simples, conforme a norma.
> [@Autor2022capitulo, p. 67].
```

### Erros comuns com referências

| Sintoma | Causa provável | Solução |
|---------|---------------|---------|
| Citações aparecem como `[?]` | Arquivo `.bib` não encontrado | Verifique o caminho em `bibliography:` e se o arquivo existe na pasta |
| Seção "REFERÊNCIAS" não aparece | Campo `bibliography:` ausente no YAML | Adicione `bibliography: referencias.bib` ao cabeçalho |
| Nome do autor em maiúsculas erradas | Organização sem `{{ }}` duplas | Envolva o nome: `author = {{Instituto Brasileiro...}}` |
| `et al.` não aparece em itálico | Opção não propagada | Não é necessário configurar — a extensão aplica automaticamente |
| Erro no LaTeX: `I found no \citation` | Nenhuma citação usada no texto | Use ao menos uma citação `@chave` ou remova o campo `bibliography:` |

## Normas implementadas

- Margens: sup/esq 3cm, inf/dir 2cm (sec 3.2.2)
- Fonte Times 12pt; 11pt para citações longas, notas, legendas (sec 3.2.1)
- Espaçamento 1,5 no texto; simples em citações/notas/referências (sec 3.2.3)
- Parágrafo 1,25cm, justificado, sem espaço entre parágrafos (sec 3.2.3)
- Seções primárias: MAIÚSCULAS + negrito; nova página (sec 3.2.4)
- Títulos sem indicativo numérico: centralizados MAIÚSCULAS negrito (sec 3.2.5)
- Paginação: algarismos arábicos, canto superior direito, a partir da Introdução (sec 3.2.7)
- Citações curtas com aspas duplas; longas recuadas 4cm (sec 4.1)
- Referências: título em negrito, et al. em itálico, ordem alfabética (sec 5)
- Indicadores de Impacto (Resolução PRPG n. 012/2024)


## Referência

UNIVERSIDADE FEDERAL DE LAVRAS. Biblioteca Universitária. Manual de normalização e estrutura de trabalhos acadêmicos. 6. ed. Lavras, 2025.

## Licença

O código da extensão é distribuído sob a licença MIT; veja [LICENSE](LICENSE).
Os arquivos do abnTeX2 incluídos na extensão (`abntex2cite.sty` e
`abntex2-alf.bst`) seguem a LaTeX Project Public License, e o logo da UFLA
pertence à universidade.
