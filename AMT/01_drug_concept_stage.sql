DROP TABLE IF EXISTS supplier;
CREATE TABLE supplier AS
SELECT DISTINCT initcap(substring(concept_name, '\((.*)\)')) AS supplier, concept_code
FROM concept_stage_sn
WHERE concept_class_id IN ('Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND substring(concept_name, '\((.*)\)') IS NOT NULL
  AND NOT substring(concept_name, '\((.*)\)') ~ '[0-9]'
  AND NOT substring(concept_name, '\((.*)\)') ~
          'blood|virus|inert|capsule|vaccine|D|accidental|CSL|paraffin|once|extemporaneous|long chain|perindopril|triglycerides|Night Tablet'
  AND length(substring(concept_name, '\(.*\)')) > 5
  AND substring(lower(concept_name), '\((.*)\)') != 'night'
  AND substring(lower(concept_name), '\((.*)\)') != 'capsule';

UPDATE supplier
SET supplier=regexp_replace(supplier, 'Night\s', '', 'g')
WHERE supplier LIKE '%Night%';
UPDATE supplier
SET supplier=regexp_replace(supplier, 'Night\s', '', 'g')
WHERE supplier LIKE '%Night%';
UPDATE SUPPLIER
SET SUPPLIER = 'Pfizer'
WHERE SUPPLIER = 'Pfizer Perth';
UPDATE SUPPLIER
SET SUPPLIER = 'Sanofi'
WHERE SUPPLIER LIKE '%Sanofi%';
UPDATE SUPPLIER
SET SUPPLIER = 'B Braun'
WHERE SUPPLIER LIKE '%B Braun%';
UPDATE SUPPLIER
SET SUPPLIER = 'Fresenius Kabi'
WHERE SUPPLIER LIKE '%Fresenius Kabi%';
UPDATE SUPPLIER
SET SUPPLIER = 'Baxter'
WHERE SUPPLIER LIKE '%Baxter%';
UPDATE SUPPLIER
SET SUPPLIER = 'Priceline'
WHERE SUPPLIER LIKE '%Priceline%';
UPDATE SUPPLIER
SET SUPPLIER = 'Pharmacist'
WHERE SUPPLIER LIKE '%Pharmacist%';

--add suppliers with abbreviations
DROP TABLE IF EXISTS supplier_2;
CREATE TABLE supplier_2 AS
SELECT DISTINCT supplier
FROM supplier;
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Apo');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Sun');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('David Craig');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Parke Davis');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Bioceuticals');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Ipc');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Rbx');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Dakota');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Dbl');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Scp');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Myx');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Aft');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Douglas');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Omega');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Bnm');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Qv');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Gxp');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Fbm');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Drla');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Csl');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Briemar');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Nature''S Way');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Sau');
INSERT INTO SUPPLIER_2 (SUPPLIER)
VALUES ('Drx');

ALTER TABLE supplier_2
    ADD concept_code varchar(255);

--using old codes from previous runs that have OMOP-codes 
UPDATE supplier_2 s2
SET concept_code=i.concept_code
FROM (
     SELECT concept_code, concept_name FROM devv5.concept WHERE concept_class_id = 'Supplier' AND vocabulary_id = 'AMT'
     ) i
WHERE i.concept_name = s2.supplier

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'IPC'
                 ),
    supplier='IPC'
WHERE supplier = 'Ipc';
UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Sun'
                 )
WHERE supplier = 'Sun';
UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Boucher & Muir'
                 ),
    supplier='Boucher & Muir'
WHERE supplier = 'Bnm';
UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'GXP'
                 ),
    supplier='GXP'
WHERE supplier = 'Gxp';
UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'FBM'
                 ),
    supplier='FBM'
WHERE supplier = 'Fbm';
UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Douglas'
                 )
WHERE supplier = 'Douglas';
UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'DRX'
                 ),
    supplier='DRX'
WHERE supplier = 'Drx';
UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM devv5.concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Saudi'
                 ),
    supplier='Saudi'
WHERE supplier = 'Sau';
/*
drop sequence if exists new_voc;
create sequence new_voc start with 528823;
*/

-- generate codes for those suppliers that haven't existed in the previous release
UPDATE supplier_2
SET concept_code='OMOP' || nextval('new_voc')
WHERE concept_code IS NULL;

--creating first table for drug_strength
DROP TABLE IF EXISTS ds_0;
CREATE TABLE ds_0 AS
SELECT sourceid, destinationid, UNITID, VALUE
FROM sources.amt_rf2_ss_strength_refset a
     JOIN sources.amt_sct2_rela_full_au b
     ON referencedComponentId = b.id
;

