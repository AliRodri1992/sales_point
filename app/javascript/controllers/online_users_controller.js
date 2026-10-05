import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { currentUserId: String }

    connect() {
        this.filterSelf()
        this.observer = new MutationObserver(() => this.filterSelf())
        this.observer.observe(this.element, {
            childList: true,
            subtree: true
        })
    }

    disconnect() {
        this.observer?.disconnect()
    }

    filterSelf() {
        let visibleCount = 0

        this.element
            .querySelectorAll("[data-online-user-id]")
            .forEach((el) => {
                if (el.dataset.onlineUserId === this.currentUserIdValue) {
                    el.style.display = "none"
                } else {
                    el.style.display = ""
                    visibleCount++
                }
            })

        const emptyEl = this.element.querySelector(".online-users-empty")
        if (emptyEl) {
            emptyEl.style.display = visibleCount === 0 ? "" : "none"
        }
    }
}
