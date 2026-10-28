import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parent.parent
EXT = RAIZ / "_extensions" / "ufla-normas"
SAIDA = RAIZ / "tests" / "_out"

YAML_BASE = {
    "title": '"Título de teste"',
    "author": '"Fulano de Tal"',
    "ano": '"2025"',
    "abstract": '"Resumo de teste."',
    "keywords": '"palavra um; palavra dois"',
    "abstract-en": '"Test abstract."',
    "keywords-en": '"word one; word two"',
    "tipo": "dissertacao",
    "curso": '"Agronomia/Fitotecnia"',
    "orientador": '"Prof. Dr. Fulano"',
}
FORMAT_BASE = "format:\n  ufla-normas-pdf: default\n"


def _chaves_topo(yaml: str) -> set[str]:
    chaves = set()
    for linha in yaml.splitlines():
        if linha and not linha[0].isspace() and not linha.startswith(("#", "-")) and ":" in linha:
            chaves.add(linha.split(":", 1)[0].strip())
    return chaves


def _monta_yaml(yaml: str, yaml_base: bool) -> str:
    if not yaml_base:
        return yaml.rstrip("\n") + "\n" if yaml.strip() else ""
    sobrescritas = _chaves_topo(yaml)
    base = "".join(f"{k}: {v}\n" for k, v in YAML_BASE.items() if k not in sobrescritas)
    if "format" not in sobrescritas:
        base += FORMAT_BASE
    return base + (yaml.rstrip("\n") + "\n" if yaml.strip() else "")


@dataclass
class Render:
    ok: bool
    log: str
    texto: str
    pdf: Path | None = None

    def pagina(self, n: int) -> str:
        paginas = self.texto.split("\f")
        return paginas[n - 1] if 1 <= n <= len(paginas) else ""

    def depois(self, marcador: str) -> str:
        """Texto após a primeira linha que contém `marcador` (sem diferenciar
        maiúsculas), buscando só nas páginas posteriores à do SUMÁRIO para
        pular o próprio sumário. Sem página SUMÁRIO, busca no texto todo."""
        paginas = self.texto.split("")
        inicio = 0
        for i, pag in enumerate(paginas):
            if "SUMÁRIO" in pag:
                inicio = i + 1
                break
        alvo = "".join(paginas[inicio:])
        chave = marcador.casefold()
        linhas = alvo.splitlines(keepends=True)
        for i, linha in enumerate(linhas):
            if chave in linha.casefold():
                return "".join(linhas[i + 1:])
        return ""


@pytest.fixture
def render():
    def _render(nome, yaml="", corpo="", arquivos=None, yaml_base=True):
        pasta = SAIDA / nome
        if pasta.exists():
            shutil.rmtree(pasta)
        destino = pasta / "_extensions" / "ufla-normas"
        shutil.copytree(EXT, destino)
        for rel, conteudo in (arquivos or {}).items():
            p = pasta / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(conteudo, encoding="utf-8")
        qmd = pasta / f"{nome}.qmd"
        qmd.write_text(
            "---\n" + _monta_yaml(yaml, yaml_base) + "---\n\n" + corpo + "\n",
            encoding="utf-8",
        )
        try:
            proc = subprocess.run(
                ["quarto", "render", qmd.name],
                cwd=pasta, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=300,
            )
            log = (proc.stdout or "") + (proc.stderr or "")
            rc = proc.returncode
        except subprocess.TimeoutExpired as e:
            log = f"TIMEOUT após 300 s\n{e.stdout or ''}{e.stderr or ''}"
            rc = -1
        pdf = pasta / f"{nome}.pdf"
        texto = ""
        if pdf.exists():
            t = subprocess.run(
                ["pdftotext", "-enc", "UTF-8", "-layout", str(pdf), "-"],
                capture_output=True, encoding="utf-8", errors="replace",
            )
            texto = t.stdout or ""
        return Render(ok=(rc == 0 and pdf.exists()), log=log, texto=texto,
                      pdf=pdf if pdf.exists() else None)

    return _render


def fonte_de(pdf_path, trecho, depois=None):
    """Nome da fonte do primeiro trecho de texto (span do PyMuPDF) que contém
    `trecho`. Com `depois`, só procura após a última linha cujo texto é
    exatamente `depois` (por exemplo, o título "REFERÊNCIAS", pulando o
    sumário). Devolve "" se não achar."""
    pymupdf = pytest.importorskip("pymupdf")
    spans = []
    with pymupdf.open(str(pdf_path)) as doc:
        for pagina in doc:
            for bloco in pagina.get_text("dict")["blocks"]:
                for linha in bloco.get("lines", []):
                    texto_linha = "".join(s["text"] for s in linha["spans"]).strip()
                    spans.append(("linha", texto_linha))
                    for s in linha["spans"]:
                        spans.append((s["font"], s["text"]))
    inicio = 0
    if depois is not None:
        marcas = [i for i, (tipo, txt) in enumerate(spans)
                  if tipo == "linha" and txt == depois]
        if not marcas:
            return ""
        inicio = marcas[-1] + 1
    for fonte, texto in spans[inicio:]:
        if fonte != "linha" and trecho in texto:
            return fonte
    return ""
