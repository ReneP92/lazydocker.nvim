# lazydocker.nvim

[![CI](https://github.com/ReneP92/lazydocker.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/ReneP92/lazydocker.nvim/actions/workflows/ci.yml)

Open [LazyDocker](https://github.com/jesseduffield/lazydocker) in a floating Neovim terminal. Inspect containers, read logs, and manage your Docker environment without leaving your editor.

Inspired by [lazygit.nvim](https://github.com/kdheepak/lazygit.nvim). Written in Lua using Neovim's native terminal and floating-window APIs, with no plugin dependencies.

## Features

- `:LazyDocker` opens or focuses the terminal.
- `:LazyDockerToggle` hides or restores the same running session.
- Configurable size, border, and transparency, with automatic resizing.
- Starts in Neovim's current working directory and inherits your Docker environment.
- Restores editor focus on close and keeps diagnostic output visible after failed exits.
- Works without a `setup()` call; supports lazy loading.

## Requirements

- **Neovim 0.11+**.
- **LazyDocker** installed and available on Neovim's `PATH`, or configured with an absolute executable path.
- **Docker**, a reachable Docker daemon, and a Docker version compatible with your installed LazyDocker. Docker Compose is needed for Compose features.

On macOS, install LazyDocker with:

```sh
brew install lazydocker
```

See [LazyDocker's installation guide](https://github.com/jesseduffield/lazydocker#installation) for other platforms. The plugin uses your existing LazyDocker configuration.

## Installation

### lazy.nvim

```lua
{
  "ReneP92/lazydocker.nvim",
  cmd = { "LazyDocker", "LazyDockerToggle" },
  opts = {},
  keys = {
    { "<leader>ld", "<cmd>LazyDocker<cr>", desc = "Open LazyDocker" },
  },
}
```

### Neovim's package manager (0.12+)

```lua
vim.pack.add({ { src = "https://github.com/ReneP92/lazydocker.nvim" } })
vim.keymap.set("n", "<leader>ld", "<cmd>LazyDocker<cr>", { desc = "Open LazyDocker" })
```

### vim-plug

```vim
Plug 'ReneP92/lazydocker.nvim'
nnoremap <silent> <leader>ld <cmd>LazyDocker<cr>
```

## Usage

Run `:LazyDocker`. The terminal receives keyboard input immediately, so LazyDocker's normal keybindings work, including `q` to quit and Escape to dismiss its dialogs.

To get back to Neovim's terminal-normal mode, press `<C-\><C-n>`. From there:

- `:LazyDockerToggle` or `:close` hides the window while LazyDocker continues running.
- `:LazyDocker` shows it again.
- `:lua require("lazydocker").close()` stops the session entirely.

There is one session per Neovim instance. Reopening it preserves its process, working directory, and UI state. Quit LazyDocker or call `close()` to start a new session in a different directory or with updated configuration.

To toggle directly from both normal and terminal mode, choose a key that you do not need inside LazyDocker. For example, add this to your `lazy.nvim` spec's `keys`:

```lua
{
  "<C-g>",
  function()
    require("lazydocker").toggle()
  end,
  mode = { "n", "t" },
  desc = "Toggle LazyDocker",
},
```

No mappings are installed by default while LazyDocker is running. After a nonzero exit, the terminal stays open in normal mode: `q` closes it, and `:LazyDocker` starts a fresh process.

## Configuration

These are all the defaults. With `lazy.nvim`, put overrides in `opts`; otherwise call `setup()`:

```lua
require("lazydocker").setup({
  command = "lazydocker",
  args = {},
  window = {
    width = 0.9,
    height = 0.9,
    border = "rounded",
    winblend = 0,
  },
})
```

| Option | Description |
| --- | --- |
| `command` | Executable name or full path. Put arguments in `args`, not in this string. |
| `args` | List of arguments passed directly to the executable, without a shell. |
| `window.width` | Fraction of available width, greater than `0` and at most `1`. |
| `window.height` | Fraction of available height, greater than `0` and at most `1`. |
| `window.border` | `"none"`, `"single"`, `"double"`, `"rounded"`, `"solid"`, or `"shadow"`. |
| `window.winblend` | Integer transparency from `0` (opaque) to `100`. |

Borders are accounted for when sizing the window. On very small grids the title or border is omitted so the window fits.

Each `setup()` call merges its options with the defaults. Invalid options raise an error. Configuration changes take effect for the next new session.

### Compose files and working directory

Pass LazyDocker's CLI flags as separate arguments:

```lua
require("lazydocker").setup({
  args = { "-f", "compose.dev.yml" },
})
```

Open a new session in a specific directory:

```lua
require("lazydocker").open({ cwd = "/path/to/project" })
```

Relative paths resolve against Neovim's current working directory. By default, the plugin respects window-local and tab-local directories (`:lcd` and `:tcd`). It does not change Neovim's directory or search for a project root. LazyDocker uses the launch directory for Compose discovery; Docker context and environment variables such as `DOCKER_HOST` are inherited.

### Lua API

```lua
local lazydocker = require("lazydocker")

lazydocker.setup({})                -- Configure defaults for new sessions.
lazydocker.open({ cwd = "/path" })  -- Open or focus; cwd is optional.
lazydocker.toggle()                 -- Hide if visible, otherwise open.
lazydocker.hide()                   -- Hide and keep the process running.
lazydocker.close()                  -- Stop the process and remove its buffer.
```

`open()` and `toggle()` return `true` on success, or `false` on a launch error. `hide()` and `close()` return whether they had a window/session to act on. `toggle()` accepts the same optional argument as `open()`. Open options apply only when a new process is started.

### Highlights

| Group | Default link |
| --- | --- |
| `LazyDockerFloat` | `NormalFloat` |
| `LazyDockerBorder` | `FloatBorder` |

Customize them using `vim.api.nvim_set_hl()`. Colors drawn by LazyDocker itself are controlled by its own configuration.

## Troubleshooting

Run `:checkhealth lazydocker` to check Neovim and executable availability. It checks your configured `command` and the Docker CLI; use `docker info` to check daemon connectivity.

- **Executable not found:** check `:echo executable('lazydocker')`. GUI Neovim may inherit a different `PATH` than your shell. Set `command` to the full executable path if necessary. Shell aliases are not executable names.
- **Cannot connect to Docker:** start your Docker daemon and check the active Docker context and environment. Try launching LazyDocker directly from the same directory and environment.
- **Compose services are missing:** check `:pwd`, open a fresh session from the Compose project directory, or supply `args = { "-f", "/path/to/compose.yml" }`.
- **Keys run Neovim commands:** press `i` to re-enter terminal mode. Review any global terminal mappings that may intercept LazyDocker's keys.
- **Process exited with an error:** read the retained terminal output. Press `q` to close it or run `:LazyDocker` to retry.

In-editor reference: `:help lazydocker.nvim`.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests, formatting, architecture, and the real-LazyDocker smoke-test procedure.

## License

[MIT](LICENSE).
