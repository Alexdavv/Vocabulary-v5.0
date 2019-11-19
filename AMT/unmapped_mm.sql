-- fill in supplier concept_codes
UPDATE amt_mm mm
SET code = (
           SELECT concept_code
           FROM drug_concept_stage dcs
           WHERE mm.name = dcs.concept_name
           )
WHERE mm.flag = 'suppl';

SELECT *
FROM amt_mm;

-- check for source_code validity in amt_mm
SELECT mm.code
FROM amt_mm mm
     LEFT JOIN sources.amt_full_descr_drug_only dscr
     ON dscr.conceptid::text = mm.code
WHERE dscr.conceptid IS NULL
  AND mm.flag <> 'suppl';

-- check for ill-copied concept_ids in amt_mm
SELECT mm.concept_id
FROM amt_mm mm
     LEFT JOIN concept c
     ON c.concept_id = mm.concept_id
WHERE c.concept_id IS NULL;

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


-- fill rtc with rtc_bckp data
TRUNCATE TABLE relationship_to_concept;
INSERT INTO relationship_to_concept
SELECT *
FROM relationship_to_concept_bckp300817;


-- update invalid 'U' concepts in rtc
UPDATE relationship_to_concept rtc
SET concept_id_2 = (
                   SELECT cr.concept_id_2
                   FROM relationship_to_concept rtc2
                        JOIN concept_relationship cr
                        ON rtc2.concept_id_2 = cr.concept_id_1
                   WHERE cr.relationship_id = 'Concept replaced by'
                     AND rtc.concept_code_1 = rtc2.concept_code_1
                   )
WHERE rtc.concept_code_1 IN (
                            SELECT rtc2.concept_code_1
                            FROM relationship_to_concept rtc2
                                 JOIN concept c
                                 ON rtc2.concept_id_2 = c.concept_id
                            WHERE c.invalid_reason = 'U'
                            );

-- get new rtc via union of rtc and mm
-- replace repetitive concepts from each table with mm ones
DROP TABLE IF EXISTS temp_rtc;
CREATE TEMP TABLE temp_rtc AS (
                              SELECT *
                              FROM (
                                   SELECT *
                                   FROM relationship_to_concept rtc
                                   WHERE rtc.concept_code_1 NOT IN (SELECT code FROM amt_mm WHERE code IS NOT NULL)
                                   UNION
                                   SELECT code AS concept_code_1, 'AMT' AS vocabulary_id_1, concept_id AS concept_id_2,
                                          1    AS precedence,
                                          NULL AS conversion_factor
                                   FROM amt_mm
                                   ) tab
                              );

SELECT *
FROM temp_rtc;


-- check for invalid concepts in rtc
SELECT rtc.concept_code_1, dcs.concept_name, dcs.concept_class_id, c.concept_id, c.concept_name, c.invalid_reason
FROM temp_rtc rtc
     LEFT JOIN concept c
     ON rtc.concept_id_2 = c.concept_id
     JOIN drug_concept_stage dcs
     ON dcs.concept_code = rtc.concept_code_1
WHERE c.invalid_reason IS NOT NULL;


-- check for non-standard ingredients in rtc
SELECT rtc.concept_code_1, dcs.concept_name, dcs.concept_class_id, c.concept_name, c.invalid_reason
FROM temp_rtc rtc
     LEFT JOIN concept c
     ON rtc.concept_id_2 = c.concept_id
     JOIN drug_concept_stage dcs
     ON dcs.concept_code = rtc.concept_code_1
WHERE c.concept_class_id = 'Ingredient'
  AND c.standard_concept <> 'S';


-- get total amount dcs unmapped concepts for reference and fun
SELECT *
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
WHERE rtc.concept_code_1 IS NULL
  AND dcs.concept_class_id IN ('Brand Name', 'Ingredient', 'Dose Form', 'Supplier', 'Unit');

-- get unmapped Dose Forms
SELECT *
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
WHERE dcs.concept_class_id = 'Dose Form'
  AND rtc.concept_code_1 IS NULL;

