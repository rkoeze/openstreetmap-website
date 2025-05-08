module User::RateLimitable
  def max_messages_per_hour
    account_age_in_seconds = Time.now.utc - created_at
    account_age_in_hours = account_age_in_seconds / 3600
    recent_messages = messages.where(:sent_on => Time.now.utc - 3600..).count
    max_messages = account_age_in_hours.ceil + recent_messages - (active_reports * 10)
    max_messages.clamp(0, Settings.max_messages_per_hour)
  end

  def max_follows_per_hour
    account_age_in_seconds = Time.now.utc - created_at
    account_age_in_hours = account_age_in_seconds / 3600
    recent_follows = Follow.where(:following => self).where(:created_at => Time.now.utc - 3600..).count
    max_follows = account_age_in_hours.ceil + recent_follows - (active_reports * 10)
    max_follows.clamp(0, Settings.max_follows_per_hour)
  end

  def max_changeset_comments_per_hour
    if moderator?
      Settings.moderator_changeset_comments_per_hour
    else
      previous_comments = changeset_comments.limit(Settings.comments_to_max_changeset_comments).count
      max_comments = previous_comments / Settings.comments_to_max_changeset_comments.to_f * Settings.max_changeset_comments_per_hour
      max_comments = max_comments.floor.clamp(Settings.initial_changeset_comments_per_hour, Settings.max_changeset_comments_per_hour)
      max_comments /= 2**active_reports
      max_comments.floor.clamp(Settings.min_changeset_comments_per_hour, Settings.max_changeset_comments_per_hour)
    end
  end
end
