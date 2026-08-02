# Create default languages
[
  { code: 'en', name: 'English', flag_iso: 'us', status: 'active' },
  { code: 'es', name: 'Español', flag_iso: 'es', status: 'active' },
  { code: 'ko', name: '한국어', flag_iso: 'kr', status: 'active' }
].each do |lang_attrs|
  Language.find_or_create_by(code: lang_attrs[:code]) do |language|
    language.assign_attributes(lang_attrs)
  end
end

(1..12).each do |i|
  SatMonth.create!(
    code: format('%02d', i),
    description: Date::MONTHNAMES[i],
    month_number: i
  )
end
