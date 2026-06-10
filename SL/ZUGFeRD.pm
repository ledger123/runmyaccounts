#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2024
#
#  Author: IBP
#
#======================================================================
#
# ZUGFeRD / Factur-X XML generator
#
# Generates a ZUGFeRD 2.x / Factur-X 1.0 XML document (profile
# "EN 16931" a.k.a. COMFORT) directly from the invoice form data
# populated by IS::invoice_details.  The XML can be used as a
# standalone file, an email attachment, or embedded in a PDF/A-3
# document.
#
# Profile guideline ID used: urn:cen.eu:en16931:2017
# Factur-X XMP conformance level: EN 16931
#
#======================================================================

package ZUGFeRD;

use strict;
use Encode qw(decode encode);

# Package-level charset used by _esc() to re-encode form strings to UTF-8.
# Set by generate_xml() from $form->{charset} before any XML is built.
my $_charset = 'UTF-8';

sub new {
    my ($type) = @_;
    return bless {}, $type;
}

# generate_xml($form)
#
# Returns a UTF-8 encoded ZUGFeRD Factur-X XML string built from the
# data already stored in $form by IS::invoice_details.
# TypeCode 380 (invoice) or 381 (credit note) is chosen automatically
# based on $form->{formname}.
sub generate_xml {
    my ($self, $form) = @_;

    # Capture the form's charset so _esc() can re-encode strings to UTF-8.
    $_charset = $form->{charset} // 'UTF-8';

    my $typecode = ($form->{formname} eq 'credit_invoice') ? 381 : 380;

    my $xml = _header($form, $typecode);
    $xml .= _line_items($form);
    $xml .= _trade_agreement($form);
    $xml .= _trade_delivery($form);
    $xml .= _trade_settlement($form);
    $xml .= _footer();

    return $xml;
}

# -----------------------------------------------------------------------
# Private helpers
# -----------------------------------------------------------------------

