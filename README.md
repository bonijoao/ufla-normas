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

## Citações

O sistema **autor-data** é o único aceito pela UFLA. Use a sintaxe padrão do Quarto:

```markdown
Citação inline:     @Silva2020 afirma que...
Citação parentética: ... (texto) [@Silva2020].
Com página:          [@Silva2020, p. 45]
Múltiplos autores:   [@Silva2020; @Santos2021]
Quatro ou mais autores: aparecem automaticamente como "Autor et al."
```

**Citação longa** (mais de 3 linhas): use bloco de citação Markdown (`>`):

```markdown
> Texto longo com mais de três linhas...
> [@Autor2020, p. 67].
```

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

Licença Creative Commons 

Exceto quando indicado de outra forma, a licença deste item é descrita como [Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)

<img src="imgs/by.png" width="100">


