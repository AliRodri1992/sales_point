(1..12).each do |i|
  SatMonth.create!(
    code: format('%02d', i),
    description: Date::MONTHNAMES[i],
    month_number: i
  )
end
