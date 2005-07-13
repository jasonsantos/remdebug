local socket = require"socket"

print("Lua Remote Debugger")

local breakpoints = {}

while true do
  io.write("> ")
  local line = io.read("*line")
  command = string.sub(line, string.find(line, "^[a-z]+"))
  if command == "run" then
    break
  elseif command == "exit" then
    os.exit()
  elseif command == "setb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]+)%s+(%d+)$")
    if not breakpoints[filename] then breakpoints[filename] = {} end
    local breaks = breakpoints[filename]
    breakpoints[filename][line] = true
  elseif command == "delb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]w+)%s+(%d+)$")
    breakpoints[filename][line] = nil
  elseif command == "listb" then
    for k, v in pairs(breakpoints) do
      io.write(k .. ": ")
      for k, v in pairs(v) do
        io.write(k .. " ")
      end
      io.write("\n")
    end
  else
    print("Invalid command")
  end
end

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
    if not breakpoints[filename] then breakpoints[filename] = {} end
    local breaks = breakpoints[filename]
    breakpoints[filename][line] = true
    client:send("SETB " .. filename .. " " .. line .. "\n")
    client:receive()
  elseif command == "delb" then
    local _, _, _, filename, line = string.find(line, "^([a-z]+)%s+([%w%p]+)%s+(%d+)$")
    breakpoints[filename][line] = nil
    client:send("DELB " .. filename .. " " .. line .. "\n")
    client:receive()
  elseif command == "listb" then
    for k, v in pairs(breakpoints) do
      io.write(k .. ": ")
      for k, v in pairs(v) do
        io.wite(k .. " ")
      end
      io.write("\n")
    end
  else
    print("Invalid command")
  end
end
