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

use JSON;
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();

sub new {
  my ($type) = @_;
  my $self = {};

  bless $self, $type;
}

sub send {
  my ($self) = @_;

  #----- CONFIGURATION
  my $tmpfolder = 'http://domain.net/ledger123/rma/users';
  my $apikey = 'xkeysib-ad3c502c031275016ba77259cbaad630f58431abfa6eb4938c56e62e7dc64591-UfY14WhVRGN';
  #----- CONFIG END

  $self->{contenttype} = "text/plain" unless $self->{contenttype};

  for (qw(from to cc bcc)) {
    $self->{$_} =~ s/\&lt;/</g;
    $self->{$_} =~ s/\&gt;/>/g;
    $self->{$_} =~ s/(\/|\\|\$)//g;
  }

  my $json = JSON->new->utf8;

  my $data = {};

  $data->{sender}->{name} = $self->{fromname};
  $data->{sender}->{email} = $self->{from};

  if ($self->{replyto}){
     $data->{replyTo}->{name} = $self->{replyto};
     $data->{replyTo}->{email} = $self->{replyto};
  }

  $data->{to}->[0]->{name} = $self->{to};
  $data->{to}->[0]->{email} = $self->{to};

  if ($self->{cc}){
     $data->{cc}->[0]->{name} = $self->{cc};
     $data->{cc}->[0]->{email} = $self->{cc};
  }

  if ($self->{bcc}){
     $data->{bcc}->[0]->{name} = $self->{bcc};
     $data->{bcc}->[0]->{email} = $self->{bcc};
  }

  if (@{$self->{attachments}}) {
      my $i = 0;
      foreach my $attachment (@{$self->{attachments}}) {
          my $filename    = $attachment;
          $filename =~ s/(.*\/|$self->{fileid})//g;

          $data->{attachment}->[$i]->{name} = $filename;
          $data->{attachment}->[$i]->{url} = "$tmpfolder/$attachment";

          $i++;
    }
  }

  $data->{subject} = $self->{subject};
  $data->{htmlContent} = $self->{message};

  my $jsonstr = $json->encode($data);

  $commandline = q~
  curl --request POST \
      --url https://api.sendinblue.com/v3/smtp/email \
      --header 'accept: application/json' \
      --header 'api-key:~.$apikey.q~' \
      --header 'content-type: application/json' \
      --data '~.$jsonstr.q~' \
  ~;

  #print $commandline;

  system("$commandline 2>&1 /dev/null");

  return "";
}


sub send2 {
  my ($self) = @_;

  $self->{contenttype} = "text/plain" unless $self->{contenttype};

  for (qw(from to cc bcc)) {
    $self->{$_} =~ s/\&lt;/</g;
    $self->{$_} =~ s/\&gt;/>/g;
    $self->{$_} =~ s/(\/|\\|\$)//g;
  }

  my $stuff = new Email::Stuffer;

  if ($self->{noreplyemail}){
      #if $noreplyemail is set, use an SMTP server
      $stuff->transport(Email::Sender::Transport::SMTP->new({ host => 'rt.mavsol.com', port => '25', }));
  }

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

