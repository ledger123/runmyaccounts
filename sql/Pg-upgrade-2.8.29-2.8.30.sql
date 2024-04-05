UPDATE chart SET parent_id = NULL;

UPDATE chart
SET parent_id = to_update.parent_id FROM (
                WITH headers AS (
                    SELECT c.id as id,
                           c.accno as accno,
                           LENGTH(c.accno) AS class
                    FROM chart c
                    WHERE c.charttype = 'H'
                    ORDER BY c.accno
                )
                SELECT chart_id,
                       chart_accno,
                       parent_accno,
                       p.id as parent_id
                FROM (
                    SELECT chart.id as chart_id,
                           chart.accno as chart_accno,
                           MAX(headers.accno) as parent_accno
                    FROM chart
                    LEFT JOIN headers ON
                        CASE
                            WHEN chart.charttype = 'A'
                                THEN headers.accno < chart.accno
                            ELSE headers.accno < chart.accno
                                AND headers.class < (SELECT ch.class FROM headers ch WHERE chart.id = ch.id)
                        END
                    WHERE (chart.accno ~ '^[0-9]+$' OR chart.charttype = 'A')
                    GROUP BY chart.id, chart.accno
                    ORDER BY chart.accno
                ) chart_to_parent_accno
                LEFT JOIN chart p ON p.accno = parent_accno
            ) to_update
WHERE id = to_update.chart_id;

UPDATE defaults SET fldvalue = '2.8.30' WHERE fldname = 'version';
