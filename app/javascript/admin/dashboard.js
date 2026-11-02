// DELTA POS — Admin Dashboard
// Sidebar + Dropdowns + Chat + Dashboard Customization

import { GridStack } from "gridstack"
import Swal from "sweetalert2"

let activeDashboardListeners = null
let activeDashboardGrids = []
let activeDashboardSave = null

document.addEventListener("turbo:before-cache", () => {
    document.getElementById("adminDashboardContent")?.removeAttribute("inert")
    const sidebar = document.getElementById("adminSidebar")
    sidebar?.classList.remove("sidebar-open")
    sidebar?.removeAttribute("role")
    sidebar?.removeAttribute("aria-modal")
    sidebar?.removeAttribute("inert")
    document.getElementById("sidebarOverlay")?.classList.remove("is-visible")
    document.body.classList.remove("sidebar-drawer-open")
    document.getElementById("sidebarToggle")?.removeAttribute("data-sidebar-ready")
    activeDashboardSave?.abort()
    activeDashboardSave = null
    activeDashboardGrids.forEach((grid) => grid.destroy(false))
    activeDashboardGrids = []
    document.querySelectorAll(".dashboard-layout-handle").forEach((handle) => handle.remove())
    document.querySelectorAll(".dashboard-editing").forEach((grid) => grid.classList.remove("dashboard-editing"))
    document.querySelectorAll("#cancelDashboardButton, #dashboardEditingHelp").forEach((element) => { element.hidden = true })
    const customizeButton = document.getElementById("customizeDashboardButton")
    if (customizeButton) {
        customizeButton.disabled = true
        customizeButton.removeAttribute("data-dashboard-ready")
    }
    activeDashboardListeners?.abort()
    activeDashboardListeners = null
})

