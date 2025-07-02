#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use DBIx::Simple;
use DBI;
use URI::Escape qw(uri_escape);

# Global database configuration
our %db_config = (
    database => 'ledger28',
    user     => 'postgres',
    password => '',
    host     => 'localhost',
    port     => 5432
);

# Global account settings
our $clearing_account = '1230a';
our $transition_account = '1230b';

# Global base URL for CGI deployment
our $base_url = 'https://app.ledger123.com/rma/selected.pl';

# Database connection helper
helper dbs => sub {
    my $dsn = "dbi:Pg:dbname=$db_config{database};host=$db_config{host};port=$db_config{port}";
    return DBIx::Simple->connect($dsn, $db_config{user}, $db_config{password}, {
        RaiseError => 1,
        AutoCommit => 1,
        pg_enable_utf8 => 1
    });
};

# Helper to build URLs
helper build_url => sub ($c, $path, %params) {
    my $url = $base_url;
    $url .= $path if $path && $path ne '/';
    if (%params) {
        my @pairs;
        for my $key (keys %params) {
            if (defined $params{$key}) {
                my $escaped_key = uri_escape($key);
                my $escaped_value = uri_escape($params{$key});
                push @pairs, "$escaped_key=$escaped_value";
            }
        }
        $url .= '?' . join('&', @pairs) if @pairs;
    }
    return $url;
};

# Helper to format numbers with commas and 2 decimal places
helper format_number => sub ($c, $num) {
    return '' unless defined $num;
    my $formatted = sprintf("%.2f", abs($num));
    $formatted =~ s/(\d)(?=(\d{3})+(?!\d))/$1,/g;
    return $formatted;
};

# Main route
get '/' => sub ($c) {
    my $dbs = $c->dbs;
    
    # Get account description
    my $account_desc = $dbs->query(
        "SELECT description FROM chart WHERE accno = ?", 
        $clearing_account
    )->list || 'Unknown Account';
    
    my $sql = q{
        -- Accounts Receivable transactions
        SELECT ac.transdate, ar.invnumber as reference, ar.curr, ac.amount, ac.source, ac.memo,
               ar.id as trans_id, ar.invoice, c.name as company, 'AR' as trans_type
        FROM acc_trans ac 
        INNER JOIN ar ON ar.id = ac.trans_id 
        LEFT JOIN customer c ON c.id = ar.customer_id
        WHERE ac.chart_id IN (SELECT id FROM chart WHERE accno=?)
        
        UNION ALL
        
        -- Accounts Payable transactions  
        SELECT ac.transdate, ap.invnumber as reference, ap.curr, ac.amount, ac.source, ac.memo,
               ap.id as trans_id, ap.invoice, v.name as company, 'AP' as trans_type
        FROM acc_trans ac 
        INNER JOIN ap ON ap.id = ac.trans_id 
        LEFT JOIN vendor v ON v.id = ap.vendor_id
        WHERE ac.chart_id IN (SELECT id FROM chart WHERE accno=?)
        
        UNION ALL
        
        -- General Ledger transactions
        SELECT ac.transdate, gl.reference as reference, gl.curr, ac.amount, ac.source, ac.memo,
               gl.id as trans_id, NULL as invoice, '' as company, 'GL' as trans_type
        FROM acc_trans ac 
        INNER JOIN gl ON gl.id = ac.trans_id
        WHERE ac.chart_id IN (SELECT id FROM chart WHERE accno=?)
        
        ORDER BY transdate, reference
    };
    
    my $results = $dbs->query($sql, $clearing_account, $clearing_account, $clearing_account)->hashes;
    
    # Process results to add reference column and calculate totals
    my ($total_debit, $total_credit) = (0, 0);
    
    for my $row (@$results) {
        # Reference is already consolidated in the SQL query
        $row->{reference_display} = $row->{reference} || '';
        
        # Calculate debit/credit and totals
        if ($row->{amount} < 0) {
            $row->{debit} = abs($row->{amount});
            $row->{credit} = 0;
            $total_debit += abs($row->{amount});
        } else {
            $row->{debit} = 0;
            $row->{credit} = $row->{amount};
            $total_credit += $row->{amount};
        }
    }
    
    $c->render(template => 'transactions', 
               transactions => $results,
               total_debit => $total_debit,
               total_credit => $total_credit,
               clearing_account => $clearing_account,
               account_desc => $account_desc);
};


