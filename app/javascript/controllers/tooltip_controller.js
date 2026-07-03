import { Controller } from "@hotwired/stimulus"

// Tooltip leve: elementos com data-tooltip-content mostram um balão ao passar
// o mouse (ou tocar). Posicionado acima do elemento, dentro do controller.
export default class extends Controller {
  static targets = ["bubble"]

  show(event) {
    const el = event.currentTarget
    const content = el.dataset.tooltipContent
    if (!content) return

    this.bubbleTarget.textContent = content
    this.bubbleTarget.classList.remove("hidden")

    const root = this.element.getBoundingClientRect()
    const rect = el.getBoundingClientRect()
    this.bubbleTarget.style.left = `${rect.left - root.left + rect.width / 2}px`
    this.bubbleTarget.style.top = `${rect.top - root.top - 6}px`
  }

  hide() {
    this.bubbleTarget.classList.add("hidden")
  }
}
