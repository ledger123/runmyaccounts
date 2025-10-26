#!/usr/bin/env perl
BEGIN {
    push @INC, '.';
}

use Mojolicious::Lite;
use DBIx::Simple;
use Data::Dumper;
use SL::Form;
use SL::IS;
use SL::PE;
use SL::RP;
use SL::AA;

my $dbhost   = 'localhost';
my $dbuser   = 'postgres';
my $dbpasswd = '';

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
        templates    => 'templates/demo@ledger28',
        tempdir      => '/tmp',
    );

    return \%myconfig;
};

helper create_invoice => sub {
    my ( $c, $invoice_data ) = @_;

    my $db = $c->db( $invoice_data->{clientName} );

    my $rc;
    my $precision = $db->query("SELECT fldvalue FROM defaults WHERE fldname='precision'")->list;
    $precision *= 1;
    $precision ||= 2;

    # Get customer currency if not provided
    my $currency = $invoice_data->{currency};
    if ( !$currency && $invoice_data->{customer_id} ) {
        $currency = $db->query( "SELECT curr FROM customer WHERE id = ?", $invoice_data->{customer_id} )->list;
    }
    $currency ||= 'GBP';

    # Build form hash
    my %hash = (
        'type'          => 'invoice',
        'vc'            => 'customer',
        'ARAP'          => 'AR',
        'formname'      => 'invoice',
        'currency'      => $currency,
        'customer_id'   => $invoice_data->{customer_id} * 1,
        'transdate'     => $invoice_data->{transdate}     || '',
        'duedate'       => $invoice_data->{duedate}       || '',
        'invnumber'     => $invoice_data->{invnumber}     || '',
        'ordnumber'     => $invoice_data->{ordnumber}     || '',
        'ponumber'      => $invoice_data->{ponumber}      || '',
        'notes'         => $invoice_data->{notes}         || '',
        'intnotes'      => $invoice_data->{intnotes}      || '',
        'AR'            => $invoice_data->{AR}            || '1100',
        'exchangerate'  => $invoice_data->{exchangerate}  || 1,
        'department_id' => $invoice_data->{department_id} || 0,
        'warehouse_id'  => $invoice_data->{warehouse_id}  || 0,
        'employee_id'   => $invoice_data->{employee_id}   || 0,
        'taxincluded'   => $invoice_data->{taxincluded}   || 0,
        'paidaccounts'  => 0,
        'rowcount'      => 0,
    );

    # Add invoice items
    my $rowcount = 0;
    foreach my $item ( @{ $invoice_data->{items} } ) {
        $rowcount++;

        $hash{"id_$rowcount"}          = $item->{parts_id} * 1;
        $hash{"partnumber_$rowcount"}  = $item->{partnumber}  || '';
        $hash{"description_$rowcount"} = $item->{description} || '';
        $hash{"qty_$rowcount"}         = $item->{qty} * 1;
        $hash{"sellprice_$rowcount"}   = $item->{sellprice} * 1;
        $hash{"unit_$rowcount"}        = $item->{unit}        || 'ea';
        $hash{"discount_$rowcount"}    = $item->{discount}    || 0;
        $hash{"taxaccounts_$rowcount"} = $item->{taxaccounts} || '';
    }

    $hash{'rowcount'} = $rowcount;

    # Add payment information if provided
    if ( $invoice_data->{payment} && $invoice_data->{payment}{amount} ) {
        $hash{'paidaccounts'}   = 1;
        $hash{'paid_1'}         = $invoice_data->{payment}{amount} * 1;
        $hash{'datepaid_1'}     = $invoice_data->{payment}{datepaid}     || $invoice_data->{transdate};
        $hash{'AR_paid_1'}      = $invoice_data->{payment}{account}      || '1200';
        $hash{'source_1'}       = $invoice_data->{payment}{source}       || '';
        $hash{'memo_1'}         = $invoice_data->{payment}{memo}         || '';
        $hash{'exchangerate_1'} = $invoice_data->{payment}{exchangerate} || 1;
    }

    # Create form object and populate
    my $form = new Form;
    $form->{precision} = $precision;
    foreach my $key ( keys %hash ) {
        $form->{$key} = $hash{$key};
    }

    # Post the invoice
    eval { $rc = IS->post_invoice( $c->myconfig( $invoice_data->{clientName} ), $form ); };

    if ( $@ || !$rc ) {
        $db->rollback;
        return {
            error   => $@ || 'Failed to create invoice',
            success => 0
        };
    } else {
        $db->commit;
        return {
            message    => "Invoice created successfully",
            invoice_id => $form->{id},
            invnumber  => $form->{invnumber},
            success    => 1
        };
    }
};