# Clearing Account Adjustment Route
get '/list_trans' => sub ($c) {
    my $trans_id = $c->param('trans_id');
    my $accno = $c->param('accno') || $clearing_account;
    my $fromdate = $c->param('fromdate') || '';
    my $todate = $c->param('todate') || '';
    my $arap = $c->param('arap') || '';
    my $select_all = $c->param('select_all') || 0;
    my $deselect_all = $c->param('deselect_all') || 0;
    
    return $c->reply->not_found unless $trans_id;
    
    my $dbs = $c->dbs;
    
    # Get GL transaction details
    my $gl_query = q{
        SELECT gl.reference, ac.transdate, c.accno, c.description as account_description, 
               gl.description, ac.source, ac.memo, ac.fx_transaction, gl.curr,
               CASE WHEN ac.amount < 0 THEN ABS(ac.amount) ELSE 0 END as debit,
               CASE WHEN ac.amount > 0 THEN ac.amount ELSE 0 END as credit
        FROM acc_trans ac
        JOIN chart c ON (c.id = ac.chart_id)
        JOIN gl ON gl.id = ac.trans_id
        WHERE ac.trans_id = ?
        ORDER BY c.accno
    };
    
    my $gl_transactions = $dbs->query($gl_query, $trans_id)->hashes;
    
    # Get chart accounts for GL selection
    my $chart_accounts = $dbs->query(q{
        SELECT id, accno || '--' || substr(description,1,30) as descrip
        FROM chart
        WHERE charttype='A' AND allow_gl
        ORDER BY accno
    })->hashes;
    
    # Get the search amount and determine AR/AP based on debit/credit
    my ($search_debit, $search_credit) = $dbs->query(q{
        SELECT 
            CASE WHEN ac.amount < 0 THEN ABS(ac.amount) ELSE 0 END as debit,
            CASE WHEN ac.amount > 0 THEN ac.amount ELSE 0 END as credit
        FROM acc_trans ac
        JOIN gl ON gl.id = ac.trans_id
        WHERE ac.trans_id = ? AND ac.chart_id = (SELECT id FROM chart WHERE accno = ?)
        AND NOT COALESCE(fx_transaction, false)
    }, $trans_id, $accno)->list;
    
    my $search_amount = ($search_debit || 0) + ($search_credit || 0);
    
    # Auto-determine AR/AP if not set
    if (!$arap) {
        $arap = $search_debit > 0 ? 'ap' : 'ar';
    }
    
    # Get outstanding AR/AP transactions
    my (@bind, $where_clause);
    if ($fromdate) {
        $where_clause .= " AND aa.transdate >= ?";
        push @bind, $fromdate;
    }
    if ($todate) {
        $where_clause .= " AND aa.transdate <= ?";
        push @bind, $todate;
    }
    
    my $vc = $arap eq 'ar' ? 'customer' : 'vendor';
    my $transactions_query = qq{
        SELECT aa.id, aa.invnumber, aa.transdate, aa.description, aa.ordnumber, 
               vc.name, aa.curr, aa.amount, aa.paid, aa.amount - aa.paid as due, 
               aa.invoice, aa.fxamount, aa.fxpaid, aa.fxamount - aa.fxpaid as fxdue
        FROM $arap aa
        JOIN $vc vc ON (vc.id = aa.${vc}_id)
        WHERE aa.amount - aa.paid != 0
        $where_clause
        ORDER BY aa.transdate
    };
    
    my $outstanding_transactions = $dbs->query($transactions_query, @bind)->hashes;
    
    $c->render(template => 'clearing_adjustment',
               gl_transactions => $gl_transactions,
               outstanding_transactions => $outstanding_transactions,
               chart_accounts => $chart_accounts,
               trans_id => $trans_id,
               accno => $accno,
               arap => $arap,
               fromdate => $fromdate,
               todate => $todate,
               search_amount => $search_amount,
               select_all => $select_all,
               deselect_all => $deselect_all);
};

