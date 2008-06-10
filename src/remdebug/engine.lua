--
-- RemDebug 1.0 Beta
-- Copyright Kepler Project 2005 (http://www.keplerproject.org/remdebug)
--
pcall(require, "luarocks.require")

local socket = require"socket"
local lfs = require"lfs"
local debug = require"debug"

module("remdebug.engine", package.seeall)

_COPYRIGHT = "2006 - Kepler Project"
_DESCRIPTION = "Remote Debugger for the Lua programming language"
_VERSION = "1.0"

local coro_debugger
local events = { BREAK = 1, WATCH = 2 }
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

local function restore_vars(vars)
  if type(vars) ~= 'table' then return end
  local func = debug.getinfo(3, "f").func
  local i = 1
  local written_vars = {}
  while true do
    local name = debug.getlocal(3, i)
    if not name then break end
    debug.setlocal(3, i, vars[name])
    written_vars[name] = true
    i = i + 1
  end
  i = 1
  while true do
    local name = debug.getupvalue(func, i)
    if not name then break end
    if not written_vars[name] then
      debug.setupvalue(func, i, vars[name])
      written_vars[name] = true
    end
    i = i + 1
  end
end

local function capture_vars()
  local vars = {}
  local func = debug.getinfo(3, "f").func
  local i = 1
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
  setmetatable(vars, { __index = getfenv(func), __newindex = getfenv(func) })
  return vars
end

local function break_dir(path) 
  local paths = {}
  path = string.gsub(path, "\\", "/")
  for w in string.gfind(path, "[^\/]+") do
    table.insert(paths, w)
  end
  return paths
end

local function merge_paths(path1, path2)
  local paths1 = break_dir(path1)
  local paths2 = break_dir(path2)
  for i, path in ipairs(paths2) do
    if path == ".." then
      table.remove(paths1, table.getn(paths1))
    elseif path ~= "." then
      table.insert(paths1, path)
    end
  end
  return table.concat(paths1, "/")
end

local function debug_hook(event, line)
  if event == "call" then
    stack_level = stack_level + 1
  elseif event == "return" then
    stack_level = stack_level - 1
  else
    local file = debug.getinfo(2, "S").source
    if string.find(file, "@") == 1 then
      file = string.sub(file, 2)
    end
    file = merge_paths(lfs.currentdir(), file)
    local vars = capture_vars()
    table.foreach(watches, function (index, value)
      setfenv(value, vars)
      local status, res = pcall(value)
      if status and res then
      print'debugging..'
      print(status, res)
        coroutine.resume(coro_debugger, events.WATCH, vars, file, line, index)
	restore_vars(vars)
      end
    end)
    if step_into or (step_over and stack_level <= step_level) or has_breakpoint(file, line) then
      step_into = false
      step_over = false
      coroutine.resume(coro_debugger, events.BREAK, vars, file, line)
      restore_vars(vars)
    end
  end
end

local operation = {}

local SUCCESS = "200 OK\n"
local BAD_REQUEST = "400 Bad Request\n"
local EXPRESSION_ERROR_ = "401 Error in Expression "
local BREAK_PAUSE_ = "202 Paused "
local WATCH_PAUSE_ = "203 Paused "
local EXECUTION_ERROR_ = "401 Error in Execution "


--- implements SETB command
function operation.setBreakpoint(status, filename, lineNumber )
	if filename and lineNumber then
		filename = string.gsub(filename, "%%20", " ")
	    set_breakpoint(filename, tonumber(lineNumber))
	    
	    return SUCCESS 
	else
	    return BAD_REQUEST
	end
end

--- implements DELB command
function operation.removeBreakpoint(status, filename, lineNumber )
	if filename and lineNumber then
		filename = string.gsub(filename, "%%20", " ")
	    remove_breakpoint(filename, tonumber(lineNumber))
	    
	    return SUCCESS 
	else
	    return BAD_REQUEST
	end
end

function operation.execute(status, chunk)
	if chunk then 
        local func = loadstring(chunk)
        local status, res
        if func then
        	setfenv(func, eval_env)
        	status, res = xpcall(func, debug.traceback)
        end
        res = tostring(res)
        if status then
        	local s = SUCCESS .. " " .. string.len(res) .. "\n" 
        	return s .. res
        else
        	local s = EXPRESSION_ERROR_ .. string.len(res) .. "\n"
        	return s .. res
        end
	else
    	return BAD_REQUEST
	end
end

function operation.setWatch(status, exp)
	if exp then 
		local func = loadstring("return(" .. exp .. ")")
		local newidx = table.getn(watches) + 1
		watches[newidx] = func
		table.setn(watches, newidx)
		return SUCCESS .. " " .. newidx .. "\n" 
	else
		return BAD_REQUEST
	end  
end

function operation.deleteWatch(status, index)
	index = tonumber(index)
	if index then
		watches[index] = nil
		return SUCCESS 
	else
		return BAD_REQUEST
	end
end

function operation.run()
print'run success'
	server:send(SUCCESS)
    local ev, vars, file, line, idx_watch = coroutine.yield()
    eval_env = vars
    if ev == events.BREAK then
    	return BREAK_PAUSE_ .. file .. " " .. line .. "\n"
	elseif ev == events.WATCH then
    	return WATCH_PAUSE_ .. file .. " " .. line .. " " .. idx_watch .. "\n"
	else
    	return EXECUTION_ERROR_ .. string.len(file) .. "\n" .. file
	end
end

function operation.step()
print'step success' print(SUCCESS)
	server:send(SUCCESS)
print'step success sent'
	step_into = true
	
	local ev, vars, file, line, idx_watch = coroutine.yield()
	
	eval_env = vars
	
	if ev == events.BREAK then
        return BREAK_PAUSE_ .. file .. " " .. line .. "\n"
	elseif ev == events.WATCH then
        return WATCH_PAUSE_ .. file .. " " .. line .. " " .. idx_watch .. "\n"
	else
        return EXECUTION_ERROR_ .. string.len(file) .. "\n" .. file
	end
end

function operation.stepOver()
print'stepover success'
	server:send(SUCCESS)
	
	step_over = true
	step_level = stack_level
	local ev, vars, file, line, idx_watch = coroutine.yield()
	
	eval_env = vars
	
	if ev == events.BREAK then
        return BREAK_PAUSE_ .. file .. " " .. line .. "\n"
	elseif ev == events.WATCH then
        return WATCH_PAUSE_ .. file .. " " .. line .. " " .. idx_watch .. "\n"
	else
        return EXECUTION_ERROR_ .. string.len(file) .. "\n"  .. file
	end
end

local function debugger_loop(server)
	local command
	local eval_env = {}
  
	-- command x operations table.. allows alternate syntaxes to commands
	local operations = {
	  	SETB={
	  		operation = operation['setBreakpoint'],
	  		paramsMask = '([%w%p]+)%s+(%d+)$'
	  	},
	  	DELB={
	  		operation = operation['removeBreakpoint'], 
	  		paramsMask = '([%w%p]+)%s+(%d+)$'
	  	},
	  	EXEC={
	  		operation = operation['execute'], 
	  		paramsMask = '.*'
	  	},
	  	SETW={
	  		operation = operation['setWatch'], 
	  		paramsMask = '.*'
	  	},
	  	DELW={
	  		operation = operation['deleteWatch'], 
	  		paramsMask = '(%d+)'
	  	},
	  	RUN ={
	  		operation = operation['run'], 
	  		paramsMask = '.*'
	  	},
	  	STEP={
	  		operation = operation['step'], 
	  		paramsMask = '.*'
	  	},
	  	OVER={
	  		operation = operation['stepOver'], 
	  		paramsMask = '.*'
	  	},
	}
  
	while true do
		print"I'm about to receive from server"
	    local line, status = server:receive()
	print(line)
	    local result  = BAD_REQUEST
	    string.gsub(line, "^([A-Z]+)(.*)", function(command, params)
	    	print('c',command, params)
		    local operation = operations[command] and operations[command].operation
		    print(command, operation)
		    if operation then
		    	print('about to run', params,  operations[command].paramsMask)
		    	result = string.gsub(params, operations[command].paramsMask, operation)
		    	print('r',result)
		    end    	
	    end)
	    print('R',result)
    	server:send(result)
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
  
 print(controller_host, controller_port)
  local server = socket.connect(controller_host, controller_port)
  if server then
    _TRACEBACK = function (message) 
      local err = debug.traceback(message)
      server:send(EXECUTION_ERROR_ .. string.len(err) .. "\n")
      server:send(err)
      server:close()
      return err
    end
    debug.sethook(debug_hook, "lcr")
    print'waiting..'
    return coroutine.resume(coro_debugger, server)
  end
end