# Escape a plain text value for safe inclusion in XML element content.
# If the form's charset is not UTF-8, the value is decoded from that charset
# and re-encoded as UTF-8 so that the XML declaration is honoured.
sub _esc {
    my ($s) = @_;
    return '' unless defined $s;
    unless ($_charset =~ /utf-?8/i) {
        $s = encode('UTF-8', decode($_charset, $s));
    }
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

# Normalise a VAT/tax registration number so it starts with an ISO 3166-1
# alpha-2 country prefix, as required by EN 16931 rule BR-CO-09.
# Swiss UIDs are stored as "CHE-123.456.789 MWST"; this converts them to
# "CH123456789" (stripping separators, "MWST" suffix, and the 3-letter CHE
# prefix to 2-letter CH).
# $default_cc is the ISO alpha-2 fallback used when the VAT id has no
# country prefix at all (derived from the seller's postal country).
sub _vat_id {
    my ($s, $default_cc) = @_;
    return '' unless defined $s;
    unless ($_charset =~ /utf-?8/i) {
        $s = encode('UTF-8', decode($_charset, $s));
    }
    $s =~ s/\s+MWST\b.*//i;   # strip " MWST" suffix and anything that follows
    $s =~ s/[^A-Za-z0-9]//g;  # remove dots, dashes, spaces
    $s =~ s/^CHE(?=[0-9])/CH/i; # Swiss alpha-3 "CHE" -> alpha-2 "CH"
        # BR-CO-09: if no 2-letter ISO 3166-1 alpha-2 prefix is present, prepend
        # the seller's country code (or "CH" as last-resort default).
        unless ($s =~ /^[A-Za-z]{2}/) {
            $default_cc = 'CH' unless defined $default_cc && $default_cc =~ /^[A-Za-z]{2}$/;
            $s = uc($default_cc) . $s;
        }
    return $s;                  # result is alphanumeric; no XML escaping needed
}

# Map a free-text country name (or already-valid ISO code) to ISO 3166-1
# alpha-2.  Covers the country names typically stored by SQL-Ledger users in
# DACH/EU contexts.  Falls back to "CH" when no mapping is found.
my %_country_map = (
    'switzerland'    => 'CH',  'schweiz'         => 'CH',  'suisse'   => 'CH',
    'svizzera'       => 'CH',  'ch'              => 'CH',  'che'      => 'CH',
    'germany'        => 'DE',  'deutschland'     => 'DE',  'de'       => 'DE',
    'austria'        => 'AT',  'osterreich'      => 'AT',  'at'       => 'AT',
    'liechtenstein'  => 'LI',  'li'              => 'LI',
    'france'         => 'FR',  'frankreich'      => 'FR',  'fr'       => 'FR',
    'italy'          => 'IT',  'italien'         => 'IT',  'italia'   => 'IT',
    'it'             => 'IT',
    'netherlands'    => 'NL',  'niederlande'     => 'NL',  'nl'       => 'NL',
    'belgium'        => 'BE',  'belgien'         => 'BE',  'be'       => 'BE',
    'luxembourg'     => 'LU',  'luxemburg'       => 'LU',  'lu'       => 'LU',
    'spain'          => 'ES',  'spanien'         => 'ES',  'espana'   => 'ES',
    'es'             => 'ES',
    'portugal'       => 'PT',  'pt'              => 'PT',
    'united kingdom' => 'GB',  'grossbritannien' => 'GB',  'uk'       => 'GB',
    'gb'             => 'GB',  'england'         => 'GB',
    'ireland'        => 'IE',  'irland'          => 'IE',  'ie'       => 'IE',
    'poland'         => 'PL',  'polen'           => 'PL',  'pl'       => 'PL',
    'czech republic' => 'CZ',  'tschechien'      => 'CZ',  'cz'       => 'CZ',
    'denmark'        => 'DK',  'danemark'        => 'DK',  'dk'       => 'DK',
    'sweden'         => 'SE',  'schweden'        => 'SE',  'se'       => 'SE',
    'norway'         => 'NO',  'norwegen'        => 'NO',  'no'       => 'NO',
    'finland'        => 'FI',  'finnland'        => 'FI',  'fi'       => 'FI',
    'usa'            => 'US',  'united states'   => 'US',  'us'       => 'US',
);

sub _country_code {
    my ($s) = @_;
    return 'CH' unless defined $s && $s =~ /\S/;
    unless ($_charset =~ /utf-?8/i) {
        $s = encode('UTF-8', decode($_charset, $s));
    }
    # Accept an already-valid ISO alpha-2 code (case-insensitive, no other chars).
    if ($s =~ /^\s*([A-Za-z]{2})\s*$/) {
        return uc $1;
    }
    my $key = lc $s;
    $key =~ s/^\s+|\s+$//g;
    $key =~ tr/\x{00e4}\x{00f6}\x{00fc}\x{00df}\x{00e9}\x{00e8}\x{00ea}/aousee/; # rough fold
    $key =~ s/[^a-z ]//g;
    return $_country_map{$key} || 'CH';
}

# Map free-text unit names (German + English, with abbreviations) to UN/ECE
# Recommendation 20 unit codes used by EN 16931.  Falls back to C62 ("one")
# for anything we don't recognise, which is the EN 16931 default for piece
# counts.
my %_unit_map = (
    # Pieces / counts
    'stk' => 'H87', 'stck' => 'H87', 'stueck' => 'H87', 'stuck' => 'H87',
    'pc'  => 'H87', 'pcs'  => 'H87', 'piece' => 'H87', 'pieces' => 'H87',
    'pce' => 'H87', 'st'   => 'H87', 'each'  => 'H87',
    'pauschal' => 'C62', 'pausch' => 'C62', 'flat' => 'C62',
    'einheit'  => 'C62', 'unit'   => 'C62', 'one' => 'C62',
    # Time
    'h' => 'HUR', 'hr' => 'HUR', 'hour' => 'HUR', 'hours' => 'HUR',
    'std' => 'HUR', 'stunde' => 'HUR', 'stunden' => 'HUR',
    'min' => 'MIN', 'minute' => 'MIN', 'minuten' => 'MIN',
    'sec' => 'SEC', 'second' => 'SEC',
    'day' => 'DAY', 'tag' => 'DAY', 'tage' => 'DAY',
    'week' => 'WEE', 'woche' => 'WEE', 'wochen' => 'WEE',
    'month' => 'MON', 'monat' => 'MON', 'monate' => 'MON',
    'year' => 'ANN', 'jahr' => 'ANN', 'jahre' => 'ANN',
    # Mass
    'kg' => 'KGM', 'kilogramm' => 'KGM', 'kilogram' => 'KGM',
    'g'  => 'GRM', 'gramm' => 'GRM', 'gram' => 'GRM',
    't'  => 'TNE', 'tonne' => 'TNE', 'tonnen' => 'TNE',
    # Length
    'm'  => 'MTR', 'meter' => 'MTR', 'metre' => 'MTR',
    'cm' => 'CMT', 'mm' => 'MMT', 'km' => 'KMT',
    # Area / volume
    'm2' => 'MTK', 'qm' => 'MTK', 'sqm' => 'MTK',
    'm3' => 'MTQ', 'cbm' => 'MTQ',
    'l'  => 'LTR', 'liter' => 'LTR', 'litre' => 'LTR',
    'ml' => 'MLT',
    # Packaging
    'pack' => 'XPK', 'packung' => 'XPK', 'paket' => 'XPK',
    'box'  => 'XBX', 'karton' => 'XBX',
    'pal'  => 'XPL', 'palette' => 'XPL', 'pallet' => 'XPL',
);

sub _unit_code {
    my ($u) = @_;
    return 'C62' unless defined $u && $u =~ /\S/;
    unless ($_charset =~ /utf-?8/i) {
        $u = encode('UTF-8', decode($_charset, $u));
    }
    my $key = lc $u;
    $key =~ s/[\s.\/]//g;
    $key =~ tr/\x{00e4}\x{00f6}\x{00fc}\x{00df}/aous/;
    return $_unit_map{$key} || 'C62';
}

# Map a payment-method description to a UN/EDIFACT 4461 code.
# Default 30 = credit transfer.  Recognises common keywords for SEPA, direct
# debit, card and cash payments.  Any unmatched method falls back to 30.
sub _payment_means_code {
    my ($m) = @_;
    return '30' unless defined $m && $m =~ /\S/;
    my $s = lc $m;
    return '49' if $s =~ /direct\s*debit|lastschrift|sepa.*dd|sdd\b/;
    return '58' if $s =~ /sepa|credit\s*transfer|sct\b/;
    return '48' if $s =~ /card|karte|visa|master|amex/;
    return '10' if $s =~ /cash|bar(?:zahlung)?|kasse/;
    return '20' if $s =~ /check|cheque|scheck/;
    return '97' if $s =~ /clearing|verrechnung/;
    return '30';                # bank/credit transfer (default)
}

# Format a numeric value to exactly 2 decimal places using dot notation.
sub _amt {
    my ($v) = @_;
    return sprintf('%.2f', $v // 0);
}

# Format a percentage value to 2 decimal places.
sub _pct {
    my ($v) = @_;
    return sprintf('%.2f', $v // 0);
}

sub _header {
    my ($form, $typecode) = @_;

    # EN 16931 (Factur-X COMFORT) guideline identifier.
    my $guideline = 'urn:cen.eu:en16931:2017';

    return
        qq|<?xml version='1.0' encoding='UTF-8' ?>\n| .
        qq|<rsm:CrossIndustryInvoice | .
        qq|xmlns:a="urn:un:unece:uncefact:data:standard:QualifiedDataType:100" | .
        qq|xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" | .
        qq|xmlns:qdt="urn:un:unece:uncefact:data:standard:QualifiedDataType:10" | .
        qq|xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" | .
        qq|xmlns:xs="http://www.w3.org/2001/XMLSchema" | .
        qq|xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">\n| .
        qq|  <rsm:ExchangedDocumentContext>\n| .
        qq|    <ram:GuidelineSpecifiedDocumentContextParameter>\n| .
        qq|      <ram:ID>$guideline</ram:ID>\n| .
        qq|    </ram:GuidelineSpecifiedDocumentContextParameter>\n| .
        qq|  </rsm:ExchangedDocumentContext>\n| .
        qq|  <rsm:ExchangedDocument>\n| .
        qq|    <ram:ID>| . _esc($form->{invnumber}) . qq|</ram:ID>\n| .
        qq|    <ram:TypeCode>$typecode</ram:TypeCode>\n| .
        qq|    <ram:IssueDateTime>\n| .
        qq|      <udt:DateTimeString format="102">| . _esc($form->{xml_invdate}) . qq|</udt:DateTimeString>\n| .
        qq|    </ram:IssueDateTime>\n| .
        (defined $form->{invdescription} && $form->{invdescription} =~ /\S/
            ? qq|    <ram:IncludedNote>\n| .
              qq|      <ram:Content>| . _esc($form->{invdescription}) . qq|</ram:Content>\n| .
              qq|    </ram:IncludedNote>\n|
            : '') .
        qq|  </rsm:ExchangedDocument>\n| .
        qq|  <rsm:SupplyChainTradeTransaction>\n|;
}

sub _line_items {
    my ($form) = @_;

    my $xml = '';
    my $n   = scalar @{ $form->{number} // [] };

    for my $i ( 0 .. $n - 1 ) {
        my $linetotal  = _amt($form->{xml_linetotal}[$i]);
        my $sellprice  = defined $form->{xml_sellprice}[$i]
            ? $form->{xml_sellprice}[$i]
            : _amt(0);
        my $qty        = defined $form->{xml_qty}[$i]
            ? $form->{xml_qty}[$i]
            : _amt(0);
        my $taxrate    = _pct($form->{taxrates}[$i]);
        my $lineid     = _esc($form->{runningnumber}[$i]);
        my $desc       = _esc($form->{description}[$i]);
        my $itemnotes  = $form->{itemnotes}[$i];
        my $partno     = _esc($form->{number}[$i]);
        my $unit_code  = _unit_code($form->{unit}[$i]);
                # EN 16931 VAT category code: S = standard rate, Z = zero rated.
                # The codebase currently has no richer category metadata, so we infer
                # Z for explicit 0% rates and otherwise default to S.  Reverse-charge
                # (AE), intra-EU (K) and export (G) require additional flags that are
                # not yet modelled in SL-Ledger.
                my $cat        = ( ($form->{taxrates}[$i] // 0) + 0 == 0 ) ? 'Z' : 'S';

                my $note_block = '';
                if ( defined $itemnotes && $itemnotes =~ /\S/ ) {
                    $note_block =
                        qq|        <ram:Description>| . _esc($itemnotes) . qq|</ram:Description>\n|;
                }

                my $partno_block = '';
                if ( $partno =~ /\S/ ) {
                    $partno_block =
                        qq|        <ram:SellerAssignedID>$partno</ram:SellerAssignedID>\n|;
                }

        $xml .=
            qq|    <ram:IncludedSupplyChainTradeLineItem>\n| .
            qq|      <ram:AssociatedDocumentLineDocument>\n| .
            qq|        <ram:LineID>$lineid</ram:LineID>\n| .
            qq|      </ram:AssociatedDocumentLineDocument>\n| .
            qq|      <ram:SpecifiedTradeProduct>\n| .
            $partno_block .
                        qq|        <ram:Name>$desc</ram:Name>\n| .
                        $note_block .
            qq|      </ram:SpecifiedTradeProduct>\n| .
            qq|      <ram:SpecifiedLineTradeAgreement>\n| .
            qq|        <ram:NetPriceProductTradePrice>\n| .
            qq|          <ram:ChargeAmount>$sellprice</ram:ChargeAmount>\n| .
            qq|        </ram:NetPriceProductTradePrice>\n| .
            qq|      </ram:SpecifiedLineTradeAgreement>\n| .
            qq|      <ram:SpecifiedLineTradeDelivery>\n| .
            qq|        <ram:BilledQuantity unitCode="$unit_code">$qty</ram:BilledQuantity>\n| .
            qq|      </ram:SpecifiedLineTradeDelivery>\n| .
            qq|      <ram:SpecifiedLineTradeSettlement>\n| .
            qq|        <ram:ApplicableTradeTax>\n| .
            qq|          <ram:TypeCode>VAT</ram:TypeCode>\n| .
            qq|          <ram:CategoryCode>S</ram:CategoryCode>\n| .
            qq|          <ram:RateApplicablePercent>$taxrate</ram:RateApplicablePercent>\n| .
            qq|        </ram:ApplicableTradeTax>\n| .
            qq|        <ram:SpecifiedTradeSettlementLineMonetarySummation>\n| .
            qq|          <ram:LineTotalAmount>$linetotal</ram:LineTotalAmount>\n| .
            qq|        </ram:SpecifiedTradeSettlementLineMonetarySummation>\n| .
            qq|      </ram:SpecifiedLineTradeSettlement>\n| .
            qq|    </ram:IncludedSupplyChainTradeLineItem>\n|;
    }

    return $xml;
}

sub _trade_agreement {
    my ($form) = @_;

    my $seller_line2 = _esc($form->{companyaddress2} // '');
    my $buyer_line1  = _esc($form->{address1}        // '');
    my $buyer_line2  = _esc($form->{address2}        // '');
     my $seller_cc = _country_code($form->{companycountry});
        my $buyer_cc  = _country_code($form->{country});

        # Seller contact (BG-6): only emit when at least one piece of data is set.
        my $seller_contact = '';
        if (   ( $form->{companyemail}   && $form->{companyemail}   =~ /\S/ )
            || ( $form->{tel}            && $form->{tel}            =~ /\S/ )
            || ( $form->{contact}        && $form->{contact}        =~ /\S/ ) )
        {
            $seller_contact .= qq|        <ram:DefinedTradeContact>\n|;
            if ( $form->{contact} && $form->{contact} =~ /\S/ ) {
                $seller_contact .=
                    qq|          <ram:PersonName>| . _esc($form->{contact}) . qq|</ram:PersonName>\n|;
            }
            if ( $form->{tel} && $form->{tel} =~ /\S/ ) {
                $seller_contact .=
                    qq|          <ram:TelephoneUniversalCommunication>\n| .
                    qq|            <ram:CompleteNumber>| . _esc($form->{tel}) . qq|</ram:CompleteNumber>\n| .
                    qq|          </ram:TelephoneUniversalCommunication>\n|;
            }
            if ( $form->{companyemail} && $form->{companyemail} =~ /\S/ ) {
                $seller_contact .=
                    qq|          <ram:EmailURIUniversalCommunication>\n| .
                    qq|            <ram:URIID>| . _esc($form->{companyemail}) . qq|</ram:URIID>\n| .
                    qq|          </ram:EmailURIUniversalCommunication>\n|;
            }
            $seller_contact .= qq|        </ram:DefinedTradeContact>\n|;
        }

        # BuyerReference (BT-10): required under EN 16931.  Derive from the
        # customer's PO number, then the order number, then the customer number,
        # so that there is always a non-empty value.
        my $buyer_ref = $form->{ponumber}
                     || $form->{ordnumber}
                     || $form->{customernumber}
                     || 'NA';

        # Optional document references (BT-13 PO, BT-14 quote, BT-17 order).
        my $doc_refs = '';
        if ( $form->{ponumber} && $form->{ponumber} =~ /\S/ ) {
            $doc_refs .=
                qq|      <ram:BuyerOrderReferencedDocument>\n| .
                qq|        <ram:IssuerAssignedID>| . _esc($form->{ponumber}) . qq|</ram:IssuerAssignedID>\n| .
                qq|      </ram:BuyerOrderReferencedDocument>\n|;
        }
        if ( $form->{quonumber} && $form->{quonumber} =~ /\S/ ) {
            $doc_refs .=
                qq|      <ram:QuotationReferencedDocument>\n| .
                qq|        <ram:IssuerAssignedID>| . _esc($form->{quonumber}) . qq|</ram:IssuerAssignedID>\n| .
                qq|      </ram:QuotationReferencedDocument>\n|;
        }

        # Buyer VAT registration is optional, only emit if we have one.
        my $buyer_tax = '';
        if ( $form->{customertaxnumber} && $form->{customertaxnumber} =~ /\S/ ) {
            $buyer_tax =
                qq|        <ram:SpecifiedTaxRegistration>\n| .
                qq|          <ram:ID schemeID="VA">| . _vat_id($form->{customertaxnumber}, $buyer_cc) . qq|</ram:ID>\n| .
                qq|        </ram:SpecifiedTaxRegistration>\n|;
        }

    return
        qq|    <ram:ApplicableHeaderTradeAgreement>\n| .
        qq|      <ram:BuyerReference>| . _esc($buyer_ref) . qq|</ram:BuyerReference>\n| .
        qq|      <ram:SellerTradeParty>\n| .
        qq|        <ram:Name>| . _esc($form->{company}) . qq|</ram:Name>\n| .
        $seller_contact .
        qq|        <ram:PostalTradeAddress>\n| .
        qq|          <ram:PostcodeCode>| . _esc($form->{companyzip}) . qq|</ram:PostcodeCode>\n| .
        qq|          <ram:LineOne>| . _esc($form->{companyaddress1}) . qq|</ram:LineOne>\n| .
        ($seller_line2 =~ /\S/ ? qq|          <ram:LineTwo>$seller_line2</ram:LineTwo>\n| : '') .
        qq|          <ram:CityName>| . _esc($form->{companycity}) . qq|</ram:CityName>\n| .
        qq|          <ram:CountryID>$seller_cc</ram:CountryID>\n| .
        qq|        </ram:PostalTradeAddress>\n| .
        qq|        <ram:SpecifiedTaxRegistration>\n| .
        qq|          <ram:ID schemeID="VA">| . _vat_id($form->{businessnumber}, $seller_cc) . qq|</ram:ID>\n| .
        qq|        </ram:SpecifiedTaxRegistration>\n| .
        qq|      </ram:SellerTradeParty>\n| .
        qq|      <ram:BuyerTradeParty>\n| .
        qq|        <ram:Name>| . _esc($form->{name}) . qq|</ram:Name>\n| .
        qq|        <ram:PostalTradeAddress>\n| .
        qq|          <ram:PostcodeCode>| . _esc($form->{zipcode}) . qq|</ram:PostcodeCode>\n| .
        ($buyer_line1 =~ /\S/ ? qq|          <ram:LineOne>$buyer_line1</ram:LineOne>\n| : '') .
        ($buyer_line2 =~ /\S/ ? qq|          <ram:LineTwo>$buyer_line2</ram:LineTwo>\n| : '') .
        qq|          <ram:CityName>| . _esc($form->{city}) . qq|</ram:CityName>\n| .
        qq|          <ram:CountryID>$buyer_cc</ram:CountryID>\n| .
        qq|        </ram:PostalTradeAddress>\n| .
        $buyer_tax .
        qq|      </ram:BuyerTradeParty>\n| .
        $doc_refs .
        qq|    </ram:ApplicableHeaderTradeAgreement>\n|;
}

sub _trade_delivery {
    my ($form) = @_;

    return
        qq|    <ram:ApplicableHeaderTradeDelivery>\n| .
        qq|      <ram:ActualDeliverySupplyChainEvent>\n| .
        qq|        <ram:OccurrenceDateTime>\n| .
        qq|          <udt:DateTimeString format="102">| . _esc($form->{xml_invdate}) . qq|</udt:DateTimeString>\n| .
        qq|        </ram:OccurrenceDateTime>\n| .
        qq|      </ram:ActualDeliverySupplyChainEvent>\n| .
        qq|    </ram:ApplicableHeaderTradeDelivery>\n|;
}

sub _trade_settlement {
    my ($form) = @_;

    my $currency   = _esc($form->{currency});
    my $subtotal   = _amt($form->{xml_subtotal});
    my $totaltax   = _amt($form->{xml_totaltax});
    my $invtotal   = _amt($form->{xml_invtotal});
    my $iban       = _esc($form->{iban});
    my $duedate    = _esc($form->{xml_duedate});
    # Payment means: $form->{paymentmethod} is an array (one entry per paid
        # account row); fall back to a plain credit transfer if nothing matches.
        my $pm_source = '';
        if ( ref $form->{paymentmethod} eq 'ARRAY' && @{ $form->{paymentmethod} } ) {
            $pm_source = $form->{paymentmethod}[0] // '';
        } elsif ( defined $form->{paymentmethod} && !ref $form->{paymentmethod} ) {
            $pm_source = $form->{paymentmethod};
        }
        my $pm_code = _payment_means_code($pm_source);

        # Per-rate tax breakdown.  CategoryCode follows the same rule as line
        # items: zero rate -> Z, otherwise S.

    my $tax_blocks = '';
    my $ntax = scalar @{ $form->{tax} // [] };
    for my $i ( 0 .. $ntax - 1 ) {
        my $tax_amt  = _amt($form->{xml_tax}[$i]);
        my $tax_base = _amt($form->{xml_taxbase}[$i]);
        my $tax_rate = _pct($form->{xml_taxrate}[$i]);
        my $cat      = ( ($form->{xml_taxrate}[$i] // 0) + 0 == 0 ) ? 'Z' : 'S';

        $tax_blocks .=
            qq|      <ram:ApplicableTradeTax>\n| .
            qq|        <ram:CalculatedAmount>$tax_amt</ram:CalculatedAmount>\n| .
            qq|        <ram:TypeCode>VAT</ram:TypeCode>\n| .
            qq|        <ram:BasisAmount>$tax_base</ram:BasisAmount>\n| .
            qq|          <ram:CategoryCode>$cat</ram:CategoryCode>\n| .
            qq|        <ram:RateApplicablePercent>$tax_rate</ram:RateApplicablePercent>\n| .
            qq|      </ram:ApplicableTradeTax>\n|;
    }

    # Payment terms description (BT-20): assembled in English/German neutral
        # form so the buyer sees the terms in the structured invoice as well as
        # on the visible PDF.
        my $terms_desc;
        if ( defined $form->{terms} && $form->{terms} =~ /\S/
            && defined $form->{duedate} && $form->{duedate} =~ /\S/ )
        {
            $terms_desc = "Payable within $form->{terms} days, due on $form->{duedate}.";
        } elsif ( defined $form->{duedate} && $form->{duedate} =~ /\S/ ) {
            $terms_desc = "Due on $form->{duedate}.";
        } else {
            $terms_desc = 'Net payment terms.';
        }

    return
        qq|    <ram:ApplicableHeaderTradeSettlement>\n| .
        qq|      <ram:InvoiceCurrencyCode>$currency</ram:InvoiceCurrencyCode>\n| .
        qq|      <ram:SpecifiedTradeSettlementPaymentMeans>\n| .
        qq|        <ram:TypeCode>$pm_code</ram:TypeCode>\n| .
        ($iban =~ /\S/
            ? qq|        <ram:PayeePartyCreditorFinancialAccount>\n| .
              qq|          <ram:IBANID>$iban</ram:IBANID>\n| .
              qq|        </ram:PayeePartyCreditorFinancialAccount>\n|
            : '') .
        qq|      </ram:SpecifiedTradeSettlementPaymentMeans>\n| .
        $tax_blocks .
        qq|      <ram:SpecifiedTradePaymentTerms>\n| .
        qq|        <ram:Description>| . _esc($terms_desc) . qq|</ram:Description>\n| .
        qq|        <ram:DueDateDateTime>\n| .
        qq|          <udt:DateTimeString format="102">$duedate</udt:DateTimeString>\n| .
        qq|        </ram:DueDateDateTime>\n| .
        qq|      </ram:SpecifiedTradePaymentTerms>\n| .
        qq|      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n| .
        qq|        <ram:LineTotalAmount>$subtotal</ram:LineTotalAmount>\n| .
        qq|        <ram:ChargeTotalAmount>0.00</ram:ChargeTotalAmount>\n| .
        qq|        <ram:AllowanceTotalAmount>0.00</ram:AllowanceTotalAmount>\n| .
        qq|        <ram:TaxBasisTotalAmount>$subtotal</ram:TaxBasisTotalAmount>\n| .
        qq|        <ram:TaxTotalAmount currencyID="$currency">$totaltax</ram:TaxTotalAmount>\n| .
        qq|        <ram:GrandTotalAmount>$invtotal</ram:GrandTotalAmount>\n| .
        qq|        <ram:DuePayableAmount>$invtotal</ram:DuePayableAmount>\n| .
        qq|      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n| .
        qq|    </ram:ApplicableHeaderTradeSettlement>\n|;
}

sub _footer {
    return
        qq|  </rsm:SupplyChainTradeTransaction>\n| .
        qq|</rsm:CrossIndustryInvoice>\n|;
}

1;