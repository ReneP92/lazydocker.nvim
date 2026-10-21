vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/?.lua;" .. package.path
vim.o.swapfile = false
vim.o.columns = 120
vim.o.lines = 40

local H = require("tests.helpers")
vim.notify = function(message, level)
  H.notifications[#H.notifications + 1] = { message = message, level = level }
end
dofile("tests/plugin_spec.lua")
dofile("tests/ui_spec.lua")

local failed = 0
for _, case in ipairs(H.cases) do
  H.notifications = {}
  local ok, err = xpcall(function()
    if package.loaded.lazydocker then
      require("lazydocker").setup(H.fixture())
    end
    case.run()
  end, debug.traceback)
  local cleaned, cleanup_error = xpcall(H.cleanup, debug.traceback)
  if ok and cleaned then
    io.stdout:write("PASS " .. case.name .. "\n")
  else
    failed = failed + 1
    io.stdout:write("FAIL " .. case.name .. "\n" .. tostring(ok and cleanup_error or err) .. "\n")
  end
end
io.stdout:write(string.format("\n%d tests, %d failures\n", #H.cases, failed))
vim.cmd(failed == 0 and "qa!" or "cquit 1")
