require 'spec_helper'

ActiveMerchant::Billing::Base.mode = :test

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CreditCard < Model
      def number=(value)
        @number = value
      end
    end
  end
end

describe Killbill::PayuLatam::PaymentPlugin do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  before(:each) do
    # PayULatamGateway's test server has an improperly installed cert
    ::ActiveMerchant::Billing::PayULatamGateway.ssl_strict = false

    @plugin = Killbill::PayuLatam::PaymentPlugin.new

    @account_api    = ::Killbill::Plugin::ActiveMerchant::RSpec::FakeJavaUserAccountApi.new
    @payment_api    = ::Killbill::Plugin::ActiveMerchant::RSpec::FakeJavaPaymentApi.new
    svcs            = {:account_user_api => @account_api, :payment_api => @payment_api}
    @plugin.kb_apis = Killbill::Plugin::KillbillApi.new('payu', svcs)

    @call_context           = ::Killbill::Plugin::Model::CallContext.new
    @call_context.tenant_id = '00000011-0022-0033-0044-000000000055'
    @call_context           = @call_context.to_ruby(@call_context)

    @plugin.logger       = Logger.new(STDOUT)
    @plugin.logger.level = Logger::INFO
    @plugin.conf_dir     = File.expand_path(File.dirname(__FILE__) + '../../../../')
    @plugin.start_plugin

    @properties = []
    # Go through Brazil (supports auth/capture)
    @properties << create_pm_kv_info('payment_processor_account_id', 'brazil')
    # Required CVV for token-based transactions
    @properties << create_pm_kv_info('security_code', '123')
    @properties << create_pm_kv_info('payment_country', 'BR')

    @pm       = create_payment_method(::Killbill::PayuLatam::PayuLatamPaymentMethod, nil, @call_context.tenant_id, @properties, valid_cc_info)
    @amount   = BigDecimal.new('500')
    @currency = 'BRL'

    kb_payment_id = SecureRandom.uuid
    1.upto(6) do
      @kb_payment = @payment_api.add_payment(kb_payment_id)
    end
  end

  after(:each) do
    @plugin.stop_plugin
  end

  it 'should be able to charge a Credit Card directly' do
    properties = build_pm_properties(nil, valid_cc_info)
    properties += @properties

    # We created the payment method, hence the rows
    Killbill::PayuLatam::PayuLatamResponse.all.size.should == 1
    Killbill::PayuLatam::PayuLatamTransaction.all.size.should == 0

    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, SecureRandom.uuid, @amount, @currency, properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE

    responses = Killbill::PayuLatam::PayuLatamResponse.all
    responses.size.should == 2
    responses[0].api_call.should == 'add_payment_method'
    responses[0].message.should == 'Successful transaction'
    responses[1].api_call.should == 'purchase'
    responses[1].message.should == 'The transaction was approved'
    transactions = Killbill::PayuLatam::PayuLatamTransaction.all
    transactions.size.should == 1
    transactions[0].api_call.should == 'purchase'
  end

  # The sandbox doesn't support void, capture, nor refund

  #xit 'should be able to charge and refund' do
  #  payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.amount.should == @amount
  #  payment_response.transaction_type.should == :PURCHASE
  #
  #  # Try a full refund
  #  refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
  #  refund_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  refund_response.amount.should == @amount
  #  refund_response.transaction_type.should == :REFUND
  #end

  #xit 'should be able to auth, capture and refund' do
  #  payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.amount.should == @amount
  #  payment_response.transaction_type.should == :AUTHORIZE
  #
  #  # Try multiple partial captures
  #  partial_capture_amount = BigDecimal.new('10')
  #  1.upto(3) do |i|
  #    payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[i].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
  #    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #    payment_response.amount.should == partial_capture_amount
  #    payment_response.transaction_type.should == :CAPTURE
  #  end
  #
  #  # Try a partial refund
  #  refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[4].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
  #  refund_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  refund_response.amount.should == partial_capture_amount
  #  refund_response.transaction_type.should == :REFUND
  #
  #  # Try to capture again
  #  payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[5].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.amount.should == partial_capture_amount
  #  payment_response.transaction_type.should == :CAPTURE
  #end

  #it 'should be able to auth and void' do
  #  payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.amount.should == @amount
  #  payment_response.transaction_type.should == :AUTHORIZE
  #
  #  payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.transaction_type.should == :VOID
  #end

  #it 'should be able to auth, partial capture and void' do
  #  payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.amount.should == @amount
  #  payment_response.transaction_type.should == :AUTHORIZE
  #
  #  partial_capture_amount = BigDecimal.new('10')
  #  payment_response       = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.amount.should == partial_capture_amount
  #  payment_response.transaction_type.should == :CAPTURE
  #
  #  payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[2].id, @pm.kb_payment_method_id, @properties, @call_context)
  #  payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
  #  payment_response.transaction_type.should == :VOID
  #end

  private

  def valid_cc_info
    {
        # We can't use the default credit card number as it's seen as a US one (the testing account doesn't allow international credit cards)
        :cc_number    => '4422120000000008',
        # Enter APPROVED for the cardholder name value if you want the transaction to be approved or REJECTED if you want it to be rejected
        :cc_last_name => 'APPROVED'
    }
  end
end
