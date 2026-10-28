--[[
Chamada narrativa (autor incluído na sentença) com dois ou três autores.

O manual da UFLA (Quadro 4.1) pede "Gong e Tian (2020)" no texto e
"(Gong; Tian, 2020)" entre parênteses. O CSL 1.0 usa um só separador de nomes
para as duas formas, e o citeproc do Pandoc não suporta o elemento <intext> do
CSL 1.1. Este filtro roda antes do citeproc e troca cada `@chave` narrativa de
uma obra com dois ou três autores por "Nome, Nome e Nome" seguido de
`[-@chave]` (que o citeproc imprime como "(2020)" ou "(2020, p. 5)").

Com um autor ou com quatro ou mais ("Silva et al. (2023)") a saída do
citeproc já está certa, e a citação não é alterada.
]]

local CONJUNCAO = { pt = "e", en = "and", es = "y", fr = "et", it = "e", de = "und" }

local function texto(x)
  if x == nil then return nil end
  local s = pandoc.utils.stringify(x)
  if s == "" then return nil end
  return s
end

local function nome(autor)
  local literal = texto(autor.literal)
  if literal then return literal end
  local sobrenome = texto(autor.family)
  if not sobrenome then return nil end
  local particula = texto(autor["non-dropping-particle"])
  if particula then return particula .. " " .. sobrenome end
  return sobrenome
end

function Pandoc(doc)
  local ok, refs = pcall(pandoc.utils.references, doc)
  if not ok or refs == nil or #refs == 0 then return nil end

  local por_id = {}
  for _, item in ipairs(refs) do por_id[item.id] = item end

  local lang = (texto(doc.meta.lang) or "pt"):sub(1, 2):lower()
  local conjuncao = CONJUNCAO[lang] or "e"

  return doc:walk({
    Cite = function(cite)
      if #cite.citations ~= 1 then return nil end
      local c = cite.citations[1]
      if c.mode ~= "AuthorInText" then return nil end
      local item = por_id[c.id]
      if item == nil or item.author == nil then return nil end
      local n = #item.author
      if n < 2 or n > 3 then return nil end

      local nomes = {}
      for i, autor in ipairs(item.author) do
        nomes[i] = nome(autor)
        if nomes[i] == nil then return nil end
      end
      local juntos = table.concat(nomes, ", ", 1, n - 1) .. " " .. conjuncao .. " " .. nomes[n]

      local sem_autor = pandoc.Citation(c.id, "SuppressAuthor", c.prefix, c.suffix,
                                        c.note_num, c.hash)
      local saida = pandoc.Inlines(juntos)
      saida:insert(pandoc.Space())
      saida:insert(pandoc.Cite(pandoc.Inlines("[-@" .. c.id .. "]"), { sem_autor }))
      return saida
    end,
  })
end
