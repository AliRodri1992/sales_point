FactoryBot.define do
  factory :language do
    sequence(:code) do |n|
      codes = ('aa'..'zz').to_a - %w[en es ko]
      codes[(n - 1) % codes.length]
    end
    sequence(:name) { |n| "Language #{n}" }
    flag_iso { 'us' }
    status { I18n.available_locales.map(&:to_s).include?(code) ? 'active' : 'inactive' }
    deleted_at { nil }

    trait :english do
      code { 'en' }
      name { 'English' }
      flag_iso { 'us' }
    end

    to_create do |language|
      existing = Language.find_by(code: language.code)
      existing || language.save!
    end
  end
end
