--[[
Chave `tipo`: aplica os presets do manual (Quadro 3.1, em tipos.lua) e grava
campos calculados que o template.tex lê:

  ufla-nota-descritiva     frase completa da folha de rosto e de aprovação
  ufla-tipo-nome           natureza do trabalho ("Dissertação", "Tese", ...)
  ufla-orientador-rotulo   "Orientador" ou "Orientadora"
  ufla-coorientador-rotulo "Coorientador" ou "Coorientadora"
  ufla-stricto             true para dissertações e teses
  ufla-tipo                chave normalizada ("dissertacao", "tese", ...)
  ufla-tem-banca           true se algum banca-*-nome está preenchido

Sobrescritas: `tipo-trabalho` troca o nome (gênero em `genero: f|m`),
`titulo-pretendido` troca o título e `instituicao` a instituição.
Sem `tipo` e sem `tipo-trabalho` vale `dissertacao` (comportamento da v1).
`orientadora:`/`coorientadora:` (ou `orientador-genero: f`) dão o rótulo
feminino. A frase é montada como Inlines para o Pandoc escapar &, %, _ etc.
]]

-- Carrega um módulo da pasta dos filtros. No Windows, o dofile do Lua não
-- abre caminhos com acento ou "°" (ex.: ".../3° período/..."); nesse caso o
-- arquivo é lido pelo Pandoc, que entende Unicode.
local function carrega(nome)
  local caminho = pandoc.path.join({ pandoc.path.directory(PANDOC_SCRIPT_FILE), nome })
  local ok, modulo = pcall(dofile, caminho)
  if ok then return modulo end
  local _, conteudo = pandoc.mediabag.fetch(caminho)
  return assert(load(conteudo, "@" .. nome))()
end

local util = carrega("util.lua")
local TIPOS = carrega("tipos.lua")

local stringify = pandoc.utils.stringify

local MARCA_CURSO = "\\textcolor{red}{[preencha: curso]}"

-- Espaços só ASCII: no Windows, o %s do Lua casa o byte 0xA0, que é o fim
-- do "à" em UTF-8 (C3 A0) e partiria a letra ao meio.
local function texto(v)
  if v == nil then return "" end
  return (stringify(v):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function vazio(v) return texto(v) == "" end

-- Texto simples -> Inlines (Str/Space), escapado pelo escritor LaTeX.
local function frase(s)
  local r = pandoc.Inlines({})
  for palavra in s:gmatch("[^ \t\r\n]+") do
    if #r > 0 then r:insert(pandoc.Space()) end
    r:insert(pandoc.Str(palavra))
  end
  return r
end

-- Valor do YAML -> Inlines, mantendo a formatação que o autor usou.
local function inlines(v)
  local t = pandoc.utils.type(v)
  if t == "Inlines" then return v:clone() end
  if t == "Blocks" then return pandoc.utils.blocks_to_inlines(v) end
  return frase(texto(v))
end

local function feminino(v)
  return texto(v):lower():sub(1, 1) == "f"
end

local function junta(...)
  local r = pandoc.Inlines({})
  for _, parte in ipairs({ ... }) do r:extend(parte) end
  return r
end

local function rotulos(meta)
  local orientador = "Orientador"
  if not vazio(meta["orientadora"]) then
    meta["orientador"] = meta["orientadora"]
    orientador = "Orientadora"
  elseif feminino(meta["orientador-genero"]) then
    orientador = "Orientadora"
  end
  local coorientador = "Coorientador"
  if not vazio(meta["coorientadora"]) then
    meta["coorientador"] = meta["coorientadora"]
    coorientador = "Coorientadora"
  elseif feminino(meta["coorientador-genero"]) then
    coorientador = "Coorientadora"
  end
  meta["ufla-orientador-rotulo"] = orientador
  meta["ufla-coorientador-rotulo"] = coorientador
end

function Meta(meta)
  local chave, conhecido = util.preset(meta, TIPOS)
  local p = TIPOS[chave]

  local nome = frase(p.nome)
  if not vazio(meta["tipo-trabalho"]) then nome = inlines(meta["tipo-trabalho"]) end

  -- gênero: `genero:` > preset reconhecido > masculino
  local genero = conhecido and p.genero or "m"
  if not vazio(meta["genero"]) then genero = feminino(meta["genero"]) and "f" or "m" end

  local titulo = frase(p.titulo)
  if not vazio(meta["titulo-pretendido"]) then titulo = inlines(meta["titulo-pretendido"]) end

  local instituicao = frase("Universidade Federal de Lavras")
  if not vazio(meta["instituicao"]) then instituicao = inlines(meta["instituicao"]) end

  local curso = pandoc.Inlines({ pandoc.RawInline("latex", MARCA_CURSO) })
  if not vazio(meta["curso"]) then curso = inlines(meta["curso"]) end

  local area = pandoc.Inlines({})
  if not vazio(meta["area-concentracao"]) then
    area = junta(frase(", área de concentração em"), { pandoc.Space() },
                 inlines(meta["area-concentracao"]))
  end

  local nota = junta(
    nome, { pandoc.Space() },
    frase((genero == "f" and "apresentada" or "apresentado") .. " à"), { pandoc.Space() },
    instituicao,
    frase(", como parte das exigências do " .. p.nivel), { pandoc.Space() },
    curso, area,
    frase(", para a obtenção do título de"), { pandoc.Space() },
    titulo, { pandoc.Str(".") }
  )

  meta["ufla-nota-descritiva"] = pandoc.MetaInlines(nota)
  meta["ufla-tipo-nome"] = pandoc.MetaInlines(nome)
  meta["ufla-tipo"] = chave
  meta["ufla-stricto"] = p.stricto == true
  local banca = false
  for _, n in ipairs({ "um", "dois", "tres", "quatro" }) do
    banca = banca or not vazio(meta["banca-" .. n .. "-nome"])
  end
  meta["ufla-tem-banca"] = banca
  rotulos(meta)
  return meta
end
