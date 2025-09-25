import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  // Properties that match the facade interface
  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1

  // Signals that match the facade interface
  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged

  // Sway-specific properties
  property bool initialized: false
  property var workspaceCache: ({})

  // Sway IPC process for getting workspace info
  property var swayProcess: null

  // Debounce timer for updates
  Timer {
    id: updateTimer
    interval: 50
    repeat: false
    onTriggered: doUpdateWorkspaces()
  }

  // Periodic update timer for Sway (fast polling for responsiveness)
  Timer {
    id: periodicTimer
    interval: 100
    repeat: true
    running: initialized
    onTriggered: updateWorkspaces()
  }



  // Process for getting workspace information
  Process {
    id: workspaceProcess
    command: ["swaymsg", "-t", "get_workspaces"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var workspaceData = JSON.parse(text)
          updateWorkspaceModel(workspaceData)
        } catch (e) {
          Logger.error("SwayService", "Failed to parse workspace JSON:", e)
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.length > 0) {
          Logger.error("SwayService", "swaymsg stderr:", text)
        }
      }
    }
  }

  // Process for switching workspaces
  Process {
    id: switchWorkspaceProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.length > 0) {
          Logger.error("SwayService", "Workspace switch failed:", text)
        }
      }
    }
  }

  // Process for logout
  Process {
    id: logoutProcess
    command: ["swaymsg", "exit"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.length > 0) {
          Logger.error("SwayService", "Logout failed:", text)
        }
      }
    }
  }

  // Initialization
  function initialize() {
    if (initialized)
      return

    try {
      updateWorkspaces()
      initialized = true
      Logger.log("SwayService", "Initialized successfully")
    } catch (e) {
      Logger.error("SwayService", "Failed to initialize:", e)
    }
  }

  function updateWorkspaces() {
    // Debounced update - restart timer to avoid too many rapid calls
    updateTimer.restart()
  }

  function doUpdateWorkspaces() {
    if (!initialized && root.parent) {
      // Only initialize if we have a parent (are loaded)
      return
    }

    // Use swaymsg to get workspace information
    workspaceProcess.running = true
  }

  function updateWorkspaceModel(workspaceData) {
    var hasChanges = false
    var newWorkspaces = []

    // Process workspace data from Sway
    for (var i = 0; i < workspaceData.length; i++) {
      var ws = workspaceData[i]
      
      var workspaceObj = {
        id: ws.num,
        idx: ws.num,
        name: ws.name,
        isFocused: ws.focused || false,
        isOccupied: ws.windows > 0,
        isVisible: ws.visible || false,
        output: ws.output || "",
        windows: ws.windows || 0
      }
      
      newWorkspaces.push(workspaceObj)
    }

    // Check if workspaces changed
    if (workspaces.count !== newWorkspaces.length) {
      hasChanges = true
    } else {
      for (var j = 0; j < newWorkspaces.length; j++) {
        var existing = workspaces.get(j)
        var newWs = newWorkspaces[j]
        if (!existing || 
            existing.id !== newWs.id ||
            existing.isFocused !== newWs.isFocused ||
            existing.isOccupied !== newWs.isOccupied ||
            existing.output !== newWs.output) {
          hasChanges = true
          break
        }
      }
    }

    if (hasChanges) {
      workspaces.clear()
      for (var k = 0; k < newWorkspaces.length; k++) {
        workspaces.append(newWorkspaces[k])
      }
      workspaceChanged()
    }
  }

  // Functions for workspace switching
  function switchToWorkspace(workspaceId) {
    switchWorkspaceProcess.command = ["swaymsg", "workspace", workspaceId.toString()]
    switchWorkspaceProcess.running = true
    // Trigger immediate update after switching
    Qt.callLater(() => {
      updateWorkspaces()
    })
  }

  // Logout function
  function logout() {
    logoutProcess.running = true
  }

  Component.onCompleted: {
    if (parent) {
      initialize()
    }
  }
}