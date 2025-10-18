#!/usr/bin/env perl
BEGIN {
    push @INC, '.';
}

use Mojolicious::Lite;
use DBIx::Simple;
use Data::Dumper;
use SL::Form;
use SL::IS;

my $dbhost   = 'localhost';
my $dbuser   = 'postgres';
my $dbpasswd = '';

helper db => sub {
    my ( $c, $dbname ) = @_;

    my $dbh = DBI->connect( 
        "dbi:Pg:dbname=$dbname;host=$dbhost", 
        $dbuser, 
        $dbpasswd, 
        { AutoCommit => 0, RaiseError => 1 } 
    );

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
    if (!$currency && $invoice_data->{customer_id}) {
        $currency = $db->query("SELECT curr FROM customer WHERE id = ?", $invoice_data->{customer_id})->list;
    }
    $currency ||= 'GBP';

    # Build form hash
    my %hash = (
        'type'           => 'invoice',
        'vc'             => 'customer',
        'ARAP'           => 'AR',
        'formname'       => 'invoice',
        'currency'       => $currency,
        'customer_id'    => $invoice_data->{customer_id} * 1,
        'transdate'      => $invoice_data->{transdate} || '',
        'duedate'        => $invoice_data->{duedate} || '',
        'invnumber'      => $invoice_data->{invnumber} || '',
        'ordnumber'      => $invoice_data->{ordnumber} || '',
        'ponumber'       => $invoice_data->{ponumber} || '',
        'notes'          => $invoice_data->{notes} || '',
        'intnotes'       => $invoice_data->{intnotes} || '',
        'AR'             => $invoice_data->{AR} || '1100',
        'exchangerate'   => $invoice_data->{exchangerate} || 1,
        'department_id'  => $invoice_data->{department_id} || 0,
        'warehouse_id'   => $invoice_data->{warehouse_id} || 0,
        'employee_id'    => $invoice_data->{employee_id} || 0,
        'taxincluded'    => $invoice_data->{taxincluded} || 0,
        'paidaccounts'   => 0,
        'rowcount'       => 0,
    );

    # Add invoice items
    my $rowcount = 0;
    foreach my $item ( @{ $invoice_data->{items} } ) {
        $rowcount++;
        
        $hash{"id_$rowcount"}           = $item->{parts_id} * 1;
        $hash{"partnumber_$rowcount"}   = $item->{partnumber} || '';
        $hash{"description_$rowcount"}  = $item->{description} || '';
        $hash{"qty_$rowcount"}          = $item->{qty} * 1;
        $hash{"sellprice_$rowcount"}    = $item->{sellprice} * 1;
        $hash{"unit_$rowcount"}         = $item->{unit} || 'ea';
        $hash{"discount_$rowcount"}     = $item->{discount} || 0;
        $hash{"taxaccounts_$rowcount"}  = $item->{taxaccounts} || '';
    }
    
    $hash{'rowcount'} = $rowcount;

    # Add payment information if provided
    if ($invoice_data->{payment} && $invoice_data->{payment}{amount}) {
        $hash{'paidaccounts'} = 1;
        $hash{'paid_1'}       = $invoice_data->{payment}{amount} * 1;
        $hash{'datepaid_1'}   = $invoice_data->{payment}{datepaid} || $invoice_data->{transdate};
        $hash{'AR_paid_1'}    = $invoice_data->{payment}{account} || '1200';
        $hash{'source_1'}     = $invoice_data->{payment}{source} || '';
        $hash{'memo_1'}       = $invoice_data->{payment}{memo} || '';
        $hash{'exchangerate_1'} = $invoice_data->{payment}{exchangerate} || 1;
    }

    # Create form object and populate
    my $form = new Form;
    $form->{precision} = $precision;
    foreach my $key ( keys %hash ) {
        $form->{$key} = $hash{$key};
    }

    # Post the invoice
    eval {
        $rc = IS->post_invoice( $c->myconfig( $invoice_data->{clientName} ), $form );
    };

    if ($@ || !$rc) {
        $db->rollback;
        return { 
            error => $@ || 'Failed to create invoice',
            success => 0
        };
    } else {
        $db->commit;
        return { 
            message => "Invoice created successfully",
            invoice_id => $form->{id},
            invnumber => $form->{invnumber},
            success => 1
        };
    }
};

