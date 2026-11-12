module TasksHelper
  # Classes Tailwind por cor de coluna (strings literais, para o Tailwind enxergar).
  COLUMN_STYLES = {
    "slate" => { column: "border-slate-300 bg-slate-50", badge: "bg-slate-200 text-slate-700", dot: "bg-slate-400" },
    "sky" => { column: "border-sky-300 bg-sky-50", badge: "bg-sky-100 text-sky-700", dot: "bg-sky-400" },
    "amber" => { column: "border-amber-300 bg-amber-50", badge: "bg-amber-100 text-amber-800", dot: "bg-amber-400" },
    "emerald" => { column: "border-emerald-300 bg-emerald-50", badge: "bg-emerald-100 text-emerald-700", dot: "bg-emerald-500" },
    "rose" => { column: "border-rose-300 bg-rose-50", badge: "bg-rose-100 text-rose-700", dot: "bg-rose-400" },
    "violet" => { column: "border-violet-300 bg-violet-50", badge: "bg-violet-100 text-violet-700", dot: "bg-violet-400" }
  }.freeze

  def column_style(column, part)
    (COLUMN_STYLES[column.color] || COLUMN_STYLES["slate"])[part]
  end

  # Descrição/comentário: texto do usuário com quebras de linha e links, sem HTML.
  def task_text(text)
    simple_format(auto_link_urls(h(text.to_s)), {}, sanitize: false)
  end

  private

  def auto_link_urls(escaped)
    escaped.gsub(%r{https?://[^\s<]+}) do |url|
      link_to(url, url, target: "_blank", rel: "noopener noreferrer", class: "text-emerald-700 underline")
    end.html_safe
  end
end
