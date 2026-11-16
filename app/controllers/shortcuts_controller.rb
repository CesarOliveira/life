# Serve o atalho de TEMPO DE TELA (.shortcut) ASSINADO para o iPhone importar.
# (A Saúde migrou pro app nativo; só o tempo de tela ainda depende do Atalho,
# pois a Apple não deixa app nativo exportar Screen Time.) Assinado offline num
# Mac (`shortcuts sign`) e versionado em public/shortcuts/.
class ShortcutsController < ApplicationController
  # Público: o arquivo é o atalho ASSINADO com token placeholder (sem dado do
  # usuário). Precisa ser sem-login pra funcionar quando aberto no Safari (que
  # não carrega a sessão do app). O token é colado à parte, no import.
  skip_before_action :authenticate_user!, only: [:health, :today]

  FILE_PATH = Rails.root.join("public/shortcuts/saude-life.shortcut")
  TODAY_FILE_PATH = Rails.root.join("public/shortcuts/tempo-tela-hoje.shortcut")

  def health
    serve_shortcut(FILE_PATH, "Tempo-Tela-Life.shortcut")
  end

  # Variante "Hoje": coleta o dia corrente e notifica limiar cruzado (alertas
  # intradiários dos hábitos de tela). Roda por automação "ao fechar" os apps.
  def today
    serve_shortcut(TODAY_FILE_PATH, "Tempo-Tela-Hoje-Life.shortcut")
  end

  private

  def serve_shortcut(path, filename)
    return head :not_found unless File.exist?(path)

    # Sem cache: garante que o usuário sempre baixa a versão recém-publicada
    # (evita arquivo cacheado no Safari/Files/Cloudflare).
    response.set_header("Cache-Control", "no-store, no-cache, must-revalidate")
    send_file path, filename: filename, type: "application/octet-stream", disposition: "attachment"
  end
end