-- get unmapped Units
SELECT *
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
WHERE dcs.concept_class_id = 'Unit'
  AND rtc.concept_code_1 IS NOT NULL;

-- get unmapped Ingredients from dcs with NULL as invalid reason
-- and insert into rtc
INSERT INTO temp_rtc
SELECT dcs.concept_code AS connept_code_1,
       'AMT'            AS vocabulary_id_1,
       c.concept_id     AS concept_id_2,
       1                AS precedence,
       NULL             AS conversion_factor
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
     JOIN concept c
     ON lower(dcs.concept_name) = lower(c.concept_name)
WHERE dcs.concept_class_id = 'Ingredient'
  AND rtc.concept_code_1 IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND c.standard_concept = 'S';

-- get unmapped Ingredients
SELECT *
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
WHERE dcs.concept_class_id = 'Ingredient'
  AND rtc.concept_code_1 IS NULL;


-- get unmapped Suppliers from dcs with NULL as invalid reason
-- and insert into rtc
INSERT INTO temp_rtc
SELECT dcs.concept_code AS connept_code_1,
       'AMT'            AS vocabulary_id_1,
       c.concept_id     AS concept_id_2,
       1                AS precedence,
       NULL             AS conversion_factor
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
     JOIN concept c
     ON lower(dcs.concept_name) = lower(c.concept_name)
WHERE dcs.concept_class_id = 'Supplier'
  AND rtc.concept_code_1 IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND c.invalid_reason IS NULL;

-- get unmapped Suppliers
SELECT *
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
WHERE dcs.concept_class_id = 'Supplier'
  AND rtc.concept_code_1 IS NULL;

-- get unmapped Brand Names from dcs with NULL as invalid reason
-- and insert into rtc
INSERT INTO temp_rtc
SELECT dcs.concept_code AS connept_code_1,
       'AMT'            AS vocabulary_id_1,
       c.concept_id     AS concept_id_2,
       1                AS precedence,
       NULL             AS conversion_factor
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
     JOIN concept c
     ON lower(dcs.concept_name) = lower(c.concept_name)
WHERE dcs.concept_class_id = 'Brand Name'
  AND rtc.concept_code_1 IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND c.invalid_reason IS NULL;

-- get unmapped Brand Names from dcs with 'U' invalid reason
-- and insert into rtc
INSERT INTO temp_rtc
SELECT dcs.concept_code AS connept_code_1,
       'AMT'            AS vocabulary_id_1,
       cr.concept_id_2  AS concept_id_2,
       1                AS precedence,
       NULL             AS conversion_factor
-- select dcs.concept_name, c1.concept_name
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
     JOIN concept c
     ON lower(dcs.concept_name) = lower(c.concept_name)
     JOIN concept_relationship cr
     ON c.concept_id = cr.concept_id_1
JOIN concept c1
on cr.concept_id_2 = c1.concept_id
WHERE dcs.concept_class_id = 'Brand Name'
  AND rtc.concept_code_1 IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND c.invalid_reason = 'U'
  AND cr.relationship_id = 'Concept replaced by';

-- get unmapped Brand Names
SELECT *
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
WHERE dcs.concept_class_id = 'Brand Name'
  AND rtc.concept_code_1 IS NULL;


-- get unmapped concepts again for comparison and export
DROP TABLE IF EXISTS amt_concepts_to_map;
CREATE TABLE amt_concepts_to_map AS
SELECT dcs.concept_code, dcs.concept_name, dcs.concept_class_id
FROM drug_concept_stage dcs
     LEFT JOIN temp_rtc rtc
     ON dcs.concept_code = rtc.concept_code_1
WHERE rtc.concept_code_1 IS NULL
  AND dcs.concept_class_id IN ('Brand Name', 'Ingredient', 'Brand Name', 'Supplier', 'Unit')
ORDER BY concept_class_id;

SELECT *
FROM amt_concepts_to_map;

