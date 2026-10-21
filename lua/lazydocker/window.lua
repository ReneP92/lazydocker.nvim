local M = {}

function M.highlights()
  vim.api.nvim_set_hl(0, "LazyDockerFloat", { link = "NormalFloat", default = true })
  vim.api.nvim_set_hl(0, "LazyDockerBorder", { link = "FloatBorder", default = true })
end

---@param config lazydocker.WindowConfig
---@return vim.api.keyset.win_config
function M.layout(config)
  local columns = vim.o.columns
  local lines = math.max(1, vim.o.lines - vim.o.cmdheight)
  local border = config.border
  -- A border cannot fit on extremely small grids.
  if columns < 3 or lines < 3 then
    border = "none"
  end
  local padding = border == "none" and 0 or 2
  local width = math.max(1, math.floor((columns - padding) * config.width))
  local height = math.max(1, math.floor((lines - padding) * config.height))
  local opts = {
    relative = "editor",
    style = "minimal",
    width = width,
    height = height,
    row = math.max(0, math.floor((lines - height - padding) / 2)),
    col = math.max(0, math.floor((columns - width - padding) / 2)),
    border = border,
    title = "",
  }
  if border ~= "none" and width >= 12 then
    opts.title = " LazyDocker "
    opts.title_pos = "center"
  end
  return opts
end

---@param buf integer
---@param config lazydocker.WindowConfig
---@return integer
function M.open(buf, config)
  M.highlights()
  local win = vim.api.nvim_open_win(buf, true, M.layout(config))
  local options = {
    winblend = config.winblend,
    winhighlight = "Normal:LazyDockerFloat,NormalFloat:LazyDockerFloat,FloatBorder:LazyDockerBorder",
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    statuscolumn = "",
    cursorline = false,
    cursorcolumn = false,
    spell = false,
    list = false,
    wrap = false,
    scrolloff = 0,
    sidescrolloff = 0,
  }
  for name, value in pairs(options) do
    vim.wo[win][name] = value
  end
  return win
end

return M
