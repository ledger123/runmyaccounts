#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sl_zugferd.py -- Turn a SQL-Ledger customer invoice PDF into a
ZUGFeRD / Factur-X 2.x (EN 16931 / "COMFORT") hybrid PDF/A-3.

Workflow
--------
1.  Read invoice data straight out of the SQL-Ledger PostgreSQL schema
    (ar, customer, invoice, parts, acc_trans, chart).
2.  Build a Cross-Industry-Invoice (CII) XML conforming to EN 16931
    (urn:cen.eu:en16931:2017).
3.  Convert the LaTeX-generated PDF that SQL-Ledger has just produced
    into PDF/A-3b and embed the XML under the mandatory filename
    ``factur-x.xml`` together with the required XMP metadata.

Usage
-----
    sl_zugferd.py  --invoice-id 1234  --pdf-in /tmp/inv.pdf \\
                   --pdf-out /tmp/inv-zugferd.pdf

Exit code is 0 on success, non-zero on any failure (so the caller can
keep the original PDF if conversion fails).

Dependencies
------------
    pip install factur-x psycopg2-binary pikepdf
    apt install ghostscript                # for the PDF/A-3 conversion

Why factur-x + Ghostscript?
---------------------------
The pure-CLI route (Ghostscript + exiftool/pdftk) works but is fragile:
you have to hand-craft the XMP extension schema, the AFRelationship key,
and the /AF entry in the catalog.  The ``factur-x`` Python library does
exactly that for you and is the de-facto reference implementation
maintained by Akretion (also used by Odoo).  We therefore use it to do
the embedding, and only fall back to Ghostscript for the PDF/A-3
"flattening" of the incoming PDF when that PDF isn't already PDF/A.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import decimal
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from decimal import Decimal
from typing import Any, Dict, List, Optional, Tuple

try:
    import psycopg2
    import psycopg2.extras
except ImportError:  # pragma: no cover - defer to runtime error
    psycopg2 = None  # type: ignore

try:
    from lxml import etree
except ImportError:  # pragma: no cover
    etree = None  # type: ignore

try:
    from facturx import generate_from_file
except ImportError:  # pragma: no cover
    generate_from_file = None  # type: ignore


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_CONFIG = {
    # PostgreSQL connection.  Under SQL-Ledger the connection is supplied
    # by the calling process (Form.pm forwards the active dataset's
    # credentials via the standard libpq PG* environment variables), so
    # the `db` block here is only used when the script is invoked
    # standalone from the CLI.  Resolution order at runtime is:
    #   1. --db-* CLI flags
    #   2. PG* environment variables (PGHOST/PGPORT/PGDATABASE/PGUSER/
    #      PGPASSWORD) -- libpq standard, also what SL/Form.pm sets
    #   3. the `db` block below / from --config
    "db": {
        "host": None,
        "port": None,
        "dbname": None,
        "user": None,
        "password": None,
    },
    # ZUGFeRD profile / conformance.  EN 16931 == "COMFORT".
    "profile": "en16931",
    # Seller override block.  All fields are read from the per-tenant
    # SQL-Ledger DB first (defaults + bank tables, same source the PDF
    # uses).  Any non-empty value supplied here overrides the DB value.
    # For a standard SL-driven install this entire block can be omitted.
    "seller": {
        "name":     "",
        "street":   "",
        "city":     "",
        "postcode": "",
        "country":  "",
        "vat_id":   "",   # USt-IdNr. (BT-31) ? DB: defaults.businessnumber
        "tax_id":   "",   # Steuernummer (BT-32) ? not stored in SL by default
        "email":    "",
        "iban":     "",   # BT-84 ? DB: bank.iban via ar.bank_id
        "bic":      "",   # BT-86 ? DB: bank.bic  via ar.bank_id
    },
    # PDF/A-3 conversion.  Set to None to skip the Ghostscript step
    # (useful if your template already produces PDF/A).
    "ghostscript": "gs",
    # ICC profile used by Ghostscript for the PDF/A output intent.
    # Most distributions ship sRGB at this path; override if needed.
    "icc_profile": "/usr/share/color/icc/sRGB.icc",
}


