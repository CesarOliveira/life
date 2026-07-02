import { Controller } from "@hotwired/stimulus"

// Dupla confirmação para ações destrutivas: só deixa o form submeter se o
// usuário confirmar DUAS vezes.
export default class extends Controller {
  static values = { first: String, second: String }

  check(event) {
    const ok = window.confirm(this.firstValue) && window.confirm(this.secondValue)
    if (!ok) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }
}
