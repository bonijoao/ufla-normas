--[[
Funções compartilhadas pelos filtros da extensão.

Os filtros do Quarto não conseguem dar `require` uns nos outros de forma
confiável, então cada filtro carrega este arquivo com

  local util = dofile(pandoc.path.join({
    pandoc.path.directory(PANDOC_SCRIPT_FILE), "util.lua"}))
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

return M
