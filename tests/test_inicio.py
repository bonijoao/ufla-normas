"""Começo do trabalho: o modelo inicial (`template.qmd` + `referencias.bib`,
o que o `quarto use template` copia) renderiza só com o lembrete da versão
final, sem dados de defesa inventados; documentos
da 1.x continuam renderizando; o `.quartoignore` deixa de fora os arquivos
de desenvolvimento."""
import re
import subprocess

import pytest

from conftest import RAIZ

PREFIXO = "[ufla-normas]"


def separa_yaml(texto: str) -> tuple[str, str]:
    """(YAML sem os ---, corpo) de um .qmd."""
    m = re.match(r"---\r?\n(.*?)\r?\n---\r?\n(.*)", texto, re.S)
    assert m, "o .qmd não começa com um bloco YAML"
    return m.group(1), m.group(2)


def tem_tag_v1() -> bool:
    return subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", "v1.0.0^{commit}"], cwd=RAIZ,
        capture_output=True,
    ).returncode == 0


def git_show(caminho: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"v1.0.0:{caminho}"], cwd=RAIZ,
        capture_output=True, check=True,
    ).stdout


def imagens_do_modelo(corpo: str) -> dict[str, bytes]:
    """Arquivos de imagem citados no corpo como ![...](caminho)."""
    arquivos = {}
    for caminho in re.findall(r"!\[[^\]]*\]\(([^)\s]+)\)", corpo):
        if not caminho.startswith("_extensions/"):
            arquivos[caminho] = (RAIZ / caminho).read_bytes()
    return arquivos


def test_template_renderiza_so_com_o_lembrete(render):
    """O modelo não traz banca, ficha nem indicadores inventados (ficam
    comentados até a defesa), então o único aviso é o lembrete da versão
    final de dissertações e teses."""
    yaml, corpo = separa_yaml((RAIZ / "template.qmd").read_text(encoding="utf-8"))
    arquivos = {"referencias.bib": (RAIZ / "referencias.bib").read_text(encoding="utf-8")}
    arquivos.update(imagens_do_modelo(corpo))
    r = render("inicio", yaml=yaml, corpo=corpo, arquivos=arquivos, yaml_base=False)
    assert r.ok, r.log
    avisos = [linha for linha in r.log.splitlines() if PREFIXO in linha]
    assert len(avisos) == 1, avisos
    assert "Lembrete para a versão final" in avisos[0], avisos
    # nada de folha de aprovação ou ficha com dados de exemplo
    assert "APROVADA em" not in r.texto
    assert "Ficha catalográfica elaborada" not in r.texto
    assert "INDICADORES DE IMPACTO" not in r.texto
    assert "??" not in r.texto
    assert "?]" not in r.texto          # nenhuma citação sem entrada
    assert "[preencha:" not in r.texto
    assert "1 INTRODUÇÃO" in r.texto
    # quadro, figura e tabela numerados cada um a partir de 1
    for rotulo in ("Quadro 1 –", "Figura 1 –", "Tabela 1 –", "APÊNDICE A –"):
        assert rotulo in r.texto, rotulo


def test_referencias_do_modelo_sem_latex():
    """O .bib de exemplo é texto puro: nada de \\textbf, {\\'e} etc."""
    bib = (RAIZ / "referencias.bib").read_text(encoding="utf-8")
    assert "\\" not in bib
    tipos = {t.lower() for t in re.findall(r"^@(\w+)\s*\{", bib, re.M)}
    assert len(re.findall(r"^@\w+\s*\{", bib, re.M)) >= 10, tipos


def test_documento_v1_renderiza(render):
    """O template.qmd da 1.0.0, com o referencias.bib da 1.0.0 e o caminho
    _extensions/bonijoao/ufla-normas/referencias.bib que o README da 1.x
    mandava usar (é onde o `quarto add` instala a extensão)."""
    if not tem_tag_v1():
        pytest.skip("tag v1.0.0 ausente neste clone (rode git fetch --tags)")
    yaml, corpo = separa_yaml(git_show("template.qmd").decode("utf-8"))
    arquivos = {
        "referencias.bib": git_show("referencias.bib").decode("utf-8"),
        "imgs/logoUFLA.pdf": git_show("imgs/logoUFLA.pdf"),
        "_extensions/bonijoao/ufla-normas/referencias.bib":
            (RAIZ / "_extensions" / "ufla-normas" / "referencias.bib").read_text(encoding="utf-8"),
    }
    r = render("v1", yaml=yaml, corpo=corpo, arquivos=arquivos, yaml_base=False)
    assert r.ok, r.log
    assert "??" not in r.texto
    assert "?]" not in r.texto
    assert "1 INTRODUÇÃO" in r.texto
    assert "REFERÊNCIAS" in r.texto


def test_quartoignore():
    linhas = (RAIZ / ".quartoignore").read_text(encoding="utf-8").splitlines()
    linhas = {linha.strip() for linha in linhas}
    for item in ("tests/", "docs/", "CHANGELOG.md", ".superpowers/"):
        assert item in linhas, item