# New helper for creating AR transactions
helper create_ar_transaction => sub {
    my ( $c, $transaction_data ) = @_;

    my $db = $c->db( $transaction_data->{clientName} );

    my $rc;
    my $precision = $db->query("SELECT fldvalue FROM defaults WHERE fldname='precision'")->list;
    $precision *= 1;
    $precision ||= 2;

    # Get customer currency if not provided
    my $currency = $transaction_data->{currency};
    if ( !$currency && $transaction_data->{customer_id} ) {
        $currency = $db->query( "SELECT curr FROM customer WHERE id = ?", $transaction_data->{customer_id} )->list;
    }
    $currency ||= 'GBP';

    # Build form hash for AR transaction
    my %hash = (
        'type'            => 'transaction',
        'vc'              => 'customer',
        'ARAP'            => 'AR',
        'formname'        => 'transaction',
        'currency'        => $currency,
        'customer_id'     => $transaction_data->{customer_id} * 1,
        'transdate'       => $transaction_data->{transdate}       || '',
        'duedate'         => $transaction_data->{duedate}         || '',
        'invnumber'       => $transaction_data->{invnumber}       || '',
        'ordnumber'       => $transaction_data->{ordnumber}       || '',
        'ponumber'        => $transaction_data->{ponumber}        || '',
        'notes'           => $transaction_data->{notes}           || '',
        'intnotes'        => $transaction_data->{intnotes}        || '',
        'description'     => $transaction_data->{description}     || '',
        'AR'              => $transaction_data->{AR}              || '1100',
        'exchangerate'    => $transaction_data->{exchangerate}    || 1,
        'department_id'   => $transaction_data->{department_id}   || 0,
        'employee_id'     => $transaction_data->{employee_id}     || 0,
        'taxincluded'     => $transaction_data->{taxincluded}     || 0,
        'onhold'          => $transaction_data->{onhold}          || 0,
        'terms'           => $transaction_data->{terms}           || '',
        'dcn'             => $transaction_data->{dcn}             || '',
        'paidaccounts'    => 0,
        'rowcount'        => 0,
    );

    # Add AR transaction line items (amounts and accounts)
    my $rowcount = 0;
    
    foreach my $line ( @{ $transaction_data->{lines} } ) {
        $rowcount++;

        $hash{"amount_$rowcount"}      = $line->{amount} * 1;
        $hash{"AR_amount_$rowcount"}   = $line->{account}     || '4000';
        $hash{"description_$rowcount"} = $line->{description} || '';
    }

    $hash{'rowcount'} = $rowcount;

    # Add tax information
    if ( $transaction_data->{taxes} && ref($transaction_data->{taxes}) eq 'ARRAY' ) {
        my @tax_accounts;
        
        foreach my $tax ( @{ $transaction_data->{taxes} } ) {
            my $tax_id = $tax->{tax_id};  # e.g., "2200", "2205"
            
            $hash{"tax_$tax_id"}        = $tax->{amount} * 1;
            $hash{"calctax_$tax_id"}    = $tax->{calctax}    || 1;
            $hash{"AR_tax_$tax_id"}     = $tax->{account}     || "$tax_id--VAT";
            $hash{$tax_id . "_rate"}    = $tax->{rate}        || 0;
            $hash{$tax_id . "_description"} = $tax->{description} || '';
            $hash{$tax_id . "_taxnumber"}   = $tax->{taxnumber}   || '';
            
            push @tax_accounts, $tax_id;
        }
        
        $hash{'taxaccounts'} = join(' ', @tax_accounts);
    }

    # Add payment information if provided
    if ( $transaction_data->{payment} && $transaction_data->{payment}{amount} ) {
        $hash{'paidaccounts'}   = 1;
        $hash{'paid_1'}         = $transaction_data->{payment}{amount} * 1;
        $hash{'datepaid_1'}     = $transaction_data->{payment}{datepaid}     || $transaction_data->{transdate};
        $hash{'AR_paid_1'}      = $transaction_data->{payment}{account}      || '1200';
        $hash{'source_1'}       = $transaction_data->{payment}{source}       || '';
        $hash{'memo_1'}         = $transaction_data->{payment}{memo}         || '';
        $hash{'exchangerate_1'} = $transaction_data->{payment}{exchangerate} || 1;
        $hash{'vr_id_1'}        = $transaction_data->{payment}{vr_id}        || '';
        $hash{'cleared_1'}      = $transaction_data->{payment}{cleared}      || '';
    }

    # Create form object and populate
    my $form = new Form;
    $form->{precision} = $precision;
    foreach my $key ( keys %hash ) {
        $form->{$key} = $hash{$key};
    }

    # Post the AR transaction using AA module
    eval { $rc = AA->post_transaction( $c->myconfig( $transaction_data->{clientName} ), $form ); };

    if ( $@ || !$rc ) {
        $db->rollback;
        return {
            error   => $@ || 'Failed to create AR transaction',
            success => 0
        };
    } else {
        $db->commit;
        return {
            message       => "AR transaction created successfully",
            transaction_id => $form->{id},
            invnumber     => $form->{invnumber},
            success       => 1
        };
    }
};

