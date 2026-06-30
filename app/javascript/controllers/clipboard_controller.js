import { Controller } from "@hotwired/stimulus"

// Copia o conteúdo de `source` para a área de transferência e dá um feedback
// rápido no botão ("Copiado!"). Usa a Clipboard API com fallback p/ execCommand.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copied: String, label: String }

  async copy() {
    const text = (this.sourceTarget.textContent || "").trim()
    try {
      await navigator.clipboard.writeText(text)
    } catch (_) {
      this.fallbackCopy(text)
    }
    this.flash()
  }

  fallbackCopy(text) {
    const area = document.createElement("textarea")
    area.value = text
    area.setAttribute("readonly", "")
    area.style.position = "absolute"
    area.style.left = "-9999px"
    document.body.appendChild(area)
    area.select()
    try {
      document.execCommand("copy")
    } catch (_) {
      // sem clipboard disponível — nada a fazer
    }
    document.body.removeChild(area)
  }

  flash() {
    if (!this.hasButtonTarget) return
    const original = this.labelValue || this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedValue || "Copiado!"
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.buttonTarget.textContent = original
    }, 1500)
  }
}
