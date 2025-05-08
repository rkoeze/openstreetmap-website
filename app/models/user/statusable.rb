module User::Statusable
  extend ActiveSupport::Concern

  included do
    include AASM

    scope :visible, -> { where(:status => %w[pending active confirmed]) }
    scope :active, -> { where(:status => %w[active confirmed]) }

    aasm :column => :status, :no_direct_assignment => true do
      state :pending, :initial => true
      state :active
      state :confirmed
      state :suspended
      state :deleted

      # A normal account is active
      event :activate do
        transitions :from => :pending, :to => :active
      end

      # Used in test suite, not something that we would normally need to do.
      if Rails.env.test?
        event :deactivate do
          transitions :from => :active, :to => :pending
        end
      end

      # To confirm an account is used to override the spam scoring
      event :confirm do
        transitions :from => [:pending, :active, :suspended], :to => :confirmed
      end

      # To unconfirm an account is to make it subject to future spam scoring again
      event :unconfirm do
        transitions :from => :confirmed, :to => :active
      end

      # Accounts can be automatically suspended by spam_check
      event :suspend do
        transitions :from => [:pending, :active], :to => :suspended
      end

      # Unsuspending an account moves it back to active without overriding the spam scoring
      event :unsuspend do
        transitions :from => :suspended, :to => :active
      end

      # Mark the account as deleted but keep all data intact
      event :hide do
        transitions :from => [:pending, :active, :confirmed, :suspended], :to => :deleted
      end

      event :unhide do
        transitions :from => [:deleted], :to => :active
      end

      # Mark the account as deleted and remove personal data
      event :soft_destroy do
        before do
          revoke_authentication_tokens
          remove_personal_data
        end

        transitions :from => [:pending, :active, :confirmed, :suspended], :to => :deleted
      end
    end
  end

  ##
  # returns true if a user is visible
  def visible?
    %w[pending active confirmed].include? status
  end

  ##
  # returns true if a user is active
  def active?
    %w[active confirmed].include? status
  end
end
