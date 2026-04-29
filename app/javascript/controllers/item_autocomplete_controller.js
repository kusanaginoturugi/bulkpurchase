import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "menu", "itemId", "itemCode", "itemName", "variantName", "unit"]

  syncQuery() {
    const query = this.queryTarget.value.trim()
    const originalValue = this.queryTarget.dataset.originalValue || ""

    if (query === "") {
      this.clearItemFields()
      this.hideMenu()
      return
    }

    if (query === originalValue) return

    this.itemIdTarget.value = ""
    this.itemCodeTarget.value = ""
    this.itemNameTarget.value = query
    this.unitTarget.value = ""
    this.updateVariantPlaceholder(query)
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

    const exactItem = items.find((item) => item.name === this.queryTarget.value.trim() || item.code === this.queryTarget.value.trim())
    if (exactItem) this.applyItem(exactItem, { updateQuery: false })

    this.menuTarget.innerHTML = items.map((item) => {
      const payload = JSON.stringify(item).replaceAll("\"", "&quot;")
      return `<button type="button" data-payload="${payload}" class="block w-full whitespace-nowrap border-b border-stone-100 px-3 py-2 text-left text-sm text-stone-700 hover:bg-stone-50" data-action="click->item-autocomplete#select">${item.code} ${item.name}</button>`
    }).join("")

    this.menuTarget.classList.remove("hidden")
  }

  select(event) {
    const item = JSON.parse(event.currentTarget.dataset.payload)

    this.applyItem(item)
    this.hideMenu()
  }

  applyItem(item, options = {}) {
    const updateQuery = options.updateQuery ?? true

    this.itemIdTarget.value = item.id
    this.itemCodeTarget.value = item.code
    this.itemNameTarget.value = item.name
    if (updateQuery) this.queryTarget.value = `${item.code} ${item.name}`
    this.unitTarget.value = item.unit || ""
    this.updateVariantPlaceholder(item.name)
  }

  updateVariantPlaceholder(query) {
    if (query.includes("白陽八卦符")) {
      this.variantNameTarget.placeholder = "無地/ヒルコ供養等"
    } else if (query.includes("おかげ符")) {
      this.variantNameTarget.placeholder = "具体名を入力"
    } else {
      this.variantNameTarget.placeholder = ""
    }
  }

  clearItemFields() {
    this.itemIdTarget.value = ""
    this.itemCodeTarget.value = ""
    this.itemNameTarget.value = ""
    this.variantNameTarget.value = ""
    this.variantNameTarget.placeholder = ""
    this.unitTarget.value = ""
  }

  hideMenu() {
    this.menuTarget.innerHTML = ""
    this.menuTarget.classList.add("hidden")
  }
}
