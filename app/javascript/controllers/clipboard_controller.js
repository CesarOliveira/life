import { Controller } from "@hotwired/stimulus"

// Copia um texto para a área de transferência com feedback rápido.
// Fonte do texto, em ordem:
//   1) fetchUrl (busca o texto inteiro só na hora de copiar — ex.: token mascarado)
//   2) o elemento `source`
// Feedback: troca o texto do `button` por "Copiado!", ou mostra o `feedback`.
export default class extends Controller {
  static targets = ["source", "button", "feedback"]
  static values = { copied: String, label: String, fetchUrl: String }

  // Não chama preventDefault: se o gatilho for um link de download, ele baixa
  // normalmente enquanto copiamos o texto em paralelo.
  async copy() {
    const text = await this.resolveText()
    try {
      await navigator.clipboard.writeText(text)
    } catch (_) {
      this.fallbackCopy(text)
    }
    this.flash()
  }

  async resolveText() {
    if (this.hasFetchUrlValue && this.fetchUrlValue) {
      try {
        const resp = await fetch(this.fetchUrlValue, { headers: { Accept: "text/plain" }, credentials: "same-origin" })
        return (await resp.text()).trim()
      } catch (_) {
        // cai para a fonte local
      }
    }
    return (this.hasSourceTarget ? this.sourceTarget.textContent : "").trim()
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
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.classList.remove("hidden")
      clearTimeout(this.resetTimer)
      this.resetTimer = setTimeout(() => this.feedbackTarget.classList.add("hidden"), 2500)
      return
    }
    if (!this.hasButtonTarget) return
    const original = this.labelValue || this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedValue || "Copiado!"
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.buttonTarget.textContent = original
    }, 1500)
  }
}
