# frozen_string_literal: true

class Printer
  class Job < ApplicationRecord
    belongs_to :printer, inverse_of: :jobs
    belongs_to :executable, polymorphic: true, inverse_of: :jobs

    validates :status, inclusion: { in: %w[enqueued active completed error] }
  end
end
