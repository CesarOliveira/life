import { Controller } from "@hotwired/stimulus"

// Checklist persistente em localStorage (sem servidor). Cada item tem um
// data-key; o estado marcado/desmarcado sobrevive a recarregar a página.
export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.itemTargets.forEach((cb) => {
      if (this.read(cb)) cb.checked = true
      this.reflect(cb)
    })
  }

  toggle(event) {
    const cb = event.target
    this.write(cb, cb.checked)
    this.reflect(cb)
  }

  reflect(cb) {
    const row = cb.closest("[data-checklist-row]")
    if (row) row.classList.toggle("opacity-50", cb.checked)
  }

  key(cb) {
    return `setup-check:${cb.dataset.key}`
  }

  read(cb) {
    try {
      return localStorage.getItem(this.key(cb)) === "1"
    } catch (_) {
      return false
    }
  }

  write(cb, checked) {
    try {
      localStorage.setItem(this.key(cb), checked ? "1" : "0")
    } catch (_) {
      // localStorage indisponível — apenas ignora
    }
  }
}
