import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Floating weather widget - top right corner
PanelWindow {
  id: weatherWidget

  anchors {
    top: true
    right: true
  }

  margins {
    top: 60
    right: 20
  }

  implicitWidth: 180
  implicitHeight: 100
  color: "transparent"

  // White border container
  Rectangle {
    anchors.fill: parent
    color: "#1a1a1fcc"
    radius: 8
    border.width: 1
    border.color: "#ffffff44"
  }

  // Place below normal windows (desktop widget)
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "quickshell-weather"

  // Weather data properties
  property string temperature: "--"
  property string condition: "Loading..."
  property string icon: ""
  property string location: ""

  // Weather icons mapping
  function getWeatherIcon(code) {
    // WMO Weather codes: https://open-meteo.com/en/docs
    if (code === 0) return "" // Clear
    if (code === 1 || code === 2) return "" // Partly cloudy
    if (code === 3) return "" // Overcast
    if (code >= 45 && code <= 48) return "" // Fog
    if (code >= 51 && code <= 57) return "" // Drizzle
    if (code >= 61 && code <= 67) return "" // Rain
    if (code >= 71 && code <= 77) return "" // Snow
    if (code >= 80 && code <= 82) return "" // Rain showers
    if (code >= 85 && code <= 86) return "" // Snow showers
    if (code >= 95 && code <= 99) return "" // Thunderstorm
    return ""
  }

  function getConditionText(code) {
    if (code === 0) return "Clear"
    if (code === 1) return "Mostly Clear"
    if (code === 2) return "Partly Cloudy"
    if (code === 3) return "Overcast"
    if (code >= 45 && code <= 48) return "Foggy"
    if (code >= 51 && code <= 57) return "Drizzle"
    if (code >= 61 && code <= 67) return "Rainy"
    if (code >= 71 && code <= 77) return "Snowy"
    if (code >= 80 && code <= 82) return "Showers"
    if (code >= 85 && code <= 86) return "Snow Showers"
    if (code >= 95 && code <= 99) return "Thunderstorm"
    return "Unknown"
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 12

    // Weather icon
    Text {
      text: weatherWidget.icon
      color: "#33ccff"
      font.family: "Berkeley Mono"
      font.pixelSize: 42
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      // Temperature
      Text {
        text: weatherWidget.temperature + "°C"
        color: "#cfd6f4"
        font.family: "Berkeley Mono"
        font.pixelSize: 22
        font.bold: true
      }

      // Condition
      Text {
        text: weatherWidget.condition
        color: "#a6adc8"
        font.family: "Berkeley Mono"
        font.pixelSize: 11
      }

      // Location
      Text {
        text: weatherWidget.location
        color: "#595959"
        font.family: "Berkeley Mono"
        font.pixelSize: 9
        visible: weatherWidget.location !== ""
      }
    }
  }

  // Fetch weather using Open-Meteo (free, no API key needed)
  // Default: Berlin coordinates - change to your location
  Process {
    id: weatherProc
    command: ["sh", "-c", "curl -s 'https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current=temperature_2m,weather_code&timezone=auto'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          let data = JSON.parse(this.text)
          let temp = data.current.temperature_2m
          let code = data.current.weather_code
          weatherWidget.temperature = Math.round(temp).toString()
          weatherWidget.condition = weatherWidget.getConditionText(code)
          weatherWidget.icon = weatherWidget.getWeatherIcon(code)
          weatherWidget.location = "Munich" // Change this
        } catch (e) {
          weatherWidget.condition = "Error"
          weatherWidget.icon = ""
        }
      }
    }
  }

  // Update every 30 minutes
  Timer {
    interval: 1800000
    running: true
    repeat: true
    onTriggered: weatherProc.running = true
  }
}
