import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeline"]

  connect() {
    this._onScroll = () => this.trackUserScroll()
    this.timelineTarget.addEventListener("scroll", this._onScroll)

    // Track whether user is near bottom initially
    this.userPinnedToBottom = true
    this.trackUserScroll()

    // Observe added nodes (Turbo append / replace)
    this.observer = new MutationObserver(() => this.maybeScrollToBottom())
    this.observer.observe(this.timelineTarget, { childList: true, subtree: true })

    // Initial load
    this.scrollToBottom({ smooth: false })
  }

  disconnect() {
    this.timelineTarget.removeEventListener("scroll", this._onScroll)
    if (this.observer) this.observer.disconnect()
  }

  trackUserScroll() {
    const el = this.timelineTarget
    const threshold = 120 // px from bottom counts as "at bottom"
    const distanceFromBottom = el.scrollHeight - el.scrollTop - el.clientHeight
    this.userPinnedToBottom = distanceFromBottom < threshold
  }

  maybeScrollToBottom() {
    if (this.userPinnedToBottom) this.scrollToBottom({ smooth: true })
  }

  scrollToBottom({ smooth }) {
    const el = this.timelineTarget
    el.scrollTo({ top: el.scrollHeight, behavior: smooth ? "smooth" : "auto" })
  }
}
