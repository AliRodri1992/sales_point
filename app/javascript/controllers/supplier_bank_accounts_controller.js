import { Controller } from "@hotwired/stimulus"

// Filter active supplier bank accounts using only public display values.
// Encrypted account numbers and CLABEs are never sent to the browser.
export default class extends Controller {
  static targets = ["card", "search", "currency", "emptyFiltered", "pagination",
                    "range", "page", "previous", "next"]
  static values = { perPage: { type: Number, default: 8 } }

  connect() {
    this.currentPage = 1
    this.update()
  }

  filter() {
    this.currentPage = 1
    this.update()
  }

  previous() {
    if (this.currentPage <= 1) return

    this.currentPage -= 1
    this.update()
  }

  next() {
    const total = this.matchingCards().length
    if (this.currentPage >= Math.ceil(total / this.perPageValue)) return

    this.currentPage += 1
    this.update()
  }

  matchingCards() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    const currency = this.currencyTarget.value

    return this.cardTargets.filter((card) => {
      return (!query || card.dataset.search?.includes(query)) &&
        (!currency || card.dataset.currency === currency)
    })
  }

  update() {
    // The fallback without JavaScript displays every authorized active account.
    if (!this.hasCardTarget) return

    const matches = this.matchingCards()
    const total = matches.length
    const pages = Math.max(1, Math.ceil(total / this.perPageValue))
    this.currentPage = Math.min(this.currentPage, pages)
    const first = (this.currentPage - 1) * this.perPageValue
    const visibleCards = new Set(matches.slice(first, first + this.perPageValue))

    this.cardTargets.forEach((card) => card.classList.toggle("hidden", !visibleCards.has(card)))
    this.emptyFilteredTarget.classList.toggle("hidden", total > 0)
    this.paginationTarget.classList.remove("hidden")
    this.pageTarget.textContent = String(this.currentPage)
    this.previousTarget.disabled = this.currentPage === 1
    this.nextTarget.disabled = this.currentPage >= pages

    const values = {
      from: total ? first + 1 : 0,
      to: Math.min(first + this.perPageValue, total),
      total
    }
    this.rangeTarget.textContent = this.rangeTarget.dataset.rangeTemplate.replace(
      /\{(from|to|total)\}/g, (_, key) => String(values[key])
    )
  }
}
