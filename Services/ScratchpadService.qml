import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property int scratchpadCount: 0
  property var scratchpadWindows: []

  // Update timer
  Timer {
    id: updateTimer
    interval: 200
    running: true
    repeat: true
    onTriggered: updateScratchpads()
  }

  // Process to get scratchpad info
  Process {
    id: scratchpadProcess
    command: ["swaymsg", "-t", "get_tree"]

    StdioCollector {
      id: scratchpadCollector
      process: scratchpadProcess

      onStreamFinished: {
        if (scratchpadProcess.exitCode === 0) {
          parseScratchpadData(text)
        }
      }
    }
  }

  function updateScratchpads() {
    scratchpadProcess.running = true
  }

  function parseScratchpadData(jsonText) {
    try {
      const data = JSON.parse(jsonText)
      const windows = findScratchpadWindows(data)
      
      scratchpadWindows = windows
      scratchpadCount = windows.length
      
    } catch (error) {
      console.warn("ScratchpadService: Failed to parse swaymsg output:", error)
      scratchpadCount = 0
      scratchpadWindows = []
    }
  }

  function findScratchpadWindows(node) {
    let windows = []
    
    // Check if this node is the scratchpad workspace
    if (node.name === "__i3_scratch") {
      // Collect all windows in floating_nodes
      if (node.floating_nodes) {
        for (const floatingNode of node.floating_nodes) {
          const windowsInNode = collectWindows(floatingNode)
          windows = windows.concat(windowsInNode)
        }
      }
      // Also check nodes array
      if (node.nodes) {
        for (const childNode of node.nodes) {
          const windowsInNode = collectWindows(childNode)
          windows = windows.concat(windowsInNode)
        }
      }
    }
    
    // Recursively search child nodes
    if (node.nodes) {
      for (const child of node.nodes) {
        const childWindows = findScratchpadWindows(child)
        windows = windows.concat(childWindows)
      }
    }
    
    return windows
  }

  function collectWindows(node) {
    let windows = []
    
    // If this node has a window class/name, it's a window
    if (node.window && (node.app_id || node.window_properties)) {
      windows.push({
        id: node.id,
        name: node.name || "Unknown",
        app_id: node.app_id || node.window_properties?.class || "Unknown"
      })
    }
    
    // Recursively collect from child nodes
    if (node.nodes) {
      for (const child of node.nodes) {
        const childWindows = collectWindows(child)
        windows = windows.concat(childWindows)
      }
    }
    
    // Also check floating nodes
    if (node.floating_nodes) {
      for (const floatingNode of node.floating_nodes) {
        const childWindows = collectWindows(floatingNode)
        windows = windows.concat(childWindows)
      }
    }
    
    return windows
  }

  function showScratchpads() {
    if (scratchpadCount > 0) {
      // Show all scratchpad windows
      const process = Qt.createQmlObject('
        import Quickshell.Io
        Process {
          command: ["swaymsg", "scratchpad", "show"]
        }
      ', root)
      process.running = true
    }
  }
}