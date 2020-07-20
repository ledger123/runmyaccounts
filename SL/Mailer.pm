#=====================================================================
# Copyright (C) 2002
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# Original Author and copyright holder:
# Dieter Simader dsmimader@sql-ledger.com
#======================================================================
#
# This file has undergone whitespace cleanup.
#
#======================================================================
#
# mailer package
#
#======================================================================

package Mailer;

use Email::Stuffer;
use Email::Sender::Transport::SMTP ();

sub new {
  my ($type) = @_;
  my $self = {};

  bless $self, $type;
}

sub send {
  my ($self) = @_;

  $self->{contenttype} = "text/plain" unless $self->{contenttype};

  for (qw(from to cc bcc)) {
    $self->{$_} =~ s/\&lt;/</g;
    $self->{$_} =~ s/\&gt;/>/g;
    $self->{$_} =~ s/(\/|\\|\$)//g;
  }

  my $stuff = new Email::Stuffer;

  #$stuff->transport(Email::Sender::Transport::SMTP->new({ host => 'rt.mavsol.com', port => '25', }));

  $stuff->text_body($self->{message});
  $stuff->subject($self->{subject});
  $stuff->from($self->{from});
  $stuff->to($self->{to});
  $stuff->reply_to($self->{'reply-to'});
  $stuff->cc($self->{cc});
  $stuff->bcc($self->{bcc});

  if (@{$self->{attachments}}) {
    foreach my $attachment (@{$self->{attachments}}) {
      my $application = ($attachment =~ /(^\w+$)|\.(html|text|txt|sql)$/) ? "text" : "application";
      my $filename    = $attachment;
      my $type        = "$application/$self->{format}";
      $type .= '; charset="UTF-8"' if $application eq 'text';

      # strip path
      $filename =~ s/(.*\/|$self->{fileid})//g;
      $stuff->attach_file($attachment, filename => $filename);
    }
  }

  $stuff->send; 
  return "";
}

1;

