import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        this.onClick = this.handleClick.bind(this)
        this.onKeyDown = this.handleKeyDown.bind(this)
        document.addEventListener("click", this.onClick)
        document.addEventListener("keydown", this.onKeyDown)
    }

    disconnect() {
        document.removeEventListener("click", this.onClick)
        document.removeEventListener("keydown", this.onKeyDown)
    }

    get usersPanel() { return document.getElementById("onlineUsersPanel") }
    get conversationPanel() { return document.getElementById("conversationPanel") }
    get launcher() { return document.getElementById("onlineUsersButton") }

    setPanel(panel, visible) {
        if (!panel) return
        panel.classList.toggle("panel-visible", visible)
        panel.classList.toggle("panel-hidden", !visible)
        panel.setAttribute("aria-hidden", String(!visible))
        if (panel === this.usersPanel) {
            this.launcher?.setAttribute("aria-expanded", String(visible))
        }
    }

    handleClick(event) {
        const target = event.target instanceof Element ? event.target : null
        if (!target) return

        if (target.closest("#onlineUsersButton")) {
            const isOpen = this.usersPanel?.classList.contains("panel-visible")
            this.setPanel(this.conversationPanel, false)
            this.setPanel(this.usersPanel, !isOpen)
            return
        }

        if (target.closest("#onlineUsersCloseButton")) {
            this.closeAll()
            return
        }

        if (target.closest("#conversationCloseButton")) {
            this.setPanel(this.conversationPanel, false)
            this.setPanel(this.usersPanel, true)
            return
        }

        if (target.closest("#online_users_list form")) {
            this.setPanel(this.usersPanel, false)
            this.setPanel(this.conversationPanel, true)
        }
    }

    handleKeyDown(event) {
        if (event.key !== "Escape") return
        if (this.usersPanel?.classList.contains("panel-visible") ||
            this.conversationPanel?.classList.contains("panel-visible")) {
            this.closeAll()
            this.launcher?.focus()
        }
    }

    closeAll() {
        this.setPanel(this.usersPanel, false)
        this.setPanel(this.conversationPanel, false)
    }
}