-- parse units as they looks like 'mg/ml' etc.
DROP TABLE IF EXISTS unit;
CREATE TABLE unit AS
SELECT concept_name,
       concept_class_id,
       new_concept_class_id,
       concept_name AS concept_code,
       unitid
FROM (
     SELECT DISTINCT UNNEST(regexp_matches(regexp_replace(b.concept_name, '(/)(unit|each|application|dose)', '', 'g'),
                                           '[^/]+', 'g')) concept_name,
                     'Unit' AS                            new_concept_class_id,
                     concept_class_id,
                     unitid
     FROM ds_0 a
          JOIN concept_stage_sn b
          ON a.unitid::TEXT = b.concept_code
     ) AS s0;

DROP TABLE IF EXISTS form;
CREATE TABLE form AS
SELECT DISTINCT a.CONCEPT_NAME, 'Dose Form' AS NEW_CONCEPT_CLASS_ID, a.CONCEPT_CODE, a.CONCEPT_CLASS_ID
FROM concept_stage_sn a
     JOIN sources.amt_sct2_rela_full_au b
     ON a.concept_code = b.sourceid::text
     JOIN concept_stage_sn c
     ON c.concept_Code = destinationid::text
WHERE a.concept_class_id = 'AU Qualifier'
  AND a.concept_code NOT IN
      (
      SELECT DISTINCT a.concept_code
      FROM concept_stage_sn a
           JOIN sources.amt_rf2_full_relationships b
           ON a.concept_code = b.sourceid::text
           JOIN concept_stage_sn c
           ON c.concept_Code = destinationid::text
      WHERE a.concept_class_id = 'AU Qualifier'
        AND initcap(c.concept_name) IN
            ('Area Unit Of Measure', 'Biological Unit Of Measure', 'Composite Unit Of Measure',
             'Descriptive Unit Of Measure', 'Mass Unit Of Measure', 'Microbiological Culture Unit Of Measure',
             'Radiation Activity Unit Of Measure', 'Time Unit Of Measure', 'Volume Unit Of Measure',
             'Type Of International Unit', 'Type Of Pharmacopoeial Unit')
      )
  AND lower(a.concept_name) NOT IN (SELECT lower(concept_name) FROM unit);

DROP TABLE IF EXISTS dcs_bn;
CREATE TABLE dcs_bn AS
SELECT DISTINCT *
FROM concept_stage_sn
WHERE CONCEPT_CLASS_ID = 'Trade Product';

UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?(\s\w+)?/\d+\s\w+$', '', 'g')
WHERE concept_name ~ '\d+(\s\w+)?/\d+\s\w+$';
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?(\s\w+)?/\d+\s\w+$', '', 'g')
WHERE concept_name ~ '\d+(\s\w+)?/\d+\s\w+$';
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '(\d+/)?(\d+\.)?\d+/\d+(\.\d+)?$', '', 'g')
WHERE concept_name ~ '(\d+/)?(\d+\.)?\d+/\d+(\.\d+)?$'
  AND NOT concept_name ~ '-(\d+\.)?\d+/\d+$';
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?/\d+(\.\d+)?(\s)?\w+$', '', 'g')
WHERE concept_name ~ '\d+(\.\d+)?/\d+(\.\d+)?(\s)?\w+$';
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?(\s)?(\w+)?(\s\w+)?/\d+(\.\d+)?(\s)?\w+$', '', 'g')
WHERE concept_name ~ '\d+(\.\d+)?(\s)?(\w+)?(\s\w+)?/\d+(\.\d+)?(\s)?\w+$';
UPDATE dcs_bn
SET concept_name='Biostate'
WHERE concept_name LIKE '%Biostate%';
UPDATE dcs_bn
SET concept_name='Feiba-NF'
WHERE concept_name LIKE '%Feiba-NF%';
UPDATE dcs_bn
SET concept_name='Xylocaine'
WHERE concept_name LIKE '%Xylocaine%';
UPDATE dcs_bn
SET concept_name='Canesten'
WHERE concept_name LIKE '%Canesten%';
UPDATE dcs_bn
SET concept_name=rtrim(substring(concept_name, '([^0-9]+)[0-9]?'), '-')
WHERE concept_name LIKE '%/%'
  AND concept_name NOT LIKE '%Neutrogena%';

UPDATE dcs_bn
SET concept_name=replace(concept_name, '(Pfizer (Perth))', 'Pfizer');
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, ' IM$| IV$', '', 'g');

UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Infant Drops'
WHERE CONCEPT_NAME = 'Paracetamol Infant''s Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol Children''s 5 to 12 Years'
WHERE CONCEPT_NAME = 'Panadol Children''s 5 Years to 12 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol Children''s 1 to 5 Years'
WHERE CONCEPT_NAME = 'Panadol Children''s Elixir 1 to 5 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol Children''s 5 to 12 Years'
WHERE CONCEPT_NAME = 'Panadol Children''s Elixir 5 to 12 Years';

UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\(Day\)|\(Night\)|(Day and Night)$|(Day$)');

UPDATE dcs_bn
SET concept_name=trim(replace(regexp_replace(concept_name, '\d+|\.|%|\smg\s|\smg$|\sIU\s|\sIU$', '', 'g'), '  ', ' '))
WHERE NOT concept_name ~ '-\d+'
  AND length(concept_name) > 3
  AND concept_name NOT LIKE '%Years%'
;
UPDATE dcs_bn
SET concept_name=trim(replace(concept_name, '  ', ' '));

--the same names
UPDATE DCS_BN
SET CONCEPT_NAME = 'Friar''s Balsam'
WHERE CONCEPT_CODE IN ('696391000168106', '688371000168108');


DELETE
FROM dcs_bn
WHERE CONCEPT_CODE IN (SELECT CONCEPT_CODE FROM non_drug);
DELETE
FROM dcs_bn
WHERE concept_name ~*
      'chloride|phosphate|paraffin|water| acid|toxoid|hydrate|sodium|glucose|castor| talc|^iodine|antivenom'
  AND NOT concept_name ~ ' APF| CD|Forte|Relief|Adult|Bio |BCP| XR|Plus|SR|Minims|HCTZ| BP|lasma-Lyte| EC|Min-I-Jet';

DELETE
FROM dcs_bn
WHERE concept_name LIKE '% mg%'
   OR concept_name IN ('Aciclovir Intravenous', 'Aciclovir IV', 'Acidophilus Bifidus', 'Risperidone', 'Ropivacaine',
                       'Piperacillin And Tazobactam', 'Perindopril And Indapamide', 'Paracetamol IV',
                       'Paracetamol Drops', 'Ondansetron Tabs', 'Omeprazole IV', 'Olanzapine IM',
                       'Copper', 'Chromium and Manganese', 'Menthol and Eucalyptus Inhalation',
                       'Menthol and Pine Inhalation', 'Chlorhexidine Hand Lotion',
                       'Brilliant Green and Crystal Violet Paint', 'Chlorhexidine Acetate and Cetrimide',
                       'Metoprolol IV', 'Metformin',
                       'Methadone Syrup', 'Levetiracetam IV', 'Latanoprost-Timolol', 'Wash', 'Cream',
                       'Oral Rehydration Salts', 'Gentian Alkaline Mixture', 'Decongestant', 'Zinc Compound', 'Ice',
                       'Pentamidine Isethionate', 'Bath Oil', 'Ringer"s', 'Sinus Rinse', 'Mercurochrome',
                       'Kaolin Mixture', 'Sulphadiazine', 'Pentamidine Isethionate', 'Zinc Compound', 'Vitamin B',
                       'Multivitamin and Minerals', 'Mycostatin Oral Drops', 'Paracetamol Drops', 'Nystatin Drops');

DELETE
FROM dcs_bn
WHERE (concept_name LIKE '%artan % HCT%' OR concept_name LIKE '%Sodium% HCT%')
  AND concept_name != 'Asartan HCT';--delete combination of ingredients
DELETE
FROM dcs_bn
WHERE lower(concept_name) IN (SELECT lower(Concept_name) FROM concept_stage_sn WHERE CONCEPT_CLASS_ID = 'AU Substance');
DELETE
FROM dcs_bn
WHERE lower(concept_name) IN (SELECT lower(Concept_name) FROM devv5.concept WHERE CONCEPT_CLASS_ID = 'Ingredient');

--all kinds of compounds
DELETE
FROM DCS_BN
WHERE CONCEPT_CODE IN
      ('654241000168106', '770691000168104', '51957011000036109', '65048011000036101', '86596011000036106',
       '43151000168105', '60221000168109', '734591000168106', '59261000168100', '3637011000036108', '53153011000036106',
       '664311000168109',
       '65011011000036100', '60481000168107', '40851000168105', '65135011000036103', '53159011000036109',
       '65107011000036104', '76000011000036107', '846531000168104', '45161000168106', '45161000168106', '7061000168108',
       '38571000168102')
;

DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Alendronate with Colecalciferol';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Aluminium Acetate BP';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Aluminium Acetate Aqueous APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Analgesic Calmative';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Analgesic and Calmative';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Antiseptic';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Betadine Antiseptic';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Calamine Oily';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Calamine Aqueous';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Cepacaine Oral Solution';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Clotrimazole Antifungal';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Clotrimazole Anti-Fungal';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Cocaine Hydrochloride and Adrenaline Acid Tartrate APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Codeine Phosphate Linctus APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Combantrin-1 with Mebendazole';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Cough Suppressant';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Decongestant Medicine';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Dermatitis and Psoriasis Relief';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Dexamphetamine Sulfate';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Diclofenac Sodium Anti-Inflammatory Pain Relief';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Disinfectant Hand Rub';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Emulsifying Ointment BP';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Epsom Salts';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Esomeprazole Hp';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Gentian Alkaline Mixture BP';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Homatropine Hydrobromide and Cocaine Hydrochloride APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Hypurin Isophane';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Ibuprofen and Codeine';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Ipecacuanha Syrup';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Kaolin Mixture BPC';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Kaolin and Opium Mixture APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Lamivudine and Zidovudine';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Laxative with Senna';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Magnesium Trisilicate Mixture BPC';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Magnesium Trisilicate and Belladonna Mixture BPC';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Menthol and Eucalyptus BP';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Mentholaire Vaporizer Fluid';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Methylated Spirit Specially';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Nasal Decongestant';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Natural Laxative with Softener';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Paraffin Soft White BP';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Perindopril and Indapamide';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Pholcodine Linctus APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Rh(D) Immunoglobulin-VF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Ringer-Lactate';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Sodium Bicarbonate BP';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Sodium Bicarbonate APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Zinc, Starch and Talc Dusting Powder BPC';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Zinc, Starch and Talc Dusting Powder APF';
DELETE
FROM DCS_BN
WHERE CONCEPT_NAME = 'Zinc Paste APF';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Abbocillin VK'
WHERE CONCEPT_NAME = 'Abbocillin VK Filmtab';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Acnederm'
WHERE CONCEPT_NAME = 'Acnederm Foaming Wash';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Actacode'
WHERE CONCEPT_NAME = 'Actacode Linctus';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Allersoothe'
WHERE CONCEPT_NAME = 'Allersoothe Elixir';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Amoxil'
WHERE CONCEPT_NAME = 'Amoxil Paediatric Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Avelox'
WHERE CONCEPT_NAME = 'Avelox IV';
UPDATE DCS_BN
SET CONCEPT_NAME = 'B-Dose'
WHERE CONCEPT_NAME = 'B-Dose IV';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Beconase'
WHERE CONCEPT_NAME = 'Beconase Allergy and Hayfever Hour';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Benzac AC'
WHERE CONCEPT_NAME = 'Benzac AC Wash';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Bepanthen'
WHERE CONCEPT_NAME = 'Bepanthen Antiseptic';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Cepacol'
WHERE CONCEPT_NAME = 'Cepacol Antibacterial';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Cepacol'
WHERE CONCEPT_NAME = 'Cepacol Antibacterial Menthol and Eucalyptus';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Citanest Dental'
WHERE CONCEPT_NAME = 'Citanest with Adrenaline in Dental';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Citanest Dental'
WHERE CONCEPT_NAME = 'Citanest with Octapressin Dental';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Colifoam'
WHERE CONCEPT_NAME = 'Colifoam Rectal Foam';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Coloxyl'
WHERE CONCEPT_NAME = 'Coloxyl Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Coloxyl'
WHERE CONCEPT_NAME = 'Coloxyl with Senna';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Cordarone X'
WHERE CONCEPT_NAME = 'Cordarone X Intravenous';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Daktarin'
WHERE CONCEPT_NAME = 'Daktarin Tincture';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Demazin Cold Relief Paediatric'
WHERE CONCEPT_NAME = 'Demazin Cold Relief Paediatric Oral Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Demazin Cold Relief'
WHERE CONCEPT_NAME = 'Demazin Cold Relief Syrup';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Demazin Paediatric'
WHERE CONCEPT_NAME = 'Demazin Decongestant Paediatric';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dermaveen'
WHERE CONCEPT_NAME = 'Dermaveen Moisturising';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dermaveen'
WHERE CONCEPT_NAME = 'Dermaveen Shower & Bath Oil';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dermaveen'
WHERE CONCEPT_NAME = 'Dermaveen Soap Free Wash';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dettol'
WHERE CONCEPT_NAME = 'Dettol Antiseptic Cream';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dettol'
WHERE CONCEPT_NAME = 'Dettol Antiseptic Liquid';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dettol'
WHERE CONCEPT_NAME = 'Dettol Wound Wash';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Anaesthetic, Antibacterial and Anti-Inflammatory';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Anti-Inflammatory Lozenge';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Anti-Inflammatory Solution';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Anti-Inflammatory Throat';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Cough Lozenge';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam Exrta Strength'
WHERE CONCEPT_NAME = 'Difflam Extra Strength';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Lozenge';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Mouth';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam'
WHERE CONCEPT_NAME = 'Difflam Sore Throat Gargle with Iodine Concentrate';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Difflam-C'
WHERE CONCEPT_NAME = 'Difflam-C Anti-Inflammatory Antiseptic';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dimetapp Chesty Cough'
WHERE CONCEPT_NAME = 'Dimetapp Chesty Cough Elixir';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dimetapp Cold and Allergy'
WHERE CONCEPT_NAME = 'Dimetapp Cold and Allergy Elixir';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dimetapp Cold and Allergy Extra Strength'
WHERE CONCEPT_NAME = 'Dimetapp Cold and Allergy Extra Strength Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dimetapp Cold and Flu Day Relief'
WHERE CONCEPT_NAME = 'Dimetapp Cold and Flu Day Relief Liquid Cap';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dimetapp Cold and Flu Night Relief'
WHERE CONCEPT_NAME = 'Dimetapp Cold and Flu Night Relief Liquid Cap';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dimetapp DM Cough and Cold'
WHERE CONCEPT_NAME = 'Dimetapp DM Cough and Cold Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dimetapp DM Cough and Cold'
WHERE CONCEPT_NAME = 'Dimetapp DM Cough and Cold Elixir';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Donnalix Infant'
WHERE CONCEPT_NAME = 'Donnalix Infant Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Drixine'
WHERE CONCEPT_NAME = 'Drixine Decongestant';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Drixine'
WHERE CONCEPT_NAME = 'Drixine Metered Pump Decongestant';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dry Tickly Cough'
WHERE CONCEPT_NAME = 'Dry Tickly Cough Medicine';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dry Tickly Cough'
WHERE CONCEPT_NAME = 'Dry Tickly Cough Mixture';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Dulcolax SP'
WHERE CONCEPT_NAME = 'Dulcolax SP Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough Forte'
WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Liquid Forte';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough plus Nasal Decongestant'
WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Liquid plus Nasal Decongestant';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough'
WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Liquid Regular';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Chesty Cough'
WHERE CONCEPT_NAME = 'Duro-Tuss Chesty Cough Lozenge';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Cough'
WHERE CONCEPT_NAME = 'Duro-Tuss Cough Liquid Expectorant';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Dry Cough plus Nasal Decongestant'
WHERE CONCEPT_NAME = 'Duro-Tuss Dry Cough Liquid plus Nasal Decongestant';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Dry Cough'
WHERE CONCEPT_NAME = 'Duro-Tuss Dry Cough Liquid Regular';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Duro-Tuss Dry Cough'
WHERE CONCEPT_NAME = 'Duro-Tuss Dry Cough Lozenge';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Emend'
WHERE CONCEPT_NAME = 'Emend IV';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Epilim'
WHERE CONCEPT_NAME = 'Epilim Syrup';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Eulactol'
WHERE CONCEPT_NAME = 'Eulactol Antifungal';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Febridol Infant'
WHERE CONCEPT_NAME = 'Febridol Infant Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Fludara'
WHERE CONCEPT_NAME = 'Fludara IV';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Fucidin'
WHERE CONCEPT_NAME = 'Fucidin IV';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Idaprex'
WHERE CONCEPT_NAME = 'Idaprex Arg';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Imodium'
WHERE CONCEPT_NAME = 'Imodium Caplet';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Imogam'
WHERE CONCEPT_NAME = 'Imogam Rabies Pasteurised';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Lanoxin Paediatric'
WHERE CONCEPT_NAME = 'Lanoxin Paediatric Elixir';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Lemsip Cold and Flu'
WHERE CONCEPT_NAME = 'Lemsip Cold and Flu Liquid Capsule';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Lorastyne'
WHERE CONCEPT_NAME = 'Lorastyne Syrup';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Lucrin Depot'
WHERE CONCEPT_NAME = 'Lucrin Depot -Month';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Marcain Spinal'
WHERE CONCEPT_NAME = 'Marcain Spinal Heavy';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Marcain Dental'
WHERE CONCEPT_NAME = 'Marcain with Adrenaline in Dental';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Merieux'
WHERE CONCEPT_NAME = 'Merieux Inactivated Rabies Vaccine';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Mersyndol'
WHERE CONCEPT_NAME = 'Mersyndol Caplet';
UPDATE DCS_BN
SET CONCEPT_NAME = 'MS Contin'
WHERE CONCEPT_NAME = 'MS Contin Suspension';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Mycil Healthy Feet Tinea'
WHERE CONCEPT_NAME = 'Mycil Healthy Feet Tinea Cream';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Mycil Healthy Feet Tinea'
WHERE CONCEPT_NAME = 'Mycil Healthy Feet Tinea Powder';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nasonex'
WHERE CONCEPT_NAME = 'Nasonex Aqueous';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic Plus'
WHERE CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic Plus Shampoo';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic'
WHERE CONCEPT_NAME = 'Neutrogena T/Gel Therapeutic Shampoo';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nexium HP'
WHERE CONCEPT_NAME = 'Nexium Hp';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nexium'
WHERE CONCEPT_NAME = 'Nexium IV';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nucosef'
WHERE CONCEPT_NAME = 'Nucosef Syrup';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nupentin'
WHERE CONCEPT_NAME = 'Nupentin Tab';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nurocain Dental'
WHERE CONCEPT_NAME = 'Nurocain with Adrenaline in Dental';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nurofen'
WHERE CONCEPT_NAME = 'Nurofen Caplet';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nurofen'
WHERE CONCEPT_NAME = 'Nurofen Liquid Capsule';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Nurofen Zavance'
WHERE CONCEPT_NAME = 'Nurofen Zavance Liquid Capsule';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol'
WHERE CONCEPT_NAME = 'Panadol Caplet';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol Optizorb'
WHERE CONCEPT_NAME = 'Panadol Caplet Optizorb';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol Gel'
WHERE CONCEPT_NAME = 'Panadol Gel Cap';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol Gel'
WHERE CONCEPT_NAME = 'Panadol Gel Tab';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol'
WHERE CONCEPT_NAME = 'Panadol Mini Cap';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panadol Sinus PE Night and Day'
WHERE CONCEPT_NAME = 'Panadol Sinus PE Night and Day Caplet';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Panafen IB'
WHERE CONCEPT_NAME = 'Panafen IB Mini Cap';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Children''s'
WHERE CONCEPT_NAME = 'Paracetamol Children''s Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Children''s 1 Month to 2 Years'
WHERE CONCEPT_NAME = 'Paracetamol Children''s Drops 1 Month to 2 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Children''s 1 to 5 Years'
WHERE CONCEPT_NAME = 'Paracetamol Children''s Elixir 1 to 5 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Children''s 5 to 12 Years'
WHERE CONCEPT_NAME = 'Paracetamol Children''s Elixir 5 to 12 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Children''s 1 Month to 2 Years'
WHERE CONCEPT_NAME = 'Paracetamol Children''s Infant Drops 1 Month to 2 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Children''s 1 to 5 Years'
WHERE CONCEPT_NAME = 'Paracetamol Children''s Syrup 1 to 5 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Infant and Children 1 Month to 2 Years'
WHERE CONCEPT_NAME = 'Paracetamol Drops Infants and Children 1 Month to 2 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Extra'
WHERE CONCEPT_NAME = 'Paracetamol Extra Tabsule';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Infant and Children 1 Month to 4 Years'
WHERE CONCEPT_NAME = 'Paracetamol Infant and Children''s Drops 1 Month to 4 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Infant'
WHERE CONCEPT_NAME = 'Paracetamol Infant Drops';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paracetamol Pain and Fever 1 Month to 2 Years'
WHERE CONCEPT_NAME = 'Paracetamol Pain and Fever Drops 1 Month to 2 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Paralgin'
WHERE CONCEPT_NAME = 'Paralgin Tabsule';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Penta-vite'
WHERE CONCEPT_NAME = 'Penta-vite Multivitamins with Iron for Kids 1 to 12 Years';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Pholtrate'
WHERE CONCEPT_NAME = 'Pholtrate Linctus';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Polaramine'
WHERE CONCEPT_NAME = 'Polaramine Syrup';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Prefrin'
WHERE CONCEPT_NAME = 'Prefrin Liquifilm';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Proctosedyl'
WHERE CONCEPT_NAME = 'Proctosedyl Rectal';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Rhinocort'
WHERE CONCEPT_NAME = 'Rhinocort Aqueous';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Rynacrom'
WHERE CONCEPT_NAME = 'Rynacrom Metered Dose';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Sandoglobulin NF'
WHERE CONCEPT_NAME = 'Sandoglobulin NF Liquid';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Savlon'
WHERE CONCEPT_NAME = 'Savlon Antiseptic Powder';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Telfast Children'
WHERE CONCEPT_NAME = 'Telfast Children''s Elixir';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Theratears'
WHERE CONCEPT_NAME = 'Theratears Liquid';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Tinaderm'
WHERE CONCEPT_NAME = 'Tinaderm Powder Spray';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Uniclar'
WHERE CONCEPT_NAME = 'Uniclar Aqueous';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Vicks Cough'
WHERE CONCEPT_NAME = 'Vicks Cough Syrup';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Vicks Cough'
WHERE CONCEPT_NAME = 'Vicks Cough Syrup for Chesty Coughs';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Zarontin'
WHERE CONCEPT_NAME = 'Zarontin Syrup';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Zeldox'
WHERE CONCEPT_NAME = 'Zeldox IM';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Zithromax'
WHERE CONCEPT_NAME = 'Zithromax IV';
UPDATE DCS_BN
SET CONCEPT_NAME = 'Zyprexa'
WHERE CONCEPT_NAME = 'Zyprexa IM';

