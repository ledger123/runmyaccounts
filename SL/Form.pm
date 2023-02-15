#=================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================

package Form;

use Date::Parse;
use Time::Piece;
use DBIx::Simple;

sub new {
	my $type = shift;

	my $self = {};

	read( STDIN, $_, $ENV{CONTENT_LENGTH} );

	if ( $ENV{QUERY_STRING} ) {
		$_ = $ENV{QUERY_STRING};
	}

	if ( $ARGV[0] ) {
		$_ = $ARGV[0];
	}

	my $maxlength     = 0;
	my $countofparams = 0;
	foreach my $part ( split /[&]/ ) {
		my ( $key, $value ) = split /=/, $part;
		$self->{$key} = $value;
		$countofparams++;

		if ( length($value) > $maxlength ) {
			$maxlength = length($value);
		}
	}

	my $esc = 1;

	# if multipart form take apart on boundary
	my ( $content, $boundary ) = split /; /, $ENV{CONTENT_TYPE};

	if ($boundary) {
		$esc   = 0;
		%$self = ();

		( $content, $boundary ) = split /=/, $boundary;
		my $var;

		@a = split /\r/, $_;

		foreach $line (@a) {
			$line =~ s/^\n//;

			last if $line =~ /${boundary}--/;
			next if $line =~ /${boundary}/;

			if ( $line =~ /^Content-Disposition: form-data;/ ) {
				my @b = split /; /, $line;
				my @c = split /=/,  $b[1];
				$c[1] =~ s/(^"|"$)//g;
				$var  = $c[1];
				$line = shift @a;
				shift @a if $line =~ /^Content-Type:/;

				$self->{$var} = "" if $var;
				next;
			}

			if ( $self->{$var} ) {
				$self->{$var} .= "\n$line";
			}
			else {
				$self->{$var} = $line;
			}
		}
	}

	if ($esc) {
		for ( keys %$self ) { $self->{$_} = unescape( "", $self->{$_} ) }
	}

	if ( substr( $self->{action}, 0, 1 ) !~ /( |\.)/ ) {
		$self->{action} = lc $self->{action};
		$self->{action} =~ s/( |-|,|\#|\/|\.$)/_/g;
	}

	$self->{menubar} = 1 if $self->{path} =~ /lynx/i;

	$self->{version}   = "2.8.33";
	$self->{dbversion} = "2.8.23";

	bless $self, $type;

}


sub countries {
    my ($self, $myconfig, $s_country, $is_bank) = @_;

    $countrycode = $myconfig->{countrycode};
    $countrycode = 'default' if !$countrycode;

	@chTranslations = qw(CH CHE SCHWEIZ SWITZERLAND);
	@atTranslations = qw(AT ÖSTERREICH AUSTRIA);
	@frTranslations = qw(FR FRANCE FRANKREICH);
	@usTranslations = ("US", "UNITED STATES", "VEREINIGTE STAATEN VON AMERICA", "VEREINIGTE STAATEN VON AMERIKA", "VEREINIGTE STAATEN");
	@ukTranslations = ("GB", "UK", "UNITED KINGDOM", "VEREINIGTES KÖNIGREICH", "GREAT BRITAIN", "GROSS BRITANNIEN");
	@deTranslations = qw(DE DEUTSCHLAND GERMANY);

    my $countries = { 
        rma_ch_de => {
			'Andorra' => 'AD',
			'Vereinigte Arabische Emirate' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua und Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albanien' => 'AL',
			'Armenien' => 'AM',
			'Angola' => 'AO',
			'Antarktis' => 'AQ',
			'Argentinien' => 'AR',
			'Amerikanisch Samoa' => 'AS',
			'Australien' => 'AU',
			'Aruba' => 'AW',
			'Åland' => 'AX',
			'Aserbaidschan' => 'AZ',
			'Bosnien und Herzegowina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesch' => 'BD',
			'Belgien' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgarien' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivien' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brasilien' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvetinsel' => 'BV',
			'Botswana' => 'BW',
			'Weissrussland' => 'BY',
			'Belize' => 'BZ',
			'Kanada' => 'CA',
			'Kokosinseln' => 'CC',
			'Demokratische Republik Kongo' => 'CD',
			'Zentralafrikanische Republik' => 'CF',
			'Kongo' => 'CG',
			'Elfenbeinküste' => 'CI',
			'Cookinseln' => 'CK',
			'Chile' => 'CL',
			'Kamerun' => 'CM',
			'Volksrepublik China' => 'CN',
			'Kolumbien' => 'CO',
			'Costa Rica' => 'CR',
			'Kuba' => 'CU',
			'Kap Verde' => 'CV',
			'Curaçao' => 'CW',
			'Weihnachtsinsel' => 'CX',
			'Zypern' => 'CY',
			'Tschechische Republik' => 'CZ',
			'Dschibuti' => 'DJ',
			'Dänemark' => 'DK',
			'Dominica' => 'DM',
			'Dominikanische Republik' => 'DO',
			'Algerien' => 'DZ',
			'Ecuador' => 'EC',
			'Estland' => 'EE',
			'Ägypten' => 'EG',
			'Westsahara' => 'EH',
			'Eritrea' => 'ER',
			'Spanien' => 'ES',
			'Äthiopien' => 'ET',
			'Finnland' => 'FI',
			'Fidschi' => 'FJ',
			'Falklandinseln' => 'FK',
			'Mikronesien' => 'FM',
			'Färöer-Inseln' => 'FO',
			'Gabun' => 'GA',
			'Grenada' => 'GD',
			'Georgien' => 'GE',
			'Französisch-Guayana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Grönland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Äquatorialguinea' => 'GQ',
			'Griechenland' => 'GR',
			'Südgeorgien und die Südlichen Sandwichinseln' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hongkong' => 'HK',
			'Heard und McDonaldinseln' => 'HM',
			'Honduras' => 'HN',
			'Kroatien' => 'HR',
			'Haiti' => 'HT',
			'Ungarn' => 'HU',
			'Indonesien' => 'ID',
			'Irland' => 'IE',
			'Israel' => 'IL',
			'Insel Man' => 'IM',
			'Indien' => 'IN',
			'Britisches Territorium im Indischen Ozean' => 'IO',
			'Irak' => 'IQ',
			'Iran' => 'IR',
			'Island' => 'IS',
			'Italien' => 'IT',
			'Jersey' => 'JE',
			'Jamaika' => 'JM',
			'Jordanien' => 'JO',
			'Japan' => 'JP',
			'Kenia' => 'KE',
			'Kirgisistan' => 'KG',
			'Kambodscha' => 'KH',
			'Kiribati' => 'KI',
			'Komoren' => 'KM',
			'St. Kitts und Nevis' => 'KN',
			'Nordkorea' => 'KP',
			'Südkorea' => 'KR',
			'Kuwait' => 'KW',
			'Kaimaninseln' => 'KY',
			'Kasachstan' => 'KZ',
			'Laos' => 'LA',
			'Libanon' => 'LB',
			'St. Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Litauen' => 'LT',
			'Luxemburg' => 'LU',
			'Lettland' => 'LV',
			'Libyen' => 'LY',
			'Marokko' => 'MA',
			'Fürstentum Monaco' => 'MC',
			'Moldau' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagaskar' => 'MG',
			'Marshallinseln' => 'MH',
			'Mazedonien' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolei' => 'MN',
			'Macau' => 'MO',
			'Nördliche Marianen' => 'MP',
			'Martinique' => 'MQ',
			'Mauretanien' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Malediven' => 'MV',
			'Malawi' => 'MW',
			'Mexiko' => 'MX',
			'Malaysia' => 'MY',
			'Mosambik' => 'MZ',
			'Namibia' => 'NA',
			'Neukaledonien' => 'NC',
			'Niger' => 'NE',
			'Norfolkinsel' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Niederlande' => 'NL',
			'Norwegen' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'Neuseeland' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'Französisch-Polynesien' => 'PF',
			'Papua-Neuguinea' => 'PG',
			'Philippinen' => 'PH',
			'Pakistan' => 'PK',
			'Polen' => 'PL',
			'St. Pierre und Miquelon' => 'PM',
			'Pitcairninseln' => 'PN',
			'Puerto Rico' => 'PR',
			'Palästina' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Katar' => 'QA',
			'Réunion' => 'RE',
			'Rumänien' => 'RO',
			'Serbien' => 'RS',
			'Russland' => 'RU',
			'Ruanda' => 'RW',
			'Saudi-Arabien' => 'SA',
			'Salomonen' => 'SB',
			'Seychellen' => 'SC',
			'Sudan' => 'SD',
			'Schweden' => 'SE',
			'Singapur' => 'SG',
			'St. Helena' => 'SH',
			'Slowenien' => 'SI',
			'Svalbard und Jan Mayen' => 'SJ',
			'Slowakei' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'Südsudan' => 'SS',
			'São Tomé und Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'St. Maarten' => 'SX',
			'Syrien' => 'SY',
			'Swasiland' => 'SZ',
			'Turks- und Caicosinseln' => 'TC',
			'Tschad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tadschikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunesien' => 'TN',
			'Tonga' => 'TO',
			'Türkei' => 'TR',
			'Trinidad und Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tansania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Usbekistan' => 'UZ',
			'Vatikanstadt' => 'VA',
			'St. Vincent und die Grenadinen' => 'VC',
			'Venezuela' => 'VE',
			'Jungferninseln (UK)' => 'VG',
			'Jungferninseln (US)' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis und Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Jemen' => 'YE',
			'Mayotte' => 'YT',
			'Südafrika' => 'ZA',
			'Sambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Schweiz' => \@chTranslations,
			'Vereinigtes Königreich' => \@ukTranslations,
			'Vereinigte Staaten von Amerika' => \@usTranslations,
			'Deutschland' => \@deTranslations,
			'Frankreich' => \@frTranslations,
			'Österreich' => \@atTranslations,
        },
		ch => {
			'Andorra' => 'AD',
			'Vereinigte Arabische Emirate' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua und Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albanien' => 'AL',
			'Armenien' => 'AM',
			'Angola' => 'AO',
			'Antarktis' => 'AQ',
			'Argentinien' => 'AR',
			'Amerikanisch Samoa' => 'AS',
			'Australien' => 'AU',
			'Aruba' => 'AW',
			'Åland' => 'AX',
			'Aserbaidschan' => 'AZ',
			'Bosnien und Herzegowina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesch' => 'BD',
			'Belgien' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgarien' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivien' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brasilien' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvetinsel' => 'BV',
			'Botswana' => 'BW',
			'Weissrussland' => 'BY',
			'Belize' => 'BZ',
			'Kanada' => 'CA',
			'Kokosinseln' => 'CC',
			'Demokratische Republik Kongo' => 'CD',
			'Zentralafrikanische Republik' => 'CF',
			'Kongo' => 'CG',
			'Elfenbeinküste' => 'CI',
			'Cookinseln' => 'CK',
			'Chile' => 'CL',
			'Kamerun' => 'CM',
			'Volksrepublik China' => 'CN',
			'Kolumbien' => 'CO',
			'Costa Rica' => 'CR',
			'Kuba' => 'CU',
			'Kap Verde' => 'CV',
			'Curaçao' => 'CW',
			'Weihnachtsinsel' => 'CX',
			'Zypern' => 'CY',
			'Tschechische Republik' => 'CZ',
			'Dschibuti' => 'DJ',
			'Dänemark' => 'DK',
			'Dominica' => 'DM',
			'Dominikanische Republik' => 'DO',
			'Algerien' => 'DZ',
			'Ecuador' => 'EC',
			'Estland' => 'EE',
			'Ägypten' => 'EG',
			'Westsahara' => 'EH',
			'Eritrea' => 'ER',
			'Spanien' => 'ES',
			'Äthiopien' => 'ET',
			'Finnland' => 'FI',
			'Fidschi' => 'FJ',
			'Falklandinseln' => 'FK',
			'Mikronesien' => 'FM',
			'Färöer-Inseln' => 'FO',
			'Gabun' => 'GA',
			'Grenada' => 'GD',
			'Georgien' => 'GE',
			'Französisch-Guayana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Grönland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Äquatorialguinea' => 'GQ',
			'Griechenland' => 'GR',
			'Südgeorgien und die Südlichen Sandwichinseln' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hongkong' => 'HK',
			'Heard und McDonaldinseln' => 'HM',
			'Honduras' => 'HN',
			'Kroatien' => 'HR',
			'Haiti' => 'HT',
			'Ungarn' => 'HU',
			'Indonesien' => 'ID',
			'Irland' => 'IE',
			'Israel' => 'IL',
			'Insel Man' => 'IM',
			'Indien' => 'IN',
			'Britisches Territorium im Indischen Ozean' => 'IO',
			'Irak' => 'IQ',
			'Iran' => 'IR',
			'Island' => 'IS',
			'Italien' => 'IT',
			'Jersey' => 'JE',
			'Jamaika' => 'JM',
			'Jordanien' => 'JO',
			'Japan' => 'JP',
			'Kenia' => 'KE',
			'Kirgisistan' => 'KG',
			'Kambodscha' => 'KH',
			'Kiribati' => 'KI',
			'Komoren' => 'KM',
			'St. Kitts und Nevis' => 'KN',
			'Nordkorea' => 'KP',
			'Südkorea' => 'KR',
			'Kuwait' => 'KW',
			'Kaimaninseln' => 'KY',
			'Kasachstan' => 'KZ',
			'Laos' => 'LA',
			'Libanon' => 'LB',
			'St. Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Litauen' => 'LT',
			'Luxemburg' => 'LU',
			'Lettland' => 'LV',
			'Libyen' => 'LY',
			'Marokko' => 'MA',
			'Fürstentum Monaco' => 'MC',
			'Moldau' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagaskar' => 'MG',
			'Marshallinseln' => 'MH',
			'Mazedonien' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolei' => 'MN',
			'Macau' => 'MO',
			'Nördliche Marianen' => 'MP',
			'Martinique' => 'MQ',
			'Mauretanien' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Malediven' => 'MV',
			'Malawi' => 'MW',
			'Mexiko' => 'MX',
			'Malaysia' => 'MY',
			'Mosambik' => 'MZ',
			'Namibia' => 'NA',
			'Neukaledonien' => 'NC',
			'Niger' => 'NE',
			'Norfolkinsel' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Niederlande' => 'NL',
			'Norwegen' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'Neuseeland' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'Französisch-Polynesien' => 'PF',
			'Papua-Neuguinea' => 'PG',
			'Philippinen' => 'PH',
			'Pakistan' => 'PK',
			'Polen' => 'PL',
			'St. Pierre und Miquelon' => 'PM',
			'Pitcairninseln' => 'PN',
			'Puerto Rico' => 'PR',
			'Palästina' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Katar' => 'QA',
			'Réunion' => 'RE',
			'Rumänien' => 'RO',
			'Serbien' => 'RS',
			'Russland' => 'RU',
			'Ruanda' => 'RW',
			'Saudi-Arabien' => 'SA',
			'Salomonen' => 'SB',
			'Seychellen' => 'SC',
			'Sudan' => 'SD',
			'Schweden' => 'SE',
			'Singapur' => 'SG',
			'St. Helena' => 'SH',
			'Slowenien' => 'SI',
			'Svalbard und Jan Mayen' => 'SJ',
			'Slowakei' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'Südsudan' => 'SS',
			'São Tomé und Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'St. Maarten' => 'SX',
			'Syrien' => 'SY',
			'Swasiland' => 'SZ',
			'Turks- und Caicosinseln' => 'TC',
			'Tschad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tadschikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunesien' => 'TN',
			'Tonga' => 'TO',
			'Türkei' => 'TR',
			'Trinidad und Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tansania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Usbekistan' => 'UZ',
			'Vatikanstadt' => 'VA',
			'St. Vincent und die Grenadinen' => 'VC',
			'Venezuela' => 'VE',
			'Jungferninseln (UK)' => 'VG',
			'Jungferninseln (US)' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis und Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Jemen' => 'YE',
			'Mayotte' => 'YT',
			'Südafrika' => 'ZA',
			'Sambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Schweiz' => \@chTranslations,
			'Vereinigtes Königreich' => \@ukTranslations,
			'Vereinigte Staaten von Amerika' => \@usTranslations,
			'Deutschland' => \@deTranslations,
			'Frankreich' => \@frTranslations,
			'Österreich' => \@atTranslations,
        },
		ch_utf => {
			'Andorra' => 'AD',
			'Vereinigte Arabische Emirate' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua und Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albanien' => 'AL',
			'Armenien' => 'AM',
			'Angola' => 'AO',
			'Antarktis' => 'AQ',
			'Argentinien' => 'AR',
			'Amerikanisch Samoa' => 'AS',
			'Australien' => 'AU',
			'Aruba' => 'AW',
			'Åland' => 'AX',
			'Aserbaidschan' => 'AZ',
			'Bosnien und Herzegowina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesch' => 'BD',
			'Belgien' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgarien' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivien' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brasilien' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvetinsel' => 'BV',
			'Botswana' => 'BW',
			'Weissrussland' => 'BY',
			'Belize' => 'BZ',
			'Kanada' => 'CA',
			'Kokosinseln' => 'CC',
			'Demokratische Republik Kongo' => 'CD',
			'Zentralafrikanische Republik' => 'CF',
			'Kongo' => 'CG',
			'Elfenbeinküste' => 'CI',
			'Cookinseln' => 'CK',
			'Chile' => 'CL',
			'Kamerun' => 'CM',
			'Volksrepublik China' => 'CN',
			'Kolumbien' => 'CO',
			'Costa Rica' => 'CR',
			'Kuba' => 'CU',
			'Kap Verde' => 'CV',
			'Curaçao' => 'CW',
			'Weihnachtsinsel' => 'CX',
			'Zypern' => 'CY',
			'Tschechische Republik' => 'CZ',
			'Dschibuti' => 'DJ',
			'Dänemark' => 'DK',
			'Dominica' => 'DM',
			'Dominikanische Republik' => 'DO',
			'Algerien' => 'DZ',
			'Ecuador' => 'EC',
			'Estland' => 'EE',
			'Ägypten' => 'EG',
			'Westsahara' => 'EH',
			'Eritrea' => 'ER',
			'Spanien' => 'ES',
			'Äthiopien' => 'ET',
			'Finnland' => 'FI',
			'Fidschi' => 'FJ',
			'Falklandinseln' => 'FK',
			'Mikronesien' => 'FM',
			'Färöer-Inseln' => 'FO',
			'Gabun' => 'GA',
			'Grenada' => 'GD',
			'Georgien' => 'GE',
			'Französisch-Guayana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Grönland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Äquatorialguinea' => 'GQ',
			'Griechenland' => 'GR',
			'Südgeorgien und die Südlichen Sandwichinseln' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hongkong' => 'HK',
			'Heard und McDonaldinseln' => 'HM',
			'Honduras' => 'HN',
			'Kroatien' => 'HR',
			'Haiti' => 'HT',
			'Ungarn' => 'HU',
			'Indonesien' => 'ID',
			'Irland' => 'IE',
			'Israel' => 'IL',
			'Insel Man' => 'IM',
			'Indien' => 'IN',
			'Britisches Territorium im Indischen Ozean' => 'IO',
			'Irak' => 'IQ',
			'Iran' => 'IR',
			'Island' => 'IS',
			'Italien' => 'IT',
			'Jersey' => 'JE',
			'Jamaika' => 'JM',
			'Jordanien' => 'JO',
			'Japan' => 'JP',
			'Kenia' => 'KE',
			'Kirgisistan' => 'KG',
			'Kambodscha' => 'KH',
			'Kiribati' => 'KI',
			'Komoren' => 'KM',
			'St. Kitts und Nevis' => 'KN',
			'Nordkorea' => 'KP',
			'Südkorea' => 'KR',
			'Kuwait' => 'KW',
			'Kaimaninseln' => 'KY',
			'Kasachstan' => 'KZ',
			'Laos' => 'LA',
			'Libanon' => 'LB',
			'St. Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Litauen' => 'LT',
			'Luxemburg' => 'LU',
			'Lettland' => 'LV',
			'Libyen' => 'LY',
			'Marokko' => 'MA',
			'Fürstentum Monaco' => 'MC',
			'Moldau' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagaskar' => 'MG',
			'Marshallinseln' => 'MH',
			'Mazedonien' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolei' => 'MN',
			'Macau' => 'MO',
			'Nördliche Marianen' => 'MP',
			'Martinique' => 'MQ',
			'Mauretanien' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Malediven' => 'MV',
			'Malawi' => 'MW',
			'Mexiko' => 'MX',
			'Malaysia' => 'MY',
			'Mosambik' => 'MZ',
			'Namibia' => 'NA',
			'Neukaledonien' => 'NC',
			'Niger' => 'NE',
			'Norfolkinsel' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Niederlande' => 'NL',
			'Norwegen' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'Neuseeland' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'Französisch-Polynesien' => 'PF',
			'Papua-Neuguinea' => 'PG',
			'Philippinen' => 'PH',
			'Pakistan' => 'PK',
			'Polen' => 'PL',
			'St. Pierre und Miquelon' => 'PM',
			'Pitcairninseln' => 'PN',
			'Puerto Rico' => 'PR',
			'Palästina' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Katar' => 'QA',
			'Réunion' => 'RE',
			'Rumänien' => 'RO',
			'Serbien' => 'RS',
			'Russland' => 'RU',
			'Ruanda' => 'RW',
			'Saudi-Arabien' => 'SA',
			'Salomonen' => 'SB',
			'Seychellen' => 'SC',
			'Sudan' => 'SD',
			'Schweden' => 'SE',
			'Singapur' => 'SG',
			'St. Helena' => 'SH',
			'Slowenien' => 'SI',
			'Svalbard und Jan Mayen' => 'SJ',
			'Slowakei' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'Südsudan' => 'SS',
			'São Tomé und Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'St. Maarten' => 'SX',
			'Syrien' => 'SY',
			'Swasiland' => 'SZ',
			'Turks- und Caicosinseln' => 'TC',
			'Tschad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tadschikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunesien' => 'TN',
			'Tonga' => 'TO',
			'Türkei' => 'TR',
			'Trinidad und Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tansania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Usbekistan' => 'UZ',
			'Vatikanstadt' => 'VA',
			'St. Vincent und die Grenadinen' => 'VC',
			'Venezuela' => 'VE',
			'Jungferninseln (UK)' => 'VG',
			'Jungferninseln (US)' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis und Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Jemen' => 'YE',
			'Mayotte' => 'YT',
			'Südafrika' => 'ZA',
			'Sambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Schweiz' => \@chTranslations,
			'Vereinigtes Königreich' => \@ukTranslations,
			'Vereinigte Staaten von Amerika' => \@usTranslations,
			'Deutschland' => \@deTranslations,
			'Frankreich' => \@frTranslations,
			'Österreich' => \@atTranslations,
        },
		chd_utf => {
			'Andorra' => 'AD',
			'Vereinigte Arabische Emirate' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua und Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albanien' => 'AL',
			'Armenien' => 'AM',
			'Angola' => 'AO',
			'Antarktis' => 'AQ',
			'Argentinien' => 'AR',
			'Amerikanisch Samoa' => 'AS',
			'Australien' => 'AU',
			'Aruba' => 'AW',
			'Åland' => 'AX',
			'Aserbaidschan' => 'AZ',
			'Bosnien und Herzegowina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesch' => 'BD',
			'Belgien' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgarien' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivien' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brasilien' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvetinsel' => 'BV',
			'Botswana' => 'BW',
			'Weissrussland' => 'BY',
			'Belize' => 'BZ',
			'Kanada' => 'CA',
			'Kokosinseln' => 'CC',
			'Demokratische Republik Kongo' => 'CD',
			'Zentralafrikanische Republik' => 'CF',
			'Kongo' => 'CG',
			'Elfenbeinküste' => 'CI',
			'Cookinseln' => 'CK',
			'Chile' => 'CL',
			'Kamerun' => 'CM',
			'Volksrepublik China' => 'CN',
			'Kolumbien' => 'CO',
			'Costa Rica' => 'CR',
			'Kuba' => 'CU',
			'Kap Verde' => 'CV',
			'Curaçao' => 'CW',
			'Weihnachtsinsel' => 'CX',
			'Zypern' => 'CY',
			'Tschechische Republik' => 'CZ',
			'Dschibuti' => 'DJ',
			'Dänemark' => 'DK',
			'Dominica' => 'DM',
			'Dominikanische Republik' => 'DO',
			'Algerien' => 'DZ',
			'Ecuador' => 'EC',
			'Estland' => 'EE',
			'Ägypten' => 'EG',
			'Westsahara' => 'EH',
			'Eritrea' => 'ER',
			'Spanien' => 'ES',
			'Äthiopien' => 'ET',
			'Finnland' => 'FI',
			'Fidschi' => 'FJ',
			'Falklandinseln' => 'FK',
			'Mikronesien' => 'FM',
			'Färöer-Inseln' => 'FO',
			'Gabun' => 'GA',
			'Grenada' => 'GD',
			'Georgien' => 'GE',
			'Französisch-Guayana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Grönland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Äquatorialguinea' => 'GQ',
			'Griechenland' => 'GR',
			'Südgeorgien und die Südlichen Sandwichinseln' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hongkong' => 'HK',
			'Heard und McDonaldinseln' => 'HM',
			'Honduras' => 'HN',
			'Kroatien' => 'HR',
			'Haiti' => 'HT',
			'Ungarn' => 'HU',
			'Indonesien' => 'ID',
			'Irland' => 'IE',
			'Israel' => 'IL',
			'Insel Man' => 'IM',
			'Indien' => 'IN',
			'Britisches Territorium im Indischen Ozean' => 'IO',
			'Irak' => 'IQ',
			'Iran' => 'IR',
			'Island' => 'IS',
			'Italien' => 'IT',
			'Jersey' => 'JE',
			'Jamaika' => 'JM',
			'Jordanien' => 'JO',
			'Japan' => 'JP',
			'Kenia' => 'KE',
			'Kirgisistan' => 'KG',
			'Kambodscha' => 'KH',
			'Kiribati' => 'KI',
			'Komoren' => 'KM',
			'St. Kitts und Nevis' => 'KN',
			'Nordkorea' => 'KP',
			'Südkorea' => 'KR',
			'Kuwait' => 'KW',
			'Kaimaninseln' => 'KY',
			'Kasachstan' => 'KZ',
			'Laos' => 'LA',
			'Libanon' => 'LB',
			'St. Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Litauen' => 'LT',
			'Luxemburg' => 'LU',
			'Lettland' => 'LV',
			'Libyen' => 'LY',
			'Marokko' => 'MA',
			'Fürstentum Monaco' => 'MC',
			'Moldau' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagaskar' => 'MG',
			'Marshallinseln' => 'MH',
			'Mazedonien' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolei' => 'MN',
			'Macau' => 'MO',
			'Nördliche Marianen' => 'MP',
			'Martinique' => 'MQ',
			'Mauretanien' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Malediven' => 'MV',
			'Malawi' => 'MW',
			'Mexiko' => 'MX',
			'Malaysia' => 'MY',
			'Mosambik' => 'MZ',
			'Namibia' => 'NA',
			'Neukaledonien' => 'NC',
			'Niger' => 'NE',
			'Norfolkinsel' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Niederlande' => 'NL',
			'Norwegen' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'Neuseeland' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'Französisch-Polynesien' => 'PF',
			'Papua-Neuguinea' => 'PG',
			'Philippinen' => 'PH',
			'Pakistan' => 'PK',
			'Polen' => 'PL',
			'St. Pierre und Miquelon' => 'PM',
			'Pitcairninseln' => 'PN',
			'Puerto Rico' => 'PR',
			'Palästina' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Katar' => 'QA',
			'Réunion' => 'RE',
			'Rumänien' => 'RO',
			'Serbien' => 'RS',
			'Russland' => 'RU',
			'Ruanda' => 'RW',
			'Saudi-Arabien' => 'SA',
			'Salomonen' => 'SB',
			'Seychellen' => 'SC',
			'Sudan' => 'SD',
			'Schweden' => 'SE',
			'Singapur' => 'SG',
			'St. Helena' => 'SH',
			'Slowenien' => 'SI',
			'Svalbard und Jan Mayen' => 'SJ',
			'Slowakei' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'Südsudan' => 'SS',
			'São Tomé und Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'St. Maarten' => 'SX',
			'Syrien' => 'SY',
			'Swasiland' => 'SZ',
			'Turks- und Caicosinseln' => 'TC',
			'Tschad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tadschikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunesien' => 'TN',
			'Tonga' => 'TO',
			'Türkei' => 'TR',
			'Trinidad und Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tansania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Usbekistan' => 'UZ',
			'Vatikanstadt' => 'VA',
			'St. Vincent und die Grenadinen' => 'VC',
			'Venezuela' => 'VE',
			'Jungferninseln (UK)' => 'VG',
			'Jungferninseln (US)' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis und Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Jemen' => 'YE',
			'Mayotte' => 'YT',
			'Südafrika' => 'ZA',
			'Sambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Schweiz' => \@chTranslations,
			'Vereinigtes Königreich' => \@ukTranslations,
			'Vereinigte Staaten von Amerika' => \@usTranslations,
			'Deutschland' => \@deTranslations,
			'Frankreich' => \@frTranslations,
			'Österreich' => \@atTranslations,
        },
		de => {
			'Andorra' => 'AD',
			'Vereinigte Arabische Emirate' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua und Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albanien' => 'AL',
			'Armenien' => 'AM',
			'Angola' => 'AO',
			'Antarktis' => 'AQ',
			'Argentinien' => 'AR',
			'Amerikanisch Samoa' => 'AS',
			'Australien' => 'AU',
			'Aruba' => 'AW',
			'Åland' => 'AX',
			'Aserbaidschan' => 'AZ',
			'Bosnien und Herzegowina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesch' => 'BD',
			'Belgien' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgarien' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivien' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brasilien' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvetinsel' => 'BV',
			'Botswana' => 'BW',
			'Weissrussland' => 'BY',
			'Belize' => 'BZ',
			'Kanada' => 'CA',
			'Kokosinseln' => 'CC',
			'Demokratische Republik Kongo' => 'CD',
			'Zentralafrikanische Republik' => 'CF',
			'Kongo' => 'CG',
			'Elfenbeinküste' => 'CI',
			'Cookinseln' => 'CK',
			'Chile' => 'CL',
			'Kamerun' => 'CM',
			'Volksrepublik China' => 'CN',
			'Kolumbien' => 'CO',
			'Costa Rica' => 'CR',
			'Kuba' => 'CU',
			'Kap Verde' => 'CV',
			'Curaçao' => 'CW',
			'Weihnachtsinsel' => 'CX',
			'Zypern' => 'CY',
			'Tschechische Republik' => 'CZ',
			'Dschibuti' => 'DJ',
			'Dänemark' => 'DK',
			'Dominica' => 'DM',
			'Dominikanische Republik' => 'DO',
			'Algerien' => 'DZ',
			'Ecuador' => 'EC',
			'Estland' => 'EE',
			'Ägypten' => 'EG',
			'Westsahara' => 'EH',
			'Eritrea' => 'ER',
			'Spanien' => 'ES',
			'Äthiopien' => 'ET',
			'Finnland' => 'FI',
			'Fidschi' => 'FJ',
			'Falklandinseln' => 'FK',
			'Mikronesien' => 'FM',
			'Färöer-Inseln' => 'FO',
			'Gabun' => 'GA',
			'Grenada' => 'GD',
			'Georgien' => 'GE',
			'Französisch-Guayana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Grönland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Äquatorialguinea' => 'GQ',
			'Griechenland' => 'GR',
			'Südgeorgien und die Südlichen Sandwichinseln' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hongkong' => 'HK',
			'Heard und McDonaldinseln' => 'HM',
			'Honduras' => 'HN',
			'Kroatien' => 'HR',
			'Haiti' => 'HT',
			'Ungarn' => 'HU',
			'Indonesien' => 'ID',
			'Irland' => 'IE',
			'Israel' => 'IL',
			'Insel Man' => 'IM',
			'Indien' => 'IN',
			'Britisches Territorium im Indischen Ozean' => 'IO',
			'Irak' => 'IQ',
			'Iran' => 'IR',
			'Island' => 'IS',
			'Italien' => 'IT',
			'Jersey' => 'JE',
			'Jamaika' => 'JM',
			'Jordanien' => 'JO',
			'Japan' => 'JP',
			'Kenia' => 'KE',
			'Kirgisistan' => 'KG',
			'Kambodscha' => 'KH',
			'Kiribati' => 'KI',
			'Komoren' => 'KM',
			'St. Kitts und Nevis' => 'KN',
			'Nordkorea' => 'KP',
			'Südkorea' => 'KR',
			'Kuwait' => 'KW',
			'Kaimaninseln' => 'KY',
			'Kasachstan' => 'KZ',
			'Laos' => 'LA',
			'Libanon' => 'LB',
			'St. Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Litauen' => 'LT',
			'Luxemburg' => 'LU',
			'Lettland' => 'LV',
			'Libyen' => 'LY',
			'Marokko' => 'MA',
			'Fürstentum Monaco' => 'MC',
			'Moldau' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagaskar' => 'MG',
			'Marshallinseln' => 'MH',
			'Mazedonien' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolei' => 'MN',
			'Macau' => 'MO',
			'Nördliche Marianen' => 'MP',
			'Martinique' => 'MQ',
			'Mauretanien' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Malediven' => 'MV',
			'Malawi' => 'MW',
			'Mexiko' => 'MX',
			'Malaysia' => 'MY',
			'Mosambik' => 'MZ',
			'Namibia' => 'NA',
			'Neukaledonien' => 'NC',
			'Niger' => 'NE',
			'Norfolkinsel' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Niederlande' => 'NL',
			'Norwegen' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'Neuseeland' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'Französisch-Polynesien' => 'PF',
			'Papua-Neuguinea' => 'PG',
			'Philippinen' => 'PH',
			'Pakistan' => 'PK',
			'Polen' => 'PL',
			'St. Pierre und Miquelon' => 'PM',
			'Pitcairninseln' => 'PN',
			'Puerto Rico' => 'PR',
			'Palästina' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Katar' => 'QA',
			'Réunion' => 'RE',
			'Rumänien' => 'RO',
			'Serbien' => 'RS',
			'Russland' => 'RU',
			'Ruanda' => 'RW',
			'Saudi-Arabien' => 'SA',
			'Salomonen' => 'SB',
			'Seychellen' => 'SC',
			'Sudan' => 'SD',
			'Schweden' => 'SE',
			'Singapur' => 'SG',
			'St. Helena' => 'SH',
			'Slowenien' => 'SI',
			'Svalbard und Jan Mayen' => 'SJ',
			'Slowakei' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'Südsudan' => 'SS',
			'São Tomé und Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'St. Maarten' => 'SX',
			'Syrien' => 'SY',
			'Swasiland' => 'SZ',
			'Turks- und Caicosinseln' => 'TC',
			'Tschad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tadschikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunesien' => 'TN',
			'Tonga' => 'TO',
			'Türkei' => 'TR',
			'Trinidad und Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tansania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Usbekistan' => 'UZ',
			'Vatikanstadt' => 'VA',
			'St. Vincent und die Grenadinen' => 'VC',
			'Venezuela' => 'VE',
			'Jungferninseln (UK)' => 'VG',
			'Jungferninseln (US)' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis und Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Jemen' => 'YE',
			'Mayotte' => 'YT',
			'Südafrika' => 'ZA',
			'Sambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Schweiz' => \@chTranslations,
			'Vereinigtes Königreich' => \@ukTranslations,
			'Vereinigte Staaten von Amerika' => \@usTranslations,
			'Deutschland' => \@deTranslations,
			'Frankreich' => \@frTranslations,
			'Österreich' => \@atTranslations,
        },
		de_utf => {
			'Andorra' => 'AD',
			'Vereinigte Arabische Emirate' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua und Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albanien' => 'AL',
			'Armenien' => 'AM',
			'Angola' => 'AO',
			'Antarktis' => 'AQ',
			'Argentinien' => 'AR',
			'Amerikanisch Samoa' => 'AS',
			'Australien' => 'AU',
			'Aruba' => 'AW',
			'Åland' => 'AX',
			'Aserbaidschan' => 'AZ',
			'Bosnien und Herzegowina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesch' => 'BD',
			'Belgien' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgarien' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivien' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brasilien' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvetinsel' => 'BV',
			'Botswana' => 'BW',
			'Weissrussland' => 'BY',
			'Belize' => 'BZ',
			'Kanada' => 'CA',
			'Kokosinseln' => 'CC',
			'Demokratische Republik Kongo' => 'CD',
			'Zentralafrikanische Republik' => 'CF',
			'Kongo' => 'CG',
			'Elfenbeinküste' => 'CI',
			'Cookinseln' => 'CK',
			'Chile' => 'CL',
			'Kamerun' => 'CM',
			'Volksrepublik China' => 'CN',
			'Kolumbien' => 'CO',
			'Costa Rica' => 'CR',
			'Kuba' => 'CU',
			'Kap Verde' => 'CV',
			'Curaçao' => 'CW',
			'Weihnachtsinsel' => 'CX',
			'Zypern' => 'CY',
			'Tschechische Republik' => 'CZ',
			'Dschibuti' => 'DJ',
			'Dänemark' => 'DK',
			'Dominica' => 'DM',
			'Dominikanische Republik' => 'DO',
			'Algerien' => 'DZ',
			'Ecuador' => 'EC',
			'Estland' => 'EE',
			'Ägypten' => 'EG',
			'Westsahara' => 'EH',
			'Eritrea' => 'ER',
			'Spanien' => 'ES',
			'Äthiopien' => 'ET',
			'Finnland' => 'FI',
			'Fidschi' => 'FJ',
			'Falklandinseln' => 'FK',
			'Mikronesien' => 'FM',
			'Färöer-Inseln' => 'FO',
			'Gabun' => 'GA',
			'Grenada' => 'GD',
			'Georgien' => 'GE',
			'Französisch-Guayana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Grönland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Äquatorialguinea' => 'GQ',
			'Griechenland' => 'GR',
			'Südgeorgien und die Südlichen Sandwichinseln' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hongkong' => 'HK',
			'Heard und McDonaldinseln' => 'HM',
			'Honduras' => 'HN',
			'Kroatien' => 'HR',
			'Haiti' => 'HT',
			'Ungarn' => 'HU',
			'Indonesien' => 'ID',
			'Irland' => 'IE',
			'Israel' => 'IL',
			'Insel Man' => 'IM',
			'Indien' => 'IN',
			'Britisches Territorium im Indischen Ozean' => 'IO',
			'Irak' => 'IQ',
			'Iran' => 'IR',
			'Island' => 'IS',
			'Italien' => 'IT',
			'Jersey' => 'JE',
			'Jamaika' => 'JM',
			'Jordanien' => 'JO',
			'Japan' => 'JP',
			'Kenia' => 'KE',
			'Kirgisistan' => 'KG',
			'Kambodscha' => 'KH',
			'Kiribati' => 'KI',
			'Komoren' => 'KM',
			'St. Kitts und Nevis' => 'KN',
			'Nordkorea' => 'KP',
			'Südkorea' => 'KR',
			'Kuwait' => 'KW',
			'Kaimaninseln' => 'KY',
			'Kasachstan' => 'KZ',
			'Laos' => 'LA',
			'Libanon' => 'LB',
			'St. Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Litauen' => 'LT',
			'Luxemburg' => 'LU',
			'Lettland' => 'LV',
			'Libyen' => 'LY',
			'Marokko' => 'MA',
			'Fürstentum Monaco' => 'MC',
			'Moldau' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagaskar' => 'MG',
			'Marshallinseln' => 'MH',
			'Mazedonien' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolei' => 'MN',
			'Macau' => 'MO',
			'Nördliche Marianen' => 'MP',
			'Martinique' => 'MQ',
			'Mauretanien' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Malediven' => 'MV',
			'Malawi' => 'MW',
			'Mexiko' => 'MX',
			'Malaysia' => 'MY',
			'Mosambik' => 'MZ',
			'Namibia' => 'NA',
			'Neukaledonien' => 'NC',
			'Niger' => 'NE',
			'Norfolkinsel' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Niederlande' => 'NL',
			'Norwegen' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'Neuseeland' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'Französisch-Polynesien' => 'PF',
			'Papua-Neuguinea' => 'PG',
			'Philippinen' => 'PH',
			'Pakistan' => 'PK',
			'Polen' => 'PL',
			'St. Pierre und Miquelon' => 'PM',
			'Pitcairninseln' => 'PN',
			'Puerto Rico' => 'PR',
			'Palästina' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Katar' => 'QA',
			'Réunion' => 'RE',
			'Rumänien' => 'RO',
			'Serbien' => 'RS',
			'Russland' => 'RU',
			'Ruanda' => 'RW',
			'Saudi-Arabien' => 'SA',
			'Salomonen' => 'SB',
			'Seychellen' => 'SC',
			'Sudan' => 'SD',
			'Schweden' => 'SE',
			'Singapur' => 'SG',
			'St. Helena' => 'SH',
			'Slowenien' => 'SI',
			'Svalbard und Jan Mayen' => 'SJ',
			'Slowakei' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'Südsudan' => 'SS',
			'São Tomé und Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'St. Maarten' => 'SX',
			'Syrien' => 'SY',
			'Swasiland' => 'SZ',
			'Turks- und Caicosinseln' => 'TC',
			'Tschad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tadschikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunesien' => 'TN',
			'Tonga' => 'TO',
			'Türkei' => 'TR',
			'Trinidad und Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tansania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Usbekistan' => 'UZ',
			'Vatikanstadt' => 'VA',
			'St. Vincent und die Grenadinen' => 'VC',
			'Venezuela' => 'VE',
			'Jungferninseln (UK)' => 'VG',
			'Jungferninseln (US)' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis und Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Jemen' => 'YE',
			'Mayotte' => 'YT',
			'Südafrika' => 'ZA',
			'Sambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Schweiz' => \@chTranslations,
			'Vereinigtes Königreich' => \@ukTranslations,
			'Vereinigte Staaten von Amerika' => \@usTranslations,
			'Deutschland' => \@deTranslations,
			'Frankreich' => \@frTranslations,
			'Österreich' => \@atTranslations,
        },
		en_GB => {
			'Andorra' => 'AD',
			'United Arab Emirates' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua and Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albania' => 'AL',
			'Armenia' => 'AM',
			'Angola' => 'AO',
			'Antarctica' => 'AQ',
			'Argentina' => 'AR',
			'American Samoa' => 'AS',
			'Australia' => 'AU',
			'Aruba' => 'AW',
			'Åland Islands' => 'AX',
			'Azerbaijan' => 'AZ',
			'Bosnia and Herzegovina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesh' => 'BD',
			'Belgium' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgaria' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivia' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brazil' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvet Island' => 'BV',
			'Botswana' => 'BW',
			'Belarus' => 'BY',
			'Belize' => 'BZ',
			'Canada' => 'CA',
			'Cocos (Keeling) Islands' => 'CC',
			'DR Congo' => 'CD',
			'Central African Republic' => 'CF',
			'Republic of the Congo' => 'CG',
			'Ivory Coast' => 'CI',
			'Cook Islands' => 'CK',
			'Chile' => 'CL',
			'Cameroon' => 'CM',
			'China' => 'CN',
			'Colombia' => 'CO',
			'Costa Rica' => 'CR',
			'Cuba' => 'CU',
			'Cape Verde' => 'CV',
			'Curaçao' => 'CW',
			'Christmas Island' => 'CX',
			'Cyprus' => 'CY',
			'Czechia' => 'CZ',
			'Djibouti' => 'DJ',
			'Denmark' => 'DK',
			'Dominica' => 'DM',
			'Dominican Republic' => 'DO',
			'Algeria' => 'DZ',
			'Ecuador' => 'EC',
			'Estonia' => 'EE',
			'Egypt' => 'EG',
			'Western Sahara' => 'EH',
			'Eritrea' => 'ER',
			'Spain' => 'ES',
			'Ethiopia' => 'ET',
			'Finland' => 'FI',
			'Fiji' => 'FJ',
			'Falkland Islands' => 'FK',
			'Micronesia' => 'FM',
			'Faroe Islands' => 'FO',
			'Gabon' => 'GA',
			'Grenada' => 'GD',
			'Georgia' => 'GE',
			'French Guiana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Greenland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Equatorial Guinea' => 'GQ',
			'Greece' => 'GR',
			'South Georgia' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hong Kong' => 'HK',
			'Heard Island and McDonald Islands' => 'HM',
			'Honduras' => 'HN',
			'Croatia' => 'HR',
			'Haiti' => 'HT',
			'Hungary' => 'HU',
			'Indonesia' => 'ID',
			'Ireland' => 'IE',
			'Israel' => 'IL',
			'Isle of Man' => 'IM',
			'India' => 'IN',
			'British Indian Ocean Territory' => 'IO',
			'Iraq' => 'IQ',
			'Iran' => 'IR',
			'Iceland' => 'IS',
			'Italy' => 'IT',
			'Jersey' => 'JE',
			'Jamaica' => 'JM',
			'Jordan' => 'JO',
			'Japan' => 'JP',
			'Kenya' => 'KE',
			'Kyrgyzstan' => 'KG',
			'Cambodia' => 'KH',
			'Kiribati' => 'KI',
			'Comoros' => 'KM',
			'Saint Kitts and Nevis' => 'KN',
			'North Korea' => 'KP',
			'South Korea' => 'KR',
			'Kuwait' => 'KW',
			'Cayman Islands' => 'KY',
			'Kazakhstan' => 'KZ',
			'Laos' => 'LA',
			'Lebanon' => 'LB',
			'Saint Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Lithuania' => 'LT',
			'Luxembourg' => 'LU',
			'Latvia' => 'LV',
			'Libya' => 'LY',
			'Morocco' => 'MA',
			'Monaco' => 'MC',
			'Moldova' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagascar' => 'MG',
			'Marshall Islands' => 'MH',
			'North Macedonia' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolia' => 'MN',
			'Macau' => 'MO',
			'Northern Mariana Islands' => 'MP',
			'Martinique' => 'MQ',
			'Mauritania' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Maldives' => 'MV',
			'Malawi' => 'MW',
			'Mexico' => 'MX',
			'Malaysia' => 'MY',
			'Mozambique' => 'MZ',
			'Namibia' => 'NA',
			'New Caledonia' => 'NC',
			'Niger' => 'NE',
			'Norfolk Island' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Netherlands' => 'NL',
			'Norway' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'New Zealand' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'French Polynesia' => 'PF',
			'Papua New Guinea' => 'PG',
			'Philippines' => 'PH',
			'Pakistan' => 'PK',
			'Poland' => 'PL',
			'Saint Pierre and Miquelon' => 'PM',
			'Pitcairn Islands' => 'PN',
			'Puerto Rico' => 'PR',
			'Palestine' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Qatar' => 'QA',
			'Réunion' => 'RE',
			'Romania' => 'RO',
			'Serbia' => 'RS',
			'Russia' => 'RU',
			'Rwanda' => 'RW',
			'Saudi Arabia' => 'SA',
			'Solomon Islands' => 'SB',
			'Seychelles' => 'SC',
			'Sudan' => 'SD',
			'Sweden' => 'SE',
			'Singapore' => 'SG',
			'Saint Helena, Ascension and Tristan da Cunha' => 'SH',
			'Slovenia' => 'SI',
			'Svalbard and Jan Mayen' => 'SJ',
			'Slovakia' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'South Sudan' => 'SS',
			'São Tomé and Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'Sint Maarten' => 'SX',
			'Syria' => 'SY',
			'Eswatini' => 'SZ',
			'Turks and Caicos Islands' => 'TC',
			'Chad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tajikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunisia' => 'TN',
			'Tonga' => 'TO',
			'Turkey' => 'TR',
			'Trinidad and Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tanzania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Uzbekistan' => 'UZ',
			'Vatican City' => 'VA',
			'Saint Vincent and the Grenadines' => 'VC',
			'Venezuela' => 'VE',
			'British Virgin Islands' => 'VG',
			'United States Virgin Islands' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis and Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Yemen' => 'YE',
			'Mayotte' => 'YT',
			'South Africa' => 'ZA',
			'Zambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Switzerland' => \@chTranslations,
			'United Kingdom' => \@ukTranslations,
			'United States' => \@usTranslations,
			'Germany' => \@deTranslations,
			'France' => \@frTranslations,
			'Austria' => \@atTranslations,
		},
		ca_en => {
			'Andorra' => 'AD',
			'United Arab Emirates' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua and Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albania' => 'AL',
			'Armenia' => 'AM',
			'Angola' => 'AO',
			'Antarctica' => 'AQ',
			'Argentina' => 'AR',
			'American Samoa' => 'AS',
			'Australia' => 'AU',
			'Aruba' => 'AW',
			'Åland Islands' => 'AX',
			'Azerbaijan' => 'AZ',
			'Bosnia and Herzegovina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesh' => 'BD',
			'Belgium' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgaria' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivia' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brazil' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvet Island' => 'BV',
			'Botswana' => 'BW',
			'Belarus' => 'BY',
			'Belize' => 'BZ',
			'Canada' => 'CA',
			'Cocos (Keeling) Islands' => 'CC',
			'DR Congo' => 'CD',
			'Central African Republic' => 'CF',
			'Republic of the Congo' => 'CG',
			'Ivory Coast' => 'CI',
			'Cook Islands' => 'CK',
			'Chile' => 'CL',
			'Cameroon' => 'CM',
			'China' => 'CN',
			'Colombia' => 'CO',
			'Costa Rica' => 'CR',
			'Cuba' => 'CU',
			'Cape Verde' => 'CV',
			'Curaçao' => 'CW',
			'Christmas Island' => 'CX',
			'Cyprus' => 'CY',
			'Czechia' => 'CZ',
			'Djibouti' => 'DJ',
			'Denmark' => 'DK',
			'Dominica' => 'DM',
			'Dominican Republic' => 'DO',
			'Algeria' => 'DZ',
			'Ecuador' => 'EC',
			'Estonia' => 'EE',
			'Egypt' => 'EG',
			'Western Sahara' => 'EH',
			'Eritrea' => 'ER',
			'Spain' => 'ES',
			'Ethiopia' => 'ET',
			'Finland' => 'FI',
			'Fiji' => 'FJ',
			'Falkland Islands' => 'FK',
			'Micronesia' => 'FM',
			'Faroe Islands' => 'FO',
			'Gabon' => 'GA',
			'Grenada' => 'GD',
			'Georgia' => 'GE',
			'French Guiana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Greenland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Equatorial Guinea' => 'GQ',
			'Greece' => 'GR',
			'South Georgia' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hong Kong' => 'HK',
			'Heard Island and McDonald Islands' => 'HM',
			'Honduras' => 'HN',
			'Croatia' => 'HR',
			'Haiti' => 'HT',
			'Hungary' => 'HU',
			'Indonesia' => 'ID',
			'Ireland' => 'IE',
			'Israel' => 'IL',
			'Isle of Man' => 'IM',
			'India' => 'IN',
			'British Indian Ocean Territory' => 'IO',
			'Iraq' => 'IQ',
			'Iran' => 'IR',
			'Iceland' => 'IS',
			'Italy' => 'IT',
			'Jersey' => 'JE',
			'Jamaica' => 'JM',
			'Jordan' => 'JO',
			'Japan' => 'JP',
			'Kenya' => 'KE',
			'Kyrgyzstan' => 'KG',
			'Cambodia' => 'KH',
			'Kiribati' => 'KI',
			'Comoros' => 'KM',
			'Saint Kitts and Nevis' => 'KN',
			'North Korea' => 'KP',
			'South Korea' => 'KR',
			'Kuwait' => 'KW',
			'Cayman Islands' => 'KY',
			'Kazakhstan' => 'KZ',
			'Laos' => 'LA',
			'Lebanon' => 'LB',
			'Saint Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Lithuania' => 'LT',
			'Luxembourg' => 'LU',
			'Latvia' => 'LV',
			'Libya' => 'LY',
			'Morocco' => 'MA',
			'Monaco' => 'MC',
			'Moldova' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagascar' => 'MG',
			'Marshall Islands' => 'MH',
			'North Macedonia' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolia' => 'MN',
			'Macau' => 'MO',
			'Northern Mariana Islands' => 'MP',
			'Martinique' => 'MQ',
			'Mauritania' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Maldives' => 'MV',
			'Malawi' => 'MW',
			'Mexico' => 'MX',
			'Malaysia' => 'MY',
			'Mozambique' => 'MZ',
			'Namibia' => 'NA',
			'New Caledonia' => 'NC',
			'Niger' => 'NE',
			'Norfolk Island' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Netherlands' => 'NL',
			'Norway' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'New Zealand' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'French Polynesia' => 'PF',
			'Papua New Guinea' => 'PG',
			'Philippines' => 'PH',
			'Pakistan' => 'PK',
			'Poland' => 'PL',
			'Saint Pierre and Miquelon' => 'PM',
			'Pitcairn Islands' => 'PN',
			'Puerto Rico' => 'PR',
			'Palestine' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Qatar' => 'QA',
			'Réunion' => 'RE',
			'Romania' => 'RO',
			'Serbia' => 'RS',
			'Russia' => 'RU',
			'Rwanda' => 'RW',
			'Saudi Arabia' => 'SA',
			'Solomon Islands' => 'SB',
			'Seychelles' => 'SC',
			'Sudan' => 'SD',
			'Sweden' => 'SE',
			'Singapore' => 'SG',
			'Saint Helena, Ascension and Tristan da Cunha' => 'SH',
			'Slovenia' => 'SI',
			'Svalbard and Jan Mayen' => 'SJ',
			'Slovakia' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'South Sudan' => 'SS',
			'São Tomé and Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'Sint Maarten' => 'SX',
			'Syria' => 'SY',
			'Eswatini' => 'SZ',
			'Turks and Caicos Islands' => 'TC',
			'Chad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tajikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunisia' => 'TN',
			'Tonga' => 'TO',
			'Turkey' => 'TR',
			'Trinidad and Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tanzania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Uzbekistan' => 'UZ',
			'Vatican City' => 'VA',
			'Saint Vincent and the Grenadines' => 'VC',
			'Venezuela' => 'VE',
			'British Virgin Islands' => 'VG',
			'United States Virgin Islands' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis and Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Yemen' => 'YE',
			'Mayotte' => 'YT',
			'South Africa' => 'ZA',
			'Zambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Switzerland' => \@chTranslations,
			'United Kingdom' => \@ukTranslations,
			'United States' => \@usTranslations,
			'Germany' => \@deTranslations,
			'France' => \@frTranslations,
			'Austria' => \@atTranslations,
		},
		fr => {
			'Andorre' => 'AD',
			'Émirats arabes unis' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua-et-Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albanie' => 'AL',
			'Arménie' => 'AM',
			'Angola' => 'AO',
			'Antarctique' => 'AQ',
			'Argentine' => 'AR',
			'Samoa américaines' => 'AS',
			'Australie' => 'AU',
			'Aruba' => 'AW',
			'Ahvenanmaa' => 'AX',
			'Azerbaïdjan' => 'AZ',
			'Bosnie-Herzégovine' => 'BA',
			'Barbade' => 'BB',
			'Bangladesh' => 'BD',
			'Belgique' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgarie' => 'BG',
			'Bahreïn' => 'BH',
			'Burundi' => 'BI',
			'Bénin' => 'BJ',
			'Saint-Barthélemy' => 'BL',
			'Bermudes' => 'BM',
			'Brunei' => 'BN',
			'Bolivie' => 'BO',
			'Pays-Bas caribéens' => 'BQ',
			'Brésil' => 'BR',
			'Bahamas' => 'BS',
			'Bhoutan' => 'BT',
			'Île Bouvet' => 'BV',
			'Botswana' => 'BW',
			'Biélorussie' => 'BY',
			'Belize' => 'BZ',
			'Canada' => 'CA',
			'Îles Cocos' => 'CC',
			'Congo (Rép. dém.)' => 'CD',
			'République centrafricaine' => 'CF',
			'Congo' => 'CG',
			'Côte d\'Ivoire' => 'CI',
			'Îles Cook' => 'CK',
			'Chili' => 'CL',
			'Cameroun' => 'CM',
			'Chine' => 'CN',
			'Colombie' => 'CO',
			'Costa Rica' => 'CR',
			'Cuba' => 'CU',
			'Îles du Cap-Vert' => 'CV',
			'Curaçao' => 'CW',
			'Île Christmas' => 'CX',
			'Chypre' => 'CY',
			'Tchéquie' => 'CZ',
			'Djibouti' => 'DJ',
			'Danemark' => 'DK',
			'Dominique' => 'DM',
			'République dominicaine' => 'DO',
			'Algérie' => 'DZ',
			'Équateur' => 'EC',
			'Estonie' => 'EE',
			'Égypte' => 'EG',
			'Sahara Occidental' => 'EH',
			'Érythrée' => 'ER',
			'Espagne' => 'ES',
			'Éthiopie' => 'ET',
			'Finlande' => 'FI',
			'Fidji' => 'FJ',
			'Îles Malouines' => 'FK',
			'Micronésie' => 'FM',
			'Îles Féroé' => 'FO',
			'Gabon' => 'GA',
			'Grenade' => 'GD',
			'Géorgie' => 'GE',
			'Guyane' => 'GF',
			'Guernesey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Groenland' => 'GL',
			'Gambie' => 'GM',
			'Guinée' => 'GN',
			'Guadeloupe' => 'GP',
			'Guinée équatoriale' => 'GQ',
			'Grèce' => 'GR',
			'Géorgie du Sud-et-les Îles Sandwich du Sud' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinée-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hong Kong' => 'HK',
			'Îles Heard-et-MacDonald' => 'HM',
			'Honduras' => 'HN',
			'Croatie' => 'HR',
			'Haïti' => 'HT',
			'Hongrie' => 'HU',
			'Indonésie' => 'ID',
			'Irlande' => 'IE',
			'Israël' => 'IL',
			'Île de Man' => 'IM',
			'Inde' => 'IN',
			'Territoire britannique de l\'océan Indien' => 'IO',
			'Irak' => 'IQ',
			'Iran' => 'IR',
			'Islande' => 'IS',
			'Italie' => 'IT',
			'Jersey' => 'JE',
			'Jamaïque' => 'JM',
			'Jordanie' => 'JO',
			'Japon' => 'JP',
			'Kenya' => 'KE',
			'Kirghizistan' => 'KG',
			'Cambodge' => 'KH',
			'Kiribati' => 'KI',
			'Comores' => 'KM',
			'Saint-Christophe-et-Niévès' => 'KN',
			'Corée du Nord' => 'KP',
			'Corée du Sud' => 'KR',
			'Koweït' => 'KW',
			'Îles Caïmans' => 'KY',
			'Kazakhstan' => 'KZ',
			'Laos' => 'LA',
			'Liban' => 'LB',
			'Sainte-Lucie' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Lituanie' => 'LT',
			'Luxembourg' => 'LU',
			'Lettonie' => 'LV',
			'Libye' => 'LY',
			'Maroc' => 'MA',
			'Monaco' => 'MC',
			'Moldavie' => 'MD',
			'Monténégro' => 'ME',
			'Saint-Martin' => 'MF',
			'Madagascar' => 'MG',
			'Îles Marshall' => 'MH',
			'Macédoine du Nord' => 'MK',
			'Mali' => 'ML',
			'Birmanie' => 'MM',
			'Mongolie' => 'MN',
			'Macao' => 'MO',
			'Îles Mariannes du Nord' => 'MP',
			'Martinique' => 'MQ',
			'Mauritanie' => 'MR',
			'Montserrat' => 'MS',
			'Malte' => 'MT',
			'Île Maurice' => 'MU',
			'Maldives' => 'MV',
			'Malawi' => 'MW',
			'Mexique' => 'MX',
			'Malaisie' => 'MY',
			'Mozambique' => 'MZ',
			'Namibie' => 'NA',
			'Nouvelle-Calédonie' => 'NC',
			'Niger' => 'NE',
			'Île Norfolk' => 'NF',
			'Nigéria' => 'NG',
			'Nicaragua' => 'NI',
			'Pays-Bas' => 'NL',
			'Norvège' => 'NO',
			'Népal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'Nouvelle-Zélande' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Pérou' => 'PE',
			'Polynésie française' => 'PF',
			'Papouasie-Nouvelle-Guinée' => 'PG',
			'Philippines' => 'PH',
			'Pakistan' => 'PK',
			'Pologne' => 'PL',
			'Saint-Pierre-et-Miquelon' => 'PM',
			'Îles Pitcairn' => 'PN',
			'Porto Rico' => 'PR',
			'Palestine' => 'PS',
			'Portugal' => 'PT',
			'Palaos (Palau)' => 'PW',
			'Paraguay' => 'PY',
			'Qatar' => 'QA',
			'Réunion' => 'RE',
			'Roumanie' => 'RO',
			'Serbie' => 'RS',
			'Russie' => 'RU',
			'Rwanda' => 'RW',
			'Arabie Saoudite' => 'SA',
			'Îles Salomon' => 'SB',
			'Seychelles' => 'SC',
			'Soudan' => 'SD',
			'Suède' => 'SE',
			'Singapour' => 'SG',
			'Sainte-Hélène, Ascension et Tristan da Cunha' => 'SH',
			'Slovénie' => 'SI',
			'Svalbard et Jan Mayen' => 'SJ',
			'Slovaquie' => 'SK',
			'Sierra Leone' => 'SL',
			'Saint-Marin' => 'SM',
			'Sénégal' => 'SN',
			'Somalie' => 'SO',
			'Surinam' => 'SR',
			'Soudan du Sud' => 'SS',
			'São Tomé et Príncipe' => 'ST',
			'Salvador' => 'SV',
			'Saint-Martin' => 'SX',
			'Syrie' => 'SY',
			'Swaziland' => 'SZ',
			'Îles Turques-et-Caïques' => 'TC',
			'Tchad' => 'TD',
			'Terres australes et antarctiques françaises' => 'TF',
			'Togo' => 'TG',
			'Thaïlande' => 'TH',
			'Tadjikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor oriental' => 'TL',
			'Turkménistan' => 'TM',
			'Tunisie' => 'TN',
			'Tonga' => 'TO',
			'Turquie' => 'TR',
			'Trinité-et-Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taïwan' => 'TW',
			'Tanzanie' => 'TZ',
			'Ukraine' => 'UA',
			'Ouganda' => 'UG',
			'Îles mineures éloignées des États-Unis' => 'UM',
			'Uruguay' => 'UY',
			'Ouzbékistan' => 'UZ',
			'Cité du Vatican' => 'VA',
			'Saint-Vincent-et-les-Grenadines' => 'VC',
			'Venezuela' => 'VE',
			'Îles Vierges britanniques' => 'VG',
			'Îles Vierges des États-Unis' => 'VI',
			'ViÃªt Nam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis-et-Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Yémen' => 'YE',
			'Mayotte' => 'YT',
			'Afrique du Sud' => 'ZA',
			'Zambie' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Royaume-Uni' => \@ukTranslations,
			'Allemagne' => \@deTranslations,
			'Suisse' => \@chTranslations,
			'Autriche' => \@atTranslations,
			'France' => \@frTranslations,
			'États-Unis' => \@usTranslations,
		},
        default => {
			'Andorra' => 'AD',
			'United Arab Emirates' => 'AE',
			'Afghanistan' => 'AF',
			'Antigua and Barbuda' => 'AG',
			'Anguilla' => 'AI',
			'Albania' => 'AL',
			'Armenia' => 'AM',
			'Angola' => 'AO',
			'Antarctica' => 'AQ',
			'Argentina' => 'AR',
			'American Samoa' => 'AS',
			'Australia' => 'AU',
			'Aruba' => 'AW',
			'Åland Islands' => 'AX',
			'Azerbaijan' => 'AZ',
			'Bosnia and Herzegovina' => 'BA',
			'Barbados' => 'BB',
			'Bangladesh' => 'BD',
			'Belgium' => 'BE',
			'Burkina Faso' => 'BF',
			'Bulgaria' => 'BG',
			'Bahrain' => 'BH',
			'Burundi' => 'BI',
			'Benin' => 'BJ',
			'Saint Barthélemy' => 'BL',
			'Bermuda' => 'BM',
			'Brunei' => 'BN',
			'Bolivia' => 'BO',
			'Caribbean Netherlands' => 'BQ',
			'Brazil' => 'BR',
			'Bahamas' => 'BS',
			'Bhutan' => 'BT',
			'Bouvet Island' => 'BV',
			'Botswana' => 'BW',
			'Belarus' => 'BY',
			'Belize' => 'BZ',
			'Canada' => 'CA',
			'Cocos (Keeling) Islands' => 'CC',
			'DR Congo' => 'CD',
			'Central African Republic' => 'CF',
			'Republic of the Congo' => 'CG',
			'Ivory Coast' => 'CI',
			'Cook Islands' => 'CK',
			'Chile' => 'CL',
			'Cameroon' => 'CM',
			'China' => 'CN',
			'Colombia' => 'CO',
			'Costa Rica' => 'CR',
			'Cuba' => 'CU',
			'Cape Verde' => 'CV',
			'Curaçao' => 'CW',
			'Christmas Island' => 'CX',
			'Cyprus' => 'CY',
			'Czechia' => 'CZ',
			'Djibouti' => 'DJ',
			'Denmark' => 'DK',
			'Dominica' => 'DM',
			'Dominican Republic' => 'DO',
			'Algeria' => 'DZ',
			'Ecuador' => 'EC',
			'Estonia' => 'EE',
			'Egypt' => 'EG',
			'Western Sahara' => 'EH',
			'Eritrea' => 'ER',
			'Spain' => 'ES',
			'Ethiopia' => 'ET',
			'Finland' => 'FI',
			'Fiji' => 'FJ',
			'Falkland Islands' => 'FK',
			'Micronesia' => 'FM',
			'Faroe Islands' => 'FO',
			'Gabon' => 'GA',
			'Grenada' => 'GD',
			'Georgia' => 'GE',
			'French Guiana' => 'GF',
			'Guernsey' => 'GG',
			'Ghana' => 'GH',
			'Gibraltar' => 'GI',
			'Greenland' => 'GL',
			'Gambia' => 'GM',
			'Guinea' => 'GN',
			'Guadeloupe' => 'GP',
			'Equatorial Guinea' => 'GQ',
			'Greece' => 'GR',
			'South Georgia' => 'GS',
			'Guatemala' => 'GT',
			'Guam' => 'GU',
			'Guinea-Bissau' => 'GW',
			'Guyana' => 'GY',
			'Hong Kong' => 'HK',
			'Heard Island and McDonald Islands' => 'HM',
			'Honduras' => 'HN',
			'Croatia' => 'HR',
			'Haiti' => 'HT',
			'Hungary' => 'HU',
			'Indonesia' => 'ID',
			'Ireland' => 'IE',
			'Israel' => 'IL',
			'Isle of Man' => 'IM',
			'India' => 'IN',
			'British Indian Ocean Territory' => 'IO',
			'Iraq' => 'IQ',
			'Iran' => 'IR',
			'Iceland' => 'IS',
			'Italy' => 'IT',
			'Jersey' => 'JE',
			'Jamaica' => 'JM',
			'Jordan' => 'JO',
			'Japan' => 'JP',
			'Kenya' => 'KE',
			'Kyrgyzstan' => 'KG',
			'Cambodia' => 'KH',
			'Kiribati' => 'KI',
			'Comoros' => 'KM',
			'Saint Kitts and Nevis' => 'KN',
			'North Korea' => 'KP',
			'South Korea' => 'KR',
			'Kuwait' => 'KW',
			'Cayman Islands' => 'KY',
			'Kazakhstan' => 'KZ',
			'Laos' => 'LA',
			'Lebanon' => 'LB',
			'Saint Lucia' => 'LC',
			'Liechtenstein' => 'LI',
			'Sri Lanka' => 'LK',
			'Liberia' => 'LR',
			'Lesotho' => 'LS',
			'Lithuania' => 'LT',
			'Luxembourg' => 'LU',
			'Latvia' => 'LV',
			'Libya' => 'LY',
			'Morocco' => 'MA',
			'Monaco' => 'MC',
			'Moldova' => 'MD',
			'Montenegro' => 'ME',
			'Saint Martin' => 'MF',
			'Madagascar' => 'MG',
			'Marshall Islands' => 'MH',
			'North Macedonia' => 'MK',
			'Mali' => 'ML',
			'Myanmar' => 'MM',
			'Mongolia' => 'MN',
			'Macau' => 'MO',
			'Northern Mariana Islands' => 'MP',
			'Martinique' => 'MQ',
			'Mauritania' => 'MR',
			'Montserrat' => 'MS',
			'Malta' => 'MT',
			'Mauritius' => 'MU',
			'Maldives' => 'MV',
			'Malawi' => 'MW',
			'Mexico' => 'MX',
			'Malaysia' => 'MY',
			'Mozambique' => 'MZ',
			'Namibia' => 'NA',
			'New Caledonia' => 'NC',
			'Niger' => 'NE',
			'Norfolk Island' => 'NF',
			'Nigeria' => 'NG',
			'Nicaragua' => 'NI',
			'Netherlands' => 'NL',
			'Norway' => 'NO',
			'Nepal' => 'NP',
			'Nauru' => 'NR',
			'Niue' => 'NU',
			'New Zealand' => 'NZ',
			'Oman' => 'OM',
			'Panama' => 'PA',
			'Peru' => 'PE',
			'French Polynesia' => 'PF',
			'Papua New Guinea' => 'PG',
			'Philippines' => 'PH',
			'Pakistan' => 'PK',
			'Poland' => 'PL',
			'Saint Pierre and Miquelon' => 'PM',
			'Pitcairn Islands' => 'PN',
			'Puerto Rico' => 'PR',
			'Palestine' => 'PS',
			'Portugal' => 'PT',
			'Palau' => 'PW',
			'Paraguay' => 'PY',
			'Qatar' => 'QA',
			'Réunion' => 'RE',
			'Romania' => 'RO',
			'Serbia' => 'RS',
			'Russia' => 'RU',
			'Rwanda' => 'RW',
			'Saudi Arabia' => 'SA',
			'Solomon Islands' => 'SB',
			'Seychelles' => 'SC',
			'Sudan' => 'SD',
			'Sweden' => 'SE',
			'Singapore' => 'SG',
			'Saint Helena, Ascension and Tristan da Cunha' => 'SH',
			'Slovenia' => 'SI',
			'Svalbard and Jan Mayen' => 'SJ',
			'Slovakia' => 'SK',
			'Sierra Leone' => 'SL',
			'San Marino' => 'SM',
			'Senegal' => 'SN',
			'Somalia' => 'SO',
			'Suriname' => 'SR',
			'South Sudan' => 'SS',
			'São Tomé and Príncipe' => 'ST',
			'El Salvador' => 'SV',
			'Sint Maarten' => 'SX',
			'Syria' => 'SY',
			'Eswatini' => 'SZ',
			'Turks and Caicos Islands' => 'TC',
			'Chad' => 'TD',
			'French Southern and Antarctic Lands' => 'TF',
			'Togo' => 'TG',
			'Thailand' => 'TH',
			'Tajikistan' => 'TJ',
			'Tokelau' => 'TK',
			'Timor-Leste' => 'TL',
			'Turkmenistan' => 'TM',
			'Tunisia' => 'TN',
			'Tonga' => 'TO',
			'Turkey' => 'TR',
			'Trinidad and Tobago' => 'TT',
			'Tuvalu' => 'TV',
			'Taiwan' => 'TW',
			'Tanzania' => 'TZ',
			'Ukraine' => 'UA',
			'Uganda' => 'UG',
			'United States Minor Outlying Islands' => 'UM',
			'Uruguay' => 'UY',
			'Uzbekistan' => 'UZ',
			'Vatican City' => 'VA',
			'Saint Vincent and the Grenadines' => 'VC',
			'Venezuela' => 'VE',
			'British Virgin Islands' => 'VG',
			'United States Virgin Islands' => 'VI',
			'Vietnam' => 'VN',
			'Vanuatu' => 'VU',
			'Wallis and Futuna' => 'WF',
			'Samoa' => 'WS',
			'Kosovo' => 'XK',
			'Yemen' => 'YE',
			'Mayotte' => 'YT',
			'South Africa' => 'ZA',
			'Zambia' => 'ZM',
			'Zimbabwe' => 'ZW',
			'Switzerland' => \@chTranslations,
			'United Kingdom' => \@ukTranslations,
			'United States' => \@usTranslations,
			'Germany' => \@deTranslations,
			'France' => \@frTranslations,
			'Austria' => \@atTranslations,
        }
    };

	$s_country = (uc $s_country);
	if ($is_bank) {
		# Uppercase countries
		#$form->{country} = uc $form->{country};
		#print STDERR "Country: $form->{country}";
		$self->{selectbankcountry} = "<option value=''>\n";
		for (sort keys %{$countries->{$countrycode}}) {
			$country_key = $_;
			if (is_array($countries->{$countrycode}->{$country_key})) {
				$country_translations = $countries->{$countrycode}->{$country_key};
				$country_code = @$country_translations[0];
				if (grep {$s_country eq $_} @$country_translations) {
					$self->{selectbankcountry} .= "<option value=$country_code selected>$country_key</option>\n";
				} else {
					$self->{selectbankcountry} .= "<option value=$country_code>$country_key</option>\n";
				}
			} else {
				if ($s_country eq $countries->{$countrycode}->{$country_key}) {
					$self->{selectbankcountry} .= "<option value=$countries->{$countrycode}->{$country_key} selected>$country_key</option>\n";
				} else {
					$self->{selectbankcountry} .= "<option value=$countries->{$countrycode}->{$country_key}>$country_key</option>\n";
				}
			}
		}
	} else {
		$self->{selectcountry} = "<option value=''>\n";
		for (sort keys %{$countries->{$countrycode}}) {
			$country_key = $_;
			if (is_array($countries->{$countrycode}->{$country_key})) {
				$country_translations = $countries->{$countrycode}->{$country_key};
				$country_code = @$country_translations[0];
				if (grep {$s_country eq $_} @$country_translations) {
					$self->{selectcountry} .= "<option value=$country_code selected>$country_key</option>\n";
				} else {
					$self->{selectcountry} .= "<option value=$country_code>$country_key</option>\n";
				}
			} else {
				if ($s_country eq $countries->{$countrycode}->{$country_key}) {
					$self->{selectcountry} .= "<option value=$countries->{$countrycode}->{$country_key} selected>$country_key</option>\n";
				} else {
					$self->{selectcountry} .= "<option value=$countries->{$countrycode}->{$country_key}>$country_key</option>\n";
				}
			}
		}
	}

}

# https://www.perlmonks.org/?node_id=118961
sub is_array {
  my ($ref) = @_;
  # Firstly arrays need to be references, throw
  #  out non-references early.
  return 0 unless ref $ref;

  # Now try and eval a bit of code to treat the
  #  reference as an array.  If it complains
  #  in the 'Not an ARRAY reference' then we're
  #  sure it's not an array, otherwise it was.
  eval {
    my $a = @$ref;
  };
  if ($@=~/^Not an ARRAY reference/) {
    return 0;
  } elsif ($@) {
    die "Unexpected error in eval: $@\n";
  } else {
    return 1;
  }

}

sub logtofile {
	my ( $self, $txt ) = @_;
	open( FH, '>> logtofile.txt' );
	print FH "$txt\n";
	close(FH);
}

sub debug {
	my ( $self, $file, $vars ) = @_;

	if ($file) {
		open( FH, "> $file" ) or die $!;
		for ( sort keys %$self ) { print FH "$_ = $self->{$_}\n" }
		close(FH);
	}
	else {
		if ( $ENV{HTTP_USER_AGENT} ) {
			&header unless $self->{header};
			print "<pre>";
		}
        if ($vars){
		   for ( sort @$vars ) { print "$_ = $self->{$_}\n" }
        } else {
		   for ( sort keys %$self ) { print "$_ = $self->{$_}\n" }
        }
		print "</pre>" if $ENV{HTTP_USER_AGENT};
	}
}

# Dump hash values for debugging
sub dumper {
	my ( $self, $var ) = @_;

	use Data::Dumper;
	$Data::Dumper::Indent   = 3;
	$Data::Dumper::Sortkeys = 1;

	if ( $ENV{HTTP_USER_AGENT} ) {
		&header unless $self->{header};
		print "<pre>";
	}
	print Dumper($var);
	print "</pre>" if $ENV{HTTP_USER_AGENT};
}

sub escape {
	my ( $self, $str, $beenthere ) = @_;

	# for Apache 2 we escape strings twice
	if ( ( $ENV{SERVER_SIGNATURE} =~ /Apache\/2\.(\d+)\.(\d+)/ )
		&& !$beenthere )
	{
		$str = $self->escape( $str, 1 ) if $1 == 0 && $2 < 44;
	}

	$str =~ s/([^a-zA-Z0-9_.-])/sprintf("%%%02x", ord($1))/ge;
	$str;

}

sub unescape {
	my ( $self, $str ) = @_;

	$str =~ tr/+/ /;
	$str =~ s/\\$//;

	$str =~ s/%([0-9a-fA-Z]{2})/pack("c",hex($1))/eg;
	$str =~ s/\r?\n/\n/g;

	$str;

}

sub quote {
	my ( $self, $str ) = @_;

	if ( $str && !ref($str) ) {
		$str =~ s/"/&quot;/g;
		$str =~ s/\+/\&#43;/g;
	}

	$str;

}

sub unquote {
	my ( $self, $str ) = @_;

	if ( $str && !ref($str) ) {
		$str =~ s/&quot;/"/g;
	}

	$str;

}

sub helpref {
	my ( $self, $file, $countrycode ) = @_;

	return;

}

sub select_option {
	my ( $self, $list, $selected, $removeid, $rev ) = @_;

	my $str;
	my @a = split /\r?\n/, $self->unescape($list);
	my $var;

	for (@a) {
		$var = $_ = $self->quote($_);
		if ( $rev ne "" ) {
			$_   =~ s/--.*//g;
			$var =~ s/.*--//g;
		}
		if ( $removeid ne "" ) {
			$var =~ s/--.*//g;
		}

		$str .= qq|<option|;
		$str .= qq| value="$_"| if ( $removeid || $rev );
		$str .= qq| selected|
		  if ( ( $_ ne "" ) && ( $_ eq $self->quote($selected) ) );
		$str .= qq|>$var\n|;
	}

	$str;

}

sub hide_form {
	my $self = shift;

	my $str;

	if (@_) {
		for (@_) {
			$str .=
			    qq|<input type="hidden" name="$_" value="|
			  . $self->quote( $self->{$_} )
			  . qq|">\n|;
		}
		print qq|$str| if $self->{header};
	}
	else {
		delete $self->{header};
		for ( sort keys %$self ) {
			print qq|<input type="hidden" name="$_" value="|
			  . $self->quote( $self->{$_} )
			  . qq|">\n|;
		}
	}

	$str;

}

sub error {
	my ( $self, $msg, $dbmsg ) = @_;

	if ( $ENV{HTTP_USER_AGENT} ) {
		$self->{msg}    = $msg;
		$self->{dbmsg}  = $dbmsg;
		$self->{format} = "html";
		$self->format_string(msg);
		$self->format_string(dbmsg);

		delete $self->{pre};

		if ( !$self->{header} ) {
			$self->header( 0, 1 );
		}

		if ( $dbmsg && !$errormessages ) {
			print qq|<body><h2 class=error>Error!</h2>;
       <p><b id=errorMessage class=dberror>$self->{dbmsg}</b>|;
		}
		else {
			print qq|<body><h2 class=error>Error!</h2>
	   <p><b id=errorMessage>$self->{msg}</b>|;

			print qq|<h2 class=dberror>DB Error!</h2>

       <p><b class=dberror>$self->{dbmsg}</b>|;

		}
		print STDERR "Error ($errormessages): $msg\n$dbmsg\n";
		exit;

	}

	die "Error: $msg\n";

}

sub info {
	my ( $self, $msg ) = @_;

	if ( $ENV{HTTP_USER_AGENT} ) {
		$msg =~ s/\n/<br>/g;

		delete $self->{pre};

		if ( !$self->{header} ) {
			$self->header( 0, 1 );
			print qq|
      <body>|;
		}

		print "<b>$msg</b>";

	}
	else {

		print "$msg\n";

	}

}

sub numtextrows {
	my ( $self, $str, $cols, $maxrows ) = @_;

	my $rows = 0;

	for ( split /\n/, $str ) { $rows += int( ( (length) - 2 ) / $cols ) + 1 }
	$maxrows = $rows unless defined $maxrows;

	return ( $rows > $maxrows ) ? $maxrows : $rows;

}

sub dberror {
	my ( $self, $msg ) = @_;

	$self->error( $msg, $DBI::errstr );

}

sub isblank {
	my ( $self, $name, $msg ) = @_;

	$self->error($msg) if $self->{$name} =~ /^\s*$/;

}

sub header {
	my ( $self, $endsession, $nocookie, $locale ) = @_;

	return if $self->{header};

	my ( $stylesheet, $javascript, $favicon, $charset );

	my $selectNoEntriesText = 'No Results Found'; # Default select2 message

	if ($locale) {
		$selectNoEntriesText = $locale->text('No Entries');
	}

	if ( $ENV{HTTP_USER_AGENT} ) {

		if ( $self->{stylesheet} && ( -f "css/$self->{stylesheet}" ) ) {
			$stylesheet =
qq|<link rel="stylesheet" href="css/$self->{stylesheet}" type="text/css" title="SQL-Ledger stylesheet">
  |;
		}

		if ( -f "js/sql-ledger.js" ) {
			$javascript =
qq|<script type="text/javascript" src="js/sql-ledger.js"></script>|;
		}

		if ( $self->{favicon} && ( -f "$self->{favicon}" ) ) {
			$favicon =
			  qq|<link rel="icon" href="$self->{favicon}" type="image/x-icon">
<link rel="shortcut icon" href="$self->{favicon}" type="image/x-icon">
  |;
		}

		if ( $self->{charset} ) {
			$charset =
qq|<meta http-equiv="Content-Type" content="text/plain; charset=$self->{charset}">
  |;
		}

		$self->{titlebar} =
		  ( $self->{title} )
		  ? "$self->{title} - $self->{titlebar}"
		  : $self->{titlebar};

		$self->set_cookie($endsession) unless $nocookie;

		print qq|Content-Type: text/html

<head>
  <title>$self->{titlebar}</title>
  <meta name="robots" content="noindex,nofollow" />
  $favicon

  <link rel="stylesheet" href="css/select2-4.0.13.min.css" type="text/css"/>
  <link rel="stylesheet" href="css/jquery-ui-1.12.1.min.css" type="text/css"/>

  $stylesheet

  $charset

  <script src="js/jquery-3.6.0.min.js" type="text/javascript"></script>
  <script src="js/jquery-ui-1.12.1.min.js" type="text/javascript"></script>

  <script src="js/select2-4.0.13.min.js" type="text/javascript"></script>

  <script src="js/rma.js" type="text/javascript"></script>
|;
		print q|
<script>
$(document).ready(function() {
	var select2Config = {
		dropdownAutoWidth : false,
    	width: 'resolve',
    	matcher: matchStartStringOnly,
    	language: {
       		noResults: function() {
           		return "|;print qq|$selectNoEntriesText|;print q|";
       		}
   		}
	};

	$('select').select2(select2Config);
});

function matchStartStringOnly(params, data) {
  // If there are no search terms, return all of the data
  if ($.trim(params.term) === '') {
    return data;
  }

  // Skip if there is no 'children' property
  if (typeof data.id === 'undefined') {
    return null;
  }
  	// most accountans pref to search for chart number, and display results by that, while others prefer the description of the chart, therefor we distinguish between number or text search an return different results
	if(isNaN(params.term)){
		if (data.id.toUpperCase().includes(params.term.toUpperCase())) {
    		return data;
  		}
  	} else {
  		if (data.id.toUpperCase().indexOf(params.term.toUpperCase()) == 0) {
    		return data;
  		}
  	}

  // Return `null` if the term should not be displayed
  return null;
}


$(document).on('select2:open', () => {
    document.querySelector('.select2-search__field').focus();
});
$(document).ready(function(){
    var str = $('div.redirectmsg').text();
    if ( str.length > 0 ) {
    	setTimeout(function(){
    	
	    	$('div.redirectmsg').show();
	        $('div.redirectmsg').fadeOut('slow', function () {
	            $('div.redirectmsg').remove();
	        });
		}, 2000);
	} else {
	   	$('div.redirectmsg').hide();
	}
|;

		@menuids = split( ':', $self->{menuids} );
		for (@menuids) { print q|$("#menu| . $_ . qq|").trigger("click");\n|; }

		print q|
});
</script>
</head>
|;
		print qq|
$self->{pre}
|;
	}

	$self->{header} = 1;
	delete $self->{sessioncookie};

}

sub set_cookie {
	my ( $self, $endsession ) = @_;

	$self->{timeout} ||= 31557600;
	my $t = ($endsession) ? time : time + $self->{timeout};
	my $login = ( $self->{"root login"} ) ? "root login" : $self->{login};

	if ( $ENV{HTTP_USER_AGENT} ) {
		my @d = split / +/, scalar gmtime($t);

		my $today = "$d[0], $d[2]-$d[1]-$d[4] $d[3] GMT";

		if ($login) {
			if ( $self->{sessioncookie} ) {
				print
qq|Set-Cookie: SL-${login}=$self->{sessioncookie}; expires=$today; path=/;\n|;
			}
			else {
				print qq|Set-Cookie: SL-${login}=; expires=$today; path=/;\n|;
			}
		}
	}

}

sub redirect {
	my ( $self, $msg ) = @_;

	if ( $self->{callback} ) {

		$self->{callback} .= "&redirectmsg=$msg";
		if ( $self->{encpassword} ) {
			$self->{callback} .= "&encpassword=$self->{encpassword}";
		}
		my ( $script, $argv ) = split( /\?/, $self->{callback} );
		exec( "perl", $script, $argv );

	}
	else {

		$self->info($msg);

	}

}

sub sort_columns {
	my ( $self, @columns ) = @_;

	if ( $self->{sort} ) {
		$self->{sort} =~ s/;//g;
		if (@columns) {
			@columns = grep !/^$self->{sort}$/, @columns;
			splice @columns, 0, 0, $self->{sort};
		}
	}

	@columns;

}

sub sort_order {
	my ( $self, $columns, $ordinal ) = @_;

	# setup direction
	if ( $self->{direction} ) {
		if ( $self->{sort} eq $self->{oldsort} ) {
			if ( $self->{direction} eq 'ASC' ) {
				$self->{direction} = "DESC";
			}
			else {
				$self->{direction} = "ASC";
			}
		}
	}
	else {
		$self->{direction} = "ASC";
	}
	$self->{oldsort} = $self->{sort};

	my @a = $self->sort_columns( @{$columns} );
	if (%$ordinal) {
		$a[0] =
		  ( $ordinal->{ $a[$_] } )
		  ? "$ordinal->{$a[0]} $self->{direction}"
		  : "$a[0] $self->{direction}";
		for ( 1 .. $#a ) {
			$a[$_] = $ordinal->{ $a[$_] }
			  if $ordinal->{ $a[$_] };
		}
	}
	else {
		$a[0] .= " $self->{direction}";
	}

	$sortorder = join ',', @a;
	$sortorder = $self->dbclean($sortorder);
	$sortorder;

}

sub dbescape {
	my ( $self, $value ) = @_;
	$value =~ s/'/''/g;
	return $value;
}

sub dbclean {
	my ( $self, $value ) = @_;
	$value =~ s/'//g;
	return $value;
}

sub format_amount {
	my ( $self, $myconfig, $amount, $places, $dash ) = @_;

	if ( $places =~ /\d+/ ) {
		$amount = $self->round_amount( $amount, $places );
	}

	# is the amount negative
	my $negative = ( $amount < 0 );

	if ($amount) {
		if ( $myconfig->{numberformat} ) {
			my ( $whole, $dec ) = split /\./, "$amount";
			$whole =~ s/-//;
			$amount = join '', reverse split //, $whole;
			if ($places) {
				$dec .= "0" x $places;
				$dec = substr( $dec, 0, $places );
			}

			if ( $myconfig->{numberformat} eq '1,000.00' ) {
				$amount =~ s/\d{3,}?/$&,/g;
				$amount =~ s/,$//;
				$amount = join '', reverse split //, $amount;
				$amount .= "\.$dec" if ( $dec ne "" );
			}

			if ( $myconfig->{numberformat} eq "1'000.00" ) {
				$amount =~ s/\d{3,}?/$&'/g;
				$amount =~ s/'$//;
				$amount = join '', reverse split //, $amount;
				$amount .= "\.$dec" if ( $dec ne "" );
			}

			if ( $myconfig->{numberformat} eq '1.000,00' ) {
				$amount =~ s/\d{3,}?/$&./g;
				$amount =~ s/\.$//;
				$amount = join '', reverse split //, $amount;
				$amount .= ",$dec" if ( $dec ne "" );
			}

			if ( $myconfig->{numberformat} eq '1000,00' ) {
				$amount = "$whole";
				$amount .= ",$dec" if ( $dec ne "" );
			}

			if ( $myconfig->{numberformat} eq '1000.00' ) {
				$amount = "$whole";
				$amount .= ".$dec" if ( $dec ne "" );
			}

			if ( $dash =~ /-/ ) {
				$amount = ($negative) ? "($amount)" : "$amount";
			}
			elsif ( $dash =~ /DRCR/ ) {
				$amount = ($negative) ? "$amount DR" : "$amount CR";
			}
			else {
				$amount = ($negative) ? "-$amount" : "$amount";
			}
		}
	}
	else {
		if ( $dash eq "0" && $places ) {
			if ( $myconfig->{numberformat} eq '1.000,00' ) {
				$amount = "0" . "," . "0" x $places;
			}
			else {
				$amount = "0" . "." . "0" x $places;
			}
		}
		else {
			$amount = ( $dash ne "" ) ? "$dash" : "";
		}
	}

	$amount;

}

sub parse_amount {
	my ( $self, $myconfig, $amount ) = @_;

	if (   ( $myconfig->{numberformat} eq '1.000,00' )
		|| ( $myconfig->{numberformat} eq '1000,00' ) )
	{
		$amount =~ s/\.//g;
		$amount =~ s/,/\./;
	}

	if ( $myconfig->{numberformat} eq "1'000.00" ) {
		$amount =~ s/'//g;
	}

	$amount =~ s/,//g;

	return ( $amount * 1 );

}

sub round_amount {
	my ( $self, $amount, $places ) = @_;

	my ( $null, $dec ) = split /\./, $amount;
	$dec = length $dec;
	$dec = ( $dec > $places ) ? $dec : $places;
	my $adj =
	    ( $amount < 0 )
	  ? ( 1 / 10**( $dec + 2 ) ) * -1
	  : ( 1 / 10**( $dec + 2 ) );

	if ( ( $places * 1 ) >= 0 ) {
		$amount = sprintf( "%.${places}f", $amount + $adj ) * 1;
	}
	else {
		$places *= -1;
		$amount = sprintf( "%.0f", $amount );
		$amount = sprintf( "%.f", $amount / ( 10**$places ) ) * ( 10**$places );
	}

	$amount;

}

sub parse_template {
	my ( $self, $myconfig, $tmppath, $debuglatex, $noreply, $apikey ) = @_;

	my ( $chars_per_line, $lines_on_first_page, $lines_on_second_page ) =
	  ( 0, 0, 0 );
	my ( $current_page, $current_line ) = ( 1, 1 );
	my $pagebreak = "";
	my $sum;

	my $subdir = "";
	my $err    = "";

	# Setup variables from defaults table
	my $dbh = $self->dbconnect($myconfig);
	my ($noreplyemail) = $dbh->selectrow_array("SELECT fldvalue FROM defaults WHERE fldname='noreplyemail'");
	my ($utf8templates) = $dbh->selectrow_array("SELECT fldvalue FROM defaults WHERE fldname='utf8templates'");
	my ($company) = $dbh->selectrow_array("SELECT fldvalue FROM defaults WHERE fldname='company'");

	my $query =
	  "SELECT fldname, fldvalue FROM defaults WHERE fldname LIKE 'latex'";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	while ( $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		$self->{ $ref->{fldname} } = $ref->{fldvalue};
	}
	$sth->finish;
	$dbh->disconnect;

	## Uncomment following line to view template variables with values in browser.
	# $self->dumper($self); $self->error;

	my %include = ();
	my $ok;

	$self->{debuglatex} = $debuglatex;

	if ( -f "$self->{templates}/$self->{language_code}/$self->{IN}" ) {
		open( IN, "$self->{templates}/$self->{language_code}/$self->{IN}" )
		  or $self->error(
			"$self->{templates}/$self->{language_code}/$self->{IN} : $!");
	}
	else {
		open( IN, "$self->{templates}/$self->{IN}" )
		  or $self->error("$self->{templates}/$self->{IN} : $!");
	}

	my @texform = <IN>;
	close(IN);

	# OUT is used for the media, screen, printer, email
	# for postscript we store a copy in a temporary file
	my $fileid  = time;
	my $tmpfile = $self->{IN};
	$tmpfile =~ s/\./_$self->{fileid}./ if $self->{fileid};
	$self->{tmpfile} = "$tmppath/${fileid}_${tmpfile}";

	if ( $self->{format} =~ /(postscript|pdf)/ || $self->{media} eq 'email' ) {
		$out = $self->{OUT};
		$self->{OUT} = ">$self->{tmpfile}";
	}

	if ( $self->{OUT} ) {
		open( OUT, "$self->{OUT}" ) or $self->error("$self->{OUT} : $!");
	}
	else {
		open( OUT, ">-" ) or $self->error("STDOUT : $!");

		$self->header;

	}

	$self->{copies} ||= 1;

	# first we generate a tmpfile
	# read file and replace <%variable%>

	$self->{copy} = "";

	for my $i ( 1 .. $self->{copies} ) {

		$sum = 0;
		$self->{copy} = 1 if $i == 2;

		if ( $self->{format} =~ /(postscript|pdf)/ && $self->{copies} > 1 ) {
			if ( $i == 1 ) {
				@_ = ();
				while ( $_ = shift @texform ) {
					if (/\\end\{document\}/) {
						push @_, qq|\\newpage\n|;
						last;
					}
					push @_, $_;
				}
				@texform = @_;
			}

			if ( $i == 2 ) {
				while ( $_ = shift @texform ) {
					last if /\\begin\{document\}/;
				}
			}

			if ( $i == $self->{copies} ) {
				push @texform, q|\end{document}|;
			}
		}

		@_ = @texform;

		while ( $_ = shift ) {

			$par = "";
			$var = $_;

			# detect pagebreak block and its parameters
			if (/<%pagebreak ([0-9]+) ([0-9]+) ([0-9]+)%>/) {
				$chars_per_line       = $1;
				$lines_on_first_page  = $2;
				$lines_on_second_page = $3;

				while ( $_ = shift ) {
					last if (/<%end pagebreak%>/);
					$pagebreak .= $_;
				}
			}

			$sum = 0 if (/<%resetcarriedforward%>/);

			if (/<%foreach /) {

				# this one we need for the count
				chomp $var;
				$var =~ s/.*?<%foreach\s+?(.+?)%>/$1/;
				while ( $_ = shift ) {
					last if /<%end \Q$var\E%>/;

					# store line in $par
					$par .= $_;
				}

				# display contents of $self->{number}[] array
				for my $j ( 0 .. $#{ $self->{$var} } ) {

					if ( $var =~ /^(part|service)$/ ) {
						next if $self->{$var}[$j] eq 'NULL';
					}

					# Try to detect whether a manual page break is necessary
					# but only if there was a <%pagebreak ...%> block before

					if (   $var eq 'number'
						|| $var eq 'part'
						|| $var eq 'service' )
					{
						if ( $chars_per_line && ( $self->{$var} ne "" ) ) {
							my $line;
							my $lines = 0;
							my $item  = $self->{description}[$j];
							$item .= "\n" . $self->{itemnotes}[$j]
							  if $self->{itemnotes}[$j];

							foreach $line ( split /\r?\n/, $item ) {
								$lines++;
								$lines +=
								  int( length($line) / $chars_per_line );
							}

							my $lpp;

							if ( $current_page == 1 ) {
								$lpp = $lines_on_first_page;
							}
							else {
								$lpp = $lines_on_second_page;
							}

							# Yes we need a manual page break
							if ( ( $current_line + $lines ) > $lpp ) {
								my $pb = $pagebreak;

						   # replace the special variables <%sumcarriedforward%>
						   # and <%lastpage%>

								my $psum =
								  $self->format_amount( $myconfig, $sum,
									$self->{precision} );
								$pb =~ s/<%xml_sumcarriedforward%>/$sum/g;
								$pb =~ s/<%sumcarriedforward%>/$psum/g;
								$pb =~ s/<%lastpage%>/$current_page/g;

								# only "normal" variables are supported here
								# (no <%if, no <%foreach, no <%include)

								$pb =~ s/<%(.+?)%>/$self->{$1}/g;

								# page break block is ready to rock
								print( OUT $pb );
								$current_page++;
								$current_line = 1;
								$lines        = 0;
							}
							$current_line += $lines;
						}
						$sum +=
						  $self->parse_amount( $myconfig,
							$self->{linetotal}[$j] );
					}

					# don't parse par, we need it for each line
					print OUT $self->format_line($myconfig, $par, $j );

				}
				next;
			}

			# if not comes before if!
			if (/<%if\s+?not /) {

				# check if it is not set and display
				chop;
				s/.*?<%if\s+?not\s+?(.+?)%>/$1/;

				$var = $1;

				if ( !$self->{$var} ) {
					s/^$var//;

					if (/<%end /) {
						s/<%end\s+?$var%>//;
						$par = $_;
					}
					else {
						$par = $_;
						while ( $_ = shift ) {
							last if /<%end /;

							# store line in $par
							$par .= $_;
						}
					}

					$_ = $var = $par;

				}
				else {
					if ( !/<%end / ) {
						while ( $_ = shift ) {
							last if /<%end /;
						}
					}
					next;
				}
			}

			if (/<%if /) {

				# check if it is set and display
				chop;
				s/.*?<%if\s+?(.+?)%>/$1/;

				$var = $1;

				if ( $var =~ /\s/ ) {
					@a = split / /, $var, 3;
					$ok = eval qq|$self->{$a[0]} $a[1] "$a[2]"|;
				}
				else {
					$ok = $self->{$var};
				}

				if ($ok) {
					s/^$var//;
					if (/<%end /) {
						s/<%end\s+?$var%>//;
						$par = $_;
					}
					else {
						$par = $_;
						while ( $_ = shift ) {
							last if /<%end /;

							# store line in $par
							$par .= $_;
						}
					}

					$_ = $var = $par;

				}
				else {
					if ( !/<%end / ) {
						while ( $_ = shift ) {
							last if /<%end /;
						}
					}
					next;
				}
			}

			# check for <%include filename%>
			if (/<%include /) {

				# get the filename
				chomp $var;
				$var =~ s/.*?<%include\s+?(.+?)%>/$1/;

				# remove / .. for security reasons
				$var =~ s/(\/|\.\.)//g;

				# assume loop after 10 includes of the same file
				next if $include{$var} > 10;

				unless (
					open( INC, "$self->{templates}/$self->{language_code}/$var"
					)
				  )
				{
					$err = $!;
					$self->cleanup;
					$self->error(
						"$self->{templates}/$self->{language_code}/$var : $err"
					);
				}
				unshift( @_, <INC> );
				close(INC);

				$include{$var}++;

				next;
			}

			print OUT $self->format_line($myconfig, $_);

		}
	}

	close(OUT);

	# Convert the tex file to postscript
	if ( $self->{format} =~ /(postscript|pdf)/ ) {

		use Cwd;
		$self->{cwd}    = cwd();
		$self->{tmpdir} = "$self->{cwd}/$tmppath";

		unless ( chdir("$tmppath") ) {
			$err = $!;
			$self->cleanup;
			$self->error("chdir : $err");
		}

		$self->{tmpfile} =~ s/$tmppath\///g;

        if ($utf8templates){
           system("mv $self->{tmpfile} LATIN-$self->{tmpfile}");
           system("iconv -f ISO-8859-1 -t UTF8 LATIN-$self->{tmpfile} -o $self->{tmpfile}");
        }

		$self->{errfile} = $self->{tmpfile};
		$self->{errfile} =~ s/tex$/err/;

		my $r = 1;
		if ( $self->{format} eq 'postscript' ) {

			system(
"latex --interaction=nonstopmode $self->{tmpfile} > $self->{errfile}"
			);
			while ( $self->rerun_latex ) {
				system(
"latex --interaction=nonstopmode $self->{tmpfile} > $self->{errfile}"
				);
				last if ++$r > 4;
			}
			$self->{tmpfile} =~ s/tex$/dvi/;
			$self->error( $self->cleanup ) if !( -f $self->{tmpfile} );

			system("dvips $self->{tmpfile} -o -q");
			$self->error( $self->cleanup . "dvips : $!" ) if ($?);
			$self->{tmpfile} =~ s/dvi$/ps/;
		}
		if ( $self->{format} eq 'pdf' ) {
			system(
"pdflatex --interaction=nonstopmode $self->{tmpfile} > $self->{errfile}"
			);
			while ( $self->rerun_latex ) {
				system(
"pdflatex --interaction=nonstopmode $self->{tmpfile} > $self->{errfile}"
				);
				last if ++$r > 4;
			}

			$self->error( $self->cleanup ) if !( -f $self->{tmpfile} );
			$self->{tmpfile} =~ s/tex$/pdf/;
		}

	}

	if ( $self->{format} =~ /(postscript|pdf)/ || $self->{media} eq 'email' ) {

		if ( $self->{media} eq 'email' ) {

			use SL::Mailer;

			my $mail = new Mailer;

			for (qw(cc bcc subject message version format charset notify)) {
				$mail->{$_} = $self->{$_};
			}
            $noreply              = $myconfig->{email} if !$noreplyemail; # armaghan 2020-03-31 do not use noreply email if not enabled in defaults
			$mail->{to}           = qq|$self->{email}|;
            $mail->{from}         = qq|"$myconfig->{name} ($company)" <$noreply>|;
            $mail->{'reply-to'}   = qq|"$myconfig->{name}" <$myconfig->{email}>|;
			$mail->{fileid} = "$fileid.";

			# if we send html or plain text inline
			if (   ( $self->{format} =~ /(html|txt)/ )
				&& ( $self->{sendmode} eq 'inline' ) )
			{
				my $br = "";
				$br = "<br>" if $self->{format} eq 'html';

				$mail->{contenttype} = "text/$self->{format}";

				$mail->{message}       =~ s/\r?\n/$br\n/g;
				$myconfig->{signature} =~ s/\\n/$br\n/g;
				$mail->{message} .= "$br\n-- $br\n$myconfig->{signature}\n$br"
				  if $myconfig->{signature};

				unless ( open( IN, $self->{tmpfile} ) ) {
					$err = $!;
					$self->cleanup;
					$self->error("$self->{tmpfile} : $err");
				}

				while (<IN>) {
					$mail->{message} .= $_;
				}

				close(IN);

			}
			else {

				@{ $mail->{attachments} } = ( $self->{tmpfile} );

				$myconfig->{signature} =~ s/\\n/\n/g;
				$mail->{message} .= "\n-- \n$myconfig->{signature}"
				  if $myconfig->{signature};

			}

            my $err;
            if ($noreplyemail){
               $mail->{from}         = $noreply;
               $mail->{fromname}     = "$myconfig->{name} ($company)";
               $mail->{replyto}   = $myconfig->{email};
               $mail->{apikey} = $apikey;
			   $err = $mail->apisend($out);
            } else {
			   $err = $mail->send($out);
            }
			if ( $err ) {
				$self->cleanup;
				$self->error($err);
			}

		}
		else {

			$self->{OUT} = $out;
			unless ( open( IN, $self->{tmpfile} ) ) {
				$err = $!;
				$self->cleanup;
				$self->error("$self->{tmpfile} : $err");
			}

			binmode(IN);

			chdir("$self->{cwd}");

			if ( $self->{OUT} ) {
				unless ( open( OUT, $self->{OUT} ) ) {
					$err = $!;
					$self->cleanup;
					$self->error("$self->{OUT} : $err");
				}
			}
			else {

				# launch application
				print qq|Content-Type: application/$self->{format}
Content-Disposition: attachment; filename="$self->{tmpfile}"\n\n|;

				unless ( open( OUT, ">-" ) ) {
					$err = $!;
					$self->cleanup;
					$self->error("STDOUT : $err");
				}

			}

			binmode(OUT);

			while (<IN>) {
				print OUT $_;
			}

			close(IN);
			close(OUT);
		}

		$self->cleanup;

	}

}

sub string_abbreviate {
	my ($self, $string, $max_length) = @_;

	if (length($string) > $max_length) {
		$string = substr($string, 0, $max_length - 3);
		$string = $string . "...";
	}

	return $string;
}

sub string_replace {
  	my ($self, $string, $search_string, $replace_string) = @_;
  	
	$string =~ s/$search_string/$replace_string/ig;
	
	return $string;
}

sub format_line {
	my $self = shift;
	my $myconfig = shift;
	$_ = shift;
	my $i = shift;

	my $str;
	my $newstr;
	my $pos;
	my $l;
	my $lf;
	my $line;
	my $var = "";
	my %a;
	my @a;
	my $offset;
	my $pad;
	my $item;
	my $key;
	my $value;

	while (/<%(.+?)%>/) {

		$var    = $1;
		$newstr = "";
		$pipe   = "";

		if ( $var =~ />>>/ ) {
			@a    = split / >>> /, $var;
			$var  = $a[0];
			$pipe = $a[1];
		}

		%a = ();
		if ( $var =~ /(align|width|offset|group)\s*?=/ ) {
			@a = split / /, $var;
			$var = $a[0];
			foreach $item (@a) {
				( $key, $value ) = split /=/, $item;
				if ( $value ne "" ) {
					$a{$key} = $value;
				}
			}
		}

		if ( $var =~ /\s/ ) {
			$str = "";

			@a = split / /, $var, 3;
			if ( $var =~ /^if\s+?not / ) {
				$a[1] = $a[2];
				pop @a;
			}

			if ( $#a == 2 ) {
				for $j ( 0 .. 2 ) {
					$item = $a[$j];
					if ( $item !~ /'/ ) {
						if ( defined $i ) {
							if ( exists $self->{$item}[$i] ) {
								$a[$j] = qq|'$self->{$item}[$i]'|;
							}
						}
						else {
							if ( exists $self->{$item} ) {
								$a[$j] = qq|'$self->{$item}'|;
							}
						}
					}
				}
				$str = eval qq|$a[0] $a[1] $a[2]|;
			}
			else {
				if ( defined $i ) {
					$str = $self->{ $a[1] }[$i];
				}
				else {
					$str = $self->{ $a[1] };
				}
			}
		}
		else {
			if ( defined $i ) {
				if ( $var =~ /(currency)/ ) {
					$str = $self->{$var};
				}
				else {
					$str = $self->{$var}[$i];
				}

			}
			else {
				$str = $self->{$var};
			}
		}
		$newstr = $str;

		if ( $var =~ /^if\s+not / ) {
			if ($str) {
				$var =~ s/if\s+?not\s+?//;
				s/<%if\s+not\s+?$var%>.*?(<%end\s+?$var%>|$)//s;
			}
			else {
				s/<%$var%>//;
			}
			next;
		}

		if ( $var =~ /^if / ) {
			if ($str) {
				s/<%$var%>//;
			}
			else {
				$var =~ s/if\s+?//;
				s/<%if\s+?$var%>.*?(<%(end|else)\s+?$var%>|$)//s;
			}
			next;
		}

		if ( $var =~ /^else / ) {
			if ($str) {
				$var =~ s/else\s+?//;
				s/<%else\s+?$var%>.*?(<%end\s+?$var%>|$)//s;
			}
			else {
				s/<%$var%>//;
			}
			next;
		}

		if ( $var =~ /^end / ) {
			s/<%$var%>//;
			next;
		}

		if ( $a{align} || $a{width} || $a{offset} ) {

			$newstr = "";
			$offset = 0;
			$lf     = "";

			chomp $str;
			$str .= "\n";

			foreach $str ( split /\n/, $str ) {

				$line = $str;
				$l    = length $str;

				do {
					if ( ( $pos = length $str ) > $a{width} ) {
						if ( ( $pos = rindex $str, " ", $a{width} ) > 0 ) {
							$line = substr( $str, 0, $pos );
						}
						$pos = length $str if $pos == -1;
					}

					$l = length $line;

					# pad left, right or center
					$l = ( $a{width} - $l );

					$pad = " " x $l;

					if ( $a{align} =~ /right/i ) {
						$line = " " x $offset . $pad . $line;
					}

					if ( $a{align} =~ /left/i ) {
						$line = " " x $offset . $line . $pad;
					}

					if ( $a{align} =~ /center/i ) {
						$pad  = " " x ( $l / 2 );
						$line = " " x $offset . $pad . $line;
						$pad  = " " x ( $l / 2 );
						$line .= $pad;
					}

					$newstr .= "$lf$line";

					$str  = substr( $str, $pos + 1 );
					$line = $str;
					$lf   = "\n";

					$offset = $a{offset};

				} while ($str);
			}
		}

		if ( $a{group} ) {

			$a{group} =~ s/\d+//;
			$n = $&;
			@a = split //, $str;

			if ( $a{group} =~ /right/i ) {
				@a = reverse @a;
			}

			my $j = $n - 1;
			$newstr = "";
			foreach $str (@a) {
				$j++;
				if ( !( $j % $n ) ) {
					$newstr .= " $str";
				}
				else {
					$newstr .= $str;
				}
			}

			if ( $a{group} =~ /right/i ) {
				$newstr = reverse split //, $newstr;
			}
		}

		if ( $a{ASCII} ) {
			my $carret;
			my $nn;
			$n = 0;
			if ( $a{ASCII} =~ /^\^/ ) {
				$carret = '^';
			}
			if ( $a{ASCII} =~ /\d+/ ) {
				$n  = length $&;
				$nn = $&;
			}

			$newstr = "";
			for ( split //, $str ) {
				$newstr .= "$carret";
				if ($n) {
					$newstr .= substr( $nn . ord, -$n );
				}
				else {
					$newstr .= ord;
				}
			}
		}
		
		if ( $pipe =~ /yyyy-mm-dd/) {
			my $time = Time::Piece->strptime($newstr, $self->get_dateformatx($myconfig));
			$newstr = $time->strftime('%Y-%M-%d');
		}

		s/<%(.+?)%>/$newstr/;

		s/(ï¿½)/\\textsuperscript{2}/;
		s/(ï¿½)/\\textsuperscript{3}/;

	}

	$_;

}

sub today {
	my $self = shift;
	my $myconfig = shift;
	my $t = Time::Piece->localtime();
	my $format = $self->get_dateformatx($myconfig);
	$format =~ s/M/m/;
	my $time = $t->strftime($format);
	return $time;
}

sub get_dateformatx {
	my ($self, $myconfig) = @_;
	if ($myconfig->{dateformat} eq 'dd.mm.yy') {
		return '%d.%M.%Y';		
	} elsif ($myconfig->{dateformat} eq 'mm-dd-yy') {
		return '%M-%d-%Y';		
	} elsif ($myconfig->{dateformat} eq 'mm/dd/yy') {
		return '%M/%d/%Y';		
	} elsif ($myconfig->{dateformat} eq 'dd-mm-yy') {
		return '%d-%M-%Y';		
	} elsif ($myconfig->{dateformat} eq 'dd/mm/yy') {
		return '%d/%M/%Y';		
	} elsif ($myconfig->{dateformat} eq 'yyyy-mm-dd') {
		return '%Y-%M-%d';		
	}
	return '';
}

sub format_dcn {
	my $self = shift;

	$_ = shift;

	my $str;
	my $modulo;
	my $var;
	my $padl;
	my $param;

	my @m = ( 0, 9, 4, 6, 8, 2, 7, 1, 3, 5 );
	my %m;
	my $m;
	my $e;
	my @e;
	my $i;

	my $d;
	my @n;
	my $n;
	my $w;
	my $cd;
	my $lr;

	for ( 0 .. $#m ) {
		@{ $m{$_} } = @m;
		$m = shift @m;
		push @m, $m;
	}

	if (/<%/) {

		while (/<%(.+?)%>/) {

			$param = $1;
			$str   = $param;

			( $var, $padl ) = split / /, $param;
			$padl *= 1;

			if ( $var eq 'membernumber' ) {

				$str = $self->{$var};
				$str =~ s/\W//g;
				$str = substr( '0' x $padl . $str, -$padl ) if $padl;

			}
			elsif ( $var =~ /modulo/ ) {

				$str = qq|\x01$str\x01|;

			}
			else {
				$i   = 0;
				$str = $self->{$var};
				$str =~ s/\D/++$i/ge;
				$str = substr( '0' x $padl . $str, -$padl ) if $padl;
			}

			s/<%$param%>/$str/;

		}

		/(.+?)\x01modulo/;
		$modulo = $1;

		while (/\x01(modulo.+?)\x01/) {

			$param = $1;

			@e = split //, $modulo;
			$str = "";

			if ( $param eq 'modulo10' ) {
				$e = 0;

				for $n (@e) {
					$e = $m{$e}[$n];
				}
				$str = substr( 10 - $e, -1 );
			}

			if ( $param =~ /modulo(1\d+)+?_/ ) {
				( $n, $w, $lr ) = split /_/, $param;
				$cd = 0;
				$m  = $1;

				if ( $lr eq 'right' ) {
					@e = reverse @e;
				}

				if ( $w eq '12' || $w eq '21' ) {
					@n = split //, $w;

					for $i ( 0 .. $#e ) {
						$n = $i % 2;
						if ( ( $d = $e[$i] * $n[$n] ) > 9 ) {
							for $n ( split //, $d ) {
								$cd += $n;
							}
						}
						else {
							$cd += $d;
						}
					}
				}
				else {
					@n = split //, $w;
					for $i ( 0 .. $#e ) {
						$n = $i % 2;
						$cd += $e[$i] * $n[$n];
					}
				}

				$str = $cd % $m;
				if ( $m eq '10' ) {
					if ( $str > 0 ) {
						$str = $m - $str;
					}
				}
			}

			s/\x01$param\x01/$str/;

			/(.+?)\x01modulo/;
			$modulo = $1;

		}

	}

	$_;

}

sub cleanup {
	my $self = shift;

	if ( !$self->{debuglatex} ) {
		chdir("$self->{tmpdir}");

		my @err = ();
		if ( -f "$self->{errfile}" ) {
			open( FH, "$self->{errfile}" );
			@err = <FH>;
			close(FH);
		}

		if ( $self->{tmpfile} ) {

			# strip extension
			$self->{tmpfile} =~ s/\.\w+$//g;
			my $tmpfile = $self->{tmpfile};
			unlink(<$tmpfile.*>);
			unlink(<"LATIN-$tmpfile.tex">);
		}

		chdir("$self->{cwd}");

		"@err";
	}
}

sub rerun_latex {
	my $self = shift;

	my $a = 0;
	if ( -f "$self->{errfile}" ) {
		open( FH, "$self->{errfile}" );
		$a = grep /(longtable Warning:|Warning:.*?LastPage)/, <FH>;
		close(FH);
	}

	$a;

}

sub format_string {
	my ( $self, @fields ) = @_;

	my $format = $self->{format};
	if ( $self->{format} =~ /(postscript|pdf)/ ) {
		$format = ( $self->{charset} =~ /utf/i ) ? 'utf' : 'tex';
	}

	my %replace = (
		'order' => {
			html => [ '<',  '>', '\n', '\r' ],
			txt  => [ '\n', '\r' ],
			tex  => [
				quotemeta('\\'), '&', '\n', '\r',
				'\$',            '%', '_',  '#',
				quotemeta('^'),  '{', '}',  '<',
				'>',             'ï¿½'
			],
			utf => [
				quotemeta('\\'), '&', '\n', '\r', '\$', '%', '_', '#',
				quotemeta('^'), '{', '}', '<', '>'
			]
		},
		html => {
			'<'  => '&lt;',
			'>'  => '&gt;',
			'\n' => '<br>',
			'\r' => '<br>'
		},
		txt => { '\n' => "\n", '\r' => "\r" },
		tex => {
			'&'             => '\&',
			'\$'            => '\$',
			'%'             => '\%',
			'_'             => '\_',
			'#'             => '\#',
			quotemeta('^')  => '\^\\',
			'{'             => '\{',
			'}'             => '\}',
			'<'             => '$<$',
			'>'             => '$>$',
			'\n'            => '\newline ',
			'\r'            => '\newline ',
			'ï¿½'            => '\pounds ',
			quotemeta('\\') => '/'
		}
	);

	$replace{utf} = $replace{tex};

	my $key;
	foreach $key ( @{ $replace{order}{$format} } ) {
		for (@fields) { $self->{$_} =~ s/$key/$replace{$format}{$key}/g }
	}

}

sub datediff {
	my ( $self, $myconfig, $date1, $date2 ) = @_;

	use Time::Local;

	my ( $yy1, $mm1, $dd1 );
	my ( $yy2, $mm2, $dd2 );

	if ( ( $date1 && $date1 =~ /\D/ ) && ( $date2 && $date2 =~ /\D/ ) ) {

		if ( $myconfig->{dateformat} =~ /^yy/ ) {
			( $yy1, $mm1, $dd1 ) = split /\D/, $date1;
			( $yy2, $mm2, $dd2 ) = split /\D/, $date2;
		}
		if ( $myconfig->{dateformat} =~ /^mm/ ) {
			( $mm1, $dd1, $yy1 ) = split /\D/, $date1;
			( $mm2, $dd2, $yy2 ) = split /\D/, $date2;
		}
		if ( $myconfig->{dateformat} =~ /^dd/ ) {
			( $dd1, $mm1, $yy1 ) = split /\D/, $date1;
			( $dd2, $mm2, $yy2 ) = split /\D/, $date2;
		}

		$dd1 *= 1;
		$dd2 *= 1;
		$mm1--;
		$mm2--;
		$mm1 *= 1;
		$mm2 *= 1;
		$yy1 += 2000 if length $yy1 == 2;
		$yy2 += 2000 if length $yy2 == 2;

	}

	sprintf(
		"%.0f",
		(
			timelocal( 0, 0, 12, $dd2, $mm2, $yy2 ) -
			  timelocal( 0, 0, 12, $dd1, $mm1, $yy1 )
		  ) / 86400
	);
}

sub datetonum {
	my ( $self, $myconfig, $date ) = @_;

	my ( $mm, $dd, $yy );

	if ( $date && $date =~ /\D/ ) {

		if ( $myconfig->{dateformat} =~ /^yy/ ) {
			( $yy, $mm, $dd ) = split /\D/, $date;
		}
		if ( $myconfig->{dateformat} =~ /^mm/ ) {
			( $mm, $dd, $yy ) = split /\D/, $date;
		}
		if ( $myconfig->{dateformat} =~ /^dd/ ) {
			( $dd, $mm, $yy ) = split /\D/, $date;
		}

		$dd *= 1;
		$mm *= 1;
		$yy += 2000 if length $yy == 2;

		$dd = substr( "0$dd", -2 );
		$mm = substr( "0$mm", -2 );

		$date = "$yy$mm$dd";
	}

	$date;

}

sub isvaldate {
	my ( $self, $myconfig, $date, $text ) = @_;
	if ($date) {
		my $cleandate = $self->dbclean($date);
		if ( $date ne $cleandate ) {
			$self->error($text);
		}
	}
}

sub isvaldateold {
	my ( $self, $myconfig, $date, $text ) = @_;

	if ($date) {
		my $spc = $myconfig->{dateformat};
		$spc =~ s/\w//g;
		$spc = substr( $spc, 0, 1 );

		if ( $myconfig->{dateformat} =~ /^yy/ ) {
			( $yy, $mm, $dd ) = split /\D/, $date;
		}
		if ( $myconfig->{dateformat} =~ /^mm/ ) {
			( $mm, $dd, $yy ) = split /\D/, $date;
		}
		if ( $myconfig->{dateformat} =~ /^dd/ ) {
			( $dd, $mm, $yy ) = split /\D/, $date;
		}

		$dd *= 1;
		$mm *= 1;
		$yy *= 1;

		$dd = substr( "0$dd", -2 );
		$mm = substr( "0$mm", -2 );

		if ( $myconfig->{dateformat} =~ /^yy/ ) {
			$date = "$yy$spc$mm$spc$dd";
		}
		if ( $myconfig->{dateformat} =~ /^mm/ ) {
			$date = "$mm$spc$dd$spc$yy";
		}
		if ( $myconfig->{dateformat} =~ /^dd/ ) {
			$date = "$dd$spc$mm$spc$yy";
		}
		$self->error($text) if $date eq '00/00/0';
	}
	$date;
}

sub add_date {
	my ( $self, $myconfig, $date, $repeat, $unit ) = @_;

	use Time::Local;

	my $diff = 0;
	my $spc  = $myconfig->{dateformat};
	$spc =~ s/\w//g;
	$spc = substr( $spc, 0, 1 );

	if ($date) {
		if ( $date =~ /\D/ ) {

			if ( $myconfig->{dateformat} =~ /^yy/ ) {
				( $yy, $mm, $dd ) = split /\D/, $date;
			}
			if ( $myconfig->{dateformat} =~ /^mm/ ) {
				( $mm, $dd, $yy ) = split /\D/, $date;
			}
			if ( $myconfig->{dateformat} =~ /^dd/ ) {
				( $dd, $mm, $yy ) = split /\D/, $date;
			}

		}
		else {

			# ISO
			$date =~ /(....)(..)(..)/;
			$yy = $1;
			$mm = $2;
			$dd = $3;
		}

		if ( $unit eq 'days' ) {
			$diff = $repeat * 86400;
		}
		if ( $unit eq 'weeks' ) {
			$diff = $repeat * 604800;
		}
		if ( $unit eq 'months' ) {
			$diff = $mm + $repeat;

			my $whole = int( $diff / 12 );
			$yy += $whole;

			$mm   = ( $diff % 12 ) + 1;
			$diff = 0;
		}
		if ( $unit eq 'years' ) {
			$yy++;
		}

		$mm--;

		@t = localtime( timelocal( 0, 0, 12, $dd, $mm, $yy ) + $diff );

		$t[4]++;
		$mm = substr( "0$t[4]", -2 );
		$dd = substr( "0$t[3]", -2 );
		$yy = $t[5] + 1900;

		if ( $date =~ /\D/ ) {

			if ( $myconfig->{dateformat} =~ /^yy/ ) {
				$date = "$yy$spc$mm$spc$dd";
			}
			if ( $myconfig->{dateformat} =~ /^mm/ ) {
				$date = "$mm$spc$dd$spc$yy";
			}
			if ( $myconfig->{dateformat} =~ /^dd/ ) {
				$date = "$dd$spc$mm$spc$yy";
			}

		}
		else {
			$date = "$yy$mm$dd";
		}
	}

	$date;

}

sub format_date {
	my ( $self, $dateformat, $date ) = @_;

	use Time::Local;

	my $spc = $dateformat;
	$spc =~ s/\w//g;
	$spc = substr( $spc, 0, 1 );

	# ISO
	$date =~ /(....)(..)(..)/;
	$yy = $1;
	$mm = $2;
	$dd = $3;

	if ($spc) {

		if ( $dateformat =~ /^yy/ ) {
			$date = "$yy$spc$mm$spc$dd";
		}
		if ( $dateformat =~ /^mm/ ) {
			$date = "$mm$spc$dd$spc$yy";
		}
		if ( $dateformat =~ /^dd/ ) {
			$date = "$dd$spc$mm$spc$yy";
		}

	}
	else {
		$date = "$yy$mm$dd";
	}

	$date;

}

sub print_button {
	my ( $self, $button, $name ) = @_;

	print
qq|<input class="submit noprint" type=submit name=action value="$button->{$name}{value}" accesskey="$button->{$name}{key}" title="$button->{$name}{value} [Alt-$button->{$name}{key}]">\n|;

}

# Database routines used throughout

sub dbconnect {
	my ( $self, $myconfig ) = @_;

	# connect to database
	my $dbh = DBI->connect(
		$myconfig->{dbconnect}, $myconfig->{dbuser},
		$myconfig->{dbpasswd}, { PrintError => 0 }
	) or $self->dberror;
	$dbh->{PrintError} = 0;

	# set db options
	if ( $myconfig->{dboptions} ) {
		$dbh->do( $myconfig->{dboptions} )
		  || $self->dberror( $myconfig->{dboptions} );
	}

	$dbh;

}

sub dbconnect_noauto {
	my ( $self, $myconfig ) = @_;

	# connect to database
	$dbh = DBI->connect(
		$myconfig->{dbconnect}, $myconfig->{dbuser},
		$myconfig->{dbpasswd}, { PrintError => 0, AutoCommit => 0 }
	) or $self->dberror;

	# set db options
	if ( $myconfig->{dboptions} ) {
		$dbh->do( $myconfig->{dboptions} );
	}

	$dbh;

}

sub param {
	my ( $self, $fldname ) = @_;
	return $self->{$fldname};
}

sub dbquote {
	my ( $self, $var, $type ) = @_;

	$var =~ s/;/\\;/g;

	# DBI does not return NULL for SQL_DATE if the date is empty
	if ( $type eq 'SQL_DATE' ) {
		$_ = ($var) ? "'" . $self->dbclean($var) . "'" : "NULL";
	}
	if ( $type eq 'SQL_INT' ) {
		$_ = $var * 1;
	}

	$_;

}

sub update_balance {
	my ( $self, $dbh, $table, $field, $where, $value ) = @_;

	# if we have a value, go do it
	if ($value) {

		# retrieve balance from table
		my $query = "SELECT $field FROM $table WHERE $where FOR UPDATE";
		my ($balance) = $dbh->selectrow_array($query);

		$balance += $value;

		# update balance
		$query = "UPDATE $table SET $field = $balance WHERE $where";
		$dbh->do($query) || $self->dberror($query);
	}
}

sub update_exchangerate {
	my ( $self, $dbh, $curr, $transdate, $buy, $sell ) = @_;

	# some sanity check for currency
	return if ( !$curr || $self->{currency} eq $self->{defaultcurrency} );

	my $query = qq|SELECT curr FROM exchangerate
                 WHERE curr = | . $dbh->quote($curr) . qq|
	         AND transdate = '$transdate'
		 FOR UPDATE|;
	my $sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	my $set;
	if ( $buy && $sell ) {
		$set = "buy = $buy, sell = $sell";
	}
	elsif ($buy) {
		$set = "buy = $buy";
	}
	elsif ($sell) {
		$set = "sell = $sell";
	}

	if ( $sth->fetchrow_array ) {
		$query = qq|UPDATE exchangerate
                SET $set
		WHERE curr = '$curr'
		AND transdate = '$transdate'|;
	}
	else {
		$query = qq|INSERT INTO exchangerate (curr, buy, sell, transdate)
                VALUES ('$curr', $buy, $sell, '$transdate')|;
	}
	$sth->finish;

	$dbh->do($query) || $self->dberror($query);

}

sub save_exchangerate {
	my ( $self, $myconfig, $currency, $transdate, $rate, $fld ) = @_;

	my $dbh = $self->dbconnect($myconfig);

	my ( $buy, $sell ) = ( 0, 0 );
	$buy  = $rate if $fld eq 'buy';
	$sell = $rate if $fld eq 'sell';

	$self->update_exchangerate( $dbh, $currency, $transdate, $buy, $sell );

	$dbh->disconnect;

}

sub get_exchangerate {
	my ( $self, $myconfig, $dbh, $curr, $transdate, $fld ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	my $exchangerate = 1;

	if ($transdate) {
		my $query = qq|SELECT $fld FROM exchangerate
		   WHERE curr = '$curr'
		   AND transdate = '$transdate'|;
		($exchangerate) = $dbh->selectrow_array($query);
	}

	$dbh->disconnect if $disconnect;

	$exchangerate;

}

sub check_exchangerate {
	my ( $self, $myconfig, $currency, $transdate, $fld ) = @_;

	return "" if !$transdate || $self->{defaultcurrency} eq $currency;

	my $dbh = $self->dbconnect($myconfig);

	my $query;
	my $exchangerate;

	$fld ||= 'buy';
	$query = qq|SELECT $fld, buy, sell FROM exchangerate
	      WHERE curr = | . $dbh->quote($currency) . qq|
	      AND transdate = | . $self->dbquote( $transdate, SQL_DATE );
	( $exchangerate, $self->{fxbuy}, $self->{fxsell} ) =
	  $dbh->selectrow_array($query);

	$query = qq|SELECT precision FROM curr
              WHERE curr = '$currency'|;
	( $self->{precision} ) = $dbh->selectrow_array($query);

	$dbh->disconnect;

	$exchangerate;

}

sub add_shipto {
	my ( $self, $dbh, $id ) = @_;

	my $shipto;
	foreach my $item (
		qw(name address1 address2 city state zipcode country contact phone fax email)
	  )
	{
		if ( $self->{"shipto$item"} ne "" ) {
			$shipto = 1 if ( $self->{$item} ne $self->{"shipto$item"} );
		}
	}

	if ($shipto) {
		my $query = qq|INSERT INTO shipto (trans_id, shiptoname, shiptoaddress1,
                   shiptoaddress2, shiptocity, shiptostate,
		   shiptozipcode, shiptocountry, shiptocontact,
		   shiptophone, shiptofax, shiptoemail) VALUES ($id, |
		  . $dbh->quote( $self->{shiptoname} ) . qq|, |
		  . $dbh->quote( $self->{shiptoaddress1} ) . qq|, |
		  . $dbh->quote( $self->{shiptoaddress2} ) . qq|, |
		  . $dbh->quote( $self->{shiptocity} ) . qq|, |
		  . $dbh->quote( $self->{shiptostate} ) . qq|, |
		  . $dbh->quote( $self->{shiptozipcode} ) . qq|, |
		  . $dbh->quote( $self->{shiptocountry} ) . qq|, |
		  . $dbh->quote( $self->{shiptocontact} ) . qq|, |
		  . $dbh->quote( $self->{shiptophone} ) . qq|, |
		  . $dbh->quote( $self->{shiptofax} ) . qq|, |
		  . $dbh->quote( $self->{shiptoemail} ) . qq|)|;
		$dbh->do($query) || $self->dberror($query);
	}

}

sub get_employee {
	my ( $self, $dbh ) = @_;

	my $login = $self->{login};
	$login =~ s/@.*//;
	my $query = qq|SELECT name, id FROM employee 
                 WHERE login = '$login'|;
	my (@a) = $dbh->selectrow_array($query);
	$a[1] *= 1;

	@a;

}

# this sub gets the id and name from $table
sub get_name {
	my ( $self, $myconfig, $table, $transdate ) = @_;

	# connect to database
	my $dbh = $self->dbconnect($myconfig);

	my $where = "1=1";
	if ($transdate) {
		$where .= qq| AND (ct.startdate IS NULL OR ct.startdate <= '$transdate')
                  AND (ct.enddate IS NULL OR ct.enddate >= '$transdate')|;
	}

	my %defaults = $self->get_defaults( $dbh, \@{ ['namesbynumber'] } );

	my $sortorder = "name";
	$sortorder = $self->{searchby} if $self->{searchby};

	my $var;

	if ( $sortorder eq 'name' ) {
		$var = $self->like( lc $self->{$table} );
		$where .= qq| AND lower(ct.name) LIKE '$var'|;
	}
	else {
		$var = $self->like( lc $self->{"${table}number"} );
		$where .= qq| AND lower(ct.${table}number) LIKE '$var'|;
	}

	if ( $defaults{namesbynumber} ) {
		$sortorder = "${table}number";
	}

	my $query = qq|SELECT ct.*,
                 ad.address1, ad.address2, ad.city, ad.state,
		 ad.zipcode, ad.country
                 FROM $table ct
		 JOIN address ad ON (ad.trans_id = ct.id)
		 WHERE $where
		 ORDER BY $sortorder|;

	my $sth = $dbh->prepare($query);

	$sth->execute || $self->dberror($query);

	my $i = 0;
	@{ $self->{name_list} } = ();
	while ( $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push( @{ $self->{name_list} }, $ref );
		$i++;
	}
	$sth->finish;
	$dbh->disconnect;

	$i;

}

sub get_currencies {
	my ( $self, $dbh, $myconfig ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	my $currencies;
	my $curr;
	my $precision;

	my $query = qq|SELECT curr, precision FROM curr
                 ORDER BY rn|;
	my $sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	while ( ( $curr, $precision ) = $sth->fetchrow_array ) {
		if ( $self->{currency} eq $curr ) {
			$self->{precision} = $precision;
		}
		$currencies .= "$curr:";
	}
	$sth->finish;

	$dbh->disconnect if $disconnect;

	chop $currencies;
	$currencies;

}

# bp 2010/02/10
sub get_precision {
	my ( $self, $myconfig, $currency ) = @_;

	return "" if $self->{defaultcurrency} eq $currency;

	my $dbh = $self->dbconnect($myconfig);

	my $precision;

	$query = qq|SELECT precision FROM curr
              WHERE curr = '$currency'|;

	$precision = $dbh->selectrow_array($query);

	$dbh->disconnect;

	$precision;

}

sub get_defaults {
	my ( $self, $dbh, $flds ) = @_;

	my $query;
	my %defaults;

	if ( @{$flds} ) {
		$query = qq|SELECT * FROM defaults
                WHERE fldname LIKE '$flds->[0]'|;
		shift @{$flds};

		for ( @{$flds} ) {
			$query .= qq| OR fldname LIKE '$_'|;
		}
	}
	else {
		$query = qq|SELECT * FROM defaults|;
	}

	my $sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		$defaults{ $ref->{fldname} } = $ref->{fldvalue};
	}
	$sth->finish;

	%defaults;

}

sub all_vc {
	my ( $self, $myconfig, $vc, $module, $dbh, $transdate, $job, $openinv ) =
	  @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	my $sth;
	my $ref;

	my $query;
	my $arap = lc $module;
	my $joinarap;
	my $where = "1 = 1";

	if ($transdate) {
		$where .= qq| AND (vc.startdate IS NULL OR vc.startdate <= '$transdate')
                  AND (vc.enddate IS NULL OR vc.enddate >= '$transdate')|;
	}
	if ($openinv) {
		$joinarap = "JOIN $arap a ON (a.${vc}_id = vc.id)";
		$where .= " AND a.amount != a.paid";
	}
	$query .= qq|SELECT count(*) FROM $vc vc
               $joinarap
               WHERE $where|;
	my ($count) = $dbh->selectrow_array($query);

	$form->{vc} = 'customer' if $form->{vc} ne 'vendor';    # SQLI protection

	# build selection list
	if ( $count < $myconfig->{vclimit} ) {
		$self->{"${vc}_id"} *= 1;

		# ISNA: 00021 tekki
		$query =
		  qq|SELECT vc.id, vc.name, c.firstname, c.lastname, c.typeofcontact,
		  ad.city, ad.address1, ${vc}number
		FROM $vc vc
		LEFT JOIN contact c
		  ON vc.id=c.trans_id AND c.typeofcontact='company'
		LEFT JOIN address ad
		  ON vc.id=ad.trans_id
		$joinarap
		WHERE $where
		UNION SELECT vc.id, vc.name, c.firstname, c.lastname, c.typeofcontact,
		  ad.city, ad.address1, ${vc}number
		FROM $vc vc
		LEFT JOIN contact c
		  ON vc.id=c.trans_id AND c.typeofcontact='company' 
		LEFT JOIN address ad
		  ON vc.id=ad.trans_id
		WHERE vc.id = $self->{"${vc}_id"}
		ORDER BY name, lastname, firstname|;

		# ISNA_end
		$sth = $dbh->prepare($query);
		$sth->execute || $self->dberror($query);

		@{ $self->{"all_$vc"} } = ();
		while ( $ref = $sth->fetchrow_hashref(NAME_lc) ) {

			# ISNA: 00021 tekki
			my $name_ext;
			if ( $ref->{typeofcontact} eq 'company' ) {
				$name_ext = "$ref->{lastname} $ref->{firstname}, $ref->{city}";
			}
			else {
				$name_ext = "$ref->{city}, $ref->{address1}";
			}
			$name_ext =~ s/^\s+//;
			$name_ext =~ s/\s+$//;
			$name_ext =~ s/^, //;
			$name_ext =~ s/,$//;

			$ref->{name} .= " $name_ext" if $name_ext;
			$ref->{name} =~ s/(.{64}).*/$1/;

			# ISNA_end
			push @{ $self->{"all_$vc"} }, $ref;
		}
		$sth->finish;

	}

	# get self
	if ( !$self->{employee_id} ) {
		( $self->{employee}, $self->{employee_id} ) = split /--/,
		  $self->{employee};
		( $self->{employee}, $self->{employee_id} ) = $self->get_employee($dbh)
		  unless $self->{employee_id};
	}

	$self->all_employees( $myconfig, $dbh, $transdate, 1 );

	$self->all_departments( $myconfig, $dbh, $vc );

	$self->all_warehouses( $myconfig, $dbh, $vc );

	$self->all_projects( $myconfig, $dbh, $transdate, $job );

	$self->all_languages( $myconfig, $dbh );

	$self->all_taxaccounts( $myconfig, $dbh, $transdate );

	$dbh->disconnect if $disconnect;

}

sub all_languages {
	my ( $self, $myconfig, $dbh ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}
	my $sth;
	my $query;

	$query = qq|SELECT *
              FROM language
	      ORDER BY 2|;
	$sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	$self->{all_language} = ();
	while ( $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push @{ $self->{all_language} }, $ref;
	}
	$sth->finish;

	$dbh->disconnect if $disconnect;

}

sub all_taxaccounts {
	my ( $self, $myconfig, $dbh, $transdate ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}
	my $sth;
	my $query;
	my $where;

	# SQLI protection: transdate validation needs to be checked
	if ($transdate) {
		$where = qq| AND (t.validto >= '$transdate' OR t.validto IS NULL)|;
	}

	if ( $self->{taxaccounts} ) {

		# rebuild tax rates
		$query = qq|SELECT t.rate, t.taxnumber
                FROM tax t
		JOIN chart c ON (c.id = t.chart_id)
		WHERE c.accno = ?
		$where
		ORDER BY accno, validto|;
		$sth = $dbh->prepare($query) || $self->dberror($query);

		foreach my $accno ( split / /, $self->{taxaccounts} ) {
			$sth->execute("$accno");
			( $self->{"${accno}_rate"}, $self->{"${accno}_taxnumber"} ) =
			  $sth->fetchrow_array;
			$sth->finish;
		}
	}

	$dbh->disconnect if $disconnect;

}

sub all_employees {
	my ( $self, $myconfig, $dbh, $transdate, $sales ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	# setup employees/sales contacts
	my $query = qq|SELECT id, name
 	         FROM employee
		 WHERE 1 = 1|;

	# SQLI protection: transdate validation needs to be checked
	if ($transdate) {
		$query .= qq| AND (startdate IS NULL OR startdate <= '$transdate')
                  AND (enddate IS NULL OR enddate >= '$transdate')|;
	}
	else {
		$query .= qq| AND enddate IS NULL|;
	}

	if ($sales) {
		$query .= qq| AND sales = '1'|;
	}

	$query .= qq|
	         ORDER BY name|;
	my $sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push @{ $self->{all_employee} }, $ref;
	}
	$sth->finish;

	$dbh->disconnect if $disconnect;

}

sub all_projects {
	my ( $self, $myconfig, $dbh, $transdate, $job ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	my $where = "1 = 1";

	$where = qq|id NOT IN (SELECT id
                         FROM parts
			 WHERE project_id > 0)| if !$job;

	my $query = qq|SELECT *
                 FROM project
		 WHERE $where|;

	if ( $form->{language_code} ) {
		$query = qq|SELECT pr.*, t.description AS translation
                FROM project pr
		LEFT JOIN translation t ON (t.trans_id = pr.id)
		WHERE t.language_code = | . $dbh->quote( $form->{language_code} );
	}

	# SQLI protection: transdate validation needs to be checked
	if ($transdate) {
		$query .= qq| AND (startdate IS NULL OR startdate <= '$transdate')
                  AND (enddate IS NULL OR enddate >= '$transdate')|;
	}

	$query .= qq|
	         ORDER BY projectnumber|;

	$sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	@{ $self->{all_project} } = ();
	while ( $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push @{ $self->{all_project} }, $ref;
	}
	$sth->finish;

	$dbh->disconnect if $disconnect;

}

sub all_departments {
	my ( $self, $myconfig, $dbh, $vc ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	my $where = "1 = 1";

	if ($vc) {
		if ( $vc eq 'customer' ) {
			$where = " role = 'P'";
		}
	}

	my $query = qq|SELECT id, description
                 FROM department
	         WHERE $where
	         ORDER BY 2|;
	my $sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	@{ $self->{all_department} } = ();
	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push @{ $self->{all_department} }, $ref;
	}
	$sth->finish;

	$self->all_years( $myconfig, $dbh );

	$dbh->disconnect if $disconnect;

}

sub all_warehouses {
	my ( $self, $myconfig, $dbh, $vc ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	my $query = qq|SELECT id, description
                 FROM warehouse
	         ORDER BY 2|;
	my $sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	@{ $self->{all_warehouse} } = ();
	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push @{ $self->{all_warehouse} }, $ref;
	}
	$sth->finish;

	$dbh->disconnect if $disconnect;

}

sub all_years {
	my ( $self, $myconfig, $dbh ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	# get years
	my $query       = qq|SELECT MIN(transdate) FROM acc_trans|;
	my ($startdate) = $dbh->selectrow_array($query);
	my $query       = qq|SELECT MAX(transdate) FROM acc_trans|;
	my ($enddate)   = $dbh->selectrow_array($query);

	if ( $myconfig->{dateformat} =~ /^yy/ ) {
		($startdate) = split /\W/, $startdate;
		($enddate)   = split /\W/, $enddate;
	}
	else {
		(@_) = split /\W/, $startdate;
		$startdate = $_[2];
		(@_) = split /\W/, $enddate;
		$enddate = $_[2];
	}

	$self->{all_years} = ();
	$startdate = substr( $startdate, 0, 4 );
	$enddate   = substr( $enddate,   0, 4 );

	if ($startdate) {
		while ( $enddate >= $startdate ) {
			push @{ $self->{all_years} }, $enddate--;
		}
	}

	%{ $self->{all_month} } = (
		'01' => 'January',
		'02' => 'February',
		'03' => 'March',
		'04' => 'April',
		'05' => 'May ',
		'06' => 'June',
		'07' => 'July',
		'08' => 'August',
		'09' => 'September',
		'10' => 'October',
		'11' => 'November',
		'12' => 'December'
	);

	my %defaults =
	  $self->get_defaults( $dbh, \@{ [qw(method precision namesbynumber)] } );
	for ( keys %defaults ) { $self->{$_} = $defaults{$_} }
	$self->{method} ||= "accrual";

	$dbh->disconnect if $disconnect;

}

sub closedto_user {
	my ( $self, $myconfig, $dbh ) = @_;
    $login = $self->{login};
    $login =~ s/@.*//;
    $self->{closedto_user} = $dbh->selectrow_array("SELECT closedto FROM employee WHERE login = '$login'");
    if ($self->{closedto_user}){
        $self->{closedto_user} = $self->datetonum($myconfig, $self->{closedto_user});
        if ($self->{closedto}){
           $self->{closedto} = $self->{closedto_user} if $self->{closedto} < $self->{closedto_user};
        } else {
           $self->{closedto} = $self->{closedto_user};
        }
    }
}

sub create_links {
	my ( $self, $module, $myconfig, $vc, $job ) = @_;

	# get last customers or vendors
	my ( $query, $sth );

	my $dbh = $self->dbconnect($myconfig);

	my %xkeyref = ();

	$vc = 'customer' if $vc ne 'vendor';    #SQLI protection

	my %defaults =
	  $self->get_defaults( $dbh,
		\@{ [qw(closedto revtrans weightunit cdt precision showtaxper)] } );
	for ( keys %defaults ) { $self->{$_} = $defaults{$_} }
    $self->closedto_user($myconfig, $dbh);

	# now get the account numbers
	$query = qq|SELECT c.accno, c.description, c.link,
              l.description AS translation
              FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      WHERE c.link LIKE '%$module%'
	      ORDER BY c.accno|;
	$sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	$self->{accounts} = "";
	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {

		foreach my $key ( split /:/, $ref->{link} ) {
			if ( $key =~ /$module/ ) {

				# cross reference for keys
				$xkeyref{ $ref->{accno} } = $key;

				$ref->{description} = $ref->{translation}
				  if $ref->{translation};

				push @{ $self->{"${module}_links"}{$key} },
				  {
					accno       => $ref->{accno},
					description => $ref->{description}
				  };

				$self->{accounts} .= "$ref->{accno} " if $key !~ /tax/;
			}
		}
	}
	$sth->finish;

	my $arap = ( $vc eq 'customer' ) ? 'ar' : 'ap';

	$self->remove_locks( $myconfig, $dbh );

	if ( $self->{id} *= 1 ) {

		$query = qq|SELECT a.invnumber, a.transdate,
                a.${vc}_id, a.datepaid, a.duedate, a.ordnumber,
		a.taxincluded, a.curr AS currency, a.notes, a.intnotes,
		a.terms, a.cashdiscount, a.discountterms,
		c.name AS $vc, c.${vc}number, a.department_id,
		d.description AS department,
		a.amount AS oldinvtotal, a.paid AS oldtotalpaid,
		a.employee_id, e.name AS employee, a.language_code,
		a.ponumber, a.approved,
		br.id AS batchid, br.description AS batchdescription,
		a.description, a.onhold, a.exchangerate, a.dcn,
		ch.accno AS bank_accno, ch.description AS bank_accno_description,
		t.description AS bank_accno_translation,
		pm.description AS paymentmethod, a.paymentmethod_id
		FROM $arap a
		JOIN $vc c ON (a.${vc}_id = c.id)
		LEFT JOIN employee e ON (e.id = a.employee_id)
		LEFT JOIN department d ON (d.id = a.department_id)
		LEFT JOIN vr ON (vr.trans_id = a.id)
		LEFT JOIN br ON (br.id = vr.br_id)
		LEFT JOIN chart ch ON (ch.id = a.bank_id)
		LEFT JOIN translation t ON (t.trans_id = ch.id AND t.language_code = '$myconfig->{countrycode}')
		LEFT JOIN paymentmethod pm ON (pm.id = a.paymentmethod_id)
		WHERE a.id = $self->{id}|;
		$sth = $dbh->prepare($query);
		$sth->execute || $self->dberror($query);

		$ref = $sth->fetchrow_hashref(NAME_lc);

		$ref->{exchangerate} ||= 1;

		for (qw(oldinvtotal oldtotalpaid)) {
			$ref->{$_} = $self->round_amount( $ref->{$_} / $ref->{exchangerate},
				$self->{precision} );
		}
		foreach $key ( keys %$ref ) {
			$self->{$key} = $ref->{$key};
		}
		$sth->finish;

		if ( $self->{bank_accno} ) {
			$self->{payment_accno} =
			  ( $self->{bank_accno_translation} )
			  ? "$self->{bank_accno}--$self->{bank_accno_translation}"
			  : "$self->{bank_accno}--$self->{bank_accno_description}";
		}

		if ( $self->{paymentmethod_id} ) {
			$self->{payment_method} =
			  "$self->{paymentmethod}--$self->{paymentmethod_id}";
		}

		# get printed, emailed
		$query = qq|SELECT s.printed, s.emailed, s.spoolfile, s.formname
                FROM status s
		WHERE s.trans_id = $self->{id}|;
		$sth = $dbh->prepare($query);
		$sth->execute || $self->dberror($query);

		while ( $ref = $sth->fetchrow_hashref(NAME_lc) ) {
			$self->{printed} .= "$ref->{formname} " if $ref->{printed};
			$self->{emailed} .= "$ref->{formname} " if $ref->{emailed};
			$self->{queued} .= "$ref->{formname} $ref->{spoolfile} "
			  if $ref->{spoolfile};
		}
		$sth->finish;
		for (qw(printed emailed queued)) { $self->{$_} =~ s/ +$//g }

		# get recurring
		$self->get_recurring($dbh);

		# get amounts from individual entries
		$query = qq|SELECT c.accno, c.description, ac.source, ac.amount,
                ac.memo, ac.transdate, ac.cleared, ac.project_id,
		p.projectnumber, ac.id, y.exchangerate,
		l.description AS translation,
		pm.description AS paymentmethod, y.paymentmethod_id, ac.tax, ac.taxamount
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		LEFT JOIN project p ON (p.id = ac.project_id)
		LEFT JOIN payment y ON (y.trans_id = ac.trans_id AND ac.id = y.id)
		LEFT JOIN paymentmethod pm ON (pm.id = y.paymentmethod_id)
		LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		WHERE ac.trans_id = $self->{id}
		AND ac.fx_transaction = '0'
		ORDER BY ac.transdate|;
		$sth = $dbh->prepare($query);
		$sth->execute || $self->dberror($query);

		# store amounts in {acc_trans}{$key} for multiple accounts
		while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
			$ref->{description} = $ref->{translation} if $ref->{translation};
			$ref->{exchangerate} ||= 1;
			push @{ $self->{acc_trans}{ $xkeyref{ $ref->{accno} } } }, $ref;
		}
		$sth->finish;

		$self->create_lock( $myconfig, $dbh, $self->{id}, $arap );

	}
	else {

		# get date
		if ( !$self->{transdate} ) {
			$self->{transdate} = $self->current_date($myconfig);
		}
		if ( !$self->{"$self->{vc}_id"} ) {
			$self->lastname_used( $myconfig, $dbh, $vc, $module );
		}

	}

	$self->all_vc( $myconfig, $vc, $module, $dbh, $self->{transdate}, $job );

	$self->{currencies} = $self->get_currencies( $dbh, $myconfig );

	# get paymentmethod
	$query = qq|SELECT *
	      FROM paymentmethod
	      ORDER BY rn|;
	$sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	@{ $self->{"all_paymentmethod"} } = ();
	while ( $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push @{ $self->{"all_paymentmethod"} }, $ref;
	}
	$sth->finish;

	$dbh->disconnect;

}

sub create_lock {
	my ( $self, $myconfig, $dbh, $id, $module ) = @_;

	my $query;
	my $expires = time;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	# remove expired locks
	$query = qq|DELETE FROM semaphore
              WHERE expires < '$expires'|;
	$dbh->do($query) || $self->dberror($query);

	$expires = time + $myconfig->{timeout};

	if ($id) {
		$query = qq|SELECT id, login FROM semaphore
		WHERE id = $id|;
		my ( $readonly, $login ) = $dbh->selectrow_array($query);

		if ($readonly) {
			$login =~ s/@.*//;
			$query = qq|SELECT name FROM employee
		  WHERE login = '$login'|;
			( $self->{haslock} ) = $dbh->selectrow_array($query);
			$self->{readonly} = 1;
		}
		else {
			$query = qq|INSERT INTO semaphore (id, login, module, expires)
		  VALUES ($id, '$self->{login}', '$module', '$expires')|;
			$dbh->do($query) || $self->dberror($query);
		}
	}

	$dbh->disconnect if $disconnect;

}

sub remove_locks {
	my ( $self, $myconfig, $dbh, $module ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	# SQLI protection. $module validation needs to be checked
	my $query = qq|DELETE FROM semaphore
	         WHERE login = '$self->{login}'|;
	$query .= qq|
		 AND module = '$module'| if $module;
	$dbh->do($query) || $self->dberror($query);

	$dbh->disconnect if $disconnect;

}

sub lastname_used {
	my ( $self, $myconfig, $dbh, $vc, $module ) = @_;

	$vc = 'customer' if $vc ne 'vendor';    # SQLI protection

	my $arap = ( $vc eq 'customer' ) ? "ar" : "ap";
	my $where = "1 = 1";
	my $sth;

	if ( $self->{type} =~ /_order/ ) {
		$arap  = 'oe';
		$where = "quotation = '0'";
	}
	if ( $self->{type} =~ /_quotation/ ) {
		$arap  = 'oe';
		$where = "quotation = '1'";
	}

	my $query = qq|SELECT id FROM $arap
                 WHERE id IN (SELECT MAX(id) FROM $arap
		              WHERE $where
			      AND ${vc}_id > 0)|;
	my ($trans_id) = $dbh->selectrow_array($query);

	$trans_id *= 1;

	my $duedate;
	if ( $myconfig->{dbdriver} eq 'DB2' ) {
		$duedate =
		  ( $self->{transdate} )
		  ? qq|date '$self->{transdate}' + ct.terms DAYS|
		  : qq|current_date + ct.terms DAYS|;
	}
	elsif ( $myconfig->{dbdriver} eq 'Sybase' ) {
		$duedate =
		  ( $self->{transdate} )
		  ? qq|dateadd($myconfig->{dateformat}, ct.terms DAYS, $self->{transdate})|
		  : qq|dateadd($myconfig->{dateformat}, ct.terms DAYS, current_date)|;
	}
	else {
		$duedate =
		  ( $self->{transdate} )
		  ? qq|date '$self->{transdate}' + ct.terms|
		  : qq|current_date + ct.terms|;
	}

	$query = qq|SELECT ct.name AS $vc, ct.${vc}number, a.curr AS currency,
              a.${vc}_id,
              $duedate AS duedate, a.department_id,
	      d.description AS department, ct.notes AS intnotes,
	      ct.curr AS currency, ct.remittancevoucher
	      FROM $arap a
	      JOIN $vc ct ON (a.${vc}_id = ct.id)
	      LEFT JOIN department d ON (a.department_id = d.id)
	      WHERE a.id = $trans_id|;
	$sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	my $ref = $sth->fetchrow_hashref(NAME_lc);
	for ( keys %$ref ) { $self->{$_} = $ref->{$_} }
	$sth->finish;

}

sub current_date {
	my ( $self, $myconfig, $date ) = @_;

	use Time::Local;

	my $spc = $myconfig->{dateformat};
	$spc =~ s/\w//g;
	$spc = substr( $spc, 0, 1 );
	my @t = localtime;
	my $dd;
	my $mm;
	my $yy;

	if ($date) {
		if ( $date =~ /\D/ ) {

			if ( $myconfig->{dateformat} =~ /^yy/ ) {
				( $yy, $mm, $dd ) = split /\D/, $date;
			}
			if ( $myconfig->{dateformat} =~ /^mm/ ) {
				( $mm, $dd, $yy ) = split /\D/, $date;
			}
			if ( $myconfig->{dateformat} =~ /^dd/ ) {
				( $dd, $mm, $yy ) = split /\D/, $date;
			}

		}
		else {

			# ISO
			$date =~ /(....)(..)(..)/;
			$yy = $1;
			$mm = $2;
			$dd = $3;
		}

		$mm--;
		@t = ( 1, 0, 0, $dd, $mm, $yy );
	}

	@t = localtime( timelocal(@t) );

	$t[4]++;
	$mm = substr( "0$t[4]", -2 );
	$dd = substr( "0$t[3]", -2 );
	$yy = $t[5] + 1900;

	if ( $myconfig->{dateformat} =~ /\D/ ) {

		if ( $myconfig->{dateformat} =~ /^yy/ ) {
			$date = "$yy$spc$mm$spc$dd";
		}
		if ( $myconfig->{dateformat} =~ /^mm/ ) {
			$date = "$mm$spc$dd$spc$yy";
		}
		if ( $myconfig->{dateformat} =~ /^dd/ ) {
			$date = "$dd$spc$mm$spc$yy";
		}

	}
	else {
		$date = "$yy$mm$dd";
	}

	$date;

}

sub like {
	my ( $self, $str ) = @_;

	$str =~ s/;/\\;/g;

	if ( $str !~ /(%|_)/ ) {
		if ( $str =~ /(^").*("$)/ ) {
			$str =~ s/(^"|"$)//g;
		}
		else {
			$str = "%$str%";
		}
	}

	$str =~ s/'/''/g;
	$str;

}

sub redo_rows {
	my ( $self, $flds, $new, $count, $numrows ) = @_;

	my @ndx = ();

	for ( 1 .. $count ) {
		push @ndx, { num => $new->[ $_ - 1 ]->{runningnumber}, ndx => $_ };
	}

	my $i = 0;

	# fill rows
	foreach my $item ( sort { $a->{num} <=> $b->{num} } @ndx ) {
		$i++;
		$j = $item->{ndx} - 1;
		for ( @{$flds} ) { $self->{"${_}_$i"} = $new->[$j]->{$_} }
	}

	# delete empty rows
	for $i ( $count + 1 .. $numrows ) {
		for ( @{$flds} ) { delete $self->{"${_}_$i"} }
	}

}

sub get_partsgroup {
	my ( $self, $myconfig, $p ) = @_;

	my $dbh = $self->dbconnect($myconfig);

	my $query = qq|SELECT DISTINCT pg.*
                 FROM partsgroup pg
		 JOIN parts p ON (p.partsgroup_id = pg.id)|;
	my $where     = qq|WHERE p.obsolete = '0'|;
	my $sortorder = "partsgroup";

	if ( $p->{searchitems} eq 'part' ) {
		$where .= qq|
                 AND (p.inventory_accno_id > 0
		        AND p.income_accno_id > 0)|;
	}
	if ( $p->{searchitems} eq 'service' ) {
		$where .= qq|
                 AND p.inventory_accno_id IS NULL|;
	}
	if ( $p->{searchitems} eq 'assembly' ) {
		$where .= qq|
                 AND p.assembly = '1'|;
	}
	if ( $p->{searchitems} eq 'labor' ) {
		$where .= qq|
                 AND p.inventory_accno_id > 0 AND p.income_accno_id IS NULL|;
	}
	if ( $p->{searchitems} eq 'nolabor' ) {
		$where .= qq|
                 AND p.income_accno_id > 0|;
	}

	if ( $p->{all} ) {
		$query = qq|SELECT id, partsgroup, pos
                FROM partsgroup|;
		$where = "";
	}

	if ( $p->{language_code} ) {
		$sortorder = "translation";

		$query = qq|SELECT DISTINCT pg.*, t.description AS translation
		FROM partsgroup pg
		JOIN parts p ON (p.partsgroup_id = pg.id)
		LEFT JOIN translation t ON (t.trans_id = pg.id AND t.language_code = '$p->{language_code}')|;
	}

	$query .= qq| $where
		 ORDER BY $sortorder|;

	my $sth = $dbh->prepare($query);
	$sth->execute || $self->dberror($query);

	$self->{all_partsgroup} = ();
	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		push @{ $self->{all_partsgroup} }, $ref;
	}
	$sth->finish;

	my %defaults = $self->get_defaults( $dbh, \@{ ['method'] } );
	$self->{method} = ( $defaults{method} ) ? $defaults{method} : "accrual";

	$dbh->disconnect;

}

sub update_status {
	my ( $self, $myconfig ) = @_;

	# no id return
	$self->{id} *= 1;
	return unless $self->{id};

	my $dbh = $self->dbconnect_noauto($myconfig);

	my %queued = split / +/, $self->{queued};
	my $spoolfile =
	  ( $queued{ $self->{formname} } )
	  ? "'$queued{$self->{formname}}'"
	  : 'NULL';
	my $query = qq|DELETE FROM status
 	         WHERE formname = '$self->{formname}'
	         AND trans_id = $self->{id}|;
	$dbh->do($query) || $self->dberror($query);

	my $printed = ( $self->{printed} =~ /$self->{formname}/ ) ? "1" : "0";
	my $emailed = ( $self->{emailed} =~ /$self->{formname}/ ) ? "1" : "0";

	$query = qq|INSERT INTO status (trans_id, printed, emailed,
	      spoolfile, formname) VALUES ($self->{id}, '$printed',
	      '$emailed', $spoolfile,
	      '$self->{formname}')|;
	$dbh->do($query) || $self->dberror($query);

	$dbh->commit;
	$dbh->disconnect;

}

sub save_status {
	my ( $self, $dbh ) = @_;

	my $formnames  = $self->{printed};
	my $emailforms = $self->{emailed};

	$self->{id} *= 1;

	my $query = qq|DELETE FROM status
		 WHERE trans_id = $self->{id}|;
	$dbh->do($query) || $self->dberror($query);

	my %queued;
	my $formname;

	if ( $self->{queued} ) {
		%queued = split / +/, $self->{queued};

		foreach $formname ( keys %queued ) {

			$printed = ( $self->{printed} =~ /$formname/ ) ? "1" : "0";
			$emailed = ( $self->{emailed} =~ /$formname/ ) ? "1" : "0";

			if ( $queued{$formname} ) {
				$query = qq|INSERT INTO status (trans_id, printed, emailed,
		    spoolfile, formname)
		    VALUES ($self->{id}, '$printed', '$emailed',
		    '$queued{$formname}', '$formname')|;
				$dbh->do($query) || $self->dberror($query);
			}

			$formnames  =~ s/$formname//;
			$emailforms =~ s/$formname//;

		}
	}

	# save printed, emailed info
	$formnames  =~ s/^ +//g;
	$emailforms =~ s/^ +//g;

	my %status = ();
	for ( split / +/, $formnames )  { $status{$_}{printed} = 1 }
	for ( split / +/, $emailforms ) { $status{$_}{emailed} = 1 }

	foreach my $formname ( keys %status ) {
		$printed = ( $formnames  =~ /$self->{formname}/ ) ? "1" : "0";
		$emailed = ( $emailforms =~ /$self->{formname}/ ) ? "1" : "0";

		$query = qq|INSERT INTO status (trans_id, printed, emailed, formname)
		VALUES ($self->{id}, |
		  . $dbh->quote($printed) . qq|, |
		  . $dbh->quote($emailed) . qq|, |
		  . $dbh->quote($formname) . qq|)|;
		$dbh->do($query) || $self->dberror($query);
	}

}

sub get_recurring {
	my ( $self, $dbh ) = @_;

	$self->{id} *= 1;

	my $query = qq~SELECT s.*, se.formname || ':' || se.format AS emaila,
              se.message,
	      sp.formname || ':' || sp.format || ':' || sp.printer AS printa
	      FROM recurring s
	      LEFT JOIN recurringemail se ON (s.id = se.id)
	      LEFT JOIN recurringprint sp ON (s.id = sp.id)
	      WHERE s.id = $self->{id}~;
	my $sth = $dbh->prepare($query);
	$sth->execute || $form->dberror($query);

	for (qw(email print)) { $self->{"recurring$_"} = "" }

	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		for ( keys %$ref ) { $self->{"recurring$_"} = $ref->{$_} }
		$self->{recurringemail} .= "$ref->{emaila}:";
		$self->{recurringprint} .= "$ref->{printa}:";
		for (qw(emaila printa)) { delete $self->{"recurring$_"} }
	}
	$sth->finish;
	chop $self->{recurringemail};
	chop $self->{recurringprint};

	if ( $self->{recurringstartdate} ) {
		for (qw(reference description message)) {
			$self->{"recurring$_"} = $self->escape( $self->{"recurring$_"}, 1 );
		}
		for (
			qw(reference description startdate repeat unit howmany payment print email message)
		  )
		{
			$self->{recurring} .= qq|$self->{"recurring$_"},|;
		}
		chop $self->{recurring};
	}

}

sub save_recurring {
	my ( $self, $dbh, $myconfig ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect_noauto($myconfig);
	}

	my $query;

	for (qw(recurring recurringemail recurringprint)) {
		$query = qq|DELETE FROM $_ WHERE id = $self->{id}|;
		$dbh->do($query) || $self->dberror($query);
	}

	if ( $self->{recurring} ) {
		my %s = ();
		(
			$s{reference}, $s{description}, $s{startdate}, $s{repeat},
			$s{unit},      $s{howmany},     $s{payment},   $s{print},
			$s{email},     $s{message}
		) = split /,/, $self->{recurring};

		for (qw(reference description message)) {
			$s{$_} = $self->unescape( $s{$_} );
		}
		for (qw(repeat howmany payment)) { $s{$_} *= 1 }

		# calculate enddate
		my $advance = $s{repeat} * ( $s{howmany} - 1 );
		my %interval = (
			'Pg' => "(date '$s{startdate}' + interval '$advance $s{unit}')",
			'Sybase' =>
"dateadd($myconfig->{dateformat}, $advance $s{unit}, $s{startdate})",
			'DB2' => qq|(date ('$s{startdate}') + "$advance $s{unit}")|,
		);
		$interval{Oracle} = $interval{PgPP} = $interval{Pg};
		$query = qq|SELECT $interval{$myconfig->{dbdriver}}
		FROM defaults
		WHERE fldname = 'version'|;
		my ($enddate) = $dbh->selectrow_array($query);

		# calculate nextdate
		if ( $myconfig->{dbdriver} eq 'Sybase' ) {
			$query =
qq|SELECT datediff($myconfig->{dateformat}, $s{startdate}, current_date) AS a,
		  datediff($myconfig->{dateformat}, current_date, $enddate) AS b
		  FROM defaults
		  WHERE fldname = 'version'|;
		}
		else {
			$query = qq|SELECT current_date - date '$s{startdate}' AS a,
		  date '$enddate' - current_date AS b
		  FROM defaults
		  WHERE fldname = 'version'|;
		}
		my ( $a, $b ) = $dbh->selectrow_array($query);

		if ( $a + $b ) {
			$advance =
			  int( ( $a / ( $a + $b ) ) * ( $s{howmany} - 1 ) + 1 ) *
			  $s{repeat};
		}
		else {
			$advance = 0;
		}

		my $nextdate = $enddate;
		if ( $advance > 0 ) {
			if ( $advance < ( $s{repeat} * $s{howmany} ) ) {
				%interval = (
					'Pg' =>
					  "(date '$s{startdate}' + interval '$advance $s{unit}')",
					'Sybase' =>
"dateadd($myconfig->{dateformat}, $advance $s{unit}, $s{startdate})",
					'DB2' => qq|(date ('$s{startdate}') + "$advance $s{unit}")|,
				);
				$interval{Oracle} = $interval{PgPP} = $interval{Pg};
				$query = qq|SELECT $interval{$myconfig->{dbdriver}}
		    FROM defaults
		    WHERE fldname = 'version'|;
				($nextdate) = $dbh->selectrow_array($query);
			}
		}
		else {
			$nextdate = $s{startdate};
		}

		if ( $self->{recurringnextdate} ) {
			$nextdate = $self->{recurringnextdate};

			$query = qq|SELECT '$enddate' - date '$nextdate'
                  FROM defaults
		  WHERE fldname = 'version'|;
			if ( $myconfig->{dbdriver} eq 'Sybase' ) {
				$query =
qq|SELECT datediff($myconfig->{dateformat}, $enddate, $nextdate)
	            FROM defaults
		    WHERE fldname = 'version'|;
			}

			if ( $dbh->selectrow_array($query) < 0 ) {
				undef $nextdate;
			}
		}

		$self->{recurringpayment} *= 1;
		$query = qq|INSERT INTO recurring (id, reference, description,
                startdate, enddate, nextdate,
		repeat, unit, howmany, payment)
                VALUES ($self->{id}, | . $dbh->quote( $s{reference} ) . qq|,
		| . $dbh->quote( $s{description} ) . qq|,
		'$s{startdate}', '$enddate', |
		  . $self->dbquote( $nextdate, SQL_DATE )
		  . qq|, $s{repeat}, '$s{unit}', $s{howmany}, '$s{payment}')|;
		$dbh->do($query) || $self->dberror($query);

		my @p;
		my $p;
		my $i;
		my $sth;

		if ( $s{email} ) {

			# formname:format
			@p = split /:/, $s{email};

			$query =
			  qq|INSERT INTO recurringemail (id, formname, format, message)
		  VALUES ($self->{id}, ?, ?, ?)|;
			$sth = $dbh->prepare($query) || $self->dberror($query);

			for ( $i = 0 ; $i <= $#p ; $i += 2 ) {
				$sth->execute( $p[$i], $p[ $i + 1 ], $s{message} );
			}
			$sth->finish;
		}

		if ( $s{print} ) {

			# formname:format:printer
			@p = split /:/, $s{print};

			$query =
			  qq|INSERT INTO recurringprint (id, formname, format, printer)
		  VALUES ($self->{id}, ?, ?, ?)|;
			$sth = $dbh->prepare($query) || $self->dberror($query);

			for ( $i = 0 ; $i <= $#p ; $i += 3 ) {
				$p = ( $p[ $i + 2 ] ) ? $p[ $i + 2 ] : "";
				$sth->execute( $p[$i], $p[ $i + 1 ], $p );
			}
			$sth->finish;
		}

	}

	if ($disconnect) {
		$dbh->commit;
		$dbh->disconnect;
	}

}

sub save_intnotes {
	my ( $self, $myconfig, $vc ) = @_;

	# no id return
	$self->{id} *= 1;
	return unless $self->{id};

	my $dbh = $self->dbconnect($myconfig);

	my $query = qq|UPDATE $vc SET
                 intnotes = | . $dbh->quote( $self->{intnotes} ) . qq|
                 WHERE id = $self->{id}|;
	$dbh->do($query) || $self->dberror($query);

	$dbh->disconnect;

}

sub update_defaults {
	my ( $self, $myconfig, $fld, $dbh ) = @_;

	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect_noauto($myconfig);
	}

	my $query = qq|SELECT fldname FROM defaults
                 WHERE fldname = '$fld'|;

	if ( !$dbh->selectrow_array($query) ) {
		$query = qq|INSERT INTO defaults (fldname)
                VALUES ('$fld')|;
		$dbh->do($query) || $self->dberror($query);
		$dbh->commit;
	}

	$query = qq|SELECT fldvalue FROM defaults
              WHERE fldname = '$fld' FOR UPDATE|;
	($_) = $dbh->selectrow_array($query);

	$_ = "0" unless $_;

	# check for and replace
	# <%DATE%>, <%YYMMDD%>, <%YEAR%>, <%MONTH%>, <%DAY%> or variations of
	# <%NAME 1 1 3%>, <%BUSINESS%>, <%BUSINESS 10%>, <%CURR...%>
	# <%DESCRIPTION 1 1 3%>, <%ITEM 1 1 3%>, <%PARTSGROUP 1 1 3%> only for parts
	# <%PHONE%> for customer and vendors
	# <%YY%>, <%MM%>, <%DD%>, <%FDM%>, <%LDM%>

	my $num = $_;
	$num =~ s/.*?<%.*?%>//g;
	($num) = $num =~ /(\d+)/;

	if ( defined $num ) {
		my $incnum;

		# if we have leading zeros check how long it is
		if ( $num =~ /^0/ ) {
			my $l = length $num;
			$incnum = $num + 1;
			$l -= length $incnum;

			# pad it out with zeros
			my $padzero = "0" x $l;
			$incnum = ( "0" x $l ) . $incnum;
		}
		else {
			$incnum = $num + 1;
		}

		s/$num/$incnum/;
	}

	my $dbvar = $_;
	my $var   = $_;
	my $str;
	my $param;

	if (/<%/) {
		while (/<%/) {
			s/<%.*?%>//;
			last unless $&;
			$param = $&;
			$str   = "";

			if ( $param =~ /<%date%>/i ) {
				$str = (
					$self->split_date(
						$myconfig->{dateformat},
						$self->{transdate}
					)
				)[0];
				$var =~ s/$param/$str/;
			}

			if ( $param =~
				/<%(name|business|description|item|partsgroup|phone|custom)/i )
			{
				my $fld = lc $1;
				if ( $fld =~ /name/ ) {
					if ( $self->{type} ) {
						$fld = $self->{vc};
					}
				}

				my $p = $param;
				$p =~ s/(<|>|%)//g;
				my @p = split / /, $p;
				my @n = split / /, uc $self->{$fld};
				if ( $#p > 0 ) {
					for ( my $i = 1 ; $i <= $#p ; $i++ ) {
						$str .= substr( $n[ $i - 1 ], 0, $p[$i] );
					}
				}
				else {
					($str) = split /--/, $self->{$fld};
				}
				$var =~ s/$param/$str/;

				$var =~ s/\W//g if $fld eq 'phone';
			}

			if ( $param =~ /<%(yy|mm|dd)/i ) {
				my $p   = $param;
				my $mdy = $1;
				$p =~ s/(<|>|%)//g;

				if ( !$ml ) {
					my $spc = $p;
					$spc =~ s/\w//g;
					$spc = substr( $spc, 0, 1 );
					my %d = ( yy => 1, mm => 2, dd => 3 );
					my @p = ();

					my @a = $self->split_date( $myconfig->{dateformat},
						$self->{transdate} );
					for ( sort keys %d ) {
						push @p, $a[ $d{$_} ]
						  if ( $p =~ /$_/ );
					}
					$str = join $spc, @p;
				}

				$var =~ s/$param/$str/i;
			}

			if ( $param =~ /<%(fdm|ldm)%>/i ) {
				$str = $self->dayofmonth( $myconfig->{dateformat},
					$self->{transdate}, $1 );
				$var =~ s/$param/$str/i;
			}

			if ( $param =~ /<%curr/i ) {
				$var =~ s/$param/$self->{currency}/i;
			}

		}
	}

	$query = qq|UPDATE defaults
              SET fldvalue = '$dbvar'
	      WHERE fldname = '$fld'|;
	$dbh->do($query) || $self->dberror($query);

	if ($disconnect) {
		$dbh->commit;
		$dbh->disconnect;
	}

	$var;

}

sub sort_column_index {
	my ($self) = @_;

	my @c = split /,/, $self->{column_index};
	my $i = 1;
	my %c;
	my $v;
	my $j;
	my $k;
	my %d;
	my $ndx;
	my $lastndx;
	my %temp;

	my (@m) = split /,/, $self->{movecolumn};

	for (@c) {
		( $v, $j ) = split /=/, $_;
		$c{$v} = $i;
		$d{$v} = $j;
		$ndx = $i if $v eq $m[0];
		$lastndx = $i;
		$i++;
	}

	if ( $m[1] eq 'right' ) {
		$c{ $m[0] } += 1.5;
		$i = $ndx + 1;

		if ( exists $self->{"a_1"} ) {
			if ( $i == $lastndx + 1 ) {
				for (qw(a w f l)) {
					$temp{$_}     = $self->{"${_}_$lastndx"};
					$temp{"t_$_"} = $self->{"t_${_}_$lastndx"};
					$temp{"h_$_"} = $self->{"h_${_}_$lastndx"};
				}
				for $i ( 1 .. $lastndx - 1 ) {
					for (qw(a w f l)) {
						$k                   = $lastndx - $i + 1;
						$j                   = $lastndx - $i;
						$self->{"${_}_$k"}   = $self->{"${_}_$j"};
						$self->{"t_${_}_$k"} = $self->{"t_${_}_$j"};
						$self->{"h_${_}_$k"} = $self->{"h_${_}_$j"};
					}
				}
				for (qw(a w f l)) {
					$self->{"${_}_1"}   = $temp{$_};
					$self->{"t_${_}_1"} = $temp{"t_$_"};
					$self->{"h_${_}_1"} = $temp{"h_$_"};
				}

				$i          = 1;
				$ndx        = 1;
				$c{ $m[0] } = 0;
			}
		}
	}
	else {
		$c{ $m[0] } -= 1.5;
		$i = $ndx - 1;

		if ( exists $self->{"a_1"} ) {
			if ( $i == 0 ) {
				for (qw(a w f l)) {
					$temp{$_}     = $self->{"${_}_1"};
					$temp{"t_$_"} = $self->{"t_${_}_1"};
					$temp{"h_$_"} = $self->{"h_${_}_1"};
				}
				for $i ( 1 .. $lastndx - 1 ) {
					for (qw(a w f l)) {
						$j                   = $i + 1;
						$self->{"${_}_$i"}   = $self->{"${_}_$j"};
						$self->{"t_${_}_$i"} = $self->{"t_${_}_$j"};
						$self->{"h_${_}_$i"} = $self->{"h_${_}_$j"};
					}
				}
				for (qw(a w f l)) {
					$self->{"${_}_$lastndx"}   = $temp{$_};
					$self->{"t_${_}_$lastndx"} = $temp{"t_$_"};
					$self->{"h_${_}_$lastndx"} = $temp{"h_$_"};
				}

				$i          = 1;
				$ndx        = 1;
				$c{ $m[0] } = $lastndx + 1;
			}
		}
	}

	for (qw(a w f l)) {
		$temp{$_}              = $self->{"${_}_$ndx"};
		$temp{"t_$_"}          = $self->{"t_${_}_$ndx"};
		$temp{"h_$_"}          = $self->{"h_${_}_$ndx"};
		$self->{"${_}_$ndx"}   = $self->{"${_}_$i"};
		$self->{"t_${_}_$ndx"} = $self->{"t_${_}_$i"};
		$self->{"h_${_}_$ndx"} = $self->{"h_${_}_$i"};
		$self->{"${_}_$i"}     = $temp{$_};
		$self->{"t_${_}_$i"}   = $temp{"t_$_"};
		$self->{"h_${_}_$i"}   = $temp{"h_$_"};
	}

	$self->{column_index} = "";
	@c = ();
	for ( sort { $c{$a} <=> $c{$b} } keys %c ) {
		push @c, $_;
		$self->{column_index} .= "$_=$d{$_},";
	}
	chop $self->{column_index};

	@c;

}

sub split_date {
	my ( $self, $dateformat, $date ) = @_;

	my @t = localtime;
	my $mm;
	my $dd;
	my $yy;
	my $rv;

	if ( !$date ) {
		$dd = $t[3];
		$mm = ++$t[4];
		$yy = substr( $t[5], -2 );
		$mm = substr( "0$mm", -2 );
		$dd = substr( "0$dd", -2 );
	}

	if ( $dateformat =~ /^yy/ ) {
		if ($date) {
			if ( $date =~ /\D/ ) {
				( $yy, $mm, $dd ) = split /\D/, $date;
				$mm *= 1;
				$dd *= 1;
				$rv = "$yy$mm$dd";
			}
			else {
				$rv = $date;
				$date =~ /(....)(..)(..)/;
				$yy = $1;
				$mm = $2;
				$dd = $3;
			}
			$mm = substr( "0$mm", -2 );
			$dd = substr( "0$dd", -2 );
			$yy = substr( $yy,    -2 );
		}
		else {
			$rv = "$yy$mm$dd";
		}
	}

	if ( $dateformat =~ /^mm/ ) {
		if ($date) {
			if ( $date =~ /\D/ ) {
				( $mm, $dd, $yy ) = split /\D/, $date;
				$mm *= 1;
				$dd *= 1;
				$mm = substr( "0$mm", -2 );
				$dd = substr( "0$dd", -2 );
				$yy = substr( $yy,    -2 );
				$rv = "$mm$dd$yy";
			}
			else {
				$rv = $date;
			}
		}
		else {
			$rv = "$mm$dd$yy";
		}
	}

	if ( $dateformat =~ /^dd/ ) {
		if ($date) {
			if ( $date =~ /\D/ ) {
				( $dd, $mm, $yy ) = split /\D/, $date;
				$mm *= 1;
				$dd *= 1;
				$mm = substr( "0$mm", -2 );
				$dd = substr( "0$dd", -2 );
				$yy = substr( $yy,    -2 );
				$rv = "$dd$mm$yy";
			}
			else {
				$rv = $date;
			}
		}
		else {
			$rv = "$dd$mm$yy";
		}
	}

	( $rv, $yy, $mm, $dd );

}

sub dayofmonth {
	my ( $self, $dateformat, $date, $fdm ) = @_;

	my $rv = $date;
	my @a  = $self->split_date( $dateformat, $date );
	my $bd = 0;

	my $spc = $date;
	$spc =~ s/\w//g;
	$spc = substr( $spc, 0, 1 );

	use Time::Local;

	$a[2]-- if $a[2];

	if ( lc $fdm ne 'fdm' ) {
		$bd = 1;
		$a[2]++;
		if ( $a[2] > 11 ) {
			$a[2] = 0;
			$a[1]++;
		}
	}

	my @t = localtime( timelocal( 0, 0, 0, 1, $a[2], $a[1] ) - $bd );

	$t[4]++;
	$t[4] = substr( "0$t[4]", -2 );
	$t[3] = substr( "0$t[3]", -2 );
	$t[5] += 1900;

	if ( $dateformat =~ /^yy/ ) {
		$rv = "$t[5]$spc$t[4]$spc$t[3]";
	}

	if ( $dateformat =~ /^mm/ ) {
		$rv = "$t[4]$spc$t[3]$spc$t[5]";
	}

	if ( $dateformat =~ /^dd/ ) {
		$rv = "$t[3]$spc$t[4]$spc$t[5]";
	}

	$rv;

}

sub from_to {
	my ( $self, $yy, $mm, $interval ) = @_;

	use Time::Local;

	my @t;
	my $dd       = 1;
	my $fromdate = "$yy${mm}01";
	my $bd       = 1;

	if ( defined $interval ) {
		if ( $interval == 12 ) {
			$yy++;
		}
		else {
			if ( ( $mm += $interval ) > 12 ) {
				$mm -= 12;
				$yy++;
			}
			if ( $interval == 0 ) {
				@t  = localtime;
				$dd = $t[3];
				$mm = $t[4] + 1;
				$yy = $t[5] + 1900;
				$bd = 0;
			}
		}
	}
	else {
		if ( ++$mm > 12 ) {
			$mm -= 12;
			$yy++;
		}
	}

	$mm--;
	@t = localtime( timelocal( 0, 0, 0, $dd, $mm, $yy ) - $bd );

	$t[4]++;
	$t[4] = substr( "0$t[4]", -2 );
	$t[3] = substr( "0$t[3]", -2 );
	$t[5] += 1900;

	( $fromdate, "$t[5]$t[4]$t[3]" );

}

sub fdld {
	my ( $self, $myconfig, $locale ) = @_;

	$self->{fdm} =
	  $self->dayofmonth( $myconfig->{dateformat}, $self->{transdate}, 'fdm' );
	$self->{ldm} =
	  $self->dayofmonth( $myconfig->{dateformat}, $self->{transdate} );

	my $transdate = $self->datetonum( $myconfig, $self->{transdate} );

	$self->{yy} = substr( $transdate, 2, 2 );
	( $self->{yyyy}, $self->{mm}, $self->{dd} ) =
	  $transdate =~ /(....)(..)(..)/;

	my $m1;
	my $m2;
	my $y1;
	my $y2;
	my $d1;
	my $d2;
	my $d3;
	my $d4;

	for ( 1 .. 11 ) {
		$m1 = $self->{mm} + $_;
		$y1 = $self->{yyyy};
		if ( $m1 > 12 ) {
			$m1 -= 12;
			$y1++;
		}
		$m1 = substr( "0$m1", -2 );

		$m2 = $self->{mm} - $_;
		$y2 = $self->{yyyy};
		if ( $m2 < 1 ) {
			$m2 += 12;
			$y2--;
		}
		$m2 = substr( "0$m2", -2 );

		$d1 = $self->format_date( $myconfig->{dateformat}, "$y1${m1}01" );
		$d2 = $self->format_date( $myconfig->{dateformat},
			$self->dayofmonth( "yyyymmdd", "$y1${m1}01" ) );
		$d3 = $self->format_date( $myconfig->{dateformat}, "$y2${m2}01" );
		$d4 = $self->format_date( $myconfig->{dateformat},
			$self->dayofmonth( "yyyymmdd", "$y2${m2}01" ) );

		if ( exists $self->{longformat} ) {
			$self->{"fdm+$_"} =
			  $locale->date( $myconfig, $d1, $self->{longformat} );
			$self->{"ldm+$_"} =
			  $locale->date( $myconfig, $d2, $self->{longformat} );
			$self->{"fdm-$_"} =
			  $locale->date( $myconfig, $d3, $self->{longformat} );
			$self->{"ldm-$_"} =
			  $locale->date( $myconfig, $d4, $self->{longformat} );
		}
		else {
			$self->{"fdm+$_"} = $d1;
			$self->{"ldm+$_"} = $d2;
			$self->{"fdm-$_"} = $d3;
			$self->{"ldm-$_"} = $d4;
		}
	}

	$d1 = $self->format_date( $myconfig->{dateformat},
		"$self->{yyyy}$self->{mm}01" );
	$d2 = $self->format_date( $myconfig->{dateformat},
		$self->dayofmonth( "yyyymmdd", "$self->{yyyy}$form->{mm}01" ) );

	if ( exists $self->{longformat} ) {
		$self->{fdm} =
		  $locale->date( $myconfig, $self->{fdm}, $self->{longformat} );
		$self->{ldm} =
		  $locale->date( $myconfig, $self->{ldm}, $self->{longformat} );
		$self->{fdy} = $locale->date( $myconfig, $d1, $self->{longformat} );
		$self->{ldy} = $locale->date( $myconfig, $d2, $self->{longformat} );
	}
	else {
		$self->{fdy} = $d1;
		$self->{ldy} = $d2;
	}

	for ( 1 .. 3 ) {
		$y1 = $self->{yyyy} + $_;
		$y2 = $self->{yyyy} - $_;

		$d1 = $self->format_date( $myconfig->{dateformat}, "$y1$self->{mm}01" );
		$d2 = $self->format_date( $myconfig->{dateformat},
			$self->dayofmonth( "yyyymmdd", "$y1$self->{mm}01" ) );
		$d3 = $self->format_date( $myconfig->{dateformat}, "$y2$self->{mm}01" );
		$d4 = $self->format_date( $myconfig->{dateformat},
			$self->dayofmonth( "yyyymmdd", "$y2$self->{mm}01" ) );

		if ( exists $self->{longformat} ) {
			$self->{"fdy+$_"} =
			  $locale->date( $myconfig, $d1, $self->{longformat} );
			$self->{"ldy+$_"} =
			  $locale->date( $myconfig, $d2, $self->{longformat} );
			$self->{"fdy-$_"} =
			  $locale->date( $myconfig, $d3, $self->{longformat} );
			$self->{"ldy-$_"} =
			  $locale->date( $myconfig, $d4, $self->{longformat} );
		}
		else {
			$self->{"fdy+$_"} = $d1;
			$self->{"ldy+$_"} = $d2;
			$self->{"fdy-$_"} = $d3;
			$self->{"ldy-$_"} = $d4;
		}

	}

}

sub audittrail {
	my ( $self, $dbh, $myconfig, $audittrail ) = @_;

	# table, $reference, $formname, $action, $id, $transdate) = @_;

	my $query;
	my $rv;
	my $disconnect = ($dbh) ? 0 : 1;

	if ( !$dbh ) {
		$dbh = $self->dbconnect($myconfig);
	}

	# if we have an id add audittrail, otherwise get a new timestamp

	if ( $audittrail->{id} *= 1 ) {

		my %defaults = $self->get_defaults( $dbh, \@{ ['audittrail'] } );

		if ( $defaults{audittrail} ) {
			my ( $null, $employee_id ) = $self->get_employee($dbh);

			if ( $self->{audittrail} && !$myconfig ) {
				chop $self->{audittrail};

				my @a = split /\|/, $self->{audittrail};
				my %newtrail = ();
				my $key;
				my $i;
				my @flds = qw(tablename reference formname action transdate);

				# put into hash and remove dups
				while (@a) {
					$key = "$a[2]$a[3]";
					$i   = 0;
					$newtrail{$key} = { map { $_ => $a[ $i++ ] } @flds };
					splice @a, 0, 5;
				}

				$query =
				  qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id, transdate)
	            VALUES ($audittrail->{id}, ?, ?,
		    ?, ?, $employee_id, ?)|;
				my $sth = $dbh->prepare($query) || $self->dberror($query);

				foreach $key (
					sort {
						$newtrail{$a}{transdate} cmp $newtrail{$b}{transdate}
					} keys %newtrail
				  )
				{
					$i = 1;
					for (@flds) {
						$sth->bind_param( $i++, $newtrail{$key}{$_} );
					}

					$sth->execute || $self->dberror;
					$sth->finish;
				}
			}

			if ( $audittrail->{transdate} ) {
				$query =
				  qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id, transdate) VALUES (
		    $audittrail->{id}, |
				  . $dbh->quote( $audittrail->{tablename} ) . qq|, |
				  . $dbh->quote( $audittrail->{reference} ) . qq|',
		    |
				  . $dbh->quote( $audittrail->{formname} ) . qq|, |
				  . $dbh->quote( $audittrail->{action} ) . qq|,
		    | . $self->dbclean($employee_id) . qq|, '$audittrail->{transdate}')|;
			}
			else {
				$query =
				  qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id) VALUES ($audittrail->{id},
		    |
				  . $dbh->quote( $audittrail->{tablename} ) . qq|, |
				  . $dbh->quote( $audittrail->{reference} ) . qq|,
		    |
				  . $dbh->quote( $audittrail->{formname} ) . qq|, |
				  . $dbh->quote( $audittrail->{action} ) . qq|,
		    | . $self->dbclean($employee_id) . qq|)|;
			}
			$dbh->do($query);
		}
	}
	else {

		$query = qq|SELECT current_timestamp FROM defaults
                WHERE fldname = 'version'|;
		my ($timestamp) = $dbh->selectrow_array($query);

		$rv =
"$audittrail->{tablename}|$audittrail->{reference}|$audittrail->{formname}|$audittrail->{action}|$timestamp|";
	}

	$dbh->disconnect if $disconnect;

	$rv;

}

