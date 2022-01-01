local json = require('lib.dkjson')

local function read_file(path)
      local file = io.open(path, "rb") -- r read mode and b binary mode
      if not file then return nil end
      local content = file:read "*a" -- *a or *all reads the whole file
      file:close()
      return content
  end
local function getJson(path)
  path = 'sampledata/' .. path
  local str = read_file(path)
  
  -- http://dkolf.de/src/dkjson-lua.fsl/wiki?name=Documentation
  local obj, pos, err = json.decode (str, 1, nil, nil)
  if err then
    print ("Error:", err)
  else
    return obj
  end
end

return {
  s9 = getJson("9.json"),
  s23 = getJson("23.json"),
  s43 = getJson("43.json"),
  s44 = getJson("44.json"),
  s48 = getJson("48.json"),
  s44_alien_max_2000 = getJson("44_alien_max_2000.json"),
  s44_marine_max_2000 = getJson("44_marine_max_2000.json"),
  s44_allsame = getJson("44_allsame.json"),
  s43_allsame = getJson("43_allsame.json"),
}