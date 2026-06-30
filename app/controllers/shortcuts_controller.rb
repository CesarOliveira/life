# Serve o atalho de Saúde (.shortcut) ASSINADO para o iPhone importar.
# O arquivo é assinado offline (num Mac, via `shortcuts sign`) e versionado em
# public/shortcuts/. Tem token placeholder (sem segredo) — o usuário cola o token
# uma vez após instalar.
class ShortcutsController < ApplicationController
  FILE_PATH = Rails.root.join("public/shortcuts/saude-life.shortcut")

  def health
    return head :not_found unless File.exist?(FILE_PATH)

    send_file FILE_PATH,
              filename: "Saude-Life.shortcut",
              type: "application/octet-stream",
              disposition: "attachment"
  end
end
