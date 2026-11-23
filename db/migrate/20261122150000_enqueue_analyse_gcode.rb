# frozen_string_literal: true

# Reads the G-code files uploaded before G-code summaries (#2936), once, in the background: a pending
# gcode_summaries row and one AnalyseGcodeJob per G-code file, run by Sidekiq once the app is up (bin/docker-run.sh
# migrates, then starts Procfile.prod). Safe to run again: a file with a row keeps it, and the job skips a current
# row.
class EnqueueAnalyseGcode < ActiveRecord::Migration[8.1]
  def up
    # In batches of 1000, each a single INSERT
    gcode_item_ids.each_slice(1000) do |ids|
      create_pending_rows(ids)
      ids.each { |id| AnalyseGcodeJob.perform_later(id) }
    end
  rescue RedisClient::Error => e
    # The summaries are a nice-to-have: never keep the app from starting over them. Their rows stay pending until the
    # file is saved again or `bin/rails gcode:reanalyse` runs
    say "Could not enqueue AnalyseGcodeJob (#{e.class}: #{e.message}): run bin/rails gcode:reanalyse later"
  end

  def down; end

  private

  # The filename is on the attached blob. SQL, not models: the app's may have changed by the time this runs
  def gcode_item_ids
    select_values(<<~SQL.squish).map { |id| Integer(id) }
      SELECT file_records.id FROM file_records
      JOIN active_storage_attachments ON active_storage_attachments.record_id = file_records.id
        AND active_storage_attachments.record_type = 'Library::Item' AND active_storage_attachments.name = 'file'
      JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id
      WHERE LOWER(active_storage_blobs.filename) LIKE '%.gcode'
      ORDER BY file_records.id
    SQL
  end

  def create_pending_rows(ids)
    now = connection.quote(Time.current)
    values = ids.map { |id| "(#{Integer(id)}, 'pending', #{now}, #{now})" }.join(', ')
    # INSERT IGNORE: a file that has a row (a run before, an upload since) keeps it
    execute(<<~SQL.squish)
      INSERT IGNORE INTO gcode_summaries (file_record_id, status, created_at, updated_at) VALUES #{values}
    SQL
  end
end