# Book selected transactions route
post '/book_selected' => sub ($c) {
    my $trans_id = $c->param('trans_id');
    my $accno = $c->param('accno');
    my $gl_account_id = $c->param('gl_account_id');
    my $rowcount = $c->param('rowcount') || 0;
    
    my @selected_ids;
    for my $i (1..$rowcount-1) {
        if ($c->param("x_$i")) {
            push @selected_ids, $c->param("id_$i");
        }
    }
    
    my $dbs = $c->dbs;
    
    # Get GL transaction details for display
    my $gl_query = q{
        SELECT gl.id, gl.reference, ac.transdate, c.id as acc_id, c.accno, 
               c.description as account_description, gl.description, ac.source, ac.memo,
               CASE WHEN ac.amount < 0 THEN ABS(ac.amount) ELSE 0 END as debit,
               CASE WHEN ac.amount > 0 THEN ac.amount ELSE 0 END as credit
        FROM acc_trans ac
        JOIN gl ON gl.id = ac.trans_id
        JOIN chart c ON (c.id = ac.chart_id)
        WHERE ac.trans_id = ?
        ORDER BY c.accno
    };
    
    my $gl_details = $dbs->query($gl_query, $trans_id)->hashes;
    
    # Get selected transactions details if any
    my $selected_transactions = [];
    if (@selected_ids) {
        my $ids_placeholder = join(',', ('?') x @selected_ids);
        my $selected_query = qq{
            SELECT id, 'ar' as module, invnumber, description, ordnumber, transdate, amount, invoice
            FROM ar WHERE id IN ($ids_placeholder)
            UNION ALL
            SELECT id, 'ap' as module, invnumber, description, ordnumber, transdate, amount, invoice  
            FROM ap WHERE id IN ($ids_placeholder)
            ORDER BY id
        };
        $selected_transactions = $dbs->query($selected_query, @selected_ids, @selected_ids)->hashes;
    }
    
    # Get GL account details if selected
    my $gl_account_details = {};
    if ($gl_account_id) {
        $gl_account_details = $dbs->query(
            "SELECT accno, description FROM chart WHERE id = ?", 
            $gl_account_id
        )->hash || {};
    }
    
    $c->render(template => 'book_confirmation',
               gl_details => $gl_details,
               selected_transactions => $selected_transactions,
               gl_account_details => $gl_account_details,
               trans_id => $trans_id,
               accno => $accno,
               gl_account_id => $gl_account_id,
               selected_ids => join(',', @selected_ids));
};

