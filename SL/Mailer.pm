#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# mailer package
#
#======================================================================

package Mailer;

use POSIX;
use JSON::XS;
use MIME::Base64 ('encode_base64');
use File::Slurper ('read_binary');
use HTML::FromText;

sub new {
  my ($type) = @_;
  my $self = {};

  bless $self, $type;
}

sub apisend {
  my ($self) = @_;

  $self->{contenttype} = "text/plain" unless $self->{contenttype};

  for (qw(from to replyto cc bcc)) {
    $self->{$_} =~ s/\&lt;/</g;
    $self->{$_} =~ s/\&gt;/>/g;
    $self->{$_} =~ s/(\/|\\|\$)//g;
  }

  my $json = JSON::XS->new;
  my $data = {};

  $data->{sender}->{name} = $self->{fromname};
  $data->{sender}->{email} = $self->{from};

  if ($self->{replyto}){
     $data->{replyTo}->{name} = $self->{fromname};
     $data->{replyTo}->{email} = $self->{replyto};
  }

  $data->{to}->[0]->{name} = $self->{to};
  $data->{to}->[0]->{email} = $self->{to};

  if ($self->{cc}){
     $self->{cc} =~ tr/ //ds;
     @cc = split /,/, $self->{cc};
     my $i = 0;
     for (@cc){
        $data->{cc}->[$i]->{name} = $_;
        $data->{cc}->[$i]->{email} = $_;
        $i++;
     }
  }
  if ($self->{bcc}){
     $self->{bcc} =~ tr/ //ds;
     @bcc = split /,/, $self->{bcc};
     my $i = 0;
     for (@bcc){
        $data->{bcc}->[$i]->{name} = $_;
        $data->{bcc}->[$i]->{email} = $_;
        $i++;
     }
  }

  if (@{$self->{attachments}}) {
      my $i = 0;
      foreach my $attachment (@{$self->{attachments}}) {
          my $filename    = $attachment;
          $filename =~ s/(.*\/|$self->{fileid})//g;

          $raw_string = read_binary($attachment);
          $encoded = encode_base64( $raw_string );

          $data->{attachment}->[$i]->{name} = $filename;
          $data->{attachment}->[$i]->{content} = $encoded;

          $i++;
    }
  }

  $data->{subject} = $self->{subject};
  $self->{message} = '.' if !$self->{message}; #sendinblue api throws error on blank message text so stuffing '.'

  my $html_convert = HTML::FromText->new({
    lines      => 1,
});
  $data->{textContent} = $self->{message};
  $data->{htmlContent} = "<!DOCTYPE html><html>\n<body>\n".$html_convert->parse($self->{message})."</body>\n</html>";

  # open (FH, "> /tmp/email.html"); print FH "$data->{htmlContent}"; close(FH); # Dump email contents to temp file for inspection.

  my $jsonstr = $json->encode($data);

  use File::Temp qw(tempfile);
  my ($fh, $filename) = tempfile();
  binmode( $fh, ":utf8" );

  print $fh $jsonstr;
  close $fh;

  $commandline = q~
  curl -sS --request POST \
      --url https://api.sendinblue.com/v3/smtp/email \
      --header 'accept: application/json' \
      --header 'api-key:~.$self->{apikey}.q~' \
      --header 'content-type: application/json' \
      -d @~.$filename.q~ \
      > /tmp/apierror.txt
  ~;
  system(qq~$commandline~);
  unlink $filename;

  return "";
}


