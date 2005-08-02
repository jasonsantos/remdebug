--
-- RemDebug 1.0 Alpha
-- Copyright Kepler Project 2005 (http://www.keplerproject.org/remdebug)
--

local socket = require"socket"

print("Lua Remote Debugger")
print("Type 'help' for commands")

local breakpoints = {}
local watches = {}

while true do
  io.write("> ")
  local line = io.read("*line")
  command = string.sub(line, string.find(line, "^[a-z]+"))
  if command == "wait" then
    break
  elseif command == "exit" then
    os.exit()
  elseif command == "setb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]+)%s+(%d+)$")
    if filename and line then
      if not breakpoints[filename] then breakpoints[filename] = {} end
      breakpoints[filename][line] = true
    else
      print("Invalid command")
    end
  elseif command == "setw" then
    local _, _, exp = string.find(line, "^[a-z]+%s+(.+)$")
    if exp then
      local newidx = table.getn(watches) + 1
      watches[newidx] = exp
      table.setn(watches, newidx)
      print("Inserted watch exp no. " .. newidx)
    else
      print("Invalid command")
    end
  elseif command == "delb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]w+)%s+(%d+)$")
    if filename and line then
      breakpoints[filename][line] = nil
    else
      print("Invalid command")
    end
  elseif command == "delw" then
    local _, _, index = string.find(line, "^[a-z]+%s+(%d+)$")
    if index then
      watches[index] = nil
    else
      print("Invalid command")
    end
  elseif command == "listb" then
    for k, v in pairs(breakpoints) do
      io.write(k .. ": ")
      for k, v in pairs(v) do
        io.write(k .. " ")
      end
      io.write("\n")
    end
  elseif command == "listw" then
    for i, v in ipairs(watches) do
      print("Watch exp. " .. i .. ": " .. v)
    end    
  elseif command == "help" then
    print("setb <file> <line>    -- sets a breakpoint")
    print("delb <file> <line>    -- removes a breakpoint")
    print("setw <exp>            -- adds a new watch expression")
    print("delw <index>          -- removes the watch expression at index")
    print("wait                  -- waits for program to run")
    print("listb                 -- lists breakpoints")
    print("listw                 -- lists watch expressions")
    print("exit                  -- exits debugger")
  else
    print("Invalid command")
  end
end

print("Now run the program you wish to debug")

local server = socket.bind("*", 8171)
local client = server:accept()

for file, breaks in pairs(breakpoints) do
  for line, _ in pairs(breaks) do
    client:send("SETB " .. file .. " " .. line .. "\n")
    client:receive()
  end
end

for index, exp in ipairs(watches) do
  client:send("SETW " .. exp .. "\n")
  client:receive()
end

client:send("RUN\n")
client:receive()

local breakpoint = client:receive()
local _, _, file, line = string.find(breakpoint, "^202 Paused%s+([%w%p]+)%s+(%d+)$")
print("Breakpoint reached at file " .. file .. " line " .. line)

while true do
  io.write("> ")
  local line = io.read("*line")
  command = string.sub(line, string.find(line, "^[a-z]+"))
  if command == "run" or command == "step" or command == "over" then
    client:send(string.upper(command) .. "\n")
    client:receive()
    local breakpoint = client:receive()
    if not breakpoint then
      print("Program finished")
      os.exit()
    end
    local _, _, file, line = string.find(breakpoint, "^202 Paused%s+([%w%p]+)%s+(%d+)$")
    print("Breakpoint reached at file " .. file .. " line " .. line)
  elseif command == "exit" then
    client:close()
    os.exit()
  elseif command == "setb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]+)%s+(%d+)$")
    if filename and line then
      if not breakpoints[filename] then breakpoints[filename] = {} end
      breakpoints[filename][line] = true
      client:send("SETB " .. filename .. " " .. line .. "\n")
      client:receive()
    else
      print("Invalid command")
    end
  elseif command == "setw" then
    local _, _, exp = string.find(line, "^[a-z]+%s+(.+)$")
    if exp then
      local newidx = table.getn(watches) + 1
      watches[newidx] = exp
      table.setn(watches, newidx)
      print("Inserted watch exp no. " .. newidx)
      client:send("SETW " .. exp .. "\n")
      client:receive()
    else
      print("Invalid command")
    end
  elseif command == "delb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]+)%s+(%d+)$")
    if filename and line then
      breakpoints[filename][line] = nil
      client:send("DELB " .. filename .. " " .. line .. "\n")
      client:receive()
    else
      print("Invalid command")
    end
  elseif command == "delw" then
    local _, _, index = string.find(line, "^[a-z]+%s+(%d+)$")
    if index then
      watches[index] = nil
      client:send("DELW " .. index .. "\n")
      client:receive()
    else
      print("Invalid command")
    end
  elseif command == "eval" then
    local _, _, exp = string.find(line, "^[a-z]+%s+(.+)$")
    if exp then 
      client:send("EVAL " .. exp .. "\n")
      local line = client:receive()
      local _, _, len = string.find(line, "^200 OK (%d+)$")
      len = tonumber(len)
      local res = client:receive(len)
      print(res)
    else
      print("Invalid command")
    end
  elseif command == "listb" then
    for k, v in pairs(breakpoints) do
      io.write(k .. ": ")
      for k, v in pairs(v) do
        io.wite(k .. " ")
      end
      io.write("\n")
    end
  elseif command == "listw" then
    for i, v in ipairs(watches) do
      print("Watch exp. " .. i .. ": " .. v)
    end    
  elseif command == "help" then
    print("setb <file> <line>    -- sets a breakpoint")
    print("delb <file> <line>    -- removes a breakpoint")
    print("setw <exp>            -- adds a new watch expression")
    print("delw <index>          -- removes the watch expression at index")
    print("run                   -- run until next breakpoint")
    print("step                  -- run until next line, stepping into function calls")
    print("over                  -- run until next line, stepping over function calls")
    print("listb                 -- lists breakpoints")
    print("listw                 -- lists watch expressions")
    print("eval <exp>            -- evaluates expression on the current context")
    print("exit                  -- exits debugger")
  else
    print("Invalid command")
  end
end
