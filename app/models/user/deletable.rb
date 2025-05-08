module User::Deletable
  def deletion_allowed_at
    unless Settings.user_account_deletion_delay.nil?
      last_changeset = changesets.reorder(:closed_at => :desc).first
      return last_changeset.closed_at.utc + Settings.user_account_deletion_delay.hours if last_changeset
    end
    creation_time.utc
  end

  def deletion_allowed?
    deletion_allowed_at <= Time.now.utc
  end
end
