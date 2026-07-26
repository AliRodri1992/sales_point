module AuthenticationHelper
  def authentication_logo
    "logo.svg"
  end

  def authentication_title
    t("devise.sessions.new.title")
  end
end