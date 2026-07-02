import { Controller } from "@hotwired/stimulus"

// Linha expansível (accordeon): clique alterna o painel de detalhes.
export default class extends Controller {
  static targets = ["panel", "chevron"]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    if (this.hasChevronTarget) this.chevronTarget.classList.toggle("rotate-90")
  }
}
