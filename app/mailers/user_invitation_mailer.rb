# frozen_string_literal: true

require 'digest'

class UserInvitationMailer < ApplicationMailer
  def invite(invitation_id, raw_token)
    invitation = UserInvitation.includes(:user, :organization).find(invitation_id)
    return unless invitation.usable?
    return unless ActiveSupport::SecurityUtils.secure_compare(invitation.token_digest, Digest::SHA256.hexdigest(raw_token.to_s))

    template = EmailTemplate.find_by(key: 'user_invitation', locale: invitation.user.language&.code || 'es', enabled: true) ||
               EmailTemplate.find_by!(key: 'user_invitation', locale: 'es', enabled: true)
    activation_url = user_invitation_url(token: raw_token)
    subject, html, plain = template.render_with(
      invited_name: invitation.user.display_name, organization_name: invitation.organization.name,
      activation_url:, expiration_hours: 72, current_year: Time.current.year,
      logo_url: ActionController::Base.helpers.image_url('delta-pos-logo.svg', host: default_url_options[:host])
    )
    mail(to: invitation.user.email, subject:) do |format|
      format.html { render html: html.html_safe, layout: false }
      format.text { render plain: }
    end
  end
end
