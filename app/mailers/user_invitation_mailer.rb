# frozen_string_literal: true

require 'digest'

class UserInvitationMailer < ApplicationMailer
  after_deliver :mark_delivered

  def invite(invitation_id, encrypted_token)
    raw_token = Users::InvitationDeliveryToken.decrypt(encrypted_token)
    @invitation_id = invitation_id
    invitation = UserInvitation.includes(:user, :organization).find(invitation_id)
    return unless valid_invitation?(invitation, raw_token)

    subject, html, plain = invitation_template(invitation).render_with(template_variables(invitation, raw_token))
    mail(to: invitation.user.email, subject:) do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end

  private

  def mark_delivered
    invitation = UserInvitation.find_by(id: @invitation_id)
    invitation&.update!(delivery_status: 'sent', sent_at: Time.current)
  end

  def valid_invitation?(invitation, token)
    return false unless invitation.usable?

    ActiveSupport::SecurityUtils.secure_compare(invitation.token_digest, Digest::SHA256.hexdigest(token.to_s))
  end

  def invitation_template(invitation)
    EmailTemplate.ensure_invitation_template!
    EmailTemplate.find_by(key: 'user_invitation', locale: invitation.user.language&.code, enabled: true) ||
      EmailTemplate.find_by!(key: 'user_invitation', locale: 'es', enabled: true)
  end

  def template_variables(invitation, token)
    {
      invited_name: invitation.user.display_name,
      organization_name: invitation.organization.name,
      activation_url: user_invitation_url(token:),
      expiration_hours: 72,
      current_year: Time.current.year,
      logo_url: ActionController::Base.helpers.image_url(
        'delta-pos-logo.svg', host: default_url_options[:host]
      )
    }
  end
end
