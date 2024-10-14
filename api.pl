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
    my ( $c, $dbname ) = @_;

    return DBIx::Simple->connect( "dbi:Pg:dbname=$dbname", 'postgres', '' );
};

helper myconfig => sub {
    my $c = shift;

    my %myconfig = (
        dbconnect    => "dbi:Pg:dbname=ledger28",
        dateformat   => 'dd/mm/yy',
        dbdriver     => 'Pg',
        dbhost       => '',
        dbname       => 'ledger28',
        dbpasswd     => '',
        dbport       => '',
        dbuser       => 'postgres',
        numberformat => '1,000.00',
    );

    return \%myconfig;    # Return a reference to the hash
};


post '/post_payment' => sub {
    my $c             = shift;
    my $database_name = 'ledger28';
    my $db            = $c->db($database_name);
    my $json          = $c->req->json;

    my $arap = lc( $json->[0]->{ARAP} );
    my $vc   = $arap eq 'ar' ? 'customer' : 'vendor';
    my $type = $arap eq 'ar' ? 'receipt'  : 'payment';
    my ($customer_id, $currency) = $db->query("
        SELECT customer_id, curr
        FROM ar
        WHERE id = ?", $json->[0]->{id}
    )->list;
    my ($ar_accno, $ar_description) = $db->query("
        SELECT accno, description
        FROM chart
        WHERE link = 'AR'
        AND id IN (SELECT chart_id FROM acc_trans WHERE trans_id = ?)
        LIMIT 1",
        $json->[0]->{id}
    )->list;


    my $AR = "$ar_accno--$ar_description";

    my $hash = {
        'formname'     => 'receipt',
        'AR'           => $AR,
        'AR_paid'      => $json->[0]->{payment}->{account},
        'arap'         => $arap,
        'vc'           => $vc,
        'payment'      => 'payment',
        'type'         => $type,
        'rowcount'     => 1,
        'currency'     => $currency,
        'exchangerate' => $json->[0]->{payment}->{exchangeRate},    # Use exchange rate from JSON
        'customer_id'  => $customer_id,
        'ARAP'         => $json->[0]->{ARAP},
        'datepaid'     => $json->[0]->{payment}->{date},
        'source'       => $json->[0]->{payment}->{source},
        'memo'         => $json->[0]->{payment}->{memo},
        'amount'       => $json->[0]->{payment}->{amount},
        'id_1'         => $json->[0]->{id},
        'transdate_1'  => $json->[0]->{payment}->{date},
        'discount_1'   => '0',
        'paid_1'       => $json->[0]->{payment}->{amount},
        'checked_1'    => '1',
    };

    #die $c->dumper($hash);

    my $form         = new Form;
    foreach my $key (keys %$hash) {
        $form->{$key} = $hash->{$key};
    }

    use SL::OP;
    use SL::CP;

    CP->post_payment($c->myconfig, $form);

    $c->render(
        json   => { message => 'Payment is posted' },
        status => 200
    );
};


get '/' => sub {
    my $c = shift;

    # Prepare the sample JSON data
    my $json_data = [
        {
            "ARAP"    => "AR",
            "id"      => 10000,
            "payment" => {
                "date"         => "01.01.1970",
                "amount"       => 100.00,
                "source"       => "Text",
                "memo"         => "Text",
                "exchangeRate" => 1.02,
                "account"      => "1001--Chart of acc"
            }
        }
    ];

    # Pass the JSON data to the template
    $c->stash( json_data => encode_json($json_data) );
    $c->render( template => 'index' );
} => 'home';

app->start;

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Form</title>
</head>
<body>
  <h1>Post Payment</h1>
  <button id="postButton">Post Payment</button>

  <script>
    // Define the postPayment function here
    async function postPayment() {
      // Get the JSON data passed from the route and convert to valid JS
      const data = <%== $json_data %>;

      try {
        const response = await fetch('<%= url_for('post_payment')->to_abs->scheme('https') %>', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(data)
        });
        
        const result = await response.json();
        alert('Status: ' + response.status + ', Message: ' + result.message);
      } catch (error) {
        alert('Error posting payment: ' + error );
      }
    }

    // Attach the postPayment function to the button after the DOM is loaded
    document.getElementById('postButton').addEventListener('click', postPayment);
  </script>
</body>
</html>