# Main page with ordered lists
get '/' => sub {
    my $c = shift;
    $c->render(template => 'index');
};

# Usage notes page
get '/usage_notes' => sub {
    my $c = shift;
    $c->render(template => 'usage_notes');
};

# Single item - Digger Hand Trencher
get '/test_single_item' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        duedate       => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        department_id => 10136,
        employee_id   => 10102,
        currency      => 'GBP',
        notes         => 'Single item test - Digger Hand Trencher',
        items         => [
            {
                parts_id    => 10116,
                partnumber  => 'D009',
                description => 'Digger Hand Trencher',
                qty         => 1,
                sellprice   => 18.99,
                unit        => 'NOS',
                taxaccounts => '2200'
            }
        ]
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Single Item Invoice - Digger Hand Trencher'
    );
    $c->render(template => 'result');
};

# Single item - The Claw Hand Rake
get '/test_single_item_claw' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        duedate       => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        department_id => 10136,
        employee_id   => 10102,
        currency      => 'GBP',
        notes         => 'Single item test - The Claw Hand Rake',
        items         => [
            {
                parts_id    => 10117,
                partnumber  => 'T010',
                description => 'The Claw Hand Rake',
                qty         => 1,
                sellprice   => 14.99,
                unit        => 'NOS',
                taxaccounts => '2200'
            }
        ]
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Single Item Invoice - The Claw Hand Rake'
    );
    $c->render(template => 'result');
};

# Single item with full payment
get '/test_single_with_payment' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        department_id => 10136,
        currency      => 'GBP',
        notes         => 'Single item with full payment',
        items         => [
            {
                parts_id    => 10116,
                partnumber  => 'D009',
                qty         => 2,
                sellprice   => 18.99,
                unit        => 'NOS',
                taxaccounts => '2200'
            }
        ],
        payment => {
            amount       => 37.98,
            datepaid     => '2025-01-15',
            account      => '1200--Bank Current Account',
            source       => 'Cash',
            memo         => 'Payment received'
        }
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Single Item with Full Payment'
    );
    $c->render(template => 'result');
};

# Single item with partial payment
get '/test_single_partial_payment' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        currency      => 'GBP',
        notes         => 'Single item with partial payment',
        items         => [
            {
                parts_id    => 10116,
                qty         => 3,
                sellprice   => 18.99,
                taxaccounts => '2200'
            }
        ],
        payment => {
            amount       => 30.00,
            datepaid     => '2025-01-15',
            account      => '1200--Bank Current Account',
            source       => 'Bank Transfer',
            memo         => 'Partial payment'
        }
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Single Item with Partial Payment'
    );
    $c->render(template => 'result');
};

# Multiple items - Original invoice recreation
get '/test_multi_items' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        department_id => 10136,
        employee_id   => 10102,
        currency      => 'GBP',
        notes         => 'Multi-item invoice - recreating AR-001',
        items         => [
            {
                parts_id    => 10116,
                partnumber  => 'D009',
                description => 'Digger Hand Trencher',
                qty         => 6,
                sellprice   => 18.99,
                unit        => 'NOS',
                taxaccounts => '2200'
            },
            {
                parts_id    => 10117,
                partnumber  => 'T010',
                description => 'The Claw Hand Rake',
                qty         => 3,
                sellprice   => 14.99,
                unit        => 'NOS',
                taxaccounts => '2200'
            }
        ]
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Multiple Items (Original AR-001)'
    );
    $c->render(template => 'result');
};

# Three items with payment
get '/test_multi_items_three' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        currency      => 'GBP',
        notes         => 'Three items with full payment',
        items         => [
            {
                parts_id    => 10116,
                qty         => 2,
                sellprice   => 18.99,
                taxaccounts => '2200'
            },
            {
                parts_id    => 10117,
                qty         => 1,
                sellprice   => 14.99,
                taxaccounts => '2200'
            },
            {
                parts_id    => 10116,
                qty         => 1,
                sellprice   => 18.99,
                taxaccounts => '2200'
            }
        ],
        payment => {
            amount   => 100.00,
            datepaid => '2025-01-15',
            account  => '1200--Bank Current Account',
            source   => 'Cash'
        }
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Three Items with Payment'
    );
    $c->render(template => 'result');
};

