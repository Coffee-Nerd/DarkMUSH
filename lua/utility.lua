util = {}

defaultFromColor = "@x135"
defaultTextColor = "@x208"

function util.notify(func, text)
  Note("")
  ColourTell(
    "#222222", "#000000", "[",
    "#FF0000", "#000000", "D",
    "#8B0000", "#000000", "E",
    "#FF0000", "#000000", "M",
    "#8B0000", "#000000", "O",
    "#FF0000", "#000000", "N",
    "#222222", "#000000", "]",
    "#000000", "", " "
  )

  local string = string.format(
    "%s@W: %s",
    defaultFromColor .. func:gsub('$C', defaultFromColor),
    defaultTextColor .. text:gsub("$C", defaultTextColor)
  )

  util.print(string)
end

function util.success(func, text)
  util.notify(func .. ' @W| @G[SUCCESS]', text)
end

function util.error(func, text)
  util.notify(func .. ' @W| @R[ERROR]', text)
end

function util.print(string)
  AnsiNote(stylesToANSI(ColoursToStyles(string)))
end

function util.yesno(data, yesText, noText)
  local text  = yesText or 'YES'
  local color = '@G'

  if data == 0 or data == "0" then
    color = "@R"
    text  = noText or 'NO'
  end

  return color .. text
end

function ternary(condition, ifTrue, ifFalse)
  if condition then
    return ifTrue
  else
    return ifFalse
  end
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function table.count(table)
  if type(table) ~= "table" then
    return 0
  end

  index = 0
  for k,v in pairs(table) do
    index = index + 1
  end

  return index
end

function trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

function split(line, delim)
  local result = {}
  local index = 1

  for token in string.gmatch(line, delim) do
    result[index] = token
    index = index + 1
  end

  return result
end


--------------- Debug Functions ---------------

showDebug = false
debugColor = "@x33"

function util.debug(from, ...)
  if not showDebug then
    return
  end

  local info = debug.getinfo(2)

  from = string.format("@RDEBUG [@W%s@R][@WL:%d@R]", from, info.lastlinedefined)

  local args = {...}

  if #args == 0 then
    util.notify(from, "@Rneed at least 1 argument to debug function!")
    return
  end

  local text = debugColor .. args[1]:gsub('$C', debugColor)

  if #args == 1 then
    util.notify(from, text)
    return
  end

  for i = 2,#args do
    if type(args[i]) == 'table' then
      util.notify(from, text)
      tprint(args[i])
    elseif type(args[i]) == 'boolean' then
      util.notify(from, text, (args[i] and 'true') or 'false')
    else
      util.notify(from, text, args[i])
    end
  end
end

function debugbool(source)
  if source then
    return 'true'
  else
    return 'false'
  end
end
