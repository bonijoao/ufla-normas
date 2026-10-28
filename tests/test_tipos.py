"""Chave `tipo`: presets do Quadro 3.1 do manual, nota descritiva da folha de
rosto/aprovação e rótulo do orientador."""
import re

import pytest


def normaliza(s: str) -> str:
    """Tira espaços e hífens: a nota fica numa minipage estreita e o LaTeX
    pode hifenizar qualquer palavra ("exigên-cias")."""
    return re.sub(r"[\s\-]+", "", s)


def pagina_com(r, trecho: str) -> str:
    """Primeira página do PDF que contém `trecho` (mesmo hifenizado)."""
    for pag in r.texto.split("\f"):
        if normaliza(trecho) in normaliza(pag):
            return pag
    return ""


def nota(r) -> str:
    return normaliza(pagina_com(r, "apresentad"))


UFLA = "Universidade Federal de Lavras"

CASOS = [
    ("tcc", "Engenharia Florestal", None,
     f"Trabalho de conclusão de curso apresentado à {UFLA}, como parte das "
     "exigências do Curso de Engenharia Florestal, para a obtenção do título "
     "de Bacharel."),
    ("monografia", "Zootecnia", None,
     f"Monografia apresentada à {UFLA}, como parte das exigências do Curso de "
     "Zootecnia, para a obtenção do título de Bacharel."),
    ("monografia-licenciatura", "Ciências Biológicas", None,
     f"Monografia apresentada à {UFLA}, como parte das exigências do Curso de "
     "Ciências Biológicas, para a obtenção do título de Licenciado."),
    ("especializacao", "Estatística Aplicada", None,
     f"Monografia apresentada à {UFLA}, como parte das exigências do Curso de "
     "Pós-Graduação Lato Sensu em Estatística Aplicada, para a obtenção do "
     "título de Especialista."),
    ("dissertacao", "Agronomia/Fitotecnia", "Produção Vegetal",
     f"Dissertação apresentada à {UFLA}, como parte das exigências do "
     "Programa de Pós-Graduação em Agronomia/Fitotecnia, área de concentração "
     "em Produção Vegetal, para a obtenção do título de Mestre."),
    ("dissertacao-profissional", "Administração Pública", None,
     f"Dissertação apresentada à {UFLA}, como parte das exigências do "
     "Programa de Pós-Graduação do Mestrado Profissional em Administração "
     "Pública, para a obtenção do título de Mestre."),
    ("tese", "Estatística e Experimentação Agropecuária", "Estatística",
     f"Tese apresentada à {UFLA}, como parte das exigências do Programa de "
     "Pós-Graduação em Estatística e Experimentação Agropecuária, área de "
     "concentração em Estatística, para a obtenção do título de Doutor."),
    ("relatorio-estagio", "Medicina Veterinária", None,
     f"Relatório de estágio supervisionado apresentado à {UFLA}, como parte "
     "das exigências do Curso de Medicina Veterinária, para a obtenção do "
     "título de Bacharel."),
]


@pytest.mark.parametrize("tipo, curso, area, esperado", CASOS,
                         ids=[c[0] for c in CASOS])
def test_nota_descritiva(render, tipo, curso, area, esperado):
    yaml = f'tipo: {tipo}\ncurso: "{curso}"\n'
    if area:
        yaml += f'area-concentracao: "{area}"\n'
    # defesa: imprime a folha de aprovação, que repete a nota
    yaml += ('defesa: "10 de outubro de 2025"\n'
             'banca-um-nome: "Dr. Beltrano"\nbanca-um-inst: "UFLA"\n')
    r = render(f"tipo_{tipo}", yaml=yaml)
    assert r.ok, r.log
    assert normaliza(esperado) in nota(r)
    aprovacao = normaliza(pagina_com(r, "APROVADA"))
    assert normaliza(esperado) in aprovacao


def test_orientadora(render):
    yaml = ('orientadora: "Profa. Dra. Maria"\n'
            'coorientador: "Prof. Dr. João"\n'
            'coorientador-genero: f\n'
            'ficha-catalografica: true\n')
    r = render("tipo_orientadora", yaml=yaml)
    assert r.ok, r.log
    rosto = pagina_com(r, "apresentad")
    assert "Profa. Dra. Maria" in rosto
    assert re.search(r"^\s*Orientadora\s*$", rosto, re.M), rosto
    assert re.search(r"^\s*Coorientadora\s*$", rosto, re.M), rosto
    assert "Orientadora: Profa. Dra. Maria" in r.texto  # ficha catalográfica


def test_orientador_padrao(render):
    r = render("tipo_orientador", yaml="")
    assert r.ok, r.log
    rosto = pagina_com(r, "apresentad")
    assert re.search(r"^\s*Orientador\s*$", rosto, re.M), rosto


def test_tipo_trabalho_livre(render):
    r = render("tipo_livre", yaml='tipo-trabalho: "Produto técnico"\ngenero: m\n')
    assert r.ok, r.log
    assert normaliza("Produto técnico apresentado à") in nota(r)


def test_titulo_pretendido_sobrepoe(render):
    r = render("tipo_titulo", yaml="tipo: tese\ntitulo-pretendido: Doutora\n")
    assert r.ok, r.log
    assert normaliza("Tese apresentada à") in nota(r)
    assert normaliza("título de Doutora.") in nota(r)


def test_curso_vazio_marca_preencha(render):
    r = render("tipo_sem_curso", yaml='curso: ""\n')
    assert r.ok, r.log
    assert normaliza("Programa de Pós-Graduação em [preencha: curso]") in nota(r)


def test_caracteres_especiais_escapados(render):
    r = render("tipo_especiais",
               yaml='curso: "Física & Química_1 100%"\n'
                    'area-concentracao: "Ensino #2"\n')
    assert r.ok, r.log
    assert normaliza("Física & Química_1 100%, área de concentração em Ensino #2,") in nota(r)


def test_documento_v1_sem_tipo(render):
    yaml = ('title: "Título v1"\nauthor: "Fulano"\nano: "2025"\n'
            'curso: "Agronomia"\norientador: "Prof. Dr. Fulano"\n'
            'format:\n  ufla-normas-pdf: default\n')
    r = render("tipo_v1", yaml=yaml, yaml_base=False)
    assert r.ok, r.log
    assert normaliza(
        f"Dissertação apresentada à {UFLA}, como parte das exigências do "
        "Programa de Pós-Graduação em Agronomia, para a obtenção do título de "
        "Mestre.") in nota(r)


def test_documento_v1_tipo_trabalho(render):
    yaml = ('title: "Título v1"\nauthor: "Fulano"\nano: "2025"\n'
            'tipo-trabalho: "Tese"\ntitulo-pretendido: "Doutor"\n'
            'curso: "Agronomia"\norientador: "Prof. Dr. Fulano"\n'
            'format:\n  ufla-normas-pdf: default\n')
    r = render("tipo_v1_trabalho", yaml=yaml, yaml_base=False)
    assert r.ok, r.log
    assert normaliza("Tese apresentada à") in nota(r)
    assert normaliza("título de Doutor.") in nota(r)
