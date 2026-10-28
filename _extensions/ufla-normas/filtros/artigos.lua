--[[
Formato de artigos (`formato: artigos`; manual, Figura 3.23 e seções 4 e 5).

1. Partes: `# Primeira parte {.parte}` vira um título sem número, em caixa
   alta, negrito e centralizado, em página nova e no sumário. Com o título
   vazio (`# {.parte}`) o texto vem de `lang`: "PRIMEIRA PARTE", "SEGUNDA
   PARTE – ARTIGOS" (quando a parte tem artigos), "TERCEIRA PARTE"; "FIRST
   PART"... em inglês.
2. Artigos: `# Título {.artigo nota="..."}` vira "ARTIGO 1 – TÍTULO", com a
   nota de rodapé `nota`; as seções do artigo (##, ###) são numeradas 1, 1.1,
   recomeçando em cada artigo (template.tex: \uflaArtigo, \uflaFimArtigos).
3. Referências de cada artigo: as citações de um artigo passam pelo citeproc
   só com o texto do artigo, e a lista "REFERÊNCIAS" (só com as obras citadas
   nele) fica no fim do artigo, ou onde o autor pôs `::: {#refs}` dentro
   dele. `csl="periodico.csl"` no título usa o estilo do periódico naquele
   artigo (manual 4 e 5). As citações já resolvidas saem do documento, então
   a lista geral (citeproc do Quarto, depois de todos os filtros) só tem as
   citações de fora dos artigos; elementos.lua a põe antes dos apêndices.

Roda depois de referencias.lua (chaves sem entrada já viraram "[chave?]") e
de citacoes.lua ("Costa e Ferreira (2022)"), e antes de elementos.lua, que
ainda vê os títulos .apendice/.anexo que terminam o último artigo.

Sem `formato: artigos`, títulos .parte/.artigo geram um aviso e ficam como
capítulos comuns.
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

-- Espaços só ASCII: no Windows, o %s do Lua casa o byte 0xA0 (fim do "à").
local function texto(v)
  if v == nil then return "" end
  return (stringify(v):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function latex(s) return pandoc.RawInline("latex", s) end

--- Caixa alta correta para Unicode ("é" -> "É", "ç" -> "Ç").
local function maiusculas(inl)
  return inl:walk({
    Str = function(s)
      s.text = pandoc.text.upper(s.text)
      return s
    end,
  })
end

--- Texto simples ("SEGUNDA PARTE") -> Inlines.
local function inlines(s)
  local r = pandoc.Inlines({})
  for palavra in s:gmatch("[^ ]+") do
    if #r > 0 then r:insert(pandoc.Space()) end
    r:insert(pandoc.Str(palavra))
  end
  return r
end

local function classe(b)
  if b.t ~= "Header" then return nil end
  if b.classes:includes("parte") then return "parte" end
  if b.classes:includes("artigo") then return "artigo" end
  return nil
end

--- Rótulo LaTeX: o id do autor se for ASCII, senão `reserva`.
local function rotulo(header, reserva)
  local id = header.identifier
  if id ~= "" and id:match("^[%w_:%.%-]+$") then return id end
  return reserva
end

local function eh_oculto(b)
  return b.t == "Div" and b.classes:includes("hidden")
end

-- Avisos fora do formato de artigos ---------------------------------------

local function avisa_marcas_sem_formato(doc, formato)
  local achou = false
  doc.blocks:walk({
    Header = function(h) if classe(h) then achou = true end end,
  })
  if achou then
    util.aviso("Há títulos {.parte} ou {.artigo}, mas o formato é \"" .. formato
      .. "\": eles ficaram como capítulos comuns. Para o formato de artigos, "
      .. "use formato: artigos no YAML.")
  end
end

local function avisa_estrutura(doc)
  local partes, artigos = 0, 0
  doc.blocks:walk({
    Header = function(h)
      local c = classe(h)
      if c and h.level > 1 then
        util.aviso('"' .. stringify(h.content) .. '": partes e artigos usam título de '
          .. "nível 1 (# Título {." .. c .. "}); este ficou como seção comum.")
      elseif c == "parte" then partes = partes + 1
      elseif c == "artigo" then artigos = artigos + 1
      end
    end,
  })
  if partes == 0 then
    util.aviso("formato: artigos — use # Primeira parte {.parte}, # Segunda parte – "
      .. "Artigos {.parte} e # Terceira parte {.parte} para dividir o trabalho "
      .. "(manual, Figura 3.23). Exemplo:\n"
      .. "    # Segunda parte – Artigos {.parte}\n"
      .. '    # Título do artigo {.artigo nota="Artigo redigido conforme a NBR 6022 (ABNT, 2018)."}')
  end
  if artigos == 0 then
    util.aviso("formato: artigos, mas nenhum título tem a classe {.artigo} "
      .. '(ex.: # Título do artigo {.artigo nota="..."}).')
  end
end

-- Estilo (CSL) de um artigo ------------------------------------------------

--- Caminho do `csl=` do artigo, relativo à pasta do .qmd (o Quarto roda o
--- Pandoc nela, como para `bibliography`). Arquivo inexistente para.
local function caminho_csl(rel, titulo)
  local pasta = pandoc.system.get_working_directory()
  local caminho = rel
  if not pandoc.path.is_absolute(caminho) then
    caminho = pandoc.path.join({ pasta, rel })
  end
  caminho = pandoc.path.normalize(caminho)
  -- o Pandoc lê caminhos com acento no Windows; o io.open do Lua não
  if not pcall(pandoc.mediabag.fetch, caminho) then
    util.erro('Não encontrei o arquivo de estilo "' .. rel .. '" do artigo "' .. titulo
      .. '". Procurei em: ' .. pandoc.path.directory(caminho)
      .. ". Confira o nome e se ele está na mesma pasta do .qmd.")
  end
  return caminho
end

-- Referências de um artigo -----------------------------------------------

--- Resolve as citações de `blocks` (um artigo) com o citeproc e devolve os
--- blocos com a lista "REFERÊNCIAS" do artigo. `n` numera os ids.
local function referencias_artigo(blocks, n, meta, ids_bib, csl)
  -- referências cruzadas (@fig-x, @sec-x) ficam guardadas: o citeproc as
  -- trataria como citações sem entrada
  local guardadas = {}
  local cita = false
  blocks = blocks:walk({
    Cite = function(c)
      for _, cit in ipairs(c.citations) do
        if ids_bib[cit.id] then cita = true; return nil end
      end
      guardadas[#guardadas + 1] = c
      return pandoc.Span({}, pandoc.Attr("ufla-guardada-" .. #guardadas))
    end,
  })

  -- lugar da lista: ::: {#refs} do autor dentro do artigo, senão o fim
  -- (antes dos Divs ocultos que o Quarto põe no fim do documento)
  local pos = nil
  for i, b in ipairs(blocks) do
    if b.t == "Div" and b.identifier == "refs" then pos = i end
  end
  if not cita then
    if pos then blocks:remove(pos) end
  else
    if pos == nil then
      pos = #blocks + 1
      while pos > 1 and eh_oculto(blocks[pos - 1]) do pos = pos - 1 end
      blocks:insert(pos, pandoc.Div({}, pandoc.Attr("refs")))
    end
    local m = {}
    for k, v in pairs(meta) do m[k] = v end
    m.nocite = nil
    m["suppress-bibliography"] = nil
    if csl then m.csl = csl end
    blocks = pandoc.utils.citeproc(pandoc.Pandoc(blocks, m)).blocks
  end

  -- ids únicos (a lista geral também tem #refs e #ref-chave) e citações já
  -- resolvidas viram texto, para o citeproc do Quarto não as ver de novo
  local prefixo = "ref-artigo" .. n .. "-"
  local function novo_id(id)
    if id == "refs" then return "refs-artigo" .. n end
    local chave = id:match("^ref%-(.+)$")
    if chave then return prefixo .. chave end
    return id
  end
  blocks = blocks:walk({
    Cite = function(c) return c.content end,
    Link = function(l)
      local alvo = l.target:match("^#(.+)$")
      if alvo then l.target = "#" .. novo_id(alvo) end
      return l
    end,
  })
  blocks = blocks:walk({
    Span = function(s)
      local k = s.identifier:match("^ufla%-guardada%-(%d+)$")
      if k then return guardadas[tonumber(k)] end
    end,
  })
  local saida = pandoc.Blocks({})
  for _, b in ipairs(blocks) do
    if b.t == "Div" and b.identifier == "refs" then
      b = b:walk({
        Div = function(d)
          if d.identifier ~= "" then d.identifier = novo_id(d.identifier) end
          return d
        end,
      })
      b.identifier = novo_id("refs")
      -- título "REFERÊNCIAS" sem página nova, no sumário dentro do artigo
      saida:insert(pandoc.RawBlock("latex", "\\begingroup\\uflaRefsArtigo"))
      saida:insert(b)
      saida:insert(pandoc.RawBlock("latex", "\\endgroup"))
    else
      saida:insert(b)
    end
  end
  return saida
end

-- Títulos --------------------------------------------------------------------

local function titulo_parte(h, n, tem_artigos, rot)
  local inl
  if #h.content == 0 then
    local nome = rot.partes[n] or (rot.parte .. " " .. n)
    if tem_artigos then nome = nome .. " – " .. rot.artigos end
    inl = inlines(nome)
  else
    inl = maiusculas(h.content)
  end
  local r = pandoc.Inlines({ latex("\\uflaParte{" .. rotulo(h, "parte-" .. n) .. "}{") })
  r:extend(inl)
  r:insert(latex("}"))
  return pandoc.Plain(r)
end

local function titulo_artigo(h, n, rot)
  local r = pandoc.Inlines({
    latex("\\uflaArtigo{" .. rotulo(h, "artigo-" .. n) .. "}{"),
    pandoc.Str(rot.artigo), pandoc.Space(), pandoc.Str(tostring(n)),
    pandoc.Space(), pandoc.Str("–"), pandoc.Space(),
  })
  r:extend(maiusculas(h.content))
  r:insert(latex("}{"))
  local nota = texto(h.attributes["nota"])
  if nota ~= "" then
    r:insert(pandoc.Note(pandoc.read(nota, "markdown").blocks))
  end
  r:insert(latex("}"))
  return pandoc.Plain(r)
end

-- Filtro -----------------------------------------------------------------------

function Pandoc(doc)
  local formato = texto(doc.meta.formato):lower()
  if formato == "" then formato = "texto-integral" end
  if formato ~= "artigos" then
    avisa_marcas_sem_formato(doc, formato)
    return nil
  end

  local rot = util.ROTULOS[util.idioma(doc.meta)]
  avisa_estrutura(doc)

  -- chaves da bibliografia (referencias.lua já gravou a lista limpa)
  local ids_bib = {}
  local ok, refs = pcall(pandoc.utils.references, doc)
  if ok and refs then
    for _, item in ipairs(refs) do ids_bib[item.id] = true end
  end

  -- quais partes têm artigos ("SEGUNDA PARTE – ARTIGOS" automático)
  local partes_com_artigos, np = {}, 0
  for _, b in ipairs(doc.blocks) do
    local c = b.t == "Header" and b.level == 1 and classe(b)
    if c == "parte" then np = np + 1
    elseif c == "artigo" then partes_com_artigos[np] = true end
  end

  local saida = pandoc.Blocks({})
  local n_parte, n_artigo = 0, 0
  local artigo = nil          -- { blocos, csl } do artigo aberto
  local numeracao_artigo = false

  local function fecha_artigo()
    if artigo == nil then return end
    local blocos = artigo.blocos
    -- Divs ocultos do Quarto no fim do documento ficam fora do artigo
    local resto = pandoc.Blocks({})
    while #blocos > 0 and eh_oculto(blocos[#blocos]) do
      resto:insert(1, blocos:remove(#blocos))
    end
    saida:extend(referencias_artigo(blocos, n_artigo, doc.meta, ids_bib, artigo.csl))
    saida:extend(resto)
    artigo = nil
  end

  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" and b.level == 1 then
      fecha_artigo()
      local c = classe(b)
      if c ~= "artigo" and numeracao_artigo then
        saida:insert(pandoc.RawBlock("latex", "\\uflaFimArtigos"))
        numeracao_artigo = false
      end
      if c == "parte" then
        n_parte = n_parte + 1
        saida:insert(titulo_parte(b, n_parte, partes_com_artigos[n_parte], rot))
      elseif c == "artigo" then
        n_artigo = n_artigo + 1
        local csl = texto(b.attributes["csl"])
        artigo = {
          blocos = pandoc.Blocks({}),
          csl = csl ~= "" and caminho_csl(csl, stringify(b.content)) or nil,
        }
        saida:insert(titulo_artigo(b, n_artigo, rot))
        numeracao_artigo = true
      else
        saida:insert(b)
      end
    elseif artigo ~= nil then
      artigo.blocos:insert(b)
    else
      saida:insert(b)
    end
  end
  fecha_artigo()
  doc.blocks = saida

  -- sem citações fora dos artigos, não há lista geral (um ::: {#refs}
  -- vazio daria um CSLReferences sem itens)
  local cita_fora = doc.meta.nocite ~= nil
  doc.blocks:walk({
    Cite = function(c)
      for _, cit in ipairs(c.citations) do
        if ids_bib[cit.id] then cita_fora = true end
      end
    end,
  })
  if not cita_fora then doc.meta["suppress-bibliography"] = true end
  return doc
end
