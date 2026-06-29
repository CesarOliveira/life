import { Controller } from "@hotwired/stimulus"

// Alterna as seções do formulário de hábito:
// - "automático" (de métrica) esconde a cadência e mostra a regra de limiar.
// - cadência: dias específicos (weekly_days) ou Nx por semana (weekly_count).
export default class extends Controller {
  static targets = ["frequency", "weeklyDays", "weeklyCount", "auto", "autoFields", "cadenceFields"]

  connect() {
    this.toggleAuto()
    this.toggleFrequency()
  }

  toggleAuto() {
    const isAuto = this.hasAutoTarget && this.autoTarget.checked
    if (this.hasAutoFieldsTarget) this.autoFieldsTarget.classList.toggle("hidden", !isAuto)
    if (this.hasCadenceFieldsTarget) this.cadenceFieldsTarget.classList.toggle("hidden", isAuto)
  }

  toggleFrequency() {
    if (!this.hasFrequencyTarget) return
    const isCount = this.frequencyTarget.value === "weekly_count"
    if (this.hasWeeklyDaysTarget) this.weeklyDaysTarget.classList.toggle("hidden", isCount)
    if (this.hasWeeklyCountTarget) this.weeklyCountTarget.classList.toggle("hidden", !isCount)
  }
}
