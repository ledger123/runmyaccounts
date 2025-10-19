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

# Main page - List invoices
get '/' => sub {
    my $c = shift;

    my $dbname = $c->param('dbname') || 'ledger28';
    my $db     = $c->db($dbname);

    my @invoices = $db->query('SELECT id, invnumber, transdate, amount, paid FROM ar ORDER BY invnumber DESC LIMIT 100')->hashes;

    $c->stash(
        invoices => \@invoices,
        dbname   => $dbname
    );
    $c->render( template => 'index' );
};

# Print invoice as PDF
get '/print_invoice/:id' => sub {
    my $c = shift;

    # TODO: To be fixed
    ## Line items don't print
    ## Payment information is missing
    ## Shipto/address/defaults need to be corrected

    my $invoice_id = $c->param('id');
    my $dbname     = $c->param('dbname') || 'ledger28';

    # Get current working directory
    use Cwd 'abs_path';
    use File::Basename;
    my $script_dir = dirname( abs_path($0) );

    # Create form object
    my $form     = new Form;
    my $myconfig = $c->myconfig($dbname);

    # Override myconfig with correct absolute paths
    $myconfig->{templates}      = "$script_dir/templates/demo\@ledger28";
    $myconfig->{tempdir}        = "$script_dir/tmp";
    $myconfig->{company}        = 'SQL-Ledger';
    $myconfig->{tel}            = '';
    $myconfig->{fax}            = '';
    $myconfig->{businessnumber} = '';
    $myconfig->{address}        = '';

    # Create tmp directory if it doesn't exist
    mkdir $myconfig->{tempdir} unless -d $myconfig->{tempdir};

    # Set form parameters
    $form->{id}       = $invoice_id;
    $form->{type}     = 'invoice';
    $form->{formname} = 'invoice';
    $form->{format}   = 'pdf';
    $form->{media}    = 'screen';
    $form->{vc}       = 'customer';
    $form->{ARAP}     = 'AR';

    # Initialize database connection
    $form->{dbh} = DBI->connect( $myconfig->{dbconnect}, $myconfig->{dbuser}, $myconfig->{dbpasswd}, { AutoCommit => 1, RaiseError => 1, PrintError => 0 } )
      or die "Cannot connect to database: $DBI::errstr";

    eval {
        # Retrieve invoice
        $form->{db} = 'customer';

        $form->create_links( "AR", $myconfig, "customer", 1 );
        AA->get_name( $myconfig, $form );

        IS->retrieve_invoice( $myconfig, $form );

        AA->company_details( $myconfig, $form );

        # Get invoice details
        IS->invoice_details( $myconfig, $form );

        # CRITICAL FIX: Convert invoice_details array to line item format for template
        my $i = 1;
        foreach my $ref ( @{ $form->{invoice_details} } ) {
            map { $form->{"${_}_$i"} = $ref->{$_} } keys %$ref;
            $i++;
        }
        $form->{rowcount} = $i - 1;

        # CRITICAL FIX: Format payment information for template
        my $j = 1;
        foreach my $ref ( @{ $form->{acc_trans}{AR_paid} } ) {
            $form->{"paid_$j"}         = $ref->{amount} * -1;  # Reverse sign for display
            $form->{"datepaid_$j"}     = $ref->{transdate};
            $form->{"source_$j"}       = $ref->{source};
            $form->{"memo_$j"}         = $ref->{memo};
            $form->{"AR_paid_$j"}      = "$ref->{accno}--$ref->{description}";
            $form->{"exchangerate_$j"} = $ref->{exchangerate};
            $j++;
        }
        $form->{paidaccounts} = $j - 1;

        # Set additional form fields needed for template
        $form->{company} = $myconfig->{company};
        $form->{address} = $myconfig->{address};
        $form->{tel}     = $myconfig->{tel};
        $form->{fax}     = $myconfig->{fax};

        # Set language
        $form->{language_code} ||= '';

        # Set the input template file - just the filename, path is in templates
        $form->{IN}        = "invoice.tex";
        $form->{templates} = $myconfig->{templates};

        # Verify template exists
        my $full_template_path = "$myconfig->{templates}/$form->{IN}";
        unless ( -f $full_template_path ) {
            die "<pre>Template file not found: $full_template_path\n" . "Script dir: $script_dir\n" . "Templates dir: $myconfig->{templates}\n" . "Looking for: $form->{IN}";
        }

        # Create unique temporary filename
        my $timestamp      = time;
        my $safe_invnumber = $form->{invnumber};
        $safe_invnumber =~ s/[^a-zA-Z0-9_-]/_/g;
        $form->{tmpfile} = "${timestamp}_${safe_invnumber}";

        # Set output file path - just the filename, path is in tempdir
        $form->{OUT} = "$form->{tmpfile}.tex";

        # Process the template
        $form->parse_template( $myconfig, $myconfig->{tempdir} );

        my $pdf_file = "$myconfig->{tempdir}/$form->{tmpfile}.pdf";

        # Read the PDF
        open my $pdf_fh, '<:raw', $pdf_file or die "Cannot open PDF: $!";
        my $pdf_content = do { local $/; <$pdf_fh> };
        close $pdf_fh;

        # Disconnect database
        $form->{dbh}->disconnect if $form->{dbh};

        # Send PDF to browser
        $c->res->headers->content_type('application/pdf');
        $c->res->headers->content_disposition("attachment; filename=\"$form->{invnumber}.pdf\"");
        return $c->render( data => $pdf_content );
    };

    if ($@) {

        # Disconnect database on error
        $form->{dbh}->disconnect if $form->{dbh};

        return $c->render(
            text   => "Error generating PDF: $@",
            status => 500
        );
    }
};

