import { Controller } from "@hotwired/stimulus"

// Facilita instalar como PWA. Mostra um banner e também responde ao item
// "Instalar app" do menu da conta (ação promptInstall).
// - Android/Chrome/desktop: usa o evento `beforeinstallprompt` (prompt nativo).
// - iOS (qualquer navegador — todos usam WebKit): não há prompt nativo, então
//   mostra a instrução "Compartilhar → Adicionar à Tela de Início".
// - Esconde-se se já instalado (standalone) ou dispensado (localStorage).
export default class extends Controller {
  static targets = ["banner", "hint", "installButton", "menuItem"]

  connect() {
    this.deferredPrompt = null

    this.onBeforeInstall = (event) => {
      event.preventDefault()
      this.deferredPrompt = event
      if (this.hasInstallButtonTarget) this.installButtonTarget.classList.remove("hidden")
      if (!this.isStandalone() && !this.dismissed()) this.show()
    }
    window.addEventListener("beforeinstallprompt", this.onBeforeInstall)

    if (this.isStandalone()) {
      if (this.hasMenuItemTarget) this.menuItemTarget.classList.add("hidden")
      return
    }

    // iOS não dispara beforeinstallprompt em nenhum navegador → instrução manual.
    if (this.isIos() && !this.dismissed()) {
      this.useIosHint()
      this.show()
    }
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.onBeforeInstall)
  }

  // Acionado pelo item "Instalar app" do menu.
  promptInstall() {
    this.undismiss()
    if (this.deferredPrompt) {
      this.install()
    } else {
      if (this.isIos()) this.useIosHint()
      this.show()
    }
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
      // localStorage indisponível — apenas esconde.
    }
    this.hide()
  }

  undismiss() {
    try {
      localStorage.removeItem("pwa-install-dismissed")
    } catch (_) {
      // ignore
    }
  }

  useIosHint() {
    if (this.hasHintTarget) this.hintTarget.textContent = this.hintTarget.dataset.iosText
  }

  show() {
    if (this.hasBannerTarget) this.bannerTarget.classList.remove("hidden")
  }

  hide() {
    if (this.hasBannerTarget) this.bannerTarget.classList.add("hidden")
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

  // iPhone/iPad em qualquer navegador (todos rodam WebKit no iOS).
  isIos() {
    const ua = window.navigator.userAgent
    return (
      /iPad|iPhone|iPod/.test(ua) ||
      (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
    )
  }
}
