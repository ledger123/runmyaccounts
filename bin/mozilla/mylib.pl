use IO::File;
use File::Temp qw(tempfile);
#use Spreadsheet::WriteExcel;

1;

###############################
sub export_to_xls {
   my ($dbh, $query, $filename) = @_;

   my ($fh, $name) = tempfile();

   my $workbook = Spreadsheet::WriteExcel->new("$name");
   my $worksheet = $workbook->add_worksheet();

   my $sth = $dbh->prepare($query);
   $sth->execute or $form->dberror($query);
   my $ncols = $sth->{NUM_OF_FIELDS};
   my $line = 0;
   for (0 .. $ncols - 1) {
       $worksheet->write($line, $_, $sth->{NAME}->[$_]);
   }
   $line++;
   while (@row = $sth->fetchrow_array) {
      for ($column=0; $column<=$ncols; $column++) {
         $worksheet->write($line, $column, $row[$column]);
      }
      $line++;
   }
   $workbook->close;

   my @fileholder;
   open (DLFILE, qq|<$name|) || $form->error('Cannot open file for download');
   @fileholder = <DLFILE>;
   close (DLFILE) || $form->error('Cannot close file opened for download');
   my $dlfile = $filename . ".xls";
   print "Content-Type: application/vnd.ms-excel\n";
   print "Content-Disposition: attachment; filename=$dlfile\n\n";
   print @fileholder;
   unlink($name) or die "Couldn't unlink $name : $!" 
}
 
###############################
sub ref_to_csv {
   my ($data, $filename, $column_index) = @_;

   my ($fh, $name) = tempfile();

   for (@$column_index) { print $fh "$_," }
   print $fh "\n";

   foreach $ref (@{ $form->{$data} }) {
   	  my $cellValue = '';
      for (@$column_index) {
      	$cellValue = &escape_csv($ref->{$_});
      	print $fh qq|"$cellValue",|;
      }
      print $fh "\n";
   }

   close ($fh) || $form->error('Cannot close csv file');
   my @fileholder;
   open (DLFILE, qq|<$name|) || $form->error('Cannot open file for download');
   @fileholder = <DLFILE>;
   close (DLFILE) || $form->error('Cannot close file opened for download');
   my $dlfile = $filename . ".csv";
   print "Content-Type: application/csv\n";
   print "Content-Disposition:attachment; filename=$dlfile\n\n";
   print @fileholder;
   unlink($name) or die "Couldn't unlink $name : $!" 
}

###############################
sub export_to_csv {
   my ($dbh, $query, $filename, $copyfromcsv) = @_;

   my ($fh, $name) = tempfile();

   my $sth = $dbh->prepare($query);
   $sth->execute or $form->dberror($query);
   my $ncols = $sth->{NUM_OF_FIELDS};
   my $collist;
   for (0 .. $ncols - 1) {
       $collist .= "$sth->{NAME}->[$_],";
   }
   chop $collist; 
   if ($copyfromcsv){
       print $fh "COPY tablename($collist) FROM STDIN CSV HEADER;\n";
    }
   print $fh "$collist\n";
   my $line; 
   while (@row = $sth->fetchrow_array) {
      $line = '';
      for ($column=0; $column<$ncols; $column++) {
         $line .= qq|"$row[$column]",|;
      }
      chop $line;
      print $fh "$line\n";
   }
   print $fh '\.' if $copyfromcsv;
   close ($fh) || $form->error('Cannot close csv file');

   my @fileholder;
   open (DLFILE, qq|<$name|) || $form->error('Cannot open file for download');
   @fileholder = <DLFILE>;
   close (DLFILE) || $form->error('Cannot close file opened for download');
   my $dlfile = $filename . ".csv";
   print "Content-Type: application/csv\n";
   print "Content-Disposition:attachment; filename=$dlfile\n\n";
   print @fileholder;
   unlink($name) or die "Couldn't unlink $name : $!" 
}

sub escape_csv {
   my $str = shift;
   $str =~ s/"/""/g;
   $str =~ s/\n/ /g;
   return $str;
}

sub escape_double_quotes_with_two_double_quotes {
   my $str = shift;
   $str =~ s/"/""/g;
   return $str;
}

#################
#
# EOF: mylib.pl
#
#################
 
