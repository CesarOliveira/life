import { Controller } from "@hotwired/stimulus"

// Modal com <dialog> nativo: botão abre, X/Cancelar fecham, clique no
// backdrop fecha.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Fecha ao clicar fora do conteúdo (no backdrop do próprio <dialog>).
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