-- attempt to automap
-- CREATE TABLE table_name_automapped
-- AS (
WITH
    all_concepts AS (
    SELECT DISTINCT a.name, cc.concept_id, a.algorithm
    FROM (
         SELECT concept_name   AS name,
                concept_id     AS concept_id,
                'concept_name' AS algorithm
         FROM devv5.concept c

         UNION ALL

         SELECT concept_synonym_name AS name,
                concept_id           AS concept_id,
                'concept_synonym'    AS algorithm
         FROM devv5.concept_synonym

         UNION ALL

         SELECT source_code          AS name,
                target_concept_id    AS concept_id,
                source_vocabulary_id AS algorithm
         FROM dalex.all_projects_mapping

         UNION ALL

         SELECT source_code_description AS name,
                target_concept_id       AS concept_id,
                source_vocabulary_id    AS algorithm
         FROM dalex.all_projects_mapping

         UNION ALL

         /*             SELECT source_code_description_eng as name,
                             target_concept_id as concept_id,
                             source_vocabulary_id as algorithm
                      FROM dalex.all_projects_mapping

                      UNION ALL */

--Mapping non-standard to standard through concept relationship
         SELECT c.concept_name    AS name,
                cr.concept_id_2   AS concept_id,
                'concept_maps_to' AS algorithm
         FROM devv5.concept c
              JOIN devv5.concept_relationship cr
              ON (cr.concept_id_1 = c.concept_id
                  AND cr.invalid_reason IS NULL AND
                  cr.relationship_id = 'Maps to')
              JOIN devv5.concept cc
              ON (cr.concept_id_2 = cc.concept_id
                  AND cc.standard_concept = 'S' AND cc.invalid_reason IS NULL)
         WHERE c.standard_concept != 'S'
            OR c.standard_concept IS NULL

         UNION ALL

--Mapping non-standard synonym to standard through concept relationship
         SELECT cs.concept_synonym_name   AS name,
                cc.concept_id,
                'concept_synonym_maps_to' AS algorithm
         FROM devv5.concept_synonym cs
              JOIN devv5.concept c
              ON cs.concept_id = c.concept_id
              JOIN devv5.concept_relationship cr
              ON (cs.concept_id = cr.concept_id_1
                  AND cr.relationship_id = 'Maps to' AND
                  cr.invalid_reason IS NULL)
              JOIN devv5.concept cc
              ON (cr.concept_id_2 = cc.concept_id
                  AND cc.standard_concept = 'S' AND cc.invalid_reason IS NULL)
         WHERE c.standard_concept != 'S'
            OR c.standard_concept IS NULL

         ) AS a

         JOIN devv5.concept cc
         ON a.concept_id = cc.concept_id

    WHERE cc.standard_concept = 'S'
      AND cc.invalid_reason IS NULL
      AND cc.domain_id IN ('Route') --domains selection 'Condition', 'Observation'
                    --AND cc.vocabulary_id in ('SNOMED') --vocabularies selection
    )


SELECT DISTINCT concept_name,                 -- Check
                CASE
                    WHEN NOT EXISTS(SELECT 1
                                    FROM amt_concepts_to_map s3
                                         JOIN all_concepts c3
                                         ON trim(s3.concept_name) = trim(c3.name)
                                    WHERE s.concept_name = s3.concept_name)
                        THEN 'Check CASE'
                    ELSE NULL END AS comment, --to check these records manually
                ac.concept_id     AS target_concept_id,
                string_agg(ac.algorithm::varchar, ', ')


FROM amt_concepts_to_map s --source table
     JOIN all_concepts ac
     ON trim(lower(s.concept_name)) = trim(lower(ac.name))


GROUP BY concept_name,
         CASE
             WHEN NOT EXISTS(SELECT 1
                             FROM amt_concepts_to_map s3
                                  JOIN all_concepts c3
                                  ON trim(s3.concept_name) = trim(c3.name)
                             WHERE s.concept_name = s3.concept_name)
                 THEN 'Check CASE'
             ELSE NULL END,
         ac.concept_id
--    );