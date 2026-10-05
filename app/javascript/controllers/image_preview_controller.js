import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "preview"]

  connect() {}

  update(event) {
    const file = event.target.files[0]

    if (!file || !file.type.startsWith("image/")) {
      return
    }

    const reader = new FileReader()

    reader.onload = (e) => {
      this.previewElement.innerHTML = `
        <div class="flex-shrink-0">
          <div class="h-20 w-20 rounded-lg object-cover border border-slate-200 bg-slate-50">
            <img src="${e.target.result}" class="h-20 w-20 rounded-lg object-cover" alt="Preview">
          </div>
          <p class="mt-1 text-xs text-slate-500 truncate max-w-20 text-center">${file.name}</p>
        </div>
      `
    }

    reader.readAsDataURL(file)
  }
}