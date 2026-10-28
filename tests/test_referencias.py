"""Citações e referências (citeproc + ufla-abnt.csl), seções numeradas a
partir do capítulo e texto Unicode com LuaLaTeX."""
import re

import pytest

from conftest import RAIZ, SAIDA, fonte_de

FIXTURES = RAIZ / "tests" / "fixtures"


def normaliza(s: str) -> str:
    """Junta as linhas do pdftotext: hífen no fim da linha cola na linha
    seguinte, quebras dentro de URL somem e o resto do espaço em branco vira
    um espaço só."""
    s = re.sub(r"-[ \t]*\n\s*", "-", s)
    s = re.sub(r"\s+", " ", s)
    anterior = None
    while anterior != s:
        anterior = s
        s = re.sub(r"(https?://\S*[/._~=?&#])\s(?=[a-z0-9%])", r"\1", s)
    return s.strip()


def _bib(nome: str) -> str:
    return (FIXTURES / f"{nome}.bib").read_text(encoding="utf-8")


def _chaves(bib: str) -> list[str]:
    return re.findall(r"@\w+\s*\{\s*([^,\s]+)\s*,", bib)


_CACHE = {}


def _render_fixture(render, nome):
    """Renderiza uma vez por arquivo .bib, citando todas as chaves."""
    if nome not in _CACHE:
        bib = _bib(nome)
        cites = " ".join(f"[@{k}]" for k in _chaves(bib))
        _CACHE[nome] = render(
            f"refs-{nome}",
            yaml="bibliography: refs.bib",
            corpo=f"# Introdução\n\nCitações: {cites}.\n",
            arquivos={"refs.bib": bib},
        )
    return _CACHE[nome]


SILVA = ("SILVA, João da et al. Métodos de análise estatística em ciências "
         "agrárias. Ciência e Agrotecnologia, v. 47, n. 2, p. 123-145, mar. 2023.")

SOUZA = ("SOUZA, Ana Paula. Modelagem da produtividade do café. 2024. "
         "Dissertação (Mestrado em Estatística e Experimentação Agropecuária) "
         "– Universidade Federal de Lavras, Lavras, 2024.")

CASOS = [
    ("zotero", "silva_metodos_2023", SILVA),
    ("zotero", "souza_modelagem_2024", SOUZA),
    ("zotero", "instituto_brasileiro_de_geografia_e_estatistica_censo_2023",
     "INSTITUTO BRASILEIRO DE GEOGRAFIA E ESTATÍSTICA. Censo Demográfico 2022. "
     "IBGE, 2023. Disponível em: https://www.ibge.gov.br/estatisticas/sociais/"
     "populacao/22827-censo-demografico-2022.html. Acesso em: 20 out. 2026."),
    ("zotero", "wickham_r_2023",
     "WICKHAM, Hadley; ÇETINKAYA-RUNDEL, Mine; GROLEMUND, Garrett. R for data "
     "science: import, tidy, transform, visualize, and model data. 2. ed. "
     "Sebastopol: O’Reilly, 2023."),
    ("zotero", "costa_redes_2022",
     "COSTA, Bruno; FERREIRA, Carla. Redes neurais para previsão de preços. "
     "In: Anais do Simpósio Brasileiro de Pesquisa Operacional. Campinas: "
     "Sobrapo, 2022. p. 1-12."),
    ("zotero-biblatex", "silva_metodos_2023", SILVA),
    ("zotero-biblatex", "souza_modelagem_2024",
     "SOUZA, Ana Paula. Modelagem da produtividade do café. 2024. Dissertação "
     "(mestrado) – Universidade Federal de Lavras, Lavras, 2024."),
]


@pytest.mark.parametrize("fixture, chave, esperado", CASOS)
def test_exportacoes_reais(render, fixture, chave, esperado):
    r = _render_fixture(render, fixture)
    assert r.ok, r.log
    refs = normaliza(r.depois("REFERÊNCIAS"))
    assert normaliza(esperado) in refs, refs


