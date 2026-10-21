# Contributing

## Local setup

Clone this repository and use Neovim 0.11 or newer. To load your checkout with `lazy.nvim`:

```lua
{
  dir = "/absolute/path/to/lazydocker.nvim",
  cmd = { "LazyDocker", "LazyDockerToggle" },
  opts = {},
}
```

## Automated tests

From the repository root:

```sh
make test
```

Or invoke Neovim directly:

```sh
nvim --headless -u NONE -i NONE -n -l tests/run.lua
```

The suite requires only Neovim on Linux or macOS. It does not require Docker, LazyDocker, a running daemon, or a third-party test framework.

- **Integration tests** launch a small interactive Neovim/Lua fixture as a real terminal process. They verify configuration, literal arguments and paths, inherited environment, focus, session reuse, exit cleanup, error recovery, resizing, and external window/buffer deletion.
- **Interactive UI tests** launch a second Neovim in a PTY and send actual keyboard input. They check terminal-mode entry, input forwarding, terminal-mode toggling, rendered borders, resize propagation to the process, normal exit, and failed-start diagnostics.
- **Documentation checks** generate help tags in a temporary directory and open the public API reference.

Tests wait for observable events with bounded timeouts rather than fixed sleeps. Temporary processes and directories are cleaned up after each case, including failures. A failing assertion exits Neovim with a nonzero status.

Run against a particular Neovim binary:

```sh
make test NVIM=/path/to/nvim
```

CI runs the suite on Linux and macOS with Neovim 0.11.0 and the current stable release, plus nightly on Linux.

## Formatting

Install [StyLua](https://github.com/JohnnyMorganz/StyLua), then run:

```sh
make format-check
make format
```

CI checks formatting using StyLua 2.6.0. `make check` runs both formatting checks and tests.

## Real-LazyDocker smoke test

For changes to terminal behavior, also test with LazyDocker and a compatible running Docker daemon:

1. Load the local checkout in an interactive Neovim instance.
2. Run `:LazyDocker` in a project directory. Confirm the UI is centered, has no line-number/sign gutters, and receives input immediately.
3. Navigate between LazyDocker panels and view container information or logs.
4. Hide and restore it using a normal/terminal toggle mapping. Check that the selected panel and process are preserved.
5. Resize Neovim, including a small terminal, and inspect the borders and layout.
6. Quit using LazyDocker's `q`. Confirm focus and normal mode return to the original editor window.
7. Run `:checkhealth lazydocker` and check that `:help lazydocker.nvim` opens.

Keep the automated fixture deterministic. Use real Docker smoke tests to validate the external application's rendering and integration.

## Architecture

- `plugin/lazydocker.lua`: lightweight command registration; loads implementation on use.
- `lua/lazydocker/init.lua`: public API, single-session lifecycle, terminal jobs, and autocmds.
- `lua/lazydocker/config.lua`: defaults and validation.
- `lua/lazydocker/window.lua`: float geometry, local window options, and highlight defaults.
- `lua/lazydocker/health.lua`: `:checkhealth lazydocker` integration.
- `doc/lazydocker.txt`: in-editor reference.

Keep the runtime dependency-free. Pass executable arguments as a list, leave Neovim's working directory alone, and guard asynchronous callbacks against stale sessions. Update both the README and help reference when changing the public API.
