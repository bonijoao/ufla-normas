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
--- Só classes ASCII explícitas: no Windows, o %s do Lua casa o byte 0xA0
--- (fim do "à" em UTF-8) e o %a casa bytes de letras acentuadas.
local function limpa_texto(s, apara)
  if s == "" then return s end
  s = s:gsub("\\i%f[^A-Za-z]", "i")
  -- acentos de símbolo: \'{e}, \'e, {\'e}
  s = s:gsub("\\([`'%^~\"])[ \t\r\n]*{([A-Za-z])}", function(c, l) return acentua(c, l, l) end)
  s = s:gsub("\\([`'%^~\"])([A-Za-z])", function(c, l) return acentua(c, l, l) end)
  -- acentos de letra: \c{c}, \c c
  s = s:gsub("\\([cHv]){([A-Za-z])}", function(c, l) return acentua(c, l, l) end)
  s = s:gsub("\\([cHv])[ \t\r\n]+([A-Za-z])", function(c, l) return acentua(c, l, l) end)
  -- caracteres escapados: \& \% \_ \$ \#
  s = s:gsub("\\([&%%_%$#])", ESCAPES)
  -- comandos de formatação e outros comandos: \textbf{X} -> {X}
  s = s:gsub("\\[A-Za-z]+[ \t\r\n]*", "")
  s = s:gsub("\\", "")
  s = s:gsub("[{}]", "")
  if apara then
    s = s:gsub("[ \t\r\n]+", " "):gsub("^ ", ""):gsub(" $", "")
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
  es = { mestrado = "Tesis de maestría", doutorado = "Tesis doctoral" },
}

local function capitaliza(s)
  if s == "" then return s end
  return pandoc.text.upper(pandoc.text.sub(s, 1, 1)) .. pandoc.text.sub(s, 2)
end

local function genero_tese(genero, idioma)
  local chave = pandoc.text.lower(genero):gsub("’", "'")
  local grau = GENERO_PADRAO[chave]
  if grau then return (GENERO[idioma] or GENERO.pt)[grau] end
  return capitaliza(genero)
end

-- Limpa a editora: só texto, sem aspas ou espaços em volta. As aspas curvas
-- saem como strings inteiras: numa classe [...] os bytes soltos delas
-- cortariam o fim de letras como "À" ou "Ü".
local VOLTA_EDITORA = { '"', "“", "”", " ", "\t", "\r", "\n" }

