# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'courrier@sophiedeziel.com'
  layout 'mailer'
end
