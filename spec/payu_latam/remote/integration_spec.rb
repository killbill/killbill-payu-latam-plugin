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

class PayUJavaPaymentApi < ::Killbill::Plugin::ActiveMerchant::RSpec::FakeJavaPaymentApi

  def get_account_payment_methods(kb_account_id, plugin_info, properties, context)
    [OpenStruct.new(:plugin_name => 'killbill-payu-latam', :id => SecureRandom.uuid)]
  end

  def create_purchase(kb_account, kb_payment_method_id, kb_payment_id, amount, currency, payment_external_key, payment_transaction_external_key, properties, context)
    add_payment(SecureRandom.uuid, SecureRandom.uuid, payment_transaction_external_key, :PURCHASE)
  end
end

describe Killbill::PayuLatam::PaymentPlugin do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  before(:each) do
    # PayULatamGateway's test server has an improperly installed cert
    ::ActiveMerchant::Billing::PayULatamGateway.ssl_strict = false

    ::Killbill::PayuLatam::PayuLatamPaymentMethod.delete_all
    ::Killbill::PayuLatam::PayuLatamResponse.delete_all
    ::Killbill::PayuLatam::PayuLatamTransaction.delete_all

    @payment_api = PayUJavaPaymentApi.new

    @plugin = build_plugin(::Killbill::PayuLatam::PaymentPlugin, 'payu_latam')
    svcs = @plugin.kb_apis.proxied_services
    svcs[:payment_api] = @payment_api
    @plugin.kb_apis = ::Killbill::Plugin::KillbillApi.new('payu_latam', svcs)

    @plugin.start_plugin

    @call_context = build_call_context

    @properties = []
    # Go through Brazil (supports auth/capture)
    @properties << build_property('payment_processor_account_id', 'brazil')
    # Required CVV for token-based transactions
    @properties << build_property('security_code', '123')
    @properties << build_property('payment_country', 'BR')

    @pm         = create_payment_method(::Killbill::PayuLatam::PayuLatamPaymentMethod, nil, @call_context.tenant_id, @properties, valid_cc_info)
    @amount     = BigDecimal.new('500')
    @currency   = 'BRL'

    kb_payment_id = SecureRandom.uuid
    1.upto(6) do
      @kb_payment = @plugin.kb_apis.proxied_services[:payment_api].add_payment(kb_payment_id)
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

  # HPP
  it 'should generate vouchers correctly' do
    properties         = [build_property('payment_processor_account_id', 'colombia')]
    nb_payments        = @payment_api.payments.size

    # Generate the voucher
    payment_properties = {
        :externalKey => SecureRandom.uuid,
        :amount      => 6000,
        :currency    => 'COP'
    }
    descriptor_fields  = @plugin.hash_to_properties(payment_properties)
    descriptor         = @plugin.build_form_descriptor(@pm.kb_account_id, descriptor_fields, properties, @plugin.kb_apis.create_context(@call_context.tenant_id))

    # Verify the descriptor
    descriptor.kb_account_id.should == @pm.kb_account_id
    descriptor.form_method.should == 'GET'
    descriptor.form_url.should_not be_nil
    # For manual debugging
    puts "Redirect to: #{descriptor.form_url}"
    payu_order_id = @plugin.find_value_from_properties(descriptor.form_fields, 'order_id')
    payu_order_id.should_not be_nil
    payu_transaction_id = @plugin.find_value_from_properties(descriptor.form_fields, 'transaction_id')
    payu_transaction_id.should_not be_nil

    # Verify the pending payment has been created in Kill Bill
    @payment_api.payments.size.should == nb_payments + 1
    payment = @payment_api.payments[-1]
    payment.transactions.size.should == 1
    payment.transactions[0].external_key.should == payment_properties[:externalKey]

    # Trigger manually the purchase call (this is done automatically in a live system)
    properties << build_property('from_hpp', 'true')
    properties << build_property('payu_order_id', payu_order_id)
    properties << build_property('payu_transaction_id', payu_transaction_id)
    payment_response = @plugin.purchase_payment(@pm.kb_account_id, payment.id, payment.transactions[0].id, @pm.id, payment_properties[:amount], payment_properties[:currency], properties, @plugin.kb_apis.create_context(@call_context.tenant_id))
    payment_response.status.should == :PENDING

    # Verify the response row was created
    response = Killbill::PayuLatam::PayuLatamResponse.all[-1]
    response.kb_account_id.should == @pm.kb_account_id
    response.kb_payment_id.should == payment.id
    response.kb_payment_transaction_id.should == payment.transactions[0].id
    response.transaction_type.should == 'PURCHASE'
    response.authorization.should == "#{payu_order_id};#{payu_transaction_id}"
    response.payment_processor_account_id.should == 'colombia'
    response.kb_tenant_id.should == @call_context.tenant_id

    # Verify the pending payment has been created in Kill Bill
    @payment_api.payments.size.should == nb_payments + 1
    payment = @payment_api.payments[-1]
    payment.transactions.size.should == 1
    payment.transactions[0].external_key.should == payment_properties[:externalKey]

    # Verify the payment in PayU (simulate the Kill Bill polling)
    t_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, payment.id, properties, @plugin.kb_apis.create_context(@call_context.tenant_id))
    t_info_plugins.size.should == 1
    t_info_plugin = t_info_plugins[0]
    #t_info_plugin.status.should == :PENDING
    t_info_plugin.kb_payment_id.should == payment.id
    t_info_plugin.kb_transaction_payment_id.should == payment.transactions[0].id
    t_info_plugin.transaction_type.should == :PURCHASE
    #t_info_plugin.amount.should == payment_properties[:amount]
    #t_info_plugin.currency.should == payment_properties[:currency]
  end

  private

  def valid_cc_info
    {
        # To work-around fraud detection bugs in the sandbox
        :country      => 'BR',
        :zip          => '19999-999',
        # We can't use the default credit card number as it's seen as a US one (the testing account doesn't allow international credit cards)
        :cc_number    => '4422120000000008',
        # Enter APPROVED for the cardholder name value if you want the transaction to be approved or REJECTED if you want it to be rejected
        :cc_last_name => 'APPROVED'
    }
  end
end
