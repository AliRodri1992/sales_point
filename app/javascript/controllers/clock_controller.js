import { Controller } from "@hotwired/stimulus"
import { greetingPeriod } from "../lib/greeting_period.mjs"

export default class extends Controller {
    static targets = ["date", "greeting"]
    static values = { locale: String, morning: String, afternoon: String, evening: String }

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

        this.dateTarget.textContent =
            `${capitalize(date)} · ${time}`

        const period = greetingPeriod(now.getHours())
        this.greetingTarget.textContent = this[`${period}Value`]
    }
}

function capitalize(value) {
    return value.length ? value[0].toUpperCase() + value.slice(1) : value
}