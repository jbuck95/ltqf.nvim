# ltqf.nvim - LanguageTool-QuickFix 

A lightweight, fast, and customizable Neovim plugin for local spelling and grammar checking using LanguageTool.

## Features 

- **Local Server Management:** Automatically starts and stops the local Java LanguageTool server.
- **Buffer Highlights:** Direct visual highlighting of errors and spelling mistakes in your buffer.
- **Interactive Quickfix-Mode:** Quickly jump through errors with a floating popup. Includes apply, ignore, undo, and go-back functionality.
- **Persistent Ignore-List:** Case-sensitive ignore list, saved simply as a `.txt` file for easy editing.
- **Advanced Filtering:** Regex-based filters to exclude specific lines (e.g., Blockquotes), entire blocks (via start/end tokens like `# Literature`), and inline elements (e.g., Markdown footnotes or LaTeX commands) from being sent to the server.
- **Floating UI:** Conveniently view errors and apply correction suggestions directly under the cursor.

## Prerequisites

You need to download the offline version of LanguageTool:
1. Download the [LanguageTool Desktop/Offline version](https://languagetool.org/download/LanguageTool-stable.zip).
2. Unzip it to a directory on your machine (e.g., `~/LanguageTool-6.6/`).

## Installation & Configuration

Install and configure the plugin using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
    "jbuck95/languagetools.nvim",
    name = "languagetools.nvim",
    ft = { "markdown", "text" },
	cmd = { "LanguageToolStartServer", "LanguageToolClear", "LanguageToolStopServer", "LanguageToolCheckVisual" },

	config = function()
		require("languagetools").setup({
			--language = "de-DE",    -- Set your Language!  
			language = "en-GB",
			server_jar = vim.fn.expand("~/LanguageTool-6.6/languagetool-server.jar"),
			server_command = "java --enable-native-access=ALL-UNNAMED -cp '"
				.. vim.fn.expand("~/LanguageTool-6.6/*")
				.. "' org.languagetool.server.HTTPServer &> /dev/null",
			ignored_words_path = vim.fn.expand("~/.config/nvim/lua/languagetools/ignored.txt"),

			inline_exclude_patterns = {
				"%[%^%d+%]",  -- Obsidian footnotes [^1]
				"\\newpage",  -- latex examples 
				"\\pagebreak",   
				"\\medskip",   
			},
			exclude_patterns = {
				"^>",         -- Blockquotes
				"^%s*>",      -- Blockquotes + whitespace
			},

			-- check_start_token = "^# Introduction", -- Start the check from here
			-- check_end_token = "^# Literature", -- End check here
		})

		local map = vim.keymap.set
		map("n", "<leader>ls", "<Plug>(LTStartServer)",  { desc = "LT: Start server" })
		map("n", "<leader>lc", "<Plug>(LTCheck)",        { desc = "LT: Check buffer" })
		map("n", "<leader>lq", "<Plug>(LTQuickfix)",     { desc = "LT: Quickfix mode" })
		map("n", "<leader>le", "<Plug>(LTErrorAtPoint)", { desc = "LT: Error at point" })
		map("n", "<leader>lx", "<Plug>(LTClear)",        { desc = "LT: Clear" })
		map("v", "<leader>lv", "<Plug>(LTCheckVisual)",  { desc = "LT: Check visual" })
	end,
}
```

## Keybindings

### Global Mappings

| Key | Action | Command/Plug |
| :--- | :--- | :--- |
| `<leader>ls` | Start LanguageTool server | `<Plug>(LTStartServer)` |
| `<leader>lc` | Check the whole buffer | `<Plug>(LTCheck)` |
| `<leader>lv` | Check visual selection | `<Plug>(LTCheckVisual)` |
| `<leader>lq` | Start Interactive Quickfix mode | `<Plug>(LTQuickfix)` |
| `<leader>le` | Show error under cursor | `<Plug>(LTErrorAtPoint)` |
| `<leader>lx` | Clear highlights & close popups | `<Plug>(LTClear)` |

### Popup UI (Quickfix / Error at Point)
When a floating window with suggestions is open, you can use the following actions:

| Key | Action |
| :--- | :--- |
| `1`-`9` | Apply the corresponding suggestion and move to the next |
| `i` | Add the word to your `ignore.txt` file |
| `u` | Undo the last applied fix and go back one step |
| `b` | Go back to the previous error (without undoing text) |
| `q` | Close the popup |

## Credits

This project is heavily inspired by [vigoux/LanguageTool.nvim](https://github.com/vigoux/LanguageTool.nvim).

## License

The **Languagetools-nvim** plugin is distributed under the VIM LICENSE (see `:help copyright` in Neovim, replacing "Vim" with "Languagetools-nvim").

[LanguageTool](https://languagetool.org/) is an independent software project and is freely available under the LGPL license.
