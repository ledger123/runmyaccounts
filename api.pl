#!/usr/bin/env perl
BEGIN {
    push @INC, '.';
}

use Mojolicious::Lite;
use Mojo::JSON qw(decode_json encode_json);
use DBIx::Simple;
use Data::Dumper;
use Config::Tiny;
use SL::Form;

plugin 'JSONConfig' => { file => 'api.json' };

my $dbhost   = app->config->{dbhost};
my $dbuser   = app->config->{dbuser};
my $dbpasswd = app->config->{dbpasswd};

helper db => sub {
    my ( $c, $dbname ) = @_;

    my $dbh = DBI->connect( "dbi:Pg:dbname=$dbname;host=$dbhost", $dbuser, $dbpasswd, { AutoCommit => 0, RaiseError => 1 } );

    return DBIx::Simple->connect($dbh);
};

helper myconfig => sub {
    my ( $c, $dbname ) = @_;

    my %myconfig = (
        dbconnect    => "dbi:Pg:dbname=$dbname;host=$dbhost",
        dateformat   => 'yyyy-mm-dd',
        dbdriver     => 'Pg',
        dbhost       => $dbhost,
        dbname       => $dbname,
        dbpasswd     => $dbpasswd,
        dbport       => '',
        dbuser       => $dbuser,
        numberformat => '1,000.00',
    );

    return \%myconfig;    # Return a reference to the hash
};

post '/post_payment' => sub {
    my $c    = shift;
    my $json = $c->req->json;
    my $db   = $c->db( $json->{clientName} );

    my $rc;
    my $precision = $db->query("SELECT fldvalue FROM defaults WHERE fldname='precision'")->list;
    $precision *= 1;

    # Loop through each invoice in the JSON array
    foreach my $invoice ( @{ $json->{invoices} } ) {
        my $arap = lc( $invoice->{invoiceType} );
        my $vc   = $arap eq 'ar' ? 'customer' : 'vendor';
        my $type = $arap eq 'ar' ? 'receipt'  : 'payment';

        my $query = qq|SELECT customer_id, curr FROM $arap WHERE id = $invoice->{invoiceId}*1|;
        my ( $customer_id, $currency ) = $db->query($query)->list;

        my $total_amount = 0;
        my $rowcount     = 0;
        my %hash         = (
            'formname'    => $type,
            'AR_paid'     => '',                        # We'll set this later
            'arap'        => $arap,
            'vc'          => $vc,
            'type'        => $type,
            'currency'    => $currency,
            'customer_id' => $customer_id,
            'ARAP'        => $invoice->{invoiceType},
            'datepaid'    => '',                        # We'll set this later
            'source'      => '',                        # We'll set this later
            'memo'        => '',                        # We'll set this later
        );

        # Loop through each payment for the current invoice
        foreach my $i ( 0 .. $#{ $invoice->{payments} } ) {
            my $payment = $invoice->{payments}->[$i];
            my $index   = $i + 1;

            $hash{"id_$index"}                      = $invoice->{invoiceId} * 1;                # Convert to number
            $hash{"transdate_$index"}               = $payment->{date};
            $hash{"paid_$index"}                    = $payment->{amount} * 1;                   # Convert to number
            $hash{"discount_$index"}                = '0';
            $hash{"checked_$index"}                 = '1';
            $hash{'AR_paid'}                        = $payment->{account};
            $hash{'datepaid'}                       = $payment->{date};
            $hash{'source'}                         = $payment->{source};
            $hash{'memo'}                           = $payment->{memo};
            $hash{'exchangerate'}                   = $payment->{exchangeRate} * 1;             # Convert to number
            $hash{"imported_transaction_id_$index"} = $payment->{importedTransactionId} * 1;    # Convert to integer

            $total_amount += $payment->{amount} * 1;                                            # Convert to number
            $rowcount++;
        }

        $hash{'amount'}   = $total_amount;
        $hash{'rowcount'} = $rowcount;

        my $form = new Form;
        $form->{precision} = $precision;
        foreach my $key ( keys %hash ) {
            $form->{$key} = $hash{$key};
        }

        use SL::OP;
        use SL::CP;
        $rc += CP->post_payment( $c->myconfig( $json->{clientName} ), $form );
    }

    if ( !$rc ) {
        return $c->render(
            json   => { error => 'Failed to post payments' },
            status => 400
        );
    } else {
        return $c->render(
            json   => { message => "Payments are posted for $rc invoices." },
            status => 200
        );
    }
};

