-- Schweizer Kontenrahmen KMU (Sterchi/Schweizer Gewerbeverband)
-- exkl. Konzern- und Tochtergesellschaften
-- ab SQL Ledger Version 2.8, einsprachig (deutsch)
-- Das Script löscht den bestehenden Kontenrahmen (falls vorhanden). 
-- Dieses Script nur bei Neuinstallationen bzw. Datenbanken ohne bestehende Buchungen durchführen.
-- integratio GmbH, September 2007

-- Diverse Anpassungen durch Run my Accounts AG, Juni, September 2008, Oktober 2010
-- Version 10.01.2011, Thomas Brändle

-----------------
--- 1 AKTIVEN ---
-----------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1','AKTIVEN','H','1','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('10','UMLAUFVERMÖGEN','H','100','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('100','FLÜSSIGE MITTEL UND WERTSCHRIFTEN','H','100','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1000','Kasse','A','100','A','AR_paid:AP_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1020','Bank','A','100','A','AR_paid:AP_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1050','kurzfristige Geldanlagen','A','100','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('110','FORDERUNGEN','H','110','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1100','Debitoren','A','110','A','AR');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1101','Debitoren alt','A','110','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1109','Delkredere','A','110','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1170','Vorsteuer 8.0% auf Mat. + DL','A','110','A','AP_tax');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1172','Vorsteuer 2.5% auf Mat. + DL','A','110','A','AP_tax');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1173','Vorsteuer 8.0% auf Inv. + übr. BA','A','110','A','AP_tax');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1174','Vorsteuer 3.8% auf Inv. + übr. BA','A','110','A','AP_tax');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1175','Vorsteuer 2.5% auf Inv. + übr. BA','A','110','A','AP_tax');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1179','Guthaben Verrechnungssteuer','A','110','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1190','Übrige kurzfristige Forderungen','A','110','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('120','ANGEFANGENE ARBEITEN','H','120','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1280','Angefangene Arbeiten','A','120','A','IC');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('130','AKTIVE RECHNUNGSABGRENZUNG','H','130','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1300','Transitorische Aktiven','A','130','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('14','ANLAGEVERMÖGEN','H','140','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('140','FINANZANLAGEN','H','140','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1400','Wertpapiere des Anlagevermögens','A','140','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1420','Beteiligungen','A','140','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1440','Darlehensforderungen gegenüber Dritten','A','140','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1460','Darlehensforderungen gegenüber Gesellschaftern','A','140','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('150','MOBILE SACHANLAGEN','H','150','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1500','Maschinen und Apparate','A','150','A','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1510','Mobiliar und Einrichtungen','A','150','A','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1520','IT, Software, Kommunikation','A','150','A','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1530','Fahrzeuge','A','150','A','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1540','Werkzeuge und Geräte','A','150','A','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1590','Übrige mobile Sachanlagen','A','150','A','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('170','IMMATERIELLE ANLAGEN','H','170','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1700','Patente, Marken, Lizenzen','A','170','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('18','AKTIVIERTER AUFWAND UND AKTIVE BERICHTIGUNGSPOSTEN','H','180','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1800','Gründungs-, Kapitalerhöhungs- und Organisationsaufwand','A','180','A','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('1850','Nichteinbezahltes Kapital','A','180','A','');
------------------
--- 2 PASSIVEN ---
------------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2','PASSIVEN','H','2','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('20','FREMDKAPITAL KURZFRISTIG','H','200','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('200','KREDITOREN','H','200','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2000','Kreditoren','A','200','L','AP');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2001','Kreditoren alt','A','200','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2002','Verbindlichkeiten für Personalaufwand','A','200','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2010','Verbindlichkeiten für AHV','A','200','L','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2011','Verbindlichkeiten für BVG','A','200','L','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2012','Verbindlichkeiten für UVG','A','200','L','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2013','Verbindlichkeiten für KTG','A','200','L','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2014','Verbindlichkeiten für Quellensteuer','A','200','L','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2030','Anzahlungen von Kunden','A','200','L','AR_amount:IC_income ');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('210','KURZFR. FINANZVERBINDLICHKEITEN','H','210','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2160','Kontokorrent Gesellschafter','A','210','L','AR_paid:AP_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2185','Kreditkarte','A','210','L','AP_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('220','ANDERE KURZFRISTIGE VERBINDLICHKEITEN','H','220','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2200','Geschuldete MWST','A','220','L','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2201','MWST 8,0%','A','220','L','AR_tax:IC_taxpart:IC_taxservice');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2202','MWST 3,8%','A','220','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2203','MWST 2,5%','A','220','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('230','PASSIVE RECHNUNGSABGRENZUNG UND KURZFRISTIGE RÜCKSTELLUNGEN','H','230','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2300','Transitorische Passiven','A','230','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('24','FREMDKAPITAL LANGFRISTIG','H','240','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('240','LANGFRISTIGE FINANZVERBINDLICHKEITEN','H','240','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2400','Bankschulden langfristig','A','240','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2500','Langfristige Verbindlichkeiten gegenüber Dritten','A','240','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2560','Langfristige Verbindlichkeiten gegenüber Gesellschaftern','A','240','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('260','RÜCKSTELLUNGEN LANGFRISTIG','H','260','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2600','Rückstellungen','A','260','L','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('28','EIGENKAPITAL','H','280','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('280','KAPITAL','H','280','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2800','Eigenkapital','A','280','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('290','RESERVEN','H','290','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2900','Gesetzliche Reserven','A','290','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2910','Andere Reserven','A','290','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('299','BILANZGEWINN / BILANZVERLUST','H','299','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2990','Gewinnvortrag / Verlustvortrag','A','299','Q','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('2991','Jahresgewinn / Jahresverlust','A','299','Q','');
------------------------
--- 3 BETRIEBSERTRAG ---
------------------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3','BETRIEBSERTRAG AUS LIEFERUNGEN UND LEISTUNGEN','H','3','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('30','PRODUKTIONSERTRAG','H','300','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3000','Produktionsertrag','A','300','I','AR_amount:IC_income');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('32','HANDELSSERTRAG','H','320','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3200','Handelsertrag','A','320','I','AR_amount:IC_income');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('34','DIENSTLEISTUNGSERTRAG','H','340','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3400','Dienstleistungsertrag','A','340','I','AR_amount:IC_income');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('36','ÜBRIGER ERTRAG','H','360','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3600','Nebenertrag aus Lieferung und Leistung','A','360','I','AR_amount:IC_income');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3600','Systemkonto','A','360','I','AR_amount:IC_sale:IC_income');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('39','ERTRAGSMINDERUNGEN','H','390','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3900','Skonti','A','390','E','AR_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3901','Rabatte und Preisnachlässe','A','390','E','AR_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('3905','Debitorenverluste','A','390','E','AR_paid');
----------------------------------------------------------
--- 4 AUFWAND FÜR MATERIAL, WAREN UND DRITTLEISTUNGEN ---
----------------------------------------------------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('4','AUFWAND FÜR MATERIAL, WAREN UND DIENSTLEISTUNGEN','H','400','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('40','MATERIALAUFWAND','H','400','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('4000','Materialaufwand','A','400','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('42','HANDELSWARENAUFWAND','H','420','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('4200','Handelswarenaufwand','A','420','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('44','AUFWAND FÜR DRITTLEISTUNGEN','H','440','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('4400','Aufwand für Drittleistungen','A','440','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('49','SKONTO','H','470','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('4900','Skonto','A','470','E','AP_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('4999','Systemkonto','A','400','E','AP_amount:IC_cogs:IC_expense');
-------------------------
--- 5 PERSONALAUFWAND ---
-------------------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5','PERSONALAUFWAND','H','500','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('54','PERSONALAUFWAND DIENSTLEISTUNGEN','H','540','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5400','Löhne','A','540','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5401','Zulagen','A','540','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5402','Erfolgsbeteiligungen','A','540','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5405','Leistungen von Sozialversicherungen','A','540','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('57','SOZIALVERSICHERUNGSAUFWAND','H','570','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5700','AHV, IV, EO, ALV, FAK','A','570','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5720','Berufliche Vorsorge','A','570','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5730','Unfallversicherung','A','570','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5740','Krankentaggeldversicherung','A','570','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5790','Quellensteuer','A','570','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('58','ÜBRIGER PERSONALAUFWAND','H','580','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5800','Personalinserate','A','580','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5810','Aus- und Weiterbildung','A','580','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5820','Spesenentschädigungen effektiv','A','580','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5830','Spesenentschädigungen pauschal','A','580','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5840','Personalkantine','A','580','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('5880','Sonstiger Personalaufwand','A','580','E','AP_amount');
-----------------------------------
--- 6 SONSTIGER BETRIEBSAUFWAND ---
-----------------------------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6','SONSTIGER BETRIEBSAUFWAND','H','600','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('60','RAUMAUFWAND','H','600','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6000','Mieten','A','600','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6030','Nebenkosten','A','600','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6040','Reinigung','A','600','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6090','Privatanteile Raumaufwand','A','600','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('61','UNTERHALT, REPARATUREN, ERSATZ (URE) UND LEASINGAUFWAND MOBILE SACHANLAGEN','H','610','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6130','Unterhalt und Ersatz','A','610','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('616','Leasingaufwand mobile Sachanlagen','H','610','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6160','Leasing mobile Sachanlagen','A','610','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('62','FAHRZEUG- UND TRANSPORTAUFWAND','H','620','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6200','Reparaturen, Service, Reinigung Personenwagen','A','620','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6210','Benzin','A','620','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6220','Versicherungen Fahrzeuge','A','620','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6230','Verkehrsabgaben, Beiträge, Gebühren','A','620','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6260','Fahrzeugleasing','A','620','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6270','Privatanteil am Fahrzeugaufwand','A','620','E','AR_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('630','SACHVERSICHERUNGEN','H','630','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6300','Sachversicherungen','A','630','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('636','ABGABEN, GEBÜHREN, BEWILLIGUNGEN','H','636','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6360','Abgaben und Gebühren','A','636','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6370','Bewilligungen','A','636','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('64','ENERGIE-, ENTSORGUNGSAUFWAND','H','640','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6400','Elektrizität','A','640','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6460','Entsorgungsaufwand (Kehricht)','A','640','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('65','VERWALTUNGS- UND INFORMATIKAUFWAND','H','650','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('650','VERWALTUNGSAUFWAND','H','650','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6500','Büromaterial','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6501','Drucksachen','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6503','Fachliteratur','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6510','Telekommunikation','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6513','Porti','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6520','Mitgliedschaften, Spenden, Beiträge, Trinkgelder','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6530','Buchführung und Abschluss','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6531','Unternehmensberatung','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6532','Rechtsberatung','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6540','Verwaltungsrat, Generalversammlung','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6542','Revisionsstelle','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('656','INFORMATIKAUFWAND','H','650','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6561','Hosting und Wartung','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6573','Verbrauchsmaterial IT','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6580','Beratung und Entwicklung IT','A','650','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('66','WERBEAUFWAND','H','660','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6600','Werbung','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6610','Werbedrucksachen, Werbematerial, Muster','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6620','Fachmessen, Ausstellungen, Dekoration','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6640','Reisespesen','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6641','Kundenbetreuung','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6660','Sponsoring','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6670','Öffentlichkeitsarbeit, Public Relations, Kundenanlässe','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6680','Werbeberatung, Marktanalysen','A','660','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('67','ÜBRIGER BETRIEBSAUFWAND','H','670','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6700','Übriger Betriebsaufwand','A','670','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('68','FINANZERFOLG','H','680','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('680','FINANZAUFWAND','H','680','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6800','Zinsaufwand gegenüber Dritten','A','680','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6830','Zinsaufwand gegenüber Vorsorgeeinrichtungen','A','680','E','AP_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6840','Bank-/PC-Spesen','A','680','E','AR_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6842','Kursverluste','A','680','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('685','FINANZERTRAG','H','685','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6850','Erträge aus flüssigen Mitteln und Wertschriften','A','685','I','AR_amount');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6892','Kursgewinne','A','685','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('69','ABSCHREIBUNGEN','H','690','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('6900','Abschreibungen','A','690','E','');
----------------------------------------------------------------
--- 8 AUSSERORDENTLICHER UND BETRIEBSFREMDER ERFOLG, STEUERN ---
----------------------------------------------------------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('8','AUSSERORDENTLICHER UND BETRIEBSFREMDER ERFOLG, STEUERN','H','800','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('800','AUSSERORDENTLICHER ERTRAG','H','800','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('8000','Ausserordentlicher Ertrag','A','800','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('801','AUSSERORDENTLICHER AUFWAND','H','800','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('8010','Ausserordentlicher Aufwand','A','800','I','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('89','STEUERN','H','890','E','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('8900','Steuern','A','890','E','AP_amount');
-------------------
--- 9 ABSCHLUSS ---
-------------------
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('9','TRANSFERKONTEN','H','900','A','');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('9900','Transferkonto','A','900','A','AR_paid:AP_paid');
INSERT INTO chart (accno,description,charttype,gifi_accno,category,link) VALUES ('9910','Abklärungskonto','A','900','A','AP_amount');
---
DELETE FROM tax;
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '1170'),0.080);
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '1172'),0.025);
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '1173'),0.080);
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '1174'),0.038);
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '1175'),0.025);
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '2201'),0.080);
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '2202'),0.038);
INSERT INTO tax (chart_id,rate) VALUES ((select id from chart where accno = '2203'),0.025);
--
DELETE FROM DEFAULTS WHERE fldname='inventory_accno_id';
DELETE FROM DEFAULTS WHERE fldname='income_accno_id';
DELETE FROM DEFAULTS WHERE fldname='expense_accno_id';
DELETE FROM DEFAULTS WHERE fldname='fxgain_accno_id';
DELETE FROM DEFAULTS WHERE fldname='fxloss_accno_id';
DELETE FROM DEFAULTS WHERE fldname='currencies';
DELETE FROM DEFAULTS WHERE fldname='weightunit';
DELETE FROM DEFAULTS WHERE fldname='cdt';
INSERT INTO defaults (fldname, fldvalue) VALUES ('inventory_accno_id', (SELECT id FROM chart WHERE accno = '1280'));
INSERT INTO defaults (fldname, fldvalue) VALUES ('income_accno_id', (SELECT id FROM chart WHERE accno = '3400'));
INSERT INTO defaults (fldname, fldvalue) VALUES ('expense_accno_id', (SELECT id FROM chart WHERE accno = '4200'));
INSERT INTO defaults (fldname, fldvalue) VALUES ('fxgain_accno_id', (SELECT id FROM chart WHERE accno = '6892'));
INSERT INTO defaults (fldname, fldvalue) VALUES ('fxloss_accno_id', (SELECT id FROM chart WHERE accno = '6842'));
INSERT INTO defaults (fldname, fldvalue) VALUES ('weightunit', 'kg');
INSERT INTO defaults (fldname, fldvalue) VALUES ('precision', '2');
INSERT INTO DEFAULTS (fldname, fldvalue) VALUES ('cdt', '1');
INSERT INTO defaults (fldname, fldvalue) VALUES ('glnumber','X-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('sinumber','R-999');
INSERT INTO defaults (fldname, fldvalue) VALUES ('vinumber','EB-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('batchnumber','V-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('vouchernumber','B-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('sonumber','AB-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('ponumber','E-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('sqnumber','O-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('rfqnumber','EO-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('partnumber','ART-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('employeenumber','MA-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('customernumber','KD-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('vendornumber','L-0');
INSERT INTO defaults (fldname, fldvalue) VALUES ('projectnumber','P-0');
--
DELETE FROM curr;
INSERT INTO curr (rn, curr, precision) VALUES (1,'CHF',2);
INSERT INTO curr (rn, curr, precision) VALUES (2,'EUR',2);
INSERT INTO curr (rn, curr, precision) VALUES (3,'USD',2);
INSERT INTO curr (rn, curr, precision) VALUES (4,'GBP',2);


