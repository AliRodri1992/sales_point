// DELTA POS — Admin Dashboard
// Sidebar + Dropdowns + Chat + Dashboard Customization

import { GridStack } from "gridstack"
import Swal from "sweetalert2"

let activeDashboardListeners = null

document.addEventListener("turbo:before-cache", () => {
    document.getElementById("adminDashboardContent")?.removeAttribute("inert")
    const sidebar = document.getElementById("adminSidebar")
    sidebar?.classList.remove("sidebar-open")
    sidebar?.removeAttribute("role")
    sidebar?.removeAttribute("aria-modal")
    document.getElementById("sidebarOverlay")?.classList.remove("is-visible")
    document.body.classList.remove("sidebar-drawer-open")
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

    // Below this width both grids stack into a single column.
    const stackBreakpoint = 768

    // KPI cards go full width when stacked, so they use shorter
    // cells there to keep the same card proportions.
    const kpiCellHeight = () =>
        window.innerWidth <= stackBreakpoint ? 80 : 96

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
                    breakpoints: [{ w: stackBreakpoint, c: 1 }],
                    breakpointForWindow: true
                },
                cellHeight: kpiCellHeight(),
                margin: 10,
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
                    breakpoints: [{ w: stackBreakpoint, c: 1 }],
                    breakpointForWindow: true
                },
                cellHeight: 80,
                margin: "8px 10px",
                float: false,
                animate: true,
                disableDrag: true,
                disableResize: true,
                minRow: 12,
                resizable: {
                    handles: "e,se,s,sw,w"
                }
            },
            mainDashboardGridElement
        )
    }

    // Keep the KPI cells compact when crossing the stacking breakpoint.
    onWindow("resize", () => {
        if (!kpiGrid) return

        kpiGrid.cellHeight(kpiCellHeight())
    })

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
            return
        }

        try {
            const response = await fetch(
                "/admin/dashboard/preferences",
                {
                    method: "POST",
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

            if (!response.ok) {
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
        } catch (error) {
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
    branchDetails?.querySelector("summary")?.addEventListener("click", () => {
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
        if (window.innerWidth < 1024) sidebar.setAttribute("inert", "")
        sidebar.removeAttribute("role")
        sidebar.removeAttribute("aria-modal")
        sidebarToggle?.setAttribute("aria-expanded", "false")
        sidebarContent?.removeAttribute("inert")
        document.body.classList.remove("sidebar-drawer-open")

        if (sidebarOverlay) {
            sidebarOverlay.classList.remove("is-visible")
            sidebarOverlay.setAttribute("aria-hidden", "true")
        }

        if (wasOpen && window.innerWidth < 1024) sidebarToggle?.focus()
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
    }

    onWindow("resize", () => {
        if (!sidebar) return
        if (window.innerWidth >= 1024) {
            if (sidebar.classList.contains("sidebar-open")) closeMobileSidebar()
            sidebar.removeAttribute("inert")
        } else if (!sidebar.classList.contains("sidebar-open")) {
            sidebar.setAttribute("inert", "")
        }
    })

    onDocument("keydown", trapMobileSidebarFocus)
    sidebarCloseButton?.addEventListener("click", closeMobileSidebar)

    if (sidebar && sidebarToggle) {
        sidebarToggle.setAttribute(
            "aria-expanded",
            String(window.innerWidth >= 1024 && !sidebar.classList.contains("sidebar-collapsed"))
        )
        sidebarToggle.addEventListener("click", () => {
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
            persistSidebarState(collapsed)
        })
    }

    const persistSidebarState = (collapsed) => {
        const csrf = document.querySelector(
            'meta[name="csrf-token"]'
        )
        if (!csrf) return

        fetch("/admin/sidebar", {
            method: "PATCH",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": csrf.content,
                "X-Requested-With": "XMLHttpRequest"
            },
            body: JSON.stringify({
                sidebar_collapsed: collapsed
            })
        }).catch(() => {})
    }

    if (sidebarOverlay) {
        sidebarOverlay.addEventListener("click", () => {
            closeMobileSidebar()
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

        button.addEventListener("click", (event) => {
            event.stopPropagation()
            toggleDropdown(button, menu)
        })

        menu.addEventListener("click", (event) => {
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

    const customizeDashboardButton =
        document.getElementById(
            "customizeDashboardButton"
        )

    const setDashboardEditing = (
        editing
    ) => {
        if (!customizeDashboardButton) {
            return
        }

        const dashboardGrids = [
            kpiGrid,
            mainDashboardGrid
        ]

        dashboardGrids.forEach((grid) => {
            if (!grid) return

            // Only the base 12-column layout can be customized,
            // since that is the layout that gets persisted.
            const editable =
                editing && grid.getColumn() === 12

            grid.enableMove(editable)
            grid.enableResize(editable)
        })

        const dashboardGridElements = [
            kpiGridElement,
            mainDashboardGridElement
        ]

        dashboardGridElements.forEach(
            (gridElement) => {
                if (!gridElement) return

                gridElement.classList.toggle(
                    "dashboard-editing",
                    editing
                )
            }
        )

        customizeDashboardButton.classList.toggle(
            "is-active",
            editing
        )

        customizeDashboardButton.setAttribute(
            "aria-pressed",
            editing.toString()
        )

        const icon =
            customizeDashboardButton.querySelector(
                "i"
            )

        if (icon) {
            icon.classList.toggle(
                "fa-sliders",
                !editing
            )

            icon.classList.toggle(
                "fa-check",
                editing
            )
        }

        const textNode =
            Array.from(
                customizeDashboardButton.childNodes
            ).find(
                (node) =>
                    node.nodeType === Node.TEXT_NODE &&
                    node.textContent
                        .trim()
                        .length > 0
            )

        if (textNode) {
            textNode.textContent = editing
                ? ` ${translateDashboard("save_changes")}`
                : ` ${translateDashboard("customize_dashboard")}`
        }
    }

    if (customizeDashboardButton) {
        customizeDashboardButton.setAttribute(
            "aria-pressed",
            "false"
        )

        const customizationAvailable = () =>
            [kpiGrid, mainDashboardGrid].some(
                (grid) => grid && grid.getColumn() === 12
            )

        const syncCustomizationAvailability = () => {
            const available =
                customizationAvailable()

            customizeDashboardButton.disabled =
                !available

            if (
                !available &&
                customizeDashboardButton.classList.contains(
                    "is-active"
                )
            ) {
                setDashboardEditing(false)
            }
        }

        syncCustomizationAvailability()

        // GridStack remaps its columns through a throttled
        // ResizeObserver, so the button state is re-checked once
        // the viewport has settled (e.g. after a rotation).
        onWindow("resize", () => {
            window.setTimeout(
                syncCustomizationAvailability,
                150
            )
        })

        customizeDashboardButton.addEventListener(
            "click",
            async () => {
                const isEditing =
                    customizeDashboardButton.classList.contains(
                        "is-active"
                    )

                if (isEditing) {
                    await saveDashboardPreferences()
                }

                setDashboardEditing(
                    !isEditing
                )
            }
        )
    }

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
