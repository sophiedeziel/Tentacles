require "application_system_test_case"

class PrintersTest < ApplicationSystemTestCase
  setup do
    @printer = printers(:one)
  end

  test "visiting the index" do
    visit printers_url
    assert_selector "h1", text: "Printers"
  end

  test "should create printer" do
    visit printers_url
    click_on "New printer"

    click_on "Create Printer"

    assert_text "Printer was successfully created"
    click_on "Back"
  end

  test "should update Printer" do
    visit printer_url(@printer)
    click_on "Edit this printer", match: :first

    click_on "Update Printer"

    assert_text "Printer was successfully updated"
    click_on "Back"
  end

  test "should destroy Printer" do
    visit printer_url(@printer)
    click_on "Destroy this printer", match: :first

    assert_text "Printer was successfully destroyed"
  end
end
