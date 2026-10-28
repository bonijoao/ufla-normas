"""Citações e referências (citeproc + ufla-abnt.csl), seções numeradas a
partir do capítulo e texto Unicode com LuaLaTeX."""
import re

import pytest

from conftest import RAIZ, fonte_de

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

CASOS = [
    ("zotero", "silva_metodos_2023", SILVA),
    pytest.param(
        "zotero", "souza_modelagem_2024",
        "SOUZA, Ana Paula. Modelagem da produtividade do café. 2024. "
        "Dissertação (Mestrado em Estatística e Experimentação Agropecuária) "
        "– Universidade Federal de Lavras, Lavras, 2024.",
        marks=pytest.mark.xfail(strict=True, reason="Task 2"),
    ),
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