sub save_form {
	my ( $self, $type ) = @_;
	if ( $type eq 'report' ) {
		if ( !-f "$self->{login}_menu.ini" ) {
			open FH, ">$self->{login}_menu.ini";
			print FH qq|[Saved Reports]\n|;
			close FH;
		}
		open FH, ">>$self->{login}_menu.ini";
		print FH qq|\n[Saved Reports--$self->{reportname}]\n|;
		print FH qq|module=$self->{script}\n|;
		print FH qq|action=$self->{actionname}\n|;
		for ( sort keys %$self ) {
			if (
				$self->{$_}
				and ( $_ !~
/^(parts|callback|action|actionname|nextsub|link|precision|filetype|oldsort|dbversion|debug|path|session|sessioncookie|stylesheet|title|titlebar|version|timeout|login|direction|reportname|level|script|GL|TB|transactions|balance|selectwarehouse|selectdepartment)$/
				)
			  )
			{
				print FH qq|$_=$self->{$_}\n|;
			}
		}
		close FH;
		$self->info('Saved');
	}
}


sub get_lastused {
	my ( $self, $myconfig, $report, $default_checked ) = @_;
	my $dbh = $self->dbconnect($myconfig);
    my $dbs = DBIx::Simple->connect($dbh);
    my $cols = $dbs->query("SELECT cols FROM lastused WHERE report = ? AND login = ? LIMIT 1", $report, $self->{login})->list;
    $cols = $default_checked if !$cols;
    my @colslist = split /,/, $cols;
    for (@colslist){ $self->{"l_$_"} = 'checked' };
}