# Main page - List invoices and transactions
get '/' => sub {
    my $c = shift;

    my $dbname = $c->param('dbname') || 'ledger28';
    my $db     = $c->db($dbname);

    my @invoices = $db->query('SELECT id, invnumber, transdate, amount, paid, invoice FROM ar ORDER BY id DESC LIMIT 100')->hashes;

    $c->stash(
        invoices => \@invoices,
        dbname   => $dbname
    );
    $c->render( template => 'index' );
};

# REST API endpoint - Create invoice
post '/api/create_invoice' => sub {
    my $c = shift;

    my $invoice_data = $c->req->json;
    $invoice_data->{clientName} ||= 'ledger28';

    my $result = $c->create_invoice($invoice_data);

    $c->render( json => $result );
};

# REST API endpoint - Create AR transaction
post '/api/create_ar_transaction' => sub {
    my $c = shift;

    my $transaction_data = $c->req->json;
    $transaction_data->{clientName} ||= 'ledger28';

    my $result = $c->create_ar_transaction($transaction_data);

    $c->render( json => $result );
};

# Test invoice creation page
get '/test_invoices' => sub {
    my $c = shift;
    $c->render( template => 'test_invoices' );
};

# Test AR transaction creation page
get '/test_ar_transactions' => sub {
    my $c = shift;
    $c->render( template => 'test_ar_transactions' );
};

# Process test invoice creation
post '/process_test_invoices' => sub {
    my $c = shift;

    my $count        = $c->param('count')        || 1;
    my $with_payment = $c->param('with_payment') || 0;

    my @results;

    for ( my $i = 1 ; $i <= $count ; $i++ ) {
        my $invoice_data = {
            clientName    => 'ledger28',
            customer_id   => 10118,
            transdate     => '2025-10-26',
            duedate       => '2025-11-26',
            invnumber     => '',
            ordnumber     => "ORD-TEST-$i",
            ponumber      => "PO-$i",
            notes         => "Test invoice $i created via API",
            intnotes      => "Internal notes for test $i",
            department_id => 10136,
            employee_id   => 10102,
            items         => [
                {
                    parts_id    => 10116,
                    partnumber  => 'D009',
                    description => 'Digger Hand Trencher',
                    qty         => 2,
                    sellprice   => 18.99,
                    unit        => 'NOS',
                    taxaccounts => '2200',
                },
                {
                    parts_id    => 10117,
                    partnumber  => 'T010',
                    description => 'The Claw Hand Rake',
                    qty         => 3,
                    sellprice   => 14.99,
                    unit        => 'NOS',
                    taxaccounts => '2200',
                }
            ],
        };

        if ($with_payment) {
            $invoice_data->{payment} = {
                amount   => 80.95,
                datepaid => '2025-10-26',
                account  => '1200',
                source   => "CHQ-$i",
                memo     => "Payment for test invoice $i",
            };
        }

        my $result = $c->create_invoice($invoice_data);
        push @results, $result;
    }

    $c->stash( results => \@results );
    $c->render( template => 'test_results' );
};

