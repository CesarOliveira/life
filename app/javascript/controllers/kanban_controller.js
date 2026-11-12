import { Controller } from "@hotwired/stimulus"

// Arrastar e soltar tarefas entre colunas. Solta -> move o cartão no DOM e
// avisa o servidor (PATCH .../move com coluna e posição). Se o servidor recusar,
// recarrega a página para voltar ao estado real.
export default class extends Controller {
  static targets = ["column", "list", "card", "count", "empty"]

  start(event) {
    this.dragged = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.taskId)
    requestAnimationFrame(() => this.dragged.classList.add("opacity-40"))
  }

  end() {
    if (this.dragged) this.dragged.classList.remove("opacity-40")
    this.columnTargets.forEach((column) => column.classList.remove("ring-2", "ring-emerald-400"))
  }

  over(event) {
    if (!this.dragged) return
    event.preventDefault()
    const column = event.currentTarget
    column.classList.add("ring-2", "ring-emerald-400")
    const list = column.querySelector("[data-kanban-target='list']")
    const after = this.cardAfter(list, event.clientY)
    if (after) list.insertBefore(this.dragged, after)
    else list.insertBefore(this.dragged, list.querySelector("[data-kanban-target='empty']"))
  }

  leave(event) {
    if (!event.currentTarget.contains(event.relatedTarget)) {
      event.currentTarget.classList.remove("ring-2", "ring-emerald-400")
    }
  }

  async drop(event) {
    if (!this.dragged) return
    event.preventDefault()
    const card = this.dragged
    const column = event.currentTarget
    const cards = Array.from(column.querySelectorAll("[data-kanban-target='card']"))
    const position = cards.indexOf(card)
    this.end()
    this.dragged = null
    this.refreshCounts()

    try {
      const response = await fetch(card.dataset.moveUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "",
        },
        body: JSON.stringify({ column_id: column.dataset.columnId, position }),
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      const title = card.querySelector("p")
      if (title) {
        title.classList.toggle("line-through", data.done)
        title.classList.toggle("text-slate-500", data.done)
      }
    } catch (_error) {
      window.location.reload()
    }
  }

  // Cartão imediatamente abaixo do ponteiro (para inserir antes dele).
  cardAfter(list, y) {
    const cards = Array.from(list.querySelectorAll("[data-kanban-target='card']")).filter((c) => c !== this.dragged)
    return cards.find((card) => {
      const box = card.getBoundingClientRect()
      return y < box.top + box.height / 2
    })
  }

  refreshCounts() {
    this.columnTargets.forEach((column) => {
      const total = column.querySelectorAll("[data-kanban-target='card']").length
      const count = column.querySelector("[data-kanban-target='count']")
      const empty = column.querySelector("[data-kanban-target='empty']")
      if (count) count.textContent = total
      if (empty) empty.classList.toggle("hidden", total > 0)
    })
  }
}
