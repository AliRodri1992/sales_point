const TOOLTIP_ID = "adminSidebarTooltip"

const sidebarTooltip = () => document.getElementById(TOOLTIP_ID)

const removeSidebarTooltip = () => {
    sidebarTooltip()?.remove()
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

document.addEventListener("mouseover", showSidebarTooltip)
document.addEventListener("mouseout", (event) => {
    const target = event.target.closest("[data-tooltip]")
    if (!target) return

    const nextTarget = event.relatedTarget
    if (nextTarget && target.contains(nextTarget)) return

    removeSidebarTooltip()
})

document.addEventListener("focusin", showSidebarTooltip)
document.addEventListener("focusout", removeSidebarTooltip)
document.addEventListener("scroll", (event) => {
    if (event.target.closest?.("#adminSidebar nav")) removeSidebarTooltip()
}, true)
window.addEventListener("resize", removeSidebarTooltip)
document.addEventListener("mousemove", refreshSidebarTooltip)
