--
-- RemDebug 1.0 Alpha
-- Copyright Kepler Project 2005 (http://www.keplerproject.org/remdebug)
--

module("remdebug.engine")

_COPYRIGHT = "2005 - Kepler Project"
_DESCRIPTION = "Remote Debugger for the Lua programming language"
_VERSION = "1.0 Alpha"

local socket = require"socket"
local debug = debug

local coro_debugger
local events = { BREAK = 1 }
local breakpoints = {}
local watches = {}
local step_into = false
local step_over = false
local step_level = 0
local stack_level = 0

local controller_host = "localhost"
local controller_port = 8171

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

local function capture_vars()
  local vars = {}
  local func = debug.getinfo(3, "f").func
  local i = 1
  i = 1
  while true do
    local name, value = debug.getupvalue(func, i)
    if not name then break end
    vars[name] = value
    i = i + 1
  end
  i = 1
  while true do
    local name, value = debug.getlocal(3, i)
    if not name then break end
    vars[name] = value
    i = i + 1
  end
  setmetatable(vars, { __index = getfenv(func) })
  return vars
end

local function debug_hook(event, line)
  if event == "call" then
    stack_level = stack_level + 1
  elseif event == "return" then
    stack_level = stack_level - 1
  else
    local file = debug.getinfo(2, "S").source
    local vars = capture_vars()
    if string.find(file, "@") == 1 then
      file = string.sub(file, 2)
    end
    table.foreachi(watches, function (index, value)
      setfenv(value, vars)
      if value() then
        coroutine.resume(coro_debugger, events.BREAK, file, line, vars)
      end
    end)
    if step_into or (step_over and stack_level <= step_level) or has_breakpoint(file, line) then
      step_into = false
      step_over = false
      coroutine.resume(coro_debugger, events.BREAK, file, line, vars)
    end
  end
end

local function debugger_loop(server)
  local command
  local eval_env = {}
  while true do
    local line, status = server:receive()
    command = string.sub(line, string.find(line, "^[A-Z]+"))
    if command == "SETB" then
      local _, _, _, filename, line = string.find(line, "^([A-Z]+)%s+([%w%p]+)%s+(%d+)$")
      if filename and line then
        set_breakpoint(filename, tonumber(line))
        server:send("200 OK\n")
      else
        server:send("400 Bad Request\n")
      end
    elseif command == "DELB" then
      local _, _, _, filename, line = string.find(line, "^([A-Z]+)%s+([%w%p]+)%s+(%d+)$")
      if filename and line then
        remove_breakpoint(filename, tonumber(line))
        server:send("200 OK\n")
      else
        server:send("400 Bad Request\n")
      end
    elseif command == "EVAL" then
      local _, _, exp = string.find(line, "^[A-Z]+%s+(.+)$")
      if exp then 
        local func = loadstring("return(" .. exp .. ")")
        setfenv(func, eval_env)
        local status, res = pcall(func)
        if status then
          res = tostring(res)
          server:send("200 OK " .. string.len(res) .. "\n") 
          server:send(res)
        else
          server:send("400 Bad Request\n")
        end
      else
        server:send("400 Bad Request\n")
      end
    elseif command == "SETW" then
      local _, _, exp = string.find(line, "^[A-Z]+%s+(.+)$")
      if exp then 
        local func = loadstring("return(" .. exp .. ")")
        local newidx = table.getn(watches) + 1
        watches[newidx] = func
        table.setn(watches, newidx)
        server:send("200 OK" .. newidx .. "\n") 
      else
        server:send("400 Bad Request\n")
      end
    elseif command == "DELW" then
      local _, _, index = string.find(line, "^[A-Z]+%s+(%d+)$")
      if index then
        watches[index] = nil
        server:send("200 OK") 
      else
        server:send("400 Bad Request\n")
      end
    elseif command == "RUN" then
      server:send("200 OK\n")
      local ev, file, line, vars = coroutine.yield()
      eval_env = vars
      if ev == events.BREAK then
        server:send("202 Paused " .. file .. " " .. line .. "\n")
      end
    elseif command == "STEP" then
      server:send("200 OK\n")
      step_into = true
      local ev, file, line, vars = coroutine.yield()
      eval_env = vars
      if ev == events.BREAK then
        server:send("202 Paused " .. file .. " " .. line .. "\n")
      end
    elseif command == "OVER" then
      server:send("200 OK\n")
      step_over = true
      step_level = stack_level
      local ev, file, line, vars = coroutine.yield()
      eval_env = vars
      if ev == events.BREAK then
        server:send("202 Paused " .. file .. " " .. line .. "\n")
      end
    else
      server:send("400 Bad Request\n")
    end
  end
end

coro_debugger = coroutine.create(debugger_loop)

--
-- remdebug.engine.config(tab)
-- Configures the engine
--
function config(tab)
  if tab.host then
    controller_host = tab.host
  end
  if tab.port then
    controller_port = tab.port
  end
end

--
-- remdebug.engine.start()
-- Tries to start the debug session by connecting with a controller
--
function start()
  pcall(require, "remdebug.config")
  local server = socket.connect(controller_host, controller_port)
  if server then
    debug.sethook(debug_hook, "lcr")
    return coroutine.resume(coro_debugger, server)
  end
end

