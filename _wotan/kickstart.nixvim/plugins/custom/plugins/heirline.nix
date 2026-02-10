{...}: {
  programs.nixvim = {
    plugins.heirline = {
      enable = true;
      settings = {
        statusline.__raw = ''
          local conditions = require('heirline.conditions')

          local Space = { provider = ' ' }
          local Align = { provider = '%=' }

          local ViMode = {
            init = function(self)
              self.mode = vim.fn.mode(1)
            end,
            static = {
              mode_names = {
                n = 'N', no = 'N', nt = 'N',
                v = 'V', V = 'V',
                i = 'I', ic = 'I', ix = 'I',
                s = 'S', S = 'S',
                R = 'R', Rc = 'R', Rx = 'R', Rv = 'R',
                c = 'C', cv = 'C', r = 'R', rm = 'R', ['r?'] = 'R',
                ['!'] = '!', t = 'T',
              },
            },
            provider = function(self)
              local name = self.mode_names[self.mode] or self.mode
              return '  ' .. name .. ' '
            end,
            hl = { bold = true },
            update = { 'ModeChanged' },
          }

          local Git = {
            condition = conditions.is_git_repo,
            provider = function()
              local gsd = vim.b.gitsigns_status_dict
              if not gsd or not gsd.head then return "" end
              return ('  %s '):format(gsd.head)
            end,
          }

          local FileName = {
            provider = function()
              local name = vim.api.nvim_buf_get_name(0)
              if name == "" then return '[No Name]' end
              return vim.fn.fnamemodify(name, ':t')
            end,
            hl = { bold = true },
          }

          local diag_cfg = vim.diagnostic.config()
          local diag_signs = diag_cfg and diag_cfg.signs
          local get_sign = function(sev, default)
            if type(diag_signs) == 'table' and diag_signs.text then
              return diag_signs.text[sev] or default
            end
            return default
          end

          local Diagnostics = {
            condition = conditions.has_diagnostics,
            static = {
              error_icon = get_sign(vim.diagnostic.severity.ERROR, ' '),
              warn_icon = get_sign(vim.diagnostic.severity.WARN, ' '),
              info_icon = get_sign(vim.diagnostic.severity.INFO, ' '),
              hint_icon = get_sign(vim.diagnostic.severity.HINT, ' '),
            },
            init = function(self)
              self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
              self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
              self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
              self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
            end,
            update = { 'DiagnosticChanged', 'BufEnter' },
            { provider = '[' },
            {
              provider = function(self) return self.errors > 0 and (self.error_icon .. self.errors .. ' ') end,
              hl = { fg = 'DiagnosticError' },
            },
            {
              provider = function(self) return self.warnings > 0 and (self.warn_icon .. self.warnings .. ' ') end,
              hl = { fg = 'DiagnosticWarn' },
            },
            {
              provider = function(self) return self.info > 0 and (self.info_icon .. self.info .. ' ') end,
              hl = { fg = 'DiagnosticInfo' },
            },
            {
              provider = function(self) return self.hints > 0 and (self.hint_icon .. self.hints) end,
              hl = { fg = 'DiagnosticHint' },
            },
            { provider = ']' },
          }

          local LSPActive = {
            condition = conditions.lsp_attached,
            update = { 'LspAttach', 'LspDetach' },
            provider = function()
              local names = {}
              for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
                table.insert(names, client.name)
              end
              if #names == 0 then return "" end
              return ' ' .. table.concat(names, ',') .. ' '
            end,
          }

          local Ruler = { provider = ' %2l:%-2v ' }

          return { ViMode, Space, Git, FileName, Space, Diagnostics, Align, LSPActive, Ruler }
        '';

        winbar.__raw = ''
          local navic_ok, navic = pcall(require, 'nvim-navic')
          if not navic_ok then return nil end

          local Breadcrumbs = {
            condition = function()
              return navic.is_available() and navic.get_location() ~= ""
            end,
            provider = function()
              return navic.get_location()
            end,
          }

          return { Breadcrumbs }
        '';

        opts.__raw = ''
          local conditions = require('heirline.conditions')
          return {
            disable_winbar_cb = function(args)
              return conditions.buffer_matches({
                buftype = { 'nofile', 'prompt', 'help', 'quickfix' },
                filetype = { '^git', 'neo-tree', 'Trouble', 'dashboard' },
              }, args.buf)
            end,
          }
        '';
      };
    };
  };
}
