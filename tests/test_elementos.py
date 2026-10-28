"""Elementos em Markdown (elementos.lua): apêndices e anexos, `fonte=` em
figuras, tabelas e quadros, quadros com referência cruzada, listas de siglas
e símbolos, glossário; e os includes do Quarto no template (callouts,
include-in-header) sem perder o SUMÁRIO e as legendas da UFLA."""
import re
import shutil

import pytest

from conftest import SAIDA

LOGO = "_extensions/ufla-normas/logoUFLA.pdf"

BIB = """@book{silva_livro_2020,
  author = {Silva, João},
  title = {Livro de teste},
  publisher = {Editora UFLA},
  address = {Lavras},
  year = {2020}
}
"""


def junta(s: str) -> str:
    """Um espaço só entre as palavras (o pdftotext -layout alinha colunas)."""
    return re.sub(r"\s+", " ", s)


def paginas(r) -> list[str]:
    return r.texto.split("\f")


def indice_pagina(r, trecho: str, desde: int = 0) -> int:
    """Índice da primeira página (a partir de `desde`) que contém `trecho`."""
    for i, pag in enumerate(paginas(r)):
        if i >= desde and trecho in junta(pag):
            return i
    return -1


def sumario(r) -> str:
    i = indice_pagina(r, "SUMÁRIO")
    assert i >= 0, "PDF sem a página SUMÁRIO"
    return junta(paginas(r)[i])


# Apêndices e anexos ---------------------------------------------------------

CORPO_APENDICES = (
    "# Introdução\n\n"
    "Texto que cita [@silva_livro_2020] e remete ao @apx-roteiro.\n\n"
    "# Questionário aplicado à gestão {.apendice}\n\n"
    "Conteúdo do questionário.\n\n"
    "## Parte interna\n\n"
    "Detalhe do questionário.\n\n"
    "# Roteiro de observação {#apx-roteiro .apendice}\n\n"
    "Conteúdo do roteiro.\n\n"
    "# Lei de criação {.anexo}\n\n"
    "Texto da lei.\n"
)


def test_apendice_anexo(render):
    r = render(
        "apendice-anexo",
        yaml="bibliography: refs.bib",
        corpo=CORPO_APENDICES,
        arquivos={"refs.bib": BIB},
    )
    assert r.ok, r.log
    rotulos = [
        "APÊNDICE A – QUESTIONÁRIO APLICADO À GESTÃO",
        "APÊNDICE B – ROTEIRO DE OBSERVAÇÃO",
        "ANEXO A – LEI DE CRIAÇÃO",
    ]
    toc = sumario(r)
    for rotulo in rotulos:
        assert rotulo in toc, toc
    assert "Parte interna" not in toc, toc   # subdivisão interna do apêndice
    # referências antes do primeiro apêndice, mesmo sem ::: {#refs}
    depois_refs = junta(r.depois("REFERÊNCIAS"))
    assert "SILVA, João. Livro de teste" in depois_refs, depois_refs
    for rotulo in rotulos:
        assert rotulo in depois_refs, depois_refs
    assert depois_refs.index("SILVA, João.") < depois_refs.index(rotulos[0])
    # ordem e página nova para cada um
    pags = [indice_pagina(r, rotulo, desde=indice_pagina(r, "SUMÁRIO") + 1) for rotulo in rotulos]
    assert pags[0] < pags[1] < pags[2], pags
    assert "Conteúdo do questionário" not in paginas(r)[pags[1]]
    # sem número de seção na parte pós-textual
    texto = junta(r.texto)
    assert "2 QUESTIONÁRIO" not in texto
    assert "2.1 Parte interna" not in texto and "Parte interna" in texto
    # @apx-roteiro vira "Apêndice B"
    assert "remete ao Apêndice B" in texto, texto
    assert "?@apx" not in texto


def test_apendice_latex_v1(render):
    """O comando LaTeX da v1 continua funcionando."""
    r = render(
        "apendice-v1",
        corpo="# Introdução\n\nTexto.\n\n\\apendice{Velho}\n\nConteúdo antigo.\n",
    )
    assert r.ok, r.log
    assert "APÊNDICE A – VELHO" in junta(r.texto)


def test_refs_do_autor_depois_dos_apendices_sobe(render):
    """`::: {#refs}` escrito depois dos apêndices sobe para antes deles."""
    corpo = (
        "# Introdução\n\nTexto [@silva_livro_2020].\n\n"
        "# Questionário {.apendice}\n\nConteúdo.\n\n"
        "# Referências\n\n::: {#refs}\n:::\n"
    )
    r = render("refs-sobe", yaml="bibliography: refs.bib", corpo=corpo,
               arquivos={"refs.bib": BIB})
    assert r.ok, r.log
    depois_refs = junta(r.depois("REFERÊNCIAS"))
    assert "SILVA, João." in depois_refs
    assert "APÊNDICE A – QUESTIONÁRIO" in depois_refs, depois_refs


