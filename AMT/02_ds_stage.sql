DROP TABLE IF EXISTS ds_0_1_1;
CREATE TABLE ds_0_1_1 AS -- still only MP
SELECT DISTINCT SOURCEID::text    AS drug_concept_code, DESTINATIONID AS ingredient_concept_Code, b.concept_name,
                CASE
                    WHEN lower(a.concept_name) LIKE '%/each%' OR lower(a.concept_name) LIKE '%/application%' OR
                         lower(a.concept_name) LIKE '%/dose%' OR lower(a.concept_name) LIKE '%/square'
                        THEN c.VALUE
                    ELSE NULL END AS amount_value,
                CASE
                    WHEN lower(a.concept_name) LIKE '%/each%' OR lower(a.concept_name) LIKE '%/application%' OR
                         lower(a.concept_name) LIKE '%/dose%' OR lower(a.concept_name) LIKE '%/square'
                        THEN regexp_replace(lower(a.concept_name), '/each|/square|/dose|/application', '', 'gi')
                    ELSE NULL END AS amount_unit,
                CASE
                    WHEN lower(a.concept_name) NOT LIKE '%/each%' AND
                         lower(a.concept_name) NOT LIKE '%/application%' AND
                         lower(a.concept_name) NOT LIKE '%/dose%' AND lower(a.concept_name) NOT LIKE '%/square'
                        THEN VALUE
                    ELSE NULL END AS numerator_value,
                CASE
                    WHEN lower(a.concept_name) NOT LIKE '%/each%' AND
                         lower(a.concept_name) NOT LIKE '%/application%' AND
                         lower(a.concept_name) NOT LIKE '%/dose%' AND lower(a.concept_name) NOT LIKE '%/square'
                        THEN regexp_replace(a.concept_name, '/.*', '', 'g')
                    ELSE NULL END AS numerator_unit,
                CASE
                    WHEN lower(a.concept_name) NOT LIKE '%/each%' AND
                         lower(a.concept_name) NOT LIKE '%/application%' AND
                         lower(a.concept_name) NOT LIKE '%/dose%' AND lower(a.concept_name) NOT LIKE '%/square'
                        THEN replace(substring(a.concept_name, '/.*'), '/', '')
                    ELSE NULL END AS denominator_unit
FROM ds_0 c
     JOIN concept_stage_sn a
     ON a.concept_code = c.UNITID::text
     JOIN drug_concept_stage b
     ON c.SOURCEID::text = b.concept_code
;
UPDATE ds_0_1_1
SET amount_value=NULL,
    amount_unit=NULL
WHERE lower(amount_unit) = 'ml';

DROP TABLE IF EXISTS ds_0_1_3;
CREATE TABLE ds_0_1_3 AS
SELECT c.concept_code AS drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value, amount_unit, numerator_value,
       numerator_unit, denominator_unit, c.concept_name
FROM ds_0_1_1 a
     JOIN sources.amt_rf2_full_relationships b
     ON a.drug_concept_code = destinationid::text
     JOIN drug_concept_stage c
     ON sourceid::text = concept_code
