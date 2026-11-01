// Progressive enhancement for single-choice selects throughout Delta POS.
// Native selects keep their name, value, validation rules and change handlers.
const SELECTOR = "select:not([multiple]):not([data-native-select]):not([data-delta-select-skip])"

function eligible(select) {
  if (!select.isConnected || select.closest('[data-controller~="delta-select"]')) return false
  // SweetAlert2 injects a hidden native <select> even for notifications without
  // input fields. Enhancing it adds an unwanted visible dropdown to the toast.
  // Leave all SweetAlert2-owned inputs to SweetAlert2 itself.
  if (select.closest(".swal2-container")) return false
  if (select.size > 1 || select.closest('[data-select-enhancement="off"]')) return false
  return !select.matches(".tomselected, .choices__input, .select2-hidden-accessible")
}

function enhance(root) {
  const selects = []
  if (root.matches?.(SELECTOR)) selects.push(root)
  root.querySelectorAll?.(SELECTOR).forEach((select) => selects.push(select))

  selects.forEach((select) => {
    if (!eligible(select)) return

    const wrapper = document.createElement("div")
    wrapper.className = "relative min-w-0 w-full delta-select-container"
    wrapper.dataset.controller = "delta-select"
    wrapper.dataset.autoDeltaSelect = "true"
    select.before(wrapper)
    wrapper.append(select)
  })
}

function start() {
  if (!document.body) return
  enhance(document.body)
  // Turbo Drive can replace the BODY. Observe the active body, never a detached one.
  if (start.observer && start.observedBody === document.body) return
  start.observer?.disconnect()
  start.observedBody = document.body

  start.observer = new MutationObserver((mutations) => {
    mutations.forEach(({ addedNodes }) => {
      addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE) enhance(node)
      })
    })
  })
  start.observer.observe(document.body, { childList: true, subtree: true })
}

export function installAutomaticSelects() {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true })
  } else {
    start()
  }
  document.addEventListener("turbo:load", start)
}
