DO
$body$
    BEGIN
        EXECUTE format('create table %I as select * from relationship_to_concept',
                       'relationship_to_concept_backup_' || to_char(current_date, 'yyyymmdd'));
    END
$body$;



DROP TABLE ingredient_mapped;

CREATE TABLE ingredient_mapped AS
SELECT DISTINCT dcs.concept_name,
                NULL                                        AS new_name,
                c.concept_id                                AS concept_id_2,
                c.concept_name                              AS concept_name_2,
                rank() OVER (PARTITION BY dcs.concept_code
                    ORDER BY c.vocabulary_id, c.concept_id) AS precedence
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

INSERT INTO ingredient_mapped
SELECT DISTINCT dcs.concept_name,
                NULL                                          AS new_name,
                cc.concept_id                                 AS concept_id_2,
                cc.concept_name                               AS concept_name_2,
                rank() OVER (PARTITION BY dcs.concept_code
                    ORDER BY cc.vocabulary_id, cc.concept_id) AS precedence
FROM drug_concept_stage dcs
     JOIN concept c
     ON lower(c.concept_name) = lower(dcs.concept_name)
         AND c.concept_class_id = 'Precise Ingredient'
         AND c.vocabulary_id LIKE 'RxNorm%'
         AND (c.standard_concept IS NULL OR c.invalid_reason IS NOT NULL)
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
  AND NOT EXISTS(SELECT 1
                 FROM ingredient_mapped im
                 WHERE lower(dcs.concept_name) = lower(im.concept_name)
    );


-- update invalid concepts via "Maps to" relationship
INSERT INTO ingredient_mapped
SELECT DISTINCT dcs.concept_name,
                NULL                                          AS new_name,
                cc.concept_id                                 AS concept_id_2,
                cc.concept_name                               AS concept_name_2,
                rank() OVER (PARTITION BY dcs.concept_code
                    ORDER BY cc.vocabulary_id, cc.concept_id) AS precedence
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
  AND NOT EXISTS(SELECT 1
                 FROM ingredient_mapped im
                 WHERE lower(dcs.concept_name) = lower(im.concept_name)
    )
;

