module User::Languages
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
end
