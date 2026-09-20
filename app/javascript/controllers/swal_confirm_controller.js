import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// SweetAlert2 integration for the admin language catalog.
//
// 1) Replaces Turbo's native window.confirm with a SweetAlert2 dialog for any form
//    that carries a data-turbo-confirm attribute (e.g. the delete button).
// 2) Registers a custom "swal" Turbo Stream action so the server can drive a
//    success toast from a Turbo Stream response (create/update/delete) without a
//    full page reload. This is more reliable than listening for turbo:submit-end,
//    because the toast fires exactly when the response is processed.
//
// Both registrations are module-level and guarded so re-evaluation cannot double
// register the stream action or reset the confirm override.
if (!Turbo.StreamActions.swal) {
    Turbo.StreamActions.swal = function () {
        const message = this.templateContent ? this.templateContent.textContent : ""
        if (!message) return

        window.Swal.fire({
            toast: true,
            icon: "success",
            position: "top-end",
            timer: 2600,
            showConfirmButton: false,
            timerProgressBar: true,
            html: message.trim(),
            locale: document.documentElement.lang || "en"
        })
    }
}

let confirmConfigured = false

export default class extends Controller {
    connect() {
        if (confirmConfigured) return
        confirmConfigured = true

        Turbo.config.forms.confirm = (message) =>
            window.Swal.fire({
                icon: "warning",
                title: message,
                showCancelButton: true,
                reverseButtons: true,
                focusCancel: true,
                confirmButtonColor: "#dc2626",
                cancelButtonColor: "#64748b",
                cancelButtonText: this.element.dataset.swalCancelText || "Cancel",
                locale: document.documentElement.lang || "en"
            }).then((result) => result.isConfirmed)
    }
}
