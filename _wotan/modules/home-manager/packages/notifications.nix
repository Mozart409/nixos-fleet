{lib, ...}: {
  options.desktop.notifications = {
    backend = lib.mkOption {
      type = lib.types.enum ["dunst" "quickshell"];
      default = "dunst";
      description = ''
        Which process owns org.freedesktop.Notifications.

        Deliberately one option rather than a pair of imports: the bus name has
        exactly one owner, so running both daemons is not a configuration with
        a meaningful outcome -- whichever loses the race simply gets no
        notifications, silently. An enum makes that unrepresentable.

        "dunst"      the mature C daemon; isolated from the shell, so a QML
                     error in quickshell costs you the bar but not your
                     notifications.
        "quickshell" the in-shell daemon (quickshell/NotificationDaemon.qml).
                     Shares Theme.qml with the bar and supports action buttons
                     and inline replies, which dunst cannot do. The trade is
                     that it dies with the shell.

        Switching either way needs a rebuild; the daemons are started and
        stopped by activation, not at runtime.
      '';
    };
  };
}
