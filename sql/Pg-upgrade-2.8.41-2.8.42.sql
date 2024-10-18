CREATE EXTENSION fuzzystrmatch;

CREATE TEXT SEARCH DICTIONARY simple_related_party(
    TEMPLATE = simple,
    STOPWORDS = related_party
);

CREATE TEXT SEARCH CONFIGURATION simple_related_party(
    COPY = simple
);
ALTER TEXT SEARCH CONFIGURATION simple_related_party
    ALTER MAPPING REPLACE simple WITH simple_related_party;

UPDATE defaults SET fldvalue = '2.8.42' WHERE fldname = 'version';