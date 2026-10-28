--[[
Tipos de trabalho do manual da UFLA (Quadro 3.1). Só dados: carregado por
tipo.lua (nota descritiva) e validar.lua (valores aceitos em `tipo:`).

Cada entrada:
  nome   natureza do trabalho, início da nota descritiva
  genero "f" ou "m" (apresentada/apresentado)
  nivel  texto antes do nome do curso ("Curso de", "Programa de ... em")
  titulo título pretendido padrão
]]

return {
  ["tcc"] = {
    nome = "Trabalho de conclusão de curso", genero = "m",
    nivel = "Curso de", titulo = "Bacharel",
  },
  ["monografia"] = {
    nome = "Monografia", genero = "f",
    nivel = "Curso de", titulo = "Bacharel",
  },
  ["monografia-licenciatura"] = {
    nome = "Monografia", genero = "f",
    nivel = "Curso de", titulo = "Licenciado",
  },
  ["especializacao"] = {
    nome = "Monografia", genero = "f",
    nivel = "Curso de Pós-Graduação Lato Sensu em", titulo = "Especialista",
  },
  ["dissertacao"] = {
    nome = "Dissertação", genero = "f",
    nivel = "Programa de Pós-Graduação em", titulo = "Mestre",
  },
  ["dissertacao-profissional"] = {
    nome = "Dissertação", genero = "f",
    nivel = "Programa de Pós-Graduação do Mestrado Profissional em", titulo = "Mestre",
  },
  ["tese"] = {
    nome = "Tese", genero = "f",
    nivel = "Programa de Pós-Graduação em", titulo = "Doutor",
  },
  ["relatorio-estagio"] = {
    nome = "Relatório de estágio supervisionado", genero = "m",
    nivel = "Curso de", titulo = "Bacharel",
  },
}
