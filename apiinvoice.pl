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

helper get_ar_accounts => sub {
    my ( $c, $dbname ) = @_;
    
    my $db = $c->db($dbname);
    
    # Get AR_amount accounts (revenue accounts)
    my @ar_amount_accounts = $db->query(
        "SELECT accno, description FROM chart WHERE link LIKE '%AR_amount%' ORDER BY accno"
    )->hashes;
    
    # Get AR_paid accounts (payment accounts)
    my @ar_paid_accounts = $db->query(
        "SELECT accno, description FROM chart WHERE link LIKE '%AR_paid%' ORDER BY accno"
    )->hashes;
    
    # Get AR_tax accounts (tax accounts) with their rates
    my @ar_tax_accounts = $db->query(
        "SELECT c.id, c.accno, c.description, t.rate
         FROM chart c
         LEFT JOIN tax t ON c.id = t.chart_id AND t.validto IS NULL
         WHERE c.link LIKE '%AR_tax%' 
         ORDER BY c.accno"
    )->hashes;
    
    return {
        ar_amount => \@ar_amount_accounts,
        ar_paid   => \@ar_paid_accounts,
        ar_tax    => \@ar_tax_accounts
    };
};

helper get_customer_tax_accounts => sub {
    my ( $c, $dbname, $customer_id ) = @_;
    
    my $db = $c->db($dbname);
    
    # Get customer's tax chart_ids from customertax table
    my @customer_tax_ids = $db->query(
        "SELECT chart_id FROM customertax WHERE customer_id = ?", 
        $customer_id
    )->flat;
    
    return \@customer_tax_ids;
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
    my $payment_count = 0;
    if ( $transaction_data->{payment} && $transaction_data->{payment}{amount} ) {
        # Single payment format (backward compatible)
        $payment_count = 1;
        $hash{'paid_1'}         = $transaction_data->{payment}{amount} * 1;
        $hash{'datepaid_1'}     = $transaction_data->{payment}{datepaid}     || $transaction_data->{transdate};
        $hash{'AR_paid_1'}      = $transaction_data->{payment}{account}      || '1200';
        $hash{'source_1'}       = $transaction_data->{payment}{source}       || '';
        $hash{'memo_1'}         = $transaction_data->{payment}{memo}         || '';
        $hash{'exchangerate_1'} = $transaction_data->{payment}{exchangerate} || 1;
        $hash{'vr_id_1'}        = $transaction_data->{payment}{vr_id}        || '';
        $hash{'cleared_1'}      = $transaction_data->{payment}{cleared}      || '';
    }
    elsif ( $transaction_data->{payments} && ref($transaction_data->{payments}) eq 'ARRAY' ) {
        # Multiple payments format
        my $pmt_num = 0;
        foreach my $payment ( @{ $transaction_data->{payments} } ) {
            next unless $payment->{amount};
            $pmt_num++;
            
            $hash{"paid_$pmt_num"}         = $payment->{amount} * 1;
            $hash{"datepaid_$pmt_num"}     = $payment->{datepaid}     || $transaction_data->{transdate};
            $hash{"AR_paid_$pmt_num"}      = $payment->{account}      || '1200';
            $hash{"source_$pmt_num"}       = $payment->{source}       || '';
            $hash{"memo_$pmt_num"}         = $payment->{memo}         || '';
            $hash{"exchangerate_$pmt_num"} = $payment->{exchangerate} || 1;
            $hash{"vr_id_$pmt_num"}        = $payment->{vr_id}        || '';
            $hash{"cleared_$pmt_num"}      = $payment->{cleared}      || '';
        }
        $payment_count = $pmt_num;
    }
    
    $hash{'paidaccounts'} = $payment_count;

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
    
    my $dbname = 'ledger28';
    my $customer_id = 10125;  # InfoMed Ltd. - default customer
    
    my $accounts = $c->get_ar_accounts($dbname);
    my $customer_taxes = $c->get_customer_tax_accounts($dbname, $customer_id);
    
    $c->stash(
        ar_amount_accounts => $accounts->{ar_amount},
        ar_paid_accounts   => $accounts->{ar_paid},
        ar_tax_accounts    => $accounts->{ar_tax},
        customer_taxes     => $customer_taxes
    );
    
    $c->render( template => 'test_ar_transactions' );
};

