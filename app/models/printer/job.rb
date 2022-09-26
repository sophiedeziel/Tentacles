# frozen_string_literal: true

class Printer
  class Job < ApplicationRecord
    belongs_to :printer
    belongs_to :executable, polymorphic: true

    validates :status, inclusion: { in: %w[enqueued active completed error] }
  end
end
