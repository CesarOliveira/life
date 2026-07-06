import { Controller } from "@hotwired/stimulus"

// Submete o form ao mudar um campo (ex.: select de meses).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
