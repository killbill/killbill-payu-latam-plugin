module Killbill #:nodoc:
  module PayuLatam #:nodoc:
    class PayuLatamTransaction < ::Killbill::Plugin::ActiveMerchant::ActiveRecord::Transaction

      self.table_name = 'payu_latam_transactions'

      belongs_to :payu_latam_response

    end
  end
end
