class AccountsController < ApplicationController
  def edit; end

  def update
    unless current_user.authenticate(params[:current_password].to_s)
      return redirect_to edit_account_path, alert: "Senha atual incorreta."
    end

    if current_user.update(params.permit(:name, :password, :password_confirmation).compact_blank)
      redirect_to root_path, notice: "Dados atualizados."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