# Process test AR transaction creation
post '/process_test_ar_transactions' => sub {
    my $c = shift;

    my $count        = $c->param('count')        || 1;
    my $with_payment = $c->param('with_payment') || 0;

    my @results;

    for ( my $i = 1 ; $i <= $count ; $i++ ) {
        my $transaction_data = {
            clientName    => 'ledger28',
            customer_id   => 10125,             # InfoMed Ltd.
            transdate     => '2025-10-26',
            duedate       => '2025-10-26',
            invnumber     => '',
            ordnumber     => "ORD-AR-$i",
            ponumber      => "PO-AR-$i",
            notes         => "Test AR transaction $i created via API",
            intnotes      => "Internal notes for AR test $i",
            description   => "Sales room rental transaction $i",
            department_id => 10136,             # HARDWARE
            employee_id   => 10102,             # Armaghan Saqib
            terms         => '',
            lines         => [
                {
                    amount      => 1000.00,
                    account     => '4000',      # Sales
                    description => 'Sales room rental',
                }
            ],
            taxes => [
                {
                    tax_id      => '2200',
                    amount      => 88.00,
                    calctax     => 1,
                    account     => '2200',
                    rate        => 0.088,
                    description => 'VAT (10%)',
                    taxnumber   => '',
                },
                {
                    tax_id      => '2205',
                    amount      => 50.00,
                    calctax     => 1,
                    account     => '2205',
                    rate        => 0.05,
                    description => 'VAT (5%)',
                    taxnumber   => '',
                }
            ],
        };

        if ($with_payment) {
            $transaction_data->{payment} = {
                amount   => 500.00,
                datepaid => '2025-10-26',
                account  => '1200',
                source   => "AR-CHQ-$i",
                memo     => "Payment for AR transaction $i",
            };
        }

        my $result = $c->create_ar_transaction($transaction_data);
        push @results, $result;
    }

    $c->stash( results => \@results );
    $c->render( template => 'test_ar_results' );
};

# Usage notes page
get '/usage_notes' => sub {
    my $c = shift;
    $c->render( template => 'usage_notes' );
};

app->start;

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SQL-Ledger Invoice List</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-light">
    <nav class="navbar navbar-expand-lg navbar-dark bg-black border-bottom border-secondary">
        <div class="container">
            <a class="navbar-brand fw-bold" href="<%= url_for '/' %>">SQL-Ledger API</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link active" href="<%= url_for '/' %>">List</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_ar_transactions' %>">Test AR Transactions</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5">
        <h1 class="h3 fw-bold mb-4">Recent Invoices & AR Transactions</h1>
        
        <div class="table-responsive">
            <table class="table table-dark table-hover table-bordered">
                <thead>
                    <tr class="table-secondary">
                        <th>ID</th>
                        <th>Type</th>
                        <th>Invoice Number</th>
                        <th>Date</th>
                        <th class="text-end">Amount</th>
                        <th class="text-end">Paid</th>
                        <th class="text-end">Balance</th>
                    </tr>
                </thead>
                <tbody>
                    % for my $inv (@$invoices) {
                        % my $type = $inv->{invoice} ? 'Invoice' : 'AR Transaction';
                        % my $balance = $inv->{amount} - $inv->{paid};
                        <tr>
                            <td><%= $inv->{id} %></td>
                            <td><span class="badge <%= $inv->{invoice} ? 'bg-primary' : 'bg-info' %>"><%= $type %></span></td>
                            <td><%= $inv->{invnumber} || 'N/A' %></td>
                            <td><%= $inv->{transdate} %></td>
                            <td class="text-end"><%= sprintf("%.2f", $inv->{amount}) %></td>
                            <td class="text-end"><%= sprintf("%.2f", $inv->{paid}) %></td>
                            <td class="text-end <%= $balance > 0 ? 'text-warning' : 'text-success' %>">
                                <%= sprintf("%.2f", $balance) %>
                            </td>
                        </tr>
                    % }
                </tbody>
            </table>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

