import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "collapsedNotice", "dismissButton", "restoreButton"]
  static values = {
    contextEnabled: Boolean,
    hasSuggestions: Boolean,
    toggleUrl: String,
    initiallyDismissed: Boolean
  }

  connect() {
    const canCollapse = this.contextEnabledValue && this.hasSuggestionsValue
    if (!canCollapse) return

    this.applyCollapsed(this.initiallyDismissedValue)
  }

  dismiss(event) {
    event.preventDefault()
    this.applyCollapsed(true)
    this.persist(true)
  }

  restore(event) {
    event.preventDefault()
    this.applyCollapsed(false)
    this.persist(false)
  }

  applyCollapsed(collapsed) {
    this.element.classList.toggle("is-collapsed", collapsed)

    if (this.hasContentTarget) {
      this.contentTarget.setAttribute("aria-hidden", collapsed ? "true" : "false")
    }

    if (this.hasCollapsedNoticeTarget) {
      this.collapsedNoticeTarget.setAttribute("aria-hidden", collapsed ? "false" : "true")
    }

    if (this.hasDismissButtonTarget) {
      this.dismissButtonTarget.hidden = collapsed
    }

    if (this.hasRestoreButtonTarget) {
      this.restoreButtonTarget.hidden = !collapsed
    }
  }

  persist(dismissed) {
    if (!this.hasToggleUrlValue || !this.toggleUrlValue) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const body = new URLSearchParams({ dismissed: dismissed ? "true" : "false" })

    fetch(this.toggleUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken || "",
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"
      },
      body: body.toString(),
      credentials: "same-origin"
    }).catch(() => {})
  }
}
