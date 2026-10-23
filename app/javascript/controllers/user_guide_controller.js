import { Controller } from "@hotwired/stimulus"

// Search chapter titles, task steps and results without server requests.
export default class extends Controller {
  static targets = ["search", "section", "topic", "navSection", "navItem", "empty"]

  filter() {
    const term = this.normalize(this.searchTarget.value)
    let visible = 0
    const matchedIds = new Set()

    this.topicTargets.forEach((topic) => {
      const heading = topic.closest("section")?.querySelector("h2")?.textContent || ""
      const matches = !term || this.normalize(heading + " " + topic.textContent).includes(term)
      topic.classList.toggle("hidden", !matches)
      if (matches) {
        visible += 1
        matchedIds.add(topic.dataset.topicId)
        if (term) topic.querySelector("details").open = true
      }
    })

    this.sectionTargets.forEach((section) => {
      section.classList.toggle("hidden", !section.querySelector('[data-user-guide-target="topic"]:not(.hidden)'))
    })

    this.navItemTargets.forEach((item) => {
      item.classList.toggle("hidden", !matchedIds.has(item.dataset.topicId))
    })
    this.navSectionTargets.forEach((section) => {
      section.classList.toggle("hidden", !section.querySelector('[data-user-guide-target="navItem"]:not(.hidden)'))
    })
    this.emptyTarget.classList.toggle("hidden", visible > 0)
  }

  jump(event) {
    const id = event.currentTarget.getAttribute("href")?.slice(1)
    const topic = this.topicTargets.find((element) => element.id === id)
    if (topic) topic.querySelector("details").open = true
  }

  normalize(value) {
    return value.toLocaleLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  }
}
