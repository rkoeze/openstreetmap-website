module User::Roleable
  ##
  # returns true if the user has the moderator role, false otherwise
  def moderator?
    role? "moderator"
  end

  ##
  # returns true if the user has the administrator role, false otherwise
  def administrator?
    role? "administrator"
  end

  ##
  # returns true if the user has the importer role, false otherwise
  def importer?
    role? "importer"
  end

  ##
  # returns true if the user has the requested role
  def role?(role)
    roles.any? { |r| r.role == role }
  end
end
