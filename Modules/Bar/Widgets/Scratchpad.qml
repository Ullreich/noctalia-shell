import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets
import qs.Modules.Bar.Extras

Item {
  id: root

  property ShellScreen screen
  property real scaling: 1.0

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId]
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0) {
      var widgets = Settings.data.bar.widgets[section]
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex]
      }
    }
    return {}
  }

  // Hide widget when no scratchpads are open
  visible: ScratchpadService.scratchpadCount > 0
  
  implicitWidth: visible ? pill.width : 0
  implicitHeight: visible ? pill.height : 0

  BarPill {
    id: pill
    
    anchors.verticalCenter: parent.verticalCenter
    compact: (Settings.data.bar.density === "compact")
    rightOpen: BarService.getPillDirection(root)
    icon: "window-restore"
    autoHide: false
    text: ScratchpadService.scratchpadCount.toString()
    
    onClicked: {
      ScratchpadService.showScratchpads()
    }
    
    tooltipText: {
      if (ScratchpadService.scratchpadCount === 1) {
        return "1 scratchpad window - click to show"
      } else {
        return ScratchpadService.scratchpadCount + " scratchpad windows - click to show"
      }
    }
  }
  
  // Scale animation for count changes
  SequentialAnimation {
    id: countChangeAnimation
    PropertyAnimation {
      target: pill
      property: "scale"
      from: 1.0
      to: 1.1
      duration: Style.animationFast
      easing.type: Easing.OutBack
    }
    PropertyAnimation {
      target: pill
      property: "scale"
      to: 1.0
      duration: Style.animationFast
      easing.type: Easing.OutQuad
    }
  }
  
  Connections {
    target: ScratchpadService
    function onScratchpadCountChanged() {
      if (ScratchpadService.scratchpadCount > 0) {
        countChangeAnimation.start()
      }
    }
  }

  Component.onCompleted: {
    console.log("Scratchpad widget created")
    console.log("ScratchpadService.scratchpadCount:", ScratchpadService.scratchpadCount)
  }
}