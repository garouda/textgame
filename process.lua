local proc = {}
local commands = require("res.commands")
setmetatable(proc, { __call = function(_, ...) return proc.process(...) end})

local working_src = {}

function proc.setSrc(src) working_src = src end
function proc.getSrc() return working_src end
--

local synonyms = {}
for i,v in pairs{"res/text/thesaurus.txt"} do
  if love.filesystem.getInfo(v) then
    for l in love.filesystem.lines(v) do
      local key, value = l:match("(.+)%s*[:=]%s*(.*)")
      local s = {}
      value = value or ""
      for w in value:gmatch(",*%s*([%w%s-]+)%s*,*%s*") do
        s[#s+1] = w
      end
      s[#s+1] = key
      if not l:match("^%s*//") then synonyms[key:lower()] = s end
    end
  end
end
--
local function correct_vowel(text,insert,orig_word)
  -- Correct to a/an with regards to whether b begins with vowel.
  -- Does not account for phonemes that are written as consonants but pronounced as vowels (e.g. X-Ray) but that scenario should never arise.
  local _vowel = __.any({"a","e","i","o","u"}, function(_,l) return l == insert:sub(1,1):lower() end)
  return text:gsub("(%w*)([aA])(n?)%s"..orig_word.."([%A^_])", function(a,b,c,d)
      if a=="" then
        if _vowel then c = "n" else c = "" end
        return a..b..c.." "..insert..d
      end
    end, 1)
end
--

local function thesaurus(text,word)
  local no_linebreak = text:gsub("\n","")
  local s, e = no_linebreak:find("{"..Misc.sanitize(word).."}")
  if not s then return text end
  local replacement
  if not synonyms[word] then
    replacement = word
  else
    replacement = synonyms[word][math.random(1, #synonyms[word])]
  end
  if no_linebreak:sub(s-2, e):match("[%?%!%.]") then replacement = Misc.capitalize(replacement) else replacement = replacement:lower() end

  text = correct_vowel(text, replacement, "{"..Misc.sanitize(word).."}")

  return text:gsub("{"..Misc.sanitize(word).."}", replacement, 1)
end
--

local function clean_up(text)
  text = text:gsub("@[%w_]+%b()", ""):gsub("%b<>",""):gsub("[%[%]]",""):gsub("~",""):gsub("^%s*", ""):gsub("%s*$", ""):gsub("\n\n+","\n\n")
  return text
end
--

function proc.getReplacementList(ent)
  local list = {
    ["chosen"] = choices.chosen,
    ["chosen_n"] = choices.chosen_n,
    ["input"] = input.result,
    ["lastsrc"] = tostring(out.last_src):lower(),
    ["lasttext"] = out.last_text,
    ["checkpoint"]=out.checkpoint,
    ["weather"] = weather.get(),
    ["enemy"]=combat.enemies[1],
  }
  for _,ref in pairs{"self","player","enemy","ally","target"} do
    list[ref]=ent.name
    list[ref.."species"]=Misc.capitalize(ent.species)
    list[ref.."lvl"]=ent.lvl
    list[ref.."hasweapon"]=ent.equipped[1] and true or false
    list[ref.."hashat"]=ent.equipped[2] and true or false
    list[ref.."hastop"]=ent.equipped[3] and true or false
    list[ref.."hasbottom"]=ent.equipped[4] and true or false
    list[ref.."hasclothing"]=(ent.equipped[2] or ent.equipped[3] or ent.equipped[4]) and true or false
    list[ref.."skin_col"]=species[ent.species].species_colors[ent.skin_col]
    list[ref.."skin_col_n"]=ent.skin_col
    for i,v in pairs(species[ent.species]) do if type(v)~="table" then list[ref..i] = v end end
  end
  return list
end
--

local function get_public(text,var,ent)
  local pad = 3
  local ref = "player"
  var = var:lower()

  for e,t in pairs{["self"]=ent,["player"]=player,["enemy"]=combat.enemies[1],["ally"]=(combat.allies[1])} do
    if var:match(e) then
      ent = ent or t
      ref = e
    end
  end

  ent = ent or player

  if not ref then return text end

  local public = proc.getReplacementList(ent)

  local p = public[var]
  local flg = flags[var:match("^flag:(.+)")] or (var:match("^tempflag:(.+)") and flags["~~"..var:match("^tempflag:(.+)")])

  while p==nil and not flg do
    var = var:sub(1,-2)
    if #var==0 then return text end
    p = public[var]
  end

  p = flg and (tostring(flg)) or tostring(p)

  local s, e = text:find("#"..Misc.sanitize(var))

  if not s then return text end
  -- Correct capitalization and a/an
  if var~="lasttext" then
    if (text:sub(s-pad, e):match("[%?%!%.]") or #text:sub(s-pad, e) < pad) then p = Misc.capitalize(p)
    elseif var~=ref and var~=ref.."species" and var~="input" then
      p = p:lower()
    end
  end

  text = correct_vowel(text, p, "#"..Misc.sanitize(var))

  return text:gsub("#"..var, p, 1)
end
--

function proc.insert(text)
  if not next(working_src.insert or {}) then return text end
  for m in text:gmatch("%b[]") do
    local e = {}
    local ins = proc.replace(m):lower()
    for i,v in pairs(working_src.insert[ins:gsub("[%[%]]","")] or {}) do
      local p = proc.process(v:gsub("\\n","\n") or v)
      if p ~= "" then table.insert(e,p) break end
    end
    text = text:gsub("%["..m:sub(2,-2).."%]", e[math.random(1,#e)] or "")
  end
  return text
end
--
function proc.replace(text,ent)
  -- replace variable name with the value it represents
  for var in text:gmatch("#([%w_:]+)") do
    text = get_public(text,var,ent)
  end
  return text
end
--
function proc.exec_cmd(text,ent,target)
  text = text or ""
  local eval = false
  local cmd, identity, p = "", "", ""
  local function reset()
    cmd,identity,p = text:match("(@(%w+)(%b()))")
    p = (p or ""):sub(2,-2)
  end
  reset()
  while cmd do
    local len, depth, params, current = 0, 0, {}, ""
    local function insert()
      current = Misc.autoCast(current)
      table.insert(params, current)
      current = ""
    end
    for char in p:gmatch(".") do
      len = len + 1
      if char == "(" then depth = depth + 1 elseif char == ")" then depth = depth - 1 end
      if (char == "|" and depth == 0) then insert() else current = current..char end
      if len == #p then insert() end
    end
    -- Execute the command with the supplied parameters
    local output
    for i=1,2 do if type(params[i])=="string" then params[i] = Misc.autoCast(proc.replace(params[i])) end end
    identity = identity:lower()
    if commands[identity] then output = commands[identity](params,{cmd=cmd,text=text}) end
    if output then eval = true end
    output = text:gsub(Misc.sanitize(cmd),output or "")
    text = output or text
    reset()
  end
  return text,eval
end
--
function proc.synonym(text)
  -- Replace marked words with random synonyms
  for t in text:gmatch("%{([%w|_%s-]+)%}") do
    text = thesaurus(text,t)
  end
  return text
end
--

function proc.process(text,ent)
  if not text or type(text)~="string" then return "" end
  local raw = text
  local half_raw
  local eval
  text = proc.insert(text)
  half_raw = text
  text, eval = proc.exec_cmd(text)
  -- Attempt synonym and var fetching after executing commands in case a command returned one.
  text = proc.replace(text,ent)
  text = proc.synonym(text)

  -- Return both the processed and the raw text, as well as the raw text with insertions. eval signifies whether a command was executed or not.
  return clean_up(text), raw, half_raw, eval
end
--

return proc