TRUNCATE TABLE drug_concept_stage;
INSERT INTO drug_concept_stage (CONCEPT_NAME, VOCABULARY_ID, CONCEPT_CLASS_ID, STANDARD_CONCEPT, CONCEPT_CODE,
                                POSSIBLE_EXCIPIENT, domain_id, VALID_START_DATE, VALID_END_DATE, INVALID_REASON,
                                SOURCE_CONCEPT_CLASS_ID)
SELECT CONCEPT_NAME, 'AMT', NEW_CONCEPT_CLASS_ID, NULL, CONCEPT_CODE, NULL, 'Drug',
       TO_DATE('20161101', 'yyyymmdd') AS valid_start_date, TO_DATE('20991231', 'yyyymmdd') AS valid_end_date, NULL,
       CONCEPT_CLASS_ID
FROM (
     SELECT CONCEPT_NAME, 'Ingredient' AS NEW_CONCEPT_CLASS_ID, CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM concept_stage_sn
     WHERE CONCEPT_CLASS_ID = 'AU Substance'
       AND concept_code NOT IN ('52990011000036102', '48158011000036109')-- Aqueous Cream ,Cotton Wool
     UNION
     SELECT CONCEPT_NAME, 'Brand Name' AS NEW_CONCEPT_CLASS_ID, CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM dcs_bn
     UNION
     SELECT CONCEPT_NAME, NEW_CONCEPT_CLASS_ID, CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM form
     UNION
     SELECT supplier, 'Supplier', concept_code, ''
     FROM supplier_2
     UNION
     SELECT CONCEPT_NAME, NEW_CONCEPT_CLASS_ID, initcap(CONCEPT_NAME), CONCEPT_CLASS_ID
     FROM unit
     UNION
     SELECT CONCEPT_NAME, 'Drug Product', CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM concept_stage_sn
     WHERE CONCEPT_CLASS_ID IN
           ('Containered Pack', 'Med Product Pack', 'Trade Product Pack', 'Med Product Unit', 'Trade Product Unit')
       AND CONCEPT_NAME NOT LIKE '%(&)%'
       AND (SELECT count(*) FROM regexp_matches(concept_name, '\sx\s', 'g')) <= 1
       AND concept_name NOT LIKE '%Trisequens, 28%'--exclude packs
     UNION
     SELECT concat(substr(CONCEPT_NAME, 1, 242), ' [Drug Pack]') AS concept_name, 'Drug Product', CONCEPT_CODE,
            CONCEPT_CLASS_ID
     FROM concept_stage_sn
     WHERE CONCEPT_CLASS_ID IN
           ('Containered Pack', 'Med Product Pack', 'Trade Product Pack', 'Med Product Unit', 'Trade Product Unit')
       AND (CONCEPT_NAME LIKE '%(&)%' OR (SELECT count(*) FROM regexp_matches(concept_name, '\sx\s', 'g')) > 1 OR
            concept_name LIKE '%Trisequens, 28%')
     ) AS s0;

