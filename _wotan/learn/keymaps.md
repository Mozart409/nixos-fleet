# Neovim Keymap & Shortcuts Guide

A comprehensive reference for all keymaps and plugin shortcuts in your Neovim configuration.

**Leader Key:** `<Space>`

---

## 📂 File Navigation & Management

### File Explorer (Neo-tree)

| Keymap       | Description                          | Mode | Plugin   |
| ------------ | ------------------------------------ | ---- | -------- |
| `<leader>fe` | Reveal file in Neo-tree              | n    | neo-tree |
| `\`          | Close Neo-tree window (when focused) | n    | neo-tree |

### File Browser (Oil) - Currently Disabled

| Keymap  | Description                    | Mode | Plugin |
| ------- | ------------------------------ | ---- | ------ |
| `g?`    | Show help                      | n    | oil    |
| `<CR>`  | Select/open file               | n    | oil    |
| `-`     | Go to parent directory         | n    | oil    |
| `_`     | Open current working directory | n    | oil    |
| `` ` `` | Change directory (cd)          | n    | oil    |
| `~`     | Tab change directory (tcd)     | n    | oil    |
| `g.`    | Toggle hidden files            | n    | oil    |

---

## 🔍 Search & Find (FZF-lua)

### Basic Search

| Keymap             | Description                             | Mode | Plugin  |
| ------------------ | --------------------------------------- | ---- | ------- |
| `<leader>sf`       | Search Files                            | n    | fzf-lua |
| `<leader>sg`       | Search by Grep (live grep)              | n    | fzf-lua |
| `<leader>sw`       | Search current Word under cursor        | n    | fzf-lua |
| `<leader><leader>` | Find existing buffers                   | n    | fzf-lua |
| `<leader>sh`       | Search Help tags                        | n    | fzf-lua |
| `<leader>sk`       | Search Keymaps                          | n    | fzf-lua |
| `<leader>ss`       | Search Select (fzf-lua builtin pickers) | n    | fzf-lua |
| `<leader>sd`       | Search Diagnostics in document          | n    | fzf-lua |
| `<leader>sr`       | Search Resume (resume last search)      | n    | fzf-lua |
| `<leader>s.`       | Search Recent Files (oldfiles)          | n    | fzf-lua |

### Advanced Search

| Keymap       | Description                      | Mode | Plugin  |
| ------------ | -------------------------------- | ---- | ------- |
| `<leader>/`  | Fuzzily search in current buffer | n    | fzf-lua |
| `<leader>s/` | Search in open files             | n    | fzf-lua |
| `<leader>sn` | Search Neovim config files       | n    | fzf-lua |

---

## 🔧 LSP (Language Server Protocol)

### Navigation

| Keymap      | Description              | Mode | Plugin        |
| ----------- | ------------------------ | ---- | ------------- |
| `gd`        | Goto Definition          | n    | lsp + fzf-lua |
| `gr`        | Goto References          | n    | lsp + fzf-lua |
| `gI`        | Goto Implementation      | n    | lsp + fzf-lua |
| `gD`        | Goto Declaration         | n    | lsp           |
| `<leader>D` | Type Definition          | n    | lsp + fzf-lua |
| `<C-t>`     | Jump back (built-in Vim) | n    | vim           |

### Code Actions

| Keymap       | Description              | Mode | Plugin     |
| ------------ | ------------------------ | ---- | ---------- |
| `<leader>ca` | Code Action              | n    | lsp        |
| `<leader>rn` | Rename with live preview | n    | inc-rename |

### Symbols & Diagnostics

| Keymap       | Description                   | Mode | Plugin        |
| ------------ | ----------------------------- | ---- | ------------- |
| `<leader>ds` | Document Symbols              | n    | lsp + fzf-lua |
| `<leader>ws` | Workspace Symbols             | n    | lsp + fzf-lua |
| `<leader>q`  | Open diagnostic quickfix list | n    | lsp           |

### Toggles

| Keymap       | Description        | Mode | Plugin |
| ------------ | ------------------ | ---- | ------ |
| `<leader>th` | Toggle Inlay Hints | n    | lsp    |

---

## 📝 Editing & Code Manipulation

### Formatting

| Keymap      | Description   | Mode | Plugin  |
| ----------- | ------------- | ---- | ------- |
| `<leader>f` | Format buffer | n, v | conform |

### Commenting (Comment.nvim - Default Keymaps)

| Keymap | Description                          | Mode | Plugin  |
| ------ | ------------------------------------ | ---- | ------- |
| `gcc`  | Toggle line comment                  | n    | comment |
| `gbc`  | Toggle block comment                 | n    | comment |
| `gc`   | Toggle comment (motion/visual)       | n, v | comment |
| `gb`   | Toggle block comment (motion/visual) | n, v | comment |

### Documentation Generation (Neogen)

