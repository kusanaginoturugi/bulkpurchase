import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add() {
    const content = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", Date.now().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
    this.reindex()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-controller='item-autocomplete']")
    const idField = row.querySelector("input[name*='[id]']")
    const destroyField = row.querySelector("input[name*='[_destroy]']")

    if (idField && idField.value.length > 0 && destroyField) {
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }

    this.reindex()
  }

  reindex() {
    this.containerTarget.querySelectorAll("[data-controller='item-autocomplete']").forEach((row, index) => {
      const input = row.querySelector("input[name*='[sort_order]']")
      if (input) input.value = index
    })
  }
}
