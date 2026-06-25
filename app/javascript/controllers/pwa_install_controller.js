import { Controller } from "@hotwired/stimulus"

// Banner para facilitar a instalação como PWA.
// - Android/Chrome: captura o evento `beforeinstallprompt` e mostra um botão
//   "Instalar" que dispara o prompt nativo.
// - iOS Safari: não há prompt nativo, então mostra a instrução
//   "Compartilhar → Adicionar à Tela de Início".
// - Esconde-se se já estiver instalado (standalone) ou se foi dispensado.
export default class extends Controller {
  static targets = ["banner", "hint", "installButton"]

  connect() {
    this.deferredPrompt = null
    if (this.isStandalone() || this.dismissed()) return

    this.onBeforeInstall = (event) => {
      event.preventDefault()
      this.deferredPrompt = event
      this.installButtonTarget.classList.remove("hidden")
      this.show()
    }
    window.addEventListener("beforeinstallprompt", this.onBeforeInstall)

    if (this.isIosSafari()) {
      this.hintTarget.textContent = this.hintTarget.dataset.iosText
      this.show()
    }
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.onBeforeInstall)
  }

  async install() {
    if (!this.deferredPrompt) return
    this.deferredPrompt.prompt()
    await this.deferredPrompt.userChoice
    this.deferredPrompt = null
    this.hide()
  }

  dismiss() {
    try {
      localStorage.setItem("pwa-install-dismissed", "1")
    } catch (_) {
      // localStorage indisponível (modo privado antigo) — apenas esconde.
    }
    this.hide()
  }

  show() {
    this.bannerTarget.classList.remove("hidden")
  }

  hide() {
    this.bannerTarget.classList.add("hidden")
  }

  dismissed() {
    try {
      return localStorage.getItem("pwa-install-dismissed") === "1"
    } catch (_) {
      return false
    }
  }

  isStandalone() {
    return (
      window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true
    )
  }

  isIosSafari() {
    const ua = window.navigator.userAgent
    const ios =
      /iPad|iPhone|iPod/.test(ua) ||
      (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
    const webkit = /WebKit/.test(ua)
    const otherBrowser = /CriOS|FxiOS|EdgiOS|OPiOS/.test(ua)
    return ios && webkit && !otherBrowser
  }
}
