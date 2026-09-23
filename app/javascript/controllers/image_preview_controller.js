import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "preview"]

  connect() {
    this.input = this.fileTarget
    this.previewElement = this.previewTarget
  }

  update(event) {
    const file = event.target.files[0]

    if (!file) {
      this.clearPreview()
      return
    }

    if (!file.type.startsWith("image/")) {
      this.clearPreview()
      return
    }

    const reader = new FileReader()

    reader.onload = (e) => {
      this.showPreview(e.target.result, file.name)
    }

    reader.readAsDataURL(file)
  }

  showPreview(dataURL, filename) {
    if (!this.previewElement) return

    this.previewElement.innerHTML = `
      <div class="mt-2">
        <div class="mb-2 flex items-center gap-2">
          <img src="${dataURL}" class="h-24 w-24 rounded-lg object-cover border border-slate-200" alt="Preview">
          <div class="flex-1">
            <p class="text-sm font-medium text-slate-700">${filename}</p>
            <p class="text-xs text-slate-500">Click to change</p>
          </div>
        </div>
      </div>
    `
  }

  clearPreview() {
    if (this.previewElement) {
      this.previewElement.innerHTML = ""
    }
  }
}