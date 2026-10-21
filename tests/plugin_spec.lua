local H = require("tests.helpers")
local api = vim.api

H.test("commands are lazy and can be sourced twice", function()
  H.eq(nil, package.loaded.lazydocker)
  vim.cmd.runtime("plugin/lazydocker.lua")
  vim.cmd.runtime("plugin/lazydocker.lua")
  H.eq(2, vim.fn.exists(":LazyDocker"))
  H.eq(2, vim.fn.exists(":LazyDockerToggle"))
  H.eq(nil, package.loaded.lazydocker)
  require("lazydocker").setup(H.fixture())
end)

H.test("setup merges defaults and isolates caller-owned tables", function()
  local plugin = require("lazydocker")
  local opts = { args = { "-f", "compose.dev.yml" }, window = { width = 0.7 } }
  plugin.setup(opts)
  opts.args[1] = "changed"
  opts.window.width = 0.1
  local config = require("lazydocker.config").options
  H.eq("lazydocker", config.command)
  H.eq({ "-f", "compose.dev.yml" }, config.args)
  H.eq({ width = 0.7, height = 0.9, border = "rounded", winblend = 0 }, config.window)
  plugin.setup()
  H.eq({}, require("lazydocker.config").options.args)
  H.eq(0.9, require("lazydocker.config").options.window.width)
end)

H.test("invalid configuration is rejected without replacing valid options", function()
  local config = require("lazydocker.config")
  local previous = vim.deepcopy(config.options)
  local invalid = {
    false,
    "invalid",
    { command = "" },
    { command = {} },
    { args = "-f compose.yml" },
    { args = { 1 } },
    { args = { name = "value" } },
    { window = false },
    { window = { width = 0 } },
    { window = { height = 1.1 } },
    { window = { width = 0 / 0 } },
    { window = { border = "invalid" } },
    { window = { winblend = 101 } },
    { window = { winblend = 0.5 } },
    { window = { typo = true } },
    { typo = true },
  }
  for _, opts in ipairs(invalid) do
    local ok, err = pcall(require("lazydocker").setup, opts)
    H.eq(false, ok)
    H.contains(err, "lazydocker.nvim:")
    H.eq(previous, config.options)
  end
end)

