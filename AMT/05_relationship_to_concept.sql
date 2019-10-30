TRUNCATE TABLE relationship_to_concept;
--insert into relationship_to_concept mappings from previos run
--update existing relationship to concept (Timur)

--delete deprecated concepts (mainly wrong BN)
DELETE
FROM drug_concept_stage
WHERE concept_code IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
           JOIN concept c
           ON concept_id_2 = c.concept_id
               AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND c.vocabulary_id = 'RxNorm Extension'
               AND concept_id_2 NOT IN (43252204, 43252218)
      );

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
           JOIN concept c
           ON concept_id_2 = c.concept_id
               AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND c.vocabulary_id = 'RxNorm Extension'
               AND concept_id_2 NOT IN (43252204, 43252218)
      );

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
                        SELECT concept_code_1
                        FROM relationship_to_concept
                             JOIN concept c
                             ON concept_id_2 = c.concept_id
                                 AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND
                                c.vocabulary_id = 'RxNorm Extension'
                                 AND concept_id_2 NOT IN (43252204, 43252218)
                        );

--give Medical Coders list of unmapped concepts
-- 1. deprecated concepts                       
SELECT *
FROM relationship_to_concept
     JOIN concept
     ON concept_id = concept_id_2
WHERE invalid_reason IS NOT NULL
;
-- 2. Review and map new concepts
SELECT *
FROM drug_concept_stage
WHERE concept_class_id NOT IN ('Drug Product', 'Device')
  AND concept_code NOT IN (SELECT concept_code_1 FROM relationship_to_concept);
