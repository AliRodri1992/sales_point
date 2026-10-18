import { Controller } from "@hotwired/stimulus"

// Mapbox imagery is served by our authenticated Rails proxy; no token in the browser.
export default class extends Controller {
  static targets = ["latitude", "longitude", "signature", "confirmed", "mapImage",
    "mapPlaceholder", "mapClick", "pin", "lookupButton", "confirmButton", "status"]
  static values = {
    suggestUrl: String, mapUrl: String, unavailable: String, ready: String,
    confirmed: String, searching: String
  }

  connect() {
    this.point = this.savedPoint()
    this.mapCenter = this.point
    this.zoomLevel = 15
    this.dragOrigin = null
    this.suppressClick = false
    this.pending = false
    this.request = null
    if (this.point) this.showMap()
  }

  disconnect() {
    this.request?.abort()
  }

  savedPoint() {
    const lat = Number(this.latitudeTarget.value)
    const lon = Number(this.longitudeTarget.value)
    return this.latitudeTarget.value && this.longitudeTarget.value &&
      this.valid(lat, lon) ? { lat, lon } : null
  }

  valid(lat, lon) {
    return Number.isFinite(lat) && Number.isFinite(lon) &&
      lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
  }

  changed(event) {
    const name = event.target.name || ""
    const geographic = ["street", "exterior_number", "interior_number", "neighborhood",
      "city", "state", "postal_code", "country_id"]
    if (!geographic.some((field) => name.endsWith("[" + field + "]"))) return

    this.request?.abort()
    this.request = null
    this.pending = false
    this.lookupButtonTarget.disabled = false
    this.point = null
    this.mapCenter = null
    this.latitudeTarget.value = ""
    this.longitudeTarget.value = ""
    this.signatureTarget.value = ""
    this.confirmedTarget.value = "0"
    this.confirmButtonTarget.classList.add("hidden")
    this.showMap()
  }

  async lookup() {
    if (this.pending) return

    const body = new URLSearchParams()
    for (const field of ["street", "exterior_number", "interior_number", "neighborhood",
      "city", "state", "postal_code", "country_id"]) {
      const value = this.element.querySelector('[name="address[' + field + ']"]')?.value || ""
      body.append("address[" + field + "]", value)
    }
    const snapshot = body.toString()
    const request = new AbortController()
    this.request = request
    this.pending = true
    this.lookupButtonTarget.disabled = true
    this.statusTarget.textContent = this.searchingValue
    try {
      const response = await fetch(this.suggestUrlValue, {
        method: "POST", body,
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "",
          Accept: "application/json"
        }, credentials: "same-origin", signal: request.signal
      })
      if (!response.ok) throw new Error("Location lookup failed")
      const data = await response.json()
      if (request !== this.request || snapshot !== this.addressSnapshot()) return
      if (!this.valid(Number(data.latitude), Number(data.longitude))) throw new Error("Invalid coordinates")
      this.signatureTarget.value = data.signature
      this.point = { lat: Number(data.latitude), lon: Number(data.longitude) }
      this.confirmedTarget.value = "0"
      this.statusTarget.textContent = this.readyValue
      this.showMap()
    } catch (error) {
      if (error.name !== "AbortError" && request === this.request) {
        this.statusTarget.textContent = this.unavailableValue
      }
    } finally {
      if (request === this.request) {
        this.request = null
        this.pending = false
        this.lookupButtonTarget.disabled = false
      }
    }
  }

  addressSnapshot() {
    const body = new URLSearchParams()
    for (const field of ["street", "exterior_number", "interior_number", "neighborhood",
      "city", "state", "postal_code", "country_id"]) {
      body.append("address[" + field + "]", this.element.querySelector('[name="address[' + field + ']"]')?.value || "")
    }
    return body.toString()
  }

  showMap() {
    const visible = !!this.point
    this.mapPlaceholderTarget.classList.toggle("hidden", visible)
    this.mapImageTarget.classList.toggle("hidden", !visible)
    this.mapClickTarget.classList.toggle("hidden", !visible)
    this.pinTarget.classList.toggle("hidden", !visible)
    this.confirmButtonTarget.classList.toggle("hidden", !visible)
    if (!visible) {
      this.mapImageTarget.removeAttribute("src")
      return
    }

    this.mapCenter = { ...this.point }
    const url = new URL(this.mapUrlValue, window.location.href)
    url.searchParams.set("latitude", this.mapCenter.lat)
    url.searchParams.set("longitude", this.mapCenter.lon)
    url.searchParams.set("zoom", String(this.zoomLevel))
    this.mapImageTarget.src = url.toString()
  }

  adjust(event) {
    if (event.type === 'click' && this.suppressClick) {
      this.suppressClick = false
      return
    }
    if (!this.mapCenter || !this.signatureTarget.value) return

    const rect = event.currentTarget.getBoundingClientRect()
    const scale = 512 * 2 ** this.zoomLevel
    const latRad = this.mapCenter.lat * Math.PI / 180
    const centerX = (this.mapCenter.lon + 180) / 360 * scale
    const centerY = (1 - Math.asinh(Math.tan(latRad)) / Math.PI) / 2 * scale
    const x = centerX + (event.clientX - rect.left - rect.width / 2) * 600 / rect.width
    const y = centerY + (event.clientY - rect.top - rect.height / 2) * 300 / rect.height
    const lon = Math.max(-180, Math.min(180, x / scale * 360 - 180))
    const lat = Math.atan(Math.sinh(Math.PI * (1 - 2 * y / scale))) * 180 / Math.PI
    if (!this.valid(lat, lon)) return

    this.point = { lat, lon }
    this.confirmedTarget.value = "0"
    this.statusTarget.textContent = this.readyValue
    this.showMap()
  }

  zoomIn() {
    this.zoomLevel = Math.min(this.zoomLevel + 1, 18)
    if (this.point) this.showMap()
  }

  zoomOut() {
    this.zoomLevel = Math.max(this.zoomLevel - 1, 12)
    if (this.point) this.showMap()
  }

  dragStart(event) {
    if (event.button !== 0 || !this.mapCenter) return
    this.dragOrigin = { x: event.clientX, y: event.clientY }
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  dragEnd(event) {
    if (!this.dragOrigin) return
    const moved = Math.hypot(event.clientX - this.dragOrigin.x, event.clientY - this.dragOrigin.y)
    this.dragOrigin = null
    if (moved > 4) {
      this.adjust(event)
      this.suppressClick = true
    }
  }

  nudge(event) {
    const directions = {
      ArrowLeft: [-10, 0], ArrowRight: [10, 0],
      ArrowUp: [0, -10], ArrowDown: [0, 10]
    }
    if (!directions[event.key] || !this.point || !this.signatureTarget.value) return
    event.preventDefault()
    const rect = event.currentTarget.getBoundingClientRect()
    const [dx, dy] = directions[event.key]
    this.adjust({ currentTarget: event.currentTarget,
      clientX: rect.left + rect.width / 2 + dx,
      clientY: rect.top + rect.height / 2 + dy })
  }

  confirm() {
    if (!this.point || !this.signatureTarget.value) return

    this.latitudeTarget.value = this.point.lat.toFixed(6)
    this.longitudeTarget.value = this.point.lon.toFixed(6)
    this.confirmedTarget.value = "1"
    this.statusTarget.textContent = this.confirmedValue
  }
}
