# ltqf.nvim - LanguageTool-QuickFix 

A lightweight, fast, and customizable Neovim plugin for local spelling and grammar checking using LanguageTool.

## Features 

- **Buffer Highlights:** Direct visual highlighting of errors and spelling mistakes in your buffer.
- **Interactive Quickfix-Mode:** Quickly jump through errors with a floating popup. Includes apply, ignore, undo, and go-back functionality.
- **Persistent Ignore-List:** Case-sensitive ignore list, saved simply as a `.txt` file for easy editing.
- **Advanced Filtering:** Regex-based filters to exclude specific lines (e.g., Blockquotes), entire blocks (via start/end tokens like `# Literature`), and inline elements (e.g., Markdown footnotes or LaTeX commands) from being sent to the server.
- **Floating UI:** Conveniently view errors and apply correction suggestions directly under the cursor.

https://github.com/user-attachments/assets/aff6e251-e5ee-435a-9fe5-54b33f7b5b1e

## Requirements

- `java` (JRE/JDK) -- for running LanguageTool server
- `curl` -- for accessing the LanguageTool HTTP API
- [LanguageTool](https://languagetool.org/download/LanguageTool-stable.zip) -- download and extract to `~/LanguageTool-6.6/`

Verify: `:checkhealth ltqf`  |  Help: `:h ltqf`

## Installation & Configuration

Install and configure the plugin using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "jbuck95/ltqf.nvim",
  ft = { "markdown", "text" },
  cmd = "LanguageTool",
  keys = {
    { "<leader>ls", "<Plug>(LTStartServer)",  desc = "LT: Start server" },
    { "<leader>lc", "<Plug>(LTCheck)",        desc = "LT: Check buffer" },
    { "<leader>lq", "<Plug>(LTQuickfix)",     desc = "LT: Quickfix mode" },
    { "<leader>le", "<Plug>(LTErrorAtPoint)", desc = "LT: Error at point" },
    { "<leader>lx", "<Plug>(LTClear)",        desc = "LT: Clear" },
    { "<leader>lv", "<Plug>(LTCheckVisual)",  desc = "LT: Check visual", mode = "v" },
  },
  opts = {
    language = "en-GB",
    languagetool_server_jar = vim.fn.expand("~/LanguageTool-6.6/languagetool-server.jar"),
    ignored_words_path = vim.fn.stdpath("data") .. "/ltqf_ignored.txt",
    inline_exclude_patterns = {
      "%[%^%d+%]",
      "\\newpage",
      "\\pagebreak",
      "\\medskip",
    },
    exclude_patterns = {
      "^>",
      "^%s*>",
    },
    -- check_start_token = "^# Introduction",
    -- check_end_token = "^# Literature",
  },
}
```

> **Tip:** See `lua/plugins/ltqf.lua` in the repo for a full example spec.

You can also show ltqf-status in your lualine:
```lua
{
    require("ltqf").status,
    color = function()
        local s = require("ltqf").status()
        if s == "✓" then return { fg = "#00ff00" }
        else return { fg = "#ff6600" }
        end
    end
}
```

## Usage

1. Start the server (`:LanguageTool start`)
2. Check the buffer (`:LanguageTool check`)
3. Run quickfix or manually correct the text

## Commands

All commands are scoped under `:LanguageTool`:

| Command | Action |
| :--- | :--- |
| `:LanguageTool start` | Start LanguageTool server |
| `:LanguageTool stop` | Stop LanguageTool server |
| `:LanguageTool check` | Check the whole buffer |
| `:LanguageTool check-visual` | Check current visual selection |
| `:LanguageTool quickfix` | Toggle interactive quickfix mode |
| `:LanguageTool error` | Show error under cursor in popup |
| `:LanguageTool clear` | Clear highlights, diagnostics, and popups |

## Keybindings

ltqf does **not** create global keymaps. It provides `<Plug>` mappings that you map yourself:

### `<Plug>` Mappings

| Mapping | Mode | Action |
| :--- | :---: | :--- |
| `<Plug>(LTStartServer)` | n | Start LanguageTool server |
| `<Plug>(LTStopServer)` | n | Stop LanguageTool server |
| `<Plug>(LTCheck)` | n | Check the whole buffer |
| `<Plug>(LTCheckVisual)` | v | Check visual selection |
| `<Plug>(LTQuickfix)` | n | Toggle quickfix mode |
| `<Plug>(LTErrorAtPoint)` | n | Show error under cursor |
| `<Plug>(LTClear)` | n | Clear everything |

Example mappings:
```lua
vim.keymap.set("n", "<leader>ls", "<Plug>(LTStartServer)",  { desc = "LT: Start server" })
vim.keymap.set("n", "<leader>lc", "<Plug>(LTCheck)",        { desc = "LT: Check buffer" })
vim.keymap.set("n", "<leader>lq", "<Plug>(LTQuickfix)",     { desc = "LT: Quickfix mode" })
vim.keymap.set("n", "<leader>le", "<Plug>(LTErrorAtPoint)", { desc = "LT: Error at point" })
vim.keymap.set("n", "<leader>lx", "<Plug>(LTClear)",        { desc = "LT: Clear" })
vim.keymap.set("v", "<leader>lv", "<Plug>(LTCheckVisual)",  { desc = "LT: Check visual" })
```

### Popup UI (Quickfix / Error at Point)
When a floating window with suggestions is open, you can use the following actions:

| Key | Action |
| :--- | :--- |
| `1`-`9` | Apply the corresponding suggestion and move to the next |
| `i` | Add the word to your ignore file |
| `u` | Undo the last applied fix and go back one step |
| `b` | Go back to the previous error (without undoing text) |
| `q` | Close the popup |

## Lua API

All functionality is accessible programmatically:

```lua
local lt = require("ltqf")

