import { Controller } from "@hotwired/stimulus"

// Deltín deliberately uses the documented guide; no unsanctioned data access.
export default class extends Controller {
  static targets = [
    "launcher", "panel", "closeButton", "question", "sendButton",
    "screen", "result", "resultTitle", "reply", "steps",
    "note", "guideLink", "speechButton"
  ]

  static values = { endpoint: String, locale: String, labels: Object }

  connect() {
    this.lastAnswer = ""
    this.requestController = null
    this.speech = null
    this.previousFocus = null
    // Bind the launcher immediately, even when contextual data cannot be read.
    this.boundLauncherClick = (event) => {
      event.preventDefault()
      event.stopPropagation()
      this.open()
    }
    this.launcherTarget.addEventListener("click", this.boundLauncherClick)
    this.element.dataset.assistantReady = "true"
    this.boundEscape = (event) => {
      if (this.panelTarget.hidden) return
      if (event.key === "Escape") this.close()
      if (event.key === "Tab") this.keepFocus(event)
    }
    document.addEventListener("keydown", this.boundEscape)
    this.boundTurbo = () => this.stopSpeaking()
    document.addEventListener("turbo:before-cache", this.boundTurbo)
    this.boundOtherPanel = () => this.close()
    document.getElementById("onlineUsersButton")?.addEventListener("click", this.boundOtherPanel)
  }

  disconnect() {
    this.launcherTarget.removeEventListener("click", this.boundLauncherClick)
    delete this.element.dataset.assistantReady
    document.removeEventListener("keydown", this.boundEscape)
    document.removeEventListener("turbo:before-cache", this.boundTurbo)
    document.getElementById("onlineUsersButton")?.removeEventListener("click", this.boundOtherPanel)
    this.requestController?.abort()
    this.stopSpeaking()
    this.resetSpotlight()
  }

  detectContext() {
    const path = window.location.pathname
    const matches = [
      [/\/admin\/supplier_invoices/, "supplier_invoices"],
      [/\/admin\/supplier_payments/, "supplier_payments"],
      [/\/admin\/supplier_credit_notes/, "supplier_credits"],
      [/\/admin\/account_payables/, "payables"],
      [/\/admin\/purchase_orders/, "purchase_orders"],
      [/\/admin\/purchase_quotations/, "purchase_quotations"],
      [/\/admin\/purchase_requests/, "purchase_requests"],
      [/\/admin\/purchase_returns/, "purchase_returns"],
      [/\/admin\/suppliers/, "suppliers"],
      [/\/admin\/products/, "products"],
      [/\/admin\/categories/, "categories"],
      [/\/admin\/clients/, "clients"],
      [/\/admin\/branches/, "branches"],
      [/\/admin\/users/, "users"],
      [/\/admin\/languages/, "languages"],
      [/\/admin\/profile/, "profile"],
      [/\/admin\/onboarding/, "onboarding"],
      [/\/admin\/dashboard/, "dashboard"]
    ]
    this.context = matches.find(([pattern]) => pattern.test(path))?.[1] || ""
    const heading = document.querySelector("main h1")?.textContent?.trim()
    this.screenTarget.textContent = heading || this.labelsValue.topic || "Delta POS"
  }

  open() {
    this.previousFocus = document.activeElement
    this.panelTarget.hidden = false
    this.launcherTarget.setAttribute("aria-expanded", "true")
    this.closeButtonTarget.focus()
    this.mood("happy")
    this.detectContext()
  }

  close() {
    this.requestController?.abort()
    this.requestController = null
    this.panelTarget.hidden = true
    this.launcherTarget.setAttribute("aria-expanded", "false")
    this.stopSpeaking()
    this.resetSpotlight()
    this.mood("idle")
    if (this.previousFocus?.isConnected) this.previousFocus.focus()
  }