@@ test_invoices.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Invoice Creation</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-light">
    <nav class="navbar navbar-expand-lg navbar-dark bg-black border-bottom border-secondary">
        <div class="container">
            <a class="navbar-brand fw-bold" href="<%= url_for '/' %>">SQL-Ledger API</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/' %>">List</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link active" href="<%= url_for '/test_invoices' %>">Test Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_ar_transactions' %>">Test AR Transactions</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 600px;">
        <h1 class="h3 fw-bold mb-4">Test Invoice Creation</h1>
        
        <div class="card bg-black border-secondary">
            <div class="card-body">
                <form method="post" action="<%= url_for '/process_test_invoices' %>">
                    <div class="mb-3">
                        <label for="count" class="form-label">Number of Invoices</label>
                        <input type="number" class="form-control bg-dark text-light border-secondary" 
                               id="count" name="count" value="1" min="1" max="50">
                        <div class="form-text text-secondary">Create 1-50 test invoices</div>
                    </div>
                    
                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="with_payment" name="with_payment" value="1">
                        <label class="form-check-label" for="with_payment">
                            Include Payment
                        </label>
                    </div>

                    <button type="submit" class="btn btn-primary w-100">Create Test Invoices</button>
                </form>
            </div>
        </div>

        <div class="mt-4">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to List</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

@@ test_ar_transactions.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test AR Transaction Creation</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-light">
    <nav class="navbar navbar-expand-lg navbar-dark bg-black border-bottom border-secondary">
        <div class="container">
            <a class="navbar-brand fw-bold" href="<%= url_for '/' %>">SQL-Ledger API</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/' %>">List</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link active" href="<%= url_for '/test_ar_transactions' %>">Test AR Transactions</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 600px;">
        <h1 class="h3 fw-bold mb-4">Test AR Transaction Creation</h1>
        
        <div class="card bg-black border-secondary">
            <div class="card-body">
                <form method="post" action="<%= url_for '/process_test_ar_transactions' %>">
                    <div class="mb-3">
                        <label for="count" class="form-label">Number of AR Transactions</label>
                        <input type="number" class="form-control bg-dark text-light border-secondary" 
                               id="count" name="count" value="1" min="1" max="50">
                        <div class="form-text text-secondary">Create 1-50 test AR transactions</div>
                    </div>
                    
                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="with_payment" name="with_payment" value="1">
                        <label class="form-check-label" for="with_payment">
                            Include Payment
                        </label>
                    </div>

                    <button type="submit" class="btn btn-primary w-100">Create Test AR Transactions</button>
                </form>
            </div>
        </div>

        <div class="alert alert-info border-secondary bg-dark mt-4" role="alert">
            <h6 class="fw-bold">What is an AR Transaction?</h6>
            <p class="mb-0 small">
                AR Transactions are simpler than invoices - they record revenue without linking to specific products/inventory. 
                Perfect for services, fees, or simple income entries. Each transaction includes line items with amounts and accounts, 
                plus optional tax calculations.
            </p>
        </div>

        <div class="mt-4">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to List</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

