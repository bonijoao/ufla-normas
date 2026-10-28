--[[
Elementos do trabalho escritos em Markdown, sem LaTeX.

1. Apêndices e anexos: `# Título {.apendice}` vira "APÊNDICE A – TÍTULO" e
   `# Título {.anexo}` vira "ANEXO A – TÍTULO" (A, B, ..., Z, AA, AB, ...),
   sem número, em página nova e no sumário (manual 3.1.2.4.3). O primeiro
   deles abre a parte pós-textual: os títulos seguintes ficam sem número.
   `@apx-x` (id de um desses títulos) vira "Apêndice B" com link.
2. Referências antes do pós-textual: se o autor não pôs `::: {#refs}`, ele é
   criado antes do primeiro apêndice/anexo; se pôs depois deles, sobe.
3. Fonte de figuras, tabelas e quadros: o atributo `fonte="..."` (ou as
   opções `fig-fonte`/`tbl-fonte` de células de código) vira a linha
   "Fonte: ...." abaixo do elemento, em tamanho 11 (manual 3.2.9 e 3.2.10).
4. Quadros: `::: {#qdr-x}` com o último parágrafo como título já é tratado
   pelo crossref do Quarto (_extension.yml); aqui entra `quadro="Título"`,
   para quadros sem parágrafo de título.
5. YAML `siglas:` e `simbolos:` viram as listas pré-textuais (o template lê
   `ufla-lista-siglas` e `ufla-lista-simbolos`); `glossario:` vira o
   GLOSSÁRIO logo depois das referências. Siglas e glossário em ordem
   alfabética; símbolos na ordem em que foram escritos (use a forma de
   lista, `- "x": significado`, para manter a ordem; num mapa o Pandoc
   ordena as chaves).
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

local stringify = pandoc.utils.stringify

-- Espaços só ASCII: no Windows, o %s do Lua casa o byte 0xA0, que é o fim
-- do "à" em UTF-8 (C3 A0).
local function apara(s)
  return (s:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function preenchido(s)
  return s ~= nil and apara(s) ~= ""
end

local function latex(s) return pandoc.RawInline("latex", s) end

--- Texto Markdown de um atributo -> Inlines (itálico, citações, ...).
local function md_inlines(s)
  local doc = pandoc.read(s, "markdown")
  return pandoc.utils.blocks_to_inlines(doc.blocks)
end

--- Valor do YAML -> Inlines.
local function meta_inlines(v)
  local t = pandoc.utils.type(v)
  if t == "Inlines" then return v:clone() end
  if t == "Blocks" then return pandoc.utils.blocks_to_inlines(v) end
  if t == "Inline" then return pandoc.Inlines({ v }) end
  return md_inlines(stringify(v))
end

--- Caixa alta correta para Unicode ("à" -> "À", "ç" -> "Ç").
local function maiusculas(inl)
  return inl:walk({
    Str = function(s)
      s.text = pandoc.text.upper(s.text)
      return s
    end,
  })
end

--- 1 -> A, 26 -> Z, 27 -> AA, 28 -> AB (como o \AlphAlph da v1).
local function letras(n)
  local s = ""
  while n > 0 do
    n = n - 1
    s = string.char(65 + n % 26) .. s
    n = n // 26
  end
  return s
end

-- Ordem alfabética sem diferenciar maiúsculas e acentos.
local SEM_ACENTO = {
  ["á"] = "a", ["à"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a",
  ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
  ["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i",
  ["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o",
  ["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
  ["ç"] = "c", ["ñ"] = "n",
}

local function chave_ordem(s)
  s = pandoc.text.lower(s)
  for acento, letra in pairs(SEM_ACENTO) do s = s:gsub(acento, letra) end
  return s
end

-- Fonte ----------------------------------------------------------------------

local FIM_FRASE = { ["."] = true, ["!"] = true, ["?"] = true }

--- Bloco "\fonte{texto.}" com o texto como Inlines, para que citações e
--- formatação passem pelo Pandoc (e pelo citeproc).
local function bloco_fonte(texto)
  local inl = md_inlines(texto)
  if not FIM_FRASE[stringify(inl):sub(-1)] then inl:insert(pandoc.Str(".")) end
  local r = pandoc.Inlines({ latex("\\fonte{") })
  r:extend(inl)
  r:insert(latex("}"))
  return pandoc.Plain(r)
end

local function como_blocos(conteudo)
  if pandoc.utils.type(conteudo) == "Blocks" then return conteudo end
  return pandoc.Blocks({ conteudo })
end

local function fonte_do_float(float)
  local a = float.attributes
  local especifica = (float.type == "Table") and a["tbl-fonte"] or a["fig-fonte"]
  for _, v in ipairs({ a["fonte"], especifica, a["fig-fonte"], a["tbl-fonte"] }) do
    if preenchido(v) then return v end
  end
  return nil
end

-- Células de código: a opção `fig-fonte`/`tbl-fonte` fica na Div da célula
-- (o knitr repassa opções desconhecidas como atributos); copia para o
-- elemento flutuante dentro dela. O Quarto não expõe outra forma de
-- percorrer os nós próprios (FloatRefTarget) dentro de uma Div.
local avisou_walk = false
local function walk_quarto(el, filtro)
  local q = quarto and quarto._quarto
  if q and q.ast and q.ast.walk then return q.ast.walk(el, filtro) end
  if not avisou_walk then
    avisou_walk = true
    util.aviso("Esta versão do Quarto não permite aplicar fig-fonte/tbl-fonte de "
      .. "células de código; use fonte=\"...\" na figura ou tabela.")
  end
  return nil
end

local filtro_celulas = {
  Div = function(div)
    if not div.classes:includes("cell") then return nil end
    local fig, tbl = div.attributes["fig-fonte"], div.attributes["tbl-fonte"]
    if not preenchido(fig) and not preenchido(tbl) then return nil end
    return walk_quarto(div, {
      FloatRefTarget = function(float)
        if preenchido(float.attributes["fonte"]) then return nil end
        local v = (float.type == "Table") and (tbl or fig) or (fig or tbl)
        if preenchido(v) then
          float.attributes["fonte"] = v
          return float
        end
        return nil
      end,
    })
  end,
}

local filtro_floats = {
  FloatRefTarget = function(float)
    local mudou = false
    -- quadro="Título": título vindo do atributo
    local titulo = float.attributes["quadro"]
    if preenchido(titulo) and float.identifier:match("^qdr%-") then
      -- o Quarto já tomou o último parágrafo como título: ele volta ao corpo
      if float.caption_long ~= nil and stringify(float.caption_long) ~= "" then
        local corpo = como_blocos(float.content):clone()
        corpo:insert(pandoc.Para(pandoc.utils.blocks_to_inlines(como_blocos(float.caption_long))))
        float.content = corpo
      end
      float.caption_long = pandoc.Blocks({ pandoc.Plain(md_inlines(titulo)) })
      mudou = true
    end
    local fonte = fonte_do_float(float)
    if fonte ~= nil then
      local corpo = como_blocos(float.content):clone()
      corpo:insert(bloco_fonte(fonte))
      float.content = corpo
      mudou = true
    end
    if mudou then return float end
    return nil
  end,

  -- figura sem #fig- (o Quarto não numera): fonte no atributo da imagem
  Figure = function(fig)
    local fonte = fig.attributes["fonte"]
    fig.content:walk({
      Image = function(img)
        if not preenchido(fonte) then fonte = img.attributes["fonte"] end
      end,
    })
    if not preenchido(fonte) then return nil end
    fig.content:insert(bloco_fonte(fonte))
    return fig
  end,

  -- quadro sem parágrafo de título: o Quarto não o reconhece como quadro
  Div = function(div)
    local titulo = div.attributes["quadro"]
    if not div.identifier:match("^qdr%-") or not preenchido(titulo) then return nil end
    -- sem `quadro` e `fonte` nos atributos, para que o handler de
    -- FloatRefTarget acima não os aplique de novo
    local atributos = {}
    for k, v in pairs(div.attributes) do
      if k ~= "quadro" and k ~= "fonte" then atributos[k] = v end
    end
    local attr = pandoc.Attr(div.identifier, div.classes, atributos)
    local corpo = div.content
    local fonte = div.attributes["fonte"]
    if preenchido(fonte) then
      corpo = corpo:clone()
      corpo:insert(bloco_fonte(fonte))
    end
    return quarto.FloatRefTarget({
      attr = attr,
      type = "Quadro",
      content = corpo,
      caption_long = { pandoc.Plain(md_inlines(titulo)) },
    })
  end,
}

-- Siglas, símbolos e glossário -------------------------------------------------

--- Entradas {termo = Inlines, significado = Inlines, chave = string} de um
--- mapa (`sigla: significado`) ou de uma lista de mapas de uma chave.
local function entradas(v)
  local r = {}
  local function junta(chave, valor)
    if not preenchido(chave) then return end
    r[#r + 1] = { termo = md_inlines(chave), significado = meta_inlines(valor), chave = chave }
  end
  local t = pandoc.utils.type(v)
  if t == "List" then
    for _, item in ipairs(v) do
      if pandoc.utils.type(item) == "table" or type(item) == "table" then
        for k, x in pairs(item) do
          if type(k) == "string" then junta(k, x) end
        end
      end
    end
  elseif type(v) == "table" then
    for k, x in pairs(v) do
      if type(k) == "string" then junta(k, x) end
    end
  end
  return r
end

local function em_ordem_alfabetica(lista)
  table.sort(lista, function(a, b) return chave_ordem(a.chave) < chave_ordem(b.chave) end)
  return lista
end

--- Itens do ambiente uflaLista do template (\item[termo] significado).
local function itens_lista(lista)
  local blocos = pandoc.Blocks({})
  for _, e in ipairs(lista) do
    local inl = pandoc.Inlines({ latex("\\item[{") })
    inl:extend(e.termo)
    inl:insert(latex("}] "))
    inl:extend(e.significado)
    blocos:insert(pandoc.Plain(inl))
  end
  return blocos
end

local function glossario(lista)
  local blocos = pandoc.Blocks({
    pandoc.RawBlock("latex", "\\uflaTituloPos{glossario}{GLOSSÁRIO}"),
  })
  local defs = {}
  for _, e in ipairs(lista) do
    defs[#defs + 1] = { e.termo, { pandoc.Plain(e.significado) } }
  end
  blocos:insert(pandoc.DefinitionList(defs))
  return blocos
end

-- Parte pós-textual -----------------------------------------------------------

local ROTULOS = {
  apendice = { titulo = "APÊNDICE", texto = "Apêndice" },
  anexo = { titulo = "ANEXO", texto = "Anexo" },
}

local function tipo_pos(b)
  if b.t ~= "Header" or b.level ~= 1 then return nil end
  if b.classes:includes("apendice") then return "apendice" end
  if b.classes:includes("anexo") then return "anexo" end
  return nil
end

local function eh_refs(b)
  return b.t == "Div" and b.identifier == "refs"
end

--- Título "APÊNDICE A – TÍTULO" (travessão U+2013 entre espaços).
local function titulo_pos(header, tipo, letra, rotulo_id)
  local inl = pandoc.Inlines({
    latex("\\uflaTituloPos{" .. rotulo_id .. "}{"),
    pandoc.Str(ROTULOS[tipo].titulo), pandoc.Space(), pandoc.Str(letra),
    pandoc.Space(), pandoc.Str("–"), pandoc.Space(),
  })
  inl:extend(maiusculas(header.content))
  inl:insert(latex("}"))
  return pandoc.Plain(inl)
end

local function parte_pos_textual(doc)
  local blocks = doc.blocks
  doc.blocks:walk({
    Header = function(h)
      if h.level > 1 and (h.classes:includes("apendice") or h.classes:includes("anexo")) then
        util.aviso('"' .. stringify(h.content) .. '": apêndices e anexos usam título de '
          .. 'nível 1 (# Título {.apendice}); este ficou como seção comum.')
      end
    end,
  })
  local contadores = { apendice = 0, anexo = 0 }
  local nomes = {}       -- id do título -> "Apêndice B"
  local saida = pandoc.Blocks({})
  local primeiro = nil   -- posição do primeiro apêndice/anexo em `saida`
  local refs_depois = nil

  for _, b in ipairs(blocks) do
    local tipo = tipo_pos(b)
    if tipo then
      contadores[tipo] = contadores[tipo] + 1
      local letra = letras(contadores[tipo])
      -- rótulo LaTeX: o id do autor se for ASCII (é o que o link do
      -- Pandoc usa), senão "apendice-b"
      local id = b.identifier
      if not id:match("^[%w_:%.%-]+$") then id = tipo .. "-" .. letra:lower() end
      nomes[id] = ROTULOS[tipo].texto .. " " .. letra
      if primeiro == nil then primeiro = #saida + 1 end
      saida:insert(titulo_pos(b, tipo, letra, id))
    elseif primeiro ~= nil and eh_refs(b) then
      refs_depois = b      -- sobe para antes do primeiro apêndice/anexo
    else
      -- depois do primeiro apêndice/anexo: títulos sem número; as
      -- subdivisões internas ficam fora do sumário
      if primeiro ~= nil and b.t == "Header" then
        if not b.classes:includes("unnumbered") then b.classes:insert("unnumbered") end
        if b.level > 1 and not b.classes:includes("unlisted") then b.classes:insert("unlisted") end
      end
      saida:insert(b)
    end
  end

  local function acha_refs()
    for i, b in ipairs(saida) do
      if eh_refs(b) then return i end
    end
    return nil
  end

  local lista_glossario = em_ordem_alfabetica(entradas(doc.meta["glossario"]))
  local i_refs = acha_refs()
  if i_refs == nil and (primeiro ~= nil or #lista_glossario > 0) then
    local refs = refs_depois or pandoc.Div({}, pandoc.Attr("refs"))
    if primeiro ~= nil then
      saida:insert(primeiro, refs)
      primeiro = primeiro + 1
      i_refs = primeiro - 1
    else
      saida:insert(refs)
      i_refs = #saida
    end
  end
  if #lista_glossario > 0 then
    local g = glossario(lista_glossario)
    for k = #g, 1, -1 do saida:insert(i_refs + 1, g[k]) end
  end

  doc.blocks = saida
  return nomes
end

--- @apx-x (id de um apêndice/anexo) -> "Apêndice B" com link.
local function referencias_pos(doc, nomes)
  if next(nomes) == nil then return end
  doc.blocks = doc.blocks:walk({
    Cite = function(cite)
      if #cite.citations ~= 1 then return nil end
      local id = cite.citations[1].id
      local nome = nomes[id]
      if nome == nil then return nil end
      local texto = pandoc.Inlines({})
      for palavra in nome:gmatch("[^ ]+") do
        if #texto > 0 then texto:insert(pandoc.Space()) end
        texto:insert(pandoc.Str(palavra))
      end
      return pandoc.Link(texto, "#" .. id)
    end,
  })
end

local filtro_documento = {
  Pandoc = function(doc)
    local siglas = em_ordem_alfabetica(entradas(doc.meta["siglas"]))
    if #siglas > 0 then doc.meta["ufla-lista-siglas"] = pandoc.MetaBlocks(itens_lista(siglas)) end
    local simbolos = entradas(doc.meta["simbolos"])
    if #simbolos > 0 then doc.meta["ufla-lista-simbolos"] = pandoc.MetaBlocks(itens_lista(simbolos)) end

    local nomes = parte_pos_textual(doc)
    referencias_pos(doc, nomes)
    return doc
  end,
}

return { filtro_celulas, filtro_floats, filtro_documento }
