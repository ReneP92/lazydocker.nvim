-- A real interactive process, launched in a PTY instead of mocking jobstart().
io.stdout:setvbuf("no")

for _, value in ipairs(arg) do
  local code = value:match("^%-%-exit=(%d+)$")
  if code then
    io.write("STARTUP FAILURE: fixture diagnostic\n")
    os.exit(tonumber(code))
  end
end

io.write("CWD:" .. vim.fn.getcwd() .. "\n")
for _, value in ipairs(arg) do
  io.write("ARG:" .. value .. "\n")
end
io.write("ENV:" .. (vim.env.LAZYDOCKER_TEST_ENV or "") .. "\n")
io.write("READY\n")

local tty = assert(vim.uv.new_tty(1, false))
while true do
  local line = io.read("*l")
  if not line then
    break
  end
  local code = line:match("^exit (%d+)$")
  if code then
    io.write("EXITING:" .. code .. "\n")
    os.exit(tonumber(code))
  elseif line == "size" then
    local width, height = tty:get_winsize()
    io.write("SIZE:" .. width .. ":" .. height .. "\n")
  else
    io.write("ECHO:" .. line .. "\n")
  end
end
os.exit(0)
