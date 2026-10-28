"""Trabalhos redigidos em outro idioma (`lang:`): pré-textuais sempre em
português; do primeiro capítulo em diante, rótulos (Figure, Source:,
APPENDIX A –, ...), título das referências e termos do citeproc (Available
at, Accessed on) no idioma do texto. Folha de aprovação com o título
original e a tradução em português (`titulo-traduzido`, manual 3.1.2.1)."""
import re

from conftest import RAIZ, SAIDA

FIXTURES = RAIZ / "tests" / "fixtures"
PREFIXO = "[ufla-normas]"
LOGO = "_extensions/ufla-normas/logoUFLA.pdf"
IBGE = "instituto_brasileiro_de_geografia_e_estatistica_censo_2023"

TESE_SEM_TIPO = """
@thesis{lima_tese_2021,
  author = {Lima, Carla},
  title = {Uma tese sem tipo},
  institution = {Universidade Federal de Lavras},
  address = {Lavras},
  year = {2021}
}
"""


def junta(s: str) -> str:
    """Um espaço só entre as palavras (o pdftotext -layout alinha colunas);
    hífen de fim de linha cola na palavra seguinte."""
    s = re.sub(r"-[ \t]*\n\s*", "-", s)
    return re.sub(r"\s+", " ", s)


def paginas(r) -> list[str]:
    return r.texto.split("\f")


def indice_pagina(r, trecho: str) -> int:
    for i, pag in enumerate(paginas(r)):
        if trecho in junta(pag):
            return i
    return -1


def avisos(r) -> list[str]:
    return [linha for linha in r.log.splitlines() if PREFIXO in linha]


def bib() -> str:
    return (FIXTURES / "zotero.bib").read_text(encoding="utf-8") + TESE_SEM_TIPO


def corpo(titulo_intro: str) -> str:
    return (
        f"# {titulo_intro}\n\n"
        "See @fig-um, @qdr-q and @apx-roteiro.\n\n"
        f"Data [@{IBGE}; @lima_tese_2021].\n\n"
        f"![A figure]({LOGO}){{#fig-um width=20% fonte=\"Own work (2025)\"}}\n\n"
        "| a | b |\n|---|---|\n| 1 | 2 |\n\n: A table {#tbl-dois}\n\n"
        "::: {#qdr-q quadro=\"A chart\" fonte=\"Own work (2025)\"}\n\n"
        "| x | y |\n|---|---|\n| 3 | 4 |\n\n"
        ":::\n\n"
        "# Interview guide {#apx-roteiro .apendice}\n\nGuide.\n\n"
        "# Founding law {.anexo}\n\nLaw.\n"
    )


YAML_EN = """lang: en
keep-tex: true
title: "A study written in English"
titulo-traduzido: "Título em português"
defesa: "10 de março de 2026"
banca-um-nome: "Dr. Beltrano"
banca-um-inst: "UFLA"
lof: true
loq: true
bibliography: refs.bib
glossario:
  Term: A definition.
"""


def test_lang_en(render):
    r = render("lang-en", yaml=YAML_EN, corpo=corpo("Introduction"),
               arquivos={"refs.bib": bib()})
    assert r.ok, r.log
    log = "\n".join(avisos(r))
    assert "titulo-traduzido" not in log, log    # campo conhecido e preenchido
    # babel: inglês como idioma principal (hifenização do texto), português
    # nos pré-textuais
    tex = (SAIDA / "lang-en" / "lang-en.tex").read_text(encoding="utf-8")
    assert r"\usepackage[brazil, english]{babel}" in tex
    i_pt = tex.index(r"\selectlanguage{brazil}")
    i_en = tex.index(r"\selectlanguage{english}")
    assert i_pt < tex.index("\\tableofcontents\n") < i_en < tex.index("Introduction")

    # pré-textuais em português
    rosto = junta(r.pagina(2))
    assert "Orientador" in rosto and "apresentada" in rosto, rosto
    i_aprov = indice_pagina(r, "APROVADA em")
    assert i_aprov >= 0, r.texto
    aprov = junta(paginas(r)[i_aprov])
    i_orig = aprov.index("A STUDY WRITTEN IN ENGLISH")
    assert aprov.index("(TÍTULO EM PORTUGUÊS)") > i_orig, aprov
    assert "RESUMO" in r.texto and "SUMÁRIO" in r.texto
    # listas: título em português, itens com o rótulo da legenda no texto
    lof = junta(paginas(r)[indice_pagina(r, "LISTA DE FIGURAS")])
    assert "Figure 1 – A figure" in lof, lof
    loq = junta(paginas(r)[indice_pagina(r, "LISTA DE QUADROS")])
    assert "Chart 1 – A chart" in loq, loq

    # corpo em inglês
    texto = junta(r.depois("INTRODUCTION"))
    assert "See Figure 1, Chart 1 and Appendix A." in texto, texto
    assert "Figure 1 – A figure" in texto, texto
    assert "Table 1 – A table" in texto, texto
    assert "Chart 1 – A chart" in texto, texto
    assert "Source: Own work (2025)." in texto, texto
    assert "Fonte:" not in texto, texto
    assert "REFERENCES" in texto, texto
    assert "APPENDIX A – INTERVIEW GUIDE" in texto, texto
    assert "ANNEX A – FOUNDING LAW" in texto, texto
    assert "GLOSSARY" in texto, texto
    refs = junta(r.depois("REFERENCES"))
    assert "Available at: https://www.ibge.gov.br" in refs, refs
    assert "Accessed on: 20 Oct. 2026." in refs, refs
    assert "Disponível em" not in refs and "Acesso em" not in refs, refs
    # @thesis sem `type`: gênero em inglês, não "Trabalho acadêmico"
    assert "Uma tese sem tipo. 2021. Academic work – Universidade Federal de Lavras" in refs, refs
    assert "Trabalho acadêmico" not in refs, refs
    toc = junta(paginas(r)[indice_pagina(r, "SUMÁRIO")])
    assert "APPENDIX A – INTERVIEW GUIDE" in toc and "REFERENCES" in toc, toc


