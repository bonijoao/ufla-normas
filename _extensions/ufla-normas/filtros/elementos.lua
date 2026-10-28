--[[
Elementos em Markdown, segunda parte (roda por último, depois de
referencias.lua; elementos-atributos.lua faz a primeira parte).

1. Apêndices e anexos: `# Título {.apendice}` vira "APÊNDICE A – TÍTULO" e
   `# Título {.anexo}` vira "ANEXO A – TÍTULO" (A, B, ..., Z, AA, AB, ...;
   "APPENDIX A –"/"ANNEX A –" etc. conforme `lang`),
   sem número, em página nova e no sumário (manual 3.1.2.4.3). O primeiro
   deles abre a parte pós-textual: os títulos seguintes ficam sem número.
   `@apx-x` (id de um desses títulos) vira "Apêndice B" com link.
2. Referências antes do pós-textual: se o autor não pôs `::: {#refs}`, ele é
   criado antes do primeiro apêndice/anexo; se pôs depois deles, sobe.
   Roda depois de referencias.lua, que já tratou o título "Referências"
   escrito pelo autor e a Div #refs.
3. Siglas, símbolos e glossário montados por elementos-atributos.lua (Divs
   no início do corpo): as listas vão para os metadados lidos pelo template
   e o GLOSSÁRIO vai para logo depois das referências.
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

local function latex(s) return pandoc.RawInline("latex", s) end

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

-- Parte pós-textual -----------------------------------------------------------

-- Rótulos no idioma do texto (`lang`; util.ROTULOS), definidos em Pandoc().
local ROTULOS

local function define_rotulos(meta)
  local r = util.ROTULOS[util.idioma(meta)]
  ROTULOS = {
    apendice = { titulo = r.apendice, texto = r.apendice_texto },
    anexo = { titulo = r.anexo, texto = r.anexo_texto },
  }
end

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

--- `glossario`: blocos montados por elementos-atributos.lua (ou nil).
--- Com `suppress-bibliography` (o autor pediu, ou artigos.lua: todas as
--- citações estão dentro dos artigos) não há lista geral: o #refs sai, para
--- não virar um CSLReferences vazio, e o glossário fica no lugar dele.
local function parte_pos_textual(doc, glossario)
  local blocks = doc.blocks
  local sem_refs = doc.meta["suppress-bibliography"] == true
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
    elseif sem_refs and eh_refs(b) then
      -- sem lista geral
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

  if sem_refs then
    if glossario ~= nil then
      local i = primeiro or (#saida + 1)
      for k = #glossario, 1, -1 do saida:insert(i, glossario[k]) end
    end
    doc.blocks = saida
    return nomes
  end

  local i_refs = acha_refs()
  if i_refs == nil and (primeiro ~= nil or glossario ~= nil) then
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
  if glossario ~= nil then
    for k = #glossario, 1, -1 do saida:insert(i_refs + 1, glossario[k]) end
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


--- Tira do corpo a Div `id` montada por elementos-atributos.lua.
local function retira_div(doc, id)
  for i, b in ipairs(doc.blocks) do
    if b.t == "Div" and b.identifier == id then
      doc.blocks:remove(i)
      return b.content
    end
  end
  return nil
end

local filtro_documento = {
  Pandoc = function(doc)
    define_rotulos(doc.meta)
    local siglas = retira_div(doc, "ufla-lista-siglas")
    if siglas then doc.meta["ufla-lista-siglas"] = pandoc.MetaBlocks(siglas) end
    local simbolos = retira_div(doc, "ufla-lista-simbolos")
    if simbolos then doc.meta["ufla-lista-simbolos"] = pandoc.MetaBlocks(simbolos) end
    local glossario = retira_div(doc, "ufla-glossario")

    local nomes = parte_pos_textual(doc, glossario)
    referencias_pos(doc, nomes)
    return doc
  end,
}

return { filtro_documento }