def load_config(path: Optional[str]) -> Dict[str, Any]:
    cfg = json.loads(json.dumps(DEFAULT_CONFIG))  # deep copy
    if not path:
        return cfg
    with open(path, "r", encoding="utf-8") as fh:
        user_cfg = json.load(fh)

    def _merge(dst: Dict[str, Any], src: Dict[str, Any]) -> None:
        for k, v in src.items():
            if isinstance(v, dict) and isinstance(dst.get(k), dict):
                _merge(dst[k], v)
            else:
                dst[k] = v

    _merge(cfg, user_cfg)
    return cfg


def resolve_db_params(cli_args: argparse.Namespace,
                      cfg: Dict[str, Any]) -> Dict[str, Any]:
    """Resolve the libpq connection params.

    Precedence (highest first):
      1. ``--db-*`` command-line flags
      2. ``PG*`` environment variables (libpq standard; SL/Form.pm
         exports these for the active dataset on multi-tenant installs)
      3. ``db`` block from the JSON config / defaults

    Returns a dict suitable for ``psycopg2.connect(**params)``; keys
    whose value is ``None``/empty are dropped so libpq applies its own
    defaults (e.g. peer auth, ``$PGHOST`` socket dir).
    """
    cfg_db = cfg.get("db") or {}
    layers = [
        # Lowest priority: config file / defaults.
        {
            "host":     cfg_db.get("host"),
            "port":     cfg_db.get("port"),
            "dbname":   cfg_db.get("dbname"),
            "user":     cfg_db.get("user"),
            "password": cfg_db.get("password"),
        },
        # Then: PG* env vars.
        {
            "host":     os.environ.get("PGHOST"),
            "port":     os.environ.get("PGPORT"),
            "dbname":   os.environ.get("PGDATABASE"),
            "user":     os.environ.get("PGUSER"),
            "password": os.environ.get("PGPASSWORD"),
        },
        # Highest: CLI flags.
        {
            "host":     getattr(cli_args, "db_host",     None),
            "port":     getattr(cli_args, "db_port",     None),
            "dbname":   getattr(cli_args, "db_name",     None),
            "user":     getattr(cli_args, "db_user",     None),
            "password": getattr(cli_args, "db_password", None),
        },
    ]

    params: Dict[str, Any] = {}
    for layer in layers:
        for k, v in layer.items():
            if v is None or v == "":
                continue
            params[k] = v

    if "port" in params:
        try:
            params["port"] = int(params["port"])
        except (TypeError, ValueError):
            del params["port"]

    return params


# ---------------------------------------------------------------------------
# Database extraction
# ---------------------------------------------------------------------------

def _d(v: Any) -> Decimal:
    """Coerce *anything* numeric to Decimal with 2-digit rounding."""
    if v is None:
        return Decimal("0.00")
    return Decimal(str(v)).quantize(Decimal("0.01"),
                                    rounding=decimal.ROUND_HALF_UP)


def _d4(v: Any) -> Decimal:
    if v is None:
        return Decimal("0.0000")
    return Decimal(str(v)).quantize(Decimal("0.0001"),
                                    rounding=decimal.ROUND_HALF_UP)


