if vim.g.loaded_lazydocker then
  return
end
vim.g.loaded_lazydocker = true

vim.api.nvim_create_user_command("LazyDocker", function()
  require("lazydocker").open()
end, { desc = "Open LazyDocker" })

vim.api.nvim_create_user_command("LazyDockerToggle", function()
  require("lazydocker").toggle()
end, { desc = "Toggle the LazyDocker terminal" })
