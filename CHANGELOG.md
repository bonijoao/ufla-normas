# Changelog

## [2.0.0] — 2026-10-28

Versão reescrita para quem usa Quarto e não sabe LaTeX: ajustar o YAML e
escrever. Documentos da 1.x continuam renderizando; veja "Como migrar da 1.x".

### Corrigido
- O exemplo oficial saía com todas as citações `(??)` e a lista REFERÊNCIAS
  vazia, sem erro visível: o caminho `_extensions/bonijoao/ufla-normas/referencias.bib`
  tinha `_`, que chegava escapado ao BibTeX. As referências agora passam pelo
  citeproc, e o caminho do `.bib` pode ter `_`, espaço e acento.
- Seções numeradas "0.1 INTRODUÇÃO", "0.2 ..."; agora "1 INTRODUÇÃO".
- `.bib` em BibLaTeX (Zotero/Better BibTeX) dava citação sem ano
  (`(Silva et al., )`) e entradas sem periódico ou instituição.
- Dissertação exportada pelo Zotero saía "Tese (Dissertação ...)".
- `urldate` era ignorado; agora sai "Disponível em: URL. Acesso em: 20 out. 2026."
  (sem `< >`, como na NBR 6023:2018).
- "García" saía "GARCíA" e "Çetinkaya-Rundel" era cortado.
- "Silva, João da" saía "SILVA, J. d."; agora "SILVA, João da".
- Instituição como autor (`{{ }}`) saía em minúsculas na lista.
- `[ver @x, p. 45]` e `[-@x]` derrubavam a compilação com uma mensagem
  enganosa de "missing packages".
- Folha de rosto com "Dissertação apresentado"; a concordância segue o tipo.
- `@mastersthesis` sem `type` saía "Mathesis"; agora "Dissertação (Mestrado)".
- Folha de aprovação com `defesa:` e sem banca quebrava o LaTeX.
- O coorientador saía na mesma linha do rótulo do orientador.
- Caixas do Quarto (`.callout-*`) e `include-in-header` quebravam o PDF.
- Uma tabela dentro de quadro contava como tabela (a primeira tabela depois
  de um quadro saía "Tabela 2").
- O campo `errata` gerava aviso de campo desconhecido.

### Adicionado
- `tipo:` com os oito tipos do Quadro 3.1 do manual (`tcc`, `monografia`,
  `monografia-licenciatura`, `especializacao`, `dissertacao`,
  `dissertacao-profissional`, `tese`, `relatorio-estagio`), que montam a nota
  descritiva; `genero`, `orientadora`, `coorientadora`, `orientador-genero` e
  `coorientador-genero`.
- Estilo ABNT da UFLA (`ufla-abnt.csl`) com citeproc: qualquer `.bib` BibTeX
  ou BibLaTeX funciona; chamada narrativa com dois ou três autores
  ("Costa e Ferreira (2022)"); limpeza de `\textbf{}` e acentos em LaTeX nos
  campos do `.bib`.
- Citação sem entrada no `.bib`: aviso com sugestão da chave mais parecida e
  **[chave?]** em vermelho no PDF.
- Validação do YAML com mensagens em português: arquivo `.bib` inexistente e
  `tipo` desconhecido param a renderização; campos com erro de digitação,
  campos básicos vazios (com `[preencha: campo]` no PDF), resumo fora de 150
  a 500 palavras, banca vazia e lembrete da versão final de dissertações e
  teses geram aviso.
- `fonte="..."` em figuras, tabelas e quadros (e `fig-fonte`/`tbl-fonte` em
  células de código); quadros com `::: {#qdr-x}` e `@qdr-x`; LISTA DE QUADROS
  (`loq`).
- Apêndices e anexos em Markdown: `# Título {.apendice}` / `{.anexo}`, com
  `@apx-x` no texto.
- `siglas`, `simbolos` e `glossario` no YAML.
- Trabalho em outro idioma (`lang: en`, `lang: es`) com `titulo-traduzido`:
  pré-textuais em português e rótulos e referências no idioma do texto.
