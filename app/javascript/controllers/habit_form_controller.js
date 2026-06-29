import { Controller } from "@hotwired/stimulus"

// Mostra os "dias da semana" ou a "meta semanal" conforme a cadência escolhida.
// weekly_days → dias específicos; weekly_count → Nx por semana.
export default class extends Controller {
  static targets = ["weeklyDays", "weeklyCount", "frequency"]

  connect() {
    this.toggle()
  }

  toggle() {
    const value = this.frequencyTarget.value
    const isCount = value === "weekly_count"
    if (this.hasWeeklyDaysTarget) this.weeklyDaysTarget.classList.toggle("hidden", isCount)
    if (this.hasWeeklyCountTarget) this.weeklyCountTarget.classList.toggle("hidden", !isCount)
  }
}
