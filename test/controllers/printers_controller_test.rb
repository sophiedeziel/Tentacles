require "test_helper"

class PrintersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @printer = printers(:one)
  end

  test "should get index" do
    get printers_url
    assert_response :success
  end

  test "should get new" do
    get new_printer_url
    assert_response :success
  end

  test "should create printer" do
    assert_difference("Printer.count") do
      post printers_url, params: { printer: {  } }
    end

    assert_redirected_to printer_url(Printer.last)
  end

  test "should show printer" do
    get printer_url(@printer)
    assert_response :success
  end

  test "should get edit" do
    get edit_printer_url(@printer)
    assert_response :success
  end

  test "should update printer" do
    patch printer_url(@printer), params: { printer: {  } }
    assert_redirected_to printer_url(@printer)
  end

  test "should destroy printer" do
    assert_difference("Printer.count", -1) do
      delete printer_url(@printer)
    end

    assert_redirected_to printers_url
  end
end
