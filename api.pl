#!/usr/bin/env perl
BEGIN {
    push @INC, '.';
}

use Mojolicious::Lite;
use Mojo::JSON qw(decode_json encode_json);
use DBIx::Simple;
use Data::Dumper;

use SL::Form;

helper db => sub {
    my ( $c, $dbname, $dbhost ) = @_;

    return DBIx::Simple->connect( "dbi:Pg:dbname=$dbname;host=$dbhost", 'postgres', '' );
};

helper myconfig => sub {
    my ( $c, $dbname, $dbhost ) = @_;

    my %myconfig = (
        dbconnect    => "dbi:Pg:dbname=$dbname;host=$dbhost",
        dateformat   => 'yyyy-mm-dd',
        dbdriver     => 'Pg',
        dbhost       => '$dbhost',
        dbname       => $dbname,
        dbpasswd     => '',
        dbport       => '',
        dbuser       => 'postgres',
        numberformat => '1,000.00',
    );

    return \%myconfig;    # Return a reference to the hash
};

post '/post_payment' => sub {
    my $c    = shift;
    my $json = $c->req->json;
    my $db   = $c->db( $json->{dbname}, 'localhost' );

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

            $hash{"id_$index"}                      = $invoice->{invoiceId} * 1;                  # Convert to number
            $hash{"transdate_$index"}               = $payment->{date};
            $hash{"paid_$index"}                    = $payment->{amount} * 1;                     # Convert to number
            $hash{"discount_$index"}                = '0';
            $hash{"checked_$index"}                 = '1';
            $hash{'AR_paid'}                        = $payment->{account};
            $hash{'datepaid'}                       = $payment->{date};
            $hash{'source'}                         = $payment->{source};
            $hash{'memo'}                           = $payment->{memo};
            $hash{'exchangerate'}                   = $payment->{exchangeRate} * 1;               # Convert to number
            $hash{"imported_transaction_id_$index"} = $payment->{imported_transaction_id} * 1;    # Convert to integer

            $total_amount += $payment->{amount} * 1;                                              # Convert to number
            $rowcount++;
        }

        $hash{'amount'}   = $total_amount;
        $hash{'rowcount'} = $rowcount;

        my $form = new Form;
        foreach my $key ( keys %hash ) {
            $form->{$key} = $hash{$key};
        }

        use SL::OP;
        use SL::CP;
        CP->post_payment( $c->myconfig( $json->{dbname}, 'localhost' ), $form );
    }

    $c->render(
        json   => { message => 'All payments are posted' },
        status => 200
    );
};

app->start;

__DATA__

@@ endpoint_testing.txt
curl -X POST https://app.ledger123.com/rma/api.pl/post_payment \
    -H "Content-Type: application/json" \
    -d '{
          "dbname": "ledger28",
          "invoices": [
            {
              "invoiceId": 10148,
              "invoiceType": "AR",
              "payments": [
                {
                  "account": "1200--Bank Account GBP",
                  "source": "testsource",
                  "memo": "testmemo",
                  "exchangeRate": "1",
                  "date": "2007-07-06",
                  "amount": 225.37,
                  "imported_transaction_id": 123
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
                  "exchangeRate": "1",
                  "date": "2007-07-06",
                  "amount": 225.37,
                  "imported_transaction_id": 124
                },
                {
                  "account": "1200--Bank Account GBP",
                  "source": "testsource",
                  "memo": "testmemo",
                  "exchangeRate": "1",
                  "date": "2007-07-07",
                  "amount": 300.50,
                  "imported_transaction_id": 125
                }
              ]
            }
          ]
        }' 
> error.html

