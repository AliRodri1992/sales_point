const TOOLTIP_ID = "adminSidebarTooltip"
const FLYOUT_ID = "adminSidebarFlyout"

const sidebarTooltip = () => document.getElementById(TOOLTIP_ID)
const sidebarFlyout = () => document.getElementById(FLYOUT_ID)

const isCollapsedSidebar = () =>
    document.getElementById("adminSidebar")?.classList.contains("sidebar-collapsed")

const removeSidebarTooltip = () => {
    sidebarTooltip()?.remove()
}

const removeSidebarFlyout = () => {
    sidebarFlyout()?.remove()
}

const positionSidebarTooltip = (target) => {
    const tooltip = sidebarTooltip()
    if (!tooltip) return

    const rect = target.getBoundingClientRect()
    const gap = 12

    tooltip.style.left = `${rect.right + gap}px`
    tooltip.style.top = `${rect.top + rect.height / 2}px`
}

const showSidebarTooltip = (event) => {
    const sidebar = document.getElementById("adminSidebar")
    if (!sidebar?.classList.contains("sidebar-collapsed")) return

    const target = event.target.closest("[data-tooltip]")
    if (!target || !sidebar.contains(target)) return

    if (target.matches(".sidebar-catalog > summary")) {
        removeSidebarTooltip()
        return
    }

    const message = target.dataset.tooltip?.trim()
    if (!message) return

    removeSidebarTooltip()

    const tooltip = document.createElement("div")
    tooltip.id = TOOLTIP_ID
    tooltip.setAttribute("role", "tooltip")
    tooltip.textContent = message
    document.body.appendChild(tooltip)
    positionSidebarTooltip(target)
    requestAnimationFrame(() => tooltip.classList.add("is-visible"))
}

const refreshSidebarTooltip = (event) => {
    const tooltip = sidebarTooltip()
    const target = event.target.closest("[data-tooltip]")
    if (tooltip && target) positionSidebarTooltip(target)
}

const flyoutItemMarkup = (submenu) => {
    const fragment = document.createDocumentFragment()

    submenu.querySelectorAll(":scope > a, :scope > details").forEach((item) => {
        const clone = item.cloneNode(true)
        fragment.appendChild(clone)
    })

    return fragment
}

const positionSidebarFlyout = (target, flyout) => {
    const rect = target.getBoundingClientRect()
    const gap = 10
    const viewportPadding = 12

    flyout.style.left = `${rect.right + gap}px`

    const flyoutHeight = flyout.offsetHeight
    const preferredTop = rect.top
    const maxTop = window.innerHeight - flyoutHeight - viewportPadding
    const top = Math.max(viewportPadding, Math.min(preferredTop, maxTop))

    flyout.style.top = `${top}px`
}

const showSidebarFlyout = (target) => {
    if (!isCollapsedSidebar()) return

    const submenu = target.parentElement?.querySelector(":scope > .sidebar-submenu")
    if (!submenu) return

    removeSidebarTooltip()
    removeSidebarFlyout()

    const flyout = document.createElement("div")
    flyout.id = FLYOUT_ID
    flyout.className = "admin-sidebar-flyout"
    flyout.setAttribute("role", "menu")
    flyout.setAttribute("aria-label", target.querySelector(".sidebar-label")?.textContent?.trim() || "")

    const title = document.createElement("div")
    title.className = "admin-sidebar-flyout__title"
    title.textContent = target.querySelector(".sidebar-label")?.textContent?.trim() || ""

    const items = document.createElement("div")
    items.className = "admin-sidebar-flyout__items"
    items.appendChild(flyoutItemMarkup(submenu))

    flyout.append(title, items)
    document.body.appendChild(flyout)
    positionSidebarFlyout(target, flyout)

    requestAnimationFrame(() => flyout.classList.add("is-visible"))

    flyout.addEventListener("mouseleave", () => {
        if (!target.matches(":hover")) removeSidebarFlyout()
    })
}

const refreshSidebarFlyout = (target) => {
    const flyout = sidebarFlyout()
    if (flyout && isCollapsedSidebar()) {
        positionSidebarFlyout(target, flyout)
    }
}

document.addEventListener("mouseover", (event) => {
    const target = event.target.closest(".sidebar-catalog > summary")
    if (target && document.getElementById("adminSidebar")?.contains(target)) {
        showSidebarFlyout(target)
    }

    showSidebarTooltip(event)
})

document.addEventListener("mouseout", (event) => {
    const target = event.target.closest("[data-tooltip]")
    if (!target) return

    const nextTarget = event.relatedTarget
    if (nextTarget && target.contains(nextTarget)) return

    removeSidebarTooltip()
})

document.addEventListener("focusin", (event) => {
    const target = event.target.closest(".sidebar-catalog > summary")
    if (target && document.getElementById("adminSidebar")?.contains(target)) {
        showSidebarFlyout(target)
        return
    }

    showSidebarTooltip(event)
})

document.addEventListener("focusout", (event) => {
    const target = event.target.closest(".sidebar-catalog > summary")
    if (target && !event.relatedTarget?.closest?.("#adminSidebarTooltip, #adminSidebarFlyout")) {
        removeSidebarFlyout()
    }

    removeSidebarTooltip()
})

document.addEventListener("click", (event) => {
    const sidebar = document.getElementById("adminSidebar")
    const target = event.target.closest(".sidebar-catalog > summary")

    if (target && sidebar?.contains(target) && sidebar.classList.contains("sidebar-collapsed")) {
        event.preventDefault()
        showSidebarFlyout(target)
        return
    }

    if (!event.target.closest("#adminSidebarFlyout") && !event.target.closest(".sidebar-catalog > summary")) {
        removeSidebarFlyout()
    }
})

document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
        removeSidebarFlyout()
        removeSidebarTooltip()
        return
    }

    if ((event.key === "Enter" || event.key === " ") && event.target.matches(".sidebar-catalog > summary")) {
        if (!isCollapsedSidebar()) return

        event.preventDefault()
        showSidebarFlyout(event.target)
    }
})

document.addEventListener("scroll", (event) => {
    if (event.target.closest?.("#adminSidebar nav")) {
        removeSidebarTooltip()
        removeSidebarFlyout()
    }
}, true)

window.addEventListener("resize", () => {
    removeSidebarTooltip()
    removeSidebarFlyout()
})

document.addEventListener("mousemove", (event) => {
    refreshSidebarTooltip(event)

    const target = event.target.closest(".sidebar-catalog > summary")
    if (target && sidebarFlyout()) refreshSidebarFlyout(target)
})
