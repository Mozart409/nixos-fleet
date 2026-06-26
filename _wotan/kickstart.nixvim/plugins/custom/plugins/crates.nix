{...}: {
  # crates.nvim — shows latest crates.io versions inline in Cargo.toml,
  # with upgrade commands, completion, and popups for features/versions.
  programs.nixvim.plugins.crates = {
    enable = true;

    settings = {
      # Inline virtual text with the newest available version.
      smart_insert = true;
      autoload = true;
      autoupdate = true;

      # Pull extra metadata from crates.io (downloads, homepage, etc.).
      loading_indicator = true;

      # Use the in-process LSP source instead of the deprecated nvim-cmp
      # source. crates.nvim spins up a tiny LSP that feeds completion,
      # code actions, and hover to whatever completion engine is attached.
      lsp = {
        enabled = true;
        actions = true;
        completion = true;
        hover = true;
      };
    };
  };

  # Buffer-local keymaps, only active inside Cargo.toml.
  programs.nixvim.autoCmd = [
    {
      event = ["BufRead"];
      pattern = ["Cargo.toml"];
      callback.__raw = ''
        function()
          local crates = require("crates")
          local opts = function(desc)
            return { buffer = true, silent = true, desc = desc }
          end
          vim.keymap.set("n", "<leader>ct", crates.toggle, opts("Crates: toggle"))
          vim.keymap.set("n", "<leader>cr", crates.reload, opts("Crates: reload"))
          vim.keymap.set("n", "<leader>cv", crates.show_versions_popup, opts("Crates: versions popup"))
          vim.keymap.set("n", "<leader>cf", crates.show_features_popup, opts("Crates: features popup"))
          vim.keymap.set("n", "<leader>cu", crates.update_crate, opts("Crates: update crate"))
          vim.keymap.set("v", "<leader>cu", crates.update_crates, opts("Crates: update crates"))
          vim.keymap.set("n", "<leader>cU", crates.upgrade_crate, opts("Crates: upgrade crate"))
          vim.keymap.set("v", "<leader>cU", crates.upgrade_crates, opts("Crates: upgrade crates"))
          vim.keymap.set("n", "<leader>cA", crates.upgrade_all_crates, opts("Crates: upgrade all"))
        end
      '';
    }
  ];
}
