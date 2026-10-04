export function isDashboardSelectorOpen(container) {
    if (!container) return false

    const detailsOpen = Array.from(container.querySelectorAll("details")).some(
        (details) => details.open
    )
    const menusOpen = Array.from(container.querySelectorAll("[data-dashboard-selector-menu]")).some(
        (menu) => !menu.classList.contains("hidden")
    )

    return detailsOpen || menusOpen
}

export function closeDashboardSelectors(except = null) {
    document.querySelectorAll("[data-dashboard-selector]").forEach((container) => {
        if (container === except) return

        container.querySelectorAll("details").forEach((details) => {
            details.open = false
        })

        container.querySelectorAll("[data-dashboard-selector-menu]").forEach((menu) => {
            menu.classList.add("hidden")
        })

        container.querySelector("#notificationsButton")?.setAttribute("aria-expanded", "false")
        container.querySelectorAll('[data-language-selector-target="dropdown"]').forEach((dropdown) => {
            dropdown.classList.add("hidden")
        })
    })
}

const selectorOpenedHandler = (event) => {
    closeDashboardSelectors(event.detail?.source ?? null)
}

const outsideClickHandler = (event) => {
    const selector = event.target instanceof Element
        ? event.target.closest("[data-dashboard-selector]")
        : null

    if (!selector) closeDashboardSelectors()
}

const escapeHandler = (event) => {
    if (event.key === "Escape") closeDashboardSelectors()
}

document.addEventListener("dashboard:selector:open", selectorOpenedHandler)
document.addEventListener("click", outsideClickHandler)
document.addEventListener("keydown", escapeHandler)
