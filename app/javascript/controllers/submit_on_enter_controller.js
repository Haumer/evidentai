import { Controller } from "@hotwired/stimulus"

// Submits the form on Enter.
// Shift+Enter inserts a newline.
// Works with Turbo (local: false) and ensures the form never gets "stuck".
// Clears the textarea and re-enables controls after Turbo completes the request.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.sending = false

    this._onKeydown = (e) => this.keydown(e)
    this._onSubmitStart = () => this.onSubmitStart()
    this._onSubmitEnd = (e) => this.onSubmitEnd(e)

    // Listen on the form element (this.element is the form)
    this.element.addEventListener("keydown", this._onKeydown)
    this.element.addEventListener("turbo:submit-start", this._onSubmitStart)
    this.element.addEventListener("turbo:submit-end", this._onSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this._onKeydown)
    this.element.removeEventListener("turbo:submit-start", this._onSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this._onSubmitEnd)
  }

  keydown(e) {
    // Only handle Enter in the textarea
    if (!this.hasInputTarget) return
    if (e.target !== this.inputTarget) return

    if (e.key !== "Enter") return

    // Shift+Enter => newline
    if (e.shiftKey) return

    // Enter => submit
    e.preventDefault()

    if (this.sending) return

    const text = (this.inputTarget.value || "").trim()
    if (text.length === 0) return

    // Submit the form (Turbo-friendly)
    this.element.requestSubmit()
  }

  onSubmitStart() {
    this.sending = true
    this.disableControls()
  }

  onSubmitEnd(e) {
    // Always unlock, even on error
    this.sending = false
    this.enableControls()

    // Clear input on success (HTTP 2xx)
    if (e?.detail?.success) {
      if (this.hasInputTarget) {
        this.inputTarget.value = ""
        this.inputTarget.focus()
      }
    }
  }

  disableControls() {
    // Keep it minimal: disable only the submit button + textarea
    // (attachment button etc can stay disabled by your own UI state)
    this.element.querySelectorAll('textarea, button[type="submit"], input[type="submit"]').forEach((el) => {
      el.disabled = true
    })
  }

  enableControls() {
    this.element.querySelectorAll('textarea, button[type="submit"], input[type="submit"]').forEach((el) => {
      el.disabled = false
    })
  }
}