DELETE
FROM DRUG_CONCEPT_STAGE
WHERE CONCEPT_CODE IN (SELECT CONCEPT_CODE FROM non_drug);

INSERT INTO drug_concept_stage (CONCEPT_NAME, VOCABULARY_ID, CONCEPT_CLASS_ID, STANDARD_CONCEPT, CONCEPT_CODE,
                                POSSIBLE_EXCIPIENT, domain_id, VALID_START_DATE, VALID_END_DATE, INVALID_REASON,
                                SOURCE_CONCEPT_CLASS_ID)
SELECT DISTINCT CONCEPT_NAME, 'AMT', 'Device', 'S', CONCEPT_CODE, NULL, 'Device',
                TO_DATE('20161101', 'yyyymmdd') AS valid_start_date, TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                NULL, CONCEPT_CLASS_ID
FROM non_drug
WHERE concept_class_id NOT IN ('AU Qualifier', 'AU Substance', 'Trade Product');

UPDATE drug_concept_stage
SET concept_name=INITCAP(concept_name)
WHERE NOT (concept_class_id = 'Supplier' AND length(concept_name) < 4);--to fix chloride\Chloride

DELETE
FROM drug_concept_stage --delete containers
WHERE concept_code IN (
                      SELECT destinationid::text
                      FROM concept_stage_sn a
                           JOIN sources.amt_sct2_rela_full_au b
                           ON destinationid::text = a.concept_code
                           JOIN concept_stage_sn c
                           ON c.concept_code = sourceid::text
                      WHERE typeid = '30465011000036106'
                      );

UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
FROM (
     SELECT concept_name, MIN(concept_code) m
     FROM drug_concept_stage
     WHERE concept_class_id IN ('Ingredient', 'Dose Form', 'Brand Name', 'Unit') --and  source_concept_class_id not in ('Medicinal Product','Trade Product')
     GROUP BY concept_name
     HAVING count(concept_name) >= 1
     ) d
WHERE d.m = dcs.concept_code;

UPDATE drug_concept_stage
SET POSSIBLE_EXCIPIENT='1'
WHERE concept_name = 'Aqueous Cream';

DELETE
FROM drug_concept_stage
WHERE lower(concept_name) IN ('containered trade product pack', 'trade product pack', 'medicinal product unit of use',
                              'trade product unit of use', 'form', 'medicinal product pack', 'unit of use',
                              'unit of measure');

DELETE
FROM drug_concept_stage
WHERE initcap(concept_name) IN --delete all unnecessary concepts
      ('Alternate Strength Followed By Numerator/Denominator Strength', 'Alternate Strength Only',
       'Australian Qualifier', 'Numerator/Denominator Strength',
       'Numerator/Denominator Strength Followed By Alternate Strength', 'Preferred Strength Representation Type',
       'Area Unit Of Measure', 'Square', 'Kbq', 'Dispenser Pack', 'Diluent', 'Tube', 'Tub', 'Carton', 'Unit Dose',
       'Vial', 'Strip',
       'Biological Unit Of Measure', 'Composite Unit Of Measure', 'Descriptive Unit Of Measure', 'Medicinal Product',
       'Mass Unit Of Measure', 'Microbiological Culture Unit Of Measure', 'Radiation Activity Unit Of Measure',
       'Time Unit Of Measure', 'Australian Substance', 'Medicinal Substance', 'Volume Unit Of Measure',
       'Measure', 'Continuous', 'Dose', 'Ampoule', 'Bag', 'Bead', 'Bottle', 'Ampoule', 'Type Of International Unit',
       'Type Of Pharmacopoeial Unit');

