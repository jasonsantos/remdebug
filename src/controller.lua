--
-- RemDebug 0.1 Alpha
-- Copyright Kepler Project 2005 (http://www.keplerproject.org/remdebug)
--

local socket = require"socket"

print("Lua Remote Debugger")
print("Type 'help' for commands")

local breakpoints = {}

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
  elseif command == "delb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]w+)%s+(%d+)$")
    if filename and line then
      breakpoints[filename][line] = nil
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
  elseif command == "help" then
    print("setb <file> <line>    -- sets a breakpoint")
    print("delb <file> <line>    -- removes a breakpoint")
    print("wait                  -- waits for program to run")
    print("listb                  -- lists breakpoints")
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
    local line, status = client:receive()
  end
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
  if command == "run" then
    client:send("RUN\n")
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
  elseif command == "delb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]+)%s+(%d+)$")
    if filename and line then
      breakpoints[filename][line] = nil
      client:send("DELB " .. filename .. " " .. line .. "\n")
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
  elseif command == "help" then
    print("setb <file> <line>    -- sets a breakpoint")
    print("delb <file> <line>    -- removes a breakpoint")
    print("run                   -- run until next breakpoint")
    print("listb                 -- lists breakpoints")
    print("eval <exp>            -- evaluates expression on the current context")
    print("exit                  -- exits debugger")
  else
    print("Invalid command")
  end
end