post '/delete_payment' => sub {
    my $c    = shift;
    my $json = $c->req->json;
    my $db   = $c->db( $json->{clientName} );

    my $rc;

    foreach my $invoice ( @{ $json->{invoices} } ) {
        my $arap = lc( $invoice->{invoiceType} );

        my $acc_trans_deleted = $db->query( 'DELETE FROM acc_trans WHERE imported_transaction_id = ?',     $invoice->{importedTransactionId} );
        my $payment_deleted   = $db->query( 'DELETE FROM payment WHERE trans_id = ? AND exchangerate = ?', $invoice->{invoiceId}, $invoice->{exchangeRate} );

        my $datepaid = $db->query("
            SELECT MAX(transdate)
            FROM acc_trans
            WHERE trans_id = ? 
            AND chart_id IN (SELECT id FROM chart WHERE link LIKE '%_paid%')", $invoice->{invoiceId}
        )->list;

        my $paid = $db->query("
            SELECT SUM(amount)
            FROM acc_trans
            WHERE trans_id = ? 
            AND NOT fx_transaction
            AND chart_id IN (SELECT id FROM chart WHERE link LIKE '%_paid%')", $invoice->{invoiceId}
        )->list;
        $paid *= -1; 

        my $exchangerate = $db->query("SELECT exchangerate FROM ar WHERE id = ?", $invoice->{invoiceId})->list;
        $exchangerate ||= 1;

        my $fxpaid = $paid * $exchangerate;

        my $arap_updated      = $db->query( "
            UPDATE $arap
            SET paid = ?, fxpaid = ?, datepaid = ?
            WHERE id = ?", $paid, $fxpaid, $datepaid, $invoice->{invoiceId} 
        );

        $rc++ if $acc_trans_deleted && $payment_deleted && $arap_updated;
    }

    if ( !$rc ) {
        $db->rollback;
        return $c->render(
            json   => { error => 'Failed to post payments' },
            status => 400
        );
    } else {
        $db->commit;
        return $c->render(
            json   => { message => "Payments are posted for $rc invoices." },
            status => 200
        );
    }
};

app->start;

__DATA__

@@ endpoint_testing.txt
curl -X POST https://app.ledger123.com/rma/api.pl/post_payment \
    -H "Content-Type: application/json" \
    -d '{
          "clientName": "ledger28",
          "invoices": [
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "payments": [
                {
                  "account": "1200--Bank Account GBP",
                  "source": "testsource",
                  "memo": "testmemo",
                  "exchangeRate": 1,
                  "date": "2007-07-06",
                  "amount": 225.37,
                  "importedTransactionId": 123
                }
              ]
            },
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "payments": [
                {
                  "account": "1200--Bank Account GBP",
                  "source": "testsource",
                  "memo": "testmemo",
                  "exchangeRate": 1,
                  "date": "2007-07-06",
                  "amount": 225.37,
                  "importedTransactionId": 124
                },
                {
                  "account": "1200--Bank Account GBP",
                  "source": "testsource",
                  "memo": "testmemo",
                  "exchangeRate": 1,
                  "date": "2007-07-07",
                  "amount": 300.50,
                  "importedTransactionId": 125
                }
              ]
            }
          ]
        }' > error.html

# Single invoice payment posting call
curl -X POST https://app.ledger123.com/rma/api.pl/post_payment \
    -H "Content-Type: application/json" \
    -d '{
          "clientName": "ledger28",
          "invoices": [
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "payments": [
                {
                  "account": "1200--Bank Account GBP",
                  "source": "testsource",
                  "memo": "testmemo",
                  "exchangeRate": 1.3,
                  "date": "2007-07-06",
                  "amount": 225.37,
                  "importedTransactionId": 123
                }
              ]
            }
          ]
        }' > error.html


# Single invoice delete payment
curl -X POST https://app.ledger123.com/rma/api.pl/delete_payment \
    -H "Content-Type: application/json" \
    -d '{
          "clientName": "ledger28",
          "invoices": [
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "exchangeRate": 1.3,
              "importedTransactionId": 123
            }
          ]
        }' > error.html


# Multiple invoices delete payment
curl -X POST https://app.ledger123.com/rma/api.pl/delete_payment \
    -H "Content-Type: application/json" \
    -d '{
          "clientName": "ledger28",
          "invoices": [
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "exchangeRate": 1,
              "importedTransactionId": 123
            },
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "exchangeRate": 1,
              "importedTransactionId": 124
            },
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "exchangeRate": 1,
              "importedTransactionId": 125
            }
          ]
        }' > error.html

