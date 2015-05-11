module Killbill #:nodoc:
  module PayuLatam #:nodoc:
    class PrivatePaymentPlugin < ::Killbill::Plugin::ActiveMerchant::PrivatePaymentPlugin
      def initialize(session = {})
        super(:payu_latam,
              ::Killbill::PayuLatam::PayuLatamPaymentMethod,
              ::Killbill::PayuLatam::PayuLatamTransaction,
              ::Killbill::PayuLatam::PayuLatamResponse,
              session)
      end
    end
  end
end
