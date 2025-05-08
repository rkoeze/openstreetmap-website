# == Schema Information
#
# Table name: users
#
#  email                :string           not null
#  id                   :bigint           not null, primary key
#  pass_crypt           :string           not null
#  creation_time        :datetime         not null
#  display_name         :string           default(""), not null
#  data_public          :boolean          default(FALSE), not null
#  description          :text             default(""), not null
#  home_lat             :float
#  home_lon             :float
#  home_zoom            :integer          default(3)
#  home_location_name   :string
#  pass_salt            :string
#  email_valid          :boolean          default(FALSE), not null
#  new_email            :string
#  languages            :string
#  status               :enum             default("pending"), not null
#  terms_agreed         :datetime
#  consider_pd          :boolean          default(FALSE), not null
#  auth_uid             :string
#  preferred_editor     :string
#  terms_seen           :boolean          default(FALSE), not null
#  description_format   :enum             default("markdown"), not null
#  changesets_count     :integer          default(0), not null
#  traces_count         :integer          default(0), not null
#  diary_entries_count  :integer          default(0), not null
#  image_use_gravatar   :boolean          default(FALSE), not null
#  auth_provider        :string
#  home_tile            :bigint
#  tou_agreed           :datetime
#  diary_comments_count :integer          default(0)
#  note_comments_count  :integer          default(0)
#  creation_address     :inet
#
# Indexes
#
#  index_users_on_creation_address   (creation_address) USING gist
#  users_auth_idx                    (auth_provider,auth_uid) UNIQUE
#  users_display_name_canonical_idx  (lower(NORMALIZE(display_name, NFKC)))
#  users_display_name_idx            (display_name) UNIQUE
#  users_email_idx                   (email) UNIQUE
#  users_email_lower_idx             (lower((email)::text))
#  users_home_idx                    (home_tile)
#