def fetch_invoice(conn, invoice_id: int) -> Dict[str, Any]:
    """Pull a single AR invoice with everything we need for ZUGFeRD."""
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # ----- header -------------------------------------------------------
    cur.execute(
        """
        SELECT a.id,
               a.invnumber,
               a.transdate,
               a.duedate,
               a.ordnumber,
               a.notes,
               a.intnotes,
               a.curr,
               a.amount     AS gross_amount,
               a.netamount  AS net_amount,
               a.paid,
               a.terms,
               c.id              AS customer_id,
               c.name            AS customer_name,
               c.address1        AS customer_address1,
               c.address2        AS customer_address2,
               c.city            AS customer_city,
               c.zipcode         AS customer_zip,
               c.country         AS customer_country,
               c.email           AS customer_email,
               c.taxnumber       AS customer_taxnumber,
               c.iban            AS customer_iban,
               c.gifi_accno      AS customer_gifi,
               c.customernumber  AS customer_number
          FROM ar a
          JOIN customer c ON c.id = a.customer_id
         WHERE a.id = %s
        """,
        (invoice_id,),
    )
    head = cur.fetchone()
    if head is None:
        raise RuntimeError(f"AR invoice id={invoice_id} not found")

    # SQL-Ledger stores the VAT-id either on customer.taxnumber or on a
    # custom field; we expose both.
    head["customer_vat_id"] = head.get("customer_taxnumber") or ""

    # ----- line items --------------------------------------------------
    cur.execute(
        """
        SELECT i.id,
               i.parts_id,
               i.description,
               i.qty,
               i.sellprice,
               i.discount,
               i.unit,
               i.fxsellprice,
               p.partnumber,
               p.partnumber AS sku,
               COALESCE( (
                   SELECT SUM(t.rate)
                     FROM partstax pt
                     JOIN tax       t  ON t.chart_id = pt.chart_id
                    WHERE pt.parts_id = i.parts_id
               ), 0)::numeric AS taxrate
          FROM invoice i
          JOIN parts   p ON p.id = i.parts_id
         WHERE i.trans_id = %s
           AND COALESCE(i.assemblyitem,'f') = 'f'
         ORDER BY i.id
        """,
        (invoice_id,),
    )
    rows = cur.fetchall() or []
    lines: List[Dict[str, Any]] = []
    for r in rows:
        qty       = _d4(r["qty"])
        sellprice = _d4(r["sellprice"])
        discount  = _d4(r["discount"] or 0)               # 0.00 .. 1.00
        net       = _d(qty * sellprice * (Decimal("1") - discount))
        rate_pct  = _d4(Decimal(str(r["taxrate"] or 0)) * 100)
        lines.append({
            "sku":         r["partnumber"] or "",
            "name":        (r["description"] or "").strip() or
                           (r["partnumber"] or ""),
            "qty":         qty,
            "unit":        (r["unit"] or "C62").strip() or "C62",
            "unit_price":  sellprice,
            "discount":    discount,
            "net_amount":  net,
            "tax_percent": rate_pct,
        })

    # ----- tax breakdown from acc_trans -------------------------------
    # SQL-Ledger writes one row per tax account into acc_trans; the
    # account is flagged in chart as tax-link 'AR_tax'.
    cur.execute(
        """
        SELECT c.accno,
               c.description,
               COALESCE(t.rate, 0)::numeric * 100      AS rate_pct,
               SUM(ac.amount)::numeric                 AS tax_amount
          FROM acc_trans ac
          JOIN chart c ON c.id = ac.chart_id
          LEFT JOIN tax t ON t.chart_id = c.id
         WHERE ac.trans_id = %s
           AND c.link LIKE '%%AR_tax%%'
         GROUP BY c.accno, c.description, t.rate
         ORDER BY c.accno
        """,
        (invoice_id,),
    )
    tax_rows = cur.fetchall() or []
    # Group lines by tax rate to get the per-rate net base.
    bases: Dict[Decimal, Decimal] = {}
    for ln in lines:
        bases.setdefault(ln["tax_percent"], Decimal("0.00"))
        bases[ln["tax_percent"]] += ln["net_amount"]

    tax_breakdown: List[Dict[str, Any]] = []
    for tr in tax_rows:
        rate = _d4(tr["rate_pct"])
        # acc_trans stores tax amounts on the credit side (negative).
        amount = abs(_d(tr["tax_amount"]))
        base = bases.get(rate, Decimal("0.00"))
        tax_breakdown.append({
            "rate":   rate,
            "base":   base,
            "amount": amount,
            "category": "S" if rate > 0 else "Z",  # S=standard, Z=zero
        })

    # If acc_trans gave us nothing useful (e.g. tax inclusive prices),
    # fall back to a synthetic breakdown computed from the line items.
    if not tax_breakdown:
        for rate, base in bases.items():
            amount = _d(base * rate / Decimal("100"))
            tax_breakdown.append({
                "rate":   rate,
                "base":   base,
                "amount": amount,
                "category": "S" if rate > 0 else "Z",
            })

    cur.close()

    # ----- totals ------------------------------------------------------
    net_total  = _d(sum((ln["net_amount"] for ln in lines), Decimal("0")))
    tax_total  = _d(sum((t["amount"]      for t in tax_breakdown),
                        Decimal("0")))
    gross_total = _d(head["gross_amount"] or (net_total + tax_total))
    paid_total = _d(head["paid"] or 0)

    return {
        "id":              head["id"],
        "number":          head["invnumber"],
        "issue_date":      head["transdate"],
        "due_date":        head["duedate"] or head["transdate"],
        "order_number":    head["ordnumber"],
        "notes":           head["notes"],
        "payment_terms":   (head["terms"] and f"Net {head['terms']} days") or "",
        "currency":        (head["curr"] or "EUR")[:3].upper(),
        "buyer": {
            "id":       head["customer_number"],
            "name":     head["customer_name"],
            "street":   " ".join(filter(None, [head["customer_address1"],
                                               head["customer_address2"]])),
            "postcode": head["customer_zip"] or "",
            "city":     head["customer_city"] or "",
            "country":  (head["customer_country"] or "DE")[:2].upper(),
            "vat_id":   head["customer_vat_id"],
            "email":    head["customer_email"],
        },
        "lines":         lines,
        "tax_breakdown": tax_breakdown,
        "net_total":     net_total,
        "tax_total":     tax_total,
        "gross_total":   gross_total,
        "paid_total":    paid_total,
        "due_total":     _d(gross_total - paid_total),
    }


