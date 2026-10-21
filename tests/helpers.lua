local H = { cases = {}, root = vim.fn.getcwd(), resources = {} }

function H.test(name, run)
  H.cases[#H.cases + 1] = { name = name, run = run }
end

function H.eq(expected, actual)
  if not vim.deep_equal(expected, actual) then
    error("expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual), 2)
  end
end

function H.contains(text, fragment)
  assert(text:find(fragment, 1, true), "missing " .. vim.inspect(fragment) .. " in " .. vim.inspect(text))
end

function H.wait(predicate, message, timeout)
  assert(vim.wait(timeout or 5000, predicate, 10), message or "timed out waiting for terminal")
end

function H.text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

function H.output(buf, fragment)
  local ok = vim.wait(5000, function()
    return vim.api.nvim_buf_is_valid(buf) and H.text(buf):gsub("\n", ""):find(fragment, 1, true) ~= nil
  end, 10)
  assert(ok, "terminal did not output " .. vim.inspect(fragment) .. ":\n" .. H.text(buf))
end

function H.fixture(extra)
  local args = { "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", H.root .. "/tests/fixtures/terminal.lua" }
  vim.list_extend(args, extra or {})
  return { command = vim.v.progpath, args = args }
end

function H.start(opts)
  assert(require("lazydocker").open(opts))
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local job = vim.b[buf].terminal_job_id
  assert(job and job > 0, "missing terminal job")
  H.output(buf, "READY")
  return buf, win, job
end

function H.stopped(job)
  H.wait(function()
    return vim.fn.jobwait({ job }, 0)[1] ~= -1
  end, "terminal process did not stop")
end

function H.tempdir()
  local path = vim.fn.tempname() .. " project with spaces"
  vim.fn.mkdir(path, "p")
  H.resources[#H.resources + 1] = function()
    vim.fn.delete(path, "rf")
  end
  return path
end

function H.child(fail)
  local address = vim.fn.tempname() .. ".sock"
  local job = vim.fn.jobstart({
    vim.v.progpath,
    "-n",
    "-i",
    "NONE",
    "-u",
    H.root .. "/tests/fixtures/init.lua",
    "--listen",
    address,
  }, {
    pty = true,
    width = 120,
    height = 40,
    env = {
      LAZYDOCKER_TEST_ROOT = H.root,
      LAZYDOCKER_TEST_FAIL = fail and "1" or "",
      NVIM_NOTTYFAST = "1",
      TERM = "xterm-256color",
    },
    on_stdout = function() end,
  })
  assert(job > 0, "could not start interactive Neovim")
  local channel
  H.resources[#H.resources + 1] = function()
    if channel then
      pcall(vim.rpcnotify, channel, "nvim_command", "qa!")
    end
    pcall(vim.fn.jobstop, job)
    vim.fn.jobwait({ job }, 5000)
    if channel then
      pcall(vim.fn.chanclose, channel)
    end
    vim.fn.delete(address)
  end
  H.wait(function()
    local ok, result = pcall(vim.fn.sockconnect, "pipe", address, { rpc = true })
    if ok and result > 0 then
      channel = result
      return true
    end
  end, "interactive Neovim RPC did not start")

  local child = { job = job }
  function child.lua(code, ...)
    return vim.rpcrequest(channel, "nvim_exec_lua", code, { ... })
  end
  function child.keys(keys)
    vim.fn.chansend(job, keys)
  end
  function child.wait(code, message)
    local ok = vim.wait(5000, function()
      return child.lua(code)
    end, 10)
    assert(
      ok,
      (message or "interactive Neovim timed out: " .. code)
        .. "\n"
        .. vim.inspect(child.lua("return {mode = vim.fn.mode(), lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)}"))
    )
  end
  child.wait("return vim.fn.exists(':LazyDocker') == 2", "plugin commands were not loaded at startup")
  return child
end

function H.cleanup()
  if package.loaded.lazydocker then
    require("lazydocker").close()
  end
  for index = #H.resources, 1, -1 do
    H.resources[index]()
  end
  H.resources = {}
  vim.cmd.stopinsert()
  vim.cmd("silent! tabonly!")
  vim.cmd("silent! only!")
  vim.cmd.cd(vim.fn.fnameescape(H.root))
  vim.o.columns = 120
  vim.o.lines = 40
  vim.o.cmdheight = 1
end

return H