# Invoice without payment
get '/test_no_payment' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        duedate       => '2025-02-15',
        AR            => '1100',
        warehouse_id  => 10134,
        currency      => 'GBP',
        notes         => 'Invoice on credit - 30 days',
        items         => [
            {
                parts_id    => 10117,
                qty         => 5,
                sellprice   => 14.99,
                taxaccounts => '2200'
            }
        ]
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Invoice Without Payment (Credit)'
    );
    $c->render(template => 'result');
};

# Invoice with discount
get '/test_with_discount' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        currency      => 'GBP',
        notes         => 'Invoice with 10% discount',
        items         => [
            {
                parts_id    => 10116,
                qty         => 10,
                sellprice   => 18.99,
                discount    => 10,
                taxaccounts => '2200'
            }
        ]
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Invoice With 10% Discount'
    );
    $c->render(template => 'result');
};

# Invoice with notes
get '/test_with_notes' => sub {
    my $c = shift;
    
    my $invoice_data = {
        clientName    => 'ledger28',
        customer_id   => 10118,
        transdate     => '2025-01-15',
        AR            => '1100',
        warehouse_id  => 10134,
        currency      => 'GBP',
        notes         => 'Customer requested express delivery. Handle with care.',
        intnotes      => 'Priority customer - check stock before confirming',
        ordnumber     => 'ORD-2025-001',
        ponumber      => 'PO-CUST-123',
        items         => [
            {
                parts_id    => 10116,
                qty         => 5,
                sellprice   => 18.99,
                taxaccounts => '2200'
            }
        ]
    };
    
    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title => 'Invoice With Notes and References'
    );
    $c->render(template => 'result');
};

# Batch create invoices
get '/test_batch_create' => sub {
    my $c = shift;
    
    my @results;
    
    for my $i (1..5) {
        my $invoice_data = {
            clientName    => 'ledger28',
            customer_id   => 10118,
            transdate     => '2025-01-15',
            AR            => '1100',
            warehouse_id  => 10134,
            currency      => 'GBP',
            notes         => "Batch invoice $i of 5",
            items         => [
                {
                    parts_id    => 10116,
                    qty         => $i,
                    sellprice   => 18.99,
                    taxaccounts => '2200'
                }
            ]
        };
        
        my $result = $c->create_invoice($invoice_data);
        push @results, $result;
    }
    
    $c->stash(results => \@results);
    $c->render(template => 'batch_results');
};

app->start;

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SQL-Ledger Invoice API</title>
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
                        <a class="nav-link active" href="<%= url_for '/' %>">Home</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage Notes</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 900px;">
        <h1 class="display-5 fw-bold mb-3">Invoice Creation API</h1>
        <p class="lead text-secondary mb-4">Test SQL-Ledger invoice creation with Auto Exchange Express data</p>
        
        <div class="alert alert-secondary border-secondary" role="alert">
            <strong>Note:</strong> All examples use real data from invoice AR-001 (Customer: Auto Exchange Express, Location: London GB)
        </div>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Single Item Invoices</h2>
        <p class="text-secondary small mb-3">Create invoices with one item - testing basic functionality</p>
        <ol class="list-group list-group-numbered mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_single_item' %>" class="text-decoration-none text-light stretched-link">Single Item - Digger Hand Trencher</a>
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_single_item_claw' %>" class="text-decoration-none text-light stretched-link">Single Item - The Claw Hand Rake</a>
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_single_with_payment' %>" class="text-decoration-none text-light stretched-link">Single Item + Full Payment</a>
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_single_partial_payment' %>" class="text-decoration-none text-light stretched-link">Single Item + Partial Payment</a>
            </li>
        </ol>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Multiple Item Invoices</h2>
        <p class="text-secondary small mb-3">Create invoices with multiple items</p>
        <ol class="list-group list-group-numbered mb-4" start="5">
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_multi_items' %>" class="text-decoration-none text-light stretched-link">Two Items (Original Invoice)</a>
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_multi_items_three' %>" class="text-decoration-none text-light stretched-link">Three Items + Payment</a>
            </li>
        </ol>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Special Cases</h2>
        <p class="text-secondary small mb-3">Test special scenarios</p>
        <ol class="list-group list-group-numbered mb-4" start="7">
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_no_payment' %>" class="text-decoration-none text-light stretched-link">Invoice Without Payment</a>
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_with_discount' %>" class="text-decoration-none text-light stretched-link">Invoice With Discount</a>
            </li>
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_with_notes' %>" class="text-decoration-none text-light stretched-link">Invoice With Notes</a>
            </li>
        </ol>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Batch Operations</h2>
        <p class="text-secondary small mb-3">Create multiple invoices in sequence</p>
        <ol class="list-group list-group-numbered mb-4" start="10">
            <li class="list-group-item list-group-item-dark border-secondary">
                <a href="<%= url_for '/test_batch_create' %>" class="text-decoration-none text-light stretched-link">Create 5 Invoices</a>
            </li>
        </ol>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

