const TOOLTIP_ID = "adminSidebarTooltip"
const FLYOUT_ID = "adminSidebarFlyout"

let activeFlyoutTarget = null
let flyoutCloseTimer = null
const cancelFlyoutClose = () => {
    if (flyoutCloseTimer !== null) clearTimeout(flyoutCloseTimer)
    flyoutCloseTimer = null
}

const sidebarTooltip = () => document.getElementById(TOOLTIP_ID)
const sidebarFlyout = () => document.getElementById(FLYOUT_ID)

const isCollapsedSidebar = () =>
    window.innerWidth >= 1024 &&
    document.getElementById("adminSidebar")?.classList.contains("sidebar-collapsed")

const removeSidebarTooltip = () => {
    sidebarTooltip()?.remove()
}

const removeSidebarFlyout = () => {
    cancelFlyoutClose()
    sidebarFlyout()?.remove()
    activeFlyoutTarget?.setAttribute("aria-expanded", "false")
    activeFlyoutTarget?.removeAttribute("aria-controls")
    activeFlyoutTarget = null
}

const positionSidebarTooltip = (target) => {
    const tooltip = sidebarTooltip()
    if (!tooltip) return

    const rect = target.getBoundingClientRect()
    const gap = 12

    tooltip.style.left = `${Math.max(4, Math.min(rect.right + gap, window.innerWidth - tooltip.offsetWidth - 4))}px`
    tooltip.style.top = `${Math.max(tooltip.offsetHeight / 2 + 4, Math.min(rect.top + rect.height / 2, window.innerHeight - tooltip.offsetHeight / 2 - 4))}px`
}

const showSidebarTooltip = (event) => {
    const sidebar = document.getElementById("adminSidebar")
    if (!isCollapsedSidebar() || !sidebar) return

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

    Array.from(submenu.children).filter((item) => item.matches("a, details, [aria-disabled]")).forEach((item) => {
        const clone = item.cloneNode(true)
        clone.removeAttribute("id")
        clone.querySelectorAll("[id]").forEach((child) => child.removeAttribute("id"))
        fragment.appendChild(clone)
    })

    return fragment
}

const positionSidebarFlyout = (target, flyout) => {
    const rect = target.getBoundingClientRect()
    const gap = 10
    const viewportPadding = 12

    flyout.style.left = `${Math.min(rect.right + gap, Math.max(12, window.innerWidth - flyout.offsetWidth - 12))}px`

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
    if (activeFlyoutTarget === target && sidebarFlyout()) {
        refreshSidebarFlyout()
        return
    }
    removeSidebarFlyout()
    activeFlyoutTarget = target
    target.setAttribute("aria-expanded", "true")

    const flyout = document.createElement("div")
    flyout.id = FLYOUT_ID
    flyout.className = "admin-sidebar-flyout"
    flyout.setAttribute("role", "navigation")
    target.setAttribute("aria-controls", FLYOUT_ID)
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
    if (!isCollapsedSidebar() || !sidebar) return null

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

    if (flyout?.contains(event.target)) {
        cancelFlyoutClose()
    } else if (activeFlyoutTarget && sidebar?.contains(event.target)) {
        removeSidebarFlyout()
    } else if (activeFlyoutTarget && flyoutCloseTimer === null) {
        // Allow the pointer to cross the small gap to the floating submenu.
        flyoutCloseTimer = setTimeout(removeSidebarFlyout, 160)
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
        if (!sidebarFlyout()) showSidebarFlyout(target)
        return
    }

    showSidebarTooltip(event)
})

document.addEventListener("focusout", (event) => {
    const target = event.target instanceof Element
        ? event.target.closest(".sidebar-catalog > summary")
        : null

    if (target && !event.relatedTarget?.closest?.("#adminSidebarFlyout")) {
        // Defer dismissal until focus settles; clicking through the flyout must remain possible.
        queueMicrotask(() => {
            const focused = document.activeElement
            if (!sidebarFlyout()?.contains(focused) && focused !== activeFlyoutTarget) removeSidebarFlyout()
        })
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
        const returnTarget = activeFlyoutTarget
        removeSidebarFlyout()
        removeSidebarTooltip()
        if (returnTarget && isCollapsedSidebar()) returnTarget.focus()
        return
    }

    if (
        (event.key === "Enter" || event.key === " ") &&
        event.target.matches(".sidebar-catalog > summary")
    ) {
        if (!isCollapsedSidebar()) return

        event.preventDefault()
        showSidebarFlyout(event.target)
        sidebarFlyout()?.querySelector("a[href], summary")?.focus()
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

// Keep focus in the expanded menu when tabbing into cloned flyout links.
document.addEventListener("focusin", (event) => {
    if (sidebarFlyout()?.contains(event.target)) removeSidebarTooltip()
})

document.addEventListener("turbo:before-cache", () => {
    removeSidebarTooltip()
    removeSidebarFlyout()
})
