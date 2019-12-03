--1. Ingredient
--TEMPORARY SCRIPT

DROP TABLE IF EXISTS ingredient_mapped;
CREATE TABLE IF NOT EXISTS ingredient_mapped
(
    name varchar(255),
    new_name     varchar(255),
    concept_id_2 integer,
    precedence   integer,
    mapping_type varchar(50)
);

--population of ingredient_mapped from rtc backup
WITH rtc AS (SELECT DISTINCT * FROM relationship_to_concept_bckp300817)

INSERT INTO ingredient_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT dcs.concept_name,
                NULL,
                c.concept_id,
                rtc.precedence,
                'rtc_backup' AS mapping_type
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
                              HAVING COUNT(DISTINCT c.concept_id) > 1
                              )
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


-- insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                c.concept_id, --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
     JOIN concept c
     ON lower(c.concept_name) = lower(dcs.concept_name)
         AND c.concept_class_id = 'Ingredient'
         AND c.vocabulary_id LIKE 'RxNorm%'
         AND c.invalid_reason IS NULL
         AND c.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert auto-mapping into rtc by Precise Ingredient name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id, --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_precise_ing_name_match' AS mapping_type
FROM drug_concept_stage dcs
     JOIN concept c
     ON lower(c.concept_name) = lower(dcs.concept_name)
         AND c.concept_class_id = 'Precise Ingredient'
         AND c.vocabulary_id LIKE 'RxNorm%'
         AND c.invalid_reason IS NULL
     JOIN concept_relationship cr
     ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL
     JOIN concept cc
     ON cr.concept_id_2 = cc.concept_id
         AND cc.concept_class_id = 'Ingredient'
         AND cc.vocabulary_id LIKE 'RxNorm%'
         AND cc.invalid_reason IS NULL
         AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert mapping into rtc by concept_name match throught U/D ingredients and 'Maps to' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id, --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id),
                NULL::double precision,
                'am_U/D_name_match + link to Valid' AS mapping_type
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
         AND cc.invalid_reason IS NULL
         AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
  AND dcs.concept_name NOT IN ('Rhamnus Frangula', 'Polylactic Acid')
;

--TODO: Is 'Polylactic Acid' Drud? If not, delete as AMT ingredient?

-- update 'U/D' in ingredient_mapped
WITH to_be_updated AS (
SELECT DISTINCT im.name,
                im.concept_id_2 AS concept_id_2,
                c2.concept_id   AS new_concept_id_2,
                c2.concept_name AS new_concept_name_2
FROM ingredient_mapped im
JOIN concept c1
         ON im.concept_id_2 = c1.concept_id
                AND c1.invalid_reason IN ('U', 'D')
JOIN concept_relationship cr
         ON cr.concept_id_1 = c1.concept_id
                AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
JOIN concept c2
         ON c2.concept_id = cr.concept_id_2
                AND c2.concept_class_id = 'Ingredient'
                AND c2.vocabulary_id LIKE 'RxNorm%'
                AND c2.invalid_reason IS NULL
                AND c2.standard_concept = 'S'
WHERE
--excluding names mapped to > 1 concept
    im.name NOT IN (
                                     SELECT im2.name
                                     FROM ingredient_mapped im2
                                     GROUP BY im2.name
                                     HAVING count(*) > 1
                                     )
    )

UPDATE ingredient_mapped im
SET concept_id_2  = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE im.name = to_be_updated.name;

--TODO: Polylactic Acid, Rhamnus Frangula


--delete from ingredient mapped if target concept is still U/D
WITH to_be_deleted AS (
    SELECT *
    FROM ingredient_mapped
    WHERE concept_id_2 IN (
                          SELECT concept_id
                          FROM concept
                          WHERE invalid_reason IS NOT NULL
                          )
    )
DELETE
FROM ingredient_mapped
WHERE name IN (SELECT name FROM to_be_deleted)
;


DROP TABLE IF EXISTS ingredient_to_map;

--ingredients to_map
CREATE TABLE IF NOT EXISTS ingredient_to_map AS
SELECT DISTINCT dcs.concept_name AS name,
                '' AS new_name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Ingredient'
  AND dcs.concept_code NOT IN (SELECT DISTINCT concept_code_1 FROM relationship_to_concept)
  AND dcs.concept_name NOT IN (SELECT DISTINCT name FROM ingredient_mapped)
ORDER BY dcs.concept_name
;

SELECT *
FROM ingredient_to_map
ORDER BY name;


--CHECKS
-- get mapping for review
with automapped as (
SELECT DISTINCT dcs.concept_name AS name, c.concept_id, c.concept_name, rtc.mapping_type
FROM relationship_to_concept rtc
JOIN drug_concept_stage dcs
     ON dcs.concept_code = rtc.concept_code_1
JOIN concept c
     ON rtc.concept_id_2 = c.concept_id
),

ingredient_mapped AS (
SELECT DISTINCT im.name AS name, c.concept_id, c.concept_name, im.mapping_type
FROM ingredient_mapped im
JOIN concept c
     ON c.concept_id = im.concept_id_2
)

SELECT * FROM automapped

UNION ALL

SELECT * FROM ingredient_mapped
WHERE name NOT IN (SELECT name FROM automapped)

ORDER BY mapping_type;


--check inserted mapping with precedence > 1
SELECT *
FROM ingredient_mapped im
     JOIN devv5.concept c
     ON im.concept_id_2 = c.concept_id

WHERE im.name IN
      (
      SELECT im.name
      FROM ingredient_mapped im
      GROUP BY im.name
      HAVING COUNT(*) > 1
      )
;
