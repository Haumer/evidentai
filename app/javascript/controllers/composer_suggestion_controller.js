import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String
  }

  insert() {
    const textarea = document.getElementById("composer_instruction")
    if (!textarea) return

    textarea.value = this.textValue || ""
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
    textarea.focus()
    textarea.setSelectionRange(textarea.value.length, textarea.value.length)
  }
}
