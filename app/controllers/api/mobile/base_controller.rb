module Api
  module Mobile
    # Rotas usadas pelas telas NATIVAS do app (token da conta em Authorization: Bearer).
    class BaseController < Api::BaseController
      private

      # Pessoa por trás do token: o dono da conta.
      def current_owner
        @current_owner ||= current_account.owner || current_account.users.first
      end
    end
  end
end
