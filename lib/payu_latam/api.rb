module Killbill #:nodoc:
  module PayuLatam #:nodoc:
    class PaymentPlugin < ::Killbill::Plugin::ActiveMerchant::PaymentPlugin

      def initialize
        gateway_builder = Proc.new do |config|
          ::OffsitePayments.mode = config[:test] ? :test : :production
          ::ActiveMerchant::Billing::PayULatamGateway.new :api_login          => config[:api_login],
                                                          :api_key            => config[:api_key],
                                                          :country_account_id => config[:country_account_id],
                                                          :merchant_id        => config[:merchant_id]
        end

        super(gateway_builder,
              :payu_latam,
              ::Killbill::PayuLatam::PayuLatamPaymentMethod,
              ::Killbill::PayuLatam::PayuLatamTransaction,
              ::Killbill::PayuLatam::PayuLatamResponse)
      end

      def on_event(event)
        # Require to deal with per tenant configuration invalidation
        super(event)
        #
        # Custom event logic could be added below...
        #
      end

      def authorize_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        add_required_options(properties, options)

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def capture_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        add_required_options(properties, options)

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def purchase_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Direct payment?
        if find_value_from_properties(properties, 'from_hpp') != 'true'
          options = {}
          add_required_options(properties, options)
          properties = merge_properties(properties, options)
          super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        else
          # Nope, HPP
          payu_order_id                = find_value_from_properties(properties, 'payu_order_id')
          payu_transaction_id          = find_value_from_properties(properties, 'payu_transaction_id')
          payment_processor_account_id = find_value_from_properties(properties, 'payment_processor_account_id')

          # Record a response row, to keep track of the created vouchers in PayU
          response                     = @response_model.create(:api_call                     => :build_form_descriptor,
                                                                :kb_account_id                => kb_account_id,
                                                                :kb_payment_id                => kb_payment_id,
                                                                :kb_payment_transaction_id    => kb_payment_transaction_id,
                                                                :transaction_type             => :PURCHASE,
                                                                :authorization                => [payu_order_id, payu_transaction_id].join(';'),
                                                                :payment_processor_account_id => payment_processor_account_id,
                                                                :kb_tenant_id                 => context.tenant_id,
                                                                :success                      => true,
                                                                :created_at                   => Time.now.utc,
                                                                :updated_at                   => Time.now.utc)

          # Get the payment status from PayU (we are required to fetch the status from PayU within 7 minutes of the URL creation)
          get_payment_transaction_info_from_payu(kb_payment_id, kb_payment_transaction_id, amount, currency, properties_to_hash(properties), context.tenant_id, response)
        end
      end

      def void_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        add_required_options(properties, options)

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, properties, context)
      end

      def credit_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        add_required_options(properties, options)

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def refund_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        add_required_options(properties, options)

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
      end

      def get_payment_info(kb_account_id, kb_payment_id, properties, context)
        t_info_plugins = super(kb_account_id, kb_payment_id, properties, context)

        t_info_plugins.reject! { |t_info_plugin| t_info_plugin.status == :UNDEFINED }

        t_info_plugins = get_payment_info_from_payu(kb_payment_id, properties_to_hash(properties), context) if t_info_plugins.empty?

        t_info_plugins
      end

      def search_payments(search_key, offset, limit, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(search_key, offset, limit, properties, context)
      end

      def add_payment_method(kb_account_id, kb_payment_method_id, payment_method_props, set_default, properties, context)
        # Pass extra parameters for the gateway here
        options = {
            :payer_user_id => kb_account_id
        }

        add_required_options(properties, options)

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_method_id, payment_method_props, set_default, properties, context)
      end

      def delete_payment_method(kb_account_id, kb_payment_method_id, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_method_id, properties, context)
      end

      def get_payment_method_detail(kb_account_id, kb_payment_method_id, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, kb_payment_method_id, properties, context)
      end

      def set_default_payment_method(kb_account_id, kb_payment_method_id, properties, context)
        # TODO
      end

      def get_payment_methods(kb_account_id, refresh_from_gateway, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(kb_account_id, refresh_from_gateway, properties, context)
      end

      def search_payment_methods(search_key, offset, limit, properties, context)
        # Pass extra parameters for the gateway here
        options = {}

        properties = merge_properties(properties, options)
        super(search_key, offset, limit, properties, context)
      end

      def reset_payment_methods(kb_account_id, payment_methods, properties, context)
        super
      end

      def build_form_descriptor(kb_account_id, descriptor_fields, properties, context)
        payu_hpp_credentials             = payu_hpp_credentials(properties_to_hash(properties))

        # Prepare the PayU request
        # Available fields:
        #  * :expiration_date
        #  * :customer (:name, :email, :phone, :dni_number)
        #  * :billing_address (:address1, :city, :state, :country)
        form_fields                      = properties_to_hash(descriptor_fields)
        payu_reference_code              = form_fields[:externalKey] || SecureRandom.uuid
        options                          = {
            # Required fields
            :order_id       => payu_reference_code,
            :description    => form_fields['description'] || 'Kill Bill payment',
            :payment_method => form_fields['paymentMethod'] || 'BALOTO',
        }.merge(payu_hpp_credentials)
        descriptor_fields                = merge_properties(descriptor_fields, options)

        # Create the voucher
        descriptor                       = super(kb_account_id, descriptor_fields, properties, context)
        payu_response                    = properties_to_hash(descriptor.form_fields)
        descriptor.form_url              = payu_response[:url]

        # Create the payment in Kill Bill to start the polling
        kb_account                       = @kb_apis.account_user_api.get_account_by_id(kb_account_id, context)
        kb_payment_method_id             = (@kb_apis.payment_api.get_account_payment_methods(kb_account_id, false, [], context).find { |pm| pm.plugin_name == 'killbill-payu-latam' }).id
        kb_payment_id                    = nil
        payment_external_key             = payu_response[:order_id]
        payment_transaction_external_key = payu_reference_code
        # See purchase call above
        properties                       = hash_to_properties(:from_hpp => true, :payu_order_id => payu_response[:order_id], :payu_transaction_id => payu_response[:transaction_id])

        @kb_apis.payment_api.create_purchase(kb_account,
                                             kb_payment_method_id,
                                             kb_payment_id,
                                             form_fields[:amount],
                                             form_fields[:currency] || kb_account.currency,
                                             payment_external_key,
                                             payment_transaction_external_key,
                                             properties,
                                             context)

        descriptor
      end

      def process_notification(notification, properties, context)
        # Pass extra parameters for the gateway here
        options    = {}
        properties = merge_properties(properties, options)

        super(notification, properties, context) do |gw_notification, service|
          # Retrieve the payment
          # gw_notification.kb_payment_id =
          #
          # Set the response body
          # gw_notification.entity =
        end
      end

      private

      def get_payment_info_from_payu(kb_payment_id, options, context)
        kb_payment = @kb_apis.payment_api.get_payment(kb_payment_id, false, [], context)

        t_info_plugins = []
        kb_payment.transactions.each do |transaction|
          t_info_plugins << get_payment_transaction_info_from_payu(kb_payment_id, transaction.id, transaction.amount, transaction.currency, options, context.tenant_id)
        end
        t_info_plugins
      end

      def get_payment_transaction_info_from_payu(kb_payment_id, kb_payment_transaction_id, amount, currency, options, kb_tenant_id, response=nil)
        # Guaranteed to have a unique mapping KB transaction <=> PayU HPP creation
        response = @response_model.where("transaction_type = 'PURCHASE' AND kb_payment_id = '#{kb_payment_id}' AND kb_payment_transaction_id = '#{kb_payment_transaction_id}' AND kb_tenant_id = '#{kb_tenant_id}'").order(:created_at)[0] if response.nil?
        raise "Unable to retrieve response for kb_payment_id=#{kb_payment_id}, kb_payment_transaction_id=#{kb_payment_transaction_id}, kb_tenant_id=#{kb_tenant_id}" if response.nil?

        # Retrieve the transaction from PayU
        order_id, transaction_id = response.authorization.split(';')
        payu_status              = (get_payu_status(transaction_id, options) || {})[:status]

        transaction = nil
        if payu_status == 'APPROVED'
          transaction = response.create_payu_latam_transaction(:kb_account_id                => response.kb_account_id,
                                                               :kb_tenant_id                 => response.kb_tenant_id,
                                                               :amount_in_cents              => amount,
                                                               :currency                     => currency,
                                                               :api_call                     => :purchase,
                                                               :kb_payment_id                => kb_payment_id,
                                                               :kb_payment_transaction_id    => kb_payment_transaction_id,
                                                               :transaction_type             => response.transaction_type,
                                                               :payment_processor_account_id => response.payment_processor_account_id,
                                                               :txn_id                       => response.txn_id,
                                                               :payu_latam_response_id       => response.id)
        end

        t_info_plugin        = response.to_transaction_info_plugin(transaction)
        t_info_plugin.status = payu_status_to_plugin_status(payu_status)
        t_info_plugin
      end

      def payu_status_to_plugin_status(payu_status)
        if payu_status == 'APPROVED'
          :PROCESSED
        elsif payu_status == 'DECLINED' || payu_status == 'ERROR' || payu_status == 'EXPIRED'
          :ERROR
        elsif payu_status == 'PENDING'
          :PENDING
        else
          :UNDEFINED
        end
      end

      def get_payu_status(transaction_id, options)
        options = payu_hpp_credentials(options)
        helper  = get_active_merchant_module.const_get('Helper').new(nil, options.delete(:account_id), options)
        helper.transaction_status(transaction_id)
      end

      def payu_hpp_credentials(options)
        payment_processor_account_id = options[:payment_processor_account_id] || :default
        gateway                      = lookup_gateway(payment_processor_account_id)

        {
            :credential2 => gateway.options[:api_login],
            :credential3 => gateway.options[:api_key],
            :credential4 => gateway.options[:country_account_id],
            :account_id  => gateway.options[:merchant_id]
        }
      end

      def get_active_merchant_module
        ::OffsitePayments::Integrations::PayULatam
      end

      def add_required_options(properties, options)
        language           = find_value_from_properties(properties, 'language') || 'en'
        options[:language] ||= language
      end
    end
  end
end
