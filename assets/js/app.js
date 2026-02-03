// NeoExcelPPT JavaScript
// Phoenix LiveView and core functionality

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// LiveView Hooks for custom JS functionality
let Hooks = {}

// Number Input Hook - handles number formatting
Hooks.NumberInput = {
  mounted() {
    this.el.addEventListener("input", (e) => {
      // Remove non-numeric characters except decimal
      let value = e.target.value.replace(/[^0-9.]/g, "")
      e.target.value = value
    })
  }
}

// Scrubber Hook - handles timeline scrubber interactions
Hooks.Scrubber = {
  mounted() {
    this.el.addEventListener("input", (e) => {
      this.pushEvent("goto_position", {position: e.target.value})
    })
  }
}

// Auto-resize textarea
Hooks.AutoResize = {
  mounted() {
    this.resize()
    this.el.addEventListener("input", () => this.resize())
  },
  resize() {
    this.el.style.height = "auto"
    this.el.style.height = this.el.scrollHeight + "px"
  }
}

// Copy to clipboard
Hooks.Copy = {
  mounted() {
    this.el.addEventListener("click", () => {
      let text = this.el.dataset.copy
      navigator.clipboard.writeText(text).then(() => {
        this.pushEvent("copied", {})
      })
    })
  }
}

// LiveSvelte Hook - renders Svelte components or shows placeholder
// To enable full Svelte support: cd assets && npm install && npm run build
Hooks.LiveSvelte = {
  mounted() {
    const component = this.el.dataset.component
    const props = JSON.parse(this.el.dataset.props || "{}")

    // Show placeholder with component info
    this.el.innerHTML = `
      <div class="flex flex-col h-full bg-gradient-to-br from-slate-50 to-slate-100 border border-slate-200 rounded-lg overflow-hidden">
        <div class="bg-slate-800 text-white px-4 py-2 flex items-center justify-between">
          <span class="font-semibold">${component}</span>
          <span class="text-xs bg-slate-600 px-2 py-1 rounded">Svelte Component</span>
        </div>
        <div class="flex-1 p-4 overflow-auto">
          <div class="mb-4">
            <p class="text-slate-600 text-sm">
              To enable interactive Svelte components, run:
            </p>
            <code class="block mt-2 bg-slate-800 text-green-400 p-3 rounded text-xs font-mono">
              cd assets && npm install && npm run build
            </code>
          </div>
          <div class="border-t border-slate-200 pt-4">
            <p class="text-xs text-slate-500 mb-2">Component Props:</p>
            <pre class="text-xs bg-white p-3 rounded border border-slate-200 overflow-auto max-h-48">${JSON.stringify(props, null, 2)}</pre>
          </div>
        </div>
      </div>
    `
  },
  updated() {
    // Re-render on update
    this.mounted()
  }
}

// LiveSocket configuration
let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve focus on input elements during updates
      if (from._liveViewHook && from === document.activeElement) {
        let value = from.value
        let selStart = from.selectionStart
        let selEnd = from.selectionEnd

        requestAnimationFrame(() => {
          to.value = value
          to.setSelectionRange(selStart, selEnd)
          to.focus()
        })
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#3b82f6"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Connect LiveSocket
liveSocket.connect()

// Expose liveSocket for debugging
window.liveSocket = liveSocket

// Custom event handlers
window.addEventListener("phx:skill-updated", (e) => {
  console.log("Skill updated:", e.detail)
})

window.addEventListener("phx:timeline-event", (e) => {
  console.log("Timeline event:", e.detail)
})

// Format numbers with commas
window.formatNumber = (num) => {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

// Debounce function for input handlers
window.debounce = (func, wait) => {
  let timeout
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout)
      func(...args)
    }
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
  }
}