sub save_lastused {
	my ( $self, $myconfig, $report, $cols, $cols2 ) = @_;
	my $dbh = $self->dbconnect($myconfig);
    my $dbs = DBIx::Simple->connect($dbh);

    my $colslist;

    for (@$cols) { $colslist .= "$_," if $self->{"l_$_"} }
    for (@$cols2) { $colslist .= "$_," if $self->{"l_$_"} }
    chop $report_columns;

    my $exists = $dbs->query( "SELECT 1 FROM lastused WHERE report=? AND login = ? LIMIT 1", $report, $self->{login} )->list;
    if ($exists) {
        $dbs->query( "UPDATE lastused SET cols = ? WHERE report=? AND login = ?", $colslist, $report, $self->{login} );
    } else {
        $dbs->query( "INSERT INTO lastused (report, cols, login) VALUES (?, ?, ?)", $report, $colslist, $self->{login} );
    }
}


package Locale;

sub new {
	my ( $type, $country, $NLS_file ) = @_;
	my $self = {};

	%self = ();
	if ( $country && -d "locale/$country" ) {
		$self->{countrycode} = $country;
		eval { require "locale/$country/$NLS_file"; };
	}

	$self->{NLS_file} = $NLS_file;
	$self->{charset}  = $self{charset};

	push @{ $self->{LONG_MONTH} },
	  (
		"January",   "February", "March",    "April",
		"May ",      "June",     "July",     "August",
		"September", "October",  "November", "December"
	  );
	push @{ $self->{SHORT_MONTH} },
	  (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec));

	bless $self, $type;

}

