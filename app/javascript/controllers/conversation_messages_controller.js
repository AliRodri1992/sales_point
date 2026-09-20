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

                const ownStyle =
                    "background-color:#2563eb;color:#ffffff"
                const incomingStyle =
                    el.dataset.messageStyle ||
                    "background-color:#ffffff;color:#334155"

                el.classList.toggle("justify-end", isOwn)
                el.classList.toggle("justify-start", !isOwn)

                bubble.classList.remove(
                    "bg-blue-600",
                    "text-white",
                    "bg-white",
                    "text-slate-700"
                )
                bubble.style.cssText = isOwn ? ownStyle : incomingStyle
            })
    }
}