# Fonte de figuras e tabelas -------------------------------------------------

def tamanho_fonte(pdf, trecho):
    pymupdf = pytest.importorskip("pymupdf")
    with pymupdf.open(str(pdf)) as doc:
        for pagina in doc:
            for bloco in pagina.get_text("dict")["blocks"]:
                for linha in bloco.get("lines", []):
                    for s in linha["spans"]:
                        if trecho in s["text"]:
                            return s["size"]
    return None


def test_fonte_figura_tabela(render):
    corpo = (
        "# Introdução\n\n"
        "Veja a @fig-logo e a @tbl-dados.\n\n"
        f"![Logomarca]({LOGO}){{#fig-logo fonte=\"Elaboração própria (2025)\" width=3cm}}\n\n"
        "| Coluna um | Coluna dois |\n|---|---|\n| 10 | 20 |\n\n"
        ": Dados de teste {#tbl-dados fonte=\"Elaboração própria (2025)\"}\n"
    )
    r = render("fonte-figura-tabela", corpo=corpo)
    assert r.ok, r.log
    texto = junta(r.texto)
    assert texto.count("Fonte: Elaboração própria (2025).") == 2, texto
    # numeração sequencial (Figura 1, não 1.1) e título acima, fonte abaixo
    assert "Veja a Figura 1 e a Tabela 1" in texto, texto
    assert "Figura 1 – Logomarca" in texto
    i_tab = texto.index("Tabela 1 – Dados de teste")
    assert i_tab < texto.index("Coluna um") < texto.index("10 20")
    assert texto.index("10 20") < texto.index("Fonte:", i_tab)
    # a imagem não tem texto: logo depois do título vem a fonte
    assert "Figura 1 – Logomarca Fonte: Elaboração própria (2025)." in texto
    assert tamanho_fonte(r.pdf, "Elaboração própria") == pytest.approx(11, abs=0.2)


@pytest.mark.skipif(shutil.which("Rscript") is None, reason="R não instalado")
def test_fonte_celula_de_codigo(render):
    corpo = (
        "# Introdução\n\n"
        "```{r}\n"
        "#| label: fig-pontos\n"
        "#| fig-cap: \"Pontos\"\n"
        "#| fig-fonte: \"Dados simulados (2025)\"\n"
        "#| echo: false\n"
        "plot(1:3)\n"
        "```\n\n"
        "```{r}\n"
        "#| label: tbl-carros\n"
        "#| tbl-cap: \"Carros\"\n"
        "#| tbl-fonte: \"R Core Team (2025)\"\n"
        "#| echo: false\n"
        "knitr::kable(head(mtcars[, 1:2], 2))\n"
        "```\n"
    )
    r = render("fonte-celula", corpo=corpo)
    if not r.ok and "there is no package called" in r.log:
        pytest.skip("knitr/rmarkdown não instalados")
    assert r.ok, r.log
    texto = junta(r.texto)
    assert "Figura 1 – Pontos" in texto
    assert "Fonte: Dados simulados (2025)." in texto, texto
    assert "Tabela 1 – Carros" in texto
    assert "Fonte: R Core Team (2025)." in texto, texto


# Quadros --------------------------------------------------------------------

def test_quadro(render):
    corpo = (
        "# Introdução\n\n"
        "Os critérios estão resumidos conforme o @qdr-comp e o @qdr-dois.\n\n"
        "::: {#qdr-comp fonte=\"Elaboração própria (2025)\"}\n\n"
        "| Critério | Opção A |\n|---|---|\n| Custo | Baixo |\n\n"
        "Comparação\n\n"
        ":::\n\n"
        "::: {#qdr-dois quadro=\"Segunda comparação\" fonte=\"Elaboração própria (2025)\"}\n\n"
        "| Item | Valor |\n|---|---|\n| Prazo | Curto |\n\n"
        ":::\n"
    )
    r = render("quadro", yaml="loq: true", corpo=corpo)
    assert r.ok, r.log
    texto = junta(r.texto)
    assert "conforme o Quadro 1 e o Quadro 2" in texto, texto
    corpo_pdf = junta(r.depois("resumidos"))
    i1 = corpo_pdf.index("Quadro 1 – Comparação")
    assert i1 < corpo_pdf.index("Critério") < corpo_pdf.index("Fonte: Elaboração própria (2025).")
    i2 = corpo_pdf.index("Quadro 2 – Segunda comparação")
    assert i2 < corpo_pdf.index("Prazo")
    assert corpo_pdf.count("Fonte: Elaboração própria (2025).") == 2
    # lista de quadros antes do sumário
    i_lista = indice_pagina(r, "LISTA DE QUADROS")
    assert 0 <= i_lista < indice_pagina(r, "SUMÁRIO")
    lista = junta(paginas(r)[i_lista])
    assert "Comparação" in lista and "Segunda comparação" in lista, lista


