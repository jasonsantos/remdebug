require"remdebug.engine"

remdebug.engine.start()

local tab = {
  foo = 1,
  bar = 2
}

print("Start")

for i = 1, 10 do
  print("Loop")
  tab.foo = tab.foo * 2
end

print("End")

