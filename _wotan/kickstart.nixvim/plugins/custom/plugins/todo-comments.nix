{pkgs, ...}: {
  programs.nixvim.plugins.todo-comments = {
    enable = true;

    settings = {
      # Show icons in signs column
      signs = true;
      sign_priority = 8;

      # Keywords configuration
      keywords = {
        FIX = {
          icon = " ";
          color = "error";
          alt = ["FIXME" "BUG" "FIXIT" "ISSUE"];
        };
        TODO = {
          icon = " ";
          color = "info";
        };
        HACK = {
          icon = " ";
          color = "warning";
        };
        WARN = {
          icon = " ";
          color = "warning";
          alt = ["WARNING" "XXX"];
        };
        PERF = {
          icon = " ";
          alt = ["OPTIM" "PERFORMANCE" "OPTIMIZE"];
        };
        NOTE = {
          icon = " ";
          color = "hint";
          alt = ["INFO"];
        };
        TEST = {
          icon = "⏲ ";
          color = "test";
          alt = ["TESTING" "PASSED" "FAILED"];
        };
      };
    };
  };

  # Keymaps for jumping between todos.
  # The plugin module's `keymaps` option only exposes picker actions
  # (TodoFzfLua/QuickFix/LocList/Trouble/Telescope), so jump_next/jump_prev
  # are wired up as plain Lua keymaps instead.
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "]t";
      action.__raw = "function() require('todo-comments').jump_next() end";
      options.desc = "Next todo comment";
    }
    {
      mode = "n";
      key = "[t";
      action.__raw = "function() require('todo-comments').jump_prev() end";
      options.desc = "Previous todo comment";
    }
  ];
}
