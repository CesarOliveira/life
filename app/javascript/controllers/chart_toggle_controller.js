import { Controller } from "@hotwired/stimulus"

// Alterna entre gráficos (barras / linha) já renderizados no DOM, sem recarregar.
export default class extends Controller {
  static targets = ["chart", "button"]

  select(event) {
    const type = event.currentTarget.dataset.chartType
    this.chartTargets.forEach((c) => c.classList.toggle("hidden", c.dataset.chartType !== type))
    this.buttonTargets.forEach((b) => {
      const active = b.dataset.chartType === type
      b.classList.toggle("bg-emerald-600", active)
      b.classList.toggle("text-white", active)
      b.classList.toggle("text-slate-600", !active)
    })
  }
}