# Final processing route
# Final processing route - complete implementation
post '/process_adjustment' => sub ($c) {
    my $trans_id = $c->param('trans_id');
    my $gl_account_id = $c->param('gl_account_id');
    my $accno = $c->param('accno');
    my $selected_ids = $c->param('trans') || '';
    
    my $dbs = $c->dbs;
    
    eval {
        # Start transaction
        $dbs->begin;
        
        # Get clearing and transition account IDs
        my $clearing_accno_id = $dbs->query(
            "SELECT id FROM chart WHERE accno = ?", $clearing_account
        )->list;
        
        my $transition_accno_id = $dbs->query(
            "SELECT id FROM chart WHERE accno = ?", $transition_account
        )->list;
        
        # Simple GL account change (no AR/AP transactions selected)
        if ($gl_account_id && !$selected_ids) {
            $dbs->query(
                "UPDATE acc_trans SET chart_id = ? WHERE chart_id = ? AND trans_id = ?",
                $gl_account_id, $clearing_accno_id, $trans_id
            );
            
            $dbs->commit;
            $c->redirect_to($c->build_url('/', success => 'gl_updated'));
            return;
        }
        
        # Complex adjustment with AR/AP transactions
        if ($selected_ids) {
            # Get GL transaction details
            my ($gl_date, $curr, $fxrate) = $dbs->query(
                "SELECT transdate, curr, COALESCE(exchangerate, 1) FROM gl WHERE id = ?", 
                $trans_id
            )->list;
            
            $fxrate ||= 1;  # Default to 1 if null
            
            # Get the adjustment amount available from GL
            my $adjustment_available = $dbs->query(
                "SELECT 0 - amount FROM acc_trans WHERE chart_id = ? AND trans_id = ? AND NOT COALESCE(fx_transaction, false)",
                $clearing_accno_id, $trans_id
            )->list || 0;
            
            # Get AR/AP transactions to be adjusted
            my $query = qq{
                SELECT id, 'ar' as tbl, invnumber, transdate, fxamount - fxpaid as fxdue
                FROM ar
                WHERE id IN ($selected_ids)
                
                UNION ALL
                
                SELECT id, 'ap' as tbl, invnumber, transdate, amount - paid as fxdue
                FROM ap
                WHERE id IN ($selected_ids)
                
                ORDER BY id
            };
            
            my @rows = $dbs->query($query)->hashes;
            
            my $adjustment_total = 0;
            
            # Process each selected AR/AP transaction
            for my $row (@rows) {
                my $arap = $row->{tbl};
                my $ml = ($arap eq 'ap') ? 1 : -1;  # Multiplier for AP vs AR
                my $ARAP = uc($arap);
                
                # Determine payment date (later of GL date or AR/AP date)
                my $arap_date = $row->{transdate};
                my $payment_date;
                
                # Compare dates - use the later one
                if ($c->_date_compare($gl_date, $arap_date) > 0) {
                    $payment_date = $arap_date;
                } else {
                    $payment_date = $gl_date;
                }
                
                # Calculate amount to be adjusted
                my $amount_to_be_adjusted;
                if (abs($adjustment_available * $ml) < abs($row->{fxdue})) {
                    $amount_to_be_adjusted = $adjustment_available;
                    $adjustment_available = 0;
                } else {
                    $amount_to_be_adjusted = $row->{fxdue} * $ml;
                    $adjustment_available -= ($row->{fxdue} * $ml);
                }
                
                # Calculate FX adjustment if needed
                my $fx_amount_to_be_adjusted = 0;
                my $payment_id = undef;
                
                if ($fxrate != 1) {
                    $fx_amount_to_be_adjusted = $amount_to_be_adjusted * $fxrate - $amount_to_be_adjusted;
                    $payment_id = $dbs->query("SELECT COALESCE(MAX(id), 0) + 1 FROM payment")->list || 1;
                }
                
                # Get the AR/AP account ID
                my $arap_accno_id = $dbs->query(
                    "SELECT chart_id FROM acc_trans WHERE trans_id = ? AND chart_id IN (SELECT id FROM chart WHERE link LIKE ?) LIMIT 1",
                    $row->{id}, "%${ARAP}%"
                )->list;
                
                if ($arap eq 'ap') {
                    # AP adjustments
                    $dbs->query(
                        "INSERT INTO acc_trans(trans_id, chart_id, transdate, amount, id) VALUES (?, ?, ?, ?, ?)",
                        $row->{id}, $transition_accno_id, $payment_date, $amount_to_be_adjusted, $payment_id
                    );
                    
                    if ($fx_amount_to_be_adjusted != 0) {
                        $dbs->query(
                            "INSERT INTO acc_trans(trans_id, chart_id, fx_transaction, transdate, amount) VALUES (?, ?, ?, ?, ?)",
                            $row->{id}, $transition_accno_id, 't', $payment_date, $fx_amount_to_be_adjusted
                        );
                    }
                    
                    $dbs->query(
                        "INSERT INTO acc_trans(trans_id, chart_id, transdate, amount) VALUES (?, ?, ?, ?)",
                        $row->{id}, $arap_accno_id, $payment_date, 
                        ($row->{fxdue} * -1) + (($row->{fxdue} * $fxrate - $row->{fxdue}) * -1)
                    );
                    
                } else {
                    # AR adjustments
                    $dbs->query(
                        "INSERT INTO acc_trans(trans_id, chart_id, transdate, amount, id) VALUES (?, ?, ?, ?, ?)",
                        $row->{id}, $transition_accno_id, $payment_date, $amount_to_be_adjusted * -1, $payment_id
                    );
                    
                    if ($fx_amount_to_be_adjusted != 0) {
                        $dbs->query(
                            "INSERT INTO acc_trans(trans_id, chart_id, fx_transaction, transdate, amount) VALUES (?, ?, ?, ?, ?)",
                            $row->{id}, $transition_accno_id, 't', $payment_date, $fx_amount_to_be_adjusted * -1
                        );
                    }
                    
                    $dbs->query(
                        "INSERT INTO acc_trans(trans_id, chart_id, transdate, amount) VALUES (?, ?, ?, ?)",
                        $row->{id}, $arap_accno_id, $payment_date,
                        $row->{fxdue} + ($row->{fxdue} * $fxrate - $row->{fxdue})
                    );
                }
                
                # Insert payment record if FX rate is not 1
                if ($payment_id && $fxrate != 1) {
                    $dbs->query(
                        "INSERT INTO payment (id, trans_id, exchangerate) VALUES (?, ?, ?)",
                        $payment_id, $row->{id}, $fxrate
                    );
                }
                
                # Update AR/AP paid amounts and payment date
                $dbs->query(
                    "UPDATE $arap SET paid = paid + ?, fxpaid = COALESCE(fxpaid, 0) + ?, datepaid = ? WHERE id = ?",
                    $amount_to_be_adjusted + $fx_amount_to_be_adjusted,
                    abs($amount_to_be_adjusted),
                    $payment_date,
                    $row->{id}
                );
                
                $adjustment_total += $amount_to_be_adjusted;
            }
            
            # Update GL transaction - replace clearing account with transition account
            if ($adjustment_total != 0) {
                # Add transition account entry
                $dbs->query(
                    "INSERT INTO acc_trans (trans_id, chart_id, amount, transdate) VALUES (?, ?, ?, ?)",
                    $trans_id, $transition_accno_id, $adjustment_total, $gl_date
                );
                
                # Add FX transaction if needed
                if ($fxrate != 1) {
                    my $fx_adjustment = $adjustment_total * $fxrate - $adjustment_total;
                    if ($fx_adjustment != 0) {
                        $dbs->query(
                            "INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction) VALUES (?, ?, ?, ?, ?)",
                            $trans_id, $transition_accno_id, $fx_adjustment, $gl_date, 't'
                        );
                    }
                }
                
                # Reduce the clearing account amount
                $dbs->query(
                    "UPDATE acc_trans SET amount = amount - ? WHERE chart_id = ? AND trans_id = ? AND NOT COALESCE(fx_transaction, false)",
                    $adjustment_total, $clearing_accno_id, $trans_id
                );
                
                # Check if clearing account amount is now zero and delete if so
                my $remaining_amount = $dbs->query(
                    "SELECT amount FROM acc_trans WHERE chart_id = ? AND trans_id = ? AND NOT COALESCE(fx_transaction, false)",
                    $clearing_accno_id, $trans_id
                )->list;
                
                if (defined $remaining_amount && abs($remaining_amount) < 0.01) {  # Essentially zero
                    $dbs->query(
                        "DELETE FROM acc_trans WHERE chart_id = ? AND trans_id = ? AND NOT COALESCE(fx_transaction, false)",
                        $clearing_accno_id, $trans_id
                    );
                }
            }
            
            $dbs->commit;
            $c->redirect_to($c->build_url('/', success => 'adjustment_complete'));
        }
    };
    
    if ($@) {
        $dbs->rollback;
        $c->render(text => "Error processing adjustment: $@", status => 500);
    }
};

