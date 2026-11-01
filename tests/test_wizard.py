"""_schema.yml e _snippets.json (Quarto Wizard) não podem divergir dos filtros."""
import json
import re
from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

RAIZ = Path(__file__).resolve().parent.parent
EXT = RAIZ / "_extensions" / "ufla-normas"
FORMATO = "ufla-normas-pdf"

# Chaves de _extension.yml que configuram o formato e não são dados do trabalho.
CONFIGURACAO = {
    "template", "pdf-engine", "lang", "csl", "top-level-division", "filters",
    "crossref", "language", "fig-cap-location", "tbl-cap-location", "keep-tex",
    "date-format", "toc", "number-sections",
    # declarado em _extension.yml, mas nenhum filtro ou template o lê
    "indicadores-impacto",
}


def _schema():
    return yaml.safe_load((EXT / "_schema.yml").read_text(encoding="utf-8"))


def _campos_schema():
    return _schema()["formats"][FORMATO]


def _snippets():
    return json.loads((EXT / "_snippets.json").read_text(encoding="utf-8"))


def _lua(nome):
    return (EXT / "filtros" / nome).read_text(encoding="utf-8")


def _expande(linha):
    """Troca os marcadores do snippet pelo texto padrão deles."""
    linha = re.sub(r"\$\{\d+\|([^,|]*)[^|]*\|\}", r"\1", linha)
    linha = re.sub(r"\$\{\d+:([^}]*)\}", r"\1", linha)
    return re.sub(r"\$\d+", "", linha)


def test_schema_cobre_os_campos_de_extension_yml():
    ext = yaml.safe_load((EXT / "_extension.yml").read_text(encoding="utf-8"))
    dados = set(ext["contributes"]["formats"]["pdf"]) - CONFIGURACAO
    assert dados - set(_campos_schema()) == set()


def test_campos_do_schema_sao_conhecidos_por_validar_lua():
    lua = _lua("validar.lua")
    bloco = lua[lua.index("local CAMPOS_CONHECIDOS"):lua.index("local PREFIXOS_CONHECIDOS")]
    conhecidos = set(re.findall(r'"([^"]+)"', bloco))
    assert set(_campos_schema()) - conhecidos == set()


def test_tipo_do_schema_e_o_de_tipos_lua():
    tipos = re.findall(r'^\s*\["([a-z-]+)"\]\s*=\s*\{', _lua("tipos.lua"), re.M)
    assert tipos
    assert _campos_schema()["tipo"]["enum"] == tipos


def test_formato_do_schema_e_o_de_util_lua():
    bloco = re.search(r"M\.FORMATOS\s*=\s*\{([^}]*)\}", _lua("util.lua")).group(1)
    assert _campos_schema()["formato"]["enum"] == re.findall(r'"([^"]+)"', bloco)


def test_classes_do_schema_sao_lidas_pelos_filtros():
    filtros = _lua("artigos.lua") + _lua("elementos.lua")
    for classe in _schema()["classes"]:
        assert f'classes:includes("{classe}")' in filtros, classe


def test_snippets_tem_o_formato_do_vscode():
    snippets = _snippets()
    assert snippets
    prefixos = [s["prefix"] for s in snippets.values()]
    assert len(prefixos) == len(set(prefixos))
    for nome, s in snippets.items():
        assert isinstance(s["body"], list), nome
        assert s["description"], nome


def test_snippet_de_yaml_so_usa_campos_conhecidos():
    lua = _lua("validar.lua")
    bloco = lua[lua.index("local CAMPOS_CONHECIDOS"):lua.index("local PREFIXOS_CONHECIDOS")]
    conhecidos = set(re.findall(r'"([^"]+)"', bloco))
    corpo = "\n".join(_expande(l) for l in _snippets()["Versão final"]["body"])
    assert set(yaml.safe_load(corpo)) - conhecidos == set()


def test_campos_dentro_de_format_chegam_ao_pdf(render):
    """O Wizard só completa opções dentro de format: ufla-normas-pdf:."""
    r = render(
        "wizard_aninhado",
        yaml_base=False,
        yaml=(
            'title: "Título de teste"\n'
            'author: "Fulano de Tal"\n'
            "format:\n"
            "  ufla-normas-pdf:\n"
            "    tipo: tese\n"
            '    ano: "2026"\n'
            '    curso: "Curso Aninhado"\n'
            '    orientadora: "Profa. Aninhada"\n'
        ),
        corpo="# Introdução\n\nTexto.",
    )
    assert r.ok, r.log
    assert "Falta preencher" not in r.log
    assert "Tese apresentada" in r.texto
    assert "Curso Aninhado" in r.texto
    assert "Profa. Aninhada" in r.texto


def test_snippets_de_corpo_renderizam(render):
    snippets = _snippets()
    nomes = ["Figura", "Figura em célula R", "Tabela", "Quadro", "Apêndice", "Anexo"]
    corpo = "# Introdução\n\nTexto.\n\n" + "\n\n".join(
        "\n".join(_expande(l) for l in snippets[n]["body"]).replace("fig-nome", f"fig-{i}")
        for i, n in enumerate(nomes)
    )
    png = (RAIZ / "imgs" / "grafico-exemplo.png").read_bytes()
    r = render("wizard_snippets", corpo=corpo, arquivos={"imgs/grafico.png": png})
    assert r.ok, r.log
    assert "${" not in r.texto
    for esperado in ("Figura 1", "Figura 2", "Tabela 1", "Quadro 1", "APÊNDICE A", "ANEXO A"):
        assert esperado in r.texto, esperado
    assert "Fonte:" in r.texto


def test_snippets_de_artigos_renderizam(render):
    snippets = _snippets()
    corpo = "\n\n".join(
        "\n".join(_expande(l) for l in snippets[n]["body"]) for n in ("Parte", "Artigo")
    ) + "\n\n## Introdução\n\nTexto."
    r = render("wizard_artigos", yaml="formato: artigos\n", corpo=corpo)
    assert r.ok, r.log
    assert "ARTIGO 1" in r.texto
