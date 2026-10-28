--[[
Confere o YAML antes dos outros filtros e explica os problemas em português.

Erros (param a renderização):
  - arquivo de `bibliography` que não existe (relativo à pasta do .qmd);
  - `tipo` que não está em tipos.lua.
Avisos (a renderização continua):
  - campo de topo desconhecido (com sugestão do nome mais parecido);
  - campo básico vazio (title, author, ano, curso, orientador), que aparece
    como [preencha: campo] em vermelho no PDF;
  - `genero`, `orientador-genero` ou `coorientador-genero` diferente de f/m;
  - `tipo-trabalho` em texto livre sem `tipo`;
  - resumo/abstract fora de 150 a 500 palavras;
  - `defesa` sem membros da banca;
  - lembrete (uma vez) dos elementos da versão final de dissertações e teses;
  - citações no texto sem `bibliography`;
  - `lang` sem rótulos na extensão (cai no português);
  - trabalho em outro idioma sem `titulo-traduzido`.

Valores "" contam como ausentes: o _extension.yml declara vários campos com
"" e esses padrões chegam aqui misturados aos do documento.
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

-- Campos conhecidos ----------------------------------------------------------
-- Tarefas que criarem chaves novas no YAML devem acrescentá-las aqui.

local CAMPOS_CONHECIDOS = {
  -- _extension.yml (formato)
  "template", "pdf-engine", "pdf-engine-opts", "lang", "csl", "top-level-division",
  "filters", "keep-tex", "date-format", "toc", "number-sections",
  -- _extension.yml (dados do trabalho)
  "tipo", "tipo-trabalho", "genero", "titulo-pretendido", "curso",
  "area-concentracao", "orientador", "orientadora", "orientador-genero",
  "coorientador", "coorientadora", "coorientador-genero", "cidade", "ano",
  "instituicao", "frente-verso", "ficha-catalografica", "indicadores-impacto",
  "banca-um-nome", "banca-um-inst", "banca-dois-nome", "banca-dois-inst",
  "banca-tres-nome", "banca-tres-inst", "banca-quatro-nome", "banca-quatro-inst",
  "defesa", "dedicatoria", "agradecimentos", "epigrafe", "epigrafe-autor",
  "abstract-en", "keywords-en", "indicadores-impacto-texto",
  "impact-indicators-texto", "fc-autor-sobrenome", "fc-autores", "fc-tipo",
  "fc-catalogacao", "fc-classificacao", "fc-ilust",
  -- Quarto/Pandoc que o autor costuma usar
  "title", "subtitle", "author", "date", "abstract", "keywords", "bibliography",
  "references", "nocite", "link-citations", "link-bibliography", "citeproc",
  "cite-method", "citation", "format", "execute", "knitr", "jupyter", "engine",
  "crossref", "lof", "lot", "toc-depth", "toc-title", "number-depth",
  "number-offset", "editor", "params", "freeze", "echo", "eval", "warning",
  "error", "include", "output", "message", "cache", "language", "highlight-style",
  "code-block-bg", "code-block-border-left", "documentclass", "classoption",
  "geometry", "fontsize", "linestretch", "mainfont", "sansfont", "monofont",
  "mathfont", "fontfamily", "papersize", "include-in-header",
  "include-before-body", "include-after-body", "header-includes",
  "include-before", "include-after", "metadata-files", "resource-path",
  "output-file", "output-dir", "abstract-title", "appendix-style",
  "reference-location", "cap-location", "df-print", "shortcodes", "draft",
  "colorlinks", "linkcolor", "urlcolor", "citecolor", "filecolor", "toccolor",
  "links-as-notes", "listings", "indent", "block-headings", "mermaid",
  "biblio-config", "biblio-title", "biblatexoptions", "natbiboptions",
  -- chaves que o próprio Quarto injeta nos metadados
  "authors", "by-author", "affiliations", "by-affiliation", "labels",
  "revealjs-plugins",
  -- elementos.lua (listas pré-textuais, glossário, lista de quadros)
  "siglas", "simbolos", "glossario", "loq",
  -- trabalhos em outro idioma (título em português na folha de aprovação)
  "titulo-traduzido",
}

-- Prefixos de famílias de opções do Quarto (fig-width, tbl-cap-location, ...).
local PREFIXOS_CONHECIDOS = {
  "fig-", "tbl-", "lst-", "eq-", "code-", "callout-", "quarto-", "title-block-",
  "latex-", "pdf-", "toc-", "number-", "ufla-", "_",
}

local CONHECIDOS = {}
for _, k in ipairs(CAMPOS_CONHECIDOS) do CONHECIDOS[k] = true end

local function conhecido(campo)
  if CONHECIDOS[campo] then return true end
  for _, p in ipairs(PREFIXOS_CONHECIDOS) do
    if campo:sub(1, #p) == p then return true end
  end
  return false
end

-- Tipos na ordem do Quadro 3.1 do manual (para as mensagens).
local ORDEM_TIPOS = util.chaves_tipos(TIPOS)

-- Auxiliares -----------------------------------------------------------------

-- Espaços só ASCII: no Windows, o %s do Lua casa o byte 0xA0, que é o fim
-- do "à" em UTF-8 (C3 A0).
local function apara(s)
  return (s:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function texto(v)
  if v == nil then return "" end
  if pandoc.utils.type(v) == "Blocks" then
    v = pandoc.utils.blocks_to_inlines(v, { pandoc.Space() })
  end
  return apara(stringify(v))
end

local function vazio(v) return texto(v) == "" end

local function verdadeiro(v)
  return v == true or texto(v):lower() == "true"
end

-- Palavras: trechos entre espaços com ao menos uma letra ou algarismo
-- (bytes >= 0x80 são letras acentuadas em UTF-8).
local function conta_palavras(v)
  local n = 0
  for trecho in texto(v):gmatch("[^ \t\r\n]+") do
    if trecho:find("[A-Za-z0-9\128-\255]") then n = n + 1 end
  end
  return n
end

-- Valor de `bibliography` (texto ou lista) -> lista de caminhos.
local function caminhos_bib(v)
  local r = {}
  if v == nil then return r end
  if pandoc.utils.type(v) == "List" then
    for _, item in ipairs(v) do
      local s = texto(item)
      if s ~= "" then r[#r + 1] = s end
    end
  else
    local s = texto(v)
    if s ~= "" then r[#r + 1] = s end
  end
  return r
end

-- O Quarto roda o Pandoc com a pasta do .qmd como diretório atual. O Pandoc
-- lê o arquivo (pandoc.mediabag.fetch), o que funciona com acentos no
-- Windows, ao contrário do io.open do Lua.
local function existe(caminho)
  local ok = pcall(pandoc.mediabag.fetch, caminho)
  return ok
end

-- Regras -----------------------------------------------------------------------

local function confere_bibliography(meta, erros)
  local pasta = pandoc.system.get_working_directory()
  for _, rel in ipairs(caminhos_bib(meta.bibliography)) do
    local caminho = rel
    if not pandoc.path.is_absolute(caminho) then
      caminho = pandoc.path.join({ pasta, rel })
    end
    caminho = pandoc.path.normalize(caminho)
    if not existe(caminho) then
      erros[#erros + 1] = string.format(
        'Não encontrei o arquivo de referências "%s". Procurei em: %s. '
          .. "Confira o nome e se ele está na mesma pasta do .qmd.",
        rel, pandoc.path.directory(caminho))
    end
  end
end

local function confere_tipo(meta, erros)
  local valor = texto(meta.tipo)
  if valor == "" or TIPOS[valor:lower()] then return end
  local msg = string.format('tipo: "%s" não existe.', valor)
  local sugestao = util.sugerir(valor:lower(), ORDEM_TIPOS)
  if sugestao then msg = msg .. string.format(' Você quis dizer "%s"?', sugestao) end
  erros[#erros + 1] = msg .. " Use um destes: " .. table.concat(ORDEM_TIPOS, ", ") .. "."
end

local function confere_campos(meta)
  local desconhecidos = {}
  for campo in pairs(meta) do
    if not conhecido(campo) then desconhecidos[#desconhecidos + 1] = campo end
  end
  table.sort(desconhecidos)
  for _, campo in ipairs(desconhecidos) do
    local sugestao = util.sugerir(campo, CAMPOS_CONHECIDOS)
    if sugestao then
      util.aviso(string.format('Campo "%s" desconhecido — você quis dizer "%s"?', campo, sugestao))
    else
      util.aviso(string.format('Campo "%s" não é usado pela extensão.', campo))
    end
  end
end

local function falta(campo)
  util.aviso(string.format('Falta preencher "%s" (aparece como [preencha: %s] no PDF).',
    campo, campo))
end

local function confere_basicos(meta)
  if vazio(meta.title) then falta("title") end
  if vazio(meta.author) then falta("author") end
  if vazio(meta.ano) and vazio(meta.date) then falta("ano") end
  if vazio(meta.curso) then falta("curso") end
  if vazio(meta.orientador) and vazio(meta.orientadora) then falta("orientador") end
end

local function confere_generos(meta)
  for _, campo in ipairs({ "genero", "orientador-genero", "coorientador-genero" }) do
    local v = texto(meta[campo])
    if v ~= "" and v:lower() ~= "f" and v:lower() ~= "m" then
      util.aviso(string.format(
        '%s: "%s" não é válido; use f (feminino) ou m (masculino).', campo, v))
    end
  end
end

local function confere_tipo_trabalho(meta, reconhecido)
  if reconhecido then return end
  local p = TIPOS["dissertacao"]
  local msg = string.format('tipo-trabalho "%s" sem tipo: — a nota descritiva usará "%s"',
    texto(meta["tipo-trabalho"]), p.nivel)
  if vazio(meta["titulo-pretendido"]) then
    msg = msg .. string.format(' e o título "%s"', p.titulo)
  end
  util.aviso(msg .. ". Defina tipo: para escolher o nível (ex.: tipo: tcc).")
end

local function confere_resumos(meta)
  for _, par in ipairs({ { "abstract", "resumo" }, { "abstract-en", "abstract" } }) do
    local campo, nome = par[1], par[2]
    if not vazio(meta[campo]) then
      local n = conta_palavras(meta[campo])
      if n < 150 or n > 500 then
        util.aviso(string.format("O %s tem %d palavras; o manual pede de 150 a 500.", nome, n))
      end
    end
  end
end

local BANCA = { "banca-um-nome", "banca-dois-nome", "banca-tres-nome", "banca-quatro-nome" }

local function confere_banca(meta)
  if vazio(meta.defesa) then return end
  for _, campo in ipairs(BANCA) do
    if not vazio(meta[campo]) then return end
  end
  util.aviso("A folha de aprovação está sem membros da banca (banca-um-nome, "
    .. "banca-um-inst, banca-dois-nome, ...).")
end

local function confere_versao_final(meta, chave)
  if not TIPOS[chave].stricto then return end
  if vazio(meta.defesa) or not verdadeiro(meta["ficha-catalografica"])
      or vazio(meta["indicadores-impacto-texto"]) then
    util.aviso("Lembrete para a versão final: dissertações e teses precisam de "
      .. "folha de aprovação (defesa:), ficha catalográfica e indicadores de impacto.")
  end
end

local function confere_citacoes(doc)
  if #caminhos_bib(doc.meta.bibliography) > 0 or doc.meta.references ~= nil then return end
  local eh_crossref = util.crossref(doc)
  local chaves, vistas = {}, {}
  doc.blocks:walk({
    Cite = function(cite)
      for _, c in ipairs(cite.citations) do
        if not vistas[c.id] and not eh_crossref(c.id) then
          vistas[c.id] = true
          chaves[#chaves + 1] = "@" .. c.id
        end
      end
    end,
  })
  if #chaves == 0 then return end
  local lista = chaves
  if #chaves > 5 then
    lista = { table.unpack(chaves, 1, 5) }
    lista[#lista + 1] = string.format("e mais %d", #chaves - 5)
  end
  util.aviso(string.format('O texto cita %s, mas não há "bibliography:" no YAML.',
    table.concat(lista, ", ")))
end

local function confere_idioma(meta)
  local idioma, suportado, bruto = util.idioma(meta)
  if not suportado then
    util.aviso(string.format('lang: "%s" não é suportado; os rótulos do texto (Figura, '
      .. 'Fonte, APÊNDICE, REFERÊNCIAS...) ficam em português. Idiomas com rótulos '
      .. 'próprios: pt, en, es.', bruto))
    return
  end
  if idioma ~= "pt" and vazio(meta["titulo-traduzido"]) then
    util.aviso('Trabalho em outro idioma: preencha "titulo-traduzido" (o manual exige '
      .. 'o título em português na folha de aprovação).')
  end
end

-- Filtro -----------------------------------------------------------------------

function Pandoc(doc)
  local meta = doc.meta
  local erros = {}
  confere_bibliography(meta, erros)
  confere_tipo(meta, erros)

  confere_campos(meta)
  confere_basicos(meta)
  confere_generos(meta)
  local chave, reconhecido = util.preset(meta, TIPOS)
  confere_tipo_trabalho(meta, reconhecido)
  confere_resumos(meta)
  confere_banca(meta)
  confere_versao_final(meta, chave)
  confere_citacoes(doc)
  confere_idioma(meta)

  util.erros(erros)
  return nil
end
