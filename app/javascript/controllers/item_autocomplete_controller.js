import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "menu", "itemId", "itemCode", "itemName", "variantName", "unit"]

  syncQuery() {
    const query = this.queryTarget.value.trim()
    const originalValue = this.queryTarget.dataset.originalValue || ""

    if (query === originalValue) return

    this.itemIdTarget.value = ""
    this.itemCodeTarget.value = ""
    this.itemNameTarget.value = query
  }

  search() {
    clearTimeout(this.timeout)

    const query = this.queryTarget.value.trim()
    if (query.length < 2) {
      this.hideMenu()
      return
    }

    this.timeout = setTimeout(() => {
      fetch(`/items/search?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" }
      })
        .then((response) => response.json())
        .then((items) => this.renderMenu(items))
        .catch(() => this.hideMenu())
    }, 200)
  }

  renderMenu(items) {
    if (items.length === 0) {
      this.hideMenu()
      return
    }

    this.menuTarget.innerHTML = items.map((item) => {
      const payload = JSON.stringify(item).replaceAll("\"", "&quot;")
      return `<button type="button" data-payload="${payload}" class="block w-full border-b border-stone-100 px-3 py-2 text-left text-sm text-stone-700 hover:bg-stone-50" data-action="click->item-autocomplete#select">${item.code} ${item.name}</button>`
    }).join("")

    this.menuTarget.classList.remove("hidden")
  }

  select(event) {
    const item = JSON.parse(event.currentTarget.dataset.payload)

    this.itemIdTarget.value = item.id
    this.itemCodeTarget.value = item.code
    this.itemNameTarget.value = item.name
    this.queryTarget.value = `${item.code} ${item.name}`
    this.unitTarget.value = item.unit || ""

    if (item.special_handling_type === "hakuyo_hakke") {
      this.variantNameTarget.classList.remove("hidden")
      if (!this.variantNameTarget.value && item.variants.length > 0) {
        this.variantNameTarget.placeholder = item.variants.map((variant) => variant.name).join(" / ")
      }
    } else {
      this.variantNameTarget.value = ""
      this.variantNameTarget.classList.add("hidden")
    }

    this.hideMenu()
  }

  hideMenu() {
    this.menuTarget.innerHTML = ""
    this.menuTarget.classList.add("hidden")
  }
}
