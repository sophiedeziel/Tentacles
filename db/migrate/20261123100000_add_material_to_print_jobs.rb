# frozen_string_literal: true

# Global queue, phase 5 (#2939): the material a print job asks for, a key of Filament::MATERIALS. Null asks for the
# material its file's G-code says (PrintQueue::Needs), so the existing jobs keep what they asked for. Additive.
class AddMaterialToPrintJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :print_jobs, :material, :string, after: :all_capable
  end
end