EXTRAS_BIB = """
@book{silva_a_2020,
  author = {Silva, José},
  title = {Primeiro livro},
  publisher = {Editora UFLA},
  address = {Lavras},
  year = {2020},
}

@book{silva_b_2020,
  author = {Silva, José},
  title = {Segundo livro},
  publisher = {Editora UFLA},
  address = {Lavras},
  year = {2020},
}

@book{silva_sd,
  author = {Silva, José},
  title = {Livro sem data},
  publisher = {Editora UFLA},
  address = {Lavras},
}
"""

CITACOES = [
    ("[@silva_metodos_2023]", "(Silva et al., 2023)"),
    ("@souza_modelagem_2024", "Souza (2024)"),
    ("[@souza_modelagem_2024, p. 45]", "(Souza, 2024, p. 45)"),
    ("[ver @souza_modelagem_2024, p. 45]", "(ver Souza, 2024, p. 45)"),
    ("@souza_modelagem_2024 [p. 45]", "Souza (2024, p. 45)"),
    ("Souza [-@souza_modelagem_2024]", "Souza (2024)"),
    ("[@souza_modelagem_2024; @costa_redes_2022]",
     "(Costa; Ferreira, 2022; Souza, 2024)"),
    ("@costa_redes_2022", "Costa e Ferreira (2022)"),
    ("[@silva_a_2020; @silva_b_2020]", "(Silva, 2020a, 2020b)"),
    ("[@silva_sd]", "(Silva, [s.d.])"),
]


def test_sintaxes_de_citacao(render):
    corpo = "# Introdução\n\n" + "\n\n".join(
        f"Caso {i}: {md}." for i, (md, _) in enumerate(CITACOES, 1))
    r = render(
        "citacoes",
        yaml="bibliography: refs.bib",
        corpo=corpo,
        arquivos={"refs.bib": _bib("zotero") + EXTRAS_BIB},
    )
    assert r.ok, r.log
    texto = normaliza(r.depois("INTRODUÇÃO"))
    for i, (_, esperado) in enumerate(CITACOES, 1):
        assert f"Caso {i}: {esperado}." in texto, (i, texto)
    assert "??" not in r.texto


def test_secoes_numeradas(render):
    r = render("secoes", corpo=(
        "# Introdução\n\nTexto.\n\n## Sub\n\nMais texto.\n\n"
        "# Conclusão\n\nFim."))
    assert r.ok, r.log
    texto = normaliza(r.texto)
    assert "1 INTRODUÇÃO" in texto
    assert "1.1 Sub" in texto
    assert "2 CONCLUSÃO" in texto
    assert "0.1" not in r.texto


def test_unicode(render):
    simbolos = ["μ", "β", "≤", "°", "±", "≥", "ã", "ç", "ő", "ł"]
    r = render("unicode", corpo="# Introdução\n\n" + " ".join(simbolos) + "\n")
    assert r.ok, r.log
    for s in simbolos:
        assert s in r.texto, s


def test_caminho_com_espaco_acento_underscore(render):
    caminho = "minhas_refs/3° período/refs final.bib"
    r = render(
        "caminho-refs",
        yaml=f'bibliography: "{caminho}"',
        corpo="# Introdução\n\nVer [@silva2023metodos].",
        arquivos={caminho: _bib("scholar")},
    )
    assert r.ok, r.log
    assert "(Silva et al., 2023)" in normaliza(r.depois("INTRODUÇÃO"))


def test_mesmo_autor_mesmo_ano(render):
    r = render(
        "mesmo-ano",
        yaml="bibliography: refs.bib",
        corpo="# Introdução\n\nVer [@silva_a_2020; @silva_b_2020] e "
              "@silva_a_2020.",
        arquivos={"refs.bib": EXTRAS_BIB},
    )
    assert r.ok, r.log
    texto = normaliza(r.depois("INTRODUÇÃO"))
    assert "(Silva, 2020a, 2020b)" in texto
    assert "Silva (2020a)" in texto
    refs = normaliza(r.depois("REFERÊNCIAS"))
    assert "Primeiro livro. Lavras: Editora UFLA, 2020a." in refs
    assert "Segundo livro. Lavras: Editora UFLA, 2020b." in refs


