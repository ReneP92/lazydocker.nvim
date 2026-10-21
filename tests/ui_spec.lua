local H = require("tests.helpers")

H.test("interactive Neovim forwards keys, toggles in terminal mode, resizes, and restores focus", function()
  local child = H.child()
  local original = child.lua("return vim.api.nvim_get_current_win()")
  child.keys(":LazyDocker\r")
  child.wait("return vim.bo.filetype == 'lazydocker' and vim.fn.mode() == 't'", "did not enter terminal mode")
  local buf = child.lua("return vim.api.nvim_get_current_buf()")
  child.wait([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('READY', 1, true) ~= nil]])
  child.keys("keyboard-input\r")
  child.wait(
    [[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('ECHO:keyboard-input', 1, true) ~= nil]]
  )

  child.keys(string.char(7)) -- Ctrl-g, the documented normal/terminal toggle pattern.
  child.wait("return vim.bo.filetype ~= 'lazydocker' and vim.fn.mode() == 'n'", "toggle did not restore normal mode")
  H.eq(original, child.lua("return vim.api.nvim_get_current_win()"))
  child.keys(string.char(7))
  child.wait("return vim.bo.filetype == 'lazydocker' and vim.fn.mode() == 't'")
  H.eq(buf, child.lua("return vim.api.nvim_get_current_buf()"))

  vim.fn.jobresize(child.job, 80, 24)
  child.wait("return vim.o.columns == 80 and vim.api.nvim_win_get_width(0) == 70", "UI resize did not reach the float")
  child.keys("size\r")
  child.wait(
    [[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('SIZE:70:18', 1, true) ~= nil]]
  )
  local screen = child.lua([[
    local rows = {}
    for row = 1, vim.o.lines do
      local cells = {}
      for col = 1, vim.o.columns do
        cells[#cells + 1] = vim.fn.screenstring(row, col)
      end
      rows[#rows + 1] = table.concat(cells)
    end
    return table.concat(rows, '\n')
  ]])
  H.contains(screen, "LazyDocker")
  H.contains(screen, "╭")
  H.contains(screen, "╯")

  child.keys("exit 0\r")
  child.wait("return vim.bo.filetype ~= 'lazydocker' and vim.fn.mode() == 'n'", "exit did not return to the editor")
  H.eq(original, child.lua("return vim.api.nvim_get_current_win()"))
  H.eq(false, child.lua("return vim.api.nvim_buf_is_valid(...)", buf))
end)

H.test("exiting Neovim stops a hidden terminal process", function()
  local child = H.child()
  child.keys(":LazyDocker\r")
  child.wait("return vim.bo.filetype == 'lazydocker' and vim.fn.mode() == 't'")
  child.wait([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('READY', 1, true) ~= nil]])
  local pid = child.lua("return vim.fn.jobpid(vim.b.terminal_job_id)")
  child.keys(string.char(7))
  child.wait("return vim.bo.filetype ~= 'lazydocker' and vim.fn.mode() == 'n'")
  child.keys(":qa!\r")
  H.wait(function()
    return vim.uv.kill(pid, 0) == nil
  end, "hidden terminal process survived Neovim shutdown", 10000)
end)

H.test("interactive startup failure shows diagnostics and q closes the failed terminal", function()
  local child = H.child(true)
  child.keys(":LazyDocker\r")
  child.wait(
    "return vim.bo.filetype == 'lazydocker' and #vim.api.nvim_buf_get_keymap(0, 'n') > 0 and vim.fn.mode() == 'n'"
  )
  H.eq("n", child.lua("return vim.fn.mode()"))
  H.contains(child.lua("return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\\n')"), "STARTUP FAILURE")
  child.keys("q")
  child.wait("return vim.bo.filetype ~= 'lazydocker'", "q did not close the failed terminal")
end)
