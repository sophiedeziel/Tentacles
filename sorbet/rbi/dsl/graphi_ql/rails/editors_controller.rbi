# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `GraphiQL::Rails::EditorsController`.
# Please instead update this file by running `bin/tapioca dsl GraphiQL::Rails::EditorsController`.


class GraphiQL::Rails::EditorsController
  sig { returns(HelperProxy) }
  def helpers; end

  module HelperMethods
    include ::Shakapacker::Helper
    include ::ActionController::Base::HelperMethods

    sig { returns(T.untyped) }
    def graphql_endpoint_path; end
  end

  class HelperProxy < ::ActionView::Base
    include HelperMethods
  end
end