def test_sem_ano(render):
    r = render(
        "sem-ano",
        yaml="bibliography: refs.bib",
        corpo="# Introdução\n\nVer [@silva_sd].",
        arquivos={"refs.bib": EXTRAS_BIB},
    )
    assert r.ok, r.log
    assert "(Silva, [s.d.])" in normaliza(r.depois("INTRODUÇÃO"))
    refs = normaliza(r.depois("REFERÊNCIAS"))
    assert "SILVA, José. Livro sem data. Lavras: Editora UFLA, [s.d.]." in refs


def test_negrito_titulos(render):
    r = _render_fixture(render, "zotero")
    assert r.ok, r.log
    fonte = lambda t: fonte_de(r.pdf, t, depois="REFERÊNCIAS")  # noqa: E731
    assert "Bold" in fonte("Agrotecnologia")
    assert "Italic" in fonte("et al.")
    assert "Bold" in fonte("R for data")  # o título quebra a linha
    redes = fonte("Redes neurais")
    assert redes and "Bold" not in redes


# --- Normalização das referências e chaves inexistentes ---------------------

RESTOS_BIB = r"""
@book{restos_livro,
  author = {Pereira, Jos{\'e}},
  title = {{M{\'e}todos} \& {T}{\'e}cnicas},
  publisher = {" O'Reilly Media, Inc."},
  address = {Lavras},
  year = {2020},
}

@book{restos_negrito,
  author = {Almeida, Rita},
  title = {\textbf{Livro}},
  publisher = {Editora UFLA},
  address = {Lavras},
  year = {2021},
}

@phdthesis{restos_tese,
  author = {Barbosa, Caio},
  title = {Ensaios},
  type = {Disserta{\c{c}}{\~a}o ({Mestrado})},
  school = {Universidade Federal de Lavras},
  address = {Lavras},
  year = {2022},
}
"""


def test_restos_latex_no_bib(render):
    r = render(
        "restos-latex",
        yaml="bibliography: refs.bib",
        corpo="# Introdução\n\n[@restos_livro; @restos_negrito; @restos_tese].",
        arquivos={"refs.bib": RESTOS_BIB},
    )
    assert r.ok, r.log
    refs = normaliza(r.depois("REFERÊNCIAS"))
    assert "Métodos & Técnicas" in refs, refs
    assert "Lavras: O’Reilly Media, Inc., 2020." in refs, refs
    assert "Livro. Lavras: Editora UFLA, 2021." in refs, refs
    assert "2022. Dissertação (Mestrado) – Universidade Federal" in refs, refs
    for c in "{}\\\"":
        assert c not in refs, (c, refs)


def test_zotero_dissertacao_sem_chaves(render):
    r = _render_fixture(render, "zotero")
    assert r.ok, r.log
    assert normaliza(SOUZA) in normaliza(r.depois("REFERÊNCIAS"))


def test_chave_inexistente(render):
    r = render(
        "chave-inexistente",
        yaml="bibliography: refs.bib",
        corpo=("# Introdução {#sec-intro}\n\n"
               "Ver [@silva_metodo_2023] e [@silva_metodos_2023; @zzz_nada]. "
               "De novo [@silva_metodo_2023]. Volte à @sec-intro.\n"),
        arquivos={"refs.bib": _bib("zotero")},
    )
    assert r.ok, r.log
    assert ("[ufla-normas] AVISO: Citação não encontrada: @silva_metodo_2023"
            in r.log), r.log
    assert "@silva_metodos_2023" in r.log  # sugestão
    assert r.log.count("Citação não encontrada: @silva_metodo_2023") == 1, r.log
    assert "Citação não encontrada: @zzz_nada" in r.log
    assert "sec-intro" not in r.log
    texto = normaliza(r.depois("INTRODUÇÃO"))
    assert "Ver [silva_metodo_2023?] e (Silva et al., 2023) [zzz_nada?]." in texto, texto
    assert "[silva_metodo_2023?]" in r.texto
    # o marcador sai em vermelho e negrito
    pymupdf = pytest.importorskip("pymupdf")
    with pymupdf.open(str(r.pdf)) as doc:
        spans = [s for p in doc for b in p.get_text("dict")["blocks"]
                 for ln in b.get("lines", []) for s in ln["spans"]
                 if "silva_metodo_2023?" in s["text"]]
    assert spans
    assert all(s["color"] == 0xFF0000 and "Bold" in s["font"] for s in spans), spans


