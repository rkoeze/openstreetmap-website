module User::Oauth
  extend ActiveSupport::Concern

  included do
    has_many :oauth2_applications, :class_name => Doorkeeper.config.application_model.name, :as => :owner
    has_many :access_grants, :class_name => Doorkeeper.config.access_grant_model.name, :foreign_key => :resource_owner_id
    has_many :access_tokens, :class_name => Doorkeeper.config.access_token_model.name, :foreign_key => :resource_owner_id
  end

  ##
  # return an oauth 2 access token for a specified application
  def oauth_token(application_id)
    application = Doorkeeper.config.application_model.find_by(:uid => application_id)

    Doorkeeper.config.access_token_model.find_or_create_for(
      :application => application,
      :resource_owner => self,
      :scopes => application.scopes
    )
  end

  ##
  # revoke any authentication tokens
  def revoke_authentication_tokens
    access_tokens.not_expired.each(&:revoke)
  end
end