  keepFocus(event) {
    const elements = Array.from(this.panelTarget.querySelectorAll(
      "button:not([disabled]), input:not([disabled]), a[href]"
    )).filter((element) => !element.closest("[hidden]"))
    if (!elements.length) return
    const first = elements[0]
    const last = elements[elements.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  ask(event) {
    event.preventDefault()
    const message = this.questionTarget.value.trim()
    if (!message) return
    this.submitQuestion(message)
  }

  quickAsk(event) {
    const message = event.currentTarget.dataset.question || ""
    if (!message) return
    const question = message.includes("este módulo") && this.context
      ? this.context.replaceAll("_", " ") : message
    this.questionTarget.value = question
    this.submitQuestion(question)
    if (event.currentTarget.dataset.question?.includes("módulo")) this.spotlight()
  }

  async submitQuestion(message) {
    this.stopSpeaking()
    this.requestController?.abort()
    const request = new AbortController()
    this.requestController = request
    this.resultTarget.hidden = false
    this.replyTarget.textContent = this.labelsValue.processing || ""
    this.resultTitleTarget.textContent = this.labelsValue.found || ""
    this.stepsTarget.replaceChildren()
    this.noteTarget.hidden = true
    this.guideLinkTarget.hidden = true
    this.sendButtonTarget.disabled = true
    this.mood("thinking")

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ message, context: this.context }),
        signal: request.signal
      })
      if (!response.ok) throw new Error("assistant request failed")
      const result = await response.json()
      if (this.requestController !== request) return
      this.present(result)
    } catch (error) {
      if (error.name === "AbortError" || this.requestController !== request) return
      this.present({ reply: this.labelsValue.failed, mood: "concerned", steps: [] })
    } finally {
      if (this.requestController === request) {
        this.requestController = null
        this.sendButtonTarget.disabled = false
      }
    }
  }

  present(result) {
    this.replyTarget.textContent = result.reply || ""
    this.resultTitleTarget.textContent = result.title || this.labelsValue.found || ""
    this.stepsTarget.replaceChildren()
    const steps = Array.isArray(result.steps) ? result.steps : []
    steps.forEach((step, index) => {
      const li = document.createElement("li")
      li.className = "flex items-start gap-2 leading-6"
      const number = document.createElement("span")
      number.className = "flex size-6 shrink-0 items-center justify-center rounded-full bg-blue-600 text-xs font-bold text-white"
      number.textContent = String(index + 1)
      const body = document.createElement("span")
      body.textContent = String(step)
      li.append(number, body)
      this.stepsTarget.appendChild(li)
    })
    this.noteTarget.hidden = !result.note
    this.noteTarget.textContent = result.note || ""
    this.guideLinkTarget.hidden = !result.guide_url
    if (result.guide_url?.startsWith("/admin/guide")) this.guideLinkTarget.href = result.guide_url
    this.lastAnswer = [result.reply, ...steps].filter(Boolean).join(". ")
    this.mood(result.mood === "concerned" ? "concerned" : steps.length ? "happy" : "thinking")
    if (steps.length && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.mood("laughing")
      window.setTimeout(() => {
        if (this.element.dataset.mood === "laughing") this.mood("happy")
      }, 800)
    }
  }

  speak() {
    if (this.speech) {
      this.stopSpeaking()
      return
    }
    if (!this.lastAnswer || !("speechSynthesis" in window)) return
    window.speechSynthesis.cancel()
    const utterance = new SpeechSynthesisUtterance(this.lastAnswer)
    utterance.lang = this.localeValue === "ko" ? "ko-KR" : this.localeValue === "en" ? "en-US" : "es-MX"
    utterance.rate = 0.95
    utterance.onstart = () => {
      if (this.speech !== utterance) return
      this.mood("talking")
      this.speechButtonTarget.textContent = this.labelsValue.stopVoice
    }
    utterance.onend = () => this.finishSpeaking(utterance)
    utterance.onerror = () => this.finishSpeaking(utterance)
    this.speech = utterance
    window.speechSynthesis.speak(utterance)
  }

  finishSpeaking(utterance) {
    if (this.speech !== utterance) return
    this.speech = null
    this.speechButtonTarget.textContent = this.labelsValue.startVoice
    this.mood("happy")
  }

  stopSpeaking() {
    if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel()
    this.speech = null
    this.speechButtonTarget.textContent = this.labelsValue.startVoice
    if (this.element.dataset.mood === "talking") this.mood("idle")
  }

  mood(value) {
    this.element.dataset.mood = value
  }

  spotlight() {
    this.resetSpotlight()
    const selector = this.context === "products" ? 'a[href="/admin/products/new"]'
      : this.context === "suppliers" ? 'a[href="/admin/suppliers/new"]' : null
    if (!selector) return
    this.highlighted = document.querySelector(selector)
    this.highlighted?.classList.add("deltin-step-highlight")
  }

  resetSpotlight() {
    this.highlighted?.classList.remove("deltin-step-highlight")
    this.highlighted = null
  }
}
