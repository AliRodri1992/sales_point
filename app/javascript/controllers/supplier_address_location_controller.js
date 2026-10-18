import { Controller } from "@hotwired/stimulus"

// Only authenticated same-origin Rails endpoints receive map requests. The
// geocoding proposal and its confidence are verified again on the server.
export default class extends Controller {
  static targets = ["latitude", "longitude", "signature", "confirmed", "mapImage",
    "mapPlaceholder", "mapClick", "pin", "lookupButton", "confirmButton", "status",
    "reviewFields", "reviewNotice", "reviewed", "reasonError"]
  static values = {
    suggestUrl: String, mapUrl: String, unavailable: String, ready: String,
    confirmed: String, searching: String, lowConfidence: String, adjusted: String,
    reviewRequired: String, confidence: Number
  }

  connect() {
    this.point = this.savedPoint()
    this.mapCenter = this.point ? { ...this.point } : null
    this.suggestedPoint = this.point ? { ...this.point } : null
    this.zoomLevel = 15
    this.confidence = this.hasConfidenceValue ? this.confidenceValue : 1
    this.drag = null
    this.suppressClick = false
    this.pending = false
    this.request = null
    this.showMap()
  }

  disconnect() {
    this.request?.abort()
    this.drag = null
  }

  savedPoint() {
    const lat = Number(this.latitudeTarget.value)
    const lon = Number(this.longitudeTarget.value)
    return this.latitudeTarget.value && this.longitudeTarget.value &&
      this.valid(lat, lon) ? { lat, lon } : null
  }

  valid(lat, lon) {
    return Number.isFinite(lat) && Number.isFinite(lon) &&
      lat >= -85 && lat <= 85 && lon >= -180 && lon <= 180
  }

  changed(event) {
    const name = event.target.name || ""
    if (!this.geographicFields().some((field) => name.endsWith("[" + field + "]"))) return

    this.request?.abort()
    this.request = null
    this.pending = false
    this.lookupButtonTarget.disabled = false
    this.point = null
    this.suggestedPoint = null
    this.mapCenter = null
    this.confidence = 1
    this.latitudeTarget.value = ""
    this.longitudeTarget.value = ""
    this.signatureTarget.value = ""
    this.confirmedTarget.value = "0"
    this.reviewedTarget.checked = false
    this.clearReasonError()
    this.showMap()
  }

  geographicFields() {
    return ["street", "exterior_number", "interior_number", "neighborhood",
      "city", "state", "postal_code", "country_id"]
  }

  addressSnapshot() {
    const body = new URLSearchParams()
    for (const field of this.geographicFields()) {
      body.append("address[" + field + "]",
        this.element.querySelector('[name="address[' + field + ']"]')?.value || "")
    }
    return body.toString()
  }

