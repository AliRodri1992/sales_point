import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { currentUserId: String }

    connect() {
        this.alignAll()
        this.observer = new MutationObserver(() => this.alignAll())
        this.observer.observe(this.element, {
            childList: true,
            subtree: true
        })
    }

    disconnect() {
        this.observer?.disconnect()
    }

    alignAll() {
        this.element
            .querySelectorAll("[data-message-user-id]")
            .forEach((el) => {
                const isOwn =
                    el.dataset.messageUserId === this.currentUserIdValue
                const bubble = el.querySelector(".rounded-2xl")
                if (!bubble) return

                el.classList.toggle("justify-end", isOwn)
                el.classList.toggle("justify-start", !isOwn)
                bubble.classList.toggle("bg-blue-600", isOwn)
                bubble.classList.toggle("text-white", isOwn)
                bubble.classList.toggle("bg-white", !isOwn)
                bubble.classList.toggle("text-slate-700", !isOwn)
            })
    }
}
