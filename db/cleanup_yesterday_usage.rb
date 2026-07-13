# TEMP: mostra os últimos 3 dias de tempo de tela e APAGA os de ontem (dado
# errado — atalho puxou "semana passada" mas foi gravado como ontem).
y = Date.current - 1
puts "CLEANUP_START hoje=#{Date.current} ontem=#{y}"
(0..3).each do |d|
  day = Date.current - d
  rows = AppUsage.where(date: day)
  puts "CLEANUP| #{day}: #{rows.count} apps, total=#{rows.sum(:seconds)}s"
end
deleted = AppUsage.where(date: y).delete_all
puts "CLEANUP_DELETED ontem(#{y}) removidos=#{deleted}"
puts "CLEANUP_END"
