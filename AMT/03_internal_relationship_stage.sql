DROP TABLE IF EXISTS drug_to_supplier;
CREATE INDEX idx_drug_ccid ON drug_concept_stage (concept_class_id);
ANALYZE drug_concept_stage;

CREATE TABLE drug_to_supplier AS
WITH
    a AS (
    SELECT concept_code, concept_name, initcap(concept_name) init_name
    FROM drug_concept_stage
    WHERE concept_class_id = 'Drug Product'
    )
SELECT DISTINCT a.concept_code, mf.concept_code AS supplier, mf.concept_name AS s_name
FROM a
     JOIN drug_concept_stage mf
     ON substring(init_name, '\(.*\)+') LIKE '%' || mf.concept_name || '%' AND mf.concept_class_id = 'Supplier';

DROP INDEX idx_drug_ccid;
ANALYZE drug_concept_stage;

DROP TABLE IF EXISTS supp_upd;
CREATE TABLE supp_upd AS
SELECT a.concept_code, a.supplier
FROM drug_to_supplier a
     JOIN drug_to_supplier d
     ON d.concept_Code = a.concept_Code
WHERE a.supplier != d.supplier
  AND length(d.s_name) < length(a.s_name);

DELETE
FROM drug_to_supplier
WHERE concept_code IN (SELECT concept_code FROM supp_upd);
INSERT INTO drug_to_supplier (concept_code, supplier)
SELECT concept_code, supplier
FROM supp_upd;

TRUNCATE TABLE internal_relationship_stage;
INSERT INTO internal_relationship_stage (concept_code_1, concept_code_2)

-- drug to ingr
SELECT a.drug_concept_code AS concept_code_1,
       CASE
           WHEN a.ingredient_concept_Code IN (SELECT concept_Code FROM non_S_ing_to_S)
               THEN s_concept_code
           ELSE a.ingredient_concept_code END
                           AS concept_code_2
FROM ds_stage a
     LEFT JOIN non_S_ing_to_S b
     ON a.ingredient_concept_code = b.concept_code

UNION

--drug to supplier
SELECT concept_code, supplier
FROM drug_to_supplier

UNION

--drug to form
SELECT b.concept_Code,
       CASE
           WHEN c.concept_code IN (SELECT concept_Code FROM non_S_form_to_S)
               THEN s_concept_Code
           ELSE c.concept_code END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
     JOIN drug_concept_stage b
     ON a.sourceid::text = b.concept_code
     JOIN drug_concept_stage c
     ON a.destinationid::text = c.concept_code
     LEFT JOIN non_S_form_to_S d
     ON d.concept_code = c.concept_code
WHERE b.concept_class_id = 'Drug Product'
  AND b.concept_name NOT LIKE '%[Drug Pack]'
  AND c.concept_class_id = 'Dose Form'

UNION

SELECT a.sourceid::text, CASE
                             WHEN c.concept_code IN (SELECT concept_Code FROM non_S_form_to_S)
                                 THEN s_concept_Code
                             ELSE c.concept_code END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
     JOIN drug_concept_stage d2
     ON d2.concept_code = a.sourceid::text
     JOIN sources.amt_rf2_full_relationships b
     ON a.destinationid = b.sourceid
     JOIN drug_concept_stage c
     ON b.destinationid::text = c.concept_code
     LEFT JOIN non_S_form_to_S d
     ON d.concept_code = c.concept_code
WHERE c.concept_class_id = 'Dose Form'
  AND a.sourceid::text NOT IN (SELECT concept_code FROM drug_concept_stage WHERE concept_name LIKE '%[Drug Pack]')

--drug to BN
UNION

SELECT b.concept_Code, CASE
                           WHEN c.concept_code IN (SELECT concept_Code FROM non_S_bn_to_S)
                               THEN s_concept_Code
                           ELSE c.concept_code END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
     JOIN drug_concept_stage b
     ON a.sourceid::text = b.concept_code
     JOIN drug_concept_stage c
     ON a.destinationid::text = c.concept_code
     LEFT JOIN non_S_bn_to_S d
     ON d.concept_code = c.concept_code