# Test invoice creation pages
get '/test_invoices' => sub {
    my $c = shift;
    $c->render( template => 'test_invoices' );
};

# Usage notes page
get '/usage_notes' => sub {
    my $c = shift;
    $c->render( template => 'usage_notes' );
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
        title  => 'Single Item Invoice - Digger Hand Trencher'
    );
    $c->render( template => 'result' );
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
        title  => 'Single Item Invoice - The Claw Hand Rake'
    );
    $c->render( template => 'result' );
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
            amount   => 37.98,
            datepaid => '2025-01-15',
            account  => '1200--Bank Current Account',
            source   => 'Cash',
            memo     => 'Payment received'
        }
    };

    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title  => 'Single Item with Full Payment'
    );
    $c->render( template => 'result' );
};

# Single item with partial payment
get '/test_single_partial_payment' => sub {
    my $c = shift;

    my $invoice_data = {
        clientName   => 'ledger28',
        customer_id  => 10118,
        transdate    => '2025-01-15',
        AR           => '1100',
        warehouse_id => 10134,
        currency     => 'GBP',
        notes        => 'Single item with partial payment',
        items        => [
            {
                parts_id    => 10116,
                qty         => 3,
                sellprice   => 18.99,
                taxaccounts => '2200'
            }
        ],
        payment => {
            amount   => 30.00,
            datepaid => '2025-01-15',
            account  => '1200--Bank Current Account',
            source   => 'Bank Transfer',
            memo     => 'Partial payment'
        }
    };

    my $result = $c->create_invoice($invoice_data);
    $c->stash(
        result => $result,
        title  => 'Single Item with Partial Payment'
    );
    $c->render( template => 'result' );
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
        title  => 'Multiple Items (Original AR-001)'
    );
    $c->render( template => 'result' );
};

