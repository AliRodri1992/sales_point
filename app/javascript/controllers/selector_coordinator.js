export function closeDashboardSelectors(except = null) {
    document.querySelectorAll("[data-dashboard-selector]").forEach((container) => {
        if (container === except) return

        container.querySelectorAll("details").forEach((details) => {
            details.open = false
        })

        container.querySelectorAll("[data-dashboard-selector-menu]").forEach((menu) => {
            menu.classList.add("hidden")
        })

        container.querySelector("[aria-expanded]")?.setAttribute("aria-expanded", "false")
    })
}

export function openDashboardSelector(container) {
    if (!container) return

    closeDashboardSelectors(container)
}