def _conta_depois_do_sumario(r, palavra):
    paginas = r.texto.split("\f")
    inicio = next(i + 1 for i, p in enumerate(paginas) if "SUMÁRIO" in p)
    return "".join(paginas[inicio:]).casefold().count(palavra.casefold())


@pytest.mark.parametrize("titulo, refs_div", [
    ("# Referências {.unnumbered}", True),
    ("# REFERÊNCIAS", False),
])
def test_titulo_referencias_duplicado(render, titulo, refs_div):
    corpo = "# Introdução\n\nVer [@wickham_r_2023].\n\n" + titulo + "\n\n"
    if refs_div:
        corpo += "::: {#refs}\n:::\n"
    r = render(
        "titulo-refs-" + ("div" if refs_div else "fim"),
        yaml="bibliography: refs.bib",
        corpo=corpo,
        arquivos={"refs.bib": _bib("zotero")},
    )
    assert r.ok, r.log
    assert _conta_depois_do_sumario(r, "REFERÊNCIAS") == 1, r.texto
    assert "WICKHAM, Hadley" in r.depois("REFERÊNCIAS")


TESES_BIB = """
@mastersthesis{tese_mestrado,
  author = {Moura, Lia},
  title = {Mestrado sem tipo},
  school = {Universidade Federal de Lavras},
  address = {Lavras},
  year = {2023},
}

@phdthesis{tese_doutorado,
  author = {Nunes, Davi},
  title = {Doutorado sem tipo},
  school = {Universidade Federal de Lavras},
  address = {Lavras},
  year = {2024},
}
"""


@pytest.mark.parametrize("lang, mestrado, doutorado", [
    ("pt-BR", "Dissertação (Mestrado)", "Tese (Doutorado)"),
    ("en", "Master’s thesis", "Doctoral thesis"),
])
def test_genero_tese_sem_tipo(render, lang, mestrado, doutorado):
    r = render(
        f"teses-{lang}",
        yaml=f"bibliography: refs.bib\nlang: {lang}",
        corpo="# Introdução\n\n[@tese_mestrado; @tese_doutorado].",
        arquivos={"refs.bib": TESES_BIB},
    )
    assert r.ok, r.log
    texto = normaliza(r.texto).replace("'", "’")
    assert (f"Mestrado sem tipo. 2023. {mestrado} – Universidade Federal de "
            "Lavras, Lavras, 2023.") in texto, texto
    assert (f"Doutorado sem tipo. 2024. {doutorado} – Universidade Federal de "
            "Lavras, Lavras, 2024.") in texto, texto
    assert "Mathesis" not in texto and "Trabalho acadêmico" not in texto


TESE_ONLINE_BIB = """
@mastersthesis{tese_online,
  author = {Souza, Ana Paula},
  title = {Modelagem online},
  type = {Dissertação (Mestrado em Estatística)},
  school = {Universidade Federal de Lavras},
  address = {Lavras},
  year = {2024},
  url = {https://repositorio.ufla.br/handle/1/123},
  urldate = {2025-05-05},
}
"""


def test_tese_online_acesso(render):
    r = render(
        "tese-online",
        yaml="bibliography: refs.bib",
        corpo="# Introdução\n\n[@tese_online].",
        arquivos={"refs.bib": TESE_ONLINE_BIB},
    )
    assert r.ok, r.log
    refs = normaliza(r.depois("REFERÊNCIAS"))
    assert ("SOUZA, Ana Paula. Modelagem online. 2024. Dissertação (Mestrado em "
            "Estatística) – Universidade Federal de Lavras, Lavras, 2024. "
            "Disponível em: https://repositorio.ufla.br/handle/1/123. "
            "Acesso em: 5 maio 2025.") in refs, refs


