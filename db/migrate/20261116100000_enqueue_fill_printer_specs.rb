# frozen_string_literal: true

# Fills the blank specs of the printers added before autofill, once, in the background: one FillPrinterSpecsJob per
# printer, run by Sidekiq once the app is up (bin/docker-run.sh migrates, then starts Procfile.prod). Changes no
# column, so there is nothing to undo.
class EnqueueFillPrinterSpecs < ActiveRecord::Migration[8.1]
  def up
    select_values('SELECT id FROM printers').each { |id| FillPrinterSpecsJob.perform_later(Integer(id)) }
  rescue RedisClient::Error => e
    # The specs are a nice-to-have: never keep the app from starting over them
    say "Could not enqueue FillPrinterSpecsJob (#{e.class}: #{e.message}): these printers keep their blank specs"
  end

  def down; end
end