sub text {
	my ( $self, $text ) = @_;

	return ( exists $self{texts}{$text} ) ? $self{texts}{$text} : $text;

}

sub findsub {
	my ( $self, $text ) = @_;

	if ( exists $self{subs}{$text} ) {
		$text = $self{subs}{$text};
	}
	else {
		if ( $self->{countrycode} && $self->{NLS_file} ) {
			Form->error(
"$text not defined in locale/$self->{countrycode}/$self->{NLS_file}"
			);
		}
	}

	$text;

}

sub date {
	my ( $self, $myconfig, $date, $longformat ) = @_;

	my $longdate = "";
	my $longmonth = ($longformat) ? 'LONG_MONTH' : 'SHORT_MONTH';

	if ($date) {

		# get separator
		$spc = $myconfig->{dateformat};
		$spc =~ s/\w//g;
		$spc = substr( $spc, 0, 1 );

		if ( $date =~ /\D/ ) {
			if ( $myconfig->{dateformat} =~ /^yy/ ) {
				( $yy, $mm, $dd ) = split /\D/, $date;
			}
			if ( $myconfig->{dateformat} =~ /^mm/ ) {
				( $mm, $dd, $yy ) = split /\D/, $date;
			}
			if ( $myconfig->{dateformat} =~ /^dd/ ) {
				( $dd, $mm, $yy ) = split /\D/, $date;
			}
		}
		else {
			if ( length $date > 6 ) {
				( $yy, $mm, $dd ) = ( $date =~ /(....)(..)(..)/ );
			}
			else {
				( $yy, $mm, $dd ) = ( $date =~ /(..)(..)(..)/ );
			}
		}

		$dd *= 1;
		$mm--;
		$yy += 2000 if length $yy == 2;

		if ( $myconfig->{dateformat} =~ /^dd/ ) {
			$mm++;
			$dd = substr( "0$dd", -2 );
			$mm = substr( "0$mm", -2 );
			$longdate = "$dd$spc$mm$spc$yy";

			if ( $longformat ne "" ) {
				$longdate = "$dd";
				$longdate .= ( $spc eq '.' ) ? ". " : " ";
				$longdate .=
				  &text( $self, $self->{$longmonth}[ --$mm ] ) . " $yy";
			}
		}
		elsif ( $myconfig->{dateformat} =~ /^yy/ ) {
			$mm++;
			$dd = substr( "0$dd", -2 );
			$mm = substr( "0$mm", -2 );
			$longdate = "$yy$spc$mm$spc$dd";

			if ( $longformat ne "" ) {
				$longdate =
				  &text( $self, $self->{$longmonth}[ --$mm ] ) . " $dd $yy";
			}
		}
		else {
			$mm++;
			$dd = substr( "0$dd", -2 );
			$mm = substr( "0$mm", -2 );
			$longdate = "$mm$spc$dd$spc$yy";

			if ( $longformat ne "" ) {
				$longdate =
				  &text( $self, $self->{$longmonth}[ --$mm ] ) . " $dd $yy";
			}
		}

	}

	$longdate;

}

1;

