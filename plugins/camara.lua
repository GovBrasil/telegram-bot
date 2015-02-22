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
-- consulta as pautas na seguinte fonte de dados:
-- http://www2.camara.leg.br/transparencia/dados-abertos/dados-abertos-legislativo/webservices/orgaos/obterpauta
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

function parse_xml(xml)
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
      if key and not string.isblank(data) then
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

function run(msg, matches)
  xml = obter_pauta(matches[1])
  reunioes = parse_xml(xml)
  text = ""
  for i,reuniao in ipairs(reunioes) do
    text = text .. reuniao_to_string(reuniao) .. "\n"
  end
  return text
end

return {
  description = "Consulta fonte de dados abertos da Camara dos Deputados",
  usage = "!pauta [orgao id]: retorna pautas do orgao informado",
  patterns = {"^!pauta (.*)$"},
  run = run
}
