const TOOLTIP_ID = "adminSidebarTooltip"
const FLYOUT_ID = "adminSidebarFlyout"

let activeFlyoutTarget = null

const sidebarTooltip = () => document.getElementById(TOOLTIP_ID)
const sidebarFlyout = () => document.getElementById(FLYOUT_ID)

const isCollapsedSidebar = () =>
    document.getElementById("adminSidebar")?.classList.contains("sidebar-collapsed")

const removeSidebarTooltip = () => {
    sidebarTooltip()?.remove()
}

const removeSidebarFlyout = () => {
    sidebarFlyout()?.remove()
    activeFlyoutTarget = null
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

    if (tooltip && target) {
        positionSidebarTooltip(target)
    }
}

const flyoutItemMarkup = (submenu) => {
    const fragment = document.createDocumentFragment()

    submenu.querySelectorAll(":scope > a, :scope > details").forEach((item) => {
        fragment.appendChild(item.cloneNode(true))
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

    flyout.style.top = `${Math.max(viewportPadding, Math.min(preferredTop, maxTop))}px`
}

const showSidebarFlyout = (target) => {
    if (!isCollapsedSidebar()) return

    const submenu = target.parentElement?.querySelector(":scope > .sidebar-submenu")
    if (!submenu) {
        removeSidebarFlyout()
        return
    }

    removeSidebarTooltip()
    removeSidebarFlyout()
    activeFlyoutTarget = target

    const flyout = document.createElement("div")
    flyout.id = FLYOUT_ID
    flyout.className = "admin-sidebar-flyout"
    flyout.setAttribute("role", "menu")
    flyout.setAttribute(
        "aria-label",
        target.querySelector(".sidebar-label")?.textContent?.trim() || ""
    )

    const title = document.createElement("div")
    title.className = "admin-sidebar-flyout__title"
    title.textContent =
        target.querySelector(".sidebar-label")?.textContent?.trim() || ""

    const items = document.createElement("div")
    items.className = "admin-sidebar-flyout__items"
    items.appendChild(flyoutItemMarkup(submenu))

    flyout.append(title, items)
    document.body.appendChild(flyout)
    positionSidebarFlyout(target, flyout)

    requestAnimationFrame(() => flyout.classList.add("is-visible"))
}

const refreshSidebarFlyout = () => {
    const flyout = sidebarFlyout()

    if (flyout && activeFlyoutTarget && isCollapsedSidebar()) {
        positionSidebarFlyout(activeFlyoutTarget, flyout)
    }
}

const sidebarSummaryAtEvent = (event) => {
    const sidebar = document.getElementById("adminSidebar")
    if (!sidebar?.classList.contains("sidebar-collapsed")) return null

    const target = event.target instanceof Element
        ? event.target.closest(".sidebar-catalog > summary")
        : null

    return target && sidebar.contains(target) ? target : null
}

const syncFlyoutWithPointer = (event) => {
    const summary = sidebarSummaryAtEvent(event)

    if (summary) {
        if (activeFlyoutTarget !== summary) {
            showSidebarFlyout(summary)
        }

        return
    }

    const sidebar = document.getElementById("adminSidebar")
    const flyout = sidebarFlyout()

    if (
        activeFlyoutTarget &&
        sidebar?.contains(event.target) &&
        !flyout?.contains(event.target)
    ) {
        removeSidebarFlyout()
    }
}

document.addEventListener("mouseover", (event) => {
    syncFlyoutWithPointer(event)

    if (sidebarSummaryAtEvent(event)) return

    showSidebarTooltip(event)
})

document.addEventListener("mouseout", (event) => {
    const target = event.target instanceof Element
        ? event.target.closest("[data-tooltip]")
        : null

    if (!target) return

    const nextTarget = event.relatedTarget

    if (nextTarget instanceof Node && target.contains(nextTarget)) return

    removeSidebarTooltip()
})

document.addEventListener("focusin", (event) => {
    const target = event.target instanceof Element
        ? event.target.closest(".sidebar-catalog > summary")
        : null

    if (target && document.getElementById("adminSidebar")?.contains(target)) {
        showSidebarFlyout(target)
        return
    }

    showSidebarTooltip(event)
})

document.addEventListener("focusout", (event) => {
    const target = event.target instanceof Element
        ? event.target.closest(".sidebar-catalog > summary")
        : null

    if (
        target &&
        !event.relatedTarget?.closest?.("#adminSidebarTooltip, #adminSidebarFlyout")
    ) {
        removeSidebarFlyout()
    }

    removeSidebarTooltip()
})

document.addEventListener("click", (event) => {
    const sidebar = document.getElementById("adminSidebar")
    const target = event.target instanceof Element
        ? event.target.closest(".sidebar-catalog > summary")
        : null

    if (
        target &&
        sidebar?.contains(target) &&
        sidebar.classList.contains("sidebar-collapsed")
    ) {
        event.preventDefault()
        showSidebarFlyout(target)
        return
    }

    if (
        !event.target.closest?.("#adminSidebarFlyout") &&
        !event.target.closest?.(".sidebar-catalog > summary")
    ) {
        removeSidebarFlyout()
    }
})

document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
        removeSidebarFlyout()
        removeSidebarTooltip()
        return
    }

    if (
        (event.key === "Enter" || event.key === " ") &&
        event.target.matches(".sidebar-catalog > summary")
    ) {
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
    syncFlyoutWithPointer(event)
    refreshSidebarTooltip(event)
    refreshSidebarFlyout()
})
