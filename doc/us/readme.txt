Remdebug 0.1 Alpha
------------------

Installation
------------

Create a remdebug folder in your package.path and copy engine.lua to
this folder. 

Remdebug uses the new package proposal, so if you are using Lua 5.0
you should load compat-5.1.lua through your LUA_INIT environment variable.

Running
-------

You should run the controller first. Just do

  lua controller.lua

And you will be presented with a prompt. Type 'help' to see available
commands. Set at least one breakpoint, then type 'wait'. The controller
will block.

The application you want to debug should have the following lines added:

  require"remdebug.engine"
  remdebug.engine.start()

With the controller blocked, run the application. A sample one, test.lua, is
provided. Just do

  lua test.lua

The application should block on the first breakpoint you set, and the
controller will wait for further commands. Type help again to see
the commands available at this point.

Controller Commands
-------------------

If the debug session has not started (you did not call 'wait'):

- setb <file> <line>

  Sets a breakpoint for the Lua script <file> at line <line>. <file>
  should be the name of the script as the LUa debug library sees it,
  so it may include a path such as ./foo.lua.'

- delb <file> <line>
  
  Removes a previously set breakpoint.

- listb

  Lists current breakpoints

- wait

  Starts debug session by blocking until the program to be debugged runs

- help

  Lists the commands

The list of commands change after you start the debug session. There is
no 'wait' command anymore, and the following commands are added:

- eval <exp>

  Evaluates <exp>, which should be a Lua expression, in the context where
  where the program stopped (including any local variables and upvalues).
  
- run

  Run the program, blocking the controller again, until the next breakpoint.

Example of Execution
--------------------

% lua controller.lua
Lua Remote Debugger
Type 'help' for commands
> setb test.lua 10
> wait                        
Now run the program you wish to debug
Breakpoint reached at file test.lua line 10
> eval tab
table: 0x807e418
> eval tab.foo
1
> eval tab.bar
2
> setb test.lua 14
> run
Breakpoint reached at file test.lua line 14
> eval tab.foo
1
> run
Breakpoint reached at file test.lua line 14
> eval tab.foo
2
> run
Breakpoint reached at file test.lua line 14
> eval tab.foo
4
> delb test.lua 14
> run
Program finished