def fetch_seller(conn, invoice_id: int) -> Dict[str, Any]:
    """Read seller data from the SQL-Ledger per-tenant DB.

    Mirrors what SL/IS.pm does when building the PDF:
    - Company name, address components and VAT id come from the
      ``defaults`` table (fldnames: company, address1, address2, city,
      state, zip, country, businessnumber, companyemail).
    - IBAN and BIC come from the ``bank`` row linked to the invoice's
      payment account via ``ar.bank_id``.  This is the same join that
      IS.pm:663 uses to populate the IBAN on the PDF.
    """
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Fetch all relevant defaults in a single round-trip.
    cur.execute(
        """
        SELECT fldname, fldvalue
          FROM defaults
         WHERE fldname IN (
               'company', 'address1', 'address2', 'city', 'state',
               'zip', 'country', 'businessnumber', 'companyemail'
         )
        """
    )
    defs: Dict[str, str] = {
        row["fldname"]: (row["fldvalue"] or "")
        for row in (cur.fetchall() or [])
    }

    # IBAN / BIC: ar.bank_id ? bank (same path as IS.pm:663).
    cur.execute(
        """
        SELECT bk.iban, bk.bic
          FROM ar   a
          JOIN bank bk ON bk.id = a.bank_id
         WHERE a.id = %s
        """,
        (invoice_id,),
    )
    bank_row = cur.fetchone() or {}
    cur.close()

    street = " ".join(filter(None, [defs.get("address1"), defs.get("address2")]))
    country = (defs.get("country") or "DE")[:2].upper()

    return {
        "name":     defs.get("company") or "",
        "street":   street,
        "postcode": defs.get("zip") or "",
        "city":     defs.get("city") or "",
        "country":  country,
        "vat_id":   defs.get("businessnumber") or "",
        "tax_id":   "",       # SL has no separate column for BT-32
        "email":    defs.get("companyemail") or "",
        "iban":     bank_row.get("iban") or "",
        "bic":      bank_row.get("bic") or "",
    }


def _merge_seller(db_seller: Dict[str, Any],
                  cfg_seller: Dict[str, Any]) -> Dict[str, Any]:
    """Merge DB and config seller data.

    The DB is the primary source (it is per-tenant and matches what the
    PDF shows).  A non-empty value from *cfg_seller* overrides the DB
    value, allowing installations to supply fields that SL does not
    store (e.g. BT-32 tax_id, or a non-standard vat_id column name).
    """
    merged: Dict[str, Any] = {}
    for key in ("name", "street", "postcode", "city", "country",
                "vat_id", "tax_id", "email", "iban", "bic"):
        cfg_val = cfg_seller.get(key) or ""
        merged[key] = cfg_val if cfg_val else (db_seller.get(key) or "")
    return merged


# ---------------------------------------------------------------------------
# Cross-Industry-Invoice XML (EN 16931 / Factur-X COMFORT)
# ---------------------------------------------------------------------------

