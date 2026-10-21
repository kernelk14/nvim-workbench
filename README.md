# neoworkbench.nvim

A declarative IDE layout for Neovim, and the shared core that goes with it.

The workbench turns a layout tree into real Neovim splits. Nothing is a float,
so every pane behaves like a normal window: it scrolls, it resizes, it keeps
its buffers, and it follows the file you are editing. The palette is derived
from your colorscheme, so it always matches the rest of the editor.

```
┌─────────────────┬──────────────────────────────────────────┐
│ 󰈞 Explorer     │  main.lua                                │
│  󰉋 src         │    1 │ local M = {}                       │
│   󰈞 lua        │    2 │                                  │
│    󰈞 workbench │    3 │ function M.run()                   │
│  󰉋 tests       │    4 │   return true                      │
│   󰈞 layout.lua │    5 │ end                                │
│                  │                                          │
│ 󰉋 Project      │                                          │
│  nvim-tricks    │                                          │
│   main · ✓     │                                          │
└─────────────────┴──────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────┐
│ 󰒡 Problems                                    0 problems     │
└──────────────────────────────────────────────────────────────┘
```

## Features

- **Real splits** – no floats, so the panes scroll, resize and keep their buffers like any other window.
- **Declarative layouts** – a layout is a tree of rows and columns, sizes are fractions of the parent.
- **Exact sizing** – the one cell separators Neovim draws between windows are taken out of the panes, so the size you ask for is the size you get.
- **Tree aware focus** – `<leader>Wh/j/k/l` moves between panes by their geometry, not by guessing.
- **A panel that switches** – problems, quickfix, output and terminal share the bottom pane.
- **A built in file tree** – no dependency on a file explorer plugin.
- **Colourscheme derived** – the palette is sampled from `Normal`, `Comment`, `Function` and the diagnostic groups, and follows `:colorscheme`.
- **Per project sessions** – the layout and the panel of a project are remembered.
- **No dependencies** – pure Lua on top of Neovim, nothing else.

## Requirements

- Neovim 0.10 or newer
- A [Nerd Font](https://www.nerdfonts.com/) for the icons (optional)

## Installation

lazy.nvim

```lua
{
  "kernelk14/nvim-workbench",
  opts = {},
}
```

packer.nvim

```lua
use({
  "kernelk14/nvim-workbench",
  config = function()
    require("neoworkbench").setup()
  end,
})
```

vim-plug

```vim
Plug 'kernelk14/nvim-workbench'
lua require('neoworkbench').setup()
```

Manual

```bash
git clone https://github.com/kernelk14/nvim-workbench \
  ~/.local/share/nvim/site/pack/packer/start/nvim-workbench
lua require('neoworkbench').setup()
```

## Layouts

A layout is a tree. A node is a pane, a row or a column.

```lua
require("neoworkbench").setup({
  layouts = {
    writing = {
      type = "col",
      children = {
        { type = "leaf", pane = "editor", size = 0.85 },
        { type = "leaf", pane = "panel", size = 0.15 },
      },
    },
  },
})
```

A `size` between zero and one is a fraction of the parent. Children without a
size share whatever is left over. The shorthand `{ row = { ... } }` and
`{ col = { ... } }` are supported as well.

Three layouts ship with the plugin:

| Layout    | Shape                                              |
| --------- | -------------------------------------------------- |
| `default` | file tree, editor and a full width panel at the bottom |
| `focus`   | the editor on its own                               |
| `ide`     | file tree, editor, outline and a panel               |

## Panes

| Pane       | What it shows                                            |
| ---------- | -------------------------------------------------------- |
| `editor`   | the buffer that was being edited                          |
| `explorer` | a dependency free file tree                               |
| `panel`    | the bottom pane, it shows one of the panel providers     |
| `problems` | the diagnostics of the workspace                          |
| `quickfix` | the entries of the quickfix list                          |
| `output`   | the log of the workbench                                  |
| `terminal` | a terminal running inside the pane                        |
| `outline`  | the symbols of the current document                       |

A provider is a plain table, so a pane can be pointed at a third party plugin:

```lua
require("neoworkbench.providers").register({
  name = "explorer",
  title = "Files",
  buffer = function(ctx)
    return require("neo-tree.sources.manager").get_buf()
  end,
})
```

## Commands

| Command              | Description                                  |
| -------------------- | -------------------------------------------- |
| `:Workbench`         | Open the workbench                            |
| `:WorkbenchToggle`   | Open it when closed, close it when open       |
| `:WorkbenchClose`    | Close it and restore the editor               |
| `:WorkbenchLayout`   | Switch to another layout                      |
| `:WorkbenchFocus`    | Focus a pane                                  |
| `:WorkbenchPanel`    | Change the panel provider                     |
| `:WorkbenchRefresh`  | Refresh the content of every pane             |
| `:WorkbenchSave`     | Save the session of the current project       |

## Keymaps

The defaults use `<leader>W` so they do not clash with the usual `<leader>w`
for windows.

| Key         | Action                |
| ----------- | --------------------- |
| `<leader>W` | Toggle the workbench  |
| `<leader>Wh` | Move the focus left   |
| `<leader>Wj` | Move the focus down   |
| `<leader>Wk` | Move the focus up     |
| `<leader>Wl` | Move the focus right  |
| `<leader>Wp` | Cycle the panel       |
| `<leader>Wi` | Focus the explorer    |
| `<leader>Wt` | Open the terminal     |
| `<leader>Wx` | Open the problems     |
| `<leader>WL` | Change the layout     |
| `<leader>Ws` | Save the session      |
| `<leader>Wq` | Close the workbench   |

## Configuration

```lua
require("neoworkbench").setup({
  layout = "default",
  layouts = {},
  title = true,
  auto_open = false,
  panels = { "problems", "quickfix", "output", "terminal" },
  panel = "problems",
  providers = {
    explorer = "auto",
    terminal = "auto",
    problems = "auto",
    outline = "auto",
  },
  session = {
    enabled = true,
    autosave = true,
    restore = true,
  },
  keys = {
    toggle = "<leader>W",
    focus_left = "<leader>Wh",
    focus_down = "<leader>Wj",
    focus_up = "<leader>Wk",
    focus_right = "<leader>Wl",
    panel = "<leader>Wp",
    explorer = "<leader>Wi",
    terminal = "<leader>Wt",
    problems = "<leader>Wx",
    layout = "<leader>WL",
    save = "<leader>Ws",
    close = "<leader>Wq",
  },
})
```

Set a keymap to `false` to remove it.

## neocore

The repository also ships `neocore`, the shared core of the neo plugin family.
It owns the palette and the highlight group registry:

```lua
local core = require("neocore")

core.setup({ theme = "auto" })
core.hl.define("MyPluginBorder", { fg = "border" })
core.hl.apply(core.colors())
```

Colours can be a literal, `"#ff0000"` or `"NONE"`, or the name of a palette
key, `"accent"`. Groups are registered under their full name, so several
plugins can share the core without stepping on each other.

See `:help neocore` for the whole API.

## Development

```bash
make test           # run every test file headlessly
make preview        # print the layout as plain text
make format         # format the sources with stylua
make format-check   # fail when the sources are not formatted
```

The tests need nothing but Neovim, they run headless and use a fixed grid size
so the geometry is deterministic.

## License

MIT
