# Serve o atalho de Saúde (.shortcut) ASSINADO para o iPhone importar.
# O arquivo é assinado offline (num Mac, via `shortcuts sign`) e versionado em
# public/shortcuts/. Tem token placeholder (sem segredo) — o usuário cola o token
# uma vez após instalar.
class ShortcutsController < ApplicationController
  FILE_PATH = Rails.root.join("public/shortcuts/saude-life.shortcut")

  def health
    return head :not_found unless File.exist?(FILE_PATH)

    # Sem cache: garante que o usuário sempre baixa a versão recém-publicada
    # (evita arquivo cacheado no Safari/Files/Cloudflare).
    response.set_header("Cache-Control", "no-store, no-cache, must-revalidate")
    send_file FILE_PATH,
              filename: "Saude-Life.shortcut",
              type: "application/octet-stream",
              disposition: "attachment"
  end
end
