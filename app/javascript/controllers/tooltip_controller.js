import { Controller } from "@hotwired/stimulus"

// Tooltip leve: elementos com data-tooltip-content mostram um balão ao passar
// o mouse (ou tocar). O balão vive FORA do container com scroll (não é
// cortado), fica preso aos limites visíveis e vira para baixo quando não há
// espaço acima.
export default class extends Controller {
  static targets = ["bubble"]

  show(event) {
    const el = event.currentTarget
    const content = el.dataset.tooltipContent
    if (!content) return

    const bubble = this.bubbleTarget
    bubble.textContent = content
    bubble.classList.remove("hidden")

    const root = this.element.getBoundingClientRect()
    const rect = el.getBoundingClientRect()

    // X centrado na célula, preso aos limites do card (não vaza da tela).
    const half = bubble.offsetWidth / 2
    let x = rect.left - root.left + rect.width / 2
    x = Math.min(Math.max(x, half + 4), root.width - half - 4)

    // Acima da célula; se não couber, abaixo.
    const above = rect.top - root.top > bubble.offsetHeight + 10
    bubble.style.left = `${x}px`
    if (above) {
      bubble.style.top = `${rect.top - root.top - 6}px`
      bubble.style.transform = "translate(-50%, -100%)"
    } else {
      bubble.style.top = `${rect.bottom - root.top + 6}px`
      bubble.style.transform = "translate(-50%, 0)"
    }
  }

  hide() {
    this.bubbleTarget.classList.add("hidden")
  }
}
