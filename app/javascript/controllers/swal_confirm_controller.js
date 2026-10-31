import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Unified, compact confirmation for every data-turbo-confirm action in Delta POS.
// Keep text-only data separate from trusted icon markup (no user HTML injection).
const REMOVE_MESSAGE = /^(¿Quieres retirar este registro\?\s*Revisa su información antes de confirmar\.|Do you want to remove this record\?\s*Review its information before confirming\.|이 기록을 목록에서 제외하시겠습니까\?\s*확인하기 전에 정보를 검토하세요\.)$/i

const ICONS = {
  danger: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14M10 11v7m4-7v7"/></svg>',
  neutral: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.7 2.7 0 0 1 5 1.5c0 1.8-2.5 2-2.5 4M12 18h.01"/></svg>'
}

function language() {
  return (document.documentElement.lang || "es").split("-")[0].toLowerCase()
}

function copy() {
  const local = {
    es: {
      removeTitle: "¿Retirar este registro?", removeDescription: "Se quitará de la lista activa.",
      deleteTitle: "¿Eliminar este registro?", actionTitle: "¿Confirmar esta acción?",
      confirmRemove: "Sí, retirar", confirmDelete: "Sí, eliminar", confirmAction: "Confirmar",
      cancel: "Cancelar"
    },
    en: {
      removeTitle: "Remove this record?", removeDescription: "It will be removed from the active list.",
      deleteTitle: "Delete this record?", actionTitle: "Confirm this action?",
      confirmRemove: "Yes, remove", confirmDelete: "Yes, delete", confirmAction: "Confirm",
      cancel: "Cancel"
    },
    ko: {
      removeTitle: "이 기록을 제외할까요?", removeDescription: "활성 목록에서 제외됩니다.",
      deleteTitle: "이 기록을 삭제할까요?", actionTitle: "이 작업을 확인할까요?",
      confirmRemove: "예, 제외", confirmDelete: "예, 삭제", confirmAction: "확인",
      cancel: "취소"
    }
  }
  return local[language()] || local.es
}

function actionMethod(element, submitter) {
  const source = submitter || element
  const form = source?.form || (element?.tagName === "FORM" ? element : source?.closest?.("form"))
  const override = form?.querySelector('input[name="_method"]')?.value
  return String(source?.dataset?.turboMethod || override || form?.method || "").toLowerCase()
}

function sourceData(element, submitter, key) {
  const source = submitter || element
  const form = source?.form || (element?.tagName === "FORM" ? element : source?.closest?.("form"))
  return source?.dataset?.[key] || element?.dataset?.[key] || form?.dataset?.[key] || ""
}

export function confirmationOptions(message, element, submitter) {
  const original = String(message || "").trim()
  const translations = copy()
  const genericRemove = REMOVE_MESSAGE.test(original)
  const removal = genericRemove || /\b(retirar|retire|remove|archive|archivar|excluir)\b/i.test(original) ||
    /제외|보관/.test(original)
  const destructive = removal || actionMethod(element, submitter) === "delete" ||
    /\b(eliminar|borrar|delete|destroy|supprimer)\b/i.test(original) || /삭제/.test(original)
  const title = sourceData(element, submitter, "confirmTitle") ||
    (removal ? translations.removeTitle : destructive ? translations.deleteTitle : translations.actionTitle)
  const record = sourceData(element, submitter, "confirmRecord").trim()
  const description = genericRemove ? translations.removeDescription : original

  return {
    title,
    text: record ? `${record}\n${description}` : description,
    icon: destructive ? "warning" : "question",
    iconHtml: destructive ? ICONS.danger : ICONS.neutral,
    showCancelButton: true,
    showConfirmButton: true,
    reverseButtons: true,
    focusCancel: true,
    buttonsStyling: false,
    heightAuto: false,
    width: "min(32rem, calc(100vw - 2rem))",
    padding: "0",
    confirmButtonText: removal ? translations.confirmRemove :
      destructive ? translations.confirmDelete : translations.confirmAction,
    cancelButtonText: document.body?.dataset?.swalCancelText || translations.cancel,
    customClass: {
      popup: `delta-confirm-popup ${destructive ? "delta-confirm-danger" : "delta-confirm-neutral"}`,
      icon: "delta-confirm-icon",
      title: "delta-confirm-title",
      htmlContainer: "delta-confirm-description",
      actions: "delta-confirm-actions",
      confirmButton: "delta-confirm-accept",
      cancelButton: "delta-confirm-cancel"
    }
  }
}

function confirmWithSwal(message, element, submitter) {
  if (!window.Swal) return Promise.resolve(window.confirm(String(message)))
  return window.Swal.fire(confirmationOptions(message, element, submitter))
    .then((result) => result.isConfirmed)
}

// Install once for every Turbo form; individual pages need no extra controller.
Turbo.config.forms.confirm = confirmWithSwal

if (!Turbo.StreamActions.swal) {
  Turbo.StreamActions.swal = function () {
    const message = this.templateContent ? this.templateContent.textContent : ""
    if (!message) return

    window.Swal?.fire({
      toast: true, icon: "success", position: "top-end",
      timer: 2600, showConfirmButton: false,
      timerProgressBar: true, text: message.trim()
    })
  }
}

export default class extends Controller {
  connect() {
    // Some pages reconnect after Turbo navigation; keep the same shared callback.
    Turbo.config.forms.confirm = confirmWithSwal
  }
}
