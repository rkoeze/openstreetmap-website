module User::Spammable

  ##
  # return a spam score for a user
  def spam_score
    changeset_score = changesets.size * 50
    trace_score = traces.size * 50
    diary_entry_score = diary_entries.visible.inject(0) { |acc, elem| acc + elem.body.spam_score }
    diary_comment_score = diary_comments.visible.inject(0) { |acc, elem| acc + elem.body.spam_score }
    report_score = Report.where(:category => "spam", :issue => issues.with_status("open")).distinct.count(:user_id) * 20

    score = description.spam_score / 4.0
    score += diary_entries.visible.where("created_at > ?", 1.day.ago).count * 10
    score += diary_entry_score / diary_entries.visible.length unless diary_entries.visible.empty?
    score += diary_comment_score / diary_comments.visible.length unless diary_comments.visible.empty?
    score += report_score
    score -= changeset_score
    score -= trace_score

    score.to_i
  end

  ##
  # perform a spam check on a user
  def spam_check
    suspend! if may_suspend? && spam_score > Settings.spam_threshold
  end
end
