killbill-payu-latam-plugin
==========================

Plugin to use [PayU Latam](http://www.payulatam.com/) as a gateway.

Release builds are available on [Maven Central](http://search.maven.org/#search%7Cga%7C1%7Cg%3A%22org.kill-bill.billing.plugin.ruby%22%20AND%20a%3A%22payu-latam-plugin%22) with coordinates `org.kill-bill.billing.plugin.ruby:payu-latam-plugin`.

Kill Bill compatibility
-----------------------

| Plugin version | Kill Bill version |
| -------------: | ----------------: |
| 0.1.y          | 0.14.z            |

Requirements
------------

The plugin needs a database. The latest version of the schema can be found [here](https://github.com/killbill/killbill-payu-latam-plugin/blob/master/db/ddl.sql).

Configuration
-------------

```
curl -v \
     -X POST \
     -u admin:password \
     -H 'X-Killbill-ApiKey: bob' \
     -H 'X-Killbill-ApiSecret: lazar' \
     -H 'X-Killbill-CreatedBy: admin' \
     -H 'Content-Type: text/plain' \
     -d ':payu_latam:
  - :account_id: colombia
    :api_login: 11959c415b33d0c
    :api_key: 6u39nqhq8ftd0hlvnjfs66eh8c
    :country_account_id: 500538
    :merchant_id: 500238
  - :account_id: panama
    :api_login: 11959c415b33d0c
    :api_key: 6u39nqhq8ftd0hlvnjfs66eh8c
    :country_account_id: 500537
    :merchant_id: 500238' \
     http://127.0.0.1:8080/1.0/kb/tenants/uploadPluginConfig/killbill-payu-latam
```

Because PayU Latam test servers have an improperly installed cert, you maye need a `payu_latam.yml` configuration file under `/var/tmp/bundles/plugins/ruby/killbill-payu-latam/x.y.z/` containing the following:

```
:payu_latam:
  :ssl_strict: false
```

To go to production, specify:

```
:payu_latam:
  :test: false
```

Usage
-----

### Credit cards

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
             "key": "ccCountry",
             "value": "BR"
           },
           {
             "key": "zip",
             "value": "19999-999"
           },
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
             "value": 4422120000000008
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

### HPP

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
       "pluginInfo": {}
     }' \
     "http://127.0.0.1:8080/1.0/kb/accounts/<ACCOUNT_ID>/paymentMethods?isDefault=true&pluginProperty=skip_gw=true"
```

Notes:
* Make sure to replace *ACCOUNT_ID* with the id of the Kill Bill account


To create a voucher:

```
curl -v \
     -u admin:password \
     -H "X-Killbill-ApiKey: bob" \
     -H "X-Killbill-ApiSecret: lazar" \
     -H "Content-Type: application/json" \
     -H "X-Killbill-CreatedBy: demo" \
     -X POST \
     --data-binary '{
       "formFields": [
         {
           "key": "paymentMethod",
           "value": "BALOTO"
         },
         {
           "key": "name",
           "value": "José Pérez"
         },
         {
           "key": "email",
           "value": "payu@killbill.io"
         },
         {
           "key": "city",
           "value": "Bogotá"
         },
         {
           "key": "state",
           "value": "Cundinamarca"
         },
         {
           "key": "country",
           "value": "CO"
         },
         {
           "key": "amount",
           "value": 400000
         },
         {
           "key": "currency",
           "value": "COP"
         }
       ]
     }' \
     "http://127.0.0.1:8080/1.0/kb/paymentGateways/hosted/form/<ACCOUNT_ID>"
```

Notes:
* Make sure to replace *ACCOUNT_ID* with the id of the Kill Bill account
* This call can take some time, make sure to update the plugin timeout accordingly (property `org.killbill.payment.plugin.timeout`)

Here is what happens behind the scenes:

* The plugin creates the voucher in PayU.
* The plugin creates the payment in Kill Bill. During the payment call, Kill Bill will call back the plugin, which will in turn create a row in the `responses` table (to keep track of the created vouchers in PayU). A Kill Bill transaction id will always match a unique voucher in PayU.
* Kill Bill will start polling the plugin for the payment status, which it will get from PayU using the queries API.

