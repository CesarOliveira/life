import { Controller } from "@hotwired/stimulus"

// Alterna as seções do formulário de hábito:
// - "automático" (de métrica) esconde a cadência e mostra a regra de limiar.
// - cadência: dias específicos (weekly_days) ou Nx por semana (weekly_count).
// - por métrica: mostra seletor de apps (rede social) e troca o limiar entre
//   número e horário (hora de dormir).
export default class extends Controller {
  static targets = [
    "frequency", "weeklyDays", "weeklyCount", "auto", "autoFields", "cadenceFields",
    "metric", "appPicker", "numberThreshold", "timeThreshold"
  ]
  static values = {
    timeMetrics: { type: Array, default: ["sleep_bedtime"] },
    appMetrics: { type: Array, default: ["social_apps"] }
  }

  connect() {
    this.toggleAuto()
    this.toggleFrequency()
    this.toggleMetric()
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

  toggleMetric() {
    if (!this.hasMetricTarget) return
    const metric = this.metricTarget.value
    const isTime = this.timeMetricsValue.includes(metric)
    const isApps = this.appMetricsValue.includes(metric)
    if (this.hasTimeThresholdTarget) this.timeThresholdTarget.classList.toggle("hidden", !isTime)
    if (this.hasNumberThresholdTarget) this.numberThresholdTarget.classList.toggle("hidden", isTime)
    if (this.hasAppPickerTarget) this.appPickerTarget.classList.toggle("hidden", !isApps)
  }
}
