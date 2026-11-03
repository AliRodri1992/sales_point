# frozen_string_literal: true

require 'digest'

class UserInvitationsController < ApplicationController
  layout 'authentication'

  def show
    @token = params[:token].to_s
    @invitation = find_invitation
    render :invalid, status: :gone unless @invitation&.usable?
  end

  def update
    @token = params[:token].to_s
    @invitation = find_invitation
    return render :invalid, status: :gone unless @invitation&.usable?

    if @invitation.accept!(token: @token, password: params.dig(:invitation, :password),
                           password_confirmation: params.dig(:invitation, :password_confirmation))
      redirect_to new_user_session_path, notice: t('user_invitations.activated')
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def find_invitation
    return if @token.blank?

    UserInvitation.find_by(token_digest: Digest::SHA256.hexdigest(@token))
  end
end