def test_lang_es(render):
    r = render(
        "lang-es",
        yaml=("lang: es-ES\ntitle: \"Un estudio\"\n"
              "titulo-traduzido: \"Um estudo\"\nbibliography: refs.bib\n"),
        corpo=corpo("Introducción"),
        arquivos={"refs.bib": bib()},
    )
    assert r.ok, r.log
    rosto = junta(r.pagina(2))
    assert "Orientador" in rosto and "apresentada" in rosto, rosto
    texto = junta(r.depois("INTRODUCCIÓN"))
    assert "See Figura 1, Cuadro 1 and Apéndice A." in texto, texto
    assert "Figura 1 – A figure" in texto, texto
    assert "Tabla 1 – A table" in texto, texto
    assert "Cuadro 1 – A chart" in texto, texto
    assert "Fuente: Own work (2025)." in texto, texto
    assert "REFERENCIAS" in texto, texto
    assert "APÉNDICE A – INTERVIEW GUIDE" in texto, texto
    assert "ANEXO A – FOUNDING LAW" in texto, texto
    refs = junta(r.depois("REFERENCIAS"))
    assert "Disponible en: https://www.ibge.gov.br" in refs, refs
    assert "Consultado el: 20" in refs, refs
    assert "Trabajo académico" in refs, refs


def test_lang_pt_curto(render):
    """`lang: pt` (sem região) é português do Brasil, sem aviso."""
    r = render(
        "lang-pt",
        yaml="lang: pt\nbibliography: refs.bib\n",
        corpo=corpo("Introdução"),
        arquivos={"refs.bib": bib()},
    )
    assert r.ok, r.log
    assert not any("idioma" in a.lower() or "lang" in a for a in avisos(r)), avisos(r)
    texto = junta(r.depois("INTRODUÇÃO"))
    assert "See Figura 1, Quadro 1 and Apêndice A." in texto, texto
    assert "Figura 1 – A figure" in texto and "Quadro 1 – A chart" in texto, texto
    assert "Fonte: Own work (2025)." in texto, texto
    assert "APÊNDICE A – INTERVIEW GUIDE" in texto, texto
    refs = junta(r.depois("REFERÊNCIAS"))
    assert "Disponível em: https://www.ibge.gov.br" in refs, refs
    assert "Acesso em: 20 out. 2026." in refs, refs
    assert "Trabalho acadêmico – Universidade Federal de Lavras" in refs, refs


def test_lang_desconhecido(render):
    """Idioma sem rótulos na extensão: aviso e rótulos em português."""
    r = render(
        "lang-fr",
        yaml="lang: fr\ntitulo-traduzido: \"Título\"\nbibliography: refs.bib\n",
        corpo=corpo("Introduction"),
        arquivos={"refs.bib": bib()},
    )
    assert r.ok, r.log
    log = "\n".join(avisos(r))
    assert 'lang: "fr"' in log and "português" in log, log
    texto = junta(r.depois("INTRODUCTION"))
    assert "See Figura 1, Quadro 1 and Apêndice A." in texto, texto
    assert "Figura 1 – A figure" in texto, texto
    assert "Fonte: Own work (2025)." in texto, texto
    assert "APÊNDICE A – INTERVIEW GUIDE" in texto, texto
    assert "REFERÊNCIAS" in texto, texto
    refs = junta(r.depois("REFERÊNCIAS"))
    assert "Disponível em: https://www.ibge.gov.br" in refs, refs


def test_titulo_traduzido_ausente(render):
    r = render("lang-en-sem-traducao", yaml="lang: en-US\n",
               corpo="# Introduction\n\nText.\n")
    assert r.ok, r.log
    log = "\n".join(avisos(r))
    assert ('Trabalho em outro idioma: preencha "titulo-traduzido" (o manual exige '
            'o título em português na folha de aprovação).') in log, log
    assert "não é suportado" not in log, log
    texto = junta(r.depois("INTRODUCTION"))
    assert "Text." in texto, texto