@@ test_results.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Invoice Creation Results</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-light">
    <nav class="navbar navbar-expand-lg navbar-dark bg-black border-bottom border-secondary">
        <div class="container">
            <a class="navbar-brand fw-bold" href="<%= url_for '/' %>">SQL-Ledger API</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/' %>">List</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_ar_transactions' %>">Test AR Transactions</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 1200px;">
        <h1 class="h3 fw-bold mb-4">Batch Invoice Creation Results</h1>
        
        % my $success_count = grep { $_->{success} } @$results;
        % my $total_count = scalar @$results;
        
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <h5 class="card-title mb-0">
                    <span class="badge bg-success"><%= $success_count %></span>
                    of
                    <span class="badge bg-secondary"><%= $total_count %></span>
                    invoices created successfully
                </h5>
            </div>
        </div>
        
        <div class="table-responsive">
            <table class="table table-dark table-bordered">
                <thead>
                    <tr class="table-secondary">
                        <th style="width: 5%">#</th>
                        <th style="width: 15%">Status</th>
                        <th style="width: 20%">Invoice Number</th>
                        <th style="width: 15%">Invoice ID</th>
                        <th>Message / Error</th>
                    </tr>
                </thead>
                <tbody>
                    % for my $i (0 .. $#$results) {
                        % my $result = $results->[$i];
                        % my $row_class = $result->{success} ? 'table-success' : 'table-danger';
                        % my $status = $result->{success} ? 'Success' : 'Error';
                        % my $inv_num = $result->{invnumber} || 'N/A';
                        % my $inv_id = $result->{invoice_id} || 'N/A';
                        % my $message = $result->{success} ? $result->{message} : $result->{error};
                        
                        <tr class="<%= $row_class %>">
                            <td><%= $i + 1 %></td>
                            <td><%= $status %></td>
                            <td><%= $inv_num %></td>
                            <td><%= $inv_id %></td>
                            <td><%= $message %></td>
                        </tr>
                    % }
                </tbody>
            </table>
        </div>
        
        <div class="mt-4">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light me-2">View List</a>
            <a href="<%= url_for '/test_invoices' %>" class="btn btn-outline-secondary">Back to Test Creation</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

@@ test_ar_results.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AR Transaction Creation Results</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-light">
    <nav class="navbar navbar-expand-lg navbar-dark bg-black border-bottom border-secondary">
        <div class="container">
            <a class="navbar-brand fw-bold" href="<%= url_for '/' %>">SQL-Ledger API</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/' %>">List</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_ar_transactions' %>">Test AR Transactions</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 1200px;">
        <h1 class="h3 fw-bold mb-4">Batch AR Transaction Creation Results</h1>
        
        % my $success_count = grep { $_->{success} } @$results;
        % my $total_count = scalar @$results;
        
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <h5 class="card-title mb-0">
                    <span class="badge bg-success"><%= $success_count %></span>
                    of
                    <span class="badge bg-secondary"><%= $total_count %></span>
                    AR transactions created successfully
                </h5>
            </div>
        </div>
        
        <div class="table-responsive">
            <table class="table table-dark table-bordered">
                <thead>
                    <tr class="table-secondary">
                        <th style="width: 5%">#</th>
                        <th style="width: 15%">Status</th>
                        <th style="width: 20%">Transaction Number</th>
                        <th style="width: 15%">Transaction ID</th>
                        <th>Message / Error</th>
                    </tr>
                </thead>
                <tbody>
                    % for my $i (0 .. $#$results) {
                        % my $result = $results->[$i];
                        % my $row_class = $result->{success} ? 'table-success' : 'table-danger';
                        % my $status = $result->{success} ? 'Success' : 'Error';
                        % my $trans_num = $result->{invnumber} || 'N/A';
                        % my $trans_id = $result->{transaction_id} || 'N/A';
                        % my $message = $result->{success} ? $result->{message} : $result->{error};
                        
                        <tr class="<%= $row_class %>">
                            <td><%= $i + 1 %></td>
                            <td><%= $status %></td>
                            <td><%= $trans_num %></td>
                            <td><%= $trans_id %></td>
                            <td><%= $message %></td>
                        </tr>
                    % }
                </tbody>
            </table>
        </div>
        
        <div class="mt-4">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light me-2">View List</a>
            <a href="<%= url_for '/test_ar_transactions' %>" class="btn btn-outline-secondary">Back to Test Creation</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