# Process test invoice creation
post '/process_test_invoices' => sub {
    my $c = shift;

    my $count         = $c->param('count')         || 1;
    my $with_payment  = $c->param('with_payment')  || 0;
    my $tax_included  = $c->param('tax_included')  || 0;

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
            taxincluded   => $tax_included,
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
    my $tax_included = $c->param('tax_included') || 0;

    my @results;

    for ( my $i = 1 ; $i <= $count ; $i++ ) {
        
        # Collect line items (up to 5 lines)
        my @lines;
        for my $line_num (1..5) {
            my $amount = $c->param("amount_$line_num");
            my $account = $c->param("AR_amount_$line_num");
            my $description = $c->param("description_$line_num") || '';
            
            # Only add line if amount and account are provided
            if ($amount && $account) {
                push @lines, {
                    amount      => $amount * 1,
                    account     => $account,
                    description => $description,
                };
            }
        }
        
        # Skip if no lines
        if (scalar(@lines) == 0) {
            push @results, {
                success => 0,
                error   => "No line items provided"
            };
            next;
        }
        
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
            description   => "Multi-line transaction $i",
            department_id => 10136,             # HARDWARE
            employee_id   => 10102,             # Armaghan Saqib
            terms         => '',
            taxincluded   => $tax_included,
            lines         => \@lines,
        };
        
        # Collect tax information dynamically from form
        my @taxes;
        my @all_params = $c->req->params->names;
        
        foreach my $param_name (@all_params) {
            # Look for tax checkboxes (tax_XXXX where XXXX is chart_id)
            if ($param_name =~ /^tax_(\d+)$/ && $c->param($param_name)) {
                my $chart_id = $1;
                my $tax_amount = $c->param("tax_amount_$chart_id") || 0;
                my $tax_rate = $c->param("tax_rate_$chart_id") || 0;
                my $tax_account = $c->param("tax_account_$chart_id") || '';
                
                # Only add tax if checkbox is checked and amount > 0
                if ($tax_amount > 0 && $tax_account) {
                    push @taxes, {
                        tax_id      => $tax_account,  # Use account number as tax_id
                        amount      => $tax_amount * 1,
                        calctax     => 1,
                        account     => $tax_account,
                        rate        => ($tax_rate / 100) * 1,  # Convert percentage to decimal (10 -> 0.10)
                        description => '',
                        taxnumber   => '',
                    };
                }
            }
        }
        
        # Add taxes to transaction data if any were collected
        if (scalar(@taxes) > 0) {
            $transaction_data->{taxes} = \@taxes;
        }

        # Collect payment lines (up to 3 payments)
        if ($with_payment) {
            my @payments;
            for my $payment_num (1..3) {
                my $paid_amount = $c->param("paid_$payment_num");
                my $paid_account = $c->param("AR_paid_$payment_num");
                my $source = $c->param("source_$payment_num") || '';
                my $memo = $c->param("memo_$payment_num") || '';
                
                # Only add payment if amount and account are provided
                if ($paid_amount && $paid_account) {
                    push @payments, {
                        amount   => $paid_amount * 1,
                        account  => $paid_account,
                        source   => $source,
                        memo     => $memo,
                        datepaid => '2025-10-26',
                    };
                }
            }
            
            # Add payments in the correct format
            if (scalar(@payments) > 0) {
                $transaction_data->{payments} = \@payments;
            }
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

                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="tax_included" name="tax_included" value="1">
                        <label class="form-check-label" for="tax_included">
                            Tax Included
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
    <style>
        .line-row {
            border-bottom: 1px solid #495057;
            padding: 0.75rem 0;
        }
        .line-row:last-child {
            border-bottom: none;
        }
        .table-dark-custom {
            background-color: #1a1d20;
        }
        .totals-section {
            background-color: #2c3034;
            border: 2px solid #495057;
            border-radius: 0.375rem;
            padding: 1rem;
            margin-top: 1rem;
        }
        .total-row {
            display: flex;
            justify-content: space-between;
            padding: 0.5rem 0;
            font-size: 1.1rem;
        }
        .total-row.grand-total {
            border-top: 2px solid #6c757d;
            padding-top: 0.75rem;
            margin-top: 0.5rem;
            font-weight: bold;
            font-size: 1.2rem;
        }
        .total-label {
            font-weight: 600;
        }
        .total-amount {
            font-family: 'Courier New', monospace;
            font-weight: 600;
        }
        .total-amount.positive {
            color: #198754;
        }
        .total-amount.negative {
            color: #dc3545;
        }
        .total-amount.zero {
            color: #6c757d;
        }
    </style>
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

    <div class="container py-5" style="max-width: 900px;">
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

                    <hr class="border-secondary my-4">
                    <h5 class="mb-3">Line Items</h5>
                    
                    <div class="table-responsive">
                        <table class="table table-dark table-bordered table-sm">
                            <thead>
                                <tr class="table-secondary">
                                    <th style="width: 20%;">Amount</th>
                                    <th style="width: 35%;">Account</th>
                                    <th style="width: 45%;">Description</th>
                                </tr>
                            </thead>
                            <tbody>
                                % for my $line_num (1..5) {
                                    <tr>
                                        <td>
                                            <input type="number" step="0.01" 
                                                   class="form-control form-control-sm bg-dark text-light border-secondary line-amount" 
                                                   name="amount_<%= $line_num %>" 
                                                   value="<%= $line_num == 1 ? '1000.00' : '' %>"
                                                   placeholder="0.00"
                                                   onchange="calculateTotals()">
                                        </td>
                                        <td>
                                            <select class="form-select form-select-sm bg-dark text-light border-secondary" 
                                                    name="AR_amount_<%= $line_num %>">
                                                <option value="">-- Select Account --</option>
                                                % for my $account (@$ar_amount_accounts) {
                                                    <option value="<%= $account->{accno} %>" 
                                                            <%= $line_num == 1 && $account->{accno} eq '4000' ? 'selected' : '' %>>
                                                        <%= $account->{accno} %> - <%= $account->{description} %>
                                                    </option>
                                                % }
                                            </select>
                                        </td>
                                        <td>
                                            <input type="text" 
                                                   class="form-control form-control-sm bg-dark text-light border-secondary" 
                                                   name="description_<%= $line_num %>" 
                                                   value="<%= $line_num == 1 ? 'Sales room rental' : '' %>"
                                                   placeholder="Line description"
                                                   maxlength="100">
                                        </td>
                                    </tr>
                                % }
                            </tbody>
                        </table>
                    </div>
                    <div class="form-text text-secondary mb-3">Fill in up to 5 line items. Empty lines will be ignored.</div>

                    <hr class="border-secondary my-4">
                    <h5 class="mb-3">Tax</h5>
                    
                    <div class="table-responsive">
                        <table class="table table-dark table-bordered table-sm">
                            <thead>
                                <tr class="table-secondary">
                                    <th style="width: 10%;">Apply</th>
                                    <th style="width: 30%;">Tax Account</th>
                                    <th style="width: 15%;">Rate (%)</th>
                                    <th style="width: 20%;">Amount</th>
                                    <th style="width: 25%;">Description</th>
                                </tr>
                            </thead>
                            <tbody>
                                % my $tax_num = 0;
                                % for my $tax_account (@$ar_tax_accounts) {
                                    % $tax_num++;
                                    % my $chart_id = $tax_account->{id};
                                    % my $tax_id = $tax_account->{accno};
                                    % my $is_checked = grep { $_ == $chart_id } @$customer_taxes;
                                    % my $tax_rate = ($tax_account->{rate} || 0) * 100;  # Convert 0.1 to 10
                                    <tr>
                                        <td class="text-center">
                                            <input type="checkbox" 
                                                   class="form-check-input tax-checkbox" 
                                                   name="tax_<%= $chart_id %>" 
                                                   value="1"
                                                   data-chart-id="<%= $chart_id %>"
                                                   data-tax-id="<%= $tax_id %>"
                                                   data-tax-rate="<%= $tax_rate %>"
                                                   <%= $is_checked ? 'checked' : '' %>
                                                   onchange="calculateTaxes()">
                                        </td>
                                        <td>
                                            <strong><%= $tax_account->{accno} %></strong> - <%= $tax_account->{description} %>
                                            <input type="hidden" name="tax_account_<%= $chart_id %>" value="<%= $tax_account->{accno} %>">
                                            <input type="hidden" name="tax_chart_id_<%= $chart_id %>" value="<%= $chart_id %>">
                                        </td>
                                        <td>
                                            <input type="number" step="0.001" 
                                                   class="form-control form-control-sm bg-dark text-light border-secondary tax-rate" 
                                                   name="tax_rate_<%= $chart_id %>" 
                                                   id="tax_rate_<%= $chart_id %>"
                                                   data-chart-id="<%= $chart_id %>"
                                                   value="<%= $tax_rate %>"
                                                   onchange="calculateTaxes()"
                                                   style="text-align: right;">
                                        </td>
                                        <td>
                                            <input type="number" step="0.01" 
                                                   class="form-control form-control-sm bg-dark text-light border-secondary tax-amount" 
                                                   name="tax_amount_<%= $chart_id %>" 
                                                   id="tax_amount_<%= $chart_id %>"
                                                   value="0.00"
                                                   readonly
                                                   style="text-align: right; background-color: #16181b !important;">
                                        </td>
                                        <td>
                                            <small class="text-secondary"><%= $tax_account->{description} %></small>
                                        </td>
                                    </tr>
                                % }
                            </tbody>
                        </table>
                    </div>
                    <div class="form-text text-secondary mb-3">
                        Check applicable taxes. Amounts calculated automatically based on line items total and tax rate.
                        Pre-checked taxes are defaults for the selected customer.
                    </div>

                    <hr class="border-secondary my-4">
                    <h5 class="mb-3">Payment Details</h5>
                    
                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="with_payment" name="with_payment" value="1">
                        <label class="form-check-label" for="with_payment">
                            Include Payment
                        </label>
                    </div>

                    <div class="table-responsive">
                        <table class="table table-dark table-bordered table-sm">
                            <thead>
                                <tr class="table-secondary">
                                    <th style="width: 20%;">Amount</th>
                                    <th style="width: 35%;">Account</th>
                                    <th style="width: 25%;">Source</th>
                                    <th style="width: 20%;">Memo</th>
                                </tr>
                            </thead>
                            <tbody>
                                % for my $payment_num (1..3) {
                                    <tr>
                                        <td>
                                            <input type="number" step="0.01" 
                                                   class="form-control form-control-sm bg-dark text-light border-secondary payment-amount" 
                                                   name="paid_<%= $payment_num %>" 
                                                   value="<%= $payment_num == 1 ? '500.00' : '' %>"
                                                   placeholder="0.00"
                                                   onchange="calculateTotals()">
                                        </td>
                                        <td>
                                            <select class="form-select form-select-sm bg-dark text-light border-secondary" 
                                                    name="AR_paid_<%= $payment_num %>">
                                                <option value="">-- Select Account --</option>
                                                % for my $account (@$ar_paid_accounts) {
                                                    <option value="<%= $account->{accno} %>" 
                                                            <%= $payment_num == 1 && $account->{accno} eq '1200' ? 'selected' : '' %>>
                                                        <%= $account->{accno} %> - <%= $account->{description} %>
                                                    </option>
                                                % }
                                            </select>
                                        </td>
                                        <td>
                                            <input type="text" 
                                                   class="form-control form-control-sm bg-dark text-light border-secondary" 
                                                   name="source_<%= $payment_num %>" 
                                                   value="<%= $payment_num == 1 ? 'CHQ-001' : '' %>"
                                                   placeholder="Source"
                                                   maxlength="50">
                                        </td>
                                        <td>
                                            <input type="text" 
                                                   class="form-control form-control-sm bg-dark text-light border-secondary" 
                                                   name="memo_<%= $payment_num %>" 
                                                   placeholder="Memo"
                                                   maxlength="50">
                                        </td>
                                    </tr>
                                % }
                            </tbody>
                        </table>
                    </div>
                    <div class="form-text text-secondary mb-3">Fill in up to 3 payment lines. Only used if "Include Payment" is checked.</div>

                    <!-- Totals Section -->
                    <div class="totals-section">
                        <div class="total-row">
                            <span class="total-label">Line Items Subtotal:</span>
                            <span class="total-amount" id="lineItemsTotal">£0.00</span>
                        </div>
                        <div class="total-row">
                            <span class="total-label">Tax Total:</span>
                            <span class="total-amount" id="taxTotal">£0.00</span>
                        </div>
                        <div class="total-row">
                            <span class="total-label">Invoice Total (Items + Tax):</span>
                            <span class="total-amount" id="invoiceTotal">£0.00</span>
                        </div>
                        <div class="total-row">
                            <span class="total-label">Payments Total:</span>
                            <span class="total-amount" id="paymentsTotal">£0.00</span>
                        </div>
                        <div class="total-row grand-total">
                            <span class="total-label">Difference (Outstanding):</span>
                            <span class="total-amount" id="difference">£0.00</span>
                        </div>
                        <small class="text-secondary mt-2 d-block">
                            <i class="bi bi-info-circle"></i> 
                            Positive difference means payment is less than invoice total (amount due). 
                            Negative means overpayment.
                        </small>
                    </div>

                    <hr class="border-secondary my-4">
                    <h5 class="mb-3">Options</h5>

                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="tax_included" name="tax_included" value="1">
                        <label class="form-check-label" for="tax_included">
                            Tax Included
                        </label>
                    </div>

                    <button type="submit" class="btn btn-primary w-100 mt-3">Create Test AR Transactions</button>
                </form>
            </div>
        </div>

        <div class="alert alert-info border-secondary bg-dark mt-4" role="alert">
            <h6 class="fw-bold">Tips:</h6>
            <ul class="mb-0 small">
                <li>Use multiple line items to split revenue across different accounts</li>
                <li>Use multiple payment lines to record split payments or partial payments</li>
                <li>Empty line items and payment lines will be automatically ignored</li>
                <li>Accounts are loaded dynamically from your SQL-Ledger chart of accounts</li>
                <li>Totals update automatically as you enter amounts</li>
            </ul>
        </div>

        <div class="mt-4">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to List</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Function to format currency
        function formatCurrency(amount) {
            return '£' + Math.abs(amount).toFixed(2);
        }

        // Function to calculate taxes based on line items total and tax rates
        function calculateTaxes() {
            // Get line items total first
            let lineItemsTotal = 0;
            document.querySelectorAll('.line-amount').forEach(function(input) {
                const value = parseFloat(input.value) || 0;
                lineItemsTotal += value;
            });

            // Calculate each tax amount if checkbox is checked
            let taxTotal = 0;
            document.querySelectorAll('.tax-checkbox').forEach(function(checkbox) {
                const chartId = checkbox.getAttribute('data-chart-id');
                const taxRateInput = document.getElementById('tax_rate_' + chartId);
                const taxAmountInput = document.getElementById('tax_amount_' + chartId);
                
                if (checkbox.checked && taxRateInput) {
                    const taxRate = parseFloat(taxRateInput.value) || 0;
                    const taxAmount = lineItemsTotal * (taxRate / 100);
                    taxAmountInput.value = taxAmount.toFixed(2);
                    taxTotal += taxAmount;
                } else {
                    taxAmountInput.value = '0.00';
                }
            });

            // Update tax total display
            document.getElementById('taxTotal').textContent = formatCurrency(taxTotal);

            // Recalculate all totals
            calculateTotals();
        }

        // Function to calculate and display totals
        function calculateTotals() {
            // Calculate line items total
            let lineItemsTotal = 0;
            document.querySelectorAll('.line-amount').forEach(function(input) {
                const value = parseFloat(input.value) || 0;
                lineItemsTotal += value;
            });

            // Calculate tax total
            let taxTotal = 0;
            document.querySelectorAll('.tax-amount').forEach(function(input) {
                const value = parseFloat(input.value) || 0;
                taxTotal += value;
            });

            // Calculate invoice total (line items + tax)
            const invoiceTotal = lineItemsTotal + taxTotal;

            // Calculate payments total
            let paymentsTotal = 0;
            document.querySelectorAll('.payment-amount').forEach(function(input) {
                const value = parseFloat(input.value) || 0;
                paymentsTotal += value;
            });

            // Calculate difference (outstanding amount)
            const difference = invoiceTotal - paymentsTotal;

            // Update display
            document.getElementById('lineItemsTotal').textContent = formatCurrency(lineItemsTotal);
            document.getElementById('taxTotal').textContent = formatCurrency(taxTotal);
            document.getElementById('invoiceTotal').textContent = formatCurrency(invoiceTotal);
            document.getElementById('paymentsTotal').textContent = formatCurrency(paymentsTotal);
            
            const differenceElement = document.getElementById('difference');
            differenceElement.textContent = formatCurrency(difference);
            
            // Apply color classes based on difference
            differenceElement.classList.remove('positive', 'negative', 'zero');
            if (difference > 0.01) {
                differenceElement.classList.add('positive');
            } else if (difference < -0.01) {
                differenceElement.classList.add('negative');
            } else {
                differenceElement.classList.add('zero');
            }
        }

        // Calculate totals on page load
        document.addEventListener('DOMContentLoaded', function() {
            calculateTaxes();
        });

        // Add event listeners for line amounts to trigger tax calculation
        document.querySelectorAll('.line-amount').forEach(function(input) {
            input.addEventListener('input', calculateTaxes);
            input.addEventListener('keyup', calculateTaxes);
            input.addEventListener('change', calculateTaxes);
        });

        // Add event listeners for payment amounts
        document.querySelectorAll('.payment-amount').forEach(function(input) {
            input.addEventListener('input', calculateTotals);
            input.addEventListener('keyup', calculateTotals);
        });
    </script>
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

