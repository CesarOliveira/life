# One-off (idempotente): remove o dado de TESTE antigo do tempo de tela — o uso do
# próprio Mac que entrou como device=iphone durante os testes, ANTES do dado real
# do iPhone (via Atalho) começar em 2026-06-28. Mantém tudo de 28/06 em diante.
# Procedimento no DEPLOY_OPERACOES.md §2 (aplicar via startCommand, depois reverter).
puts "=== CLEANUP_MAC_TEST: inicio ==="

all = AppUsage.order(:date, :device, :bundle_id)
puts "CLEANUP total atual: #{all.count}"
all.each { |u| puts "  ROW #{u.date} #{u.device} #{u.bundle_id} = #{u.seconds}s" }

cutoff = Date.new(2026, 6, 28)
doomed = AppUsage.where("date < ?", cutoff)
puts "=== CLEANUP vai apagar #{doomed.count} (date < #{cutoff}) ==="
doomed.each { |u| puts "  DEL #{u.date} #{u.device} #{u.bundle_id} = #{u.seconds}s" }

deleted = doomed.delete_all
puts "=== CLEANUP apagadas: #{deleted} ==="

rest = AppUsage.order(:date, :bundle_id)
puts "=== CLEANUP restante: #{rest.count} ==="
rest.each { |u| puts "  KEEP #{u.date} #{u.device} #{u.bundle_id} = #{u.seconds}s" }
puts "=== CLEANUP_MAC_TEST: fim ==="