# Helper method for date comparison
helper _date_compare => sub ($c, $date1, $date2) {
    # Simple date comparison - assumes YYYY-MM-DD format
    # Returns: -1 if date1 < date2, 0 if equal, 1 if date1 > date2
    return $date1 cmp $date2;
};


app->start;

__DATA__

@@ transactions.html.ep
<!DOCTYPE html>
<html>
<head>
    <title>Accounting Transactions Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .number { text-align: right; }
        .total-row { background-color: #f9f9f9; font-weight: bold; }
        .date { white-space: nowrap; }
        .date a { color: #0066cc; text-decoration: none; }
        .date a:hover { text-decoration: underline; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f5f5f5; }
    </style>
</head>
<body>
    <h1>Accounting Transactions Report</h1>
    <h2 style="color: #666; margin-top: 5px;">Account: <%= $clearing_account %> - <%= $account_desc %></h2>
    
    <table>
        <thead>
            <tr>
                <th>Transaction Date</th>
                <th>Type</th>
                <th>Reference</th>
                <th>Currency</th>
                <th>Company</th>
                <th>Source</th>
                <th>Memo</th>
                <th class="number">Debit</th>
                <th class="number">Credit</th>
            </tr>
        </thead>
        <tbody>
            <% for my $trans (@$transactions) { %>
                <tr>
                    <td class="date">
                        <a href="<%= build_url('/list_trans', trans_id => $trans->{trans_id}, accno => $clearing_account) %>">
                            <%= $trans->{transdate} %>
                        </a>
                    </td>
                    <td><%= $trans->{trans_type} %></td>
                    <td><%= $trans->{reference_display} %></td>
                    <td><%= $trans->{curr} || '' %></td>
                    <td><%= $trans->{company} || '' %></td>
                    <td><%= $trans->{source} || '' %></td>
                    <td><%= $trans->{memo} || '' %></td>
                    <td class="number">
                        <%= $trans->{debit} > 0 ? format_number($trans->{debit}) : '' %>
                    </td>
                    <td class="number">
                        <%= $trans->{credit} > 0 ? format_number($trans->{credit}) : '' %>
                    </td>
                </tr>
            <% } %>
            <tr class="total-row">
                <td colspan="7"><strong>TOTALS:</strong></td>
                <td class="number"><strong><%= format_number($total_debit) %></strong></td>
                <td class="number"><strong><%= format_number($total_credit) %></strong></td>
            </tr>
        </tbody>
    </table>
    
    <p style="margin-top: 20px; font-size: 12px; color: #666;">
        Total Records: <%= scalar @$transactions %> |
        Total Debit: <%= format_number($total_debit) %> |
        Total Credit: <%= format_number($total_credit) %>
    </p>
</body>
</html>

@@ clearing_adjustment.html.ep
<!DOCTYPE html>
<html>
<head>
    <title>Clearing Account Adjustment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #333; }
        table { border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .number { text-align: right; }
        .form-table { border: none; }
        .form-table td { border: none; padding: 5px; }
        .submit { margin: 5px; padding: 8px 15px; }
        select, input[type="text"] { padding: 4px; }
        .checkbox { margin-right: 5px; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .highlight { background-color: #ffffcc !important; }
    </style>
</head>
<body>
    <h1>Clearing Account Adjustment</h1>
    
    <!-- GL Transaction Details -->
    <h2>GL Transaction Details</h2>
    <table>
        <thead>
            <tr>
                <th>Reference</th>
                <th>Date</th>
                <th>Account</th>
                <th>Description</th>
                <th>GL Description</th>
                <th>Source</th>
                <th>Memo</th>
                <th>Currency</th>
                <th class="number">Debit</th>
                <th class="number">Credit</th>
            </tr>
        </thead>
        <tbody>
            <% for my $gl (@$gl_transactions) { %>
                <tr>
                    <td><%= $gl->{reference} %></td>
                    <td><%= $gl->{transdate} %></td>
                    <td><%= $gl->{accno} %></td>
                    <td><%= $gl->{account_description} %></td>
                    <td><%= $gl->{description} || '' %></td>
                    <td><%= $gl->{source} || '' %></td>
                    <td><%= $gl->{memo} || '' %></td>
                    <td><%= $gl->{curr} || '' %></td>
                    <td class="number"><%= $gl->{debit} ? format_number($gl->{debit}) : '' %></td>
                    <td class="number"><%= $gl->{credit} ? format_number($gl->{credit}) : '' %></td>
                </tr>
            <% } %>
        </tbody>
    </table>

    <!-- GL Account Selection Form -->
    <form action="<%= build_url('/list_trans') %>" method="get">
        <input type="hidden" name="trans_id" value="<%= $trans_id %>">
        <input type="hidden" name="accno" value="<%= $accno %>">
        
        <table class="form-table">
            <tr>
                <td><strong>GL Account:</strong></td>
                <td>
                    <select name="gl_account_id">
                        <option value="">Select Account</option>
                        <% for my $chart (@$chart_accounts) { %>
                            <option value="<%= $chart->{id} %>"><%= $chart->{descrip} %></option>
                        <% } %>
                    </select>
                </td>
            </tr>
            <tr>
                <td><strong>From Date:</strong></td>
                <td><input type="date" name="fromdate" value="<%= $fromdate %>"></td>
            </tr>
            <tr>
                <td><strong>To Date:</strong></td>
                <td><input type="date" name="todate" value="<%= $todate %>"></td>
            </tr>
            <tr>
                <td><strong>AR or AP:</strong></td>
                <td>
                    <select name="arap">
                        <option value="ar" <%= $arap eq 'ar' ? 'selected' : '' %>>AR</option>
                        <option value="ap" <%= $arap eq 'ap' ? 'selected' : '' %>>AP</option>
                    </select>
                </td>
            </tr>
        </table>
        
        <input type="submit" class="submit" value="Continue">
        <input type="submit" class="submit" name="select_all" value="Select all">
        <input type="submit" class="submit" name="deselect_all" value="Deselect all">
    </form>

    <!-- Outstanding Transactions -->
    <% if (@$outstanding_transactions) { %>
        <h2>Outstanding <%= uc($arap) %> Transactions</h2>
        <form action="<%= build_url('/book_selected') %>" method="post">
            <input type="hidden" name="trans_id" value="<%= $trans_id %>">
            <input type="hidden" name="accno" value="<%= $accno %>">
            
            <table>
                <thead>
                    <tr>
                        <th>Select</th>
                        <th>Invoice#</th>
                        <th>Date</th>
                        <th>Description</th>
                        <th>Order#</th>
                        <th>Customer/Vendor</th>
                        <th>Currency</th>
                        <th class="number">Amount</th>
                        <th class="number">Paid</th>
                        <th class="number">Due</th>
                    </tr>
                </thead>
                <tbody>
                    <% my $j = 1; %>
                    <% for my $trans (@$outstanding_transactions) { %>
                        <% 
                            my $checked = '';
                            if (abs($trans->{fxdue} || $trans->{due}) == $search_amount) {
                                $checked = 'checked';
                            }
                            $checked = 'checked' if $select_all;
                            $checked = '' if $deselect_all;
                        %>
                        <tr <%= $checked ? 'class="highlight"' : '' %>>
                            <td>
                                <input type="checkbox" class="checkbox" name="x_<%= $j %>" <%= $checked %>>
                                <input type="hidden" name="id_<%= $j %>" value="<%= $trans->{id} %>">
                            </td>
                            <td><%= $trans->{invnumber} %></td>
                            <td><%= $trans->{transdate} %></td>
                            <td><%= $trans->{description} || '' %></td>
                            <td><%= $trans->{ordnumber} || '' %></td>
                            <td><%= $trans->{name} %></td>
                            <td><%= $trans->{curr} %></td>
                            <td class="number"><%= format_number($trans->{amount}) %></td>
                            <td class="number"><%= format_number($trans->{paid}) %></td>
                            <td class="number"><%= format_number($trans->{due}) %></td>
                        </tr>
                        <% $j++; %>
                    <% } %>
                </tbody>
            </table>
            
            <input type="hidden" name="rowcount" value="<%= $j %>">
            <input type="submit" class="submit" value="Book selected transactions">
        </form>
    <% } %>
    
    <p><a href="<%= build_url('/') %>">← Back to Main Report</a></p>
</body>
</html>

@@ book_confirmation.html.ep
<!DOCTYPE html>
<html>
<head>
    <title>Final Step: Clearing Account Adjustment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2, h3 { color: #333; }
        table { border-collapse: collapse; margin: 20px 0; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .number { text-align: right; }
        .submit { margin: 10px 5px; padding: 10px 20px; }
        .total-row { background-color: #f9f9f9; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>Final Step: Clearing Account Adjustment</h1>
    
    <h3>Clearing account transaction...</h3>
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Reference</th>
                <th>Date</th>
                <th>Account</th>
                <th>Account Description</th>
                <th>Description</th>
                <th>Source</th>
                <th>Memo</th>
                <th class="number">Debit</th>
                <th class="number">Credit</th>
            </tr>
        </thead>
        <tbody>
            <% for my $gl (@$gl_details) { %>
                <tr>
                    <td><%= $gl->{id} %></td>
                    <td><%= $gl->{reference} %></td>
                    <td><%= $gl->{transdate} %></td>
                    <td><%= $gl->{accno} %></td>
                    <td><%= $gl->{account_description} %></td>
                    <td><%= $gl->{description} || '' %></td>
                    <td><%= $gl->{source} || '' %></td>
                    <td><%= $gl->{memo} || '' %></td>
                    <td class="number"><%= $gl->{debit} ? format_number($gl->{debit}) : '' %></td>
                    <td class="number"><%= $gl->{credit} ? format_number($gl->{credit}) : '' %></td>
                </tr>
            <% } %>
        </tbody>
    </table>

    <% if (@$selected_transactions) { %>
        <h3>Transactions to be adjusted...</h3>
        <table>
            <thead>
                <tr>
                    <th>Invoice</th>
                    <th>Description</th>
                    <th>Order Number</th>
                    <th>Date</th>
                    <th class="number">Amount</th>
                </tr>
            </thead>
            <tbody>
                <% my $total_amount = 0; %>
                <% for my $trans (@$selected_transactions) { %>
                    <tr>
                        <td><%= $trans->{invnumber} %></td>
                        <td><%= $trans->{description} || '' %></td>
                        <td><%= $trans->{ordnumber} || '' %></td>
                        <td><%= $trans->{transdate} %></td>
                        <td class="number"><%= format_number($trans->{amount}) %></td>
                    </tr>
                    <% $total_amount += $trans->{amount}; %>
                <% } %>
                <tr class="total-row">
                    <td colspan="4"><strong>Total:</strong></td>
                    <td class="number"><strong><%= format_number($total_amount) %></strong></td>
                </tr>
            </tbody>
        </table>
    <% } %>

    <% if ($gl_account_details->{accno}) { %>
        <h3>Selected GL Account</h3>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th>Description</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td><%= $gl_account_details->{accno} %></td>
                    <td><%= $gl_account_details->{description} %></td>
                </tr>
            </tbody>
        </table>
    <% } %>

    <form action="<%= build_url('/process_adjustment') %>" method="post">
        <input type="hidden" name="trans_id" value="<%= $trans_id %>">
        <input type="hidden" name="gl_account_id" value="<%= $gl_account_id %>">
        <input type="hidden" name="accno" value="<%= $accno %>">
        <input type="hidden" name="trans" value="<%= $selected_ids %>">
        <input type="submit" class="submit" value="Just do it">
    </form>
    
    <p><a href="<%= build_url('/list_trans', trans_id => $trans_id, accno => $accno) %>">← Back to Adjustment</a></p>
    <p><a href="<%= build_url('/') %>">← Back to Main Report</a></p>
</body>
</html>

