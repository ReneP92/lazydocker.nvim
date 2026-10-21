vim.opt.runtimepath:prepend(assert(vim.env.LAZYDOCKER_TEST_ROOT))
vim.o.swapfile = false
vim.o.shortmess = "I"

local args = {
  "--headless",
  "-u",
  "NONE",
  "-i",
  "NONE",
  "-n",
  "-l",
  vim.env.LAZYDOCKER_TEST_ROOT .. "/tests/fixtures/terminal.lua",
}
if vim.env.LAZYDOCKER_TEST_FAIL == "1" then
  args[#args + 1] = "--exit=9"
end
require("lazydocker").setup({ command = vim.v.progpath, args = args })

vim.keymap.set({ "n", "t" }, "<C-g>", function()
  require("lazydocker").toggle()
end)
