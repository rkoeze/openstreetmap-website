module User::Purgeable
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
end
