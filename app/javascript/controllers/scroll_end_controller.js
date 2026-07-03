import { Controller } from "@hotwired/stimulus"

// Rola o container horizontal até o fim ao carregar — no heatmap, deixa a
// semana ATUAL visível (alinhada à direita) sem precisar arrastar no celular.
export default class extends Controller {
  connect() {
    requestAnimationFrame(() => {
      this.element.scrollLeft = this.element.scrollWidth
    })
  }
}
