#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use DBIx::Simple;
use DBI;

# Global database configuration
our %db_config = (
    database => 'ledger28',
    user     => 'postgres',
    password => '',
    host     => 'localhost',
    port     => 5432
);

# Global selected account
our $selected_account = '1230a';

# Database connection helper
helper dbs => sub {
    my $dsn = "dbi:Pg:dbname=$db_config{database};host=$db_config{host};port=$db_config{port}";
    return DBIx::Simple->connect($dsn, $db_config{user}, $db_config{password}, {
        RaiseError => 1,
        AutoCommit => 1,
        pg_enable_utf8 => 1
    });
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
        $selected_account
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
    
    my $results = $dbs->query($sql, $selected_account, $selected_account, $selected_account)->hashes;
    
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
               selected_account => $selected_account,
               account_desc => $account_desc);
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
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f5f5f5; }
    </style>
</head>
<body>
    <h1>Accounting Transactions Report</h1>
    <h2 style="color: #666; margin-top: 5px;">Account: <%= $selected_account %> - <%= $account_desc %></h2>
    
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
                    <td class="date"><%= $trans->{transdate} %></td>
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

