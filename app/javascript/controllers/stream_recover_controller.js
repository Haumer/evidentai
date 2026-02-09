import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Recovers missed Turbo stream updates after tab inactivity.
// Some browsers can suspend websocket delivery while backgrounded; this
// forces a lightweight page re-sync when the user returns.
export default class extends Controller {
  static values = { chatId: Number }

  connect() {
    this.reloading = false
    this.wasHidden = document.hidden

    this._onVisibilityChange = () => this.onVisibilityChange()
    this._onFocus = () => this.onFocus()
    this._onPageShow = (event) => this.onPageShow(event)

    document.addEventListener("visibilitychange", this._onVisibilityChange)
    window.addEventListener("focus", this._onFocus)
    window.addEventListener("pageshow", this._onPageShow)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this._onVisibilityChange)
    window.removeEventListener("focus", this._onFocus)
    window.removeEventListener("pageshow", this._onPageShow)
  }

  onVisibilityChange() {
    if (document.hidden) {
      this.wasHidden = true
      return
    }

    if (!this.wasHidden) return
    this.wasHidden = false
    this.recoverIfNeeded()
  }

  onFocus() {
    if (document.hidden) return
    this.recoverIfNeeded()
  }

  onPageShow(event) {
    if (!event?.persisted) return
    this.recoverIfNeeded()
  }

  recoverIfNeeded() {
    if (this.reloading) return
    if (!this.pendingWindowActive() && !this.hasPotentiallyStaleRealtimeState()) return

    this.clearPendingWindow()
    this.reloading = true
    Turbo.visit(window.location.href, { action: "replace" })
  }

  hasPotentiallyStaleRealtimeState() {
    return Boolean(
      this.element.querySelector(".message-assistant.is-streaming") ||
      this.element.querySelector(".run-status--working")
    )
  }

  pendingWindowActive() {
    const expiresAt = Number(this.readPendingValue())
    return Number.isFinite(expiresAt) && expiresAt > Date.now()
  }

  clearPendingWindow() {
    try {
      sessionStorage.removeItem(this.pendingKey())
    } catch (_) {
      // no-op
    }
  }

  readPendingValue() {
    try {
      return sessionStorage.getItem(this.pendingKey())
    } catch (_) {
      return null
    }
  }

  pendingKey() {
    const chatId = this.hasChatIdValue ? String(this.chatIdValue) : "global"
    return `evidentai:chat-pending:${chatId}`
  }
}
