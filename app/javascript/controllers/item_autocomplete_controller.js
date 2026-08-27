import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "menu", "itemId", "itemCode", "itemName", "variantName", "variantSelect", "unit"]

  connect() {
    if (this.variantNameTarget.value.trim() === "") {
      this.updateVariantPlaceholder(this.queryTarget.value.trim())
    }
    this.updateVariantControl(this.queryTarget.value.trim())
  }

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
    this.variantNameTarget.value = ""
    this.unitTarget.value = ""
    this.updateVariantPlaceholder(query)
    this.updateVariantControl(query)
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
        credentials: "same-origin",
        headers: { Accept: "application/json" }
      })
        .then((response) => (response.ok ? response.json() : []))
        .then((items) => this.renderMenu(items))
        .catch(() => this.hideMenu())
    }, 200)
  }

  renderMenu(items) {
    if (items.length === 0) {
      this.hideMenu()
      return
    }

    const query = this.queryTarget.value.trim()
    const exactItem = items.find((item) => item.name === query || item.code === query || (this.isSoKunQuery(query) && item.code === "210001"))
    if (exactItem) this.applyItem(exactItem, { updateQuery: false })

    this.menuTarget.innerHTML = items.map((item) => {
      const payload = JSON.stringify(item).replaceAll("\"", "&quot;")
      return `<button type="button" data-payload="${payload}" class="block w-full whitespace-nowrap border-b border-stone-100 px-3 py-2 text-left text-sm text-stone-700 hover:bg-stone-50" data-action="click->item-autocomplete#select">${item.code} ${item.name}</button>`
    }).join("")

    this.positionMenu()
    this.menuTarget.classList.remove("hidden")
  }

  select(event) {
    const item = JSON.parse(event.currentTarget.dataset.payload)

    this.applyItem(item)
    this.hideMenu()
  }

  applyItem(item, options = {}) {
    const updateQuery = options.updateQuery ?? true
    const previousItemId = this.itemIdTarget.value

    this.itemIdTarget.value = item.id
    this.itemCodeTarget.value = item.code
    this.itemNameTarget.value = item.name
    if (previousItemId !== "" && previousItemId !== String(item.id)) this.variantNameTarget.value = ""
    if (updateQuery) this.queryTarget.value = item.name
    this.unitTarget.value = item.unit || ""
    this.updateVariantPlaceholder(item)
    this.updateVariantControl(item)
  }

  updateVariantPlaceholder(itemOrQuery) {
    const query = typeof itemOrQuery === "string" ? itemOrQuery : itemOrQuery.name

    if (query.includes("白陽八卦符")) {
      this.variantNameTarget.placeholder = "無地・ヒルコ供養等"
    } else if (query.includes("如意棒") || query.includes("三會龍華之御柱")) {
      this.variantNameTarget.placeholder = "通常・祈願会"
    } else {
      this.variantNameTarget.placeholder = ""
    }
  }

  syncVariantSelect() {
    this.variantNameTarget.value = this.variantSelectTarget.value
  }

  updateVariantControl(itemOrQuery) {
    const code = typeof itemOrQuery === "string" ? this.itemCodeTarget.value : itemOrQuery.code
    const query = typeof itemOrQuery === "string" ? itemOrQuery : itemOrQuery.name
    const options = this.variantOptionsFor(code, query)

    if (options.length === 0) {
      this.variantSelectTarget.classList.add("hidden")
      this.variantSelectTarget.value = ""
      this.variantNameTarget.classList.remove("hidden")
      return
    }

    this.variantSelectTarget.innerHTML = [
      "<option value=\"\">選択してください</option>",
      ...options.map((option) => `<option value="${option}">${option}</option>`)
    ].join("")
    this.variantSelectTarget.value = options.includes(this.variantNameTarget.value) ? this.variantNameTarget.value : ""
    this.variantNameTarget.classList.add("hidden")
    this.variantSelectTarget.classList.remove("hidden")
  }

  variantOptionsFor(code, query) {
    if (code === "210001" || this.isSoKunQuery(query)) {
      return ["貪狼星", "巨文星", "禄存星", "文曲星", "廉貞星", "武曲星", "破軍星"]
    }

    if (code === "205002" || query.includes("四神獣符")) {
      return ["玄武", "青龍", "白虎", "朱雀"]
    }

    return []
  }

  isSoKunQuery(query) {
    const normalized = query.replaceAll("竈", "灶")

    return [
      "灶君護摩符",
      "そう君護摩符",
      "灶君北斗七星護摩符",
      "そう君北斗七星護摩符"
    ].some((name) => normalized.includes(name))
  }

  clearItemFields() {
    this.itemIdTarget.value = ""
    this.itemCodeTarget.value = ""
    this.itemNameTarget.value = ""
    this.variantNameTarget.value = ""
    this.variantNameTarget.placeholder = ""
    this.variantNameTarget.classList.remove("hidden")
    this.variantSelectTarget.classList.add("hidden")
    this.variantSelectTarget.value = ""
    this.unitTarget.value = ""
  }

  hideMenu() {
    this.menuTarget.innerHTML = ""
    this.menuTarget.classList.add("hidden")
    this.menuTarget.removeAttribute("style")
  }

  positionMenu() {
    const rect = this.queryTarget.getBoundingClientRect()

    this.menuTarget.style.position = "fixed"
    this.menuTarget.style.left = `${rect.left}px`
    this.menuTarget.style.top = `${rect.bottom + 4}px`
    this.menuTarget.style.width = `${rect.width}px`
  }
}
