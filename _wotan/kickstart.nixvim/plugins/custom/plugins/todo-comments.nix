{pkgs, ...}: {
  programs.nixvim.plugins.todo-comments = {
    enable = true;

    # Show icons in signs column
    signs = true;
    signPriority = 8;

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

    # Keymaps for jumping between todos
    keymaps = {
      todoNext = {
        key = "]t";
        desc = "Next todo comment";
      };
      todoPrev = {
        key = "[t";
        desc = "Previous todo comment";
      };
    };
  };
}
