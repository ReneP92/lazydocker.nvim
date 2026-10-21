local config = require("lazydocker.config")
local window = require("lazydocker.window")
local api = vim.api
local M = {}

---@class lazydocker.Session
---@field buf integer
---@field win? integer
---@field job? integer
---@field previous_win integer
---@field window lazydocker.WindowConfig
---@field exited? integer

---@type lazydocker.Session?
local session

local function notify(message)
  vim.notify("lazydocker.nvim: " .. message, vim.log.levels.ERROR)
end

local function visible(current)
  return current and current.win and api.nvim_win_is_valid(current.win)
end

local function resize_job(current)
  if current.job and current.exited == nil then
    vim.fn.jobresize(current.job, api.nvim_win_get_width(current.win), api.nvim_win_get_height(current.win))
  end
end

local function hide(current)
  if not visible(current) then
    return false
  end
  local win = current.win
  local restore_focus = api.nvim_get_current_win() == win
  current.win = nil
  if restore_focus then
    vim.cmd.stopinsert()
  end
  api.nvim_win_close(win, true)
  if restore_focus and api.nvim_win_is_valid(current.previous_win) then
    api.nvim_set_current_win(current.previous_win)
  end
  return true
end

local function dispose(current)
  -- Detach first: deleting the buffer and stopping the job also fire callbacks.
  if session == current then
    session = nil
  end
  hide(current)
  if current.job and current.exited == nil then
    pcall(vim.fn.jobstop, current.job)
  end
  if api.nvim_buf_is_valid(current.buf) then
    api.nvim_buf_delete(current.buf, { force = true })
  end
end

local function on_exit(current, code)
  -- A stopped process may report its exit after a replacement has started.
  if session ~= current then
    return
  end
  current.exited = code
  if code == 0 then
    dispose(current)
    return
  end

  -- Keep the terminal's diagnostic output available instead of hiding failures.
  if visible(current) and api.nvim_get_current_win() == current.win then
    vim.cmd.stopinsert()
  end
  vim.keymap.set("n", "q", function()
    if session == current then
      M.close()
    end
  end, { buffer = current.buf, silent = true, desc = "Close failed LazyDocker session" })
  notify("process exited with code " .. code .. ". See the terminal output; :LazyDocker retries, q closes.")
end

---@param opts? table See :help lazydocker-setup.
function M.setup(opts)
  config.setup(opts)
end

---@class lazydocker.OpenOptions
---@field cwd? string Working directory for a new session.

---Open or focus LazyDocker. Options apply only when starting a new session.
---@param opts? lazydocker.OpenOptions
---@return boolean success
function M.open(opts)
  if vim.fn.has("nvim-0.11") == 0 then
    notify("Neovim 0.11 or newer is required.")
    return false
  end

  if session and session.exited ~= nil then
    dispose(session)
  end
  if session then
    if not visible(session) then
      session.previous_win = api.nvim_get_current_win()
      session.win = window.open(session.buf, session.window)
      resize_job(session)
    elseif api.nvim_get_current_win() ~= session.win then
      session.previous_win = api.nvim_get_current_win()
      api.nvim_set_current_win(session.win)
    end
    vim.cmd.startinsert()
    return true
  end

  opts = opts or {}
  if type(opts) ~= "table" or (opts.cwd ~= nil and (type(opts.cwd) ~= "string" or opts.cwd == "")) then
    notify("open() expects a table with an optional non-empty cwd string.")
    return false
  end
  local cwd = vim.fn.fnamemodify(opts.cwd or vim.fn.getcwd(), ":p")
  if vim.fn.isdirectory(cwd) == 0 then
    notify("working directory does not exist: " .. cwd)
    return false
  end

  local options = config.options
  if vim.fn.executable(options.command) == 0 then
    notify(
      "executable not found: " .. options.command .. ". Install LazyDocker or configure command with its full path."
    )
    return false
  end

  local current = {
    buf = api.nvim_create_buf(false, true),
    previous_win = api.nvim_get_current_win(),
    window = vim.deepcopy(options.window),
  }
  session = current
  vim.bo[current.buf].bufhidden = "hide"
  vim.bo[current.buf].swapfile = false

  local ok, result = pcall(function()
    current.win = window.open(current.buf, current.window)
    vim.bo[current.buf].filetype = "lazydocker"
    local argv = { options.command }
    vim.list_extend(argv, options.args)
    return vim.fn.jobstart(argv, {
      term = true,
      cwd = cwd,
      on_exit = function(_, code)
        vim.schedule(function()
          on_exit(current, code)
        end)
      end,
    })
  end)

  if not ok or result <= 0 then
    dispose(current)
    notify("could not start LazyDocker: " .. tostring(result))
    return false
  end
  current.job = result
  vim.cmd.startinsert()
  return true
end

---Hide the floating window, keeping its process alive.
---@return boolean hidden
function M.hide()
  return hide(session)
end

---Hide a visible session or open it. Options apply only to a new session.
---@param opts? lazydocker.OpenOptions
---@return boolean success
function M.toggle(opts)
  if visible(session) then
    return M.hide()
  end
  return M.open(opts)
end

---Stop the process and delete its window and buffer.
---@return boolean closed
function M.close()
  if not session then
    return false
  end
  dispose(session)
  return true
end

local group = api.nvim_create_augroup("LazyDocker", { clear = true })

api.nvim_create_autocmd("VimResized", {
  group = group,
  desc = "Keep the LazyDocker terminal centered",
  callback = function()
    if visible(session) then
      api.nvim_win_set_config(session.win, window.layout(session.window))
      resize_job(session)
    end
  end,
})

api.nvim_create_autocmd("WinClosed", {
  group = group,
  callback = function(event)
    if session and session.win == tonumber(event.match) then
      session.win = nil
    end
  end,
})

api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(event)
    if session and session.buf == event.buf then
      local current = session
      session = nil
      -- Buffer deletion is still in progress; defer window/buffer cleanup.
      vim.schedule(function()
        dispose(current)
      end)
    end
  end,
})

api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = window.highlights,
})

api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    local current = session
    session = nil
    if current and current.job and current.exited == nil then
      pcall(vim.fn.jobstop, current.job)
      -- Allow jobstop's SIGHUP/TERM/KILL escalation before Neovim releases PTYs.
      pcall(vim.fn.jobwait, { current.job }, 5000)
    end
  end,
})

return M
