import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    const content = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", Date.now().toString())
    const row = event?.currentTarget.closest("[data-controller='item-autocomplete']")

    if (row) {
      row.insertAdjacentHTML("afterend", content)
      row.nextElementSibling?.querySelector("[data-item-autocomplete-target~='query']")?.focus()
    } else {
      this.containerTarget.insertAdjacentHTML("beforeend", content)
      this.containerTarget.lastElementChild?.querySelector("[data-item-autocomplete-target~='query']")?.focus()
    }

    this.reindex()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-controller='item-autocomplete']")
    const idField = row.querySelector("input[name$='[id]']")
    const destroyField = row.querySelector("input[name*='[_destroy]']")

    if (idField && idField.value.length > 0 && destroyField) {
      destroyField.value = "1"
      row.classList.add("hidden")
      row.hidden = true
    } else {
      row.remove()
    }

    this.reindex()
  }

  reindex() {
    this.containerTarget.querySelectorAll("[data-controller='item-autocomplete']:not([hidden])").forEach((row, index) => {
      const input = row.querySelector("input[name*='[sort_order]']")
      if (input) input.value = index
    })
  }
}
