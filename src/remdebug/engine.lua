module("remdebug.engine")

local socket = require"socket"

local coro_debugger

local events = { BREAK = 1 }

local breakpoints = {}

local function set_breakpoint(file, line)
  if not breakpoints[file] then
    breakpoints[file] = {}
  end
  breakpoints[file][line] = true  
end

local function remove_breakpoint(file, line)
  if breakpoints[file] then
    breakpoints[file][line] = nil
  end
end

local function has_breakpoint(file, line)
  return breakpoints[file] and breakpoints[file][line]
end

local function line_hook(event, line)
  local file = debug.getinfo(2, "S").source
  if string.find(file, "@") == 1 then
    file = string.sub(file, 2)
  end
  if has_breakpoint(file, line) then
    coroutine.resume(coro_debugger, events.BREAK, file, line)
  end
end

local function debugger_loop()
  local server = socket.connect("localhost","8171")
  local command
  while true do
    local line, status = server:receive()
    command = string.sub(line, string.find(line, "^[A-Z]+"))
    if command == "SETB" then
      local _, _, _, filename, line = string.find(line, "^([A-Z]+)%s+([%w%p]+)%s+(%d+)$")
      set_breakpoint(filename, tonumber(line))
      server:send("200 OK\n")
    elseif command == "DELB" then
      local _, _, _, filename, line = string.find(line, "^([A-Z]+)%s+([%w%p]+)%s+(%d+)$")
      remove_breakpoint(filename, tonumber(line))
      server:send("200 OK\n")
    elseif command == "RUN" then
      server:send("200 OK\n")
      local ev, file, line = coroutine.yield()
      if ev == events.BREAK then
        server:send("202 Paused " .. file .. " " .. line .. "\n")
      end
    else
      server:send("502 Invalid Request\n")
    end
  end
end

coro_debugger = coroutine.create(debugger_loop)

function start()
  debug.sethook(line_hook, "l")
  return coroutine.resume(coro_debugger)
end