MISC_BIB = """
@misc{ibge_pnad_2024,
  author = {{Instituto Brasileiro de Geografia e Estatística}},
  title = {Pesquisa nacional por amostra de domicílios},
  journal = {IBGE},
  address = {Rio de Janeiro},
  publisher = {Instituto Brasileiro de Geografia e Estatística},
  year = {2024},
}

@misc{embrapa_solos_2021,
  author = {{Empresa Brasileira de Pesquisa Agropecuária}},
  title = {Mapa de solos},
  howpublished = {Portal Embrapa},
  address = {Brasília},
  year = {2021},
}
"""


def test_misc_local_editora(render):
    r = render(
        "misc-local",
        yaml="bibliography: refs.bib",
        corpo="# Introdução\n\n[@ibge_pnad_2024; @embrapa_solos_2021].",
        arquivos={"refs.bib": MISC_BIB},
    )
    assert r.ok, r.log
    refs = normaliza(r.depois("REFERÊNCIAS"))
    assert ("INSTITUTO BRASILEIRO DE GEOGRAFIA E ESTATÍSTICA. Pesquisa nacional "
            "por amostra de domicílios. IBGE. Rio de Janeiro: Instituto "
            "Brasileiro de Geografia e Estatística, 2024.") in refs, refs
    assert ("EMPRESA BRASILEIRA DE PESQUISA AGROPECUÁRIA. Mapa de solos. "
            "Brasília: Portal Embrapa, 2021.") in refs, refs
    for colado in ("IBGERio", "solosBras", "JaneiroInstituto", ", ,"):
        assert colado not in refs, (colado, refs)


def test_crossref_nao_e_citacao(render):
    corpo = (
        "# Introdução {#sec-intro}\n\n"
        "Ver [@wickham_r_2023], @fig-um, @tbl-dois e @sec-intro.\n\n"
        "![Uma figura](_extensions/ufla-normas/logoUFLA.pdf){#fig-um width=20%}\n\n"
        "| a | b |\n|---|---|\n| 1 | 2 |\n\n: Uma tabela {#tbl-dois}\n"
    )
    r = render(
        "crossref-nao-citacao",
        yaml="bibliography: refs.bib",
        corpo=corpo,
        arquivos={"refs.bib": _bib("zotero")},
    )
    assert r.ok, r.log
    assert "Citação não encontrada" not in r.log, r.log
    assert "?]" not in r.texto, r.texto
    texto = normaliza(r.depois("INTRODUÇÃO"))
    # numeração sequencial de figuras e tabelas (manual 3.2.9)
    assert "Figura 1, Tabela 1 e Seção 1." in texto, texto
    assert "WICKHAM, Hadley" in r.depois("REFERÊNCIAS")


def test_callout_e_id_nao_sao_citacao(render):
    """Callouts (@tip-, @nte-, ...) e qualquer @chave igual ao id de um
    elemento do documento não são citações: nada de "[chave?]" no .tex nem
    no PDF, e o callout aparece no PDF."""
    nome = "callout-nao-citacao"
    corpo = (
        "# Introdução\n\n"
        "Ver [@wickham_r_2023], @tip-x, @nte-y e @meu-alvo.\n\n"
        "::: {#tip-x .callout-tip}\n## Dica\nConteúdo da dica.\n:::\n\n"
        "::: {#nte-y .callout-note}\nNota.\n:::\n\n"
        "[Um alvo]{#meu-alvo}\n"
    )
    r = render(
        nome,
        yaml="bibliography: refs.bib\nkeep-tex: true",
        corpo=corpo,
        arquivos={"refs.bib": _bib("zotero")},
    )
    tex = SAIDA / nome / f"{nome}.tex"
    assert tex.exists(), r.log
    assert "Citação não encontrada" not in r.log, r.log
    assert "textcolor{red}" not in tex.read_text(encoding="utf-8")
    assert r.ok, r.log
    assert "?]" not in r.texto, r.texto
    texto = normaliza(r.depois("INTRODUÇÃO"))
    assert "Conteúdo da dica." in texto and "Nota." in texto, texto
    assert "WICKHAM, Hadley" in r.depois("REFERÊNCIAS")
