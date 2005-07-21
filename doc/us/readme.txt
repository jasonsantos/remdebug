Remdebug 0.1 Alpha
------------------

Installation
------------

Create a remdebug folder in your package.path and copy engine.lua to
this folder.

Running
-------

You should run the controller first. Just do

  lua controller.lua

And you will be presented with a prompt. Type help to see available
commands. Set at least one breakpoint, then type wait. The controller
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

Sample Script
-------------

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