DELETE
FROM drug_concept_stage --as RxNorm doesn't have diluents in injectable drugs we will also delete them
WHERE (lower(concept_name) LIKE '%inert%' OR lower(concept_name) LIKE '%diluent%')
  AND concept_class_id = 'Drug Product'
  AND lower(concept_name) NOT LIKE '%tablet%';

ANALYZE drug_concept_stage;

--create relationship from non-standard ingredients to standard ingredients 
DROP TABLE IF EXISTS non_S_ing_to_S;
CREATE TABLE non_S_ing_to_S AS
SELECT DISTINCT b.concept_code, a.concept_code AS s_concept_Code
FROM drug_concept_stage a
     JOIN drug_concept_stage b
     ON lower(a.concept_name) = lower(b.concept_name)
WHERE a.STANDARD_CONCEPT = 'S'
  AND a.CONCEPT_CLASS_ID = 'Ingredient'
  AND b.STANDARD_CONCEPT IS NULL
  AND b.CONCEPT_CLASS_ID = 'Ingredient';
--create relationship from non-standard forms to standard forms
DROP TABLE IF EXISTS non_S_form_to_S;
CREATE TABLE non_S_form_to_S AS
SELECT DISTINCT b.concept_code, a.concept_code AS s_concept_Code
FROM drug_concept_stage a
     JOIN drug_concept_stage b
     ON lower(a.concept_name) = lower(b.concept_name)
WHERE a.STANDARD_CONCEPT = 'S'
  AND a.CONCEPT_CLASS_ID = 'Dose Form'
  AND b.STANDARD_CONCEPT IS NULL
  AND b.CONCEPT_CLASS_ID = 'Dose Form';

--create relationship from non-standard bn to standard bn
DROP TABLE IF EXISTS non_S_bn_to_S;
CREATE TABLE non_S_bn_to_S AS
SELECT DISTINCT b.concept_code, a.concept_code AS s_concept_Code
FROM drug_concept_stage a
     JOIN drug_concept_stage b
     ON lower(a.concept_name) = lower(b.concept_name)
WHERE a.STANDARD_CONCEPT = 'S'
  AND a.CONCEPT_CLASS_ID = 'Brand Name'
  AND b.STANDARD_CONCEPT IS NULL
  AND b.CONCEPT_CLASS_ID = 'Brand Name';