WHERE c.source_concept_class_id IN
      ('Med Product Pack', 'Med Product Unit', 'Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND c.CONCEPT_NAME NOT LIKE '%[Drug Pack]%'
  AND c.concept_code NOT IN (SELECT drug_concept_code FROM ds_0_1_1)
;

DROP TABLE IF EXISTS ds_0_1_4;
CREATE TABLE ds_0_1_4 AS
SELECT c.concept_code AS drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value, amount_unit, numerator_value,
       numerator_unit, denominator_unit, c.concept_name
FROM ds_0_1_1 a
     JOIN sources.amt_rf2_full_relationships b
     ON a.drug_concept_code = destinationid::text
     JOIN sources.amt_rf2_full_relationships b2
     ON b.sourceid = b2.destinationid
     JOIN drug_concept_stage c
     ON b2.sourceid::text = concept_code
WHERE c.source_concept_class_id IN
      ('Med Product Pack', 'Med Product Unit', 'Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND c.CONCEPT_NAME NOT LIKE '%[Drug Pack]%'
;
DELETE
FROM ds_0_1_4
WHERE drug_concept_Code IN (SELECT drug_concept_code FROM ds_0_1_1 UNION SELECT drug_concept_code FROM ds_0_1_3);

DROP TABLE IF EXISTS ds_0_2_0;
CREATE TABLE ds_0_2_0 AS
SELECT DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, CONCEPT_NAME, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE,
       NUMERATOR_UNIT, DENOMINATOR_UNIT
FROM ds_0_1_1
UNION
SELECT DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, CONCEPT_NAME, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE,
       NUMERATOR_UNIT, DENOMINATOR_UNIT
FROM ds_0_1_3
UNION
SELECT DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, CONCEPT_NAME, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE,
       NUMERATOR_UNIT, DENOMINATOR_UNIT
FROM ds_0_1_4
;

DROP TABLE IF EXISTS ds_0_2;
CREATE TABLE ds_0_2 AS
SELECT drug_concept_code, ingredient_concept_code, amount_value, amount_unit, numerator_value, numerator_unit,
       denominator_unit, concept_name,
       substring(concept_name, ',\s[0-9.]+\s(Mg|Ml|G|L|Actuations)')   AS new_denom_unit, --add real volume (, 50 Ml Vial)
       substring(concept_name, ',\s([0-9.]+)\s(Mg|Ml|G|L|Actuations)') AS new_denom_value
FROM ds_0_2_0;

UPDATE ds_0_2
SET new_denom_value=substring(concept_name, ',\s[0-9.]+\sX\s([0-9.]+)\s(Mg|Ml|G|L|Actuations)'),
    new_denom_unit=substring(concept_name, ',\s[0-9.]+\sX\s[0-9.]+\s(Mg|Ml|G|L|Actuations)') --(5 X 50 Ml Vial)
WHERE new_denom_value IS NULL
  AND substring(concept_name, ',\s[0-9.]+\sX\s([0-9.]+)\s(Mg|Ml|G|L|Actuations)') IS NOT NULL;

UPDATE ds_0_2
SET NUMERATOR_VALUE=amount_value,
    NUMERATOR_UNIT=amount_unit,
    amount_unit=NULL,
    amount_value=NULL
WHERE amount_value IS NOT NULL
  AND NEW_DENOM_UNIT IS NOT NULL
  AND NEW_DENOM_UNIT NOT IN ('Mg', 'G');

UPDATE ds_0_2
SET new_denom_value=NULL
WHERE drug_concept_code IN (
                           SELECT concept_code
                           FROM drug_concept_stage
                           WHERE concept_name LIKE '%Oral%' AND concept_name ~ '\s5\sMl$'
                           );

--select distinct * from ds_0_2 where new_denom_unit is not null and denominator_unit is null; 
UPDATE ds_0_2
SET numerator_value=CASE
                        WHEN new_denom_value IS NOT NULL AND (lower(new_denom_unit) = lower(denominator_unit) OR
                                                              (denominator_unit = 'actuation' AND new_denom_unit = 'Actuations'))
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('mg') AND lower(NUMERATOR_UNIT) = 'mg'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT * 1000
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('ml') AND lower(NUMERATOR_UNIT) = 'mg'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('mg') AND lower(NUMERATOR_UNIT) = 'microgram'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT * 1000000
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('ml') AND lower(NUMERATOR_UNIT) = 'microgram'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('mg') AND
                             lower(denominator_unit) IN ('g') AND lower(NUMERATOR_UNIT) = 'mg'
                            THEN (numerator_value::FLOAT * new_denom_value::FLOAT) / 1000
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('ml') AND
                             lower(denominator_unit) IN ('g') AND lower(NUMERATOR_UNIT) = 'mg'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('ml') AND
                             denominator_unit IS NULL
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        ELSE numerator_value::FLOAT END;

UPDATE ds_0_2
SET denominator_unit=new_denom_unit
WHERE new_denom_unit IS NOT NULL
  AND amount_unit IS NULL;


UPDATE ds_0_2
SET amount_value=round(amount_value::numeric, 5),
    numerator_value=round(numerator_value::numeric, 5),
    new_denom_value=round(new_denom_value::numeric, 5);

UPDATE ds_0_2
SET amount_unit=initcap(amount_unit),
    numerator_unit=initcap(numerator_unit),
    denominator_unit=initcap(denominator_unit);

UPDATE ds_0_2
SET new_denom_value=NULL
WHERE DENOMINATOR_UNIT = '24 Hours'
   OR DENOMINATOR_UNIT = '16 Hours';

DROP TABLE IF EXISTS ds_0_3;
CREATE TABLE ds_0_3
AS
SELECT a.*, substring(concept_name, '([0-9]+)\sX\s[0-9]+')::int4 AS box_size
FROM ds_0_2 a;

UPDATE ds_0_3
SET box_size=substring(concept_name, ',\s(\d+)(,\s([^0-9])*)*$')::int4
WHERE amount_value IS NOT NULL
  AND box_size IS NULL;

UPDATE ds_0_3
SET new_denom_value=NULL
WHERE amount_unit IS NOT NULL;

--transform gases dosages into %
UPDATE ds_0_3
SET numerator_value=CASE
                        WHEN denominator_unit IN ('Ml', 'L') AND numerator_unit = 'Ml'
                            THEN numerator_value::float * 100
                        ELSE numerator_value::float END,
    numerator_unit=CASE
                       WHEN denominator_unit IN ('Ml', 'L') AND numerator_unit = 'Ml'
                           THEN '%'
                       ELSE numerator_unit END,
    denominator_unit=CASE WHEN new_denom_value IS NOT NULL THEN denominator_unit ELSE NULL END
WHERE concept_name LIKE '% Gas%';

TRUNCATE TABLE ds_stage;
INSERT INTO ds_stage --add box size
(DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, BOX_SIZE, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE, NUMERATOR_UNIT,
 DENOMINATOR_VALUE, DENOMINATOR_UNIT)
SELECT DISTINCT drug_concept_code, INGREDIENT_CONCEPT_CODE, box_size, amount_value::float, amount_unit,
                numerator_value::float, numerator_unit, new_denom_value::float, denominator_unit
FROM ds_0_3;

UPDATE DS_STAGE
SET AMOUNT_VALUE = NULL,
    AMOUNT_UNIT  = NULL
WHERE DRUG_CONCEPT_CODE = '80146011000036104';
UPDATE DS_STAGE
SET AMOUNT_VALUE = NULL,
    AMOUNT_UNIT  = NULL
WHERE DRUG_CONCEPT_CODE = '81257011000036108';

INSERT INTO ds_stage (DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE) -- add drugs that don't have dosages
SELECT DISTINCT a.sourceid, a.destinationid
FROM sources.amt_rf2_full_relationships a
     JOIN drug_concept_stage b
     ON b.concept_code = a.sourceid::text
     JOIN drug_concept_stage c
     ON c.concept_code = a.destinationid::text
WHERE b.concept_class_id = 'Drug Product'
  AND c.concept_class_id = 'Ingredient'
  AND sourceid::text NOT IN (SELECT drug_concept_code FROM ds_stage)
  AND sourceid::text NOT IN (SELECT pack_concept_code FROM pc_stage);

INSERT INTO ds_stage (DRUG_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE)
SELECT DISTINCT a.sourceid, d.destinationid
FROM sources.amt_rf2_full_relationships a
     JOIN drug_concept_stage b
     ON b.concept_code = a.sourceid::text
     JOIN sources.amt_rf2_full_relationships d
     ON d.sourceid = a.destinationid
     JOIN drug_concept_stage c
     ON c.concept_code = d.destinationid::text
WHERE b.concept_class_id = 'Drug Product'
  AND c.concept_class_id = 'Ingredient'
  AND a.sourceid::text NOT IN (SELECT drug_concept_code FROM ds_stage)
  AND b.concept_name NOT LIKE '%Drug Pack%';

UPDATE ds_stage
SET numerator_unit='Mg',
    numerator_value=numerator_value / 1000
WHERE drug_concept_code IN
      (
      SELECT DISTINCT a.drug_concept_code
      FROM (
           SELECT DISTINCT a.amount_unit, a.numerator_unit, cs.concept_code, cs.concept_name AS canada_name,
                           rc.concept_name                                                   AS RxName,
                           a.drug_concept_code
           FROM ds_stage a
                JOIN relationship_to_concept b
                ON a.ingredient_concept_code = b.concept_code_1
                JOIN drug_concept_stage cs
                ON cs.concept_code = a.ingredient_concept_code
                JOIN devv5.concept rc
                ON rc.concept_id = b.concept_id_2
                JOIN drug_concept_stage rd
                ON rd.concept_code = a.drug_concept_code
                JOIN (
                     SELECT a.drug_concept_code, b.concept_id_2
                     FROM ds_stage a
                          JOIN relationship_to_concept b
                          ON a.ingredient_concept_code = b.concept_code_1
                     GROUP BY a.drug_concept_code, b.concept_id_2
                     HAVING count(1) > 1
                     ) c
                ON c.drug_concept_code = a.drug_concept_code AND c.concept_id_2 = b.concept_id_2
           WHERE precedence = 1
           ) a
           JOIN
               (
               SELECT DISTINCT a.amount_unit, a.numerator_unit, cs.concept_name AS canada_name,
                               rc.concept_name                                  AS RxName, a.drug_concept_code
               FROM ds_stage a
                    JOIN relationship_to_concept b
                    ON a.ingredient_concept_code = b.concept_code_1
                    JOIN drug_concept_stage cs
                    ON cs.concept_code = a.ingredient_concept_code
                    JOIN devv5.concept rc
                    ON rc.concept_id = b.concept_id_2
                    JOIN drug_concept_stage rd
                    ON rd.concept_code = a.drug_concept_code
                    JOIN (
                         SELECT a.drug_concept_code, b.concept_id_2
                         FROM ds_stage a
                              JOIN relationship_to_concept b
                              ON a.ingredient_concept_code = b.concept_code_1
                         GROUP BY a.drug_concept_code, b.concept_id_2
                         HAVING count(1) > 1
                         ) c
                    ON c.drug_concept_code = a.drug_concept_code AND c.concept_id_2 = b.concept_id_2
               WHERE precedence = 1
               ) b
           ON a.RxName = b.RxName AND a.drug_concept_code = b.drug_concept_code AND
              (a.amount_unit != b.amount_unit OR a.numerator_unit != b.numerator_unit OR
               a.numerator_unit IS NULL AND b.numerator_unit IS NOT NULL
                  OR a.amount_unit IS NULL AND b.amount_unit IS NOT NULL)
      )
  AND numerator_unit = 'Microgram';

UPDATE ds_stage
SET numerator_value=numerator_value / 1000,
    numerator_unit='Mg'
WHERE numerator_unit = 'Microgram'
  AND numerator_value > 999;
UPDATE ds_stage
SET amount_value=amount_value / 1000,
    amount_unit='Mg'
WHERE amount_unit = 'Microgram'
  AND amount_value > 999;

UPDATE ds_stage
SET DENOMINATOR_VALUE=NULL,
    NUMERATOR_VALUE=NUMERATOR_VALUE / 5
WHERE DRUG_CONCEPT_CODE IN
      (
      SELECT DRUG_CONCEPT_CODE
      FROM ds_stage a
           JOIN drug_concept_stage
           ON drug_concept_code = concept_code
      WHERE DENOMINATOR_VALUE = '5'
        AND concept_name LIKE '%Oral%Measure%'
      );

UPDATE ds_stage
SET DENOMINATOR_UNIT='Actuation'
WHERE DENOMINATOR_UNIT = 'Actuations';
UPDATE ds_stage
SET DENOMINATOR_UNIT='Ml',
    DENOMINATOR_VALUE=DENOMINATOR_VALUE * 1000
WHERE DENOMINATOR_UNIT = 'L'
  AND drug_concept_code NOT IN
      (
      SELECT SOURCEID::text
      FROM sources.amt_rf2_full_relationships a
      WHERE DESTINATIONID IN (122011000036104, 187011000036109)
      );

UPDATE ds_stage a
SET ingredient_concept_code=(SELECT s_concept_code FROM non_S_ing_to_S WHERE CONCEPT_CODE = ingredient_concept_code)
WHERE ingredient_concept_code IN (SELECT CONCEPT_CODE FROM non_S_ing_to_S);

UPDATE ds_stage --fix patches
SET denominator_unit='Hour',
    denominator_value=24
WHERE denominator_unit = '24 Hours';
UPDATE ds_stage
SET denominator_unit='Hour',
    denominator_value=16
WHERE denominator_unit = '16 Hours';

DROP TABLE IF EXISTS ds_sum;
CREATE TABLE ds_sum AS
SELECT DISTINCT drug_concept_code, ingredient_concept_code, BOX_SIZE,
                sum(amount_value) AS amount_value,
                amount_unit, numerator_value, numerator_unit, denominator_value, denominator_unit
FROM ds_stage
GROUP BY drug_concept_code, ingredient_concept_code, box_size, amount_unit, numerator_value, numerator_unit,
         denominator_value, denominator_unit
;

TRUNCATE TABLE ds_stage;
INSERT INTO ds_stage
SELECT *
FROM ds_sum;

--Movicol
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 8000,
    NUMERATOR_UNIT    = 'Unit',
    DENOMINATOR_VALUE = 20,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '94311000036106'
  AND INGREDIENT_CONCEPT_CODE = '1981011000036104';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 8000,
    NUMERATOR_UNIT    = 'Unit',
    DENOMINATOR_VALUE = 20,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '94321000036104'
  AND INGREDIENT_CONCEPT_CODE = '1981011000036104';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 100000,
    NUMERATOR_UNIT    = 'Unit',
    DENOMINATOR_VALUE = 50,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '94331000036102'
  AND INGREDIENT_CONCEPT_CODE = '1981011000036104';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 100000,
    NUMERATOR_UNIT    = 'Unit',
    DENOMINATOR_VALUE = 50,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '94341000036107'
  AND INGREDIENT_CONCEPT_CODE = '1981011000036104';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 46.6,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652501000168101'
  AND INGREDIENT_CONCEPT_CODE = '2500011000036101';
UPDATE DS_STAGE
SET NUMERATOR_VALUE  = 46.6,
    NUMERATOR_UNIT   = 'Mg',
    DENOMINATOR_UNIT = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652511000168103'
  AND INGREDIENT_CONCEPT_CODE = '2500011000036101';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 932,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 500,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652521000168105'
  AND INGREDIENT_CONCEPT_CODE = '2500011000036101';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 350.7,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652501000168101'
  AND INGREDIENT_CONCEPT_CODE = '2591011000036106';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 350.7,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652511000168103'
  AND INGREDIENT_CONCEPT_CODE = '2591011000036106';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 7014,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 500,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652521000168105'
  AND INGREDIENT_CONCEPT_CODE = '2591011000036106';
UPDATE DS_STAGE
SET DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652501000168101'
  AND INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE
SET DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652511000168103'
  AND INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE
SET DENOMINATOR_VALUE = 500,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652521000168105'
  AND INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 178.5,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652501000168101'
  AND INGREDIENT_CONCEPT_CODE = '2736011000036107';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 178.5,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652511000168103'
  AND INGREDIENT_CONCEPT_CODE = '2736011000036107';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 3570,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 500,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652521000168105'
  AND INGREDIENT_CONCEPT_CODE = '2736011000036107';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 13125,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652501000168101'
  AND INGREDIENT_CONCEPT_CODE = '2799011000036106';
UPDATE DS_STAGE
SET NUMERATOR_VALUE   = 13125,
    NUMERATOR_UNIT    = 'Mg',
    DENOMINATOR_VALUE = 25,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652511000168103'
  AND INGREDIENT_CONCEPT_CODE = '2799011000036106';
UPDATE DS_STAGE
SET AMOUNT_UNIT       = '',
    NUMERATOR_VALUE   = 262.5,
    NUMERATOR_UNIT    = 'G',
    DENOMINATOR_VALUE = 500,
    DENOMINATOR_UNIT  = 'Ml'
WHERE DRUG_CONCEPT_CODE = '652521000168105'
  AND INGREDIENT_CONCEPT_CODE = '2799011000036106';

--inserting Inert Tablets with '0' in amount
INSERT INTO ds_stage (drug_concept_code, ingredient_concept_code, amount_value, amount_unit)
SELECT concept_code, '920012011000036105', '0', 'Mg'
FROM drug_concept_stage
WHERE concept_name LIKE '%Inert%'
  AND concept_name NOT LIKE '%Drug Pack%'
  AND concept_class_id = 'Drug Product';

--bicarbonate
DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE IN ('652521000168105', '652501000168101', '652511000168103')
  AND INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE
SET DENOMINATOR_VALUE = 25
WHERE DRUG_CONCEPT_CODE = '652511000168103'
  AND INGREDIENT_CONCEPT_CODE = '2500011000036101';

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT concept_code FROM non_drug);
