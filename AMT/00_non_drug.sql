DROP TABLE IF EXISTS non_drug;
CREATE TABLE non_drug AS
SELECT *
FROM concept_stage_sn
WHERE concept_name ~*
      'dialysis|mma/pa|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement|containing| rope|procal|glytactin|gauze|keyomega|cystine|docomega|anamix|xlys|xmtvi |pku |tyr |msud |hcu |eaa |cranberry|pedialyte|msud|hydralyte|hcu cooler|pouch|burger|biscuits|wipes|kilocalories|cake|roll|adhesive|milk|dessert'
  AND concept_class_id IN ('AU Substance', 'AU Qualifier', 'Med Product Unit', 'Med Product Pack', 'Medicinal Product',
                           'Trade Product Pack', 'Trade Product', 'Trade Product Unit', 'Containered Pack')
  AND concept_name NOT LIKE '%Panadol%'
  AND concept_name NOT LIKE '%ointment%'
  AND concept_name NOT LIKE '%Scotch pine%';

INSERT INTO non_drug
SELECT *
FROM concept_stage_sn
WHERE concept_name ~*
      'juice|gluten|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|artificial saliva|cylinder|bq |mineral mixture|amino acids|trace elements|energivit|pro-phree|elecare|neocate'
  AND concept_class_id IN ('AU Substance', 'AU Qualifier', 'Med Product Unit', 'Med Product Pack', 'Medicinal Product',
                           'Trade Product Pack', 'Trade Product', 'Trade Product Unit', 'Containered Pack')
  AND concept_name NOT LIKE '%Panadol%'
  AND concept_name NOT LIKE '%ointment%'
  AND concept_name NOT LIKE '%Scotch pine%';

INSERT INTO non_drug
SELECT DISTINCT a.*
FROM concept_stage_sn a
     JOIN sources.amt_rf2_full_relationships b
     ON a.concept_code = destinationid::text
     JOIN concept_stage_sn c
     ON c.concept_Code = sourceid::text
WHERE a.concept_name IN ('bar', 'can', 'roll', 'rope', 'sheet')
;
INSERT INTO non_drug
SELECT DISTINCT c.*
FROM concept_stage_sn a
     JOIN sources.amt_rf2_full_relationships b
     ON a.concept_code = destinationid::text
     JOIN concept_stage_sn c
     ON c.concept_Code = sourceid::text
WHERE a.concept_name IN ('bar', 'can', 'roll', 'rope', 'sheet')
  AND c.concept_name NOT LIKE '%ointment%'
  AND c.concept_code != '159011000036105';--soap bar

INSERT INTO non_drug --dietary supplement
SELECT *
FROM concept_stage_sn
WHERE concept_name LIKE '%Phlexy-10%'
   OR concept_name LIKE '%Wagner 1000%'
   OR concept_name LIKE '%Nutrition Care%'
   OR concept_name LIKE '%amino acid formula%'
   OR concept_name LIKE '%Crampeze%'
   OR concept_name LIKE '%Elevit%'
   OR concept_name LIKE '%Bio Magnesium%';

INSERT INTO non_drug --contrast
SELECT DISTINCT a.*
FROM concept_stage_sn a
     JOIN sources.amt_rf2_full_relationships b
     ON a.concept_code = sourceid::text
WHERE (destinationid IN (31108011000036106, 75889011000036104, 31109011000036103, 31527011000036107, 75888011000036107,
                         48143011000036102, 48144011000036100, 48145011000036101, 31956011000036101, 733181000168100,
                         732871000168102)
    OR concept_name LIKE '% kBq %')
  AND a.concept_code NOT IN (SELECT concept_code FROM non_drug);

INSERT INTO non_drug
SELECT DISTINCT a.*
FROM concept_stage_sn a
WHERE concept_code IN
      ('31108011000036106', '75889011000036104', '31109011000036103', '31527011000036107', '75888011000036107',
       '48143011000036102', '48144011000036100', '48145011000036101', '31956011000036101', '733181000168100',
       '732871000168102');

INSERT INTO non_drug --add non_drugs that are related to already found
SELECT c.*
FROM non_drug a
     JOIN sources.amt_rf2_full_relationships b
     ON destinationid::text = a.concept_code
     JOIN concept_stage_sn c
     ON sourceid::text = c.concept_code
WHERE c.concept_code NOT IN (SELECT concept_code FROM non_drug)
;
INSERT INTO non_drug --add non_drugs that are related to already found
SELECT DISTINCT c.*
FROM non_drug a
     JOIN sources.amt_rf2_full_relationships b
     ON sourceid::text = a.concept_code
     JOIN concept_stage_sn c
     ON destinationid::text = c.concept_code
WHERE c.concept_code NOT IN (SELECT concept_code FROM non_drug)
  AND c.concept_class_id IN ('Trade Product Pack', 'Trade Product', 'Med Product Unit', 'Med Product Pack');

INSERT INTO non_drug --add supplement
SELECT DISTINCT c.*
FROM non_drug a
     JOIN sources.amt_rf2_full_relationships b
     ON sourceid::text = a.concept_code
     JOIN concept_stage_sn c
     ON destinationid::text = c.concept_code
WHERE c.concept_code NOT IN (SELECT concept_code FROM non_drug)
  AND (c.concept_name LIKE '%tape%' OR c.concept_name LIKE '%amino acid%' OR c.concept_name LIKE '%carbohydrate%' OR
       c.concept_name LIKE '%protein %')
  AND c.concept_code NOT IN ('31530011000036109', '32170011000036100', '31034011000036102');

INSERT INTO non_drug --add supplement
SELECT DISTINCT a.*
FROM concept_stage_sn a
     JOIN sources.amt_rf2_full_relationships b
     ON b.sourceid::text = a.concept_code
     JOIN sources.amt_rf2_full_relationships e
     ON b.destinationid = e.sourceid
     JOIN concept_stage_sn c
     ON c.concept_code = e.destinationid::text
WHERE c.concept_class_id IN ('AU Qualifier', 'AU Substance')
  AND c.concept_name ~ 'dressing|amino acid|trace elements'
  AND NOT c.concept_name ~ 'copper|manganese|zinc|magnesium'
  AND a.concept_code NOT IN (SELECT concept_code FROM non_drug)
;

DELETE
FROM non_drug
WHERE concept_code = '159011000036105'
   OR concept_name LIKE '%lignocaine%'
   OR concept_name LIKE '%Xylocaine%';
