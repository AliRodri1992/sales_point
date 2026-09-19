// NEXO POS — Admin Dashboard
// Sidebar + Dropdowns + Chat + Dashboard Customization

import { GridStack } from "gridstack"
import Swal from "sweetalert2"

document.addEventListener("turbo:load", () => {
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
                cellHeight: 96,
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
        if (!grid || !preferences.length) {
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

    const saveDashboardPreferences = async () => {
        const widgets = [
            ...getGridPreferences(
                kpiGrid,
                "kpi"
            ),
            ...getGridPreferences(
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
        dropdowns.forEach(({ button, menu }) => {
            if (!button || !menu || menu === except) return

            menu.classList.add("hidden")
            button.setAttribute("aria-expanded", "false")
        })
    }

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

        if (sidebarOverlay) {
            sidebarOverlay.classList.add("is-visible")
            sidebarOverlay.setAttribute(
                "aria-hidden",
                "false"
            )
        }
    }

    const closeMobileSidebar = () => {
        if (!sidebar) return

        sidebar.classList.remove("sidebar-open")

        if (sidebarOverlay) {
            sidebarOverlay.classList.remove("is-visible")
            sidebarOverlay.setAttribute(
                "aria-hidden",
                "true"
            )
        }
    }

    if (sidebar && sidebarToggle) {
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

            sidebar.classList.toggle(
                "sidebar-collapsed"
            )
        })
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

    document.addEventListener("click", () => {
        closeAllDropdowns()
    })

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

            grid.enableMove(editing)
            grid.enableResize(editing)
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

    document.addEventListener(
        "keydown",
        (event) => {
            if (event.key !== "Escape") return

            closeAllDropdowns()

            if (chatPanel) {
                closeChat()
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

    window.addEventListener(
        "resize",
        () => {
            if (!sidebar) return

            if (window.innerWidth >= 1024) {
                closeMobileSidebar()
            } else {
                sidebar.classList.remove(
                    "sidebar-collapsed"
                )
            }
        }
    )
})