# frozen_string_literal: true

require 'digest'

class UserInvitationsController < ApplicationController
  layout 'authentication'

  def show
    @token = params[:token].to_s
    @invitation = find_invitation
    return render :invalid, status: :gone unless @invitation&.usable?

    store_location_for(:user, user_invitation_path(token: @token)) if @invitation.user.active? && !user_signed_in?
  end

  def update
    @token = params[:token].to_s
    @invitation = find_invitation
    return render :invalid, status: :gone unless @invitation&.usable?

    if @invitation.user.active?
      return render :show, status: :forbidden unless user_signed_in? && current_user.id == @invitation.user_id

      return redirect_to(admin_dashboard_path, notice: t('user_invitations.joined')) if @invitation.accept_existing!(
        token: @token, signed_in_user: current_user
      )
    elsif @invitation.accept!(token: @token, password: params.dig(:invitation, :password),
                             password_confirmation: params.dig(:invitation, :password_confirmation))
      return redirect_to(new_user_session_path, notice: t('user_invitations.activated'))
    end

    return render :invalid, status: :gone unless @invitation.usable?

    render :show, status: :unprocessable_content
  end

  private

  def find_invitation
    return if @token.blank?

    UserInvitation.find_by(token_digest: Digest::SHA256.hexdigest(@token))
  end
end