# Siglas, símbolos e glossário ----------------------------------------------

YAML_LISTAS = """bibliography: refs.bib
siglas:
  UFLA: Universidade Federal de Lavras
  ABNT: Associação Brasileira de Normas Técnicas
simbolos:
  - "$\\\\alpha$": Nível de significância
  - "$\\\\beta$": Coeficiente angular
glossario:
  Zootecnia: Ciência da criação animal.
  Ética: Estudo da conduta.
  Agronomia: Ciência da produção vegetal.
"""


def test_siglas_glossario(render):
    corpo = (
        "# Introdução\n\nTexto [@silva_livro_2020].\n\n"
        "# Questionário {.apendice}\n\nConteúdo.\n"
    )
    r = render("siglas-glossario", yaml=YAML_LISTAS, corpo=corpo,
               arquivos={"refs.bib": BIB})
    assert r.ok, r.log
    assert "desconhecido" not in r.log and "não é usado" not in r.log, r.log
    i_sumario = indice_pagina(r, "SUMÁRIO")
    # siglas: página própria antes do sumário, em ordem alfabética
    i_siglas = indice_pagina(r, "LISTA DE ABREVIATURAS E SIGLAS")
    assert 0 <= i_siglas < i_sumario
    siglas = junta(paginas(r)[i_siglas])
    # (o pdftotext -layout separa as colunas; confere a ordem de cada uma)
    assert siglas.index("ABNT") < siglas.index("UFLA"), siglas
    assert siglas.index("Associação Brasileira") < siglas.index("Universidade Federal"), siglas
    # símbolos: na ordem em que foram escritos
    i_simbolos = indice_pagina(r, "LISTA DE SÍMBOLOS")
    assert i_siglas < i_simbolos < i_sumario
    simbolos = junta(paginas(r)[i_simbolos])
    assert simbolos.index("Nível de significância") < simbolos.index("Coeficiente angular")
    # glossário: depois das referências, antes dos apêndices, alfabético
    toc = sumario(r)
    assert "GLOSSÁRIO" in toc
    assert "LISTA DE ABREVIATURAS" not in toc
    depois_refs = junta(r.depois("REFERÊNCIAS"))
    assert "GLOSSÁRIO" in depois_refs, depois_refs
    glossario = depois_refs[depois_refs.index("GLOSSÁRIO"):]
    assert glossario.index("Agronomia") < glossario.index("Ética") < glossario.index("Zootecnia")
    assert glossario.index("Zootecnia") < glossario.index("APÊNDICE A – QUESTIONÁRIO")
    assert depois_refs.index("SILVA, João.") < depois_refs.index("GLOSSÁRIO")


# Includes do Quarto (callouts, include-in-header) --------------------------

CALLOUT = "::: {.callout-tip}\n## Dica de redação\nTexto dentro da dica.\n:::\n"


def test_callout_renderiza(render):
    r = render("callout", corpo="# Introdução\n\nTexto.\n\n" + CALLOUT)
    assert r.ok, r.log
    texto = junta(r.texto)
    assert "Dica de redação" in texto and "Texto dentro da dica." in texto


def test_sumario_continua_sumario(render):
    corpo = (
        "# Introdução\n\nVeja a @fig-logo.\n\n" + CALLOUT + "\n"
        f"![Logomarca]({LOGO}){{#fig-logo fonte=\"UFLA (2025)\" width=3cm}}\n"
    )
    r = render("callout-sumario", yaml="lof: true", corpo=corpo)
    assert r.ok, r.log
    texto = junta(r.texto)
    assert "SUMÁRIO" in texto
    assert "ÍNDICE" not in texto.upper()
    assert "LISTA DE FIGURAS" in texto
    assert "Figura 1 – Logomarca" in texto


def test_include_in_header(render):
    yaml = (
        "include-in-header:\n"
        "  text: |\n"
        "    \\newcommand{\\minhamacro}{Macro do autor}\n"
    )
    r = render("include-header", yaml=yaml,
               corpo="# Introdução\n\nTexto \\minhamacro{} aqui.\n")
    assert r.ok, r.log
    assert "Texto Macro do autor aqui." in junta(r.texto)