NS = {
    "rsm": "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
    "ram": "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
    "udt": "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100",
    "qdt": "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
}

GUIDELINE_EN16931 = (
    "urn:cen.eu:en16931:2017"
)
GUIDELINE_BY_PROFILE = {
    "minimum":   "urn:factur-x.eu:1p0:minimum",
    "basicwl":   "urn:factur-x.eu:1p0:basicwl",
    "basic":     "urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic",
    "en16931":   GUIDELINE_EN16931,
    "extended":  "urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended",
}


def _e(parent, qname: str, text: Optional[str] = None, **attrib) -> Any:
    """Helper to create a namespaced element."""
    prefix, local = qname.split(":")
    el = etree.SubElement(parent,
                          f"{{{NS[prefix]}}}{local}",
                          attrib={k: str(v) for k, v in attrib.items()})
    if text is not None:
        el.text = str(text)
    return el


def _fmt_amount(v: Decimal) -> str:
    return f"{v:.2f}"


def _fmt_qty(v: Decimal) -> str:
    return f"{v:.4f}"


def _fmt_date(d: Any) -> str:
    if isinstance(d, _dt.date):
        return d.strftime("%Y%m%d")
    # SQL-Ledger may give us a string already
    s = str(d)
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", s)
    if m:
        return "".join(m.groups())
    return s


