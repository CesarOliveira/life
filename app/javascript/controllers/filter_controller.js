import { Controller } from "@hotwired/stimulus"

// Filtro client-side da listagem de exames: busca por nome (ignora acentos)
// e/ou grupo. Esconde seções sem itens visíveis e mostra o vazio geral.
export default class extends Controller {
  static targets = ["query", "group", "item", "section", "empty"]

  apply() {
    const q = this.norm(this.hasQueryTarget ? this.queryTarget.value : "")
    const g = this.hasGroupTarget ? this.groupTarget.value : ""
    let visible = 0

    this.itemTargets.forEach((el) => {
      const matches =
        (!q || this.norm(el.dataset.filterName).includes(q)) &&
        (!g || el.dataset.filterGroup === g)
      el.classList.toggle("hidden", !matches)
      if (matches) visible++
    })

    this.sectionTargets.forEach((sec) => {
      const any = sec.querySelector('[data-filter-target="item"]:not(.hidden)')
      sec.classList.toggle("hidden", !any)
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", visible > 0)
  }

  norm(str) {
    return (str || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  }
}
