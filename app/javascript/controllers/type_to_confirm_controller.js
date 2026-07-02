import { Controller } from "@hotwired/stimulus"

// Confirmação digitada para ações destrutivas: o botão só habilita quando o
// usuário digita a palavra exata (ex.: DELETE).
export default class extends Controller {
  static targets = ["input", "button"]
  static values = { word: { type: String, default: "DELETE" } }

  connect() {
    this.check()
  }

  check() {
    this.buttonTarget.disabled = this.inputTarget.value.trim() !== this.wordValue
  }
}