@@ usage_notes.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Usage Notes - SQL-Ledger API</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-light">
    <nav class="navbar navbar-expand-lg navbar-dark bg-black border-bottom border-secondary">
        <div class="container">
            <a class="navbar-brand fw-bold" href="<%= url_for '/' %>">SQL-Ledger API</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/' %>">List</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_ar_transactions' %>">Test AR Transactions</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link active" href="<%= url_for '/usage_notes' %>">Usage</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 900px;">
        <h1 class="h3 fw-bold mb-4">API Usage Guide</h1>
        
        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">1. Create AR Transaction</h2>
        
        <h3 class="h5 fw-semibold mt-4 mb-3">Endpoint</h3>
        <div class="card bg-black border-secondary mb-3">
            <div class="card-body">
                <code>POST /api/create_ar_transaction</code>
            </div>
        </div>

        <h3 class="h5 fw-semibold mt-4 mb-3">Example Request</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0" style="font-size: 0.85rem;"><code>{
  "clientName": "ledger28",
  "customer_id": 10125,
  "transdate": "2025-10-26",
  "duedate": "2025-10-26",
  "description": "Sales room rental",
  "notes": "Monthly rental fee",
  "intnotes": "Internal notes",
  "department_id": 10136,
  "employee_id": 10102,
  "lines": [
    {
      "amount": 1000.00,
      "account": "4000",
      "description": "Sales room rental"
    }
  ],
  "taxes": [
    {
      "tax_id": "2200",
      "amount": 88.00,
      "calctax": 1,
      "account": "2200",
      "rate": 0.088,
      "description": "VAT (10%)"
    }
  ],
  "payment": {
    "amount": 500.00,
    "datepaid": "2025-10-26",
    "account": "1200",
    "source": "CHQ-001",
    "memo": "Partial payment"
  }
}</code></pre>
            </div>
        </div>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">2. Create Invoice</h2>
        
        <h3 class="h5 fw-semibold mt-4 mb-3">Endpoint</h3>
        <div class="card bg-black border-secondary mb-3">
            <div class="card-body">
                <code>POST /api/create_invoice</code>
            </div>
        </div>

        <h3 class="h5 fw-semibold mt-4 mb-3">Example Request</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0" style="font-size: 0.85rem;"><code>{
  "clientName": "ledger28",
  "customer_id": 10118,
  "transdate": "2025-10-26",
  "duedate": "2025-11-26",
  "notes": "Thank you",
  "department_id": 10136,
  "employee_id": 10102,
  "items": [
    {
      "parts_id": 10116,
      "partnumber": "D009",
      "description": "Digger Hand Trencher",
      "qty": 2,
      "sellprice": 18.99,
      "unit": "NOS",
      "taxaccounts": "2200"
    }
  ],
  "payment": {
    "amount": 100.00,
    "datepaid": "2025-10-26",
    "account": "1200",
    "source": "CHQ-12345",
    "memo": "Payment received"
  }
}</code></pre>
            </div>
        </div>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">3. Test Data</h2>
        
        <h3 class="h5 fw-semibold mt-4 mb-3">Customers</h3>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">
                <strong>Auto Exchange Express:</strong> ID 10118, Customer# AE001
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <strong>InfoMed Ltd.:</strong> ID 10125, Customer# IL008
            </li>
        </ul>

        <h3 class="h5 fw-semibold mt-4 mb-3">Chart of Accounts</h3>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">
                <strong>Revenue:</strong> 4000 (Sales), 4010 (Export Sales)
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <strong>AR:</strong> 1100 (Debtors Control)
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <strong>Payment:</strong> 1200 (Bank Current)
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <strong>Tax:</strong> 2200 (VAT 10%), 2205 (VAT 5%)
            </li>
        </ul>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">4. Usage with curl</h2>

        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code># Create AR Transaction
curl -X POST http://localhost:3000/api/create_ar_transaction \
  -H "Content-Type: application/json" \
  -d @ar_transaction.json

# Create Invoice
curl -X POST http://localhost:3000/api/create_invoice \
  -H "Content-Type: application/json" \
  -d @invoice.json</code></pre>
            </div>
        </div>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">5. Running the API</h2>

        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code>perl api_with_ar_fixed.pl daemon
# Access at: http://localhost:3000</code></pre>
            </div>
        </div>

        <div class="mt-5">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to List</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

