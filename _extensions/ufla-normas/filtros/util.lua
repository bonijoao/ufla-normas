--[[
Funções compartilhadas pelos filtros da extensão.

Os filtros do Quarto não conseguem dar `require` uns nos outros de forma
confiável, então cada filtro carrega este arquivo com a função `carrega`,
copiada no começo de cada filtro. Não use `dofile` sozinho: no Windows ele
não abre caminhos com acento ou "°"; `carrega` tenta o `dofile` e, se ele
falhar, lê o arquivo pelo Pandoc (pandoc.mediabag.fetch).
]]

local M = {}

local PREFIXO = "[ufla-normas] "

--- Aviso no stderr; a renderização continua.
function M.aviso(msg)
  io.stderr:write(PREFIXO .. "AVISO: " .. msg .. "\n")
end

--- Erro no stderr; a renderização para.
function M.erro(msg)
  io.stderr:write(PREFIXO .. "ERRO: " .. msg .. "\n")
  os.exit(1)
end

--- Vários erros de uma vez: mostra todos e então para a renderização.
function M.erros(msgs)
  if #msgs == 0 then return end
  for i = 1, #msgs - 1 do io.stderr:write(PREFIXO .. "ERRO: " .. msgs[i] .. "\n") end
  M.erro(msgs[#msgs])
end

-- Divide uma string UTF-8 em caracteres.
local function caracteres(s)
  local t = {}
  if utf8.len(s) == nil then  -- bytes inválidos: compara byte a byte
    for i = 1, #s do t[i] = s:byte(i) end
    return t
  end
  for _, c in utf8.codes(s) do t[#t + 1] = c end
  return t
end

--- Distância de edição (Levenshtein) entre duas strings UTF-8.
function M.levenshtein(a, b)
  local x, y = caracteres(a), caracteres(b)
  local n, m = #x, #y
  if n == 0 then return m end
  if m == 0 then return n end
  local anterior = {}
  for j = 0, m do anterior[j] = j end
  for i = 1, n do
    local atual = { [0] = i }
    for j = 1, m do
      local custo = (x[i] == y[j]) and 0 or 1
      atual[j] = math.min(anterior[j] + 1, atual[j - 1] + 1, anterior[j - 1] + custo)
    end
    anterior = atual
  end
  return anterior[m]
end

--- Opção mais parecida com `nome`, ou nil se nenhuma estiver perto o
--- bastante: distância até um terço do tamanho de `nome` (mínimo 1), para
--- que nomes curtos ("foo", "nome") não recebam sugestões sem sentido.
function M.sugerir(nome, opcoes)
  local limite = math.max(1, (utf8.len(nome) or #nome) // 3)
  local melhor, menor = nil, math.huge
  for _, opcao in ipairs(opcoes) do
    local d = M.levenshtein(nome, opcao)
    if d < menor then melhor, menor = opcao, d end
  end
  if melhor ~= nil and menor <= limite then return melhor end
  return nil
end

-- Tipos de trabalho ---------------------------------------------------------

-- Espaços só ASCII: no Windows, o %s do Lua casa o byte 0xA0, que é o fim
-- do "à" em UTF-8 (C3 A0).
local function texto(v)
  if v == nil then return "" end
  return (pandoc.utils.stringify(v):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

--- Chaves de `tipos` (tabela de tipos.lua) na ordem do Quadro 3.1.
function M.chaves_tipos(tipos)
  local r = {}
  for k in pairs(tipos) do r[#r + 1] = k end
  table.sort(r, function(a, b)
    local oa, ob = tipos[a].ordem or math.huge, tipos[b].ordem or math.huge
    if oa ~= ob then return oa < ob end
    return a < b
  end)
  return r
end

-- Ordem usada para reconhecer um `tipo-trabalho` da v1 sem `tipo`.
local ORDEM_V1 = {
  "dissertacao", "tese", "tcc", "monografia", "relatorio-estagio",
}

--- Resolve o preset de `tipos` para os metadados: `tipo` explícito, senão
--- `tipo-trabalho` com o nome de um tipo da v1, senão dissertação. Devolve
--- a chave e se o preset foi reconhecido (false para `tipo-trabalho` em
--- texto livre). Tipo desconhecido é erro em validar.lua; aqui só cai na
--- dissertação para não quebrar. Usado por tipo.lua e validar.lua.
function M.preset(meta, tipos)
  local chave = texto(meta["tipo"]):lower()
  if chave ~= "" then
    if tipos[chave] then return chave, true end
    return "dissertacao", true
  end
  local tipo_trabalho = texto(meta["tipo-trabalho"])
  if tipo_trabalho ~= "" then
    local nome = pandoc.text.lower(tipo_trabalho)
    for _, k in ipairs(ORDEM_V1) do
      if pandoc.text.lower(tipos[k].nome) == nome then return k, true end
    end
    return "dissertacao", false
  end
  return "dissertacao", true
end

-- Idioma do texto ------------------------------------------------------------

--- Rótulos do corpo do trabalho (do primeiro capítulo em diante) por idioma.
--- Os pré-textuais ficam sempre em português (manual 3.1.2.1), então só
--- entram aqui os rótulos que aparecem no corpo e no pós-textual. `babel` é
--- o nome do idioma para o pacote babel do LaTeX.
M.ROTULOS = {
  pt = {
    babel = "brazil", figura = "Figura", tabela = "Tabela",
    fonte = "Fonte", quadro = "Quadro",
    apendice = "APÊNDICE", apendice_texto = "Apêndice",
    anexo = "ANEXO", anexo_texto = "Anexo",
    glossario = "GLOSSÁRIO", trabalho_academico = "Trabalho acadêmico",
    artigo = "ARTIGO", artigos = "ARTIGOS",
    partes = { "PRIMEIRA PARTE", "SEGUNDA PARTE", "TERCEIRA PARTE", "QUARTA PARTE" },
    parte = "PARTE",
  },
  en = {
    babel = "english", figura = "Figure", tabela = "Table",
    fonte = "Source", quadro = "Chart",
    apendice = "APPENDIX", apendice_texto = "Appendix",
    anexo = "ANNEX", anexo_texto = "Annex",
    glossario = "GLOSSARY", trabalho_academico = "Academic work",
    artigo = "ARTICLE", artigos = "ARTICLES",
    partes = { "FIRST PART", "SECOND PART", "THIRD PART", "FOURTH PART" },
    parte = "PART",
  },
  es = {
    -- modificadores do babel: noshorthands (sem os atalhos ativos do
    -- espanhol, <, > e ", que quebram as tabelas do Pandoc) e tabla
    -- ("Tabla 1", não "Cuadro 1", nas tabelas)
    babel = "spanish", babel_modificadores = ".noshorthands.tabla",
    figura = "Figura", tabela = "Tabla", fonte = "Fuente", quadro = "Cuadro",
    apendice = "APÉNDICE", apendice_texto = "Apéndice",
    anexo = "ANEXO", anexo_texto = "Anexo",
    glossario = "GLOSARIO", trabalho_academico = "Trabajo académico",
    artigo = "ARTÍCULO", artigos = "ARTÍCULOS",
    partes = { "PRIMERA PARTE", "SEGUNDA PARTE", "TERCERA PARTE", "CUARTA PARTE" },
    parte = "PARTE",
  },
}

--- Valores de `formato` (validar.lua avisa os outros; artigos.lua usa).
M.FORMATOS = { "texto-integral", "artigos" }

-- Variantes regionais com nome próprio no babel.
local BABEL_REGIAO = { ["en-gb"] = "british", ["en-uk"] = "british" }

--- Idioma do texto a partir de `lang` (pt, pt-BR, en, en-US, es, es-ES...).
--- Devolve a chave de ROTULOS ("pt", "en" ou "es"), se o idioma é suportado
--- (false: cai no português) e o valor escrito em `lang`. Sem `lang`, pt.
function M.idioma(meta)
  local bruto = texto(meta and meta.lang)
  if bruto == "" then return "pt", true, bruto end
  local base = bruto:lower():match("^([a-z]+)")
  if base ~= nil and M.ROTULOS[base] then return base, true, bruto end
  return "pt", false, bruto
end

--- Nome do idioma para o babel ("english", "british", "spanish", ...).
function M.babel(meta)
  local chave, _, bruto = M.idioma(meta)
  return BABEL_REGIAO[bruto:lower():gsub("_", "-")] or M.ROTULOS[chave].babel
end

-- Referências cruzadas ----------------------------------------------------

-- Prefixos de referência cruzada do Quarto: @fig-x, @tbl-x, ... não são
-- citações bibliográficas.
local PREFIXOS_CROSSREF = {
  fig = true, tbl = true, sec = true, eq = true, lst = true, thm = true, lem = true,
  cor = true, prp = true, cnj = true, def = true, exm = true, exr = true, sol = true,
  rem = true, qdr = true, apx = true, anx = true,
  -- callouts (Quarto >= 1.4)
  nte = true, tip = true, wrn = true, imp = true, cau = true,
}

-- Identificadores de elementos do documento: qualquer @chave igual a um deles
-- é referência cruzada, mesmo com um prefixo que a lista acima não conhece.
local function identificadores(blocks)
  local ids = {}
  local function guarda(el)
    if el.identifier ~= nil and el.identifier ~= "" then ids[el.identifier] = true end
    -- células de código: #| label: fig-x
    if el.attributes ~= nil then
      local rotulo = el.attributes["label"]
      if rotulo ~= nil and rotulo ~= "" then ids[rotulo] = true end
    end
  end
  local function rotulo_celula(el)
    guarda(el)
    for linha in el.text:gmatch("[^\n]+") do
      local rotulo = linha:match("^[ \t]*#|[ \t]*label:[ \t]*[\"']?([A-Za-z0-9_:%.%-]+)")
      if rotulo then ids[rotulo] = true end
    end
  end
  blocks:walk({
    Header = guarda, Div = guarda, Span = guarda, Figure = guarda,
    Table = guarda, Image = guarda, Link = guarda, CodeBlock = rotulo_celula,
  })
  return ids
end

--- Devolve `eh_crossref(chave)` para o documento: verdadeira quando a
--- @chave é referência cruzada (prefixo conhecido, prefixo de `crossref:
--- custom:` ou id de um elemento do documento), e não citação.
function M.crossref(doc)
  local prefixos = {}
  for k, v in pairs(PREFIXOS_CROSSREF) do prefixos[k] = v end
  -- custom crossref do Quarto (crossref: custom: - key: qdr)
  local crossref = doc.meta.crossref
  if type(crossref) == "table" and crossref.custom then
    for _, c in ipairs(crossref.custom) do
      if type(c) == "table" and c.key then
        prefixos[pandoc.utils.stringify(c.key)] = true
      end
    end
  end
  local ids_doc = identificadores(doc.blocks)
  return function(chave)
    if ids_doc[chave] then return true end
    local prefixo = chave:match("^([A-Za-z]+)%-")
    return prefixo ~= nil and prefixos[prefixo] == true
  end
end

return M
