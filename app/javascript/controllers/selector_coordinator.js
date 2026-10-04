export function closeDashboardSelectors(except = null) {
    document.querySelectorAll('[data-dashboard-selector] details').forEach((details) => {
        const container = details.closest("[data-dashboard-selector]")

        if (container !== except) {
            details.open = false
        }
    })

    document.querySelectorAll('[data-language-selector-target="dropdown"]').forEach((dropdown) => {
        const container = dropdown.closest("[data-dashboard-selector]")

        if (container !== except) {
            dropdown.classList.add("hidden")
        }
    })

    const notificationMenu = document.getElementById("notificationsMenu")
    const notificationContainer = notificationMenu?.closest("[data-dashboard-selector]")

    if (notificationMenu && notificationContainer !== except) {
        notificationMenu.classList.add("hidden")
        document.getElementById("notificationsButton")?.setAttribute("aria-expanded", "false")
    }
}

export function isDashboardSelectorOpen(container) {
    const details = container?.querySelector("details")
    const dropdown = container?.querySelector('[data-language-selector-target="dropdown"]')
    const notificationMenu = container?.querySelector("#notificationsMenu")

    return Boolean(
        details?.open ||
        (dropdown && !dropdown.classList.contains("hidden")) ||
        (notificationMenu && !notificationMenu.classList.contains("hidden"))
    )
}
