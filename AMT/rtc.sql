--TEMPORARY SCRIPT

--DROP TABLE IF EXISTS ingredient_mapped;
CREATE TABLE IF NOT EXISTS ingredient_mapped
(
    concept_name varchar(255),
    new_name     varchar(255),
    concept_id_2 integer,
    precedence   integer
)
;

--TRUNCATE TABLE ingredient_mapped;

--check if concept_name have several mappings with different precidence
with rtc AS (SELECT DISTINCT * FROM relationship_to_concept_bckp300817)

INSERT INTO ingredient_mapped
SELECT DISTINCT dcs.concept_name,
                NULL,
                c.concept_id,
                rtc.precedence
FROM rtc
JOIN drug_concept_stage dcs
     ON rtc.concept_code_1 = dcs.concept_code AND dcs.concept_class_id = 'Ingredient'
JOIN concept c
     ON c.concept_id = rtc.concept_id_2 AND c.concept_class_id = 'Ingredient'
WHERE dcs.concept_name NOT IN (
                                SELECT dcs.concept_name
                                FROM rtc
                                JOIN drug_concept_stage dcs
                                     ON rtc.concept_code_1 = dcs.concept_code
                                JOIN concept c
                                     ON c.concept_id = rtc.concept_id_2
                                GROUP BY dcs.concept_name, rtc.precedence
                                HAVING COUNT (DISTINCT c.concept_id) > 1
                                )
;

--check inserted mapping having precedence > 1
SELECT *
FROM ingredient_mapped im
JOIN devv5.concept c
ON im.concept_id_2 = c.concept_id

WHERE im.concept_name IN

      (SELECT concept_name
        FROM ingredient_mapped im
          GROUP BY concept_name
          HAVING COUNT (*) > 1)
;






--STABLE SCRIPT
--create relationship_to_concept table backup
DO
$body$
    BEGIN
        EXECUTE format('create table %I as select * from relationship_to_concept',
                       'relationship_to_concept_backup_' || to_char(current_date, 'yyyymmdd'));
    END
$body$;

TRUNCATE TABLE relationship_to_concept;


--TODO first update U targets, then drop all U/D targets
--TODO make update just for codes having count (DISTINCT concept_id_2 = 1)
--TODO remove CASTs

--delete deprecated from ingredient mapped
WITH
    to_be_deleted AS (
    SELECT *
    FROM ingredient_mapped
    WHERE concept_id_2 IN (SELECT concept_id FROM concept WHERE invalid_reason = 'D')
    )
DELETE
FROM ingredient_mapped
WHERE concept_id_2 IN (SELECT concept_id_2 FROM to_be_deleted);


-- update 'U' in ingredient_mapped
WITH
    to_be_updated AS (
    SELECT im.concept_id_2 AS concept_id_1,
           im.concept_name,
           c2.concept_id   AS concept_id_2,
           c2.concept_name AS concept_name_2
    FROM ingredient_mapped im
    JOIN concept c1
         ON im.concept_id_2 = c1.concept_id
    JOIN concept_relationship cr
         ON cr.concept_id_1 = c1.concept_id
    JOIN concept c2
         ON c2.concept_id = cr.concept_id_2
    WHERE cr.relationship_id = 'Maps to'
      AND cr.invalid_reason IS NULL
      AND c1.invalid_reason = 'U'
    )
UPDATE ingredient_mapped im
SET concept_id_2 = to_be_updated.concept_id_2
FROM to_be_updated
WHERE (CAST(im.concept_id_2 AS INT) = to_be_updated.concept_id_1);



-- insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                c.concept_id, --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id)
FROM drug_concept_stage dcs
JOIN concept c
     ON lower(c.concept_name) = lower(dcs.concept_name)
         AND c.concept_class_id = 'Ingredient'
         AND c.vocabulary_id LIKE 'RxNorm%'
         AND c.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE dcs.concept_code = rtc2.concept_code_1
    )
;

-- insert auto-mapping into rtc by Precise Ingredient name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id, --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id)
FROM drug_concept_stage dcs
JOIN concept c
     ON lower(c.concept_name) = lower(dcs.concept_name)
         AND c.concept_class_id = 'Precise Ingredient'
         AND c.vocabulary_id LIKE 'RxNorm%'
JOIN concept_relationship cr
     ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL
JOIN concept cc
     ON cr.concept_id_2 = cc.concept_id
         AND cc.concept_class_id = 'Ingredient'
         AND cc.vocabulary_id LIKE 'RxNorm%'
         AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE dcs.concept_code = rtc2.concept_code_1
    )
;


-- insert mapping into rtc by concept_name match throught U/D ingredients and 'Maps to' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id, --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id)
FROM drug_concept_stage dcs
JOIN concept c
     ON lower(c.concept_name) = lower(dcs.concept_name)
         AND c.concept_class_id = 'Ingredient'
         AND c.vocabulary_id LIKE 'RxNorm%'
         AND (c.standard_concept IS NULL OR c.invalid_reason IS NOT NULL)
JOIN concept_relationship cr
     ON c.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
JOIN concept cc
     ON cr.concept_id_2 = cc.concept_id
         AND cc.concept_class_id = 'Ingredient'
         AND cc.vocabulary_id LIKE 'RxNorm%'
         AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE dcs.concept_code = rtc2.concept_code_1
    )
  AND dcs.concept_name NOT IN ('Rhamnus Frangula', 'Polylactic Acid')
;

--TODO: Is 'Polylactic Acid' Drud? If not, delete as AMT ingredient?


--TODO Add comment to this check
SELECT DISTINCT concept_code_1
FROM relationship_to_concept
GROUP BY concept_code_1
HAVING count(*) > 1;
