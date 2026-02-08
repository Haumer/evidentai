// app/javascript/controllers/artifact_sheets_controller.js

import { Controller } from "@hotwired/stimulus"

// Google Sheets-ish bottom bar + expandable drawer.
// No iframe interaction; purely app chrome UI.
export default class extends Controller {
  static targets = ["drawer", "toggle", "tab", "sheet", "drawerTitle"]

  connect() {
    this.open = false
  }

  toggle() {
    this.open ? this.close() : this.openDrawer()
  }

  openDrawer() {
    this.open = true
    this.drawerTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.element.classList.add("is-open")
  }

  close() {
    this.open = false
    this.drawerTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.element.classList.remove("is-open")
  }

  select(e) {
    const idx = String(e.currentTarget.dataset.index)

    // Tabs
    this.tabTargets.forEach((t) => {
      const active = String(t.dataset.index) === idx
      t.classList.toggle("is-active", active)
      t.setAttribute("aria-selected", active ? "true" : "false")
    })

    // Sheets
    this.sheetTargets.forEach((s) => {
      const active = String(s.dataset.index) === idx
      s.hidden = !active
      s.classList.toggle("is-active", active)
    })

    // Title
    const label = e.currentTarget.textContent?.trim()
    if (label && this.hasDrawerTitleTarget) this.drawerTitleTarget.textContent = label

    // Open drawer if user clicks a tab while closed (nice UX)
    if (!this.open) this.openDrawer()
  }
}
