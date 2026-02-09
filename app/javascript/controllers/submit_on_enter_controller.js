import { Controller } from "@hotwired/stimulus"

// Submits the form on Enter.
// Shift+Enter inserts a newline.
// Works with Turbo (local: false) and ensures the form never gets "stuck".
// Clears the textarea and re-enables controls after Turbo completes the request.
//
// Extended behavior:
// - If the server marks the composer as "busy" (artifact regenerating),
//   do NOT allow submits and do NOT re-enable the submit button.
export default class extends Controller {
  static targets = ["input"]
  static values = { chatId: Number }

  connect() {
    this.sending = false
    this.firstSubmitTransitionChat = null

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

    // Block while this request is in-flight OR while server says we're busy
    if (this.sending) return
    if (this.isBusy()) return

    const text = (this.inputTarget.value || "").trim()
    if (text.length === 0) return

    // Submit the form (Turbo-friendly)
    this.element.requestSubmit()
  }

  onSubmitStart() {
    this.startFirstSubmitTransition()
    this.sending = true
    this.markPendingWindow()
    this.disableControls()
  }

  onSubmitEnd(e) {
    const submitSucceeded = !!e?.detail?.success
    this.finishFirstSubmitTransition({ submitSucceeded })

    // Always unlock local "sending" state, even on error
    this.sending = false

    // Re-enable controls, but keep submit disabled if server marked busy
    this.enableControls()

    // Clear input on success (HTTP 2xx)
    if (e?.detail?.success) {
      if (this.hasInputTarget) {
        this.inputTarget.value = ""
        this.inputTarget.focus()
      }
    }
  }

  // Server-driven busy flag:
  // When artifact generation is running, the composer submit button will have:
  // data-evidentai-busy="true"
  isBusy() {
    const submit = this.element.querySelector('button[type="submit"], input[type="submit"]')
    if (!submit) return false
    return submit.dataset?.evidentaiBusy === "true"
  }

  disableControls() {
    // Keep it minimal: disable only the submit button + textarea
    // (attachment button etc can stay disabled by your own UI state)
    this.element.querySelectorAll('textarea, button[type="submit"], input[type="submit"]').forEach((el) => {
      el.disabled = true
    })
  }

  enableControls() {
    // Always re-enable textarea
    this.element.querySelectorAll("textarea").forEach((el) => {
      el.disabled = false
    })

    // Only re-enable submit if server is NOT marking us as busy
    const busy = this.isBusy()
    this.element.querySelectorAll('button[type="submit"], input[type="submit"]').forEach((el) => {
      if (busy) return
      el.disabled = false
    })
  }

  markPendingWindow() {
    // Give recover controller a short window to auto-resync if streams are
    // missed while the tab is backgrounded.
    const expiresAt = Date.now() + (3 * 60 * 1000)

    try {
      sessionStorage.setItem(this.pendingKey(), String(expiresAt))
    } catch (_) {
      // no-op
    }
  }

  pendingKey() {
    const chatId = this.hasChatIdValue ? String(this.chatIdValue) : "global"
    return `evidentai:chat-pending:${chatId}`
  }

  startFirstSubmitTransition() {
    if (!this.hasInputTarget) return
    if ((this.inputTarget.value || "").trim().length === 0) return

    const chat = this.element.closest(".chat")
    if (!chat || !chat.classList.contains("is-empty")) return

    chat.classList.add("is-starting")
    this.firstSubmitTransitionChat = chat
  }

  finishFirstSubmitTransition({ submitSucceeded }) {
    const chat = this.firstSubmitTransitionChat
    if (!chat) return

    if (submitSucceeded) {
      chat.classList.remove("is-starting")
      chat.classList.remove("is-empty")

      const emptyState = chat.querySelector(".empty-state")
      if (emptyState) emptyState.remove()
    } else {
      chat.classList.remove("is-starting")
    }

    this.firstSubmitTransitionChat = null
  }
}
