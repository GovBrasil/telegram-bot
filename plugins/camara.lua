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
-- consulta pauta dos orgaos
-- http://www2.camara.leg.br/transparencia/dados-abertos/dados-abertos-legislativo/webservices/orgaos/obterpauta
--
-- consulta lista de orgaos
-- http://www2.camara.leg.br/transparencia/dados-abertos/dados-abertos-legislativo/webservices/orgaos/obterorgaos
--
-- dependencias de execucao, num Debian execute:
-- apt-get install lua5.2 lua-socket lua-expat

local http = require("socket.http")
local lxp = require("lxp")

function obter_pauta(orgao_id)
  today = os.date("%d/%m/%Y")
  b, c, h = http.request("http://www.camara.gov.br/SitCamaraWS/Orgaos.asmx/ObterPauta?datFim=&IDOrgao="..orgao_id.."&datIni="..today)
  return b
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
    .." na "
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
  b, c, h = http.request("http://www.camara.gov.br/SitCamaraWS/Orgaos.asmx/ObterOrgaos")
  return b
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
  usage = "!pauta: Retorna pauta de todos os orgaos",
  patterns = {"^!pauta$"},
  run = run
}
