local M = {}

function M.check()
  vim.health.start("lazydocker.nvim")
  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim >= 0.11")
  else
    vim.health.error("Neovim >= 0.11 is required")
  end

  local command = require("lazydocker.config").options.command
  if vim.fn.executable(command) == 1 then
    vim.health.ok("Executable found: " .. command)
  else
    vim.health.error("Executable not found: " .. command, {
      "Install https://github.com/jesseduffield/lazydocker",
      "Or set require('lazydocker').setup({ command = '/path/to/lazydocker' })",
    })
  end

  if vim.fn.executable("docker") == 1 then
    vim.health.ok("Docker CLI found")
  else
    vim.health.warn("Docker CLI not found on PATH", "Install Docker and make it available to LazyDocker")
  end
  vim.health.info(
    "LazyDocker uses the inherited Docker environment/context. Check daemon connectivity with docker info."
  )
end

return M
