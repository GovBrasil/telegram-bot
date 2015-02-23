-- Telegram Plugin to query data from "Camara dos Deputados"
--
-- Copyright 2015 Joenio Costa
-- http://joenio.me/
--
-- Authors: Joenio Costa <joenio AT colivre.coop.br>
--          Valessio Brito <valessio AT gmail.com>
--
-- This code is released under the terms of the GNU General Public License
-- version 2 or any later version.
--
--
-- consulta pauta dos orgaos
-- http://www2.camara.leg.br/transparencia/dados-abertos/dados-abertos-legislativo/webservices/orgaos/obterpauta
--
-- consulta lista de orgaos
-- http://www2.camara.leg.br/transparencia/dados-abertos/dados-abertos-legislativo/webservices/orgaos/obterorgaos
--
-- dependencias de execucao, num Debian execute:
-- apt-get install lua5.2 lua-socket lua-expat redis-server lua-redis
--
-- este plugin faz cache de requisicoes HTTP em banco Redis por 12 horas

local http = require("socket.http")
local lxp = require("lxp")
local redis = require("redis")

local client = redis.connect('127.0.0.1', 6379)

function get_from_cache(cache_key, block)
  local value = client:get(cache_key)
  if not value then
    value = block()
    client:set(cache_key, value)
    client:expire(cache_key, 43200) -- 43200 = 12 * 60 * 60 (12 hours)
  end
  return value
end

function obter_pauta(orgao_id)
  today = os.date("%d/%m/%Y")
  url = "http://www.camara.gov.br/SitCamaraWS/Orgaos.asmx/ObterPauta?datFim=&IDOrgao="..orgao_id.."&datIni="..today
  cache_key = 'http:request:'..url
  value = get_from_cache(cache_key, function()
    b, c, h = http.request(url)
    return b
  end)
  return value
end

function parse_pauta(xml)
  reuniao = {}
  reunioes = {}
  key = nil
  callbacks = {
    StartElement = function(parser, name)
      if (name == "reuniao" or name == "pauta") then
        reuniao = {}
      else
        key = name
      end
    end,
    CharacterData = function(parser, data)
      if key and data and not string.isblank(data) then
        reuniao[key] = data
      end
    end,
    EndElement = function(parser, name)
      if (name == "reuniao") then
        table.insert(reunioes, reuniao)
      end
    end
  }
  p = lxp.new(callbacks)
  p:parse(xml)
  p:close()
  return reunioes
end

function reuniao_to_string(reuniao)
  return "Dia "
    ..reuniao["data"]
    .." as "
    ..reuniao["horario"]
    .." "
    ..reuniao["tituloReuniao"]
    .." no(a) "
    ..reuniao["local"]
end

function parse_orgaos(xml)
  orgaos = {}
  callbacks = {
    StartElement = function(parser, name, attributes)
      if (name == "orgao") then
        orgaos[attributes["id"]] = attributes
      end
    end
  }
  p = lxp.new(callbacks)
  p:parse(xml)
  p:close()
  return orgaos
end

function obter_orgaos()
  url = "http://www.camara.gov.br/SitCamaraWS/Orgaos.asmx/ObterOrgaos"
  cache_key = 'http:request:'..url
  value = get_from_cache(cache_key, function()
    b, c, h = http.request(url)
    return b
  end)
  return value
end

function run(msg, matches)
  orgaos_xml = obter_orgaos()
  orgaos = parse_orgaos(orgaos_xml)
  text = ""
  for id in pairs(orgaos) do
    orgao = orgaos[id]
    pauta_xml = obter_pauta(orgao["id"])
    reunioes = parse_pauta(pauta_xml)
    if (#reunioes > 0) then
      text = text .. orgao["sigla"] .. "\n"
      for i,reuniao in ipairs(reunioes) do
        text = text .. "* " .. reuniao_to_string(reuniao) .. "\n"
      end
    end
  end
  return text
end

return {
  description = "Consulta fonte de dados abertos da Camara dos Deputados",
  usage = "!pauta: Retorna pauta da semana da Camara dos Deputados federais",
  patterns = {"^!pauta$"},
  run = run
}
