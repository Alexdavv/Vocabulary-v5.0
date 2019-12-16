CREATE TABLE IF NOT EXISTS ingredient_mm
(
    name                 varchar(255),
    new_name             varchar(255),
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
);

TRUNCATE TABLE ingredient_mm;

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

-- insert ingredients into ingredient_mapped from manual_mapping
INSERT INTO ingredient_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT
    name,
    new_name,
    target_concept_id,
    coalesce(precedence, row_number() OVER (PARTITION BY name)),
    'manual_mapping'
FROM ingredient_mm
WHERE target_concept_id IS NOT NULL
  AND target_concept_id NOT IN (17, 0);

-- update drug_concept_stage (set new_names, set standard_concepts)
-- -- set new_names
UPDATE drug_concept_stage dcs
SET concept_name = subquery.new_name
FROM (
     SELECT new_name, name
     FROM ingredient_mm
     WHERE new_name <> ''
     ) AS subquery
WHERE dcs.concept_name = subquery.name;

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