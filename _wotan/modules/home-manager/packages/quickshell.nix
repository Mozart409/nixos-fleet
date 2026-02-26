{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.desktop.quickshell;
in {
  options.desktop.quickshell = {
    enable = lib.mkEnableOption "quickshell custom widgets";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Main shell entry point
    xdg.configFile."quickshell/shell.qml".text = ''
      import Quickshell

      ShellRoot {
        Bar {}
      }
    '';

    # Bar component with panels on all screens
    xdg.configFile."quickshell/Bar.qml".text = ''
      import Quickshell
      import Quickshell.Hyprland
      import QtQuick
      import QtQuick.Layouts

      Scope {
        id: root

        // Time singleton for clock
        SystemClock { id: clock }

        Variants {
          model: Quickshell.screens

          PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            anchors {
              top: true
              left: true
              right: true
            }

            implicitHeight: 32
            color: "#1a1a1fdd"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 8

              // Left: Workspaces
              WorkspaceWidget {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
              }

              // Spacer
              Item { Layout.fillWidth: true }

              // Center: Clock
              ClockWidget {
                Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
                time: clock
              }

              // Spacer
              Item { Layout.fillWidth: true }

              // Right: System info
              RowLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 16

                SysInfoWidget {}
              }
            }
          }
        }
      }
    '';

    # Clock widget
    xdg.configFile."quickshell/ClockWidget.qml".text = ''
      import QtQuick
      import QtQuick.Layouts

      RowLayout {
        required property var time

        Text {
          color: "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 14
          font.bold: true
          text: Qt.formatDateTime(time.date, "ddd dd MMM  HH:mm")
        }
      }
    '';

    # System clock singleton
    xdg.configFile."quickshell/SystemClock.qml".text = ''
      import QtQuick
      import Quickshell

      Scope {
        id: root
        property date date: new Date()

        Timer {
          interval: 1000
          running: true
          repeat: true
          onTriggered: root.date = new Date()
        }
      }
    '';

    # Workspace widget using Hyprland IPC
    xdg.configFile."quickshell/WorkspaceWidget.qml".text = ''
      import QtQuick
      import QtQuick.Layouts
      import Quickshell
      import Quickshell.Hyprland

      RowLayout {
        spacing: 4

        Repeater {
          // Show workspaces 1-9
          model: 9

          Rectangle {
            id: wsButton
            required property int index

            property int wsId: index + 1
            property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === wsId
            property bool hasWindows: {
              for (let ws of Hyprland.workspaces) {
                if (ws.id === wsId && ws.windows > 0) return true
              }
              return false
            }

            width: 24
            height: 24
            radius: 6
            color: isActive ? "#33ccff" : (hasWindows ? "#2a2a2f" : "transparent")
            border.width: hasWindows && !isActive ? 1 : 0
            border.color: "#595959"

            Text {
              anchors.centerIn: parent
              text: wsButton.wsId
              color: wsButton.isActive ? "#1a1a1f" : "#cfd6f4"
              font.family: "FiraCode Nerd Font"
              font.pixelSize: 12
              font.bold: wsButton.isActive
            }

            MouseArea {
              anchors.fill: parent
              onClicked: Hyprland.dispatch("workspace " + wsButton.wsId)
            }
          }
        }
      }
    '';

    # System info widget (CPU, RAM)
    xdg.configFile."quickshell/SysInfoWidget.qml".text = ''
      import QtQuick
      import QtQuick.Layouts
      import Quickshell
      import Quickshell.Io

      RowLayout {
        spacing: 12

        // CPU usage
        Text {
          id: cpuText
          color: "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 13
          text: " ---%"

          Process {
            id: cpuProc
            command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}'"]
            running: true

            stdout: StdioCollector {
              onStreamFinished: {
                let val = parseFloat(this.text.trim())
                cpuText.text = " " + val.toFixed(0) + "%"
              }
            }
          }

          Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: cpuProc.running = true
          }
        }

        // RAM usage
        Text {
          id: ramText
          color: "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 13
          text: " ---%"

          Process {
            id: ramProc
            command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"]
            running: true

            stdout: StdioCollector {
              onStreamFinished: {
                ramText.text = " " + this.text.trim() + "%"
              }
            }
          }

          Timer {
            interval: 5000
            running: true
            repeat: true
            onTriggered: ramProc.running = true
          }
        }
      }
    '';

    # Systemd service for Quickshell
    systemd.user.services.quickshell = {
      Unit = {
        Description = "Quickshell custom widgets";
        PartOf = ["hyprland-session.target"];
        After = ["hyprland-session.target"];
      };

      Service = {
        ExecStart = "${inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/quickshell";
        Restart = "on-failure";
        RestartSec = 3;
        Environment = [
          "QT_QPA_PLATFORM=wayland"
          "PATH=${lib.makeBinPath (with pkgs; [
            bash
            coreutils
            gawk
            gnugrep
            procps
          ])}:/run/current-system/sw/bin:${config.home.profileDirectory}/bin"
        ];
      };

      Install = {
        WantedBy = ["hyprland-session.target"];
      };
    };
  };
}