local function limpa_editora(v)
  local s = pandoc.utils.stringify(v)
  local mudou = true
  while mudou and s ~= "" do
    mudou = false
    for _, q in ipairs(VOLTA_EDITORA) do
      if s:sub(1, #q) == q then s, mudou = s:sub(#q + 1), true end
      if #s >= #q and s:sub(-#q) == q then s, mudou = s:sub(1, -#q - 1), true end
    end
  end
  return s
end

-- Documentos sem autoria (manual 5.3.1.4 e Quadro 4.1) --------------------
-- A entrada é pelo título: na referência, a primeira palavra em maiúsculas
-- (ou o artigo/monossílabo inicial e a palavra seguinte); na citação, essas
-- mesmas palavras seguidas de "[...]" quando o título continua:
--   OS GRANDES clássicos das poesias líricas. [S. l.]: Ex Libris, 1981.
--   (Os grandes [...], 1981)    (Inglês, 2012)    (Nos canaviais [...], 1995)

local ARTIGOS = {
  o = true, a = true, os = true, as = true, um = true, uma = true, uns = true, umas = true,
  the = true, an = true,
  el = true, la = true, lo = true, los = true, las = true, un = true, unos = true, unas = true,
}

local VOGAIS = {
  a = true, e = true, i = true, o = true, u = true,
  ["á"] = true, ["é"] = true, ["í"] = true, ["ó"] = true, ["ú"] = true,
  ["à"] = true, ["â"] = true, ["ê"] = true, ["ô"] = true, ["ã"] = true,
  ["õ"] = true, ["ü"] = true,
}

-- Encontros vocálicos de uma sílaba só (ditongos decrescentes).
local DITONGOS = {
  ai = true, ei = true, oi = true, ui = true, au = true, eu = true, ou = true, iu = true,
  ["éi"] = true, ["éu"] = true, ["ói"] = true, ["ão"] = true, ["ãe"] = true,
  ["õe"] = true, ["ãi"] = true, ["êi"] = true,
}

local function caracteres(s)
  local t = {}
  if utf8.len(s) == nil then return t end
  for _, c in utf8.codes(s) do t[#t + 1] = utf8.char(c) end
  return t
end

--- Palavra de uma sílaba: um único grupo de vogais, que é uma vogal só ou
--- um ditongo decrescente ("Nos", "Três", "Mãe", "Pão"; não "Rio", "Rua").
local function monossilabo(palavra)
  local cs = caracteres(pandoc.text.lower(palavra))
  local grupos, atual = {}, ""
  for i, c in ipairs(cs) do
    -- o "u" de "qu"/"gu" antes de vogal não forma sílaba
    local vogal = VOGAIS[c] and not (c == "u" and (cs[i - 1] == "q" or cs[i - 1] == "g")
      and cs[i + 1] ~= nil and VOGAIS[cs[i + 1]])
    if vogal then
      atual = atual .. c
    elseif atual ~= "" then
      grupos[#grupos + 1], atual = atual, ""
    end
  end
  if atual ~= "" then grupos[#grupos + 1] = atual end
  if #grupos ~= 1 then return false end
  return utf8.len(grupos[1]) == 1 or DITONGOS[grupos[1]] == true
end

-- Pontuação ASCII e aspas em volta de uma palavra (sem classes com bytes
-- de UTF-8: ver limpa_texto).
local function sem_pontuacao(p)
  p = p:gsub("^[\"'(%[]+", ""):gsub("[\"'.,:;!?)%]]+$", "")
  for _, q in ipairs({ "“", "”", "‘", "’" }) do
    if p:sub(1, #q) == q then p = p:sub(#q + 1) end
    if #p >= #q and p:sub(-#q) == q then p = p:sub(1, -#q - 1) end
  end
  return p
end

--- Quantas palavras do título formam a entrada: 2 se a primeira for artigo
--- ou monossílabo (e houver uma segunda), senão 1.
local function palavras_de_entrada(palavras)
  if #palavras >= 2 then
    local p = sem_pontuacao(palavras[1])
    if ARTIGOS[pandoc.text.lower(p)] or monossilabo(p) then return 2 end
  end
  return math.min(1, #palavras)
end

local function palavras_do_titulo(titulo)
  local r = {}
  for p in pandoc.utils.stringify(titulo):gmatch("[^ \t\r\n]+") do r[#r + 1] = p end
  return r
end

--- Título curto da citação: as palavras de entrada e "[...]" se o título
--- continua.
local function titulo_curto(palavras, n)
  local curto = {}
  for i = 1, n do curto[i] = palavras[i] end
  local s = table.concat(curto, " ")
  s = s:gsub("[.,:;]+$", "")
  if #palavras > n then s = s .. " [...]" end
  return s
end

--- Título com as `n` primeiras palavras em maiúsculas.
local function titulo_com_entrada(titulo, n)
  local vistas = 0
  return titulo:walk({
    Str = function(el)
      if vistas >= n then return nil end
      vistas = vistas + 1
      el.text = pandoc.text.upper(el.text)
      return el
    end,
  })
end

local function sem_nomes(item)
  return item.author == nil and item.editor == nil and item.translator == nil
end

local function entrada_pelo_titulo(item)
  if not sem_nomes(item) or item.title == nil then return end
  local titulo = item.title
  if pandoc.utils.type(titulo) == "string" then titulo = pandoc.Inlines(titulo) end
  local palavras = palavras_do_titulo(titulo)
  local n = palavras_de_entrada(palavras)
  if n == 0 then return end
  item["title-short"] = titulo_curto(palavras, n)
  item.title = titulo_com_entrada(titulo, n)
end

-- Entidade com subordinação ("Universidade Federal de Lavras. Biblioteca
-- Universitária", "Brasil. Ministério da Saúde"): a referência traz o órgão
-- superior em maiúsculas e o subordinado como está; a citação, só o órgão
-- superior: (Universidade Federal de Lavras, 2025). O subordinado vai para
-- a variável `ufla-subordinada`, que o ufla-abnt.csl imprime depois do autor.

--- Posição do ". " que separa o órgão superior do subordinado: a palavra
--- antes do ponto tem 4 letras ou mais (não é abreviação como "Prof.") e a
--- seguinte começa com maiúscula.
local function separa_entidade(nome)
  local inicio = 1
  while true do
    local i = nome:find(". ", inicio, true)
    if i == nil then return nil end
    local antes = nome:sub(1, i - 1)
    local palavra = antes:match("([^ ]+)$") or ""
    local depois = nome:sub(i + 2)
    local primeira = caracteres(depois)[1]
    if (utf8.len(palavra) or 0) >= 4 and primeira ~= nil
        and pandoc.text.lower(primeira) ~= primeira then
      return antes, depois
    end
    inicio = i + 2
  end
end

local function entidade_subordinada(item)
  if item.author == nil or #item.author ~= 1 then return end
  local autor = item.author[1]
  if type(autor) ~= "table" or autor.literal == nil then return end
  local superior, subordinada = separa_entidade(pandoc.utils.stringify(autor.literal))
  if superior == nil then return end
  autor.literal = superior
  item["ufla-subordinada"] = subordinada:gsub("[ .]+$", "")
end

-- Nome do evento ----------------------------------------------------------
-- O `eventtitle` pode trazer número, ano e local, como na NBR 6023:
-- "Simpósio Brasileiro de Pesquisa Operacional, 54., 2022, Campinas" ->
-- "SIMPÓSIO BRASILEIRO DE PESQUISA OPERACIONAL, 54., 2022, Campinas".
-- Só o nome (até a primeira vírgula; depois de ";" começa outro evento) vai
-- em maiúsculas; o ufla-abnt.csl imprime o evento como chega.

local function evento_em_maiusculas(evento)
  if pandoc.utils.type(evento) == "string" then evento = pandoc.Inlines(evento) end
  local nome = true
  return evento:walk({
    Str = function(el)
      local fim = el.text:sub(-1)
      if nome then el.text = pandoc.text.upper(el.text) end
      if fim == "," then nome = false elseif fim == ";" then nome = true end
      return el
    end,
  })
end

-- Títulos "Referências" escritos pelo autor -----------------------------

local TITULOS_REFS = {
  ["referências"] = true, ["referencias"] = true, ["referências bibliográficas"] = true,
  ["referencias bibliograficas"] = true, ["references"] = true,
  ["bibliografia"] = true, ["bibliography"] = true, ["bibliografía"] = true,
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

  local idioma = util.idioma(doc.meta)

  local ids, chaves = {}, {}
  for _, item in ipairs(refs) do
    for campo, valor in pairs(item) do
      if not NAO_LIMPAR[campo] then item[campo] = limpa_valor(valor) end
    end
    if item.publisher ~= nil then item.publisher = limpa_editora(item.publisher) end
    entrada_pelo_titulo(item)
    entidade_subordinada(item)
    if item.event ~= nil then item.event = evento_em_maiusculas(item.event) end
    if item.type == "thesis" and item.genre ~= nil then
      item.genre = genero_tese(pandoc.utils.stringify(item.genre), idioma)
    elseif item.type == "thesis" and idioma ~= "pt" then
      -- sem `type`: o ufla-abnt.csl escreveria "Trabalho acadêmico"
      item.genre = util.ROTULOS[idioma].trabalho_academico
    end
    ids[item.id] = true
    chaves[#chaves + 1] = item.id
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil

  local eh_crossref = util.crossref(doc)
  local faltando, avisadas = {}, {}
  local function falta(chave)
    if ids[chave] or eh_crossref(chave) then return false end
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
