"""Formato de artigos (artigos.lua): partes do trabalho, "ARTIGO 1 – TÍTULO"
com nota, seções numeradas de novo em cada artigo, referências próprias de
cada artigo (com estilo do periódico opcional) e lista geral na terceira
parte, antes dos apêndices (manual, Figura 3.23 e seções 4 e 5)."""
import re

from conftest import RAIZ

FIXTURES = RAIZ / "tests" / "fixtures"
NOTA = "Artigo redigido conforme a NBR 6022 (ABNT, 2018)."


def junta(s: str) -> str:
    """Um espaço só entre as palavras (o pdftotext -layout alinha colunas)."""
    return re.sub(r"\s+", " ", s)


def arquivos(com_csl=False):
    a = {"refs.bib": (FIXTURES / "zotero.bib").read_text(encoding="utf-8")}
    if com_csl:
        a["numerico.csl"] = (FIXTURES / "numerico.csl").read_text(encoding="utf-8")
    return a


def sumario(r) -> str:
    for pag in r.texto.split("\f"):
        if "SUMÁRIO" in pag:
            return junta(pag)
    raise AssertionError("PDF sem a página SUMÁRIO")


def corpo_pdf(r) -> str:
    """Texto depois da página do SUMÁRIO."""
    paginas = r.texto.split("\f")
    for i, pag in enumerate(paginas):
        if "SUMÁRIO" in pag:
            return junta(" ".join(paginas[i + 1:]))
    raise AssertionError("PDF sem a página SUMÁRIO")


def trecho(texto: str, de: str, ate: str | None) -> str:
    i = texto.find(de)
    assert i >= 0, f"{de!r} não está no texto: {texto}"
    if ate is None:
        return texto[i:]
    j = texto.find(ate, i + len(de))
    assert j >= 0, f"{ate!r} não está depois de {de!r}: {texto[i:]}"
    return texto[i:j]


CORPO = (
    "# Primeira parte {.parte}\n\n"
    "# Introdução\n\n"
    "Introdução geral do trabalho.\n\n"
    "# Segunda parte – Artigos {.parte}\n\n"
    f'# Modelagem do café {{.artigo nota="{NOTA}"}}\n\n'
    "## Introdução\n\n"
    "O café foi modelado [@souza_modelagem_2024]. "
    "Veja ainda [@chave_inexistente_2020].\n\n"
    "## Resultados\n\n"
    "### Produtividade\n\n"
    "Texto dos resultados.\n\n"
    "# Redes neurais e preços {.artigo%s}\n\n"
    "## Introdução\n\n"
    "Segundo @costa_redes_2022, as redes funcionam [@garcia_soil_2021].\n\n"
    "# {.parte}\n\n"
    "# Considerações finais\n\n"
    "Conclui-se com base em [@wickham_r_2023].\n\n"
    "## Limitações\n\nTexto.\n\n"
    "# Questionário aplicado {.apendice}\n\n"
    "Conteúdo do questionário.\n"
)

YAML = "bibliography: refs.bib\nformato: artigos\n"


