import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]
  static values = {
    prefix: String,
    startedAt: String
  }

  connect() {
    this.startMs = this.resolveStartMs()
    if (!this.startMs) return

    this.tick = this.tick.bind(this)
    this.tick()
    this.timer = window.setInterval(this.tick, 1000)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }

  tick() {
    if (!this.startMs) return

    const seconds = Math.max(1, Math.floor((Date.now() - this.startMs) / 1000) + 1)
    const prefix = this.prefixValue.toString().trim()
    const text = prefix ? `${prefix} ${this.formatElapsed(seconds)}` : this.formatElapsed(seconds)

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = text
    } else {
      this.element.textContent = text
    }
  }

  resolveStartMs() {
    if (!this.hasStartedAtValue) return null

    const raw = this.startedAtValue.toString().trim()
    if (raw.length === 0) return null

    const asNumber = Number(raw)
    if (!Number.isNaN(asNumber) && Number.isFinite(asNumber) && asNumber > 0) {
      return asNumber > 1_000_000_000_000 ? asNumber : asNumber * 1000
    }

    const parsed = Date.parse(raw)
    if (!Number.isNaN(parsed)) return parsed

    return null
  }

  formatElapsed(seconds) {
    if (seconds < 60) return `${seconds}s`

    const minutes = Math.floor(seconds / 60)
    const remSeconds = seconds % 60
    if (minutes < 60) return `${minutes}m ${remSeconds}s`

    const hours = Math.floor(minutes / 60)
    const remMinutes = minutes % 60
    return `${hours}h ${remMinutes}m`
  }
}
