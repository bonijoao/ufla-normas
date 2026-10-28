"""Validação do YAML (filtros/validar.lua): erros que param a renderização,
avisos em português e o marcador [preencha: campo] no PDF."""
import re

PREFIXO = "[ufla-normas]"

BIB = """@book{silva2020,
  author = {Silva, João},
  title = {Livro de teste},
  publisher = {Editora UFLA},
  address = {Lavras},
  year = {2020}
}
"""

PALAVRAS_PT = ("ação à análise então é já também através pós-graduação "
               "região produção índice").split()


def texto_com(n: int) -> str:
    """Texto em português com exatamente `n` palavras (muitas com acento)."""
    return " ".join(PALAVRAS_PT[i % len(PALAVRAS_PT)] for i in range(n)) + "."


def avisos(r) -> list[str]:
    return [linha for linha in r.log.splitlines() if PREFIXO in linha]


def junta(s: str) -> str:
    return re.sub(r"\s+", " ", s)


# Erros -------------------------------------------------------------------

def test_bib_inexistente(render):
    r = render("val_bib_inexistente", yaml="bibliography: refs.bib\n",
               corpo="Texto [@silva2020].")
    assert not r.ok
    assert 'Não encontrei o arquivo de referências "refs.bib"' in r.log
    assert "Procurei em:" in r.log
    assert "val_bib_inexistente" in r.log  # pasta absoluta do .qmd


def test_bib_em_pasta_com_acento_e_lista(render):
    yaml = 'bibliography:\n  - "dados °/refs ç.bib"\n  - outra.bib\n'
    r = render("val_bib_lista", yaml=yaml, corpo="Texto [@silva2020].",
               arquivos={"dados °/refs ç.bib": BIB, "outra.bib": ""})
    assert r.ok, r.log
    assert "Não encontrei" not in r.log
    assert "SILVA, Jo" in r.texto


def test_bib_lista_com_um_faltando(render):
    yaml = "bibliography:\n  - refs.bib\n  - falta.bib\n"
    r = render("val_bib_lista_falta", yaml=yaml, arquivos={"refs.bib": BIB})
    assert not r.ok
    assert 'Não encontrei o arquivo de referências "falta.bib"' in r.log
    assert 'Não encontrei o arquivo de referências "refs.bib"' not in r.log


def test_tipo_invalido(render):
    r = render("val_tipo_invalido", yaml="tipo: dissertação\n")
    assert not r.ok
    assert 'tipo: "dissertação" não existe' in r.log
    assert "dissertacao" in r.log
    assert 'você quis dizer "dissertacao"' in r.log


def test_tipo_vazio_e_ausente(render):
    r = render("val_tipo_vazio", yaml='tipo: ""\n')
    assert r.ok, r.log
    assert "não existe" not in r.log


# Campos desconhecidos -----------------------------------------------------

def test_campo_com_erro_de_digitacao(render):
    r = render("val_digitacao", yaml='orientdor: "Prof. X"\n')
    assert r.ok, r.log
    assert 'Campo "orientdor" desconhecido — você quis dizer "orientador"?' in r.log


def test_campo_desconhecido_sem_sugestao(render):
    r = render("val_desconhecido", yaml="zzqqxxww-yyy: 1\n")
    assert r.ok, r.log
    assert 'Campo "zzqqxxww-yyy" não é usado pela extensão.' in r.log
    # as chaves que o Quarto e a extensão injetam não geram aviso
    assert sum("Campo " in a for a in avisos(r)) == 1


# Campos básicos -------------------------------------------------------------

def test_campo_basico_vazio(render):
    r = render("val_curso_vazio", yaml='curso: ""\n')
    assert r.ok, r.log
    assert "[preencha: curso]" in r.texto
    assert 'Falta preencher "curso" (aparece como [preencha: curso] no PDF).' in r.log


def test_campos_basicos_vazios_no_pdf(render):
    yaml = 'title: ""\nauthor: ""\nano: ""\norientador: ""\n'
    r = render("val_basicos_vazios", yaml=yaml)
    assert r.ok, r.log
    texto = junta(r.texto)
    for campo in ("title", "author", "ano", "orientador"):
        assert f"[preencha: {campo}]" in texto, campo
        assert f'Falta preencher "{campo}"' in r.log, campo


def test_orientadora_conta_como_orientador(render):
    r = render("val_orientadora", yaml='orientador: ""\norientadora: "Profa. Maria"\n')
    assert r.ok, r.log
    assert 'Falta preencher "orientador"' not in r.log
    assert "[preencha: orientador]" not in junta(r.texto)