H.test("command starts a real terminal in a centered minimal float", function()
  local previous = api.nvim_get_current_win()
  vim.cmd.LazyDocker()
  local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
  H.output(buf, "READY")
  local layout = api.nvim_win_get_config(win)
  H.eq("terminal", vim.bo[buf].buftype)
  H.eq("lazydocker", vim.bo[buf].filetype)
  H.eq(false, vim.bo[buf].buflisted)
  H.eq("editor", layout.relative)
  H.eq(106, layout.width)
  H.eq(33, layout.height)
  H.eq(6, layout.col)
  H.eq(2, layout.row)
  H.eq(false, vim.wo[win].number)
  H.eq("no", vim.wo[win].signcolumn)
  H.eq("", vim.wo[win].statuscolumn)
  H.eq(0, #api.nvim_buf_get_keymap(buf, "t"))
  require("lazydocker").hide()
  H.eq(previous, api.nvim_get_current_win())
end)

H.test("toggle preserves the buffer, process, and terminal output", function()
  local buf, win, job = H.start()
  vim.cmd.LazyDockerToggle()
  H.eq(false, api.nvim_win_is_valid(win))
  H.eq(-1, vim.fn.jobwait({ job }, 0)[1])
  vim.fn.chansend(job, "hidden-input\n")
  H.output(buf, "ECHO:hidden-input")
  vim.cmd.LazyDockerToggle()
  H.eq(buf, api.nvim_get_current_buf())
  H.eq(job, vim.b[buf].terminal_job_id)
  H.contains(H.text(buf), "ECHO:hidden-input")
end)

H.test("repeated open focuses one session and restores the invoking window", function()
  vim.cmd.vsplit()
  local invoking = api.nvim_get_current_win()
  local buf, win = H.start()
  require("lazydocker").open()
  H.eq(win, api.nvim_get_current_win())
  api.nvim_set_current_win(invoking)
  require("lazydocker").open()
  H.eq(buf, api.nvim_get_current_buf())
  H.eq(win, api.nvim_get_current_win())
  require("lazydocker").hide()
  H.eq(invoking, api.nvim_get_current_win())
end)

H.test("cwd and arguments with spaces and shell metacharacters stay literal", function()
  local cwd = H.tempdir()
  local args = { "-f", "compose file.yml", "literal;echo NOT_A_SHELL", "$(echo literal)", "" }
  require("lazydocker").setup(H.fixture(args))
  local before = vim.fn.getcwd()
  local buf = H.start({ cwd = cwd })
  H.output(buf, "CWD:" .. vim.uv.fs_realpath(cwd))
  for _, value in ipairs(args) do
    H.output(buf, "ARG:" .. value)
  end
  H.eq(before, vim.fn.getcwd())
end)

H.test("new sessions respect window-local cwd and inherit the environment", function()
  local cwd = H.tempdir()
  local old_env = vim.env.LAZYDOCKER_TEST_ENV
  H.resources[#H.resources + 1] = function()
    vim.env.LAZYDOCKER_TEST_ENV = old_env
  end
  vim.env.LAZYDOCKER_TEST_ENV = "inherited-value"
  vim.cmd.lcd(vim.fn.fnameescape(cwd))
  local buf = H.start()
  H.output(buf, "CWD:" .. vim.uv.fs_realpath(cwd))
  H.output(buf, "ENV:inherited-value")
end)

H.test("an existing session keeps its original working directory", function()
  local cwd = H.tempdir()
  local buf, _, job = H.start()
  require("lazydocker").hide()
  require("lazydocker").open({ cwd = cwd })
  H.eq(job, vim.b[buf].terminal_job_id)
  H.output(buf, "CWD:" .. H.root)
end)

H.test("successful exit deletes the float and buffer and restores focus", function()
  local previous = api.nvim_get_current_win()
  local buf, win, job = H.start()
  vim.fn.chansend(job, "exit 0\n")
  H.wait(function()
    return not api.nvim_buf_is_valid(buf)
  end)
  H.eq(false, api.nvim_win_is_valid(win))
  H.eq(previous, api.nvim_get_current_win())
  H.eq(false, require("lazydocker").close())
end)

H.test("closing stops a hidden process and stale callbacks cannot close its replacement", function()
  local old_buf, _, old_job = H.start()
  require("lazydocker").hide()
  require("lazydocker").close()
  local new_buf, new_win, new_job = H.start()
  H.stopped(old_job)
  H.eq(false, api.nvim_buf_is_valid(old_buf))
  H.eq(true, api.nvim_win_is_valid(new_win))
  H.eq(-1, vim.fn.jobwait({ new_job }, 0)[1])
  vim.fn.chansend(new_job, "replacement\n")
  H.output(new_buf, "ECHO:replacement")
end)

H.test("failed exits retain diagnostic output and open retries with a fresh process", function()
  local buf, win, job = H.start()
  vim.fn.chansend(job, "exit 7\n")
  H.wait(function()
    return #api.nvim_buf_get_keymap(buf, "n") > 0
  end)
  H.output(buf, "EXITING:7")
  H.contains(H.notifications[1].message, "process exited with code 7")
  H.eq(vim.log.levels.ERROR, H.notifications[1].level)
  H.eq(true, api.nvim_win_is_valid(win))
  local replacement, _, new_job = H.start()
  assert(replacement ~= buf and new_job ~= job)
  H.eq(false, api.nvim_buf_is_valid(buf))
end)

H.test("immediate process failures leave output available", function()
  require("lazydocker").setup(H.fixture({ "--exit=12" }))
  assert(require("lazydocker").open())
  local buf = api.nvim_get_current_buf()
  H.output(buf, "STARTUP FAILURE: fixture diagnostic")
  H.wait(function()
    return #api.nvim_buf_get_keymap(buf, "n") > 0
  end)
  H.eq(true, api.nvim_buf_is_valid(buf))
end)

H.test("missing executables fail before allocating a buffer or window", function()
  require("lazydocker").setup({ command = H.root .. "/missing-lazydocker" })
  local buffers, windows = api.nvim_list_bufs(), api.nvim_list_wins()
  H.eq(false, require("lazydocker").open())
  H.eq(buffers, api.nvim_list_bufs())
  H.eq(windows, api.nvim_list_wins())
end)

H.test("invalid directories and open options fail without opening a terminal", function()
  local windows = api.nvim_list_wins()
  for _, opts in ipairs({ { cwd = H.root .. "/missing-directory" }, { cwd = "" }, { cwd = 1 }, "invalid" }) do
    H.eq(false, require("lazydocker").open(opts))
    H.eq(windows, api.nvim_list_wins())
  end
end)

H.test("synchronous spawn errors clean up the window and buffer", function()
  local cwd = H.tempdir()
  api.nvim_create_autocmd("FileType", {
    pattern = "lazydocker",
    once = true,
    callback = function()
      -- Simulate a working directory disappearing between validation and spawn.
      vim.fn.delete(cwd, "d")
    end,
  })
  local windows = api.nvim_list_wins()
  H.eq(false, require("lazydocker").open({ cwd = cwd }))
  H.eq(windows, api.nvim_list_wins())
  H.eq(false, require("lazydocker").close())
end)

H.test("externally closing the float keeps the process available for reopening", function()
  local buf, win, job = H.start()
  api.nvim_win_close(win, true)
  require("lazydocker").open()
  H.eq(buf, api.nvim_get_current_buf())
  H.eq(job, vim.b[buf].terminal_job_id)
  H.eq(-1, vim.fn.jobwait({ job }, 0)[1])
end)

H.test("externally deleting a terminal buffer stops its job and allows reopening", function()
  local buf, _, job = H.start()
  api.nvim_buf_delete(buf, { force = true })
  H.stopped(job)
  local replacement = H.start()
  assert(replacement ~= buf)
end)

H.test("bdelete unloads the terminal and allows a fresh session", function()
  local buf, _, job = H.start()
  vim.cmd("bdelete! " .. buf)
  H.stopped(job)
  local replacement = H.start()
  assert(replacement ~= buf)
end)

H.test("a deleted previous window does not break exit cleanup", function()
  vim.cmd.vsplit()
  local previous = api.nvim_get_current_win()
  local buf, _, job = H.start()
  api.nvim_win_close(previous, true)
  vim.fn.chansend(job, "exit 0\n")
  H.wait(function()
    return not api.nvim_buf_is_valid(buf)
  end)
  H.eq(true, api.nvim_win_is_valid(api.nvim_get_current_win()))
end)

H.test("hidden process exit does not steal focus from another tab", function()
  local buf, _, job = H.start()
  require("lazydocker").hide()
  vim.cmd.tabnew()
  local other = api.nvim_get_current_win()
  vim.fn.chansend(job, "exit 0\n")
  H.wait(function()
    return not api.nvim_buf_is_valid(buf)
  end)
  H.eq(other, api.nvim_get_current_win())
end)

H.test("resizing updates both the floating window and the process PTY", function()
  local buf, win, job = H.start()
  vim.o.columns = 80
  vim.o.lines = 24
  api.nvim_exec_autocmds("VimResized", {})
  H.eq(70, api.nvim_win_get_width(win))
  H.eq(18, api.nvim_win_get_height(win))
  vim.fn.chansend(job, "size\n")
  H.output(buf, "SIZE:70:18")
end)

H.test("restoring a hidden terminal updates its process dimensions", function()
  local buf, _, job = H.start()
  require("lazydocker").hide()
  vim.o.columns = 80
  vim.o.lines = 24
  api.nvim_exec_autocmds("VimResized", {})
  require("lazydocker").open()
  vim.fn.chansend(job, "size\n")
  H.output(buf, "SIZE:70:18")
end)

H.test("full-size and tiny layouts stay inside the editor grid", function()
  require("lazydocker").setup(vim.tbl_deep_extend("force", H.fixture(), {
    window = { width = 1, height = 1, winblend = 15 },
  }))
  local _, win = H.start()
  H.eq(15, vim.wo[win].winblend)
  for _, size in ipairs({ { 80, 24 }, { 12, 6 }, { 5, 3 } }) do
    vim.o.columns, vim.o.lines = size[1], size[2]
    api.nvim_exec_autocmds("VimResized", {})
    local layout = api.nvim_win_get_config(win)
    assert(layout.width >= 1 and layout.height >= 1)
    assert(layout.col + layout.width <= vim.o.columns)
    assert(layout.row + layout.height <= vim.o.lines - vim.o.cmdheight)
    if layout.width < 12 then
      H.eq(nil, layout.title)
    end
  end
end)

H.test("setup and repeated sessions do not accumulate autocmds", function()
  local before = #api.nvim_get_autocmds({ group = "LazyDocker" })
  for _ = 1, 3 do
    require("lazydocker").setup(H.fixture())
    H.start()
    require("lazydocker").close()
  end
  H.eq(before, #api.nvim_get_autocmds({ group = "LazyDocker" }))
end)

H.test("highlight defaults survive colorscheme changes and respect overrides", function()
  H.start()
  api.nvim_set_hl(0, "LazyDockerBorder", { fg = "#abcdef" })
  api.nvim_exec_autocmds("ColorScheme", {})
  H.eq(0xabcdef, api.nvim_get_hl(0, { name = "LazyDockerBorder", link = false }).fg)
end)

H.test("health reports the configured executable and actionable missing-binary errors", function()
  local original = vim.health
  local messages = {}
  vim.health = {}
  for _, level in ipairs({ "start", "ok", "warn", "error", "info" }) do
    vim.health[level] = function(message)
      messages[#messages + 1] = level .. ":" .. message
    end
  end
  H.resources[#H.resources + 1] = function()
    vim.health = original
  end
  require("lazydocker.health").check()
  H.contains(table.concat(messages, "\n"), "ok:Executable found: " .. vim.v.progpath)
  require("lazydocker").setup({ command = "nonexistent-lazydocker-test" })
  require("lazydocker.health").check()
  H.contains(table.concat(messages, "\n"), "error:Executable not found: nonexistent-lazydocker-test")
end)

H.test("help tags generate and the public API documentation is discoverable", function()
  local runtime = H.tempdir()
  vim.fn.mkdir(runtime .. "/doc", "p")
  vim.fn.writefile(vim.fn.readfile(H.root .. "/doc/lazydocker.txt"), runtime .. "/doc/lazydocker.txt")
  vim.cmd.helptags(vim.fn.fnameescape(runtime .. "/doc"))
  vim.opt.runtimepath:append(runtime)
  H.resources[#H.resources + 1] = function()
    vim.opt.runtimepath:remove(runtime)
  end
  vim.cmd.help("lazydocker-api")
  H.eq("help", vim.bo.buftype)
  H.contains(api.nvim_get_current_line(), "lazydocker-api")
end)
