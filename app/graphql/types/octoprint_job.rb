# frozen_string_literal: true

module Types
  class OctoprintJob < Base::Object
    implements Types::Job
    description 'A job Octoprint manages.'
  end
end