def test_formato_artigos(render):
    r = render("artigos", yaml=YAML, corpo=CORPO % "", arquivos=arquivos())
    assert r.ok, r.log

    toc = sumario(r)
    ordem = ["PRIMEIRA PARTE", "SEGUNDA PARTE – ARTIGOS", "ARTIGO 1 – MODELAGEM DO CAFÉ",
             "ARTIGO 2 – REDES NEURAIS E PREÇOS", "TERCEIRA PARTE", "REFERÊNCIAS",
             "APÊNDICE A – QUESTIONÁRIO APLICADO"]
    pos = 0
    for t in ordem:     # nesta ordem (a REFERÊNCIAS geral vem depois da 3ª parte)
        pos = toc.find(t, pos)
        assert pos >= 0, (t, toc)
    assert "ÍNDICE" not in toc.upper()
    # seções do artigo numeradas a partir de 1, no sumário também
    assert "2 Resultados" in toc and "2.1 Produtividade" in toc, toc

    texto = corpo_pdf(r)
    # uma lista por artigo e a geral
    assert texto.count("REFERÊNCIAS") == 3, texto

    art1 = trecho(texto, "ARTIGO 1 – MODELAGEM DO CAFÉ", "ARTIGO 2 –")
    assert NOTA in art1, art1
    assert "1 INTRODUÇÃO" in art1 and "2 RESULTADOS" in art1, art1
    assert "2.1 Produtividade" in art1, art1
    assert "(Souza, 2024)" in art1, art1
    assert "[chave_inexistente_2020?]" in art1, art1
    refs1 = trecho(art1, "REFERÊNCIAS", None)
    assert "SOUZA, Ana Paula" in refs1, refs1
    assert "COSTA" not in refs1 and "WICKHAM" not in refs1, refs1

    art2 = trecho(texto, "ARTIGO 2 – REDES NEURAIS E PREÇOS", "TERCEIRA PARTE")
    assert "1 INTRODUÇÃO" in art2, art2          # numeração recomeça
    assert "Segundo Costa e Ferreira (2022), as redes funcionam (García, 2021)." in art2, art2
    refs2 = trecho(art2, "REFERÊNCIAS", None)
    assert "COSTA, Bruno; FERREIRA, Carla" in refs2, refs2
    assert "GARCÍA, Luis" in refs2, refs2
    assert "SOUZA" not in refs2 and "WICKHAM" not in refs2, refs2

    terceira = trecho(texto, "TERCEIRA PARTE", "APÊNDICE A –")
    assert "(Wickham; Çetinkaya-Rundel; Grolemund, 2023)" in terceira, terceira
    # depois dos artigos a numeração volta a ser a do capítulo
    assert "2 CONSIDERAÇÕES FINAIS" in terceira and "2.1 Limitações" in terceira, terceira
    geral = trecho(terceira, "REFERÊNCIAS", None)
    assert "WICKHAM, Hadley" in geral, geral
    for chave in ("SOUZA", "COSTA", "GARCÍA"):
        assert chave not in geral, geral

    assert "Citação não encontrada: @chave_inexistente_2020" in r.log, r.log
    assert 'Campo "formato"' not in r.log, r.log      # chave conhecida
    assert "formato: artigos —" not in r.log, r.log   # há partes


def test_artigo_com_csl_proprio(render):
    corpo = CORPO % ' csl="numerico.csl"'
    r = render("artigos-csl", yaml=YAML, corpo=corpo, arquivos=arquivos(com_csl=True))
    assert r.ok, r.log
    texto = corpo_pdf(r)
    art1 = trecho(texto, "ARTIGO 1 –", "ARTIGO 2 –")
    art2 = trecho(texto, "ARTIGO 2 –", "TERCEIRA PARTE")
    assert "(Souza, 2024)" in art1, art1
    assert "[1]" not in art1, art1
    assert "Segundo Costa e Ferreira [1], as redes funcionam [2]." in art2, art2
    refs2 = trecho(art2, "REFERÊNCIAS", None)
    assert "[1]" in refs2 and "Redes neurais para previsão de preços" in refs2, refs2
    geral = trecho(texto, "TERCEIRA PARTE", "APÊNDICE A –")
    assert "(Wickham; Çetinkaya-Rundel; Grolemund, 2023)" in geral, geral
    assert "[1]" not in geral, geral


def test_artigo_csl_inexistente(render):
    corpo = CORPO % ' csl="periodico.csl"'
    r = render("artigos-csl-falta", yaml=YAML, corpo=corpo, arquivos=arquivos())
    assert not r.ok
    assert 'ERRO: Não encontrei o arquivo de estilo "periodico.csl"' in r.log, r.log


def test_formato_artigos_sem_partes_avisa(render):
    corpo = (
        f'# Um artigo {{.artigo nota="{NOTA}"}}\n\n'
        "## Introdução\n\nTexto [@souza_modelagem_2024].\n"
    )
    r = render("artigos-sem-partes", yaml=YAML, corpo=corpo, arquivos=arquivos())
    assert r.ok, r.log
    assert ("formato: artigos — use # Primeira parte {.parte}, "
            "# Segunda parte – Artigos {.parte}") in r.log, r.log
    assert "ARTIGO 1 – UM ARTIGO" in corpo_pdf(r)


def test_formato_invalido_avisa(render):
    r = render("formato-invalido", yaml="formato: artigo\n",
               corpo="# Introdução\n\nTexto.\n")
    assert r.ok, r.log
    assert 'formato: "artigo" não é válido' in r.log, r.log
    assert "texto-integral, artigos" in r.log, r.log
    assert 'Campo "formato"' not in r.log, r.log


def test_formato_conhecido_nao_avisa(render):
    r = render("formato-texto-integral", yaml="formato: texto-integral\n",
               corpo="# Introdução\n\nTexto.\n")
    assert r.ok, r.log
    avisos = [l for l in r.log.splitlines() if "[ufla-normas]" in l]
    assert not any("formato" in l for l in avisos), avisos


def test_artigo_sem_formato_artigos_avisa(render):
    corpo = "# Introdução\n\nTexto.\n\n# Um artigo {.artigo}\n\nTexto do artigo.\n"
    r = render("artigo-sem-formato", corpo=corpo)
    assert r.ok, r.log
    assert "formato: artigos" in r.log, r.log
    texto = corpo_pdf(r)
    assert "ARTIGO 1" not in texto, texto
    assert "2 UM ARTIGO" in texto, texto