| Keymap       | Description                          | Mode | Plugin |
| ------------ | ------------------------------------ | ---- | ------ |
| `<leader>nf` | Generate Function documentation      | n    | neogen |
| `<leader>nc` | Generate Class documentation         | n    | neogen |
| `<leader>nt` | Generate Type documentation          | n    | neogen |
| `<leader>ng` | Generate documentation (auto-detect) | n    | neogen |

---

## 🎯 Text Objects (Treesitter)

### Select Text Objects

| Keymap | Description                       | Mode | Source                 |
| ------ | --------------------------------- | ---- | ---------------------- |
| `af`   | Around function (outer)           | v, o | treesitter-textobjects |
| `if`   | Inside function (inner)           | v, o | treesitter-textobjects |
| `ac`   | Around class (outer)              | v, o | treesitter-textobjects |
| `ic`   | Inside class (inner)              | v, o | treesitter-textobjects |
| `aa`   | Around parameter/argument (outer) | v, o | treesitter-textobjects |
| `ia`   | Inside parameter/argument (inner) | v, o | treesitter-textobjects |

### Move Between Functions/Parameters

| Keymap | Description              | Mode | Source                 |
| ------ | ------------------------ | ---- | ---------------------- |
| `]m`   | Next function start      | n    | treesitter-textobjects |
| `[m`   | Previous function start  | n    | treesitter-textobjects |
| `]M`   | Next function end        | n    | treesitter-textobjects |
| `[M`   | Previous function end    | n    | treesitter-textobjects |
| `]a`   | Next parameter start     | n    | treesitter-textobjects |
| `[a`   | Previous parameter start | n    | treesitter-textobjects |
| `]A`   | Next parameter end       | n    | treesitter-textobjects |
| `[A`   | Previous parameter end   | n    | treesitter-textobjects |

### Swap Parameters

| Keymap | Description                  | Mode | Source                 |
| ------ | ---------------------------- | ---- | ---------------------- |
| `>a`   | Swap parameter with next     | n    | treesitter-textobjects |
| `<a`   | Swap parameter with previous | n    | treesitter-textobjects |

---

## 🐛 Diagnostics & Debugging (Trouble)

| Keymap       | Description                    | Mode | Plugin  |
| ------------ | ------------------------------ | ---- | ------- |
| `<leader>xx` | Toggle diagnostics (workspace) | n    | trouble |
| `<leader>xX` | Toggle buffer diagnostics      | n    | trouble |
| `<leader>cs` | Toggle symbols                 | n    | trouble |
| `<leader>xL` | Toggle location list           | n    | trouble |
| `<leader>xQ` | Toggle quickfix list           | n    | trouble |

---

## 📋 Todo Comments

| Keymap | Description           | Mode | Plugin        |
| ------ | --------------------- | ---- | ------------- |
| `]t`   | Next todo comment     | n    | todo-comments |
| `[t`   | Previous todo comment | n    | todo-comments |

**Supported Keywords:** `TODO`, `FIX`, `FIXME`, `BUG`, `HACK`, `WARN`, `WARNING`, `XXX`, `PERF`, `NOTE`, `INFO`, `TEST`

---

## 🦀 Rust Crates (crates.nvim)

These keymaps are **buffer-local** — they are only active inside a `Cargo.toml` file. Latest crates.io versions are shown inline as virtual text.

| Keymap       | Description                  | Mode | Plugin |
| ------------ | ---------------------------- | ---- | ------ |
| `<leader>ct` | Toggle inline version info   | n    | crates |
| `<leader>cr` | Reload crate data            | n    | crates |
| `<leader>cv` | Show versions popup          | n    | crates |
| `<leader>cf` | Show features popup          | n    | crates |
| `<leader>cu` | Update crate(s) to req       | n, v | crates |
| `<leader>cU` | Upgrade crate(s) to latest   | n, v | crates |
| `<leader>cA` | Upgrade all crates           | n    | crates |

---

## 🔗 Code Outline (Aerial)

| Keymap      | Description                   | Mode | Plugin |
| ----------- | ----------------------------- | ---- | ------ |
| `<leader>a` | Toggle Aerial symbols sidebar | n    | aerial |

---

## 🚀 Motion Enhancement (Flash) - Default Keymaps

Flash is enabled with default keymaps:

- `s` - Flash forward search
- `S` - Flash backward search
- `r` - Remote flash (in operator-pending mode)
- `R` - Treesitter search
- `<c-s>` - Toggle flash in search mode

---

## 🔄 Git Integration

### Git UI (LazyGit)

| Keymap       | Description    | Mode | Plugin  |
| ------------ | -------------- | ---- | ------- |
| `<leader>gg` | Open LazyGit   | n    | lazygit |
| `<leader>tt` | LazyGit reveal | n    | lazygit |

### Git Signs (Gitsigns)

Gitsigns is enabled with visual indicators in the sign column:

- `+` - Added lines
- `~` - Changed lines
- `_` - Deleted lines
- `‾` - Top deleted lines

---

## 🔍 Search & Replace (Spectre)

| Keymap      | Description                   | Mode | Plugin  |
| ----------- | ----------------------------- | ---- | ------- |
| `<leader>S` | Open Spectre (search/replace) | n    | spectre |

