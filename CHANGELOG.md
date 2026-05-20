# Changelog

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