sub send {
  my ($self, $out) = @_;

  my $boundary = time;
  my $domain = $self->{from};
  $domain =~ s/(.*?\@|>)//g;
  my $msgid = "$boundary\@$domain";
  $boundary = "SL-$self->{version}-$boundary";
  
  $self->{charset} ||= "ISO-8859-1";
  
  if ($out) {
    open(OUT, $out) or return "$out : $!";
  } else {
    open(OUT, ">-") or return "STDOUT : $!";
  }

  $self->{contenttype} ||= "text/plain";
  
  my %h;
  for (qw(reply-to from to cc bcc)) {
    $self->{$_} =~ s/\&lt;/</g;
    $self->{$_} =~ s/\&gt;/>/g;
    $self->{$_} =~ s/(\/|\\|\$)//g;
    $self->{$_} =~ s/["]?(.*?)["]? (<.*>)/"=?$self->{charset}?B?".&encode_base64($1,"")."?= $2"/e
      if $self->{$_} =~ m/[\x00-\x1F]|[\x7B-\xFFFF]/;
    $h{$_} = $self->{$_};
  }
 
  $h{'reply-to'} = "Reply-to: $h{'reply-to'}\n" if $self->{'reply-to'};
  $h{cc} = "Cc: $h{cc}\n" if $self->{cc};
  $h{bcc} = "Bcc: $h{bcc}\n" if $self->{bcc};
  $h{subject} = ($self->{subject} =~ /([\x00-\x1F]|[\x7B-\xFFFF])/) ? "Subject: =?$self->{charset}?B?".&encode_base64($self->{subject},"")."?=" : "Subject: $self->{subject}";
    
  $now_string = strftime "%a, %d %b %Y %H:%M:%S %z", localtime;
  $h{date} = "Date: " . $now_string . "\n";
  
  if ($self->{notify}) {
    if ($self->{notify} =~ /\@/) {
      $h{notify} = "Disposition-Notification-To: $self->{notify}\n";
    } else {
      $h{notify} = "Disposition-Notification-To: $h{from}\n";
    }
  }
  
  print OUT qq|From: $h{from}
To: $h{to}
$h{date}$h{'reply-to'}$h{cc}$h{bcc}$h{subject}
Message-ID: <$msgid>
$h{notify}X-Mailer: Run my Accounts $self->{version}
MIME-Version: 1.0
|;


  if (@{ $self->{attachments} }) {
    print OUT qq|Content-Type: multipart/mixed; boundary="$boundary"

|;
    if ($self->{message} ne "") {
      print OUT qq|--${boundary}
Content-Type: $self->{contenttype}; charset="$self->{charset}"

$self->{message}

|;
    }

    foreach my $attachment (@{ $self->{attachments} }) {

      my $application = ($attachment =~ /(^\w+$)|\.(html|text|txt|sql)$/) ? "text" : "application";
      
      unless (open IN, $attachment) {
	close(OUT);
	return "$attachment : $!";
      }

      binmode(IN);
      
      my $filename = $attachment;
      # strip path
      $filename =~ s/(.*\/|$self->{fileid})//g;
      
      print OUT qq|--${boundary}
Content-Type: $application/$self->{format}; name="$filename"; charset="$self->{charset}"
Content-Transfer-Encoding: BASE64
Content-Disposition: attachment; filename="$filename"\n\n|;

      my $msg = "";
      while (<IN>) {;
        $msg .= $_;
      }
      print OUT &encode_base64($msg);

      close(IN);
      
    }
    print OUT qq|--${boundary}--\n|;

  } else {
    print OUT qq|Content-Type: $self->{contenttype}; charset="$self->{charset}"

$self->{message}
|;
  }

  close(OUT);

  return "";
  
}


sub encode_base64 ($;$) {

  # this code is from the MIME-Base64-2.12 package
  # Copyright 1995-1999,2001 Gisle Aas <gisle@ActiveState.com>

  my $res = "";
  my $eol = $_[1];
  $eol = "\n" unless defined $eol;
  pos($_[0]) = 0;                          # ensure start at the beginning

  $res = join '', map( pack('u',$_)=~ /^.(\S*)/, ($_[0]=~/(.{1,45})/gs));

  $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
  # fix padding at the end
  my $padding = (3 - length($_[0]) % 3) % 3;
  $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
  # break encoded string into lines of no more than 60 characters each
  if (length $eol) {
    $res =~ s/(.{1,60})/$1$eol/g;
  }
  return $res;
  
}


1;

