import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { locale: String }

    connect() {
        this.tick()
        this.interval = setInterval(() => this.tick(), 1000)
    }

    disconnect() {
        clearInterval(this.interval)
    }

    tick() {
        const now = new Date()
        const locale = this.localeValue || "en"

        const date = now.toLocaleDateString(locale, {
            weekday: "long",
            day: "numeric",
            month: "long",
            year: "numeric"
        })
        const time = now.toLocaleTimeString(locale, {
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit"
        })

        this.element.textContent =
            `${capitalize(date)} · ${time}`
    }
}

function capitalize(value) {
    return value.length ? value[0].toUpperCase() + value.slice(1) : value
}