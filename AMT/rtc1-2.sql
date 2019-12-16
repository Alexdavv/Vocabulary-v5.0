DROP TABLE IF EXISTS ingredient_mm;

CREATE TABLE IF NOT EXISTS ingredient_mm
(
    name                 varchar(255) NOT NULL,
    constraint chk_name
            check ((name)::text <> ''::text),
    new_name             varchar(255),
    constraint chk_new_name
            check ((new_name)::text <> ''::text),
    comment              varchar(255),
    precedence           int,
    target_concept_id    int,
    concept_code         varchar(50),
    concept_name         varchar(255),
    concept_class_id     varchar(20),
    standard_concept     varchar(20),
    invalid_reason       varchar(20),
    domain_id            varchar(20),
    target_vocabulary_id varchar(20)
) WITH OIDS;

--todo check mm mapping consistancy (target id-name, if >1 string group by name precedence should be filled), such a name is not in the _mapped table;

--check if target concepts exist in the concept table
SELECT *
FROM ingredient_mm j1
WHERE NOT EXISTS (  SELECT *
                    FROM ingredient_mm j2
                    JOIN concept c
                        ON j2.target_concept_id = c.concept_id
                            AND c.concept_name = j2.concept_name
                            AND c.vocabulary_id = j2.target_vocabulary_id
                            AND c.domain_id = j2.domain_id
                            AND c.standard_concept = 'S'
                            AND c.invalid_reason is NULL
                    WHERE j1.OID = j2.OID
                  )
    AND target_concept_id NOT IN (0, 17)
    AND target_concept_id IS NOT NULL
;








CREATE TEMP TABLE non_drug_ingredients AS
SELECT dcs2.concept_code
FROM ingredient_mm im
JOIN drug_concept_stage dcs1
    ON im.name = dcs1.concept_name
JOIN internal_relationship_stage irs
    ON dcs1.concept_code = irs.concept_code_2
JOIN drug_concept_stage dcs2
    ON irs.concept_code_1 = dcs2.concept_code
WHERE im.target_concept_id = 17;

-- place to non-drugs drug_products from manual mapping where ingredient target_id = 17
INSERT INTO non_drug
SELECT *
FROM concept_stage_sn sn
WHERE sn.concept_code IN (
                         SELECT *
                         FROM non_drug_ingredients
                         );

-- delete non_drugs from dcs which ingredients have been discovered in manual mapping
DELETE
FROM drug_concept_stage dcs
WHERE dcs.concept_code IN (
                          SELECT *
                          FROM non_drug_ingredients
                          );

-- delete non-drugs from ds_stage (ingredients)
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
                           SELECT *
                           FROM non_drug_ingredients
                           );


--delete non-drugs from irs
DELETE
FROM internal_relationship_stage irs
WHERE irs.concept_code_2 IN (
                            SELECT dcs.concept_code
                            FROM ingredient_mm im
                            JOIN drug_concept_stage dcs
                                ON im.name = dcs.concept_name
                            WHERE im.target_concept_id = 17
                            );


--delete non-drugs from pc_stage?
DELETE
FROM pc_stage
WHERE drug_concept_code IN (
                           SELECT *
                           FROM non_drug_ingredients
                           );
SELECT * FROM ingredient_mm;

-- insert ingredients into ingredient_mapped from manual_mapping
INSERT INTO ingredient_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    new_name,
    target_concept_id,
    coalesce(precedence, 1),
    'manual_mapping'
FROM ingredient_mm
--WHERE target_concept_id IS NOT NULL
--  AND target_concept_id NOT IN (17, 0)
;


-- update drug_concept_stage (set new_names, set standard_concepts)
-- -- set new_names
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM ingredient_mapped
     WHERE new_name IS NOT NULL
     ) AS names
WHERE dcs.concept_name = names.name
;

--todo delete
-- -- set standard concepts ???
-- -- -- set NULL for all standard concepts for multiple ingredients in manual mapping
WITH to_be_updated AS (
                      SELECT *
                      FROM drug_concept_stage dcs2
                      WHERE dcs2.concept_class_id = 'Ingredient'
                        AND dcs2.concept_name IN (
                                                 SELECT concept_name
                                                 FROM drug_concept_stage
                                                 GROUP BY concept_name
                                                 HAVING count(concept_name) > 1
                                                 ORDER BY concept_name
--                                                  SELECT DISTINCT new_name
--                                                  FROM ingredient_mm
--                                                  WHERE new_name <> ''
                                                 )
                      )
UPDATE drug_concept_stage dcs
SET standard_concept = NULL
FROM to_be_updated
WHERE dcs.concept_name = to_be_updated.concept_name;


-- -- -- set min concept_code for multiple ingredients to 'S'
WITH to_be_updated AS (
                      SELECT *
                      FROM drug_concept_stage dcs
                      WHERE dcs.concept_class_id = 'Ingredient'
                        AND dcs.concept_name IN (
--                                                 SELECT concept_name
--                                                 FROM drug_concept_stage
--                                                 GROUP BY concept_name
--                                                 HAVING count(concept_name) > 1
--                                                 ORDER BY concept_name
                                                SELECT DISTINCT new_name
                                                FROM ingredient_mm
                                                WHERE new_name <> ''
                                                )
                        AND dcs.concept_code IN (
                                                SELECT
                                                            FIRST_VALUE(concept_code)
                                                            OVER (PARTITION BY concept_name
                                                                ORDER BY concept_code)
                                                FROM drug_concept_stage
                                                )
                      )
UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
FROM to_be_updated
WHERE dcs.concept_code = to_be_updated.concept_code;
;

-- -- update irs. Set all non-standard concept_codes for ingredients in concept_code_2 to standard.
WITH to_be_updated AS (
                      SELECT *
                      FROM drug_concept_stage dcs
                      WHERE concept_class_id = 'Ingredient'
                        AND dcs.concept_name IN (
--                                                 SELECT DISTINCT new_name
--                                                 FROM ingredient_mm
--                                                 WHERE new_name <> ''
                                                SELECT concept_name
                                                FROM drug_concept_stage
                                                GROUP BY concept_name
                                                HAVING count(concept_name) > 1
                                                ORDER BY concept_name
                                                )
                      )
UPDATE internal_relationship_stage irs
SET concept_code_2 = (
                     SELECT *
                     FROM to_be_updated tbu
                     JOIN to_be_updated tbu_2
                         ON tbu.concept_name = tbu_2.concept_name
                     WHERE tbu_2.standard_concept = 'S'
                       AND irs.concept_code_2 = tbu.concept_code
                     );

-- delete from dcs where target_concept is 0
SELECT *
FROM ingredient_mm im
WHERE im.target_concept_id = 0;


-- update irs for deleted
-------------------------------------------------------------------

SELECT *
FROM internal_relationship_stage irs
WHERE irs.concept_code_2 = '2695011000036100';