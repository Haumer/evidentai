import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "spinner", "label"]

  connect() {
    this.beforeStreamRender = this.beforeStreamRender.bind(this)
    this.pendingUpdates = 0
    this.minUpdatingMs = 450
    this.completedMs = 900
    this.statusTimer = null
    document.addEventListener("turbo:before-stream-render", this.beforeStreamRender)
    this.setLiveStatus()
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRender)
    if (this.statusTimer) clearTimeout(this.statusTimer)
  }

  beforeStreamRender(event) {
    const stream = event.target
    if (!(stream instanceof Element)) return
    if (stream.getAttribute("target") !== "admin_ai_usage_report") return
    if (!event.detail || typeof event.detail.render !== "function") return

    this.pendingUpdates += 1
    this.setUpdatingStatus()
    const startedAt = performance.now()

    const originalRender = event.detail.render
    event.detail.render = (currentElement) => {
      originalRender(currentElement)
      this.scheduleLiveStatus(startedAt)
    }
  }

  setUpdatingStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.remove("is-complete")
      this.statusTarget.classList.remove("is-live")
      this.statusTarget.classList.add("is-updating")
    }
    if (this.hasLabelTarget) this.labelTarget.textContent = "Updating…"
  }

  setCompleteStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.remove("is-updating")
      this.statusTarget.classList.remove("is-live")
      this.statusTarget.classList.add("is-complete")
    }
    if (this.hasLabelTarget) this.labelTarget.textContent = `Updated ${this.nowLabel()}`
  }

  setLiveStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.remove("is-complete")
      this.statusTarget.classList.remove("is-updating")
      this.statusTarget.classList.add("is-live")
    }
    if (this.hasLabelTarget) this.labelTarget.textContent = `Live • Updated ${this.nowLabel()}`
  }

  scheduleLiveStatus(startedAt) {
    const elapsed = performance.now() - startedAt
    const remaining = Math.max(0, this.minUpdatingMs - elapsed)

    if (this.statusTimer) clearTimeout(this.statusTimer)

    this.statusTimer = setTimeout(() => {
      this.pendingUpdates = Math.max(0, this.pendingUpdates - 1)
      if (this.pendingUpdates !== 0) return

      this.setCompleteStatus()
      this.statusTimer = setTimeout(() => {
        if (this.pendingUpdates === 0) this.setLiveStatus()
      }, this.completedMs)
    }, remaining)
  }

  nowLabel() {
    const now = new Date()
    const hh = String(now.getHours()).padStart(2, "0")
    const mm = String(now.getMinutes()).padStart(2, "0")
    const ss = String(now.getSeconds()).padStart(2, "0")
    return `${hh}:${mm}:${ss}`
  }
}
