# frozen_string_literal: true

FactoryBot.define do
  factory :printer do
    name { 'Printer' }
    backend { 'octoprint' }
    secret { 'A8DDB1359AAB415AB38C345129815DF4' }
    uri { 'http://10.0.1.165/' }

    # Saved without validations, like the printers created before `uri` and `secret` were required
    trait :unvalidated do
      to_create { |printer| printer.save!(validate: false) }
    end

    trait :disconnected do
      unvalidated
      uri { nil }
      secret { nil }
    end

    trait :wrong_credentials do
      uri { 'http://10.0.1.165/' }
      secret { '193736djdbs' }
    end
  end
end
