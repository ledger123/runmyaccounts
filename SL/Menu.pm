#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#=====================================================================
#
# routines for menu items
#
#=====================================================================

package Menu;

use SL::Inifile;
@ISA = qw/Inifile/;


sub menuitem {
  my ($self, $myconfig, $form, $item, $level, $i) = @_;

  my $module = ($self->{$item}{module}) ? $self->{$item}{module} : $form->{script};
  my $action = ($self->{$item}{action}) ? $self->{$item}{action} : "section_menu";
  my $target = ($self->{$item}{target}) ? $self->{$item}{target} : "";

  my $level = $form->escape($item);
  my $str = qq|<a id="menu$i" href=$module?path=$form->{path}&action=$action&level=$level&login=$form->{login}&js=$form->{js}|;
  $str .= "&dbname=$myconfig->{dbname}" if $str =~ /revolut/;

  my @vars = qw(module action target href);
  
  if ($self->{$item}{href}) {
    $str = qq|<a href=$self->{$item}{href}|;
    @vars = qw(module target href);
  }

  for (@vars) { delete $self->{$item}{$_} }
  
  delete $self->{$item}{submenu};
 
  # add other params
  foreach my $key (keys %{ $self->{$item} }) {
    $str .= "&".$form->escape($key)."=";
    ($value, $conf) = split /=/, $self->{$item}{$key}, 2;
    $value = "$myconfig->{$value}$conf" if $self->{$item}{$key} =~ /=/;
    
    $str .= $form->escape($value);
  }
  $str .= qq|#id$form->{tag}| if $target eq 'acc_menu';
  
  if ($target) {
    $str .= qq| target=$target|;
  }
  
  $str .= qq|>|;
  
}


sub access_control {
  my ($self, $myconfig, $menulevel) = @_;
  
  my @menu = ();

  if ($menulevel eq "") {
    @menu = grep { !/--/ } @{ $self->{ORDER} };
  } else {
    @menu = grep { /^${menulevel}--/; } @{ $self->{ORDER} };
  }

  my @a = split /;/, $myconfig->{acs};
  my $excl = ();

  # remove --AR, --AP from array
  grep { ($a, $b) = split /--/; s/--$a$//; } @a;

  for (@a) { $excl{$_} = 1 }

  @a = ();
  for (@menu) { push @a, $_ unless $excl{$_} }

  @a;

}


1;

