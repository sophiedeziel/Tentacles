# frozen_string_literal: true

# The file library's domain: the uploaded files (Library::Item) and the labels that sort them.
#
#   item = Library::Item.find(id)
#   item.labels << Library::Label.find_by!(name: 'Calibration') # through Library::Labeling
#
# The tables keep their names (file_records, labels, file_labels). Never define Library::File: it would shadow ::File
# inside the namespace.
module Library
end
