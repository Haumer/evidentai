import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String,
    enabled: Boolean,
    delay: { type: Number, default: 18 }
  }

  connect() {
    this.stop()

    const text = this.textValue || this.element.textContent || ""
    if (!this.enabledValue || this.prefersReducedMotion()) {
      this.element.textContent = text
      return
    }

    this.element.textContent = ""
    this.cursor = 0
    this.timer = setInterval(() => this.tick(text), this.delayValue)
  }

  disconnect() {
    this.stop()
  }

  tick(text) {
    this.cursor += 1
    this.element.textContent = text.slice(0, this.cursor)
    if (this.cursor >= text.length) this.stop()
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  prefersReducedMotion() {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
