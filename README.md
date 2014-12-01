killbill-payu-latam-plugin
==========================

Plugin to use [PayU Latam](http://www.payulatam.com/) as a gateway

Usage
-----

Add a payment method:

```
curl -v \
     -u admin:password \
     -H "X-Killbill-ApiKey: bob" \
     -H "X-Killbill-ApiSecret: lazar" \
     -H "Content-Type: application/json" \
     -H "X-Killbill-CreatedBy: demo" \
     -X POST \
     --data-binary '{
       "pluginName": "killbill-payu-latam",
       "pluginInfo": {
         "properties": [
           {
             "key": "ccLastName",
             "value": "APPROVED"
           },
           {
             "key": "ccExpirationMonth",
             "value": 12
           },
           {
             "key": "ccExpirationYear",
             "value": 2017
           },
           {
             "key": "ccNumber",
             "value": 4111111111111111
           }
         ]
       }
     }' \
     "http://127.0.0.1:8080/1.0/kb/accounts/<ACCOUNT_ID>/paymentMethods?isDefault=true&pluginProperty=skip_gw=true"
```

Notes:
* Make sure to replace *ACCOUNT_ID* with the id of the Kill Bill account
* Remove `skip_gw=true` to store the credit card in the [PayU vault](http://docs.payulatam.com/en/api-integration/what-you-should-know-about-api-tokenization/)

To trigger a payment:

```
curl -v \
     -u admin:password \
     -H "X-Killbill-ApiKey: bob" \
     -H "X-Killbill-ApiSecret: lazar" \
     -H "Content-Type: application/json" \
     -H "X-Killbill-CreatedBy: demo" \
     -X POST \
     --data-binary '{"transactionType":"PURCHASE","amount":"500","currency":"BRL","transactionExternalKey":"INV-'$(uuidgen)'-PURCHASE"}' \
    "http://127.0.0.1:8080/1.0/kb/accounts/<ACCOUNT_ID>/payments?pluginProperty=security_code=123"
```

Notes:
* Make sure to replace *ACCOUNT_ID* with the id of the Kill Bill account
* Required plugin properties (such as `security_code`) will depend on the [country](http://docs.payulatam.com/en/api-integration/api-payments/4132-2/)
* To trigger payments in different countries, set `payment_processor_account_id=XXX` where XXX is one of colombia, panama, peru, mexico, argentina or brazil