def build_xml(inv: Dict[str, Any], seller: Dict[str, Any],
              profile: str = "en16931") -> bytes:
    """Render the Factur-X CII XML for *inv*."""
    if etree is None:
        raise RuntimeError("lxml is required (pip install lxml)")

    guideline = GUIDELINE_BY_PROFILE.get(profile, GUIDELINE_EN16931)

    root = etree.Element(
        f"{{{NS['rsm']}}}CrossIndustryInvoice",
        nsmap=NS,
    )

    # --- ExchangedDocumentContext ------------------------------------
    ctx = _e(root, "rsm:ExchangedDocumentContext")
    gp  = _e(ctx, "ram:GuidelineSpecifiedDocumentContextParameter")
    _e(gp, "ram:ID", guideline)

    # --- ExchangedDocument -------------------------------------------
    doc = _e(root, "rsm:ExchangedDocument")
    _e(doc, "ram:ID", inv["number"])
    _e(doc, "ram:TypeCode", "380")  # 380 = commercial invoice
    iss = _e(doc, "ram:IssueDateTime")
    dts = _e(iss, "udt:DateTimeString", _fmt_date(inv["issue_date"]),
             format="102")
    if inv.get("notes"):
        note = _e(doc, "ram:IncludedNote")
        _e(note, "ram:Content", inv["notes"])

    # --- SupplyChainTradeTransaction ---------------------------------
    txn = _e(root, "rsm:SupplyChainTradeTransaction")

    # ........ line items ............................................
    for i, ln in enumerate(inv["lines"], start=1):
        item = _e(txn, "ram:IncludedSupplyChainTradeLineItem")
        ad = _e(item, "ram:AssociatedDocumentLineDocument")
        _e(ad, "ram:LineID", str(i))

        prod = _e(item, "ram:SpecifiedTradeProduct")
        if ln["sku"]:
            _e(prod, "ram:SellerAssignedID", ln["sku"])
        _e(prod, "ram:Name", ln["name"])

        agree = _e(item, "ram:SpecifiedLineTradeAgreement")
        gross = _e(agree, "ram:GrossPriceProductTradePrice")
        _e(gross, "ram:ChargeAmount", _fmt_amount(_d(ln["unit_price"])))
        if ln["discount"] and ln["discount"] != 0:
            ad_el = _e(gross, "ram:AppliedTradeAllowanceCharge")
            ci = _e(ad_el, "ram:ChargeIndicator")
            _e(ci, "udt:Indicator", "false")     # false == allowance
            _e(ad_el, "ram:ActualAmount",
               _fmt_amount(_d(ln["unit_price"] * ln["discount"])))
        net = _e(agree, "ram:NetPriceProductTradePrice")
        net_unit = _d(ln["unit_price"] * (Decimal("1") - ln["discount"]))
        _e(net, "ram:ChargeAmount", _fmt_amount(net_unit))

        deliv = _e(item, "ram:SpecifiedLineTradeDelivery")
        _e(deliv, "ram:BilledQuantity", _fmt_qty(ln["qty"]),
           unitCode=ln["unit"][:3] if len(ln["unit"]) <= 3 else "C62")

        settle = _e(item, "ram:SpecifiedLineTradeSettlement")
        tax = _e(settle, "ram:ApplicableTradeTax")
        _e(tax, "ram:TypeCode", "VAT")
        _e(tax, "ram:CategoryCode", "S" if ln["tax_percent"] > 0 else "Z")
        _e(tax, "ram:RateApplicablePercent", _fmt_amount(ln["tax_percent"]))
        summ = _e(settle, "ram:SpecifiedTradeSettlementLineMonetarySummation")
        _e(summ, "ram:LineTotalAmount", _fmt_amount(ln["net_amount"]))

    # ........ seller / buyer ........................................
    agreement = _e(txn, "ram:ApplicableHeaderTradeAgreement")

    s = _e(agreement, "ram:SellerTradeParty")
    _e(s, "ram:Name", seller["name"] or "")
    addr = _e(s, "ram:PostalTradeAddress")
    _e(addr, "ram:PostcodeCode", seller["postcode"] or "")
    _e(addr, "ram:LineOne",      seller["street"]   or "")
    _e(addr, "ram:CityName",     seller["city"]     or "")
    _e(addr, "ram:CountryID",    seller["country"]  or "DE")
    if seller.get("vat_id"):
        treg = _e(s, "ram:SpecifiedTaxRegistration")
        _e(treg, "ram:ID", seller["vat_id"], schemeID="VA")
    if seller.get("tax_id"):
        treg = _e(s, "ram:SpecifiedTaxRegistration")
        _e(treg, "ram:ID", seller["tax_id"], schemeID="FC")

    b = _e(agreement, "ram:BuyerTradeParty")
    if inv["buyer"].get("id"):
        _e(b, "ram:ID", inv["buyer"]["id"])
    _e(b, "ram:Name", inv["buyer"]["name"] or "")
    baddr = _e(b, "ram:PostalTradeAddress")
    _e(baddr, "ram:PostcodeCode", inv["buyer"]["postcode"])
    _e(baddr, "ram:LineOne",      inv["buyer"]["street"])
    _e(baddr, "ram:CityName",     inv["buyer"]["city"])
    _e(baddr, "ram:CountryID",    inv["buyer"]["country"])
    if inv["buyer"].get("vat_id"):
        treg = _e(b, "ram:SpecifiedTaxRegistration")
        _e(treg, "ram:ID", inv["buyer"]["vat_id"], schemeID="VA")

    if inv.get("order_number"):
        bor = _e(agreement, "ram:BuyerOrderReferencedDocument")
        _e(bor, "ram:IssuerAssignedID", inv["order_number"])

    # delivery (mandatory at COMFORT level even if empty)
    deliv = _e(txn, "ram:ApplicableHeaderTradeDelivery")
    chain = _e(deliv, "ram:ActualDeliverySupplyChainEvent")
    occ   = _e(chain, "ram:OccurrenceDateTime")
    _e(occ, "udt:DateTimeString", _fmt_date(inv["issue_date"]), format="102")

    # settlement -------------------------------------------------------
    settle = _e(txn, "ram:ApplicableHeaderTradeSettlement")
    _e(settle, "ram:InvoiceCurrencyCode", inv["currency"])

    # payment means -- code 30 == credit transfer (SEPA)
    if seller.get("iban"):
        pm = _e(settle, "ram:SpecifiedTradeSettlementPaymentMeans")
        _e(pm, "ram:TypeCode", "30")
        acct = _e(pm, "ram:PayeePartyCreditorFinancialAccount")
        _e(acct, "ram:IBANID", seller["iban"])
        if seller.get("bic"):
            inst = _e(pm, "ram:PayeeSpecifiedCreditorFinancialInstitution")
            _e(inst, "ram:BICID", seller["bic"])

    for tb in inv["tax_breakdown"]:
        t = _e(settle, "ram:ApplicableTradeTax")
        _e(t, "ram:CalculatedAmount", _fmt_amount(tb["amount"]))
        _e(t, "ram:TypeCode", "VAT")
        _e(t, "ram:BasisAmount", _fmt_amount(tb["base"]))
        _e(t, "ram:CategoryCode", tb["category"])
        _e(t, "ram:RateApplicablePercent", _fmt_amount(tb["rate"]))

    pt = _e(settle, "ram:SpecifiedTradePaymentTerms")
    if inv.get("payment_terms"):
        _e(pt, "ram:Description", inv["payment_terms"])
    due = _e(pt, "ram:DueDateDateTime")
    _e(due, "udt:DateTimeString", _fmt_date(inv["due_date"]), format="102")

    summ = _e(settle, "ram:SpecifiedTradeSettlementHeaderMonetarySummation")
    _e(summ, "ram:LineTotalAmount",      _fmt_amount(inv["net_total"]))
    _e(summ, "ram:TaxBasisTotalAmount",  _fmt_amount(inv["net_total"]))
    _e(summ, "ram:TaxTotalAmount",       _fmt_amount(inv["tax_total"]),
       currencyID=inv["currency"])
    _e(summ, "ram:GrandTotalAmount",     _fmt_amount(inv["gross_total"]))
    _e(summ, "ram:TotalPrepaidAmount",   _fmt_amount(inv["paid_total"]))
    _e(summ, "ram:DuePayableAmount",     _fmt_amount(inv["due_total"]))

    return etree.tostring(root, pretty_print=True, xml_declaration=True,
                          encoding="UTF-8", standalone=False)