WHERE b.source_concept_class_id IN ('Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND c.concept_class_id = 'Brand Name'

UNION

SELECT a.sourceid::text, CASE
                             WHEN c.concept_code IN (SELECT concept_Code FROM non_S_bn_to_S)
                                 THEN s_concept_Code
                             ELSE c.concept_code END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
     JOIN drug_concept_stage d2
     ON d2.concept_code = a.sourceid::text
     JOIN sources.amt_rf2_full_relationships b
     ON a.destinationid = b.sourceid
     JOIN drug_concept_stage c
     ON b.destinationid::text = c.concept_code
     LEFT JOIN non_S_bn_to_S d
     ON d.concept_code = c.concept_code
WHERE c.concept_class_id = 'Brand Name'
  AND a.sourceid::text NOT IN (SELECT concept_code FROM drug_concept_stage WHERE concept_name LIKE '%[Drug Pack]')
  AND d2.source_concept_class_id IN ('Trade Product Unit', 'Trade Product Pack', 'Containered Pack')

UNION

--drugs from packs
SELECT DRUG_CONCEPT_CODE, CASE
                              WHEN c.concept_code IN (SELECT concept_Code FROM non_S_bn_to_S)
                                  THEN s_concept_Code
                              ELSE c.concept_code END AS concept_Code_2
FROM pc_stage a
     JOIN internal_relationship_stage b
     ON pack_concept_code = concept_Code_1
     JOIN drug_Concept_stage c
     ON concept_Code_2 = c.concept_Code AND concept_class_id = 'Brand Name'
     LEFT JOIN non_S_bn_to_S d
     ON d.concept_code = c.concept_code
;

--non standard concepts to standard
INSERT INTO internal_relationship_stage
    (concept_code_1, concept_code_2)
SELECT concept_code, s_concept_Code
FROM non_S_ing_to_S
UNION
SELECT concept_code, s_concept_Code
FROM non_S_form_to_S
UNION
SELECT concept_code, s_concept_Code
FROM non_S_bn_to_S;

--fix drugs with 2 forms like capsule and enteric capsule 

DROP TABLE IF EXISTS irs_upd;
CREATE TABLE irs_upd AS
SELECT a.concept_code_1, c.concept_code
FROM internal_relationship_stage a
     JOIN drug_concept_stage b
     ON b.concept_Code = a.concept_Code_2 AND b.concept_Class_id = 'Dose Form'
     JOIN internal_relationship_stage d
     ON d.concept_Code_1 = a.concept_Code_1
     JOIN drug_concept_stage c
     ON c.concept_Code = d.concept_Code_2 AND c.concept_Class_id = 'Dose Form'
WHERE b.concept_code != c.concept_code
  AND length(b.concept_name) < length(c.concept_name);

INSERT INTO irs_upd
SELECT a.concept_code_1, c.concept_code
FROM internal_Relationship_stage a
     JOIN drug_concept_stage b
     ON b.concept_Code = a.concept_Code_2 AND b.concept_Class_id = 'Dose Form'
     JOIN internal_Relationship_stage d
     ON d.concept_Code_1 = a.concept_Code_1
     JOIN drug_concept_stage c
     ON c.concept_Code = d.concept_Code_2 AND c.concept_Class_id = 'Dose Form'
WHERE b.concept_code != c.concept_code
  AND length(b.concept_name) = length(c.concept_name)
  AND b.concept_code < c.concept_code;

--fix those drugs that have 3 simimlar forms (like Tablet,Coated Tablet and Film Coated Tablet)
DROP TABLE IF EXISTS irs_upd_2;
CREATE TABLE irs_upd_2 AS
SELECT a.concept_code_1, a.concept_code
FROM irs_upd a
     JOIN irs_upd b
     ON a.concept_code_1 = b.concept_Code_1
WHERE a.concept_code_1 IN (SELECT concept_code_1 FROM irs_upd GROUP BY concept_code_1, concept_code HAVING count(1) > 1)
  AND a.concept_code > b.concept_code;

DELETE
FROM irs_upd
WHERE concept_code_1 IN (SELECT concept_code_1 FROM irs_upd_2);
INSERT INTO irs_upd
SELECT *
FROM irs_upd_2;

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN
      (
      SELECT a.concept_code
      FROM drug_concept_stage a
           JOIN internal_relationship_stage s
           ON a.concept_code = s.concept_code_1
           JOIN drug_concept_stage b
           ON b.concept_code = s.concept_code_2
               AND b.concept_class_id = 'Dose Form'
      WHERE a.concept_code IN (
                              SELECT a.concept_code
                              FROM drug_concept_stage a
                                   JOIN internal_relationship_stage s
                                   ON a.concept_code = s.concept_code_1
                                   JOIN drug_concept_stage b
                                   ON b.concept_code = s.concept_code_2
                                       AND b.concept_class_id = 'Dose Form'
                              GROUP BY a.concept_code
                              HAVING count(1) > 1
                              )
      )
  AND concept_code_2 IN (SELECT concept_Code FROM drug_concept_stage WHERE concept_class_id = 'Dose Form');

INSERT INTO internal_Relationship_stage (concept_code_1, concept_code_2)
SELECT DISTINCT concept_code_1, concept_code
FROM irs_upd;

DELETE
FROM drug_concept_stage
WHERE concept_code IN ( --dose forms that dont relate to any drug
                      SELECT concept_code
                      FROM drug_concept_stage a
                           LEFT JOIN internal_relationship_stage b
                           ON a.concept_code = b.concept_code_2
                      WHERE a.concept_class_id = 'Dose Form'
                        AND b.concept_code_1 IS NULL
                      )
  AND STANDARD_CONCEPT = 'S';

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (SELECT concept_code FROM non_drug);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = '701581000168103'; --2 BN
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 IN ('770161000168102', '770171000168108', '770191000168109', '770201000168107')
  AND CONCEPT_CODE_2 = '769981000168106';

--estragest,estracombi,estraderm
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = '933225691000036100'
  AND CONCEPT_CODE_2 = '13821000168101';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = '933225691000036100'
  AND CONCEPT_CODE_2 = '4174011000036102';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = '933231511000036106'
  AND CONCEPT_CODE_2 = '13821000168101';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = '933231511000036106'
  AND CONCEPT_CODE_2 = '4174011000036102';