--[[
Normaliza as referências antes do citeproc e destaca citações sem entrada.

1. Lê a bibliografia com `pandoc.utils.references`, limpa cada campo de texto
   e grava a lista em `references`, removendo `bibliography`. O citeproc (que
   o Quarto roda depois de todos os filtros Lua) passa a usar a lista limpa.
   Limpeza: restos de LaTeX que o leitor de BibTeX deixou passar (chaves
   soltas, acentos como {\'e} e \c{c}, \&, \textbf{...}), aspas e espaços em
   volta da editora e o gênero (`type`) de teses.
2. Cada `@chave` que não está na bibliografia gera um aviso (com sugestão da
   chave mais parecida) e vira um "[chave?]" vermelho e em negrito no PDF.
   Referências cruzadas do Quarto (@fig-, @tbl-, @sec-, ...) são ignoradas.
3. Remove o título "Referências" escrito pelo autor quando ele está vazio ou
   logo antes de `::: {#refs}`: o ambiente CSLReferences já imprime o título.
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

-- Acentos LaTeX -> Unicode -------------------------------------------------

local ACENTOS = {
  ["'"] = { a = "á", e = "é", i = "í", o = "ó", u = "ú", y = "ý", c = "ć", n = "ń", s = "ś", z = "ź",
            A = "Á", E = "É", I = "Í", O = "Ó", U = "Ú", Y = "Ý", C = "Ć", N = "Ń", S = "Ś", Z = "Ź" },
  ["`"] = { a = "à", e = "è", i = "ì", o = "ò", u = "ù", A = "À", E = "È", I = "Ì", O = "Ò", U = "Ù" },
  ["^"] = { a = "â", e = "ê", i = "î", o = "ô", u = "û", A = "Â", E = "Ê", I = "Î", O = "Ô", U = "Û" },
  ["~"] = { a = "ã", o = "õ", n = "ñ", A = "Ã", O = "Õ", N = "Ñ" },
  ['"'] = { a = "ä", e = "ë", i = "ï", o = "ö", u = "ü", y = "ÿ", A = "Ä", E = "Ë", I = "Ï", O = "Ö", U = "Ü" },
  c = { c = "ç", C = "Ç", s = "ş", S = "Ş" },
  H = { o = "ő", u = "ű", O = "Ő", U = "Ű" },
  v = { c = "č", s = "š", z = "ž", r = "ř", e = "ě", C = "Č", S = "Š", Z = "Ž", R = "Ř", E = "Ě" },
}

local ESCAPES = { ["&"] = "&", ["%"] = "%", ["_"] = "_", ["$"] = "$", ["#"] = "#" }

local function acentua(cmd, letra, original)
  local t = ACENTOS[cmd]
  return (t and t[letra]) or original
end

--- Tira restos de LaTeX de um texto; `apara` também junta e corta espaços.
local function limpa_texto(s, apara)
  if s == "" then return s end
  s = s:gsub("\\i%f[%A]", "i")
  -- acentos de símbolo: \'{e}, \'e, {\'e}
  s = s:gsub("\\([`'%^~\"])%s*{(%a)}", function(c, l) return acentua(c, l, l) end)
  s = s:gsub("\\([`'%^~\"])(%a)", function(c, l) return acentua(c, l, l) end)
  -- acentos de letra: \c{c}, \c c
  s = s:gsub("\\([cHv]){(%a)}", function(c, l) return acentua(c, l, l) end)
  s = s:gsub("\\([cHv])%s+(%a)", function(c, l) return acentua(c, l, l) end)
  -- caracteres escapados: \& \% \_ \$ \#
  s = s:gsub("\\([&%%_%$#])", ESCAPES)
  -- comandos de formatação e outros comandos: \textbf{X} -> {X}
  s = s:gsub("\\%a+%s*", "")
  s = s:gsub("\\", "")
  s = s:gsub("[{}]", "")
  if apara then
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  end
  return s
end

--- Limpa uma lista de inlines (título, editora, ...).
local function limpa_inlines(inl)
  -- \emph{...} envolvendo o campo todo; itálico parcial fica (nomes científicos)
  if #inl == 1 and inl[1].t == "Emph" then inl = inl[1].content end
  inl = inl:walk({
    Str = function(el)
      local t = limpa_texto(el.text, false)
      if t == "" then return {} end
      el.text = t
      return el
    end,
    RawInline = function(el)
      if el.format:match("^la?tex$") then
        local t = limpa_texto(el.text, true)
        if t == "" then return {} end
        return pandoc.Str(t)
      end
    end,
    Strong = function(el) return el.content end,  -- o CSL decide o negrito
  })
  while #inl > 0 and (inl[1].t == "Space" or inl[1].t == "SoftBreak") do inl:remove(1) end
  while #inl > 0 and (inl[#inl].t == "Space" or inl[#inl].t == "SoftBreak") do inl:remove(#inl) end
  return inl
end

local NAO_LIMPAR = { id = true, type = true, url = true, URL = true, doi = true, DOI = true,
                     isbn = true, ISBN = true, issn = true, ISSN = true }

local function limpa_valor(v)
  local tipo = pandoc.utils.type(v)
  if tipo == "string" then return limpa_texto(v, true) end
  if tipo == "Inlines" then return limpa_inlines(v) end
  if tipo == "Inline" then return limpa_inlines(pandoc.Inlines({ v })) end
  if type(v) == "table" then
    for k, x in pairs(v) do
      if not NAO_LIMPAR[k] then v[k] = limpa_valor(x) end
    end
  end
  return v
end

-- Gênero de teses --------------------------------------------------------

-- Valores que o leitor de BibTeX do Pandoc põe em `genre` quando a entrada
-- @mastersthesis/@phdthesis não tem `type` (dependem de `lang`).
local GENERO_PADRAO = {
  ["mathesis"] = "mestrado", ["master's thesis"] = "mestrado", ["masters thesis"] = "mestrado",
  ["phdthesis"] = "doutorado", ["phd thesis"] = "doutorado", ["tese de doutorado"] = "doutorado",
}
local GENERO = {
  pt = { mestrado = "Dissertação (Mestrado)", doutorado = "Tese (Doutorado)" },
  en = { mestrado = "Master's thesis", doutorado = "Doctoral thesis" },
}

local function capitaliza(s)
  if s == "" then return s end
  return pandoc.text.upper(pandoc.text.sub(s, 1, 1)) .. pandoc.text.sub(s, 2)
end

local function genero_tese(genero, idioma)
  local chave = pandoc.text.lower(genero):gsub("’", "'")
  local grau = GENERO_PADRAO[chave]
  if grau then return GENERO[idioma == "en" and "en" or "pt"][grau] end
  return capitaliza(genero)
end

-- Limpa a editora: só texto, sem aspas ou espaços em volta.
local function limpa_editora(v)
  local s = pandoc.utils.stringify(v)
  s = s:gsub("^[%s\"“”]+", ""):gsub("[%s\"“”]+$", "")
  return s
end

-- Títulos "Referências" escritos pelo autor -----------------------------

local TITULOS_REFS = {
  ["referências"] = true, ["referencias"] = true, ["referências bibliográficas"] = true,
  ["referencias bibliograficas"] = true, ["references"] = true,
  ["bibliografia"] = true, ["bibliography"] = true,
}

local function eh_div_refs(b)
  return b ~= nil and b.t == "Div" and b.identifier == "refs"
end

local function remove_titulo_duplicado(blocks)
  local tem_div = false
  for _, b in ipairs(blocks) do
    if eh_div_refs(b) then tem_div = true end
  end
  local saida = pandoc.Blocks({})
  for i, b in ipairs(blocks) do
    local manter = true
    if b.t == "Header"
        and TITULOS_REFS[pandoc.text.lower(pandoc.utils.stringify(b.content))] then
      -- pula os Divs ocultos que o Quarto põe no fim do documento
      local j = i + 1
      while blocks[j] ~= nil and blocks[j].t == "Div"
          and blocks[j].classes:includes("hidden") do
        j = j + 1
      end
      local prox = blocks[j]
      if eh_div_refs(prox) then
        manter = false
      elseif prox == nil or (prox.t == "Header" and prox.level <= b.level) then
        manter = false
        if not tem_div then  -- seção vazia: as referências vão para cá
          saida:insert(pandoc.Div({}, { id = "refs" }))
          tem_div = true
        end
      end
    end
    if manter then saida:insert(b) end
  end
  return saida
end

-- Citações sem entrada ---------------------------------------------------

local PREFIXOS_CROSSREF = {
  fig = true, tbl = true, sec = true, eq = true, lst = true, thm = true, lem = true,
  cor = true, prp = true, cnj = true, def = true, exm = true, exr = true, sol = true,
  rem = true, qdr = true, apx = true, anx = true,
}

local function eh_crossref(chave)
  local prefixo = chave:match("^(%a+)%-")
  return prefixo ~= nil and PREFIXOS_CROSSREF[prefixo] == true
end

local function escapa_latex(s)
  return (s:gsub("[\\{}_&%%#%$~%^]", function(c)
    if c == "\\" then return "\\textbackslash{}" end
    if c == "~" then return "\\textasciitilde{}" end
    if c == "^" then return "\\textasciicircum{}" end
    return "\\" .. c
  end))
end

local function marcador(chave)
  return pandoc.RawInline("latex",
    "\\textcolor{red}{\\textbf{[" .. escapa_latex(chave) .. "?]}}")
end

-- Filtro -------------------------------------------------------------------

function Pandoc(doc)
  doc.blocks = remove_titulo_duplicado(doc.blocks)

  if doc.meta.bibliography == nil and doc.meta.references == nil then
    return doc
  end
  -- Se a leitura falhar (arquivo inexistente, .bib inválido), o citeproc
  -- mostra o erro original.
  local ok, refs = pcall(pandoc.utils.references, doc)
  if not ok or refs == nil then return doc end

  local idioma = pandoc.utils.stringify(doc.meta.lang or "pt"):sub(1, 2):lower()

  -- custom crossref do Quarto (crossref: custom: - key: qdr)
  local crossref = doc.meta.crossref
  if type(crossref) == "table" and crossref.custom then
    for _, c in ipairs(crossref.custom) do
      if type(c) == "table" and c.key then
        PREFIXOS_CROSSREF[pandoc.utils.stringify(c.key)] = true
      end
    end
  end

  local ids, chaves = {}, {}
  for _, item in ipairs(refs) do
    for campo, valor in pairs(item) do
      if not NAO_LIMPAR[campo] then item[campo] = limpa_valor(valor) end
    end
    if item.publisher ~= nil then item.publisher = limpa_editora(item.publisher) end
    if item.type == "thesis" and item.genre ~= nil then
      item.genre = genero_tese(pandoc.utils.stringify(item.genre), idioma)
    end
    ids[item.id] = true
    chaves[#chaves + 1] = item.id
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil

  local faltando, avisadas = {}, {}
  local function falta(chave)
    if eh_crossref(chave) or ids[chave] then return false end
    if not avisadas[chave] then
      avisadas[chave] = true
      faltando[#faltando + 1] = "@" .. chave
      local msg = "Citação não encontrada: @" .. chave
      local sugestao = util.sugerir(chave, chaves)
      if sugestao then msg = msg .. " (você quis dizer @" .. sugestao .. "?)" end
      util.aviso(msg)
    end
    return true
  end

  doc.blocks = doc.blocks:walk({
    Cite = function(cite)
      local achadas, perdidas = {}, {}
      for _, c in ipairs(cite.citations) do
        if falta(c.id) then perdidas[#perdidas + 1] = c.id
        else achadas[#achadas + 1] = c end
      end
      if #perdidas == 0 then return nil end
      local saida = pandoc.Inlines({})
      if #achadas > 0 then
        saida:insert(pandoc.Cite(cite.content, achadas))
      end
      for _, chave in ipairs(perdidas) do
        if #saida > 0 then saida:insert(pandoc.Space()) end
        saida:insert(marcador(chave))
      end
      return saida
    end,
  })

  if #faltando > 0 then
    util.aviso(string.format("%d chave(s) sem entrada na bibliografia: %s",
      #faltando, table.concat(faltando, ", ")))
  end
  return doc
end