def test_formato_artigos_em_ingles(render):
    yaml = YAML + "lang: en\ntitulo-traduzido: \"Título em português\"\n"
    corpo = (
        "# {.parte}\n\n# Introduction\n\nGeneral text.\n\n"
        "# {.parte}\n\n"
        "# Coffee modelling {.artigo}\n\n## Introduction\n\n"
        "Coffee was modelled [@souza_modelagem_2024].\n\n"
        "# {.parte}\n\n# Final remarks\n\nBased on [@wickham_r_2023].\n"
    )
    r = render("artigos-en", yaml=yaml, corpo=corpo, arquivos=arquivos())
    assert r.ok, r.log
    toc = sumario(r)
    for t in ("FIRST PART", "SECOND PART – ARTICLES", "ARTICLE 1 – COFFEE MODELLING",
              "THIRD PART", "REFERENCES"):
        assert t in toc, toc
    texto = corpo_pdf(r)
    art = trecho(texto, "ARTICLE 1 – COFFEE MODELLING", "THIRD PART")
    assert "REFERENCES" in art and "SOUZA" in art and "WICKHAM" not in art, art
    geral = trecho(texto, "THIRD PART", None)
    assert "REFERENCES" in geral and "WICKHAM" in geral and "SOUZA" not in geral, geral


def test_sem_citacao_fora_dos_artigos(render):
    """Todas as citações dentro dos artigos e um apêndice: só as listas dos
    artigos (nenhuma REFERÊNCIAS geral vazia); referência cruzada dentro do
    artigo continua funcionando."""
    corpo = (
        "# Primeira parte {.parte}\n\n# Introdução\n\nSem citações.\n\n"
        "# Segunda parte – Artigos {.parte}\n\n"
        "# Um artigo {.artigo}\n\n## Dados\n\n"
        "Veja a @tbl-dados e [@souza_modelagem_2024].\n\n"
        "| a | b |\n|---|---|\n| 1 | 2 |\n\n: Dados {#tbl-dados}\n\n"
        "# Terceira parte {.parte}\n\n# Considerações finais\n\nFim.\n\n"
        "# Roteiro {.apendice}\n\nConteúdo.\n"
    )
    r = render("artigos-sem-geral", yaml=YAML, corpo=corpo, arquivos=arquivos())
    assert r.ok, r.log
    texto = corpo_pdf(r)
    assert texto.count("REFERÊNCIAS") == 1, texto
    art = trecho(texto, "ARTIGO 1 – UM ARTIGO", "TERCEIRA PARTE")
    assert "Veja a Tabela 1 e (Souza, 2024)." in art, art
    assert "SOUZA, Ana Paula" in trecho(art, "REFERÊNCIAS", None), art
    assert "Citação não encontrada" not in r.log, r.log
    assert "APÊNDICE A – ROTEIRO" in texto, texto


def test_titulo_referencias_no_artigo(render):
    """`## Referências` vazio no fim de cada artigo e `# Referências` na
    terceira parte: cada título aparece uma vez só, com a lista certa."""
    corpo = (CORPO % "").replace(
        "Texto dos resultados.\n\n", "Texto dos resultados.\n\n## Referências\n\n"
    ).replace(
        "as redes funcionam [@garcia_soil_2021].\n\n",
        "as redes funcionam [@garcia_soil_2021].\n\n## Referências\n\n",
    ).replace("## Limitações\n\nTexto.\n\n", "## Limitações\n\nTexto.\n\n# Referências\n\n")
    assert corpo.count("Referências") == 3
    r = render("artigos-titulo-refs", yaml=YAML, corpo=corpo, arquivos=arquivos())
    assert r.ok, r.log
    texto = corpo_pdf(r)
    assert texto.count("REFERÊNCIAS") == 3, texto
    art1 = trecho(texto, "ARTIGO 1 –", "ARTIGO 2 –")
    assert "SOUZA, Ana Paula" in trecho(art1, "REFERÊNCIAS", None), art1
    art2 = trecho(texto, "ARTIGO 2 –", "TERCEIRA PARTE")
    assert "COSTA, Bruno" in trecho(art2, "REFERÊNCIAS", None), art2
    geral = trecho(texto, "TERCEIRA PARTE", "APÊNDICE A –")
    refs = trecho(geral, "REFERÊNCIAS", None)
    assert "WICKHAM" in refs and "SOUZA" not in refs and "COSTA" not in refs, refs
