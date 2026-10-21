local M = {}

---@class lazydocker.WindowConfig
---@field width number Fraction of the available editor width, between 0 and 1.
---@field height number Fraction of the available editor height, between 0 and 1.
---@field border string Native Neovim border style.
---@field winblend integer Window transparency, between 0 and 100.

---@class lazydocker.Config
---@field command string Executable name or path, without arguments.
---@field args string[] Arguments passed directly to the executable.
---@field window lazydocker.WindowConfig

---@type lazydocker.Config
local defaults = {
  command = "lazydocker",
  args = {},
  window = {
    width = 0.9,
    height = 0.9,
    border = "rounded",
    winblend = 0,
  },
}

local borders = { "none", "single", "double", "rounded", "solid", "shadow" }

local function check(condition, message)
  if not condition then
    error("lazydocker.nvim: " .. message, 3)
  end
end

local function known_keys(value, allowed, prefix)
  check(type(value) == "table", prefix .. " must be a table")
  for key in pairs(value) do
    check(allowed[key] ~= nil, "unknown option: " .. prefix .. "." .. tostring(key))
  end
end

---@param opts? table
function M.setup(opts)
  if opts == nil then
    opts = {}
  end
  known_keys(opts, defaults, "setup")
  if opts.window ~= nil then
    known_keys(opts.window, defaults.window, "window")
  end

  local config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  check(type(config.command) == "string" and config.command ~= "", "command must be a non-empty string")
  check(type(config.args) == "table" and vim.islist(config.args), "args must be a list of strings")
  for _, arg in ipairs(config.args) do
    check(type(arg) == "string", "args must be a list of strings")
  end

  for _, key in ipairs({ "width", "height" }) do
    local value = config.window[key]
    check(type(value) == "number" and value > 0 and value <= 1, "window." .. key .. " must be in (0, 1]")
  end
  check(
    vim.tbl_contains(borders, config.window.border),
    "window.border must be one of: " .. table.concat(borders, ", ")
  )
  local blend = config.window.winblend
  check(
    type(blend) == "number" and blend >= 0 and blend <= 100 and blend % 1 == 0,
    "window.winblend must be an integer between 0 and 100"
  )

  -- Keep caller-owned tables and defaults independent of future changes.
  M.options = vim.deepcopy(config)
end

M.options = vim.deepcopy(defaults)

return M
