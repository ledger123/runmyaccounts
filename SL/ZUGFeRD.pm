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
# Generates a ZUGFeRD (Factur-X basic profile, EN 16931) XML document
# directly from the invoice form data populated by IS::invoice_details.
# The XML can be used as a standalone file, an email attachment, or
# embedded in a PDF/A-3 document.
#
#======================================================================

package ZUGFeRD;

use strict;

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
sub _esc {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
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
        qq|      <ram:ID>urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic</ram:ID>\n| .
        qq|    </ram:GuidelineSpecifiedDocumentContextParameter>\n| .
        qq|  </rsm:ExchangedDocumentContext>\n| .
        qq|  <rsm:ExchangedDocument>\n| .
        qq|    <ram:ID>| . _esc($form->{invnumber}) . qq|</ram:ID>\n| .
        qq|    <ram:TypeCode>$typecode</ram:TypeCode>\n| .
        qq|    <ram:IssueDateTime>\n| .
        qq|      <udt:DateTimeString format="102">| . _esc($form->{xml_invdate}) . qq|</udt:DateTimeString>\n| .
        qq|    </ram:IssueDateTime>\n| .
        qq|    <ram:IncludedNote>\n| .
        qq|      <ram:Content>| . _esc($form->{invdescription}) . qq|</ram:Content>\n| .
        qq|    </ram:IncludedNote>\n| .
        qq|    <ram:IncludedNote>\n| .
        qq|      <ram:Content>| . _esc(join("\n",
            $form->{company},
            $form->{companyaddress1},
            $form->{companyaddress2},
            "$form->{companyzip} $form->{companycity}",
            $form->{companycountry},
            "E-Mail: $form->{companyemail}",
            "Web: $form->{companywebsite}",
            "MWST-Nr: $form->{businessnumber}",
            "Tel: $form->{tel}",
            "Fax: $form->{fax}",
        )) . qq|</ram:Content>\n| .
        qq|    </ram:IncludedNote>\n| .
        qq|    <ram:IncludedNote>\n| .
        qq|      <ram:Content>| . _esc(join("\n",
            "Offert-Nr.: $form->{quonumber}",
            "Bestell-Nr.: $form->{ordnumber}",
            "Ihre Bestell-Nr.: $form->{ponumber}",
            "Kunden-Nr.: $form->{customernumber}",
            "MWST Nr.: $form->{businessnumber}",
            "Ihre MWST Nr.: $form->{customertaxnumber}",
            "",
            "Wir bedanken uns fuer Ihre Ueberweisung innerhalb von $form->{terms} Tagen bis zum $form->{duedate}.",
        )) . qq|</ram:Content>\n| .
        qq|    </ram:IncludedNote>\n| .
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
        my $itemnotes  = _esc($form->{itemnotes}[$i]);
        my $partno     = _esc($form->{number}[$i]);

        $xml .=
            qq|    <ram:IncludedSupplyChainTradeLineItem>\n| .
            qq|      <ram:AssociatedDocumentLineDocument>\n| .
            qq|        <ram:LineID>$lineid</ram:LineID>\n| .
            qq|      </ram:AssociatedDocumentLineDocument>\n| .
            qq|      <ram:SpecifiedTradeProduct>\n| .
            qq|        <ram:GlobalID schemeID="0160"></ram:GlobalID>\n| .
            qq|        <ram:Name>$desc\n$itemnotes\nUnsere Art. Nr.:$partno</ram:Name>\n| .
            qq|      </ram:SpecifiedTradeProduct>\n| .
            qq|      <ram:SpecifiedLineTradeAgreement>\n| .
            qq|        <ram:NetPriceProductTradePrice>\n| .
            qq|          <ram:ChargeAmount>$sellprice</ram:ChargeAmount>\n| .
            qq|        </ram:NetPriceProductTradePrice>\n| .
            qq|      </ram:SpecifiedLineTradeAgreement>\n| .
            qq|      <ram:SpecifiedLineTradeDelivery>\n| .
            qq|        <ram:BilledQuantity unitCode="C62">$qty</ram:BilledQuantity>\n| .
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

    my $buyer_line1 = _esc(
        join(' ', grep { defined $_ && $_ ne '' }
            $form->{firstname}, $form->{lastname})
    );

    return
        qq|    <ram:ApplicableHeaderTradeAgreement>\n| .
        qq|      <ram:SellerTradeParty>\n| .
        qq|        <ram:Name>| . _esc($form->{company}) . qq|</ram:Name>\n| .
        qq|        <ram:PostalTradeAddress>\n| .
        qq|          <ram:PostcodeCode>| . _esc($form->{companyzip}) . qq|</ram:PostcodeCode>\n| .
        qq|          <ram:LineOne>| . _esc($form->{companyaddress1}) . qq|</ram:LineOne>\n| .
        qq|          <ram:LineTwo>| . _esc($form->{companyaddress2}) . qq|</ram:LineTwo>\n| .
        qq|          <ram:CityName>| . _esc($form->{companycity}) . qq|</ram:CityName>\n| .
        qq|          <ram:CountryID>CH</ram:CountryID>\n| .
        qq|        </ram:PostalTradeAddress>\n| .
        qq|        <ram:SpecifiedTaxRegistration>\n| .
        qq|          <ram:ID schemeID="VA">| . _esc($form->{businessnumber}) . qq|</ram:ID>\n| .
        qq|        </ram:SpecifiedTaxRegistration>\n| .
        qq|      </ram:SellerTradeParty>\n| .
        qq|      <ram:BuyerTradeParty>\n| .
        qq|        <ram:Name>| . _esc($form->{name}) . qq|</ram:Name>\n| .
        qq|        <ram:PostalTradeAddress>\n| .
        qq|          <ram:PostcodeCode>| . _esc($form->{zipcode}) . qq|</ram:PostcodeCode>\n| .
        qq|          <ram:LineOne>$buyer_line1</ram:LineOne>\n| .
        qq|          <ram:LineTwo>| . _esc($form->{address1}) . qq|</ram:LineTwo>\n| .
        qq|          <ram:LineThree>| . _esc($form->{address2}) . qq|</ram:LineThree>\n| .
        qq|          <ram:CityName>| . _esc($form->{city}) . qq|</ram:CityName>\n| .
        qq|          <ram:CountryID>CH</ram:CountryID>\n| .
        qq|        </ram:PostalTradeAddress>\n| .
        qq|      </ram:BuyerTradeParty>\n| .
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

    my $tax_blocks = '';
    my $ntax = scalar @{ $form->{tax} // [] };
    for my $i ( 0 .. $ntax - 1 ) {
        my $tax_amt  = _amt($form->{xml_tax}[$i]);
        my $tax_base = _amt($form->{xml_taxbase}[$i]);
        my $tax_rate = _pct($form->{xml_taxrate}[$i]);

        $tax_blocks .=
            qq|      <ram:ApplicableTradeTax>\n| .
            qq|        <ram:CalculatedAmount>$tax_amt</ram:CalculatedAmount>\n| .
            qq|        <ram:TypeCode>VAT</ram:TypeCode>\n| .
            qq|        <ram:BasisAmount>$tax_base</ram:BasisAmount>\n| .
            qq|        <ram:CategoryCode>S</ram:CategoryCode>\n| .
            qq|        <ram:RateApplicablePercent>$tax_rate</ram:RateApplicablePercent>\n| .
            qq|      </ram:ApplicableTradeTax>\n|;
    }

    return
        qq|    <ram:ApplicableHeaderTradeSettlement>\n| .
        qq|      <ram:InvoiceCurrencyCode>$currency</ram:InvoiceCurrencyCode>\n| .
        qq|      <ram:PayeeTradeParty>\n| .
        qq|        <ram:Name>| . _esc($form->{company}) . qq|</ram:Name>\n| .
        qq|      </ram:PayeeTradeParty>\n| .
        qq|      <ram:SpecifiedTradeSettlementPaymentMeans>\n| .
        qq|        <ram:TypeCode>30</ram:TypeCode>\n| .
        qq|        <ram:PayeePartyCreditorFinancialAccount>\n| .
        qq|          <ram:IBANID>$iban</ram:IBANID>\n| .
        qq|        </ram:PayeePartyCreditorFinancialAccount>\n| .
        qq|      </ram:SpecifiedTradeSettlementPaymentMeans>\n| .
        $tax_blocks .
        qq|      <ram:SpecifiedTradePaymentTerms>\n| .
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