@@ result.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= $title %></title>
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
                        <a class="nav-link" href="<%= url_for '/' %>">Home</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage Notes</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 900px;">
        <h1 class="h3 fw-bold mb-4"><%= $title %></h1>
        
        % if ($result->{success}) {
            <div class="alert alert-success border-success" role="alert">
                <h4 class="alert-heading">Invoice Created Successfully</h4>
            </div>
            
            <div class="card bg-black border-secondary mb-3">
                <div class="card-body">
                    <p class="card-text text-secondary small mb-2">Invoice Number</p>
                    <h5 class="card-title"><%= $result->{invnumber} %></h5>
                </div>
            </div>
            
            <div class="card bg-black border-secondary mb-3">
                <div class="card-body">
                    <p class="card-text text-secondary small mb-2">Invoice ID</p>
                    <h5 class="card-title"><%= $result->{invoice_id} %></h5>
                </div>
            </div>
            
            <div class="card bg-black border-secondary mb-3">
                <div class="card-body">
                    <p class="card-text text-secondary small mb-2">Message</p>
                    <p class="card-text"><%= $result->{message} %></p>
                </div>
            </div>
        % } else {
            <div class="alert alert-danger border-danger" role="alert">
                <h4 class="alert-heading">Error Creating Invoice</h4>
                <hr>
                <p class="mb-0"><%= $result->{error} %></p>
            </div>
        % }
        
        <div class="mt-4">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to Main Page</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

@@ batch_results.html.ep
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Batch Invoice Results</title>
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
                        <a class="nav-link" href="<%= url_for '/' %>">Home</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage Notes</a>
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
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to Main Page</a>
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
    <title>Usage Notes - SQL-Ledger Invoice API</title>
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
                        <a class="nav-link" href="<%= url_for '/' %>">Home</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link active" href="<%= url_for '/usage_notes' %>">Usage Notes</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 900px;">
        <h1 class="h3 fw-bold mb-4">Usage Notes</h1>
        
        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Customer Information</h2>
        <div class="card bg-black border-secondary mb-3">
            <div class="card-body">
                <dl class="row mb-0">
                    <dt class="col-sm-3 text-secondary">Customer ID</dt>
                    <dd class="col-sm-9">10118</dd>
                    
                    <dt class="col-sm-3 text-secondary">Name</dt>
                    <dd class="col-sm-9">Auto Exchange Express</dd>
                    
                    <dt class="col-sm-3 text-secondary">Customer Number</dt>
                    <dd class="col-sm-9">AE001</dd>
                    
                    <dt class="col-sm-3 text-secondary">Location</dt>
                    <dd class="col-sm-9">London, GB</dd>
                    
                    <dt class="col-sm-3 text-secondary">Currency</dt>
                    <dd class="col-sm-9 mb-0">GBP</dd>
                </dl>
            </div>
        </div>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Available Products</h2>
        
        <h3 class="h5 fw-semibold mt-4 mb-3">1. Digger Hand Trencher (D009)</h3>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">Parts ID: 10116</li>
            <li class="list-group-item list-group-item-dark border-secondary">Price: £18.99</li>
            <li class="list-group-item list-group-item-dark border-secondary">Unit: NOS</li>
        </ul>

        <h3 class="h5 fw-semibold mt-4 mb-3">2. The Claw Hand Rake (T010)</h3>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">Parts ID: 10117</li>
            <li class="list-group-item list-group-item-dark border-secondary">Price: £14.99</li>
            <li class="list-group-item list-group-item-dark border-secondary">Unit: NOS</li>
        </ul>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Chart of Accounts</h2>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">AR Account: 1100 (Debtors Control Account)</li>
            <li class="list-group-item list-group-item-dark border-secondary">Payment Account: 1200 (Bank Current Account)</li>
            <li class="list-group-item list-group-item-dark border-secondary">Tax Account: 2200 (VAT 10%)</li>
        </ul>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Warehouses</h2>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">W1: 10134</li>
            <li class="list-group-item list-group-item-dark border-secondary">W2: 10135</li>
        </ul>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Departments</h2>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">HARDWARE: 10136</li>
            <li class="list-group-item list-group-item-dark border-secondary">SERVICES: 10137</li>
        </ul>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Employee</h2>
        <ul class="list-group list-group-flush mb-4">
            <li class="list-group-item list-group-item-dark border-secondary">Armaghan Saqib: 10102</li>
        </ul>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">How to Use</h2>

        <h3 class="h5 fw-semibold mt-4 mb-3">1. As Daemon</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code>perl api.pl daemon
