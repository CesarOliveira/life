module Api
  module Mobile
    # DELETE /api/mobile/account { confirm: "EXCLUIR" } — exclusão da conta de dentro do app.
    class AccountsController < BaseController
      def destroy
        return render_error("confirmation_required") unless params[:confirm].to_s.strip.casecmp?(UserDeletionsController::CONFIRMATION)

        user = current_owner
        return render_error("not_found") if user.nil?

        result = UserDeletion.new(user).call
        return render_error(result.error.to_s) unless result.ok?

        render json: { ok: true }
      end
    end
  end
end
