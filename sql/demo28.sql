--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: 
--

CREATE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

--
-- Name: del_department(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION del_department() RETURNS "trigger"
    AS $$
begin
  delete from dpt_trans where trans_id = old.id;
  return NULL;
end;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.del_department() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: acc_trans; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE acc_trans (
    trans_id integer,
    chart_id integer,
    amount double precision,
    transdate date DEFAULT ('now'::text)::date,
    source text,
    approved boolean DEFAULT true,
    fx_transaction boolean DEFAULT false,
    project_id integer,
    memo text,
    id integer,
    cleared date,
    vr_id integer
);


ALTER TABLE public.acc_trans OWNER TO postgres;

--
-- Name: addressid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE addressid
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.addressid OWNER TO postgres;

--
-- Name: addressid; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('addressid', 18, true);


--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE address (
    id integer DEFAULT nextval('addressid'::regclass) NOT NULL,
    trans_id integer,
    address1 character varying(32),
    address2 character varying(32),
    city character varying(32),
    state character varying(32),
    zipcode character varying(10),
    country character varying(32)
);


ALTER TABLE public.address OWNER TO postgres;

--
-- Name: id; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.id OWNER TO postgres;

--
-- Name: id; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('id', 10161, true);


--
-- Name: ap; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ap (
    id integer DEFAULT nextval('id'::regclass),
    invnumber text,
    transdate date DEFAULT ('now'::text)::date,
    vendor_id integer,
    taxincluded boolean DEFAULT false,
    amount double precision,
    netamount double precision,
    paid double precision,
    datepaid date,
    duedate date,
    invoice boolean DEFAULT false,
    ordnumber text,
    curr character(3),
    notes text,
    employee_id integer,
    till character varying(20),
    quonumber text,
    intnotes text,
    department_id integer DEFAULT 0,
    shipvia text,
    language_code character varying(6),
    ponumber text,
    shippingpoint text,
    terms smallint DEFAULT 0,
    approved boolean DEFAULT true,
    cashdiscount real,
    discountterms smallint,
    waybill text,
    warehouse_id integer,
    description text,
    onhold boolean DEFAULT false,
    exchangerate double precision,
    dcn text,
    bank_id integer,
    paymentmethod_id integer,
    ticket_id integer,
    tipodoc_id integer
);


ALTER TABLE public.ap OWNER TO postgres;

--
-- Name: ar; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ar (
    id integer DEFAULT nextval('id'::regclass),
    invnumber text,
    transdate date DEFAULT ('now'::text)::date,
    customer_id integer,
    taxincluded boolean,
    amount double precision,
    netamount double precision,
    paid double precision,
    datepaid date,
    duedate date,
    invoice boolean DEFAULT false,
    shippingpoint text,
    terms smallint DEFAULT 0,
    notes text,
    curr character(3),
    ordnumber text,
    employee_id integer,
    till character varying(20),
    quonumber text,
    intnotes text,
    department_id integer DEFAULT 0,
    shipvia text,
    language_code character varying(6),
    ponumber text,
    approved boolean DEFAULT true,
    cashdiscount real,
    discountterms smallint,
    waybill text,
    warehouse_id integer,
    description text,
    onhold boolean DEFAULT false,
    exchangerate double precision,
    dcn text,
    bank_id integer,
    paymentmethod_id integer,
    ticket_id integer,
    tipodoc_id integer
);


ALTER TABLE public.ar OWNER TO postgres;

--
-- Name: assemblyid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE assemblyid
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.assemblyid OWNER TO postgres;

--
-- Name: assemblyid; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('assemblyid', 6, true);


--
-- Name: assembly; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE assembly (
    id integer DEFAULT nextval('assemblyid'::regclass),
    parts_id integer,
    qty double precision,
    bom boolean,
    adj boolean,
    aid integer
);


ALTER TABLE public.assembly OWNER TO postgres;

--
-- Name: audittrail; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE audittrail (
    trans_id integer,
    tablename text,
    reference text,
    formname text,
    "action" text,
    transdate timestamp without time zone DEFAULT now(),
    employee_id integer
);


ALTER TABLE public.audittrail OWNER TO postgres;

--
-- Name: bank; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE bank (
    id integer,
    name character varying(64),
    iban character varying(34),
    bic character varying(11),
    address_id integer DEFAULT nextval('addressid'::regclass),
    dcn text,
    rvc text,
    membernumber text
);


ALTER TABLE public.bank OWNER TO postgres;

--
-- Name: br; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE br (
    id integer DEFAULT nextval('id'::regclass) NOT NULL,
    batchnumber text,
    description text,
    batch text,
    transdate date DEFAULT ('now'::text)::date,
    apprdate date,
    amount double precision,
    managerid integer,
    employee_id integer
);


ALTER TABLE public.br OWNER TO postgres;

--
-- Name: build; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE build (
    id integer DEFAULT nextval(('id'::text)::regclass) NOT NULL,
    reference text,
    transdate date,
    department_id integer,
    warehouse_id integer,
    employee_id integer
);


ALTER TABLE public.build OWNER TO postgres;

--
-- Name: business; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE business (
    id integer DEFAULT nextval('id'::regclass),
    description text,
    discount real
);


ALTER TABLE public.business OWNER TO postgres;

--
-- Name: cargo; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE cargo (
    id integer NOT NULL,
    trans_id integer NOT NULL,
    package text,
    netweight double precision,
    grossweight double precision,
    volume double precision
);


ALTER TABLE public.cargo OWNER TO postgres;

--
-- Name: chart; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE chart (
    id integer DEFAULT nextval('id'::regclass),
    accno text NOT NULL,
    description text,
    charttype character(1) DEFAULT 'A'::bpchar,
    category character(1),
    link text,
    gifi_accno text,
    contra boolean DEFAULT false
);


ALTER TABLE public.chart OWNER TO postgres;

--
-- Name: contactid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contactid
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.contactid OWNER TO postgres;

--
-- Name: contactid; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contactid', 16, true);


--
-- Name: contact; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE contact (
    id integer DEFAULT nextval('contactid'::regclass) NOT NULL,
    trans_id integer NOT NULL,
    salutation character varying(32),
    firstname character varying(32),
    lastname character varying(32),
    contacttitle character varying(32),
    occupation character varying(32),
    phone character varying(20),
    fax character varying(20),
    mobile character varying(20),
    email text,
    gender character(1) DEFAULT 'M'::bpchar,
    parent_id integer,
    typeofcontact character varying(20)
);


ALTER TABLE public.contact OWNER TO postgres;

--
-- Name: curr; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE curr (
    rn integer,
    curr character(3) NOT NULL,
    "precision" smallint
);


ALTER TABLE public.curr OWNER TO postgres;

--
-- Name: customer; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE customer (
    id integer DEFAULT nextval('id'::regclass) NOT NULL,
    name character varying(64),
    contact character varying(64),
    phone character varying(20),
    fax character varying(20),
    email text,
    notes text,
    terms smallint DEFAULT 0,
    taxincluded boolean DEFAULT false,
    customernumber character varying(32),
    cc text,
    bcc text,
    business_id integer,
    taxnumber character varying(32),
    sic_code character varying(6),
    discount real,
    creditlimit double precision DEFAULT 0,
    iban character varying(34),
    bic character varying(11),
    employee_id integer,
    language_code character varying(6),
    pricegroup_id integer,
    curr character(3),
    startdate date,
    enddate date,
    arap_accno_id integer,
    payment_accno_id integer,
    discount_accno_id integer,
    cashdiscount real,
    discountterms smallint,
    threshold double precision,
    paymentmethod_id integer,
    remittancevoucher boolean,
    tipoid_id integer
);


ALTER TABLE public.customer OWNER TO postgres;

--
-- Name: customertax; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE customertax (
    customer_id integer,
    chart_id integer
);


ALTER TABLE public.customertax OWNER TO postgres;

--
-- Name: defaults; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE "defaults" (
    fldname text,
    fldvalue text
);


ALTER TABLE public."defaults" OWNER TO postgres;

--
-- Name: department; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE department (
    id integer DEFAULT nextval('id'::regclass),
    description text,
    "role" character(1) DEFAULT 'P'::bpchar
);


ALTER TABLE public.department OWNER TO postgres;

--
-- Name: dpt_trans; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dpt_trans (
    trans_id integer,
    department_id integer
);


ALTER TABLE public.dpt_trans OWNER TO postgres;

--
-- Name: employee; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE employee (
    id integer DEFAULT nextval('id'::regclass),
    "login" text,
    name character varying(64),
    address1 character varying(32),
    address2 character varying(32),
    city character varying(32),
    state character varying(32),
    zipcode character varying(10),
    country character varying(32),
    workphone character varying(20),
    workfax character varying(20),
    workmobile character varying(20),
    homephone character varying(20),
    startdate date DEFAULT ('now'::text)::date,
    enddate date,
    notes text,
    "role" character varying(20),
    sales boolean DEFAULT false,
    email text,
    ssn character varying(20),
    iban character varying(34),
    bic character varying(11),
    managerid integer,
    employeenumber character varying(32),
    dob date
);


ALTER TABLE public.employee OWNER TO postgres;

--
-- Name: exchangerate; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE exchangerate (
    curr character(3),
    transdate date,
    buy double precision,
    sell double precision
);


ALTER TABLE public.exchangerate OWNER TO postgres;

--
-- Name: fifo; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE fifo (
    trans_id integer,
    transdate date,
    parts_id integer,
    qty double precision,
    costprice double precision,
    sellprice double precision,
    warehouse_id integer,
    invoice_id integer
);


ALTER TABLE public.fifo OWNER TO postgres;

--
-- Name: gifi; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE gifi (
    accno text,
    description text
);


ALTER TABLE public.gifi OWNER TO postgres;

--
-- Name: gl; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE gl (
    id integer DEFAULT nextval('id'::regclass),
    reference text,
    description text,
    transdate date DEFAULT ('now'::text)::date,
    employee_id integer,
    notes text,
    department_id integer DEFAULT 0,
    approved boolean DEFAULT true,
    curr character(3),
    exchangerate double precision,
    ticket_id integer
);


ALTER TABLE public.gl OWNER TO postgres;

--
-- Name: inventoryid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE inventoryid
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.inventoryid OWNER TO postgres;

--
-- Name: inventoryid; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('inventoryid', 34, true);


--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE inventory (
    id integer DEFAULT nextval('inventoryid'::regclass),
    warehouse_id integer,
    parts_id integer,
    trans_id integer,
    orderitems_id integer,
    qty double precision,
    shippingdate date,
    employee_id integer,
    department_id integer,
    warehouse_id2 integer,
    serialnumber text,
    itemnotes text,
    cost double precision,
    linetype character(1) DEFAULT '0'::bpchar,
    description text
);


ALTER TABLE public.inventory OWNER TO postgres;

--
-- Name: invoiceid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE invoiceid
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoiceid OWNER TO postgres;

--
-- Name: invoiceid; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('invoiceid', 87, true);


--
-- Name: invoice; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE invoice (
    id integer DEFAULT nextval('invoiceid'::regclass),
    trans_id integer,
    parts_id integer,
    description text,
    qty double precision,
    allocated double precision,
    sellprice double precision,
    fxsellprice double precision,
    discount real,
    assemblyitem boolean DEFAULT false,
    unit character varying(5),
    project_id integer,
    deliverydate date,
    serialnumber text,
    itemnotes text,
    lineitemdetail boolean,
    transdate date,
    lastcost double precision,
    warehouse_id integer,
    linetype character(1) DEFAULT '0'::bpchar,
    ordernumber text,
    ponumber text
);


ALTER TABLE public.invoice OWNER TO postgres;

--
-- Name: invoicetax; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE invoicetax (
    trans_id integer,
    invoice_id integer,
    chart_id integer,
    taxamount double precision
);


ALTER TABLE public.invoicetax OWNER TO postgres;

--
-- Name: jcitemsid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE jcitemsid
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.jcitemsid OWNER TO postgres;

--
-- Name: jcitemsid; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('jcitemsid', 1, true);


--
-- Name: jcitems; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE jcitems (
    id integer DEFAULT nextval('jcitemsid'::regclass),
    project_id integer,
    parts_id integer,
    description text,
    qty double precision,
    allocated double precision,
    sellprice double precision,
    fxsellprice double precision,
    serialnumber text,
    checkedin timestamp with time zone,
    checkedout timestamp with time zone,
    employee_id integer,
    notes text
);


ALTER TABLE public.jcitems OWNER TO postgres;

--
-- Name: language; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE "language" (
    code character varying(6),
    description text
);


ALTER TABLE public."language" OWNER TO postgres;

--
-- Name: makemodel; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE makemodel (
    parts_id integer,
    make text,
    model text
);


ALTER TABLE public.makemodel OWNER TO postgres;

--
-- Name: oe; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE oe (
    id integer DEFAULT nextval('id'::regclass),
    ordnumber text,
    transdate date DEFAULT ('now'::text)::date,
    vendor_id integer,
    customer_id integer,
    amount double precision,
    netamount double precision,
    reqdate date,
    taxincluded boolean,
    shippingpoint text,
    notes text,
    curr character(3),
    employee_id integer,
    closed boolean DEFAULT false,
    quotation boolean DEFAULT false,
    quonumber text,
    intnotes text,
    department_id integer DEFAULT 0,
    shipvia text,
    language_code character varying(6),
    ponumber text,
    terms smallint DEFAULT 0,
    waybill text,
    warehouse_id integer,
    description text,
    aa_id integer,
    exchangerate double precision,
    ticket_id integer
);


ALTER TABLE public.oe OWNER TO postgres;

--
-- Name: orderitemsid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orderitemsid
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.orderitemsid OWNER TO postgres;

--
-- Name: orderitemsid; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orderitemsid', 1, true);


--
-- Name: orderitems; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE orderitems (
    id integer DEFAULT nextval('orderitemsid'::regclass),
    trans_id integer,
    parts_id integer,
    description text,
    qty double precision,
    sellprice double precision,
    discount real,
    unit character varying(5),
    project_id integer,
    reqdate date,
    ship double precision,
    serialnumber text,
    itemnotes text,
    lineitemdetail boolean,
    ordernumber text,
    ponumber text
);


ALTER TABLE public.orderitems OWNER TO postgres;

--
-- Name: parts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE parts (
    id integer DEFAULT nextval('id'::regclass),
    partnumber text,
    description text,
    unit character varying(5),
    listprice double precision,
    sellprice double precision,
    lastcost double precision,
    priceupdate date DEFAULT ('now'::text)::date,
    weight double precision,
    onhand double precision DEFAULT 0,
    notes text,
    makemodel boolean DEFAULT false,
    assembly boolean DEFAULT false,
    alternate boolean DEFAULT false,
    rop double precision,
    inventory_accno_id integer,
    income_accno_id integer,
    expense_accno_id integer,
    bin text,
    obsolete boolean DEFAULT false,
    bom boolean DEFAULT false,
    image text,
    drawing text,
    microfiche text,
    partsgroup_id integer,
    project_id integer,
    avgcost double precision,
    tariff_hscode text,
    countryorigin text,
    barcode text,
    toolnumber text
);


ALTER TABLE public.parts OWNER TO postgres;

--
-- Name: partscustomer; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE partscustomer (
    parts_id integer,
    customer_id integer,
    pricegroup_id integer,
    pricebreak double precision,
    sellprice double precision,
    validfrom date,
    validto date,
    curr character(3)
);


ALTER TABLE public.partscustomer OWNER TO postgres;

--
-- Name: partsgroup; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE partsgroup (
    id integer DEFAULT nextval('id'::regclass),
    partsgroup text,
    pos boolean DEFAULT true
);


ALTER TABLE public.partsgroup OWNER TO postgres;

--
-- Name: partstax; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE partstax (
    parts_id integer,
    chart_id integer
);


ALTER TABLE public.partstax OWNER TO postgres;

--
-- Name: partsvendor; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE partsvendor (
    vendor_id integer,
    parts_id integer,
    partnumber text,
    leadtime smallint,
    lastcost double precision,
    curr character(3)
);


ALTER TABLE public.partsvendor OWNER TO postgres;

--
-- Name: payment; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE payment (
    id integer NOT NULL,
    trans_id integer NOT NULL,
    exchangerate double precision DEFAULT 1,
    paymentmethod_id integer
);


ALTER TABLE public.payment OWNER TO postgres;

--
-- Name: paymentmethod; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE paymentmethod (
    id integer DEFAULT nextval('id'::regclass) NOT NULL,
    description text,
    fee double precision,
    rn integer
);


ALTER TABLE public.paymentmethod OWNER TO postgres;

--
-- Name: pricegroup; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pricegroup (
    id integer DEFAULT nextval('id'::regclass),
    pricegroup text
);


ALTER TABLE public.pricegroup OWNER TO postgres;

--
-- Name: project; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE project (
    id integer DEFAULT nextval('id'::regclass),
    projectnumber text,
    description text,
    startdate date,
    enddate date,
    parts_id integer,
    production double precision DEFAULT 0,
    completed double precision DEFAULT 0,
    customer_id integer
);


ALTER TABLE public.project OWNER TO postgres;

--
-- Name: recurring; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE recurring (
    id integer,
    reference text,
    startdate date,
    nextdate date,
    enddate date,
    repeat smallint,
    unit character varying(6),
    howmany integer,
    payment boolean DEFAULT false,
    description text
);


ALTER TABLE public.recurring OWNER TO postgres;

--
-- Name: recurringemail; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE recurringemail (
    id integer,
    formname text,
    format text,
    message text
);


ALTER TABLE public.recurringemail OWNER TO postgres;

--
-- Name: recurringprint; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE recurringprint (
    id integer,
    formname text,
    format text,
    printer text
);


ALTER TABLE public.recurringprint OWNER TO postgres;

--
-- Name: retenc; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE retenc (
    id integer NOT NULL,
    vendor_id integer,
    tipoid_id character varying(2),
    idprov character varying,
    tipodoc_id integer,
    estab character varying(3),
    ptoemi character varying(3),
    sec character varying(7),
    ordnumber text,
    transdate date,
    estabret character varying(3),
    ptoemiret character varying(3),
    secret character varying(7),
    ordnumberret text,
    transdateret date,
    tiporet_id integer,
    porcret integer,
    base0 double precision,
    based0 double precision,
    baseni double precision,
    valret numeric(6,2),
    chart_id integer
);


ALTER TABLE public.retenc OWNER TO postgres;

--
-- Name: semaphore; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE semaphore (
    id integer,
    "login" text,
    module text,
    expires character varying(10)
);


ALTER TABLE public.semaphore OWNER TO postgres;

--
-- Name: shipto; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE shipto (
    trans_id integer,
    shiptoname character varying(64),
    shiptoaddress1 character varying(32),
    shiptoaddress2 character varying(32),
    shiptocity character varying(32),
    shiptostate character varying(32),
    shiptozipcode character varying(10),
    shiptocountry character varying(32),
    shiptocontact character varying(64),
    shiptophone character varying(20),
    shiptofax character varying(20),
    shiptoemail text
);


ALTER TABLE public.shipto OWNER TO postgres;

--
-- Name: sic; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sic (
    code character varying(6),
    sictype character(1),
    description text
);


ALTER TABLE public.sic OWNER TO postgres;

--
-- Name: status; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE status (
    trans_id integer,
    formname text,
    printed boolean DEFAULT false,
    emailed boolean DEFAULT false,
    spoolfile text
);


ALTER TABLE public.status OWNER TO postgres;

--
-- Name: tax; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tax (
    chart_id integer,
    rate double precision,
    taxnumber text,
    validto date
);


ALTER TABLE public.tax OWNER TO postgres;

--
-- Name: tipodoc; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tipodoc (
    id integer NOT NULL,
    description character varying(50),
    code character varying(3)
);


ALTER TABLE public.tipodoc OWNER TO postgres;

--
-- Name: tipoid; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tipoid (
    id integer NOT NULL,
    description character varying(30)
);


ALTER TABLE public.tipoid OWNER TO postgres;

--
-- Name: tiporet; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tiporet (
    id integer NOT NULL,
    description character varying(120),
    porcret integer,
    impuesto character varying(10)
);


ALTER TABLE public.tiporet OWNER TO postgres;

--
-- Name: translation; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE translation (
    trans_id integer,
    language_code character varying(6),
    description text
);


ALTER TABLE public.translation OWNER TO postgres;

--
-- Name: trf; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE trf (
    id integer DEFAULT nextval(('id'::text)::regclass) NOT NULL,
    transdate date,
    trfnumber text,
    description text,
    notes text,
    department_id integer,
    from_warehouse_id integer,
    to_warehouse_id integer DEFAULT 0,
    employee_id integer DEFAULT 0,
    delivereddate date,
    ticket_id integer
);


ALTER TABLE public.trf OWNER TO postgres;

--
-- Name: vendor; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE vendor (
    id integer DEFAULT nextval('id'::regclass) NOT NULL,
    name character varying(64),
    contact character varying(64),
    phone character varying(20),
    fax character varying(20),
    email text,
    notes text,
    terms smallint DEFAULT 0,
    taxincluded boolean DEFAULT false,
    vendornumber character varying(32),
    cc text,
    bcc text,
    gifi_accno character varying(30),
    business_id integer,
    taxnumber character varying(32),
    sic_code character varying(6),
    discount real,
    creditlimit double precision DEFAULT 0,
    iban character varying(34),
    bic character varying(11),
    employee_id integer,
    language_code character varying(6),
    pricegroup_id integer,
    curr character(3),
    startdate date,
    enddate date,
    arap_accno_id integer,
    payment_accno_id integer,
    discount_accno_id integer,
    cashdiscount real,
    discountterms smallint,
    threshold double precision,
    paymentmethod_id integer,
    remittancevoucher boolean,
    tipoid_id integer
);


ALTER TABLE public.vendor OWNER TO postgres;

--
-- Name: vendortax; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE vendortax (
    vendor_id integer,
    chart_id integer
);


ALTER TABLE public.vendortax OWNER TO postgres;

--
-- Name: vr; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE vr (
    br_id integer,
    trans_id integer NOT NULL,
    id integer DEFAULT nextval('id'::regclass) NOT NULL,
    vouchernumber text
);


ALTER TABLE public.vr OWNER TO postgres;

--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE warehouse (
    id integer DEFAULT nextval('id'::regclass),
    description text
);


ALTER TABLE public.warehouse OWNER TO postgres;

--
-- Name: yearend; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE yearend (
    trans_id integer,
    transdate date
);


ALTER TABLE public.yearend OWNER TO postgres;

--
-- Data for Name: acc_trans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY acc_trans (trans_id, chart_id, amount, transdate, source, approved, fx_transaction, project_id, memo, id, cleared, vr_id) FROM stdin;
10143	10017	-6000	2007-07-01		t	f	\N		\N	\N	\N
10143	10034	6000	2007-07-01		t	f	\N		\N	\N	\N
10142	10017	-10000	2007-07-01	1234	t	f	\N		\N	\N	\N
10142	10034	10000	2007-07-01	1234	t	f	\N		\N	\N	\N
10151	10038	56.969999999999999	2007-07-12	\N	t	f	\N	\N	50	\N	\N
10151	10038	44.969999999999999	2007-07-12	\N	t	f	\N	\N	51	\N	\N
10151	10014	-119.78	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10151	10025	17.84	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10153	10006	-234	2007-07-12		t	f	\N		\N	\N	\N
10153	10017	234	2007-07-12		t	f	\N		\N	\N	\N
10154	10017	250	2007-07-12		t	f	\N		\N	\N	\N
10154	10068	-250	2007-07-12		t	f	\N		\N	\N	\N
10147	10038	113.94	2007-07-05	\N	t	f	\N	\N	55	\N	\N
10147	10038	44.969999999999999	2007-07-05	\N	t	f	\N	\N	56	\N	\N
10147	10014	-186.72	2007-07-05	\N	t	f	\N	\N	\N	\N	\N
10147	10025	27.809999999999999	2007-07-05	\N	t	f	\N	\N	\N	\N	\N
10148	10038	119.92	2007-07-06	\N	t	f	\N	\N	57	\N	\N
10148	10038	71.879999999999995	2007-07-06	\N	t	f	\N	\N	58	\N	\N
10148	10014	-225.37	2007-07-06	\N	t	f	\N	\N	\N	\N	\N
10148	10025	33.57	2007-07-06	\N	t	f	\N	\N	\N	\N	\N
10148	10014	225.37	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10148	10017	-225.37	2007-07-12	8712	t	f	\N		1	\N	\N
10149	10038	900	2007-07-06	\N	t	f	\N	\N	61	\N	\N
10149	10038	400	2007-07-06	\N	t	f	\N	\N	62	\N	\N
10149	10014	-1527.5	2007-07-06	\N	t	f	\N	\N	\N	\N	\N
10149	10025	227.5	2007-07-06	\N	t	f	\N	\N	\N	\N	\N
10149	10014	1000	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10149	10017	-1000	2007-07-12	8712	t	f	\N		1	\N	\N
10150	10038	89.950000000000003	2007-07-09	\N	t	f	\N	\N	63	\N	\N
10150	10038	59.960000000000001	2007-07-09	\N	t	f	\N	\N	65	\N	\N
10150	10038	56.969999999999999	2007-07-09	\N	t	f	\N	\N	64	\N	\N
10150	10014	-243.08000000000001	2007-07-09	\N	t	f	\N	\N	\N	\N	\N
10150	10025	36.200000000000003	2007-07-09	\N	t	f	\N	\N	\N	\N	\N
10152	10038	149.94	2007-07-12	\N	t	f	\N	\N	66	\N	\N
10152	10038	74.969999999999999	2007-07-12	\N	t	f	\N	\N	68	\N	\N
10152	10038	44.969999999999999	2007-07-12	\N	t	f	\N	\N	67	\N	\N
10152	10014	-317.11000000000001	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10152	10025	47.229999999999997	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10141	10012	-509.69999999999999	2007-07-01	\N	t	f	\N	\N	69	\N	\N
10141	10012	-444	2007-07-01	\N	t	f	\N	\N	70	\N	\N
10141	10012	-239.25	2007-07-01	\N	t	f	\N	\N	71	\N	\N
10141	10022	1401.72	2007-07-01	\N	t	f	\N	\N	\N	\N	\N
10141	10025	-208.77000000000001	2007-07-01	\N	t	f	\N	\N	\N	\N	\N
10144	10012	-16.989999999999998	2007-07-01	\N	t	f	\N	\N	73	\N	\N
10144	10012	-16	2007-07-01	\N	t	f	\N	\N	72	\N	\N
10144	10022	38.759999999999998	2007-07-01	\N	t	f	\N	\N	\N	\N	\N
10144	10025	-5.7699999999999996	2007-07-01	\N	t	f	\N	\N	\N	\N	\N
10145	10012	-672	2007-07-03	\N	t	f	\N	\N	74	\N	\N
10145	10012	-494.5	2007-07-03	\N	t	f	\N	\N	77	\N	\N
10145	10012	-322.82999999999998	2007-07-03	\N	t	f	\N	\N	75	\N	\N
10145	10012	-251.78999999999999	2007-07-03	\N	t	f	\N	\N	76	\N	\N
10145	10022	2045.8199999999999	2007-07-03	\N	t	f	\N	\N	\N	\N	\N
10145	10025	-304.69999999999999	2007-07-03	\N	t	f	\N	\N	\N	\N	\N
10145	10022	-2000	2007-07-13	\N	t	f	\N	\N	\N	\N	\N
10145	10017	2000	2007-07-13	6762	t	f	\N		1	\N	\N
10146	10012	-21.5	2007-07-12	\N	t	f	\N	\N	79	\N	\N
10146	10012	-11.99	2007-07-12	\N	t	f	\N	\N	78	\N	\N
10146	10022	39.350000000000001	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10146	10025	-5.8600000000000003	2007-07-12	\N	t	f	\N	\N	\N	\N	\N
10161	10038	118.18000000000001	2009-02-02	\N	t	f	\N	\N	87	\N	\N
10161	10014	-138.86000000000001	2009-02-02	\N	t	f	\N	\N	\N	\N	\N
10161	10025	20.68	2009-02-02	\N	t	f	\N	\N	\N	\N	\N
10151	10012	36	2007-07-12	COGS	t	f	\N	\N	70	\N	\N
10151	10045	-36	2007-07-12	COGS	t	f	\N	\N	70	\N	\N
10150	10012	48	2007-07-09	COGS	t	f	\N	\N	70	\N	\N
10150	10045	-48	2007-07-09	COGS	t	f	\N	\N	70	\N	\N
10148	10012	96	2007-07-06	COGS	t	f	\N	\N	70	\N	\N
10148	10045	-96	2007-07-06	COGS	t	f	\N	\N	70	\N	\N
10147	10012	36	2007-07-05	COGS	t	f	\N	\N	70	\N	\N
10147	10045	-36	2007-07-05	COGS	t	f	\N	\N	70	\N	\N
10148	10012	52.200000000000003	2007-07-06	COGS	t	f	\N	\N	71	\N	\N
10148	10045	-52.200000000000003	2007-07-06	COGS	t	f	\N	\N	71	\N	\N
10152	10012	113.94	2007-07-12	COGS	t	f	\N	\N	75	\N	\N
10152	10045	-113.94	2007-07-12	COGS	t	f	\N	\N	75	\N	\N
10150	10012	64	2007-07-09	COGS	t	f	\N	\N	74	\N	\N
10150	10045	-64	2007-07-09	COGS	t	f	\N	\N	74	\N	\N
10150	10012	16	2007-07-09	COGS	t	f	\N	\N	72	\N	\N
10150	10045	-16	2007-07-09	COGS	t	f	\N	\N	72	\N	\N
10152	10012	35.969999999999999	2007-07-12	COGS	t	f	\N	\N	76	\N	\N
10152	10045	-35.969999999999999	2007-07-12	COGS	t	f	\N	\N	76	\N	\N
10151	10012	50.969999999999999	2007-07-12	COGS	t	f	\N	\N	69	\N	\N
10151	10045	-50.969999999999999	2007-07-12	COGS	t	f	\N	\N	69	\N	\N
10150	10012	50.969999999999999	2007-07-09	COGS	t	f	\N	\N	69	\N	\N
10150	10045	-50.969999999999999	2007-07-09	COGS	t	f	\N	\N	69	\N	\N
10147	10012	101.94	2007-07-05	COGS	t	f	\N	\N	69	\N	\N
10147	10045	-101.94	2007-07-05	COGS	t	f	\N	\N	69	\N	\N
10152	10012	64.5	2007-07-12	COGS	t	f	\N	\N	77	\N	\N
10152	10045	-64.5	2007-07-12	COGS	t	f	\N	\N	77	\N	\N
10161	10160	98.480000000000004	2009-02-02	COGS	t	f	\N	\N	86	\N	\N
10161	10045	-98.480000000000004	2009-02-02	COGS	t	f	\N	\N	86	\N	\N
10157	10012	48	2009-01-01	COMP	t	f	\N	\N	74	\N	\N
10157	10045	-48	2009-01-01	COMP	t	f	\N	\N	74	\N	\N
10157	10012	23.98	2009-01-01	COMP	t	f	\N	\N	76	\N	\N
10157	10045	-23.98	2009-01-01	COMP	t	f	\N	\N	76	\N	\N
10159	10012	67.959999999999994	2009-02-02	COMP	t	f	\N	\N	69	\N	\N
10159	10045	-67.959999999999994	2009-02-02	COMP	t	f	\N	\N	69	\N	\N
10159	10012	129	2009-02-02	COMP	t	f	\N	\N	77	\N	\N
10159	10045	-129	2009-02-02	COMP	t	f	\N	\N	77	\N	\N
10159	10160	-196.96000000000001	2009-02-02	ASM	t	f	\N	\N	86	\N	\N
10159	10045	196.96000000000001	2009-02-02	ASM	t	f	\N	\N	86	\N	\N
10157	\N	-171.66	2009-01-01	ASM	t	f	\N	\N	83	\N	\N
10157	\N	171.66	2009-01-01	ASM	t	f	\N	\N	83	\N	\N
\.


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY address (id, trans_id, address1, address2, city, state, zipcode, country) FROM stdin;
2	10118			London		AA7 9BB	UK
3	10119			London			UK
4	10120			London			UK
5	10121			London		AA7 9BB	UK
8	10124			London		AA7 9BB	UK
9	10125			London		AA7 9BB	UK
10	10126			London		AA7 9BB	UK
11	10127			London		AA7 9BB	UK
12	10128			London		AA7 9BB	UK
13	10129			London		AA7 9BB	UK
14	10130			London		AA7 9BB	UK
15	10131			London		AA7 9BB	UK
16	10132			London		AA7 9BB	UK
6	10122			London		AA7 9BB	UK
17	10134						
18	10135						
\.


--
-- Data for Name: ap; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ap (id, invnumber, transdate, vendor_id, taxincluded, amount, netamount, paid, datepaid, duedate, invoice, ordnumber, curr, notes, employee_id, till, quonumber, intnotes, department_id, shipvia, language_code, ponumber, shippingpoint, terms, approved, cashdiscount, discountterms, waybill, warehouse_id, description, onhold, exchangerate, dcn, bank_id, paymentmethod_id, ticket_id, tipodoc_id) FROM stdin;
10141	AP-001	2007-07-01	10130	f	1401.72	1192.95	0	\N	2007-07-10	t		GBP		10102	\N			10136					9	t	0	0		10134		f	1		10017	0	\N	\N
10144	AP-002	2007-07-01	10131	f	38.759999999999998	32.990000000000002	0	\N	2007-07-01	t		GBP		10102	\N			10136					0	t	0	0		10134		f	1		10017	0	\N	\N
10145	AP-003	2007-07-03	10132	f	2045.8199999999999	1741.1199999999999	2000	2007-07-13	2007-07-05	t		GBP		10102	\N			10136					0	t	0	0		10134		f	1		10017	0	\N	\N
10146	AP-004	2007-07-12	10132	f	39.350000000000001	33.490000000000002	0	\N	2007-07-12	t		GBP		10102	\N			10136					0	t	0	0		10135		f	1		10017	0	\N	\N
\.


--
-- Data for Name: ar; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ar (id, invnumber, transdate, customer_id, taxincluded, amount, netamount, paid, datepaid, duedate, invoice, shippingpoint, terms, notes, curr, ordnumber, employee_id, till, quonumber, intnotes, department_id, shipvia, language_code, ponumber, approved, cashdiscount, discountterms, waybill, warehouse_id, description, onhold, exchangerate, dcn, bank_id, paymentmethod_id, ticket_id, tipodoc_id) FROM stdin;
10151	AR-005	2007-07-12	10121	f	119.78	101.94	0	\N	2007-07-12	t		0		GBP		10102	\N			10136				t	0	0		10134		f	1	\N	\N	\N	\N	\N
10147	AR-001	2007-07-05	10118	f	186.72	158.91	0	\N	2007-07-05	t		0		GBP		10102	\N			10136				t	0	0		10134		f	1		10017	0	\N	\N
10148	AR-002	2007-07-06	10128	f	225.37	191.80000000000001	225.37	2007-07-12	2007-07-06	t		0		GBP		10102	\N			10136				t	0	0		10134		f	1		10017	0	\N	\N
10149	AR-003	2007-07-06	10128	f	1527.5	1300	1000	2007-07-12	2007-07-06	t		0		GBP		10102	\N			10137				t	0	0		10134		f	1		10017	0	\N	\N
10150	AR-004	2007-07-09	10119	f	243.08000000000001	206.88	0	\N	2007-07-10	t		1		GBP		10102	\N			10136				t	0	0		10134		f	1		10017	0	\N	\N
10152	AR-006	2007-07-12	10125	f	317.11000000000001	269.88	0	\N	2007-07-12	t		0		GBP		10102	\N			10136				t	0	0		10134		f	1		10017	0	\N	\N
10161	AR-007	2009-02-02	10125	f	138.86000000000001	118.18000000000001	0	\N	2009-02-02	t		0		GBP		10102	\N			10136				t	0	0		10134		f	1		10017	0	\N	\N
\.


--
-- Data for Name: assembly; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY assembly (id, parts_id, qty, bom, adj, aid) FROM stdin;
2	10115	3	f	t	10156
3	10110	1	f	t	10156
4	10112	2	f	t	10156
5	10116	2	f	t	10158
6	10113	3	f	t	10158
\.


--
-- Data for Name: audittrail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY audittrail (trans_id, tablename, reference, formname, "action", transdate, employee_id) FROM stdin;
\.


--
-- Data for Name: bank; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY bank (id, name, iban, bic, address_id, dcn, rvc, membernumber) FROM stdin;
\.


--
-- Data for Name: br; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY br (id, batchnumber, description, batch, transdate, apprdate, amount, managerid, employee_id) FROM stdin;
\.


--
-- Data for Name: build; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY build (id, reference, transdate, department_id, warehouse_id, employee_id) FROM stdin;
10157	test1	2009-01-01	10136	10134	10102
10159	test2	2009-02-02	10136	10134	10102
\.


--
-- Data for Name: business; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY business (id, description, discount) FROM stdin;
\.


--
-- Data for Name: cargo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY cargo (id, trans_id, package, netweight, grossweight, volume) FROM stdin;
\.


--
-- Data for Name: chart; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY chart (id, accno, description, charttype, category, link, gifi_accno, contra) FROM stdin;
10001	0010	Freehold Property	A	A			f
10002	0011	Goodwill	A	A			f
10003	0012	Goodwill Amortisation	A	A			f
10004	0020	Plant and Machinery	A	A			f
10005	0021	Plant/Machinery Depreciation	A	A			t
10006	0030	Office Equipment	A	A			f
10007	0031	Office Equipment Depreciation	A	A			t
10008	0040	Furniture and Fixtures	A	A			f
10009	0041	Furniture/Fixture Depreciation	A	A			t
10010	0050	Motor Vehicles	A	A			f
10011	0051	Motor Vehicles Depreciation	A	A			t
10013	1002	Work in Progress	A	A	IC		f
10014	1100	Debtors Control Account	A	A	AR		f
10015	1102	Other Debtors	A	A	AR		f
10016	1103	Prepayments	A	A			f
10017	1200	Bank Current Account	A	A	AR_paid:AP_paid		f
10018	1210	Bank Deposit Account	A	A			f
10019	1220	Building Society Account	A	A			f
10020	1230	Petty Cash	A	A	AR_paid:AP_paid		f
10021	1240	Company Credit Card	A	L			f
10022	2100	Creditors Control Account	A	L	AP		f
10023	2102	Other Creditors	A	L	AP		f
10024	2109	Accruals	A	L			f
10025	2200	VAT (17.5%)	A	L	AR_tax:AP_tax:IC_taxpart:IC_taxservice		f
10026	2205	VAT (5%)	A	L	AR_tax:AP_tax:IC_taxpart:IC_taxservice		f
10027	2210	P.A.Y.E. & National Insurance	A	L			f
10028	2220	Net Wages	A	L			f
10029	2250	Corporation Tax	A	L			f
10030	2300	Bank Loan	A	L			f
10031	2305	Directors loan account	A	L			f
10032	2310	Hire Purchase	A	L			f
10033	2330	Mortgages	A	L			f
10034	3000	Ordinary Shares	A	Q			f
10035	3010	Preference Shares	A	Q			f
10036	3100	Share Premium Account	A	Q			f
10037	3200	Profit and Loss Account	A	Q			f
10038	4000	Sales	A	I	AR_amount:IC_sale:IC_income		f
10039	4010	Export Sales	A	I	AR_amount:IC_sale:IC_income		f
10040	4009	Discounts Allowed	A	I			f
10041	4900	Miscellaneous Income	A	I	AR_amount:IC_sale:IC_income		f
10042	4904	Rent Income	A	I	AR_amount		f
10043	4906	Interest received	A	I	AR_amount		f
10044	4920	Foreign Exchange Gain	A	I			f
10045	5000	Materials Purchased	A	E	AP_amount:IC_cogs:IC_expense		f
10046	5001	Materials Imported	A	E	AP_amount:IC_cogs:IC_expense		f
10047	5002	Opening Stock	A	E			f
10048	5003	Closing Stock	A	E			f
10049	5200	Packaging	A	E	AP_amount		f
10050	5201	Discounts Taken	A	E			f
10051	5202	Carriage	A	E	AP_amount		f
10052	5203	Import Duty	A	E	AP_amount		f
10053	5204	Transport Insurance	A	E	AP_amount		f
10054	5205	Equipment Hire	A	E			f
10055	5220	Foreign Exchange Loss	A	E			f
10056	6000	Productive Labour	A	E	AP_amount		f
10057	6001	Cost of Sales Labour	A	E	AP_amount		f
10058	6002	Sub-Contractors	A	E	AP_amount		f
10059	7000	Staff wages & salaries	A	E	AP_amount		f
10060	7002	Directors Remuneration	A	E	AP_amount		f
10061	7006	Employers N.I.	A	E	AP_amount		f
10062	7007	Employers Pensions	A	E	AP_amount		f
10063	7008	Recruitment Expenses	A	E	AP_amount		f
10064	7100	Rent	A	E	AP_amount		f
10065	7102	Water Rates	A	E	AP_amount		f
10066	7103	General Rates	A	E	AP_amount		f
10067	7104	Premises Insurance	A	E	AP_amount		f
10068	7200	Light & heat	A	E	AP_amount		f
10069	7300	Motor expenses	A	E	AP_amount		f
10070	7350	Travelling	A	E	AP_amount		f
10071	7400	Advertising	A	E	AP_amount		f
10072	7402	P.R. (Literature & Brochures)	A	E	AP_amount		f
10073	7403	U.K. Entertainment	A	E	AP_amount		f
10074	7404	Overseas Entertainment	A	E	AP_amount		f
10075	7500	Postage and Carriage	A	E	AP_amount		f
10076	7501	Office Stationery	A	E	AP_amount		f
10077	7502	Telephone	A	E	AP_amount		f
10078	7506	Web Site costs	A	E	AP_amount		f
10079	7600	Legal Fees	A	E	AP_amount		f
10080	7601	Audit and Accountancy Fees	A	E	AP_amount		f
10081	7603	Professional Fees	A	E	AP_amount		f
10082	7701	Office Machine Maintenance	A	E	AP_amount		f
10083	7710	Computer expenses	A	E	AP_amount		f
10084	7800	Repairs and Renewals	A	E	AP_amount		f
10085	7801	Cleaning	A	E	AP_amount		f
10086	7802	Laundry	A	E	AP_amount		f
10087	7900	Bank Interest Paid	A	E			f
10088	7901	Bank Charges	A	E			f
10089	7903	Loan Interest Paid	A	E			f
10090	7904	H.P. Interest	A	E			f
10091	8000	Depreciation	A	E			f
10092	8005	Goodwill Amortisation	A	E			f
10093	8100	Bad Debt Write Off	A	E			f
10094	8201	Subscriptions	A	E	AP_amount		f
10095	8202	Clothing Costs	A	E	AP_amount		f
10096	8203	Training Costs	A	E	AP_amount		f
10097	8204	Insurance	A	E	AP_amount		f
10098	8205	Refreshments	A	E	AP_amount		f
10099	8500	Dividends	A	E			f
10100	8600	Corporation Tax	A	E			f
10101	9999	Suspense Account	A	E			f
10012	1001	Raw material stock	A	A	IC		f
10160	1003	Finished goods stock	A	A	IC		f
\.


--
-- Data for Name: contact; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contact (id, trans_id, salutation, firstname, lastname, contacttitle, occupation, phone, fax, mobile, email, gender, parent_id, typeofcontact) FROM stdin;
2	10118		Charles	Kirk							M	\N	company
3	10119	Mr.	John	King							M	\N	company
4	10120		Joseph	Rollins							M	\N	company
5	10121		Louis	Adams							M	\N	company
7	10123		Larry	Riley							M	\N	company
8	10124		Michele	Carter							M	\N	company
9	10125		Michael	Keller							M	\N	company
10	10126		Michael 								M	\N	company
11	10127		Steve	Smith							M	\N	company
12	10128		Milton	Bear							M	\N	company
13	10129										M	\N	company
14	10130		Thomas	Lucas							M	\N	company
15	10131		John	King							M	\N	company
16	10132		Michael	KIng							M	\N	company
6	10122		Larry	Riley							M	\N	company
\.


--
-- Data for Name: curr; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY curr (rn, curr, "precision") FROM stdin;
1	GBP	2
\.


--
-- Data for Name: customer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY customer (id, name, contact, phone, fax, email, notes, terms, taxincluded, customernumber, cc, bcc, business_id, taxnumber, sic_code, discount, creditlimit, iban, bic, employee_id, language_code, pricegroup_id, curr, startdate, enddate, arap_accno_id, payment_accno_id, discount_accno_id, cashdiscount, discountterms, threshold, paymentmethod_id, remittancevoucher, tipoid_id) FROM stdin;
10118	Auto Exchange Express	Charles Kirk					0	f	AE001			0			0	1500			10102		0	GBP	2007-04-29	\N	10014	10017	\N	0	0	0	\N	\N	\N
10119	Car Parts Ltd	John King					0	f	CP002			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10120	Expert Repair Ltd	Joseph Rollins					0	f	ER003			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10121	Electronics Ltd.	Louis Adams					0	f	EL004			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10124	Spare Parts, Ltd.	Michele Carter					0	f	SP007			0			0	0			10102		0	GBP	2007-04-29	\N	10014	10017	\N	0	0	0	\N	\N	\N
10125	InfoMed Ltd.	Michael Keller					0	f	IL008			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10126	Medical Supplies Plc.	Michael  					0	f	MS009			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10127	Pharm Supplies	Steve Smith					0	f	PS010			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10128	Big Porridge Ltd.	Milton Bear					0	f	BP011			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10129	Automotive Ltd	 					0	f	AL012			0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10122	Computerz Ltd.	Larry Riley					0	f	CL005			0			0	500			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	0	f	\N
\.


--
-- Data for Name: customertax; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY customertax (customer_id, chart_id) FROM stdin;
10118	10025
10119	10025
10120	10025
10121	10025
10124	10025
10125	10025
10126	10025
10127	10025
10128	10025
10129	10025
10122	10025
\.


--
-- Data for Name: defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "defaults" (fldname, fldvalue) FROM stdin;
inventory_accno_id	10012
income_accno_id	10038
expense_accno_id	10045
fxgain_accno_id	10044
fxloss_accno_id	10055
batchnumber	BATCH-000
vouchernumber	V-000
sonumber	SO-000
ponumber	PO-000
sqnumber	SO-000
rfqnumber	RFQ-000
partnumber	<%description 1%>010
customernumber	<%name 1 1%>012
projectnumber	
weightunit	kg
employeenumber	E-001
vendornumber	<%name 1 1%>003
vinumber	AP-004
glnumber	GL-004
precision	2
version	2.8.9
sinumber	AR-007
\.


--
-- Data for Name: department; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY department (id, description, "role") FROM stdin;
10136	HARDWARE	P
10137	SERVICES	P
\.


--
-- Data for Name: dpt_trans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dpt_trans (trans_id, department_id) FROM stdin;
10142	10136
10151	10136
10147	10136
10148	10136
10149	10137
10150	10136
10152	10136
10141	10136
10144	10136
10145	10136
10146	10136
10161	10136
\.


--
-- Data for Name: employee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY employee (id, "login", name, address1, address2, city, state, zipcode, country, workphone, workfax, workmobile, homephone, startdate, enddate, notes, "role", sales, email, ssn, iban, bic, managerid, employeenumber, dob) FROM stdin;
10133	ukdemo	Armaghan Saqib	\N	\N	\N	\N	\N	\N			\N	\N	2007-06-01	\N	\N	admin	t	mavsol@gmail.com	\N	\N	\N	\N	\N	\N
10102	armaghan	Armaghan Saqib							5762601	5764674			2007-04-28	\N		user	t	mavsol@gmail.com				0	E-001	\N
\.


--
-- Data for Name: exchangerate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY exchangerate (curr, transdate, buy, sell) FROM stdin;
\.


--
-- Data for Name: fifo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY fifo (trans_id, transdate, parts_id, qty, costprice, sellprice, warehouse_id, invoice_id) FROM stdin;
10148	2007-07-06	10109	12	4.3499999999999996	5.9900000000000002	0	71
10152	2007-07-12	10111	6	18.989999999999998	24.989999999999998	0	75
10152	2007-07-12	10112	3	11.99	14.99	0	76
10157	2009-01-01	10112	2	11.99	0	0	76
10152	2007-07-12	10113	3	21.5	24.989999999999998	0	77
10159	2009-02-02	10113	6	21.5	0	0	77
10150	2007-07-09	10115	1	16	17.989999999999998	0	72
10150	2007-07-09	10115	4	16	17.989999999999998	0	74
10157	2009-01-01	10115	3	16	0	0	74
10147	2007-07-05	10116	6	16.989999999999998	18.989999999999998	0	69
10150	2007-07-09	10116	3	16.989999999999998	18.989999999999998	0	69
10151	2007-07-12	10116	3	16.989999999999998	18.989999999999998	0	69
10159	2009-02-02	10116	4	16.989999999999998	0	0	69
10147	2007-07-05	10117	3	12	14.99	0	70
10148	2007-07-06	10117	8	12	14.99	0	70
10150	2007-07-09	10117	4	12	14.99	0	70
10151	2007-07-12	10117	3	12	14.99	0	70
10161	2009-02-02	10158	1	98.480000000000004	118.18000000000001	0	86
\.


--
-- Data for Name: gifi; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY gifi (accno, description) FROM stdin;
\.


--
-- Data for Name: gl; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY gl (id, reference, description, transdate, employee_id, notes, department_id, approved, curr, exchangerate, ticket_id) FROM stdin;
10143	GL-002	Initial investment (ordinary shares)	2007-07-01	10133		0	t	GBP	1	\N
10142	GL-001	Initial investment	2007-07-01	10133		10136	t	GBP	1	\N
10153	GL-003	Office equipment purchased	2007-07-12	10133		0	t	GBP	1	\N
10154	GL-004	Paid bill for light and heating system	2007-07-12	10133		0	t	GBP	1	\N
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY inventory (id, warehouse_id, parts_id, trans_id, orderitems_id, qty, shippingdate, employee_id, department_id, warehouse_id2, serialnumber, itemnotes, cost, linetype, description) FROM stdin;
2	10134	10116	10147	1	-6	2007-07-05	10102	10136	\N			\N	0	\N
3	10134	10117	10147	1	-3	2007-07-05	10102	10136	\N			\N	0	\N
4	10134	10117	10148	1	-8	2007-07-06	10102	10136	\N			\N	0	\N
5	10134	10109	10148	1	-12	2007-07-06	10102	10136	\N			\N	0	\N
8	10134	10139	10149	1	-600	2007-07-06	10102	10137	\N			\N	0	\N
9	10134	10140	10149	1	-200	2007-07-06	10102	10137	\N			\N	0	\N
10	10134	10115	10150	1	-5	2007-07-09	10102	10136	\N			\N	0	\N
11	10134	10116	10150	1	-3	2007-07-09	10102	10136	\N			\N	0	\N
12	10134	10117	10150	1	-4	2007-07-09	10102	10136	\N			\N	0	\N
13	10134	10111	10152	1	-6	2007-07-12	10102	10136	\N			\N	0	\N
14	10134	10112	10152	1	-3	2007-07-12	10102	10136	\N			\N	0	\N
15	10134	10113	10152	1	-3	2007-07-12	10102	10136	\N			\N	0	\N
16	10134	10116	10141	1	30	2007-07-01	10102	10136	\N			\N	0	\N
17	10134	10117	10141	1	37	2007-07-01	10102	10136	\N			\N	0	\N
18	10134	10109	10141	1	55	2007-07-01	10102	10136	\N			\N	0	\N
19	10134	10115	10144	1	1	2007-07-01	10102	10136	\N			\N	0	\N
20	10134	10116	10144	1	1	2007-07-01	10102	10136	\N			\N	0	\N
21	10134	10115	10145	1	42	2007-07-03	10102	10136	\N			\N	0	\N
22	10134	10111	10145	1	17	2007-07-03	10102	10136	\N			\N	0	\N
23	10134	10112	10145	1	21	2007-07-03	10102	10136	\N			\N	0	\N
24	10134	10113	10145	1	23	2007-07-03	10102	10136	\N			\N	0	\N
25	10135	10112	10146	1	1	2007-07-12	10102	10136	\N			\N	0	\N
26	10135	10113	10146	1	1	2007-07-12	10102	10136	\N			\N	0	\N
27	10134	10110	10157	\N	-2	2009-01-01	10102	10136	\N	\N	\N	\N	4	\N
28	10134	10115	10157	\N	-6	2009-01-01	10102	10136	\N	\N	\N	\N	4	\N
29	10134	10112	10157	\N	-4	2009-01-01	10102	10136	\N	\N	\N	\N	4	\N
30	10134	10156	10157	\N	2	2009-01-01	10102	10136	\N	\N	\N	\N	5	\N
31	10134	10116	10159	\N	-4	2009-02-02	10102	10136	\N	\N	\N	\N	4	\N
32	10134	10113	10159	\N	-6	2009-02-02	10102	10136	\N	\N	\N	\N	4	\N
33	10134	10158	10159	\N	2	2009-02-02	10102	10136	\N	\N	\N	\N	5	\N
34	10134	10158	10161	1	-1	2009-02-02	10102	10136	\N			\N	0	Professional Kit 2
\.


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY invoice (id, trans_id, parts_id, description, qty, allocated, sellprice, fxsellprice, discount, assemblyitem, unit, project_id, deliverydate, serialnumber, itemnotes, lineitemdetail, transdate, lastcost, warehouse_id, linetype, ordernumber, ponumber) FROM stdin;
83	10157	10156	Professional Kit	-2	0	85.829999999999998	85.829999999999998	\N	t		\N	\N	\N	\N	\N	2009-01-01	85.829999999999998	10134	5	\N	\N
73	10144	10116	Digger Hand Trencher	-1	0	16.989999999999998	16.989999999999998	0	f	NOS	\N	\N			f	2007-07-01	16.989999999999998	10134	0	\N	\N
78	10146	10112	Modeling Hammer	-1	0	11.99	11.99	0	f	NOS	\N	\N			f	2007-07-12	11.99	10135	0	\N	\N
79	10146	10113	Rubber Mallet	-1	0	21.5	21.5	0	f	NOS	\N	\N			f	2007-07-12	21.5	10135	0	\N	\N
80	10157	10110	Framing Hammer	1	0	0	0	\N	f	NOS	\N	\N	\N	\N	\N	2009-01-01	0	10134	4	\N	\N
61	10149	10139	Cleaning	600	0	1.5	1.5	0	f	SQFT	\N	\N			f	2007-07-06	0	10134	0	\N	\N
62	10149	10140	Wall Paint	200	0	2	2	0	f	SQFT	\N	\N			f	2007-07-06	0	10134	0	\N	\N
71	10141	10109	Hand Brush	-55	12	4.3499999999999996	4.3499999999999996	0	f	NOS	\N	\N			f	2007-07-01	4.3499999999999996	10134	0	\N	\N
58	10148	10109	Hand Brush	12	-12	5.9900000000000002	5.9900000000000002	0	f	NOS	\N	\N			f	2007-07-06	4.3499999999999996	10134	0	\N	\N
75	10145	10111	Mini-Sledge	-17	6	18.989999999999998	18.989999999999998	0	f	NOS	\N	\N			f	2007-07-03	18.989999999999998	10134	0	\N	\N
66	10152	10111	Mini-Sledge	6	-6	24.989999999999998	24.989999999999998	0	f	NOS	\N	\N			f	2007-07-12	18.989999999999998	10134	0	\N	\N
67	10152	10112	Modeling Hammer	3	-3	14.99	14.99	0	f	NOS	\N	\N			f	2007-07-12	11.99	10134	0	\N	\N
76	10145	10112	Modeling Hammer	-21	5	11.99	11.99	0	f	NOS	\N	\N			f	2007-07-03	11.99	10134	0	\N	\N
82	10157	10112	Modeling Hammer	2	-2	0	0	\N	f	NOS	\N	\N	\N	\N	\N	2009-01-01	11.99	10134	4	\N	\N
68	10152	10113	Rubber Mallet	3	-3	24.989999999999998	24.989999999999998	0	f	NOS	\N	\N			f	2007-07-12	21.5	10134	0	\N	\N
77	10145	10113	Rubber Mallet	-23	9	21.5	21.5	0	f	NOS	\N	\N			f	2007-07-03	21.5	10134	0	\N	\N
85	10159	10113	Rubber Mallet	6	-6	0	0	\N	f	NOS	\N	\N	\N	\N	\N	2009-02-02	21.5	10134	4	\N	\N
72	10144	10115	Deluxe Hand Saw	-1	1	16	16	0	f	NOS	\N	\N			f	2007-07-01	16	10134	0	\N	\N
63	10150	10115	Deluxe Hand Saw	5	-5	17.989999999999998	17.989999999999998	0	f	NOS	\N	\N			f	2007-07-09	16	10134	0	\N	\N
74	10145	10115	Deluxe Hand Saw	-42	7	16	16	0	f	NOS	\N	\N			f	2007-07-03	16	10134	0	\N	\N
81	10157	10115	Deluxe Hand Saw	3	-3	0	0	\N	f	NOS	\N	\N	\N	\N	\N	2009-01-01	16	10134	4	\N	\N
55	10147	10116	Digger Hand Trencher	6	-6	18.989999999999998	18.989999999999998	0	f	NOS	\N	\N			f	2007-07-05	16.989999999999998	10134	0	\N	\N
64	10150	10116	Digger Hand Trencher	3	-3	18.989999999999998	18.989999999999998	0	f	NOS	\N	\N			f	2007-07-09	16.989999999999998	10134	0	\N	\N
50	10151	10116	Digger Hand Trencher	3	-3	18.989999999999998	18.989999999999998	0	f	NOS	\N	\N			f	2007-07-12	16.989999999999998	10134	0	\N	\N
69	10141	10116	Digger Hand Trencher	-30	16	16.989999999999998	16.989999999999998	0	f	NOS	\N	\N			f	2007-07-01	16.989999999999998	10134	0	\N	\N
84	10159	10116	Digger Hand Trencher	4	-4	0	0	\N	f	NOS	\N	\N	\N	\N	\N	2009-02-02	16.989999999999998	10134	4	\N	\N
56	10147	10117	The Claw Hand Rake	3	-3	14.99	14.99	0	f	NOS	\N	\N			f	2007-07-05	12	10134	0	\N	\N
57	10148	10117	The Claw Hand Rake	8	-8	14.99	14.99	0	f	NOS	\N	\N			f	2007-07-06	12	10134	0	\N	\N
65	10150	10117	The Claw Hand Rake	4	-4	14.99	14.99	0	f	NOS	\N	\N			f	2007-07-09	12	10134	0	\N	\N
70	10141	10117	The Claw Hand Rake	-37	18	12	12	0	f	NOS	\N	\N			f	2007-07-01	12	10134	0	\N	\N
51	10151	10117	The Claw Hand Rake	3	-3	14.99	14.99	0	f	NOS	\N	\N			f	2007-07-12	12	10134	0	\N	\N
86	10159	10158	Professional Kit 2	-2	1	98.480000000000004	98.480000000000004	\N	t		\N	\N	\N	\N	\N	2009-02-02	98.480000000000004	10134	5	\N	\N
87	10161	10158	Professional Kit 2	1	-1	118.18000000000001	118.18000000000001	0	f		\N	\N			f	2009-02-02	98.480000000000004	10134	0		
\.


--
-- Data for Name: invoicetax; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY invoicetax (trans_id, invoice_id, chart_id, taxamount) FROM stdin;
10147	55	10025	19.939499999999999
10147	56	10025	7.8697499999999998
10148	57	10025	20.986000000000001
10148	58	10025	12.579000000000001
10149	61	10025	157.5
10149	62	10025	70
10150	63	10025	15.741250000000001
10150	64	10025	9.9697499999999994
10150	65	10025	10.493
10152	66	10025	26.2395
10152	67	10025	7.8697499999999998
10152	68	10025	13.11975
10141	69	10025	89.197500000000005
10141	70	10025	77.700000000000003
10141	71	10025	41.868749999999999
10144	72	10025	2.7999999999999998
10144	73	10025	2.9732500000000002
10145	74	10025	117.59999999999999
10145	75	10025	56.495249999999999
10145	76	10025	44.063249999999996
10145	77	10025	86.537499999999994
10146	78	10025	2.0982500000000002
10146	79	10025	3.7625000000000002
10161	87	10025	20.6815
\.


--
-- Data for Name: jcitems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY jcitems (id, project_id, parts_id, description, qty, allocated, sellprice, fxsellprice, serialnumber, checkedin, checkedout, employee_id, notes) FROM stdin;
\.


--
-- Data for Name: language; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "language" (code, description) FROM stdin;
\.


--
-- Data for Name: makemodel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY makemodel (parts_id, make, model) FROM stdin;
\.


--
-- Data for Name: oe; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY oe (id, ordnumber, transdate, vendor_id, customer_id, amount, netamount, reqdate, taxincluded, shippingpoint, notes, curr, employee_id, closed, quotation, quonumber, intnotes, department_id, shipvia, language_code, ponumber, terms, waybill, warehouse_id, description, aa_id, exchangerate, ticket_id) FROM stdin;
\.


--
-- Data for Name: orderitems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orderitems (id, trans_id, parts_id, description, qty, sellprice, discount, unit, project_id, reqdate, ship, serialnumber, itemnotes, lineitemdetail, ordernumber, ponumber) FROM stdin;
\.


--
-- Data for Name: parts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY parts (id, partnumber, description, unit, listprice, sellprice, lastcost, priceupdate, weight, onhand, notes, makemodel, assembly, alternate, rop, inventory_accno_id, income_accno_id, expense_accno_id, bin, obsolete, bom, image, drawing, microfiche, partsgroup_id, project_id, avgcost, tariff_hscode, countryorigin, barcode, toolnumber) FROM stdin;
10108	B001	Brush Set	NOS	9.9900000000000002	9.9900000000000002	7	2007-04-29	0	0		f	f	f	0	10012	10038	10045		f	f				10103	\N	\N				
10114	T007	The Blade Hand Planer	NOS	19.989999999999998	19.989999999999998	16.25	2007-04-29	0	0		f	f	f	0	10012	10038	10045		f	f				10105	\N	\N				
10139	CLN	Cleaning	SQFT	0	1.5	1	2007-07-12	0	0		f	f	f	0	\N	10038	10045		f	f				10138	\N	\N				
10140	PAINT	Wall Paint	SQFT	0	2	1	2007-07-12	0	0		f	f	f	0	\N	10038	10045		f	f				10138	\N	\N				
10117	T010	The Claw Hand Rake	NOS	14.99	14.99	12	2007-04-29	0	19		f	f	f	0	10012	10038	10045		f	f				10107	\N	12				
10109	H002	Hand Brush	NOS	5.9900000000000002	5.9900000000000002	4.3499999999999996	2007-04-29	0	43		f	f	f	0	10012	10038	10045		f	f				10103	\N	4.3499999999999996				
10111	M004	Mini-Sledge	NOS	24.989999999999998	24.989999999999998	18.989999999999998	2007-04-29	0	11		f	f	f	0	10012	10038	10045		f	f				10104	\N	18.989999999999998				
10110	F003	Framing Hammer	NOS	19.989999999999998	19.989999999999998	13.85	2007-04-29	0	-2		f	f	f	0	10012	10038	10045		f	f				10104	\N	\N				
10115	D008	Deluxe Hand Saw	NOS	17.989999999999998	17.989999999999998	16	2007-04-29	0	32		f	f	f	0	10012	10038	10045		f	f				10106	\N	16				
10112	M005	Modeling Hammer	NOS	14.99	14.99	11.99	2007-04-29	0	15		f	f	f	0	10012	10038	10045		f	f				10104	\N	11.99				
10156	K001	Professional Kit		0	103.94	85.829999999999998	2008-01-01	0	2		f	t	f	0	\N	10038	\N		f	f				10155	\N	\N				
10116	D009	Digger Hand Trencher	NOS	18.989999999999998	18.989999999999998	16.989999999999998	2007-04-29	0	15		f	f	f	0	10012	10038	10045		f	f				10107	\N	16.989999999999998				
10113	R006	Rubber Mallet	NOS	24.989999999999998	24.989999999999998	21.5	2007-04-29	0	15		f	f	f	0	10012	10038	10045		f	f				10104	\N	21.5				
10158	K002	Professional Kit 2		0	118.18000000000001	98.480000000000004	2009-02-02	0	1		f	t	f	0	10160	10038	10045		f	f				10155	\N	\N				
\.


--
-- Data for Name: partscustomer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY partscustomer (parts_id, customer_id, pricegroup_id, pricebreak, sellprice, validfrom, validto, curr) FROM stdin;
\.


--
-- Data for Name: partsgroup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY partsgroup (id, partsgroup, pos) FROM stdin;
10138	Services	f
10103	Brushes	t
10104	Hammers	t
10105	Hand Planes	t
10106	Hand Saws	t
10107	Picks & Hatchets	t
10155	Kits	f
\.


--
-- Data for Name: partstax; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY partstax (parts_id, chart_id) FROM stdin;
10108	10025
10109	10025
10113	10025
10110	10025
10111	10025
10112	10025
10114	10025
10115	10025
10116	10025
10117	10025
10139	10025
10140	10025
10140	10026
10156	10025
10156	10026
10158	10025
10158	10026
\.


--
-- Data for Name: partsvendor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY partsvendor (vendor_id, parts_id, partnumber, leadtime, lastcost, curr) FROM stdin;
\.


--
-- Data for Name: payment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY payment (id, trans_id, exchangerate, paymentmethod_id) FROM stdin;
1	10148	1	0
1	10149	1	0
1	10145	1	0
\.


--
-- Data for Name: paymentmethod; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY paymentmethod (id, description, fee, rn) FROM stdin;
\.


--
-- Data for Name: pricegroup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pricegroup (id, pricegroup) FROM stdin;
\.


--
-- Data for Name: project; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY project (id, projectnumber, description, startdate, enddate, parts_id, production, completed, customer_id) FROM stdin;
\.


--
-- Data for Name: recurring; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY recurring (id, reference, startdate, nextdate, enddate, repeat, unit, howmany, payment, description) FROM stdin;
\.


--
-- Data for Name: recurringemail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY recurringemail (id, formname, format, message) FROM stdin;
\.


--
-- Data for Name: recurringprint; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY recurringprint (id, formname, format, printer) FROM stdin;
\.


--
-- Data for Name: retenc; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY retenc (id, vendor_id, tipoid_id, idprov, tipodoc_id, estab, ptoemi, sec, ordnumber, transdate, estabret, ptoemiret, secret, ordnumberret, transdateret, tiporet_id, porcret, base0, based0, baseni, valret, chart_id) FROM stdin;
\.


--
-- Data for Name: semaphore; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY semaphore (id, "login", module, expires) FROM stdin;
\.


--
-- Data for Name: shipto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY shipto (trans_id, shiptoname, shiptoaddress1, shiptoaddress2, shiptocity, shiptostate, shiptozipcode, shiptocountry, shiptocontact, shiptophone, shiptofax, shiptoemail) FROM stdin;
\.


--
-- Data for Name: sic; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sic (code, sictype, description) FROM stdin;
\.


--
-- Data for Name: status; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY status (trans_id, formname, printed, emailed, spoolfile) FROM stdin;
\.


--
-- Data for Name: tax; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tax (chart_id, rate, taxnumber, validto) FROM stdin;
10025	0.17499999999999999	\N	\N
10026	0.050000000000000003	\N	\N
\.


--
-- Data for Name: tipodoc; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tipodoc (id, description, code) FROM stdin;
1	Factura	FAC
2	Nota de Venta	NVT
3	Liquidacion de Compra	LIQ
4	Nota de Debito	NDB
5	Nota de Credito	NCR
11	Pasajes emitidos por empresas de aviacion	PAS
12	Documentos Emitidos Por IF	DIF
20	Documentos de Instituciones Del Estado	DIE
41	Comprobante De Venta Emitido Por Reembolso	CVR
47	N/C Por Reembolso Emitida Por Intermediario	NCI
48	N/D Por Reembolso Emitida Por Intermediario	NDI
\.


--
-- Data for Name: tipoid; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tipoid (id, description) FROM stdin;
1	Registro Unico Contribuyente
2	Cedula de Identidad
3	Pasaporte
\.


--
-- Data for Name: tiporet; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tiporet (id, description, porcret, impuesto) FROM stdin;
303	Honorarios, comisiones y dietas	8	Renta
304	Remuneracion a otros trabajadores	1	Renta
305	Honorarios a extranjeros S. ocacionales	25	Renta
306	Por compras locales materia prima	1	Renta
307	Por compras locales bienes	1	Renta
308	Por compras locales de materia prima sin retencion	0	Renta
309	Por suministros y materiales	1	Renta
310	Por repuestos y herramientas	1	Renta
311	Por lubricantes	1	Renta
312	Por activos fijos	1	Renta
313	Servicio Transporte	1	Renta
314	Por regalias, derechos, marcas, patentes- PN (8%)	8	Renta
314	Por regalias, derechos, marcas, patentes- PN (2%)	2	Renta
316	Por pagos realizados a notarios y registradores	8	Renta
317	Por comisiones pagadas a sociedades	2	Renta
318	Por promocion y publicidad	2	Renta
319	Por arrendamiento mercantil local	2	Renta
320	Por arrendamiento de personas naturales	8	Renta
321	Por arrendamiento a sociedades	8	Renta
322	Por seguros y reaseguros	2	Renta
323	Por rendimientos financieros (no aplica para ifis)	2	Renta
325	Por loterias, rifas, apuestas y similares	15	Renta
329	Por otros servicios	2	Renta
331	Por agua y telecomunicaciones	2	Renta
331	Por pago de energia electrica	1	Renta
332	Otras compras no sujetas a retencion	0	Renta
333	Convenio de Debito o Recaudacion	0	Renta
334	Pago con Tarjeta de Credito	0	Renta
336	Reembolso Gastos - Compra del Intermediario	0	Renta
337	Reembolso Gastos - Quien Asume el Gasto	0	Renta
701	Iva Servicios Profesionales	100	Iva
702	Iva Arriendo P. Natural	100	Iva
708	Iva Otros Servicios	70	Iva
711	Iva Compra Bienes	30	Iva
\.


--
-- Data for Name: translation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY translation (trans_id, language_code, description) FROM stdin;
\.


--
-- Data for Name: trf; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY trf (id, transdate, trfnumber, description, notes, department_id, from_warehouse_id, to_warehouse_id, employee_id, delivereddate, ticket_id) FROM stdin;
\.


--
-- Data for Name: vendor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vendor (id, name, contact, phone, fax, email, notes, terms, taxincluded, vendornumber, cc, bcc, gifi_accno, business_id, taxnumber, sic_code, discount, creditlimit, iban, bic, employee_id, language_code, pricegroup_id, curr, startdate, enddate, arap_accno_id, payment_accno_id, discount_accno_id, cashdiscount, discountterms, threshold, paymentmethod_id, remittancevoucher, tipoid_id) FROM stdin;
10130	Construct Buildings Plc	Thomas Lucas					0	f	CB001				0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10131	Engineering Supplies Plc	John King					0	f	ES002				0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
10132	Skybird Agro Industries	Michael KIng					0	f	SA003				0			0	0			10102		0	GBP	2007-04-29	\N	\N	\N	\N	0	0	0	\N	\N	\N
\.


--
-- Data for Name: vendortax; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vendortax (vendor_id, chart_id) FROM stdin;
10130	10025
10131	10025
10132	10025
\.


--
-- Data for Name: vr; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vr (br_id, trans_id, id, vouchernumber) FROM stdin;
\.


--
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY warehouse (id, description) FROM stdin;
10134	W1
10135	W2
\.


--
-- Data for Name: yearend; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY yearend (trans_id, transdate) FROM stdin;
\.


--
-- Name: address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_pkey PRIMARY KEY (id);


--
-- Name: br_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY br
    ADD CONSTRAINT br_pkey PRIMARY KEY (id);


--
-- Name: build_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY build
    ADD CONSTRAINT build_pkey PRIMARY KEY (id);


--
-- Name: contact_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (id);


--
-- Name: curr_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY curr
    ADD CONSTRAINT curr_pkey PRIMARY KEY (curr);


--
-- Name: customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (id);


--
-- Name: paymentmethod_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY paymentmethod
    ADD CONSTRAINT paymentmethod_pkey PRIMARY KEY (id);


--
-- Name: trf_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY trf
    ADD CONSTRAINT trf_pkey PRIMARY KEY (id);


--
-- Name: vendor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY vendor
    ADD CONSTRAINT vendor_pkey PRIMARY KEY (id);


--
-- Name: acc_trans_chart_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX acc_trans_chart_id_key ON acc_trans USING btree (chart_id);


--
-- Name: acc_trans_source_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX acc_trans_source_key ON acc_trans USING btree (lower(source));


--
-- Name: acc_trans_trans_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX acc_trans_trans_id_key ON acc_trans USING btree (trans_id);


--
-- Name: acc_trans_transdate_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX acc_trans_transdate_key ON acc_trans USING btree (transdate);


--
-- Name: ap_employee_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ap_employee_id_key ON ap USING btree (employee_id);


--
-- Name: ap_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ap_id_key ON ap USING btree (id);


--
-- Name: ap_invnumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ap_invnumber_key ON ap USING btree (invnumber);


--
-- Name: ap_ordnumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ap_ordnumber_key ON ap USING btree (ordnumber);


--
-- Name: ap_quonumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ap_quonumber_key ON ap USING btree (quonumber);


--
-- Name: ap_transdate_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ap_transdate_key ON ap USING btree (transdate);


--
-- Name: ap_vendor_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ap_vendor_id_key ON ap USING btree (vendor_id);


--
-- Name: ar_customer_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ar_customer_id_key ON ar USING btree (customer_id);


--
-- Name: ar_employee_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ar_employee_id_key ON ar USING btree (employee_id);


--
-- Name: ar_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ar_id_key ON ar USING btree (id);


--
-- Name: ar_invnumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ar_invnumber_key ON ar USING btree (invnumber);


--
-- Name: ar_ordnumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ar_ordnumber_key ON ar USING btree (ordnumber);


--
-- Name: ar_quonumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ar_quonumber_key ON ar USING btree (quonumber);


--
-- Name: ar_transdate_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ar_transdate_key ON ar USING btree (transdate);


--
-- Name: assembly_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX assembly_id_key ON assembly USING btree (id);


--
-- Name: audittrail_trans_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX audittrail_trans_id_key ON audittrail USING btree (trans_id);


--
-- Name: cargo_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cargo_id_key ON cargo USING btree (id, trans_id);


--
-- Name: chart_accno_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX chart_accno_key ON chart USING btree (accno);


--
-- Name: chart_category_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX chart_category_key ON chart USING btree (category);


--
-- Name: chart_gifi_accno_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX chart_gifi_accno_key ON chart USING btree (gifi_accno);


--
-- Name: chart_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX chart_id_key ON chart USING btree (id);


--
-- Name: chart_link_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX chart_link_key ON chart USING btree (link);


--
-- Name: customer_contact_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX customer_contact_key ON customer USING btree (lower((contact)::text));


--
-- Name: customer_customer_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX customer_customer_id_key ON customertax USING btree (customer_id);


--
-- Name: customer_customernumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX customer_customernumber_key ON customer USING btree (customernumber);


--
-- Name: customer_name_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX customer_name_key ON customer USING btree (lower((name)::text));


--
-- Name: department_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX department_id_key ON department USING btree (id);


--
-- Name: employee_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX employee_id_key ON employee USING btree (id);


--
-- Name: employee_login_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX employee_login_key ON employee USING btree ("login");


--
-- Name: employee_name_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX employee_name_key ON employee USING btree (lower((name)::text));


--
-- Name: exchangerate_ct_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX exchangerate_ct_key ON exchangerate USING btree (curr, transdate);


--
-- Name: fifo_parts_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fifo_parts_id ON fifo USING btree (parts_id);


--
-- Name: gifi_accno_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX gifi_accno_key ON gifi USING btree (accno);


--
-- Name: gl_description_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gl_description_key ON gl USING btree (lower(description));


--
-- Name: gl_employee_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gl_employee_id_key ON gl USING btree (employee_id);


--
-- Name: gl_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gl_id_key ON gl USING btree (id);


--
-- Name: gl_reference_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gl_reference_key ON gl USING btree (reference);


--
-- Name: gl_transdate_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gl_transdate_key ON gl USING btree (transdate);


--
-- Name: inventory_parts_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX inventory_parts_id_key ON inventory USING btree (parts_id);


--
-- Name: invoice_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX invoice_id_key ON invoice USING btree (id);


--
-- Name: invoice_parts_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX invoice_parts_id ON invoice USING btree (parts_id);


--
-- Name: invoice_trans_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX invoice_trans_id_key ON invoice USING btree (trans_id);


--
-- Name: jcitems_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX jcitems_id_key ON jcitems USING btree (id);


--
-- Name: language_code_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX language_code_key ON "language" USING btree (code);


--
-- Name: makemodel_make_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX makemodel_make_key ON makemodel USING btree (lower(make));


--
-- Name: makemodel_model_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX makemodel_model_key ON makemodel USING btree (lower(model));


--
-- Name: makemodel_parts_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX makemodel_parts_id_key ON makemodel USING btree (parts_id);


--
-- Name: oe_employee_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX oe_employee_id_key ON oe USING btree (employee_id);


--
-- Name: oe_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX oe_id_key ON oe USING btree (id);


--
-- Name: oe_ordnumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX oe_ordnumber_key ON oe USING btree (ordnumber);


--
-- Name: oe_transdate_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX oe_transdate_key ON oe USING btree (transdate);


--
-- Name: orderitems_trans_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orderitems_trans_id_key ON orderitems USING btree (trans_id);


--
-- Name: parts_description_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX parts_description_key ON parts USING btree (lower(description));


--
-- Name: parts_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX parts_id_key ON parts USING btree (id);


--
-- Name: parts_partnumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX parts_partnumber_key ON parts USING btree (lower(partnumber));


--
-- Name: partscustomer_customer_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX partscustomer_customer_id_key ON partscustomer USING btree (customer_id);


--
-- Name: partscustomer_parts_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX partscustomer_parts_id_key ON partscustomer USING btree (parts_id);


--
-- Name: partsgroup_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX partsgroup_id_key ON partsgroup USING btree (id);


--
-- Name: partsgroup_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX partsgroup_key ON partsgroup USING btree (partsgroup);


--
-- Name: partstax_parts_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX partstax_parts_id_key ON partstax USING btree (parts_id);


--
-- Name: partsvendor_parts_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX partsvendor_parts_id_key ON partsvendor USING btree (parts_id);


--
-- Name: partsvendor_vendor_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX partsvendor_vendor_id_key ON partsvendor USING btree (vendor_id);


--
-- Name: pricegroup_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pricegroup_id_key ON pricegroup USING btree (id);


--
-- Name: pricegroup_pricegroup_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pricegroup_pricegroup_key ON pricegroup USING btree (pricegroup);


--
-- Name: project_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX project_id_key ON project USING btree (id);


--
-- Name: projectnumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX projectnumber_key ON project USING btree (projectnumber);


--
-- Name: shipto_trans_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX shipto_trans_id_key ON shipto USING btree (trans_id);


--
-- Name: status_trans_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX status_trans_id_key ON status USING btree (trans_id);


--
-- Name: translation_trans_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX translation_trans_id_key ON translation USING btree (trans_id);


--
-- Name: vendor_contact_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX vendor_contact_key ON vendor USING btree (lower((contact)::text));


--
-- Name: vendor_name_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX vendor_name_key ON vendor USING btree (lower((name)::text));


--
-- Name: vendor_vendornumber_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX vendor_vendornumber_key ON vendor USING btree (vendornumber);


--
-- Name: vendortax_vendor_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX vendortax_vendor_id_key ON vendortax USING btree (vendor_id);


--
-- Name: vr_br_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vr
    ADD CONSTRAINT vr_br_id_fkey FOREIGN KEY (br_id) REFERENCES br(id) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

-- Inventory transfers
CREATE TABLE trf (
    id 			integer PRIMARY KEY DEFAULT nextval('id'),
    transdate 		date,
    trfnumber 		text,
    description 	text,
    notes 		text,
    department_id 	integer,
    from_warehouse_id	integer,
    to_warehouse_id 	integer DEFAULT 0,
    employee_id		integer DEFAULT 0
);

-- Customisation of 'inventory' table for transfer module
-- linetype:
---- 0 for transactions from ar, ap, oe etc.
---- 1 for transaction entered by user in trf
---- 2 for offsetting transaction generated by system in trf
---- 3 Inventory taken out to build assembly
---- 4 Assembly built
ALTER TABLE inventory 
	ADD COLUMN department_id 	integer,
	ADD COLUMN warehouse_id2 	integer,
	ADD COLUMN serialnumber 	text,
	ADD COLUMN itemnotes 		text,
	ADD COLUMN cost 		float,
	ADD COLUMN linetype 		CHAR(1) DEFAULT '0'
;

-- delivereddate is updated by a seperate form when goods are 'received' at the other warehouse.
ALTER TABLE trf ADD COLUMN delivereddate DATE;

ALTER TABLE invoice ADD COLUMN transdate DATE;

-- Table for invoices reposting / FIFO reports.
-- trans_id is ar.id
CREATE TABLE fifo (
	trans_id	integer,
	transdate	date,
	parts_id	integer,
	qty		float,
	costprice	float,
	sellprice	float
);

ALTER TABLE invoice ADD COLUMN lastcost float;

CREATE TABLE invoicetax (
	trans_id	integer,
 	invoice_id	integer,
	chart_id	integer,
	taxamount	float
);

CREATE INDEX invoice_parts_id ON invoice (parts_id); 
CREATE INDEX fifo_parts_id ON fifo (parts_id);

CREATE TABLE build (
	id		integer PRIMARY KEY DEFAULT nextval('id'),
	reference	text,
	transdate	date,
	department_id	integer,
	warehouse_id	integer,
	employee_id	integer
);

-- description column stores user-modified description of item from invoices and transfer screen.
ALTER TABLE inventory ADD COLUMN description TEXT;

-- FIFO is based on warehouse now.
ALTER TABLE fifo ADD COLUMN warehouse_id INTEGER;
ALTER TABLE invoice ADD COLUMN warehouse_id INTEGER;

-- invoice_id reference in acc_trans 
ALTER TABLE fifo ADD COLUMN invoice_id INTEGER;

ALTER TABLE inventory ADD COLUMN invoice_id INTEGER;
CREATE INDEX inventory_invoice_id ON inventory (invoice_id);

ALTER TABLE invoice ADD COLUMN cogs float;
ALTER TABLE inventory ADD COLUMN cogs float;

-- armaghan 01/apr/2010 acc_trans primary key
CREATE SEQUENCE entry_id;
SELECT nextval ('entry_id');
ALTER TABLE acc_trans ADD COLUMN entry_id INTEGER DEFAULT nextval('entry_id');


-- Update new denormalized columns (moved from cogs reposting)
UPDATE invoice SET 
	transdate = (SELECT transdate FROM ar WHERE ar.id = invoice.trans_id),
	warehouse_id = (SELECT warehouse_id FROM ar WHERE ar.id = invoice.trans_id)
WHERE trans_id IN (SELECT id FROM ar);

UPDATE invoice SET 
	transdate = (SELECT transdate FROM ap WHERE ap.id = invoice.trans_id),
	warehouse_id = (SELECT warehouse_id FROM ap WHERE ap.id = invoice.trans_id)
WHERE trans_id IN (SELECT id FROM ap);

-- Few indexes to speed up cogs reposting
CREATE INDEX fifo_trans_id ON fifo (trans_id);
CREATE INDEX invoice_qty ON invoice (qty);

-- Tables for Ledgercart
CREATE SEQUENCE customerloginid start 1;
SELECT nextval('customerloginid');

CREATE TABLE customercart (
    cart_id character varying(32),
    customer_id integer,
    parts_id integer,
    qty double precision DEFAULT 0,
    price double precision DEFAULT 0,
    taxaccounts text
);

CREATE TABLE customerlogin (
    id integer DEFAULT nextval('customerloginid') primary key,
    "login" character varying(100) unique,
    passwd character(32),
    "session" character(32) unique,
    session_exp character varying(20),
    customer_id integer
);

CREATE TABLE partsattr (
    parts_id INTEGER,
    hotnew VARCHAR(3)
);

ALTER TABLE acc_trans ADD tax TEXT;
ALTER TABLE acc_trans ADD taxamount float;

-- dispatch methods table
CREATE TABLE dispatch (
  id int DEFAULT nextval('id'),
  description text
);

ALTER TABLE customer ADD dispatch_id INTEGER;
ALTER TABLE vendor ADD dispatch_id INTEGER;

ALTER TABLE invoicetax ADD amount float;

ALTER TABLE acc_trans ADD tax_chart_id INTEGER;

ALTER TABLE ar ADD linetax BOOLEAN DEFAULT false;
ALTER TABLE ap ADD linetax BOOLEAN DEFAULT false;

-- DATEV export 
create table debits (id serial, reference text, description text, transdate date, accno text, amount numeric(12,2));
create table credits (id serial, reference text, description text, transdate date, accno text, amount numeric(12,2));
create table debitscredits (id serial, reference text, description text, transdate date, debit_accno text, credit_accno text, amount numeric(12,2));

ALTER TABLE ar ADD fxamount NUMERIC(12,2) DEFAULT 0;
ALTER TABLE ar ADD fxpaid NUMERIC(12,2) DEFAULT 0;
ALTER TABLE ap ADD fxamount NUMERIC(12,2) DEFAULT 0;
ALTER TABLE ap ADD fxpaid NUMERIC(12,2) DEFAULT 0;
ALTER TABLE chart ADD allow_gl BOOLEAN DEFAULT true;