# Then open: http://localhost:3000</code></pre>
            </div>
        </div>

        <h3 class="h5 fw-semibold mt-4 mb-3">2. As CGI</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code>chmod +x api.pl
# Place in cgi-bin directory
# Access via web server (Apache/Nginx)
# url_for() ensures all links work in both modes</code></pre>
            </div>
        </div>

        <h3 class="h5 fw-semibold mt-4 mb-3">3. From Within Your Application</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code>my $invoice_data = {
    clientName    => 'ledger28',
    customer_id   => 10118,
    transdate     => '2025-01-15',
    AR            => '1100',
    warehouse_id  => 10134,
    currency      => 'GBP',
    items         => [
        {
            parts_id    => 10116,
            qty         => 1,
            sellprice   => 18.99,
            taxaccounts => '2200'
        }
    ]
};

my $result = $c->create_invoice($invoice_data);

if ($result->{success}) {
    # Use $result->{invoice_id} and $result->{invnumber}
    print "Invoice created: $result->{invnumber}\n";
} else {
    # Handle error
    print "Error: $result->{error}\n";
}</code></pre>
            </div>
        </div>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Invoice Data Structure</h2>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code>my $invoice_data = {
    clientName    => 'database_name',      # Required
    customer_id   => 12345,                # Required
    transdate     => 'YYYY-MM-DD',         # Required
    duedate       => 'YYYY-MM-DD',         # Optional
    AR            => '1100',               # AR account
    warehouse_id  => 10134,                # Optional
    department_id => 10136,                # Optional
    employee_id   => 10102,                # Optional
    currency      => 'GBP',                # Optional
    exchangerate  => 1,                    # Optional
    taxincluded   => 0,                    # 0 or 1
    notes         => 'Invoice notes',      # Optional
    intnotes      => 'Internal notes',     # Optional
    ordnumber     => 'ORD-123',            # Optional
    ponumber      => 'PO-456',             # Optional
    
    items => [
        {
            parts_id    => 10116,          # Required
            partnumber  => 'D009',         # Optional
            description => 'Product',      # Optional
            qty         => 1,              # Required
            sellprice   => 18.99,          # Required
            unit        => 'NOS',          # Optional
            discount    => 0,              # Optional (percentage)
            taxaccounts => '2200'          # Optional
        }
    ],
    
    payment => {                           # Optional
        amount       => 100.00,            # Payment amount
        datepaid     => 'YYYY-MM-DD',      # Payment date
        account      => '1200--Bank',      # Payment account
        source       => 'Cash',            # Payment source
        memo         => 'Payment memo',    # Optional memo
        exchangerate => 1                  # Optional
    }
};</code></pre>
            </div>
        </div>

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">Return Structure</h2>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code># On Success:
{
    success     => 1,
    invoice_id  => 12345,
    invnumber   => 'INV-001',
    message     => 'Invoice created successfully'
}

# On Error:
{
    success => 0,
    error   => 'Error message here'
}</code></pre>
            </div>
        </div>

        <div class="mt-5">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to Main Page</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

