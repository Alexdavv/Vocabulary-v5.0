/*
update drug_concept_stage set concept_name='Independent Pharmacy Cooperative' where concept_name='Ipc';
update drug_concept_stage set concept_name='Sun Pharmaceutical' where concept_name='Sun';
update drug_concept_stage set concept_name='Boucher & Muir Pty Ltd' where concept_name='Bnm';
update drug_concept_stage set concept_name='Pharma GXP' where concept_name='Gxp';
update drug_concept_stage set concept_name='Douglas Pharmaceuticals' where concept_name='Douglas';
update drug_concept_stage set concept_name='FBM-PHARMA' where concept_name='Fbm';
update drug_concept_stage set concept_name='DRX Pharmaceutical Consultants' where concept_name='Drx';
update drug_concept_stage set concept_name='Saudi pharmaceutical' where concept_name='Sau';
update drug_concept_stage set concept_name='FBM-PHARMA' where concept_name='Fbm';
*/

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
                      SELECT a.concept_code
                      FROM drug_concept_stage a
                           LEFT JOIN internal_relationship_stage b
                           ON a.concept_code = b.concept_code_2
                      WHERE a.concept_class_id = 'Brand Name'
                        AND b.concept_code_1 IS NULL
                      UNION ALL
                      SELECT a.concept_code
                      FROM drug_concept_stage a
                           LEFT JOIN internal_relationship_stage b
                           ON a.concept_code = b.concept_code_2
                      WHERE a.concept_class_id = 'Dose Form'
                        AND b.concept_code_1 IS NULL
                      );

--updating ingredients that create duplicates after mapping to RxNorm
DROP TABLE IF EXISTS ds_sum_2;
CREATE TABLE ds_sum_2 AS
WITH
    a AS (
    SELECT DISTINCT ds.drug_concept_code, ds.ingredient_concept_code, ds.box_size, ds.AMOUNT_VALUE, ds.AMOUNT_UNIT,
                    ds.NUMERATOR_VALUE, ds.NUMERATOR_UNIT, ds.DENOMINATOR_VALUE, ds.DENOMINATOR_UNIT, rc.concept_id_2
    FROM ds_stage ds
         JOIN ds_stage ds2
         ON ds.drug_concept_code = ds2.drug_concept_code AND ds.ingredient_concept_code != ds2.ingredient_concept_code
         JOIN relationship_to_concept rc
         ON ds.ingredient_concept_code = rc.concept_code_1
         JOIN relationship_to_concept rc2
         ON ds2.ingredient_concept_code = rc2.concept_code_1
    WHERE rc.concept_id_2 = rc2.concept_id_2
    )
SELECT DISTINCT DRUG_CONCEPT_CODE, max(INGREDIENT_CONCEPT_CODE)
                                   OVER (PARTITION BY DRUG_CONCEPT_CODE,concept_id_2)   AS ingredient_concept_code,
                box_size,
                sum(AMOUNT_VALUE) OVER (PARTITION BY DRUG_CONCEPT_CODE)                 AS AMOUNT_VALUE, AMOUNT_UNIT,
                sum(NUMERATOR_VALUE) OVER (PARTITION BY DRUG_CONCEPT_CODE,concept_id_2) AS NUMERATOR_VALUE,
                NUMERATOR_UNIT, DENOMINATOR_VALUE, DENOMINATOR_UNIT
FROM a
UNION
SELECT DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, box_size, NULL AS AMOUNT_VALUE, NULL AS AMOUNT_UNIT,
       NULL                                                       AS NUMERATOR_VALUE, NULL AS NUMERATOR_UNIT,
       NULL                                                       AS DENOMINATOR_VALUE, NULL AS DENOMINATOR_UNIT
FROM a
WHERE (drug_concept_code, ingredient_concept_code)
          NOT IN (SELECT drug_concept_code, max(ingredient_concept_code) FROM a GROUP BY drug_concept_code);

DELETE
FROM ds_stage
WHERE (drug_concept_code, ingredient_concept_code) IN
      (SELECT drug_concept_code, ingredient_concept_code FROM ds_sum_2);

INSERT INTO DS_STAGE (DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, BOX_SIZE, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE,
                      NUMERATOR_UNIT, DENOMINATOR_VALUE, DENOMINATOR_UNIT)
SELECT DISTINCT DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, BOX_SIZE, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE,
                NUMERATOR_UNIT, DENOMINATOR_VALUE, DENOMINATOR_UNIT
FROM DS_SUM_2
WHERE coalesce(AMOUNT_VALUE, NUMERATOR_VALUE) IS NOT NULL;

--delete relationship to ingredients that we removed
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1, concept_code_2) IN (
                                          SELECT drug_concept_code, ingredient_concept_code
                                          FROM ds_sum_2
                                          WHERE coalesce(AMOUNT_VALUE, NUMERATOR_VALUE) IS NULL
                                          );

--deleting drug forms 
DELETE
FROM ds_stage
WHERE drug_concept_code IN
      (SELECT drug_concept_code FROM ds_stage WHERE COALESCE(amount_value, numerator_value, 0) = 0);

--add water
INSERT INTO ds_stage (drug_concept_code, ingredient_concept_code, numerator_value, numerator_unit, denominator_unit)
SELECT concept_code, '11295', 1000, 'Mg', 'Ml'
FROM drug_concept_stage dcs
     JOIN (
          SELECT concept_code_1
          FROM internal_relationship_stage
               JOIN drug_concept_stage
               ON concept_code_2 = concept_code AND concept_class_id = 'Supplier'
               LEFT JOIN ds_stage
               ON drug_concept_code = concept_code_1
          WHERE drug_concept_code IS NULL
          UNION
          SELECT concept_code_1
          FROM internal_relationship_stage
               JOIN drug_concept_stage
               ON concept_code_2 = concept_code AND concept_class_id = 'Supplier'
          WHERE concept_code_1 NOT IN (
                                      SELECT concept_code_1
                                      FROM internal_relationship_stage
                                           JOIN drug_concept_stage
                                           ON concept_code_2 = concept_code AND concept_class_id = 'Dose Form'
                                      )
          ) s
     ON s.concept_code_1 = dcs.concept_code
WHERE dcs.concept_class_id = 'Drug Product'
  AND invalid_reason IS NULL
  AND concept_name LIKE 'Water%';

INSERT INTO internal_relationship_stage
    (concept_code_1, concept_code_2)
SELECT DISTINCT drug_concept_code, ingredient_concept_code
FROM ds_stage
WHERE (drug_concept_code, ingredient_concept_code) NOT IN
      (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