# Three items with payment
get '/test_multi_items_three' => sub {
    my $c = shift;

    my $invoice_data = {
        clientName   => 'ledger28',
        customer_id  => 10118,
        transdate    => '2025-01-15',
        AR           => '1100',
        warehouse_id => 10134,
        currency     => 'GBP',
        notes        => 'Three items with full payment',
        items        => [
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
        title  => 'Three Items with Payment'
    );
    $c->render( template => 'result' );
};

# Invoice without payment
get '/test_no_payment' => sub {
    my $c = shift;

    my $invoice_data = {
        clientName   => 'ledger28',
        customer_id  => 10118,
        transdate    => '2025-01-15',
        duedate      => '2025-02-15',
        AR           => '1100',
        warehouse_id => 10134,
        currency     => 'GBP',
        notes        => 'Invoice on credit - 30 days',
        items        => [
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
        title  => 'Invoice Without Payment (Credit)'
    );
    $c->render( template => 'result' );
};

# Invoice with discount
get '/test_with_discount' => sub {
    my $c = shift;

    my $invoice_data = {
        clientName   => 'ledger28',
        customer_id  => 10118,
        transdate    => '2025-01-15',
        AR           => '1100',
        warehouse_id => 10134,
        currency     => 'GBP',
        notes        => 'Invoice with 10% discount',
        items        => [
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
        title  => 'Invoice With 10% Discount'
    );
    $c->render( template => 'result' );
};

# Invoice with notes
get '/test_with_notes' => sub {
    my $c = shift;

    my $invoice_data = {
        clientName   => 'ledger28',
        customer_id  => 10118,
        transdate    => '2025-01-15',
        AR           => '1100',
        warehouse_id => 10134,
        currency     => 'GBP',
        notes        => 'Customer requested express delivery. Handle with care.',
        intnotes     => 'Priority customer - check stock before confirming',
        ordnumber    => 'ORD-2025-001',
        ponumber     => 'PO-CUST-123',
        items        => [
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
        title  => 'Invoice With Notes and References'
    );
    $c->render( template => 'result' );
};

# Batch create invoices
get '/test_batch_create' => sub {
    my $c = shift;

    my @results;

    for my $i ( 1 .. 5 ) {
        my $invoice_data = {
            clientName   => 'ledger28',
            customer_id  => 10118,
            transdate    => '2025-01-15',
            AR           => '1100',
            warehouse_id => 10134,
            currency     => 'GBP',
            notes        => "Batch invoice $i of 5",
            items        => [
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

    $c->stash( results => \@results );
    $c->render( template => 'batch_results' );
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
                        <a class="nav-link active" href="<%= url_for '/' %>">Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Creation</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage Notes</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <h1 class="h3 fw-bold mb-0">Invoice List</h1>
            <span class="badge bg-secondary"><%= scalar @$invoices %> invoices</span>
        </div>
        
        <div class="table-responsive">
            <table class="table table-dark table-hover table-bordered">
                <thead>
                    <tr class="table-secondary">
                        <th>ID</th>
                        <th>Invoice Number</th>
                        <th>Date</th>
                        <th class="text-end">Amount</th>
                        <th class="text-end">Paid</th>
                        <th class="text-end">Balance</th>
                        <th class="text-center">Action</th>
                    </tr>
                </thead>
                <tbody>
                    % for my $invoice (@$invoices) {
                        % my $balance = $invoice->{amount} - $invoice->{paid};
                        % my $status_class = $balance > 0 ? 'text-warning' : 'text-success';
                        <tr>
                            <td><%= $invoice->{id} %></td>
                            <td><strong><%= $invoice->{invnumber} %></strong></td>
                            <td><%= $invoice->{transdate} %></td>
                            <td class="text-end"><%= sprintf("%.2f", $invoice->{amount}) %></td>
                            <td class="text-end"><%= sprintf("%.2f", $invoice->{paid}) %></td>
                            <td class="text-end <%= $status_class %>"><strong><%= sprintf("%.2f", $balance) %></strong></td>
                            <td class="text-center">
                                <a href="<%= url_for('/print_invoice/' . $invoice->{id})->query(dbname => $dbname) %>" 
                                   class="btn btn-sm btn-outline-light"
                                   target="_blank">
                                    Print PDF
                                </a>
                            </td>
                        </tr>
                    % }
                </tbody>
            </table>
        </div>
        
        % if (scalar @$invoices == 0) {
            <div class="alert alert-secondary border-secondary text-center" role="alert">
                No invoices found
            </div>
        % }
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
                        <a class="nav-link" href="<%= url_for '/' %>">Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link active" href="<%= url_for '/test_invoices' %>">Test Creation</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/usage_notes' %>">Usage Notes</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-5" style="max-width: 900px;">
        <h1 class="display-5 fw-bold mb-3">Test Invoice Creation</h1>
        <p class="lead text-secondary mb-4">Create test invoices with Auto Exchange Express data</p>
        
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
                        <a class="nav-link" href="<%= url_for '/' %>">Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Creation</a>
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
            
            <div class="mt-4">
                <a href="<%= url_for('/print_invoice/' . $result->{invoice_id})->query(dbname => 'ledger28') %>" 
                   class="btn btn-success me-2"
                   target="_blank">
                    Download PDF
                </a>
                <a href="<%= url_for '/' %>" class="btn btn-outline-light">View All Invoices</a>
            </div>
        % } else {
            <div class="alert alert-danger border-danger" role="alert">
                <h4 class="alert-heading">Error Creating Invoice</h4>
                <hr>
                <p class="mb-0"><%= $result->{error} %></p>
            </div>
            
            <div class="mt-4">
                <a href="<%= url_for '/test_invoices' %>" class="btn btn-outline-light">Back to Test Creation</a>
            </div>
        % }
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
                        <a class="nav-link" href="<%= url_for '/' %>">Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Creation</a>
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
                        <th style="width: 10%">Action</th>
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
                            <td class="text-center">
                                % if ($result->{success}) {
                                    <a href="<%= url_for('/print_invoice/' . $result->{invoice_id})->query(dbname => 'ledger28') %>" 
                                       class="btn btn-sm btn-outline-light"
                                       target="_blank">
                                        PDF
                                    </a>
                                % } else {
                                    <span class="text-secondary">-</span>
                                % }
                            </td>
                        </tr>
                    % }
                </tbody>
            </table>
        </div>
        
        <div class="mt-4">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light me-2">View All Invoices</a>
            <a href="<%= url_for '/test_invoices' %>" class="btn btn-outline-secondary">Back to Test Creation</a>
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
                        <a class="nav-link" href="<%= url_for '/' %>">Invoices</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="<%= url_for '/test_invoices' %>">Test Creation</a>
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

        <h2 class="h4 fw-bold mt-5 mb-3 pb-2 border-bottom border-secondary">How to Use</h2>

        <h3 class="h5 fw-semibold mt-4 mb-3">1. View Invoices</h3>
        <p class="text-secondary">Navigate to the main page to see a list of all invoices. Click "Print PDF" button to download invoice as PDF.</p>

        <h3 class="h5 fw-semibold mt-4 mb-3">2. Create Test Invoices</h3>
        <p class="text-secondary">Use the "Test Creation" menu to create sample invoices with predefined data.</p>

        <h3 class="h5 fw-semibold mt-4 mb-3">3. As Daemon</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code>perl api.pl daemon
# Then open: http://localhost:3000</code></pre>
            </div>
        </div>

        <h3 class="h5 fw-semibold mt-4 mb-3">4. As CGI</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code>chmod +x api.pl
# Place in cgi-bin directory
# Access via web server (Apache/Nginx)</code></pre>
            </div>
        </div>

        <h3 class="h5 fw-semibold mt-4 mb-3">5. Print Invoice Programmatically</h3>
        <div class="card bg-black border-secondary mb-4">
            <div class="card-body">
                <pre class="mb-0"><code># Generate PDF for invoice ID 12345
my $invoice_id = 12345;
my $url = "/print_invoice/$invoice_id?dbname=ledger28";
# Returns PDF file for download</code></pre>
            </div>
        </div>

        <div class="mt-5">
            <a href="<%= url_for '/' %>" class="btn btn-outline-light">Back to Invoices</a>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