---

## 🪟 Window Management

| Keymap  | Description                | Mode | Source |
| ------- | -------------------------- | ---- | ------ |
| `<C-h>` | Move focus to left window  | n    | core   |
| `<C-l>` | Move focus to right window | n    | core   |
| `<C-j>` | Move focus to lower window | n    | core   |
| `<C-k>` | Move focus to upper window | n    | core   |

---

## 🎓 Learning Aids (Precognition)

| Keymap       | Description               | Mode | Plugin       |
| ------------ | ------------------------- | ---- | ------------ |
| `<leader>tp` | Toggle Precognition hints | n    | precognition |
| `<leader>up` | Precognition peek         | n    | precognition |

**Precognition shows hints for:**

- Horizontal motions: `w`, `b`, `e`, `W`, `B`, `E`, `^`, `$`, `0`, `%`
- Vertical motions: `G`, `gg`, `{`, `}`

---

## 💬 Completion (nvim-cmp)

### Insert Mode Completion

| Keymap      | Description              | Mode | Plugin |
| ----------- | ------------------------ | ---- | ------ |
| `<C-n>`     | Next completion item     | i    | cmp    |
| `<C-p>`     | Previous completion item | i    | cmp    |
| `<Tab>`     | Next completion item     | i    | cmp    |
| `<S-Tab>`   | Previous completion item | i    | cmp    |
| `<C-y>`     | Confirm completion       | i    | cmp    |
| `<CR>`      | Confirm completion       | i    | cmp    |
| `<C-Space>` | Trigger completion       | i    | cmp    |
| `<C-b>`     | Scroll docs backward     | i    | cmp    |
| `<C-f>`     | Scroll docs forward      | i    | cmp    |

### Snippet Navigation

| Keymap  | Description                          | Mode | Plugin  |
| ------- | ------------------------------------ | ---- | ------- |
| `<C-l>` | Jump to next snippet placeholder     | i, s | luasnip |
| `<C-h>` | Jump to previous snippet placeholder | i, s | luasnip |

---

## 🛠️ Utility

### Terminal

| Keymap       | Description        | Mode | Source |
| ------------ | ------------------ | ---- | ------ |
| `<Esc><Esc>` | Exit terminal mode | t    | core   |

### Search

| Keymap  | Description             | Mode | Source |
| ------- | ----------------------- | ---- | ------ |
| `<Esc>` | Clear search highlights | n    | core   |

---

## 🗂️ Which-Key Groups

These prefixes show helpful labels in which-key popup:

| Prefix      | Description                  |
| ----------- | ---------------------------- |
| `<leader>c` | **[C]**ode actions           |
| `<leader>d` | **[D]**ocument/diagnostics   |
| `<leader>r` | **[R]**ename                 |
| `<leader>s` | **[S]**earch                 |
| `<leader>w` | **[W]**orkspace              |
| `<leader>t` | **[T]**oggle                 |
| `<leader>h` | Git **[H]**unk (visual mode) |
| `<leader>n` | **[N]**eogen documentation   |
| `<leader>x` | Diagnostics (Trouble)        |
| `<leader>f` | **[F]**ormat/File explorer   |

---

## 🎨 Mini.nvim Features

Currently only `mini.icons` is enabled. Commented out but available:

- **mini.ai** - Better text objects (va), yinq, ci')
- **mini.surround** - Surround operations (saiw), sd', sr)')

---

## 📚 Additional Notes

### Plugins Currently Disabled

- **Oil.nvim** - File browser (enable = false)
- **Neogit** - Git interface (enable = false, LazyGit used instead)
- **Telescope** - Replaced with fzf-lua

### Format on Save

Conform.nvim is configured to format on save with 500ms timeout, using LSP fallback for unsupported languages (except C/C++).

### Auto-pairs

Autopairs plugin is enabled for automatic bracket/quote pairing.

---

## 🔗 Plugin Sources Summary

| Category            | Plugins                                                     |
| ------------------- | ----------------------------------------------------------- |
| **File Navigation** | neo-tree, oil (disabled)                                    |
| **Search**          | fzf-lua, telescope (disabled)                               |
| **LSP**             | lsp, fidget, cmp-nvim-lsp                                   |
| **Completion**      | nvim-cmp, luasnip, friendly-snippets                        |
| **Syntax**          | treesitter, treesitter-textobjects                          |
| **Formatting**      | conform-nvim                                                |
| **Git**             | gitsigns, lazygit                                           |
| **Diagnostics**     | trouble                                                     |
| **Motion**          | flash, precognition                                         |
| **Editing**         | comment, inc-rename, neogen                                 |
| **UI**              | which-key, noice, dressing, dashboard, heirline, nvim-navic |
| **Code Nav**        | aerial, nvim-navic                                          |
| **Utils**           | todo-comments, nvim-colorizer, spectre                      |

---

**Tip:** Press `<leader>sk` to search all keymaps interactively in Neovim, or use `<leader>sh` to search help documentation!
