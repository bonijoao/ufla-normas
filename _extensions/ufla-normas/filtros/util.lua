--[[
Funções compartilhadas pelos filtros da extensão.

Os filtros do Quarto não conseguem dar `require` uns nos outros de forma
confiável, então cada filtro carrega este arquivo com a função `carrega`
(veja referencias.lua), que funciona também em pastas com acento no Windows.
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
--- bastante (distância até 3 ou até um terço do tamanho de `nome`).
function M.sugerir(nome, opcoes)
  local limite = math.max(3, (utf8.len(nome) or #nome) // 3)
  local melhor, menor = nil, math.huge
  for _, opcao in ipairs(opcoes) do
    local d = M.levenshtein(nome, opcao)
    if d < menor then melhor, menor = opcao, d end
  end
  if melhor ~= nil and menor <= limite then return melhor end
  return nil
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
      local rotulo = linha:match("^[ \t]*#|[ \t]*label:[ \t]*[\"']?([%w_:%.%-]+)")
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
    local prefixo = chave:match("^(%a+)%-")
    return prefixo ~= nil and prefixos[prefixo] == true
  end
end

return M
