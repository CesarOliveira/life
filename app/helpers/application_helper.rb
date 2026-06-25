module ApplicationHelper
  # Link de navegação com destaque para a página atual.
  def nav_link(text, path)
    base = "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors"
    state = current_page?(path) ? "bg-slate-100 text-slate-900" : "text-slate-500 hover:text-slate-900 hover:bg-slate-100"
    link_to text, path, class: "#{base} #{state}"
  end
end
