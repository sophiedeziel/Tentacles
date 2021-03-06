# frozen_string_literal: true

class Printer
  class Job < ApplicationRecord
    belongs_to :printer
    belongs_to :executable, polymorphic: true
  end
end