-- Setup with options (optional — works out of the box)
lt.setup({ language = "en-GB" })

-- Server control
lt.start_server()   -- Start LanguageTool server
lt.stop_server()    -- Stop LanguageTool server

-- Checking
lt.check(bufnr)           -- Check entire buffer
lt.check_visual()         -- Check visual selection
lt.clear()                -- Clear highlights, diagnostics, popups

-- Quickfix navigation
lt.toggle_quickfix_mode() -- Enter/exit interactive quickfix mode
lt.show_error_at_point()  -- Show error under cursor in popup
lt.undo_last_fix()        -- Undo last applied fix
lt.go_back_without_undo() -- Go to previous error without undoing

-- Command dispatch
lt.dispatch({ fargs = { "check" } })

-- Lualine component
lt.status()               -- Returns "✓", "G:3 S:1", or ""

-- Low-level
lt.apply_fix(bufnr, error_match, suggestion_nr)
```

## Minimal Config for Issues

```lua
vim.cmd([[set rtp+=~/.local/share/nvim/lazy/ltqf.nvim]])
vim.keymap.set("n", "<leader>lc", "<Plug>(LTCheck)")
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `language` | `"en-GB"` | Language code for LanguageTool |
| `languagetool_server_jar` | `""` | Path to `languagetool-server.jar` |
| `languagetool_server_command` | `""` | Custom server command (overrides jar) |
| `ignored_words_path` | `stdpath("data")/languagetool_ignored.txt` | Ignore-list file |
| `check_start_token` | `""` | Line pattern to start checking |
| `check_end_token` | `""` | Line pattern to stop checking |
| `exclude_patterns` | `{}` | Line-level exclude patterns |
| `inline_exclude_patterns` | `{}` | Inline exclude patterns |

## Credits

This project is heavily inspired by [vigoux/LanguageTool.nvim](https://github.com/vigoux/LanguageTool.nvim).

## Disclaimer

Made for myself and released as part of my .md writing setup, large
parts are vibe coded.

## License

The **ltqf.nvim** plugin is distributed under the MIT License.

[LanguageTool](https://languagetool.org/) is an independent software project and is freely available under the LGPL license.
