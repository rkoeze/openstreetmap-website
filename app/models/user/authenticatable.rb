module User::Authenticatable
  extend ActiveSupport::Concern

  class_methods do
    def authenticate(options)
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
  end

  private

  def encrypt_password
    if pass_crypt_confirmation
      self.pass_crypt, self.pass_salt = PasswordHash.create(pass_crypt)
      self.pass_crypt_confirmation = nil
    end
  end
end
