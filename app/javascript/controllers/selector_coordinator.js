export function closeDashboardSelectors(except = null) {
    document.querySelectorAll("[data-dashboard-selector]").forEach((container) => {
        if (container === except) return

        container.querySelectorAll("details").forEach((details) => {
            details.open = false
        })

        container.querySelectorAll("[data-dashboard-selector-menu]").forEach((menu) => {
            menu.classList.add("hidden")
        })

        container.querySelector("[data-notifications-target=\"button\"]")?.setAttribute("aria-expanded", "false")
    })
}

export function openDashboardSelector(container) {
    if (!container) return

    closeDashboardSelectors(container)
}

export function isDashboardSelectorOpen(container) {
    if (!container) return false

    return Array.from(container.querySelectorAll("details")).some((details) => details.open) ||
        Array.from(container.querySelectorAll("[data-dashboard-selector-menu]")).some(
            (menu) => !menu.classList.contains("hidden")
        )
}