# ---------------------------------------------------------------------------
# PDF/A-3 conversion + embedding
# ---------------------------------------------------------------------------

def ensure_pdfa3(pdf_in: str, pdf_out: str, cfg: Dict[str, Any]) -> None:
    """Convert *pdf_in* to PDF/A-3b via Ghostscript.

    This is required because pdflatex produces a plain PDF, but
    ZUGFeRD/Factur-X mandates PDF/A-3.  factur-x's generator will add
    the embedded file + XMP, but it expects the carrier PDF to already
    be PDF/A.
    """
    gs = cfg.get("ghostscript") or "gs"
    icc = cfg.get("icc_profile") or "/usr/share/color/icc/sRGB.icc"

    if not shutil.which(gs):
        raise RuntimeError(f"Ghostscript '{gs}' not found in PATH")

    # Minimal PDFA_def.ps stream telling Ghostscript what output intent
    # to use.  Written to a temp file because the path to the ICC
    # profile must be substituted in.
    ps = (
        "[ /Title (Invoice)\n"
        "  /DOCINFO pdfmark\n"
        "[ /_objdef {icc_PDFA} /type /stream /OBJ pdfmark\n"
        "[ {icc_PDFA} <</N 3>> /PUT pdfmark\n"
        f"[ {{icc_PDFA}} ({icc}) (r) file /PUT pdfmark\n"
        "[ /_objdef {OutputIntent_PDFA} /type /dict /OBJ pdfmark\n"
        "[ {OutputIntent_PDFA} <<\n"
        "    /Type /OutputIntent /S /GTS_PDFA1\n"
        "    /DestOutputProfile {icc_PDFA}\n"
        "    /OutputConditionIdentifier (sRGB)\n"
        "    /Info (sRGB)\n"
        "  >> /PUT pdfmark\n"
        "[ {Catalog} <</OutputIntents [{OutputIntent_PDFA}]>> /PUT pdfmark\n"
    )

    with tempfile.NamedTemporaryFile("w", suffix=".ps", delete=False) as tf:
        tf.write(ps)
        pdfa_def = tf.name

    try:
        cmd = [
            gs,
            "-dPDFA=3",
            "-dBATCH", "-dNOPAUSE", "-dQUIET",
            "-sColorConversionStrategy=UseDeviceIndependentColor",
            "-sDEVICE=pdfwrite",
            "-dPDFACompatibilityPolicy=1",
            f"-sOutputFile={pdf_out}",
            pdfa_def,
            pdf_in,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0 or not os.path.exists(pdf_out):
            raise RuntimeError(
                f"Ghostscript PDF/A-3 conversion failed:\n{res.stderr}")
    finally:
        try:
            os.unlink(pdfa_def)
        except OSError:
            pass


def embed_xml(pdf_path: str, xml_bytes: bytes, inv: Dict[str, Any],
              profile: str = "en16931") -> None:
    """Embed *xml_bytes* into *pdf_path* in-place as factur-x.xml."""
    if generate_from_file is None:
        raise RuntimeError(
            "factur-x library missing (pip install factur-x)")

    pdf_meta = {
        "author":   "SQL-Ledger",
        "keywords": f"{inv['number']}, Invoice, Factur-X",
        "title":    f"Invoice {inv['number']}",
        "subject":  f"Factur-X invoice {inv['number']} "
                    f"dated {inv['issue_date']}",
    }
    generate_from_file(
        pdf_path,
        xml_bytes,
        flavor="factur-x",
        level=profile,             # 'en16931' == COMFORT
        check_xsd=False,
        pdf_metadata=pdf_meta,
        output_pdf_file=pdf_path,  # overwrite in place
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        description="Convert a SQL-Ledger invoice PDF into a ZUGFeRD/"
                    "Factur-X (PDF/A-3) hybrid invoice.")
    ap.add_argument("--invoice-id", type=int, required=True,
                    help="ar.id of the invoice in SQL-Ledger")
    ap.add_argument("--pdf-in",  required=True,
                    help="Path to the PDF produced by SQL-Ledger/pdflatex")
    ap.add_argument("--pdf-out", required=True,
                    help="Destination path of the ZUGFeRD PDF")
    ap.add_argument("--config",
                    help="JSON file with DB + seller configuration")
    ap.add_argument("--xml-only", action="store_true",
                    help="Write only the XML (to --pdf-out) -- useful "
                         "for debugging / validation runs")
    ap.add_argument("--keep-xml",
                    help="Also write the raw XML to this path")
    # DB connection overrides (highest priority).  Normally SL/Form.pm
    # sets PG* env vars instead, so these are only useful on the CLI.
    ap.add_argument("--db-host",     help="PostgreSQL host (overrides PGHOST / config)")
    ap.add_argument("--db-port",     help="PostgreSQL port (overrides PGPORT / config)")
    ap.add_argument("--db-name",     help="PostgreSQL database (overrides PGDATABASE / config)")
    ap.add_argument("--db-user",     help="PostgreSQL user (overrides PGUSER / config)")
    ap.add_argument("--db-password", help="PostgreSQL password (overrides PGPASSWORD / config)")
    args = ap.parse_args(argv)

    cfg = load_config(args.config)

    if psycopg2 is None:
        print("psycopg2 is required (pip install psycopg2-binary)",
              file=sys.stderr)
        return 2

    conn = psycopg2.connect(**resolve_db_params(args, cfg))
    try:
        inv = fetch_invoice(conn, args.invoice_id)
        db_seller = fetch_seller(conn, args.invoice_id)
    finally:
        conn.close()

    seller = _merge_seller(db_seller, cfg.get("seller") or {})
    xml = build_xml(inv, seller, profile=cfg.get("profile", "en16931"))

    if args.keep_xml:
        with open(args.keep_xml, "wb") as fh:
            fh.write(xml)

    if args.xml_only:
        with open(args.pdf_out, "wb") as fh:
            fh.write(xml)
        return 0

    if not os.path.exists(args.pdf_in):
        print(f"Input PDF not found: {args.pdf_in}", file=sys.stderr)
        return 3

    # Copy input -> output then convert in place; this way a failure
    # in Ghostscript / factur-x leaves the original PDF untouched.
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tf:
        pdfa_tmp = tf.name
    try:
        ensure_pdfa3(args.pdf_in, pdfa_tmp, cfg)
        embed_xml(pdfa_tmp, xml, inv,
                  profile=cfg.get("profile", "en16931"))
        shutil.move(pdfa_tmp, args.pdf_out)
    finally:
        if os.path.exists(pdfa_tmp):
            try:
                os.unlink(pdfa_tmp)
            except OSError:
                pass

    return 0


if __name__ == "__main__":
    sys.exit(main())