document.addEventListener("turbo:load", () => {
    activeDashboardListeners?.abort()
    const listeners = new AbortController()
    activeDashboardListeners = listeners
    const onDocument = (type, handler, options = {}) =>
        document.addEventListener(type, handler, { ...options, signal: listeners.signal })
    const onWindow = (type, handler, options = {}) =>
        window.addEventListener(type, handler, { ...options, signal: listeners.signal })
    const onElement = (element, type, handler) =>
        element?.addEventListener(type, handler, { signal: listeners.signal })
    const javascriptTranslationsElement =
        document.getElementById(
            "javascriptTranslations"
        )

    const javascriptTranslations =
        javascriptTranslationsElement
            ? JSON.parse(
                javascriptTranslationsElement.textContent || "{}"
            )
            : {}

    const translateDashboard = (key) =>
        javascriptTranslations[key] || key

    const sidebar = document.getElementById("adminSidebar")
    const sidebarToggle = document.getElementById("sidebarToggle")
    const sidebarCloseButton = document.getElementById("sidebarCloseButton")
    const sidebarContent = document.getElementById("adminDashboardContent")
    const sidebarOverlay =
        document.getElementById("sidebarOverlay")
    sidebarToggle?.removeAttribute("data-sidebar-ready")

    const dropdowns = [
        {
            button: document.getElementById("branchSelectorButton"),
            menu: document.getElementById("branchSelectorMenu")
        },
        {
            button: document.getElementById("notificationsButton"),
            menu: document.getElementById("notificationsMenu")
        },
        {
            button: document.getElementById("userMenuButton"),
            menu: document.getElementById("userMenu")
        },
        {
            button: document.getElementById("sidebarUserMenuButton"),
            menu: document.getElementById("sidebarUserMenu")
        }
    ]

    // Note: the language selector dropdown is handled entirely by the
    // Stimulus `language-selector` controller (see
    // app/javascript/controllers/language_selector_controller.js), so it is
    // intentionally excluded from this list to avoid double-toggling.

    /*
     * ============================================================
     * GridStack
     * ============================================================
     */

    const kpiGridElement =
        document.getElementById("kpiGrid")

    const mainDashboardGridElement =
        document.getElementById("mainDashboardGrid")

    let kpiGrid = null
    let mainDashboardGrid = null

    if (kpiGridElement) {
        kpiGrid = GridStack.init(
            {
                column: 12,
                columnOpts: {
                    breakpoints: [{ w: 1279, c: 1 }],
                    breakpointForWindow: true
                },
                cellHeight: 80,
                margin: 8,
                handle: ".dashboard-layout-handle",
                float: false,
                animate: true,
                disableDrag: true,
                disableResize: true,
                minRow: 2,
                resizable: {
                    handles: "e,se,s,sw,w"
                }
            },
            kpiGridElement
        )
    }

    if (mainDashboardGridElement) {
        mainDashboardGrid = GridStack.init(
            {
                column: 12,
                columnOpts: {
                    breakpoints: [{ w: 1279, c: 1 }],
                    breakpointForWindow: true
                },
                cellHeight: 80,
                margin: 8,
                handle: ".dashboard-layout-handle",
                float: false,
                animate: true,
                disableDrag: true,
                disableResize: true,
                minRow: 10,
                resizable: {
                    handles: "e,se,s,sw,w"
                }
            },
            mainDashboardGridElement
        )
    }

    activeDashboardGrids = [kpiGrid, mainDashboardGrid].filter(Boolean)

    /*
     * ============================================================
     * Dashboard Preferences
     * ============================================================
     */

    const dashboardPreferencesElement =
        document.getElementById(
            "dashboardPreferences"
        )

    const getDashboardPreferences = () => {
        if (!dashboardPreferencesElement) {
            return []
        }

        try {
            return JSON.parse(
                dashboardPreferencesElement.textContent || "[]"
            )
        } catch (error) {
            console.error(
                "Error leyendo las preferencias del dashboard:",
                error
            )

            return []
        }
    }

    const applyGridPreferences = (
        grid,
        gridType,
        preferences
    ) => {
        // Saved layouts describe the 12-column grid, so they are only
        // applied while the grid is not remapped to a breakpoint column.
        if (
            !grid ||
            !preferences.length ||
            grid.getColumn() !== 12
        ) {
            return
        }

        const gridPreferences =
            preferences.filter(
                (preference) =>
                    preference.grid_type === gridType
            )

        gridPreferences.forEach((preference) => {
            const widget =
                grid.getGridItems().find(
                    (item) =>
                        item.getAttribute("gs-id") ===
                        preference.widget_id
                )

            if (!widget) {
                return
            }

            grid.update(widget, {
                x: Number(preference.x),
                y: Number(preference.y),
                w: Number(preference.w),
                h: Number(preference.h)
            })
        })
    }

    const getGridPreferences = (
        grid,
        gridType
    ) => {
        if (!grid) return []

        return grid.getGridItems()
            .map((item) => {
                const node = item.gridstackNode

                return {
                    grid_type: gridType,
                    widget_id: node?.id,
                    x: node?.x,
                    y: node?.y,
                    w: node?.w,
                    h: node?.h
                }
            })
            .filter(
                (preference) =>
                    preference.widget_id
            )
    }

    const getBaseGridPreferences = (grid, gridType) => {
        if (!grid || grid.getColumn() !== 12) {
            return []
        }

        return getGridPreferences(grid, gridType)
    }

    const saveDashboardPreferences = async () => {
        const widgets = [
            ...getBaseGridPreferences(
                kpiGrid,
                "kpi"
            ),
            ...getBaseGridPreferences(
                mainDashboardGrid,
                "main"
            )
        ]

        if (widgets.length === 0) {
            return false
        }

        const saveController = new AbortController()
        activeDashboardSave = saveController
        try {
            const response = await fetch(
                "/admin/dashboard/preferences",
                {
                    method: "POST",
                    signal: saveController.signal,
                    headers: {
                        "Content-Type":
                            "application/json",
                        "Accept":
                            "application/json",
                        "X-CSRF-Token":
                        document.querySelector(
                            'meta[name="csrf-token"]'
                        )?.content
                    },
                    body: JSON.stringify({
                        widgets
                    })
                }
            )

            const result = response.headers.get("content-type")?.includes("application/json")
                ? await response.json() : null
            if (!response.ok || result?.success !== true) {
                throw new Error(
                    "No se pudieron guardar las preferencias del dashboard."
                )
            }

            Swal.fire({
                icon: "success",
                title: translateDashboard(
                    "saved_title"
                ),
                text: translateDashboard(
                    "saved_text"
                ),
                toast: true,
                position: "top-end",
                timer: 2500,
                showConfirmButton: false,
                timerProgressBar: true
            })
            return true
        } catch (error) {
            if (error.name === "AbortError") return false
            console.error(
                "Error guardando preferencias del dashboard:",
                error
            )

            Swal.fire({
                icon: "error",
                title: translateDashboard(
                    "save_error_title"
                ),
                text: translateDashboard(
                    "save_error_text"
                )
            })
            return false
        } finally {
            if (activeDashboardSave === saveController) activeDashboardSave = null
        }
    }

    const dashboardPreferences =
        getDashboardPreferences()

    applyGridPreferences(
        kpiGrid,
        "kpi",
        dashboardPreferences
    )

    applyGridPreferences(
        mainDashboardGrid,
        "main",
        dashboardPreferences
    )

    /*
     * ============================================================
     * Dropdown Helpers
     * ============================================================
     */

    const closeAllDropdowns = (except = null) => {
        document.querySelectorAll("[data-dashboard-selector]").forEach((container) => {
            const menu = container.querySelector("[data-dashboard-selector-menu]")
            if (menu === except) return
            container.querySelectorAll("details").forEach((details) => { details.open = false })
            if (!container.querySelector("details")) menu?.classList.add("hidden")
            container.querySelector("[aria-expanded]")?.setAttribute("aria-expanded", "false")
        })
        dropdowns.forEach(({ button, menu }) => {
            if (!button || !menu || menu === except) return
            menu.classList.add("hidden")
            button.setAttribute("aria-expanded", "false")
        })
    }

    const branchDetails = document.querySelector("[data-dashboard-selector] > details")
    onElement(branchDetails?.querySelector("summary"), "click", () => {
        closeAllDropdowns(branchDetails.querySelector("[data-dashboard-selector-menu]"))
    })

    const toggleDropdown = (button, menu) => {
        if (!button || !menu) return

        const isOpen =
            !menu.classList.contains("hidden")

        closeAllDropdowns(menu)

        if (isOpen) {
            menu.classList.add("hidden")
            button.setAttribute(
                "aria-expanded",
                "false"
            )
        } else {
            menu.classList.remove("hidden")
            button.setAttribute(
                "aria-expanded",
                "true"
            )
        }
    }

    /*
     * ============================================================
     * Sidebar
     * ============================================================
     */

    const openMobileSidebar = () => {
        if (!sidebar) return

        sidebar.classList.add("sidebar-open")
        sidebar.removeAttribute("inert")
        sidebar.setAttribute("role", "dialog")
        sidebar.setAttribute("aria-modal", "true")
        sidebarToggle?.setAttribute("aria-expanded", "true")
        sidebarContent?.setAttribute("inert", "")
        document.body.classList.add("sidebar-drawer-open")
        sidebarCloseButton?.focus()

        if (sidebarOverlay) {
            sidebarOverlay.classList.add("is-visible")
            sidebarOverlay.setAttribute("aria-hidden", "true")
        }
    }

    const closeMobileSidebar = () => {
        if (!sidebar) return

        const wasOpen = sidebar.classList.contains("sidebar-open")
        sidebar.classList.remove("sidebar-open")
        // Release the main region and restore keyboard focus before making
        // the drawer inert. Otherwise Chrome may drop focus to BODY when the
        // currently focused close button becomes inert.
        sidebarContent?.removeAttribute("inert")
        if (wasOpen && window.innerWidth < 1024) sidebarToggle?.focus({ preventScroll: true })
        if (window.innerWidth < 1024) sidebar.setAttribute("inert", "")
        sidebar.removeAttribute("role")
        sidebar.removeAttribute("aria-modal")
        sidebarToggle?.setAttribute("aria-expanded", "false")
        document.body.classList.remove("sidebar-drawer-open")

        if (sidebarOverlay) {
            sidebarOverlay.classList.remove("is-visible")
            sidebarOverlay.setAttribute("aria-hidden", "true")
        }

        if (wasOpen && window.innerWidth < 1024) {
            sidebarToggle?.focus({ preventScroll: true })
            // Restore focus after the click default action has settled.
            requestAnimationFrame(() => sidebarToggle?.focus({ preventScroll: true }))
            // When the translated drawer completes its CSS transition, Chrome
            // can blur the now offscreen close button; recover only if focus
            // was lost, without stealing it from an intentional next action.
            const recoverFocusIfLost = () => {
                if (!sidebarToggle?.isConnected || sidebar.classList.contains("sidebar-open") ||
                    window.innerWidth >= 1024) return
                const focused = document.activeElement
                const focusLost = !focused ||
                    focused === document.body ||
                    focused === document.documentElement ||
                    !focused.isConnected ||
                    sidebar.contains(focused) ||
                    sidebarOverlay?.contains(focused)
                if (focusLost) sidebarToggle.focus({ preventScroll: true })
            }
            // Deferring restoration across the CSS transform keeps focus
            // out of BODY even if Chrome blurs the removed, inert close button
            // during a busy Turbo navigation. Never override a user's focus.
            for (const delay of [0, 100, 350, 700, 1500, 3000]) {
                setTimeout(recoverFocusIfLost, delay)
            }
        }
    }

    const trapMobileSidebarFocus = (event) => {
        if (event.key !== "Tab" || !sidebar?.classList.contains("sidebar-open")) return

        const candidates = sidebar.querySelectorAll("a[href], button:not([disabled]), summary, [tabindex='0']")
        const focusable = [...candidates].filter((item) => item.getClientRects().length > 0)
        if (!focusable.length) return

        const first = focusable[0]
        const last = focusable[focusable.length - 1]
        if (event.shiftKey && document.activeElement === first) {
            event.preventDefault()
            last.focus()
        } else if (!event.shiftKey && document.activeElement === last) {
            event.preventDefault()
            first.focus()
        }
    }

    if (sidebar && window.innerWidth < 1024 && !sidebar.classList.contains("sidebar-open")) {
        sidebar.setAttribute("inert", "")
    } else if (window.innerWidth >= 1024) {
        // Turbo may restore a cached mobile drawer with an obsolete inert state.
        sidebar?.removeAttribute("inert")
    }

    onWindow("resize", () => {
        if (!sidebar) return
        if (window.innerWidth >= 1024) {
            if (sidebar.classList.contains("sidebar-open")) closeMobileSidebar()
            sidebar.removeAttribute("inert")
            sidebarContent?.removeAttribute("inert")
            sidebarToggle?.setAttribute(
                "aria-expanded",
                String(!sidebar.classList.contains("sidebar-collapsed"))
            )
        } else if (!sidebar.classList.contains("sidebar-open")) {
            sidebar.setAttribute("inert", "")
            sidebarToggle?.setAttribute("aria-expanded", "false")
        }
    })

    onDocument("keydown", trapMobileSidebarFocus)
    onElement(sidebarCloseButton, "click", closeMobileSidebar)

    if (sidebar && sidebarToggle) {
        sidebarToggle.setAttribute(
            "aria-expanded",
            String(window.innerWidth >= 1024 && !sidebar.classList.contains("sidebar-collapsed"))
        )
        onElement(sidebarToggle, "click", () => {
            const isMobile = window.innerWidth < 1024

            if (isMobile) {
                const isOpen =
                    sidebar.classList.contains("sidebar-open")

                if (isOpen) {
                    closeMobileSidebar()
                } else {
                    openMobileSidebar()
                }

                return
            }

            const collapsed = sidebar.classList.toggle(
                "sidebar-collapsed"
            )
            sidebarToggle.setAttribute("aria-expanded", String(!collapsed))
            document.dispatchEvent(new Event("sidebar:state-changed"))
            persistSidebarState(collapsed)
        })
        sidebarToggle.dataset.sidebarReady = "true"
    }

    let sidebarSaveQueue = Promise.resolve()
    let sidebarSaveRevision = 0
    let persistedSidebarCollapsed = sidebar?.classList.contains("sidebar-collapsed") ?? false
    const persistSidebarState = (collapsed) => {
        const revision = ++sidebarSaveRevision
        sidebarToggle?.setAttribute("data-sidebar-save-state", "pending")
        // Serialize saves so quick toggles cannot reach the server out of order.
        sidebarSaveQueue = sidebarSaveQueue.catch(() => {}).then(async () => {
            // Rails omits the CSRF meta tag when forgery protection is disabled
            // (for example, in browser specs). In protected environments Rails
            // validates the token; never send a fabricated or empty value.
            const csrf = document.querySelector('meta[name="csrf-token"]')?.content
            const headers = {
                "Content-Type": "application/json",
                "X-Requested-With": "XMLHttpRequest"
            }
            if (csrf) headers["X-CSRF-Token"] = csrf

            const response = await fetch("/admin/sidebar", {
                method: "PATCH",
                headers,
                body: JSON.stringify({ sidebar_collapsed: collapsed })
            })
            if (!response.ok) {
                throw new Error(`Sidebar save failed: ${response.status}`)
            }
            persistedSidebarCollapsed = collapsed
            if (revision === sidebarSaveRevision) {
                sidebarToggle?.setAttribute("data-sidebar-save-state", "saved")
            }
        }).catch((error) => {
            if (revision !== sidebarSaveRevision || !sidebar) return
            sidebarToggle?.setAttribute("data-sidebar-save-state", "error")
            sidebarToggle?.setAttribute("data-sidebar-save-error", error.message)

            sidebar.classList.toggle("sidebar-collapsed", persistedSidebarCollapsed)
            sidebarToggle?.setAttribute("aria-expanded", String(!persistedSidebarCollapsed))
            document.dispatchEvent(new Event("sidebar:state-changed"))
            window.Swal?.fire({
                toast: true,
                position: "top-end",
                icon: "error",
                title: "No se pudo guardar la preferencia del menú",
                showConfirmButton: false,
                timer: 3500
            })
        })
    }

    if (sidebarOverlay) {
        onElement(sidebarOverlay, "click", (event) => {
            // The overlay is only a drawer dismissal surface. Don't let its
            // click reach the document-wide dropdown handlers, which can move
            // focus after the drawer has returned it to the navbar toggle.
            event.preventDefault()
            event.stopPropagation()
            closeMobileSidebar()
            queueMicrotask(() => {
                if (!sidebar?.classList.contains("sidebar-open") && window.innerWidth < 1024) {
                    sidebarToggle?.focus({ preventScroll: true })
                }
            })
        })
    }

    /*
     * ============================================================
     * Dropdowns
     * ============================================================
     */

    dropdowns.forEach(({ button, menu }) => {
        if (!button || !menu) return

        button.setAttribute(
            "aria-expanded",
            "false"
        )

        onElement(button, "click", (event) => {
            event.stopPropagation()
            toggleDropdown(button, menu)
        })

        onElement(menu, "click", (event) => {
            event.stopPropagation()
        })
    })

    /*
     * ============================================================
     * Click Outside
     * ============================================================
     */

    onDocument("click", (event) => {
        if (!event.target.closest?.("[data-dashboard-selector], #userMenuButton, #sidebarUserMenuButton, #userMenu, #sidebarUserMenu")) closeAllDropdowns()
    })

    onDocument("keydown", (event) => {
        if (event.key !== "Escape") return
        const active = document.activeElement
        const openButton = dropdowns.find(({ menu }) => menu && !menu.classList.contains("hidden"))?.button
        const openDetails = document.querySelector("[data-dashboard-selector] details[open] summary")
        closeAllDropdowns()
        if (openButton || openDetails) (openButton || openDetails).focus()
        else if (active?.matches?.("[data-dashboard-selector] button")) active.focus()
    })

    /*
     * ============================================================
     * Online Users + Conversation Panels
     * ============================================================
     */

    const onlineUsersPanel =
        document.getElementById("onlineUsersPanel")
    const onlineUsersButton =
        document.getElementById("onlineUsersButton")
    const onlineUsersCloseButton =
        document.getElementById("onlineUsersCloseButton")
    const conversationPanel =
        document.getElementById("conversationPanel")

    const openOnlineUsers = () => {
        if (!onlineUsersPanel) return

        closeChat()
        closeConversation()

        onlineUsersPanel.classList.remove("panel-hidden")
        onlineUsersPanel.classList.add("panel-visible")
        onlineUsersButton?.setAttribute("aria-expanded", "true")
    }

    const closeOnlineUsers = () => {
        if (!onlineUsersPanel) return

        onlineUsersPanel.classList.remove("panel-visible")
        onlineUsersPanel.classList.add("panel-hidden")
        onlineUsersButton?.setAttribute("aria-expanded", "false")
    }

    const toggleOnlineUsers = () => {
        if (!onlineUsersPanel) return

        if (onlineUsersPanel.classList.contains("panel-visible")) {
            closeOnlineUsers()
        } else {
            openOnlineUsers()
        }
    }

    const openConversation = () => {
        if (!conversationPanel) return

        closeChat()
        closeOnlineUsers()

        conversationPanel.classList.remove("panel-hidden")
        conversationPanel.classList.add("panel-visible")
    }

    const closeConversation = () => {
        if (!conversationPanel) return

        conversationPanel.classList.remove("panel-visible")
        conversationPanel.classList.add("panel-hidden")
    }

    if (onlineUsersButton) {
        onlineUsersButton.setAttribute("aria-expanded", "false")
        onlineUsersButton.addEventListener("click", (event) => {
            event.stopPropagation()
            toggleOnlineUsers()
        })
    }

    if (onlineUsersCloseButton) {
        onlineUsersCloseButton.addEventListener("click", () => {
            closeOnlineUsers()
        })
    }

    if (onlineUsersPanel) {
        onlineUsersPanel.addEventListener("click", (event) => {
            event.stopPropagation()
        })
    }

    if (conversationPanel) {
        conversationPanel.addEventListener("click", (event) => {
            if (event.target.closest("#conversationCloseButton")) {
                closeConversation()
            }
            event.stopPropagation()
        })
    }

    // Open the conversation panel when a conversation is loaded into the
    // turbo-frame (after clicking a user avatar).
    if (conversationPanel) {
        conversationPanel.addEventListener(
            "turbo:frame-load",
            () => {
                if (
                    conversationPanel
                        .querySelector("#conversation_messages")
                ) {
                    openConversation()
                }
            }
        )
    }

    /*
     * ============================================================
     * Chat
     * ============================================================
     */

    const chatPanel =
        document.getElementById("chatPanel")

    const chatFloatingButton =
        document.getElementById(
            "chatFloatingButton"
        )

    const chatCloseButton =
        document.getElementById(
            "chatCloseButton"
        )

    const chatInput =
        document.getElementById("chatInput")

    const chatSendButton =
        document.getElementById(
            "chatSendButton"
        )

    const openChat = () => {
        if (!chatPanel || !chatFloatingButton) {
            return
        }

        chatPanel.classList.remove(
            "chat-hidden"
        )

        chatPanel.classList.add(
            "chat-visible"
        )

        chatFloatingButton.setAttribute(
            "aria-expanded",
            "true"
        )

        requestAnimationFrame(() => {
            chatInput?.focus()
        })
    }

    const closeChat = () => {
        if (!chatPanel || !chatFloatingButton) {
            return
        }

        chatPanel.classList.remove(
            "chat-visible"
        )

        chatPanel.classList.add(
            "chat-hidden"
        )

        chatFloatingButton.setAttribute(
            "aria-expanded",
            "false"
        )
    }

    const toggleChat = () => {
        if (!chatPanel) return

        const isVisible =
            chatPanel.classList.contains(
                "chat-visible"
            )

        if (isVisible) {
            closeChat()
        } else {
            openChat()
        }
    }

    if (chatPanel && chatFloatingButton) {
        chatFloatingButton.setAttribute(
            "aria-expanded",
            "false"
        )

        chatFloatingButton.addEventListener(
            "click",
            (event) => {
                event.stopPropagation()
                toggleChat()
            }
        )
    }

    if (chatCloseButton) {
        chatCloseButton.addEventListener(
            "click",
            () => {
                closeChat()
            }
        )
    }

    if (chatPanel) {
        chatPanel.addEventListener(
            "click",
            (event) => {
                event.stopPropagation()
            }
        )
    }

    if (chatSendButton && chatInput) {
        chatSendButton.addEventListener(
            "click",
            () => {
                const message =
                    chatInput.value.trim()

                if (!message) return

                console.log(
                    "Mensaje enviado:",
                    message
                )

                chatInput.value = ""
                chatInput.focus()
            }
        )

        chatInput.addEventListener(
            "keydown",
            (event) => {
                if (event.key !== "Enter") return

                event.preventDefault()
                chatSendButton.click()
            }
        )
    }

    /*
     * ============================================================
     * Personalización del Dashboard
     * ============================================================
     */

    const customizeDashboardButton = document.getElementById("customizeDashboardButton")
    const cancelDashboardButton = document.getElementById("cancelDashboardButton")
    const editingHelp = document.getElementById("dashboardEditingHelp")
    const layoutStatus = document.getElementById("dashboardLayoutStatus")
    const label = customizeDashboardButton?.querySelector("[data-dashboard-customize-label]")
    let editing = false
    let saving = false
    let originalLayout = []

    const announceLayout = (key) => {
        if (layoutStatus) layoutStatus.textContent = translateDashboard(key)
    }
    const customizationAvailable = () =>
        activeDashboardGrids.length > 0 && activeDashboardGrids.every((grid) => grid.getColumn() === 12)

    const setDashboardEditing = (value) => {
        editing = value
        activeDashboardGrids.forEach((grid) => {
            grid.enableMove(value && !saving && grid.getColumn() === 12)
            grid.enableResize(value && !saving && grid.getColumn() === 12)
            grid.el.classList.toggle("dashboard-editing", value)
        })
        customizeDashboardButton?.classList.toggle("is-active", value)
        customizeDashboardButton?.setAttribute("aria-pressed", String(value))
        if (label) label.textContent = translateDashboard(saving ? "saving" : value ? "save_changes" : "customize_dashboard")
        if (cancelDashboardButton) cancelDashboardButton.hidden = !value
        if (editingHelp) editingHelp.hidden = !value
    }

    const restoreLayout = () => {
        setDashboardEditing(false)
        activeDashboardGrids.forEach((grid, index) => {
            // GridStack stores a 12-column layout internally while stacked.
            // Restore in that base coordinate system, then return to the breakpoint.
            const columns = grid.getColumn()
            if (columns !== 12) grid.column(12)
            grid.load(originalLayout[index], false)
            if (columns !== 12) grid.column(columns)
        })
        announceLayout("cancelled")
        setDashboardEditing(false)
    }

    activeDashboardGrids.forEach((grid) => {
        grid.getGridItems().forEach((item) => {
            const handle = document.createElement("button")
            handle.type = "button"
            handle.className = "dashboard-layout-handle"
            const title = item.querySelector("h2, h3, p")?.textContent.trim() || ""
            handle.setAttribute("aria-label", `${translateDashboard("handle_label")} ${title}`)
            handle.setAttribute("aria-describedby", "dashboardEditingHelp")
            handle.textContent = "↔"
            item.append(handle)
            onElement(handle, "keydown", (event) => {
                if (!editing || saving || !event.key.startsWith("Arrow")) return
                event.preventDefault()
                const { x, y, w, h, minW = 1, minH = 1 } = item.gridstackNode
                const horizontal = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0
                const vertical = event.key === "ArrowDown" ? 1 : event.key === "ArrowUp" ? -1 : 0
                const position = event.shiftKey
                    ? { w: Math.max(minW, Math.min(12 - x, w + horizontal)), h: Math.max(minH, h + vertical) }
                    : { x: Math.max(0, Math.min(12 - w, x + horizontal)), y: Math.max(0, y + vertical) }
                grid.update(item, position)
                announceLayout("layout_updated")
            })
        })
    })

    const syncCustomizationAvailability = () => {
        const available = customizationAvailable()
        if (!available && editing && !saving) restoreLayout()
        if (customizeDashboardButton) {
            customizeDashboardButton.disabled = saving || !available
            customizeDashboardButton.title = available ? "" : translateDashboard("desktop_only")
        }
    }
    activeDashboardGrids.forEach((grid) => grid.on("change", syncCustomizationAvailability))
    let resizeTimer
    onWindow("resize", () => {
        window.clearTimeout(resizeTimer)
        resizeTimer = window.setTimeout(syncCustomizationAvailability, 200)
    })
    setDashboardEditing(false)
    syncCustomizationAvailability()
    customizeDashboardButton?.setAttribute("data-dashboard-ready", "true")

    onElement(cancelDashboardButton, "click", () => {
        if (saving) return
        restoreLayout()
        customizeDashboardButton?.focus()
    })
    onElement(customizeDashboardButton, "click", async () => {
        if (saving || !customizationAvailable()) return
        if (!editing) {
            originalLayout = activeDashboardGrids.map((grid) => grid.save(false))
            setDashboardEditing(true)
            return
        }
        saving = true
        if (cancelDashboardButton) cancelDashboardButton.disabled = true
        customizeDashboardButton.disabled = true
        customizeDashboardButton.setAttribute("aria-busy", "true")
        setDashboardEditing(true)
        const saved = await saveDashboardPreferences()
        saving = false
        if (listeners.signal.aborted) return
        if (cancelDashboardButton) cancelDashboardButton.disabled = false
        customizeDashboardButton.removeAttribute("aria-busy")
        setDashboardEditing(!saved)
        syncCustomizationAvailability()
        customizeDashboardButton.focus()
    })

    /*
     * ============================================================
     * Escape
     * ============================================================
     */

    onDocument(
        "keydown",
        (event) => {
            if (event.key !== "Escape") return

            closeAllDropdowns()

            if (chatPanel) {
                closeChat()
            }

            if (onlineUsersPanel) {
                closeOnlineUsers()
            }

            if (conversationPanel) {
                closeConversation()
            }

            if (
                sidebar &&
                window.innerWidth < 1024
            ) {
                closeMobileSidebar()
            }
        }
    )

    /*
     * ============================================================
     * Responsive Sidebar
     * ============================================================
     */

    onWindow(
        "resize",
        () => {
            if (!sidebar) return

            if (window.innerWidth >= 1024) {
                closeMobileSidebar()
                sidebarToggle?.setAttribute("aria-expanded",
                    String(!sidebar.classList.contains("sidebar-collapsed")))
            }
        }
    )
})
