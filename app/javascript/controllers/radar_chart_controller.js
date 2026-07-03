import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Radar ("gráfico em cruz") de conclusões por categoria de hábito, estilo
// visão geral do GitHub. Rótulos trazem o percentual: "Saúde 45%".
export default class extends Controller {
  static values = {
    labels: Array,   // nomes das categorias
    counts: Array,   // conclusões por categoria
    percents: Array  // % por categoria
  }

  connect() {
    const labels = this.labelsValue.map((l, i) => `${l} ${this.percentsValue[i]}%`)

    this.chart = new Chart(this.element, {
      type: "radar",
      data: {
        labels,
        datasets: [{
          data: this.countsValue,
          backgroundColor: "rgba(16, 185, 129, 0.25)",
          borderColor: "#10b981",
          borderWidth: 2,
          pointBackgroundColor: "#10b981",
          pointRadius: 3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            displayColors: false,
            callbacks: { label: (item) => `${item.parsed.r}` }
          }
        },
        scales: {
          r: {
            beginAtZero: true,
            ticks: { display: false },
            grid: { color: "rgba(148, 163, 184, 0.2)" },
            angleLines: { color: "rgba(148, 163, 184, 0.2)" },
            pointLabels: { color: "#64748b", font: { size: 11 } }
          }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
