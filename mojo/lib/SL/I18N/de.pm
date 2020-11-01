package SL::I18N::de;
use Mojo::Base 'SL::I18N';

our %Lexicon = (
    # Development:
    'Hello' => 'Hallo',
    'System Information' => 'Systeminformationen',
    'This is a minimal Mojolicious-rendered page.'
        => 'Dies ist eine minimale, von Mojolicious gerenderte Seite.',

    # Commonly used:
    'Continue' => 'Weiter',
    'Back'     => 'Zurück',
    'Create'   => 'Erstellen',
    'Download' => 'Herunterladen',
    
    # GoBD:
    'GoBD Export' => 'GoBD-Export',
    'Export successful' => 'Export erfolgreich',
    'Export failed'     => 'Export fehlgeschlagen',
    'Show log'          => 'Protokoll anzeigen',
    'Archive filename'  => 'Archiv-Dateiname',
    'Contents'          => 'Inhalt',
    'Download ZIP file' => 'ZIP-Datei herunterladen',

    # Preliminary VAT Return:
    'Preliminary VAT Return' => 'Umsatzsteuer-Voranmeldung',
    
    
    # Date picker:
    'From date' => 'Von',
    'To date'   => 'Bis',
    'or' => 'oder',
    'Period'    => 'Zeitraum',
    'Current' => 'Aktuell',
    'Month'     => 'Monat',
    'Quarter'   => 'Quartal',
    'Year'      => 'Jahr',
    'January'   => 'Januar',
    'February'  => 'Februar',
    'March'     => 'März',
    'April'     => 'April',
    'May'       => 'Mai',
    'June'      => 'Juni',
    'July'      => 'Juli',
    'August'    => 'August',
    'September' => 'September',
    'October'   => 'Oktober',
    'November'  => 'November',
    'December'  => 'Dezember',
    'Incorrect input, please check'
        => 'Ungültige Eingabe, bitte überprüfen',

    
    # Admin Backup/Restore:
    'Backup'  => 'Sichern',
    'Restore' => 'Wiederherstellen',
    'Dataset' => 'Datenset',
    'Size'    => 'Größe',
    'Action'  => 'Aktion',

    'Procedure if dataset already exists' =>
        'Vorgehensweise falls das Datenset schon existiert',
    'Do nothing; just bail out with an error' =>
        'Nichts tun; nur eine Fehlermeldung anzeigen',
    'Rename existing dataset in' =>
        'Das existierende Datenset umbenennen in',
    'Drop existing dataset (caution!)' =>
        'Das existierende Datenset löschen (Vorsicht!)',

    
    'can take a while' => 'kann eine Weile dauern',

    'Restore successful' => 'Wiederherstellung erfolgreich',
    'is now ready for use' => 'kann nun verwendet werden',
    
    'Database Administration' => 'Datenbankverwaltung',
    'Main Menu'               => 'Hauptmenü',

    'Error'              => 'Fehler',
    'Connection problem' => 'Verbindungsproblem',
    'No file chosen'     => 'Keine Datei ausgewählt',
    'No CREATE DATABASE statement found' =>
        'Keine CREATE DATABASE-Anweisung gefunden',
    'Dataset already exists' => 'Datenset existiert schon',
    'Cannot rename: No name given' =>
        'Es wurde kein Name zum Umbenennen angegeben',
);


1;
