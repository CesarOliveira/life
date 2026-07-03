import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Gráfico de linha (Chart.js) com tooltip: passar o dedo/mouse mostra a data e
// o valor de cada ponto. Dados via data-line-chart-points-value:
//   [{"d":"2026-02-10","v":4.79}, ...]
export default class extends Controller {
  static values = {
    points: Array,
    unit: { type: String, default: "" }
  }

  connect() {
    const labels = this.pointsValue.map((p) => this.formatDate(p.d))
    const data = this.pointsValue.map((p) => p.v)
    const unit = this.unitValue

    this.chart = new Chart(this.element, {
      type: "line",
      data: {
        labels,
        datasets: [{
          data,
          borderColor: "#10b981",
          backgroundColor: "rgba(16, 185, 129, 0.12)",
          fill: true,
          tension: 0.3,
          pointRadius: 3,
          pointHoverRadius: 6,
          pointBackgroundColor: "#10b981",
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            displayColors: false,
            callbacks: {
              title: (items) => items[0].label,
              label: (item) => `${this.formatNumber(item.parsed.y)}${unit ? " " + unit : ""}`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { maxTicksLimit: 8, color: "#94a3b8", font: { size: 10 } }
          },
          y: {
            grid: { color: "rgba(148, 163, 184, 0.15)" },
            ticks: { maxTicksLimit: 5, color: "#94a3b8", font: { size: 10 } }
          }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }

  formatDate(iso) {
    const [y, m, d] = iso.split("-")
    return document.documentElement.lang.startsWith("pt") ? `${d}/${m}/${y}` : `${m}/${d}/${y}`
  }

  formatNumber(value) {
    return new Intl.NumberFormat(document.documentElement.lang || "pt-BR", { maximumFractionDigits: 2 }).format(value)
  }
}
