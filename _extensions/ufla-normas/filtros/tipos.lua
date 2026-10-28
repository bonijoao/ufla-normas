--[[
Tipos de trabalho do manual da UFLA (Quadro 3.1). Só dados: carregado por
tipo.lua (nota descritiva) e validar.lua (valores aceitos em `tipo:`).

Cada entrada:
  nome   natureza do trabalho, início da nota descritiva
  genero "f" ou "m" (apresentada/apresentado)
  nivel  texto antes do nome do curso ("Curso de", "Programa de ... em")
  titulo título pretendido padrão
  ordem  posição no Quadro 3.1 (ordem das listas mostradas ao autor)
  stricto true para dissertações e teses (stricto sensu)
]]

return {
  ["tcc"] = {
    ordem = 1,
    nome = "Trabalho de conclusão de curso", genero = "m",
    nivel = "Curso de", titulo = "Bacharel",
  },
  ["monografia"] = {
    ordem = 2,
    nome = "Monografia", genero = "f",
    nivel = "Curso de", titulo = "Bacharel",
  },
  ["monografia-licenciatura"] = {
    ordem = 3,
    nome = "Monografia", genero = "f",
    nivel = "Curso de", titulo = "Licenciado",
  },
  ["especializacao"] = {
    ordem = 4,
    nome = "Monografia", genero = "f",
    nivel = "Curso de Pós-Graduação Lato Sensu em", titulo = "Especialista",
  },
  ["dissertacao"] = {
    ordem = 5, stricto = true,
    nome = "Dissertação", genero = "f",
    nivel = "Programa de Pós-Graduação em", titulo = "Mestre",
  },
  ["dissertacao-profissional"] = {
    ordem = 6, stricto = true,
    nome = "Dissertação", genero = "f",
    nivel = "Programa de Pós-Graduação do Mestrado Profissional em", titulo = "Mestre",
  },
  ["tese"] = {
    ordem = 7, stricto = true,
    nome = "Tese", genero = "f",
    nivel = "Programa de Pós-Graduação em", titulo = "Doutor",
  },
  ["relatorio-estagio"] = {
    ordem = 8,
    nome = "Relatório de estágio supervisionado", genero = "m",
    nivel = "Curso de", titulo = "Bacharel",
  },
}
