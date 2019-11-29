---------******************************---------
--manual mapping checks

-- fill in supplier concept_codes with OMOP-generated from dcs
UPDATE amt_mm mm
SET code = (
           SELECT concept_code
           FROM drug_concept_stage dcs
           WHERE mm.name = dcs.concept_name
           )
WHERE mm.flag = 'suppl';

-- check mm source name/code consistency
SELECT mm.code, mm.name, dcs.concept_code, dcs.concept_name
FROM amt_mm mm
     JOIN drug_concept_stage dcs
     ON mm.code = dcs.concept_code
WHERE lower(mm.name) <> lower(dcs.concept_name)
ORDER BY mm.name;

-- check mm target name/id consistency
SELECT *
FROM amt_mm mm
     JOIN concept c
     ON mm.concept_id = c.concept_id
WHERE mm.concept_name <> c.concept_name;

-- check for invalid concepts in amt_mm
SELECT *
FROM amt_mm mm
     JOIN devv5.concept c
     ON c.concept_id = mm.concept_id
WHERE c.invalid_reason IS NOT NULL;

-- check for non-standard ingredients in amt_mm
SELECT *
FROM amt_mm mm
     JOIN devv5.concept c
     ON c.concept_id = mm.concept_id
WHERE c.standard_concept IS NULL
  AND c.concept_class_id = 'Ingredient';

---------******************************---------

-- DO
-- $body$
--     BEGIN
--         EXECUTE format('create table %I as select * from relationship_to_concept',
--                        'relationship_to_concept_backup_' || to_char(current_date, 'yyyymmdd'));
--     END
-- $body$;

TRUNCATE TABLE relationship_to_concept;

---------******************************----------
-- mm and rtc insert/update into ingredient_mapped
TRUNCATE TABLE ingredient_mapped;
INSERT INTO ingredient_mapped
SELECT mm.name,
       NULL                                          AS new_name,
       mm.concept_id                                 AS concept_id_2,
       mm.concept_name                               AS concept_name_2,
       rank() OVER (PARTITION BY mm.concept_code
           ORDER BY mm.vocabulary_id, mm.concept_id) AS precedence
FROM amt_mm mm
WHERE mm.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM ingredient_mapped im
                 WHERE lower(mm.name) = lower(im.concept_name));


INSERT INTO ingredient_mapped
SELECT dcs.concept_name, NULL, c.concept_id, c.concept_name, rtc.precedence
FROM relationship_to_concept_bckp300817 rtc
     JOIN drug_concept_stage dcs
     ON rtc.concept_code_1 = dcs.concept_code
     JOIN concept c
     ON c.concept_id = rtc.concept_id_2
WHERE c.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM ingredient_mapped im
                 WHERE lower(dcs.concept_name) = lower(im.concept_name));


DELETE
FROM ingredient_mapped
WHERE cast(concept_id_2 AS int)
          IN (SELECT concept_id FROM concept WHERE invalid_reason = 'D');


-- delete deprecated from ingredient mapped
WITH
    to_be_deleted AS (
    SELECT *
    FROM ingredient_mapped
    WHERE cast(concept_id_2 AS int)
              IN (SELECT concept_id FROM concept WHERE invalid_reason = 'D')
    )
DELETE
FROM ingredient_mapped
WHERE concept_id_2 IN (SELECT concept_id_2 FROM to_be_deleted);


-- update 'U' in ingredient_mapped
UPDATE ingredient_mapped aim
SET concept_id_2 = c.concept_id_2
FROM (
     SELECT concept_id_2, concept_id_1
     FROM concept_relationship cr
          JOIN concept C
          ON c.concept_id = concept_id_1
              AND c.invalid_reason = 'U'
              AND relationship_id = 'Maps to'
              AND cr.invalid_reason IS NULL
     ) C
WHERE (CAST(aim.concept_id_2 AS INT) = c.concept_id_1);

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


SELECT *
FROM ingredient_mapped;
---------******************************----------

-- insert ingredients into rtc by concept_name match
INSERT
INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dcs.concept_code, 'AMT',
                c.concept_id,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY C.vocabulary_id, C.concept_id)
FROM drug_concept_stage dcs
     JOIN concept C
     ON lower(C.concept_name) = lower(dcs.concept_name)
         AND C.concept_class_id = 'Ingredient'
         AND C.vocabulary_id LIKE 'RxNorm%'
         AND C.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE dcs.concept_code = rtc2.concept_code_1
    )
;

-- insert ingredients into rtc by Precise Ingredient match
INSERT
INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dcs.concept_code, 'AMT',
                cc.concept_id,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY C.vocabulary_id, C.concept_id)
FROM drug_concept_stage dcs
     JOIN concept C
     ON lower(C.concept_name) = lower(dcs.concept_name)
         AND C.concept_class_id = 'Precise Ingredient'
         AND C.vocabulary_id LIKE 'RxNorm%'
         AND (C.standard_concept IS NULL OR C.invalid_reason IS NOT NULL)
     JOIN concept_relationship cr
     ON C.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL
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


-- update invalid ingredients via "Maps to" relationship and insert into rtc
INSERT
INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dcs.concept_code, 'AMT',
                cc.concept_id,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id)
FROM drug_concept_stage dcs
     JOIN concept C
     ON lower(C.concept_name) = lower(dcs.concept_name)
         AND C.concept_class_id = 'Ingredient'
         AND C.vocabulary_id LIKE 'RxNorm%'
         AND (C.standard_concept IS NULL OR C.invalid_reason IS NOT NULL)
     JOIN concept_relationship cr
     ON C.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
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

-----------------------------------------------------------------------
SELECT DISTINCT concept_code_1
FROM relationship_to_concept
GROUP BY concept_code_1
HAVING count(concept_code_1) > 1;