# Resumo ---------------------------------------------------------------------

def test_resumo_curto(render):
    r = render("val_resumo_curto")
    assert r.ok, r.log
    assert "O resumo tem 3 palavras; o manual pede de 150 a 500." in r.log
    assert "o manual pede de 150 a 500" in r.log


def test_resumo_conta_palavras_em_portugues(render):
    yaml = f'abstract: "{texto_com(149)}"\nabstract-en: "{texto_com(150)}"\n'
    r = render("val_resumo_pt", yaml=yaml)
    assert r.ok, r.log
    assert "O resumo tem 149 palavras" in r.log
    assert "O abstract tem" not in r.log


# Lembrete stricto sensu ---------------------------------------------------

LEMBRETE = "Lembrete para a versão final: dissertações e teses precisam"


def test_lembrete_stricto(render):
    r = render("val_lembrete", corpo="# Um\n\nTexto.\n\n# Dois\n\nMais.")
    assert r.ok, r.log
    assert r.log.count(LEMBRETE) == 1


def test_sem_lembrete_para_tcc(render):
    r = render("val_lembrete_tcc", yaml="tipo: tcc\n")
    assert r.ok, r.log
    assert LEMBRETE not in r.log


# Citações sem bibliography --------------------------------------------------

def test_citacao_sem_bibliography(render):
    corpo = ("# Introdução {#sec-intro}\n\n"
             "Segundo @silva2020 e [@souza2021], ver @sec-intro.")
    r = render("val_cita_sem_bib", corpo=corpo)
    assert r.ok, r.log
    assert ('O texto cita @silva2020, @souza2021, mas não há "bibliography:" no YAML.'
            in r.log)
    assert "@sec-intro" not in r.log


# Folha de aprovação sem banca ---------------------------------------------

def test_defesa_sem_banca(render):
    r = render("val_defesa_sem_banca", yaml='defesa: "10 de outubro de 2025"\n')
    assert r.ok, r.log
    assert "A folha de aprovação está sem membros da banca (banca-um-nome" in r.log
    assert "APROVADA em 10 de outubro de 2025" in r.texto


# Gênero ---------------------------------------------------------------------

def test_genero_invalido(render):
    yaml = 'genero: x\norientador-genero: "feminino"\ncoorientador-genero: M\n'
    r = render("val_genero", yaml=yaml)
    assert r.ok, r.log
    linhas = "\n".join(avisos(r))
    assert 'genero: "x" não é válido' in linhas
    assert 'orientador-genero: "feminino" não é válido' in linhas
    assert "coorientador-genero" not in linhas


# tipo-trabalho livre sem tipo -------------------------------------------------

def test_tipo_trabalho_livre_sem_tipo(render):
    r = render("val_tipo_trabalho_livre",
               yaml='tipo: ""\ntipo-trabalho: "Projeto final"\n')
    assert r.ok, r.log
    assert 'tipo-trabalho "Projeto final" sem tipo:' in r.log
    assert "Defina tipo: para escolher o nível" in r.log


def test_tipo_trabalho_conhecido_sem_tipo_nao_avisa(render):
    r = render("val_tipo_trabalho_v1", yaml='tipo: ""\ntipo-trabalho: "Tese"\n')
    assert r.ok, r.log
    assert "sem tipo:" not in r.log


# Documento completo ---------------------------------------------------------

def test_sem_avisos_no_exemplo_limpo(render):
    yaml = f"""title: "Título completo"
author: "Fulano de Tal"
ano: "2025"
tipo: dissertacao
curso: "Agronomia/Fitotecnia"
area-concentracao: "Produção Vegetal"
orientador: "Prof. Dr. Fulano"
orientador-genero: m
genero: f
abstract: "{texto_com(200)}"
keywords: "palavra um; palavra dois"
abstract-en: "{texto_com(200)}"
keywords-en: "word one; word two"
defesa: "10 de outubro de 2025"
banca-um-nome: "Dr. Beltrano"
banca-um-inst: "UFLA"
ficha-catalografica: true
indicadores-impacto-texto: "Texto dos indicadores de impacto."
bibliography: refs.bib
lang: pt-BR
format:
  ufla-normas-pdf: default
"""
    r = render("val_limpo", yaml=yaml, yaml_base=False,
               corpo="# Introdução\n\nTexto [@silva2020].",
               arquivos={"refs.bib": BIB})
    assert r.ok, r.log
    assert PREFIXO not in r.log, avisos(r)
