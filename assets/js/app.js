// NeoExcelPPT - Phoenix LiveView JavaScript

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// LiveView Hooks for custom JavaScript interactions
let Hooks = {}

// Hook for numeric input formatting
Hooks.NumberInput = {
  mounted() {
    this.el.addEventListener("blur", (e) => {
      const value = parseFloat(e.target.value) || 0
      e.target.value = value.toLocaleString()
    })
  }
}

// Hook for skill graph visualization
Hooks.SkillGraph = {
  mounted() {
    this.renderGraph()
  },
  updated() {
    this.renderGraph()
  },
  renderGraph() {
    // Could integrate with D3.js or similar for advanced visualization
    console.log("Skill graph rendered")
  }
}

// Hook for timeline scrubber
Hooks.TimelineScrubber = {
  mounted() {
    this.el.addEventListener("input", (e) => {
      const position = parseInt(e.target.value)
      this.pushEvent("go_to_position", {index: position})
    })
  }
}

// Hook for keyboard shortcuts
Hooks.KeyboardShortcuts = {
  mounted() {
    this.handleKeyDown = (e) => {
      // Left arrow - step backward
      if (e.key === "ArrowLeft" && e.ctrlKey) {
        this.pushEvent("step_backward", {})
      }
      // Right arrow - step forward
      if (e.key === "ArrowRight" && e.ctrlKey) {
        this.pushEvent("step_forward", {})
      }
      // Home - go to start
      if (e.key === "Home" && e.ctrlKey) {
        this.pushEvent("go_to_start", {})
      }
      // End - go to end
      if (e.key === "End" && e.ctrlKey) {
        this.pushEvent("go_to_end", {})
      }
    }
    window.addEventListener("keydown", this.handleKeyDown)
  },
  destroyed() {
    window.removeEventListener("keydown", this.handleKeyDown)
  }
}

// Hook for auto-saving form changes
Hooks.AutoSave = {
  mounted() {
    this.timeout = null
    this.el.addEventListener("input", (e) => {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        this.pushEvent("auto_save", {
          field: e.target.name,
          value: e.target.value
        })
      }, 500)
    })
  }
}

// Hook for notification sounds
Hooks.NotificationSound = {
  mounted() {
    this.handleEvent("play_notification", ({type}) => {
      // Could play different sounds based on type
      console.log("Notification:", type)
    })
  }
}

// CSRF token for Phoenix
let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

// LiveSocket configuration
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve focus during LiveView updates
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#3b82f6"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Connect the LiveSocket
liveSocket.connect()

// Expose liveSocket for debugging
window.liveSocket = liveSocket

// Custom event handlers
window.addEventListener("phx:skill_updated", (e) => {
  console.log("Skill updated:", e.detail)
})

window.addEventListener("phx:event_recorded", (e) => {
  console.log("Event recorded:", e.detail)
})

// Export for use in other modules
export {liveSocket, Hooks}
