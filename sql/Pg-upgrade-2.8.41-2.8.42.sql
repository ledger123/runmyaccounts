CREATE TABLE search_irrelevant_words (
    id SERIAL PRIMARY KEY,
    search_target TEXT NOT NULL,
    word TEXT NOT NULL
);

INSERT INTO search_irrelevant_words (search_target, word)
VALUES ('RELATED_PARTY', 'sàrl'),
       ('RELATED_PARTY', 'sa'),
       ('RELATED_PARTY', 'gmbh'),
       ('RELATED_PARTY', 'ag'),
       ('RELATED_PARTY', 'sarl'),
       ('RELATED_PARTY', 'sagl'),
       ('RELATED_PARTY', 'gbr'),
       ('RELATED_PARTY', 'ohg'),
       ('RELATED_PARTY', 'partg'),
       ('RELATED_PARTY', 'ug'),
       ('RELATED_PARTY', 'ggmbh'),
       ('RELATED_PARTY', 'llc'),
       ('COMMON', 'the'),
       ('COMMON', 'a'),
       ('COMMON', 'an'),
       ('COMMON', 'and'),
       ('COMMON', 'der'),
       ('COMMON', 'die'),
       ('COMMON', 'das'),
       ('COMMON', 'und'),
       ('COMMON', 'ein'),
       ('COMMON', 'eine'),
       ('COMMON', 'le'),
       ('COMMON', 'la'),
       ('COMMON', 'et'),
       ('COMMON', 'un'),
       ('COMMON', 'une');

CREATE EXTENSION fuzzystrmatch;

CREATE OR REPLACE FUNCTION to_filtered_tsvector(input TEXT, filter_type TEXT DEFAULT 'COMMON', ts_config REGCONFIG DEFAULT 'simple')
    RETURNS tsvector AS $$
DECLARE
    filtered_input TEXT;
BEGIN
    SELECT string_agg(input_word, ' ') INTO filtered_input
    FROM unnest(string_to_array(input, ' ')) AS input_word
    WHERE lower(input_word) NOT IN (SELECT lower(word)
                                    FROM search_irrelevant_words
                                    WHERE search_target = 'COMMON' OR search_target = filter_type);

    RETURN to_tsvector(ts_config, filtered_input);
END;
$$ LANGUAGE plpgsql;

UPDATE defaults SET fldvalue = '2.8.42' WHERE fldname = 'version';