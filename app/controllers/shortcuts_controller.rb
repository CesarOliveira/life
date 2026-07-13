# Serve o atalho de TEMPO DE TELA (.shortcut) ASSINADO para o iPhone importar.
# (A Saúde migrou pro app nativo; só o tempo de tela ainda depende do Atalho,
# pois a Apple não deixa app nativo exportar Screen Time.) Assinado offline num
# Mac (`shortcuts sign`) e versionado em public/shortcuts/.
class ShortcutsController < ApplicationController
  FILE_PATH = Rails.root.join("public/shortcuts/saude-life.shortcut")

  def health
    return head :not_found unless File.exist?(FILE_PATH)

    # Sem cache: garante que o usuário sempre baixa a versão recém-publicada
    # (evita arquivo cacheado no Safari/Files/Cloudflare).
    response.set_header("Cache-Control", "no-store, no-cache, must-revalidate")
    send_file FILE_PATH,
              filename: "Tempo-Tela-Life.shortcut",
              type: "application/octet-stream",
              disposition: "attachment"
  end
end