class User < ApplicationRecord
  require "digest"

  include User::Roleable
  include User::Statusable
  include User::Spammable
  include User::RateLimitable
  include User::Deletable

  has_many :traces, -> { where(:visible => true) }
  has_many :diary_entries, -> { order(:created_at => :desc) }, :inverse_of => :user
  has_many :diary_comments, -> { order(:created_at => :desc) }, :inverse_of => :user
  has_many :diary_entry_subscriptions, :class_name => "DiaryEntrySubscription"
  has_many :diary_subscriptions, :through => :diary_entry_subscriptions, :source => :diary_entry
  has_many :messages, -> { where(:to_user_visible => true, :muted => false).order(:sent_on => :desc).preload(:sender, :recipient) }, :foreign_key => :to_user_id
  has_many :new_messages, -> { where(:to_user_visible => true, :muted => false, :message_read => false).order(:sent_on => :desc) }, :class_name => "Message", :foreign_key => :to_user_id
  has_many :sent_messages, -> { where(:from_user_visible => true).order(:sent_on => :desc).preload(:sender, :recipient) }, :class_name => "Message", :foreign_key => :from_user_id
  has_many :muted_messages, -> { where(:to_user_visible => true, :muted => true).order(:sent_on => :desc).preload(:sender, :recipient) }, :class_name => "Message", :foreign_key => :to_user_id
  has_many :follows, -> { joins(:following).where(:users => { :status => %w[active confirmed] }) }
  has_many :followings, :through => :follows, :source => :following
  has_many :preferences, :class_name => "UserPreference"
  has_many :changesets, -> { order(:created_at => :desc) }, :inverse_of => :user
  has_many :changeset_comments, :foreign_key => :author_id, :inverse_of => :author
  has_many :changeset_subscriptions, :foreign_key => :subscriber_id
  has_many :note_comments, :foreign_key => :author_id, :inverse_of => :author
  has_many :notes, :through => :note_comments
  has_many :note_subscriptions, :class_name => "NoteSubscription"
  has_many :subscribed_notes, :through => :note_subscriptions, :source => :note

  has_many :oauth2_applications, :class_name => Doorkeeper.config.application_model.name, :as => :owner
  has_many :access_grants, :class_name => Doorkeeper.config.access_grant_model.name, :foreign_key => :resource_owner_id
  has_many :access_tokens, :class_name => Doorkeeper.config.access_token_model.name, :foreign_key => :resource_owner_id

  has_many :blocks, :class_name => "UserBlock"
  has_many :blocks_created, :class_name => "UserBlock", :foreign_key => :creator_id, :inverse_of => :creator
  has_many :blocks_revoked, :class_name => "UserBlock", :foreign_key => :revoker_id, :inverse_of => :revoker

  has_many :mutes, -> { order(:created_at => :desc) }, :class_name => "UserMute", :foreign_key => :owner_id, :inverse_of => :owner
  has_many :muted_users, :through => :mutes, :source => :subject

  has_many :roles, :class_name => "UserRole"

  has_many :issues, :class_name => "Issue", :foreign_key => :reported_user_id, :inverse_of => :reported_user
  has_many :issue_comments

  has_many :reports

  scope :identifiable, -> { where(:data_public => true) }

  has_one_attached :avatar, :service => Settings.avatar_storage

  validates :display_name, :presence => true, :length => 3..255,
                           :exclusion => %w[new terms save confirm confirm-email go_public reset-password forgot-password suspended]
  validates :display_name, :if => proc { |u| u.display_name_changed? },
                           :normalized_uniqueness => { :case_sensitive => false }
  validates :display_name, :if => proc { |u| u.display_name_changed? },
                           :characters => { :url_safe => true },
                           :whitespace => { :leading => false, :trailing => false },
                           :width => { :minimum => 3 }
  validate :display_name_cannot_be_user_id_with_other_id, :if => proc { |u| u.display_name_changed? }
  validates :email, :presence => true, :characters => true
  validates :email, :if => proc { |u| u.email_changed? },
                    :uniqueness => { :case_sensitive => false }
  validates :email, :if => proc { |u| u.email_changed? },
                    :whitespace => { :leading => false, :trailing => false }
  validates :pass_crypt, :confirmation => true, :length => 8..255
  validates :home_lat, :allow_nil => true, :numericality => true, :inclusion => { :in => -90..90 }
  validates :home_lon, :allow_nil => true, :numericality => true, :inclusion => { :in => -180..180 }
  validates :home_zoom, :allow_nil => true, :numericality => { :only_integer => true }
  validates :preferred_editor, :inclusion => Editors::ALL_EDITORS, :allow_nil => true
  validates :auth_uid, :unless => proc { |u| u.auth_provider.nil? },
                       :uniqueness => { :scope => :auth_provider }
  validates :avatar, :if => proc { |u| u.attachment_changes["avatar"] },
                     :image => true

  validates_email_format_of :email, :if => proc { |u| u.email_changed? }
  validates_email_format_of :new_email, :allow_blank => true, :if => proc { |u| u.new_email_changed? }

  alias_attribute :created_at, :creation_time

  before_save :encrypt_password
  before_save :update_tile
  after_save :spam_check

  generates_token_for :new_user, :expires_in => 1.week do
    fingerprint
  end

  generates_token_for :new_email, :expires_in => 1.week do
    fingerprint
  end

  generates_token_for :password_reset, :expires_in => 1.week do
    fingerprint
  end

  def display_name_cannot_be_user_id_with_other_id
    display_name&.match(/^user_(\d+)$/i) do |m|
      errors.add :display_name, I18n.t("activerecord.errors.messages.display_name_is_user_n") unless m[1].to_i == id
    end
  end

  def to_param
    display_name
  end

  def self.authenticate(options)
    if options[:username] && options[:password]
      user = find_by("email = ? OR display_name = ?", options[:username].strip, options[:username])

      if user.nil?
        users = where("LOWER(email) = LOWER(?) OR LOWER(NORMALIZE(display_name, NFKC)) = LOWER(NORMALIZE(?, NFKC))", options[:username].strip, options[:username])

        user = users.first if users.count == 1
      end

      if user && PasswordHash.check(user.pass_crypt, user.pass_salt, options[:password])
        if PasswordHash.upgrade?(user.pass_crypt, user.pass_salt)
          user.pass_crypt, user.pass_salt = PasswordHash.create(options[:password])
          user.save
        end
      else
        user = nil
      end
    end

    if user &&
       (user.status == "deleted" ||
         (user.status == "pending" && !options[:pending]) ||
         (user.status == "suspended" && !options[:suspended]))
      user = nil
    end

    user
  end

  def description
    RichText.new(self[:description_format], self[:description])
  end

  def languages
    attribute_present?(:languages) ? self[:languages].split(/ *[, ] */) : []
  end

  def languages=(languages)
    self[:languages] = languages.join(",")
  end

  def preferred_language
    languages.find { |l| Language.exists?(:code => l) }
  end

  def preferred_languages
    @preferred_languages ||= Locale.list(languages)
  end

  def home_location?
    home_lat && home_lon
  end

  def nearby(radius = Settings.nearby_radius, num = Settings.nearby_users)
    if home_location?
      gc = OSM::GreatCircle.new(home_lat, home_lon)
      sql_for_area = QuadTile.sql_for_area(gc.bounds(radius), "home_")
      sql_for_distance = gc.sql_for_distance("home_lat", "home_lon")
      nearby = User.active.identifiable
                   .where.not(:id => id)
                   .where(sql_for_area)
                   .where("#{sql_for_distance} <= ?", radius)
                   .order(Arel.sql(sql_for_distance))
                   .limit(num)
    else
      nearby = []
    end
    nearby
  end

  def distance(nearby_user)
    OSM::GreatCircle.new(home_lat, home_lon).distance(nearby_user.home_lat, nearby_user.home_lon)
  end

  def follows?(user)
    follows.exists?(:following => user)
  end

  ##
  # returns the first active block which would require users to view
  # a message, or nil if there are none.
  def blocked_on_view
    blocks.active.detect(&:needs_view?)
  end

  ##
  # revoke any authentication tokens
  def revoke_authentication_tokens
    access_tokens.not_expired.each(&:revoke)
  end

  ##
  # remove personal data - leave the account but purge most personal data
  def remove_personal_data
    avatar.purge_later

    self.display_name = "user_#{id}"
    self.description = ""
    self.home_lat = nil
    self.home_lon = nil
    self.email_valid = false
    self.new_email = nil
    self.auth_provider = nil
    self.auth_uid = nil

    save
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

  def fingerprint
    digest = Digest::SHA256.new
    digest.update(email)
    digest.update(pass_crypt)
    digest.hexdigest
  end

  def active_reports
    issues
      .with_status(:open)
      .joins(:reports)
      .where("reports.updated_at >= COALESCE(issues.resolved_at, '1970-01-01')")
      .count
  end

  private

  def encrypt_password
    if pass_crypt_confirmation
      self.pass_crypt, self.pass_salt = PasswordHash.create(pass_crypt)
      self.pass_crypt_confirmation = nil
    end
  end

  def update_tile
    self.home_tile = QuadTile.tile_for_point(home_lat, home_lon) if home_location?
  end
end