  async lookup() {
    if (this.pending) return
    const snapshot = this.addressSnapshot()
    const request = new AbortController()
    this.request = request
    this.pending = true
    this.lookupButtonTarget.disabled = true
    this.statusTarget.textContent = this.searchingValue
    try {
      const response = await fetch(this.suggestUrlValue, {
        method: "POST", body: new URLSearchParams(snapshot),
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
      this.suggestedPoint = { ...this.point }
      this.mapCenter = { ...this.point }
      this.confidence = Number.isFinite(Number(data.confidence)) ? Number(data.confidence) : 0
      this.confirmedTarget.value = "0"
      this.reviewedTarget.checked = false
      this.statusTarget.textContent = this.confidence < 0.8 ? this.lowConfidenceValue : this.readyValue
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

  // Web Mercator uses 512px Mapbox tiles at the requested zoom level.
  project(point) {
    const size = 512 * 2 ** this.zoomLevel
    const rad = Math.max(-85, Math.min(85, point.lat)) * Math.PI / 180
    return { x: (point.lon + 180) / 360 * size,
      y: (1 - Math.asinh(Math.tan(rad)) / Math.PI) / 2 * size }
  }

  unproject(point) {
    const size = 512 * 2 ** this.zoomLevel
    const lon = (point.x / size * 360 - 180 + 540) % 360 - 180
    const lat = Math.atan(Math.sinh(Math.PI * (1 - 2 * point.y / size))) * 180 / Math.PI
    return { lat: Math.max(-85, Math.min(85, lat)), lon }
  }

  fromScreen(x, y, rect) {
    const center = this.project(this.mapCenter)
    return this.unproject({ x: center.x + (x - rect.left - rect.width / 2) * 600 / rect.width,
      y: center.y + (y - rect.top - rect.height / 2) * 300 / rect.height })
  }

  positionPin() {
    if (!this.point || !this.mapCenter) return
    const rect = this.mapClickTarget.getBoundingClientRect()
    const center = this.project(this.mapCenter)
    const marker = this.project(this.point)
    const world = 512 * 2 ** this.zoomLevel
    let dx = marker.x - center.x
    if (dx > world / 2) dx -= world
    if (dx < -world / 2) dx += world
    const x = 50 + dx / 600 * 100
    const y = 50 + (marker.y - center.y) / 300 * 100
    this.pinTarget.style.left = x + "%"
    this.pinTarget.style.top = y + "%"
    this.pinTarget.classList.toggle("hidden", x < 0 || x > 100 || y < 0 || y > 100)
    if (rect.width) this.toggleReview()
  }

  showMap() {
    const visible = !!this.point
    this.mapPlaceholderTarget.classList.toggle("hidden", visible)
    this.mapImageTarget.classList.toggle("hidden", !visible)
    this.mapClickTarget.classList.toggle("hidden", !visible)
    this.confirmButtonTarget.classList.toggle("hidden", !visible)
    if (!visible) {
      this.pinTarget.classList.add("hidden")
      this.reviewFieldsTarget.classList.add("hidden")
      this.reviewNoticeTarget.classList.add("hidden")
      this.mapImageTarget.removeAttribute("src")
      return
    }
    this.mapCenter ||= { ...this.point }
    const url = new URL(this.mapUrlValue, window.location.href)
    url.searchParams.set("latitude", this.mapCenter.lat)
    url.searchParams.set("longitude", this.mapCenter.lon)
    url.searchParams.set("zoom", String(this.zoomLevel))
    this.mapImageTarget.src = url.toString()
    this.mapImageTarget.style.transform = ""
    this.positionPin()
  }

  moveMarker(point) {
    if (!this.signatureTarget.value || !this.valid(point.lat, point.lon)) return
    this.point = point
    this.confirmedTarget.value = "0"
    this.statusTarget.textContent = this.adjustedValue
    this.positionPin()
  }

  adjust(event) {
    if (this.suppressClick) {
      this.suppressClick = false
      return
    }
    if (!this.mapCenter || !this.signatureTarget.value) return
    const rect = event.currentTarget.getBoundingClientRect()
    this.moveMarker(this.fromScreen(event.clientX, event.clientY, rect))
  }

  dragStart(event) {
    if ((event.pointerType === 'mouse' && event.button !== 0) || !this.mapCenter || !this.point) return
    const rect = event.currentTarget.getBoundingClientRect()
    const center = this.project(this.mapCenter)
    const marker = this.project(this.point)
    const markerX = rect.left + rect.width / 2 + (marker.x - center.x) * rect.width / 600
    const markerY = rect.top + rect.height / 2 + (marker.y - center.y) * rect.height / 300
    const nearMarker = Math.hypot(event.clientX - markerX, event.clientY - markerY) <= 28
    this.drag = { x: event.clientX, y: event.clientY,
      center: { ...this.mapCenter }, point: { ...this.point },
      mode: nearMarker ? "marker" : "pan" }
    event.currentTarget.setPointerCapture?.(event.pointerId)
  }

  dragMove(event) {
    if (!this.drag) return
    const dx = event.clientX - this.drag.x
    const dy = event.clientY - this.drag.y
    const rect = event.currentTarget.getBoundingClientRect()
    if (this.drag.mode === "marker") {
      this.moveMarker(this.fromScreen(event.clientX, event.clientY, rect))
    } else {
      const start = this.project(this.drag.center)
      this.mapCenter = this.unproject({ x: start.x - dx * 600 / rect.width,
        y: start.y - dy * 300 / rect.height })
      this.mapImageTarget.style.transform = "translate(" + dx + "px," + dy + "px)"
      this.positionPin()
    }
  }

  dragEnd(event) {
    if (!this.drag) return
    const distance = Math.hypot(event.clientX - this.drag.x, event.clientY - this.drag.y)
    const movedMap = this.drag.mode === "pan" && distance > 4
    this.drag = null
    if (distance > 4) this.suppressClick = true
    if (movedMap) this.showMap()
  }

  dragCancel() {
    this.drag = null
    if (this.mapCenter) this.showMap()
  }

  nudge(event) {
    const directions = { ArrowLeft: [-10, 0], ArrowRight: [10, 0],
      ArrowUp: [0, -10], ArrowDown: [0, 10] }
    if (!directions[event.key] || !this.point || !this.signatureTarget.value) return
    event.preventDefault()
    const rect = event.currentTarget.getBoundingClientRect()
    const [dx, dy] = directions[event.key]
    if (event.shiftKey) {
      this.panPixels(dx, dy)
    } else {
      const point = this.project(this.point)
      this.moveMarker(this.unproject({ x: point.x + dx * 600 / rect.width,
        y: point.y + dy * 300 / rect.height }))
    }
  }

  panPixels(dx, dy) {
    if (!this.mapCenter) return
    const center = this.project(this.mapCenter)
    this.mapCenter = this.unproject({ x: center.x + dx, y: center.y + dy })
    this.showMap()
  }

  panDirection(event) {
    const vectors = { up: [0, -90], down: [0, 90], left: [-120, 0], right: [120, 0] }
    const [dx, dy] = vectors[event.currentTarget.dataset.direction] || [0, 0]
    this.panPixels(dx, dy)
  }

  zoomIn() {
    this.zoomLevel = Math.min(this.zoomLevel + 1, 18)
    if (this.point) this.showMap()
  }

  zoomOut() {
    this.zoomLevel = Math.max(this.zoomLevel - 1, 12)
    if (this.point) this.showMap()
  }

  wheelZoom(event) {
    if (!this.point) return
    event.preventDefault()
    if (event.deltaY < 0) this.zoomIn()
    if (event.deltaY > 0) this.zoomOut()
  }

  distanceKm() {
    if (!this.point || !this.suggestedPoint) return 0
    const radians = (degrees) => degrees * Math.PI / 180
    const lat = radians(this.point.lat - this.suggestedPoint.lat)
    const lon = radians(this.point.lon - this.suggestedPoint.lon)
    const a = Math.sin(lat / 2) ** 2 +
      Math.cos(radians(this.suggestedPoint.lat)) * Math.cos(radians(this.point.lat)) *
      Math.sin(lon / 2) ** 2
    return 12742 * Math.asin(Math.sqrt(Math.min(1, a)))
  }

  toggleReview() {
    const required = this.confidence < 0.8 || this.distanceKm() > 2
    this.reviewFieldsTarget.classList.toggle("hidden", !required)
    this.reviewNoticeTarget.classList.toggle("hidden", !required)
    if (!required) this.reviewedTarget.checked = false
  }

  clearReasonError() {
    if (!this.hasReasonErrorTarget) return
    this.reasonErrorTarget.classList.add("hidden")
    const reason = this.element.querySelector('[name="address[location_adjustment_reason]"]')
    reason?.removeAttribute("aria-invalid")
  }

  validateReason() {
    const reason = this.element.querySelector('[name="address[location_adjustment_reason]"]')
    if (reason?.value.trim()) {
      this.clearReasonError()
      return true
    }
    if (this.hasReasonErrorTarget) this.reasonErrorTarget.classList.remove("hidden")
    reason?.setAttribute("aria-invalid", "true")
    reason?.focus()
    return false
  }

  confirm() {
    if (!this.point || !this.signatureTarget.value) return
    if (!this.validateReason()) return
    if (this.distanceKm() > 25) {
      this.statusTarget.textContent = this.unavailableValue
      return
    }
    if (!this.reviewFieldsTarget.classList.contains("hidden")) {
      const reason = this.element.querySelector('[name="address[location_adjustment_reason]"]')
      if (!this.reviewedTarget.checked || reason.value.trim().length < 10) {
        this.statusTarget.textContent = this.reviewRequiredValue
        reason.focus()
        return
      }
    }
    this.latitudeTarget.value = this.point.lat.toFixed(6)
    this.longitudeTarget.value = this.point.lon.toFixed(6)
    this.confirmedTarget.value = "1"
    this.statusTarget.textContent = this.confirmedValue
  }
}
