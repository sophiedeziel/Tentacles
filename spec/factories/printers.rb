# frozen_string_literal: true

FactoryBot.define do
  factory :printer do
    name { 'Printer' }
    octoprint_key { 'A8DDB1359AAB415AB38C345129815DF4' }
    octoprint_uri { 'http://10.0.1.165/' }

    trait :disconnected do
      octoprint_uri { nil }
      octoprint_key { nil }
    end

    trait :wrong_credentials do
      octoprint_uri { 'http://10.0.1.165/' }
      octoprint_key { '193736djdbs' }
    end
  end
end