- `formato: artigos` (manual, Figura 3.23): partes (`.parte`), artigos
  (`.artigo`, com `nota=` e `csl=` por artigo) e referências por artigo.
- Modelo inicial para `quarto use template bonijoao/ufla-normas`, com um
  `referencias.bib` de exemplo de cada tipo comum.
- Testes automatizados em `tests/` (renderizam PDFs reais).

### Mudou
- Motor `pdflatex` → `lualatex`, com a fonte TeX Gyre Termes (equivalente à
  Times). Aceita qualquer caractere Unicode (μ, β, °, ≤).
- BibTeX/natbib/abnTeX2 → citeproc. Os arquivos `abntex2cite.sty` e
  `abntex2-alf.bst` saíram da extensão.
- Figuras, tabelas e quadros numerados em sequência (Figura 1, 2…) em vez de
  por capítulo (Figura 1.1). O manual (3.2.9) aceita as duas formas.
- Pacote `subfigure` → `subcaption` (o Quarto exige o `subcaption`).
- Sem `ano` e sem `date`, a capa mostra `[preencha: ano]` em vermelho em vez
  do ano corrente.
- `tipo-trabalho: "Dissertação"` sem `tipo` agora escreve "Programa de
  Pós-Graduação em" na nota descritiva, como o manual (a 1.x escrevia sempre
  "Curso de").

### Como migrar da 1.x
- `\textbf{}` nos títulos do `.bib` não é mais necessário.
- `tipo:` substitui `tipo-trabalho` + `titulo-pretendido`. Os dois campos
  antigos continuam funcionando e têm prioridade sobre o `tipo`.
- `\apendice{}` em LaTeX continua funcionando; o novo jeito é
  `# Título {.apendice}`.
- `pdflatex` → `lualatex`: no TinyTeX, rode `tlmgr install tex-gyre`; o
  MiKTeX instala o que faltar sozinho.
- O caminho `_extensions/bonijoao/ufla-normas/referencias.bib` em
  `bibliography:` não é mais necessário; liste só o seu `.bib`.
- `\subfigure{}` em LaTeX não funciona mais; use subfiguras do Quarto.
- A numeração das figuras e tabelas muda de 1.1 para 1; confira referências
  escritas à mão no texto (as feitas com `@fig-x` se ajustam sozinhas).
- Quem quiser continuar na 1.x: `quarto add bonijoao/ufla-normas@v1.0.0`.

## [1.0.0] — 2026-05-20

### Adicionado
- Extensão Quarto `ufla-normas` compatível com Quarto >= 1.4
- Template LaTeX baseado em `templufla.cls` v6.10.0, adaptado para Pandoc
- Implementação completa das normas da UFLA Manual 6a edição (2025):
  - Margens, fontes, espaçamentos (sec 3.2.1-3.2.3)
  - Paginação com lógica correta (capa não contada, ficha não contada)
  - Seções primárias a quinária (sec 3.2.4)
  - Títulos sem indicativo numérico (sec 3.2.5)
  - Citações diretas curtas e longas (sec 4.1)
  - Sistema autor-data ABNT com regras específicas UFLA (sec 4.5)
  - Referências com título em negrito e et al. em itálico (sec 5.2)
- Geração automática de todos os elementos pré-textuais obrigatórios:
  capa, folha de rosto, ficha catalográfica, folha de aprovação,
  resumo, abstract, indicadores de impacto, sumário
- Elementos pré-textuais opcionais: errata, dedicatória, agradecimentos, epígrafe
- Listas opcionais de figuras e tabelas
- Suporte a quadro, figura, tabela com formatação UFLA
- Alíneas e subalíneas (ambiente `alineas`)
- Ficha catalográfica automática com todos os campos configuráveis
- Folha de aprovação automática (gerada quando `defesa:` é definido)
- Indicadores de Impacto (Resolução PRPG n. 012/2024)
- Campo `frente-verso: true` para impressão nos dois lados
- Template de exemplo completo `template.qmd` com todos os campos documentados
