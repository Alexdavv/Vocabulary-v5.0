DROP TABLE IF EXISTS supplier;
CREATE TABLE supplier AS
SELECT DISTINCT initcap(substring(concept_name, '\((.*)\)')) AS supplier, concept_code
FROM concept_stage_sn
WHERE concept_class_id IN ('Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND substring(concept_name, '\((.*)\)') IS NOT NULL
  AND NOT substring(concept_name, '\((.*)\)') ~ '[0-9]'
  AND NOT substring(concept_name, '\((.*)\)') ~
          'blood|virus|inert|[Cc]apsule|vaccine|D|accidental|CSL|paraffin|once|extemporaneous|long chain|perindopril|triglycerides|Night Tablet'
  AND length(substring(concept_name, '\(.*\)')) > 5
  AND substring(lower(concept_name), '\((.*)\)') != 'night';

UPDATE supplier
SET supplier=regexp_replace(supplier, 'Night\s', '', 'g')
WHERE supplier LIKE '%Night%';

UPDATE supplier s
SET supplier = v.supplier_new
FROM (
     VALUES ('%Pfizer%', 'Pfizer'),
            ('%Sanofi%', 'Sanofi'),
            ('%B Braun%', 'B Braun'),
            ('%Fresenius Kabi%', 'Fresenius Kabi'),
            ('%Baxter%', 'Baxter'),
            ('%Priceline%', 'Priceline'),
            ('%Pharmacist%', 'Pharmacist')
     ) AS v (supplier_old, supplier_new)
WHERE s.supplier LIKE v.supplier_old;


--add suppliers with abbreviations
DROP TABLE IF EXISTS supplier_2;
CREATE TABLE supplier_2 AS
SELECT DISTINCT supplier
FROM supplier;
INSERT INTO supplier_2 (supplier)
VALUES ('Apo'),
       ('Sun'),
       ('David Craig'),
       ('Parke Davis'),
       ('Bioceuticals'),
       ('Ipc'),
       ('Rbx'),
       ('Dakota'),
       ('Dbl'),
       ('Scp'),
       ('Myx'),
       ('Aft'),
       ('Douglas'),
       ('Omega'),
       ('Bnm'),
       ('Qv'),
       ('Gxp'),
       ('Fbm'),
       ('Drla'),
       ('Csl'),
       ('Briemar'),
       ('Nature''S Way'),
       ('Sau'),
       ('Drx');

ALTER TABLE supplier_2
    ADD concept_code varchar(255);

--using old codes from previous runs that have OMOP-codes
UPDATE supplier_2 s2
SET concept_code=i.concept_code
FROM (
     SELECT concept_code, concept_name
     FROM devv5.concept
     WHERE concept_class_id = 'Supplier'
       AND vocabulary_id = 'AMT'
     ) i
WHERE i.concept_name = s2.supplier;

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
SELECT DISTINCT rel.sourceid, rel.destinationid, str.unitid, str.value
FROM sources.amt_rf2_ss_strength_refset str
     JOIN sources.amt_rf2_full_relationships rel
     ON str.referencedComponentId = rel.id
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
     SELECT DISTINCT
         UNNEST(regexp_matches(regexp_replace(cs.concept_name, '(/)(unit|each|application|dose)', '', 'g'),
                               '[^/]+', 'g')) concept_name,
         'Unit' AS                            new_concept_class_id,
         cs.concept_class_id,
         ds.unitid
     FROM ds_0 ds
          JOIN concept_stage_sn cs
          ON ds.unitid::TEXT = cs.concept_code
     ) AS s0;

DROP TABLE IF EXISTS form;
CREATE TABLE form AS
SELECT DISTINCT a.concept_name, 'Dose Form' AS new_concept_class_id, a.concept_code, a.concept_class_id
FROM concept_stage_sn a
     JOIN sources.amt_rf2_full_relationships b
     ON a.concept_code = b.sourceid::text
     JOIN concept_stage_sn c
     ON c.concept_code = destinationid::text
WHERE a.concept_class_id = 'AU Qualifier'
  AND a.concept_code NOT IN
      (
      SELECT DISTINCT a.concept_code
      FROM concept_stage_sn a
           JOIN sources.amt_rf2_full_relationships b
           ON a.concept_code = b.sourceid::text
           JOIN concept_stage_sn c
           ON c.concept_code = destinationid::text
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


UPDATE dcs_bn dcs
SET concept_name = v.concept_name_new
FROM (
     VALUES ('Paracetamol Infant''s Drops', 'Paracetamol Infant Drops'),
            ('Panadol Children''s 5 Years to 12 Years', 'Panadol Children''s 5 to 12 Years'),
            ('Panadol Children''s Elixir 1 to 5 Years', 'Panadol Children''s 1 to 5 Years'),
            ('Panadol Children''s Elixir 5 to 12 Years', 'Panadol Children''s 5 to 12 Years'),
            ('Abbocillin VK Filmtab', 'Abbocillin VK'),
            ('Acnederm Foaming Wash', 'Acnederm'),
            ('Actacode Linctus', 'Actacode'),
            ('Allersoothe Elixir', 'Allersoothe'),
            ('Amoxil Paediatric Drops', 'Amoxil'),
            ('Avelox IV', 'Avelox'),
            ('B-Dose IV', 'B-Dose'),
            ('Beconase Allergy and Hayfever Hour', 'Beconase'),
            ('Benzac AC Wash', 'Benzac AC'),
            ('Bepanthen Antiseptic', 'Bepanthen'),
            ('Cepacol Antibacterial', 'Cepacol'),
            ('Cepacol Antibacterial Menthol and Eucalyptus', 'Cepacol'),
            ('Citanest with Adrenaline in Dental', 'Citanest Dental'),
            ('Citanest with Octapressin Dental', 'Citanest Dental'),
            ('Colifoam Rectal Foam', 'Colifoam'),
            ('Coloxyl Drops', 'Coloxyl'),
            ('Coloxyl with Senna', 'Coloxyl'),
            ('Cordarone X Intravenous', 'Cordarone X'),
            ('Daktarin Tincture', 'Daktarin'),
            ('Demazin Cold Relief Paediatric Oral Drops', 'Demazin Cold Relief Paediatric'),
            ('Demazin Cold Relief Syrup', 'Demazin Cold Relief'),
            ('Demazin Decongestant Paediatric', 'Demazin Paediatric'),
            ('Dermaveen Moisturising', 'Dermaveen'),
            ('Dermaveen Shower & Bath Oil', 'Dermaveen'),
            ('Dermaveen Soap Free Wash', 'Dermaveen'),
            ('Dettol Antiseptic Cream', 'Dettol'),
            ('Dettol Antiseptic Liquid', 'Dettol'),
            ('Dettol Wound Wash', 'Dettol'),
            ('Difflam Anaesthetic, Antibacterial and Anti-Inflammatory', 'Difflam'),
            ('Difflam Anti-Inflammatory Lozenge', 'Difflam'),
            ('Difflam Anti-Inflammatory Solution', 'Difflam'),
            ('Difflam Anti-Inflammatory Throat', 'Difflam'),
            ('Difflam Cough Lozenge', 'Difflam'),
            ('Difflam Extra Strength', 'Difflam Exrta Strength'),
            ('Difflam Lozenge', 'Difflam'),
            ('Difflam Mouth', 'Difflam'),
            ('Difflam Sore Throat Gargle with Iodine Concentrate', 'Difflam'),
            ('Difflam-C Anti-Inflammatory Antiseptic', 'Difflam-C'),
            ('Dimetapp Chesty Cough Elixir', 'Dimetapp Chesty Cough'),
            ('Dimetapp Cold and Allergy Elixir', 'Dimetapp Cold and Allergy'),
            ('Dimetapp Cold and Allergy Extra Strength Drops', 'Dimetapp Cold and Allergy Extra Strength'),
            ('Dimetapp Cold and Flu Day Relief Liquid Cap', 'Dimetapp Cold and Flu Day Relief'),
            ('Dimetapp Cold and Flu Night Relief Liquid Cap', 'Dimetapp Cold and Flu Night Relief'),
            ('Dimetapp DM Cough and Cold Drops', 'Dimetapp DM Cough and Cold'),
            ('Dimetapp DM Cough and Cold Elixir', 'Dimetapp DM Cough and Cold'),
            ('Donnalix Infant Drops', 'Donnalix Infant'),
            ('Drixine Decongestant', 'Drixine'),
            ('Drixine Metered Pump Decongestant', 'Drixine'),
            ('Dry Tickly Cough Medicine', 'Dry Tickly Cough'),
            ('Dry Tickly Cough Mixture', 'Dry Tickly Cough'),
            ('Dulcolax SP Drops', 'Dulcolax SP'),
            ('Duro-Tuss Chesty Cough Liquid Forte', 'Duro-Tuss Chesty Cough Forte'),
            ('Duro-Tuss Chesty Cough Liquid plus Nasal Decongestant', 'Duro-Tuss Chesty Cough plus Nasal Decongestant'),
            ('Duro-Tuss Chesty Cough Liquid Regular', 'Duro-Tuss Chesty Cough'),
            ('Duro-Tuss Chesty Cough Lozenge', 'Duro-Tuss Chesty Cough'),
            ('Duro-Tuss Cough Liquid Expectorant', 'Duro-Tuss Cough'),
            ('Duro-Tuss Dry Cough Liquid plus Nasal Decongestant', 'Duro-Tuss Dry Cough plus Nasal Decongestant'),
            ('Duro-Tuss Dry Cough Liquid Regular', 'Duro-Tuss Dry Cough'),
            ('Duro-Tuss Dry Cough Lozenge', 'Duro-Tuss Dry Cough'),
            ('Emend IV', 'Emend'),
            ('Epilim Syrup', 'Epilim'),
            ('Eulactol Antifungal', 'Eulactol'),
            ('Febridol Infant Drops', 'Febridol Infant'),
            ('Fludara IV', 'Fludara'),
            ('Fucidin IV', 'Fucidin'),
            ('Idaprex Arg', 'Idaprex'),
            ('Imodium Caplet', 'Imodium'),
            ('Imogam Rabies Pasteurised', 'Imogam'),
            ('Lanoxin Paediatric Elixir', 'Lanoxin Paediatric'),
            ('Lemsip Cold and Flu Liquid Capsule', 'Lemsip Cold and Flu'),
            ('Lorastyne Syrup', 'Lorastyne'),
            ('Lucrin Depot -Month', 'Lucrin Depot'),
            ('Marcain Spinal Heavy', 'Marcain Spinal'),
            ('Marcain with Adrenaline in Dental', 'Marcain Dental'),
            ('Merieux Inactivated Rabies Vaccine', 'Merieux'),
            ('Mersyndol Caplet', 'Mersyndol'),
            ('MS Contin Suspension', 'MS Contin'),
            ('Mycil Healthy Feet Tinea Cream', 'Mycil Healthy Feet Tinea'),
            ('Mycil Healthy Feet Tinea Powder', 'Mycil Healthy Feet Tinea'),
            ('Nasonex Aqueous', 'Nasonex'),
            ('Neutrogena T/Gel Therapeutic Plus Shampoo', 'Neutrogena T/Gel Therapeutic Plus'),
            ('Neutrogena T/Gel Therapeutic Shampoo', 'Neutrogena T/Gel Therapeutic'),
            ('Nexium Hp', 'Nexium HP'),
            ('Nexium IV', 'Nexium'),
            ('Nucosef Syrup', 'Nucosef'),
            ('Nupentin Tab', 'Nupentin'),
            ('Nurocain with Adrenaline in Dental', 'Nurocain Dental'),
            ('Nurofen Caplet', 'Nurofen'),
            ('Nurofen Liquid Capsule', 'Nurofen'),
            ('Nurofen Zavance Liquid Capsule', 'Nurofen Zavance'),
            ('Panadol Caplet', 'Panadol'),
            ('Panadol Caplet Optizorb', 'Panadol Optizorb'),
            ('Panadol Gel Cap', 'Panadol Gel'),
            ('Panadol Gel Tab', 'Panadol Gel'),
            ('Panadol Mini Cap', 'Panadol'),
            ('Panadol Sinus PE Night and Day Caplet', 'Panadol Sinus PE Night and Day'),
            ('Panafen IB Mini Cap', 'Panafen IB'),
            ('Paracetamol Children''s Drops', 'Paracetamol Children''s'),
            ('Paracetamol Children''s Drops 1 Month to 2 Years', 'Paracetamol Children''s 1 Month to 2 Years'),
            ('Paracetamol Children''s Elixir 1 to 5 Years', 'Paracetamol Children''s 1 to 5 Years'),
            ('Paracetamol Children''s Elixir 5 to 12 Years', 'Paracetamol Children''s 5 to 12 Years'),
            ('Paracetamol Children''s Infant Drops 1 Month to 2 Years', 'Paracetamol Children''s 1 Month to 2 Years'),
            ('Paracetamol Children''s Syrup 1 to 5 Years', 'Paracetamol Children''s 1 to 5 Years'),
            ('Paracetamol Drops Infants and Children 1 Month to 2 Years',
             'Paracetamol Infant and Children 1 Month to 2 Years'),
            ('Paracetamol Extra Tabsule', 'Paracetamol Extra'),
            ('Paracetamol Infant and Children''s Drops 1 Month to 4 Years',
             'Paracetamol Infant and Children 1 Month to 4 Years'),
            ('Paracetamol Infant Drops', 'Paracetamol Infant'),
            ('Paracetamol Pain and Fever Drops 1 Month to 2 Years', 'Paracetamol Pain and Fever 1 Month to 2 Years'),
            ('Paralgin Tabsule', 'Paralgin'),
            ('Penta-vite Multivitamins with Iron for Kids 1 to 12 Years', 'Penta-vite'),
            ('Pholtrate Linctus', 'Pholtrate'),
            ('Polaramine Syrup', 'Polaramine'),
            ('Prefrin Liquifilm', 'Prefrin'),
            ('Proctosedyl Rectal', 'Proctosedyl'),
            ('Rhinocort Aqueous', 'Rhinocort'),
            ('Rynacrom Metered Dose', 'Rynacrom'),
            ('Sandoglobulin NF Liquid', 'Sandoglobulin NF'),
            ('Savlon Antiseptic Powder', 'Savlon'),
            ('Telfast Children''s Elixir', 'Telfast Children'),
            ('Theratears Liquid', 'Theratears'),
            ('Tinaderm Powder Spray', 'Tinaderm'),
            ('Uniclar Aqueous', 'Uniclar'),
            ('Vicks Cough Syrup', 'Vicks Cough'),
            ('Vicks Cough Syrup for Chesty Coughs', 'Vicks Cough'),
            ('Zarontin Syrup', 'Zarontin'),
            ('Zeldox IM', 'Zeldox'),
            ('Zithromax IV', 'Zithromax'),
            ('Zyprexa IM', 'Zyprexa')
     ) AS v (concept_name_old, concept_name_new)
WHERE dcs.concept_name = v.concept_name_old;

UPDATE dcs_bn
SET concept_name=rtrim(substring(concept_name, '([^0-9]+)[0-9]?'), '-')
WHERE concept_name LIKE '%/%'
  AND concept_name NOT LIKE '%Neutrogena%';
UPDATE dcs_bn
SET concept_name=replace(concept_name, '(Pfizer (Perth))', 'Pfizer');
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, ' IM$| IV$', '', 'g');
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\(Day\)|\(Night\)|(Day and Night)$|(Day$)', '', 'g');
UPDATE dcs_bn
SET concept_name=trim(replace(regexp_replace(concept_name, '\d+|\.|%|\smg\s|\smg$|\sIU\s|\sIU$', '', 'g'), '  ', ' '))
WHERE NOT concept_name ~ '-\d+'
  AND length(concept_name) > 3
  AND concept_name NOT LIKE '%Years%';

UPDATE dcs_bn
SET concept_name=trim(replace(concept_name, '  ', ' '));

--the same names
UPDATE DCS_BN
SET concept_name = 'Friar''s Balsam'
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
FROM dcs_bn
WHERE CONCEPT_CODE IN
      ('654241000168106', '770691000168104', '51957011000036109', '65048011000036101', '86596011000036106',
       '43151000168105', '60221000168109', '734591000168106', '59261000168100', '3637011000036108', '53153011000036106',
       '664311000168109',
       '65011011000036100', '60481000168107', '40851000168105', '65135011000036103', '53159011000036109',
       '65107011000036104', '76000011000036107', '846531000168104', '45161000168106', '45161000168106', '7061000168108',
       '38571000168102')
;

DELETE
FROM dcs_bn
WHERE concept_name IN ('Alendronate with Colecalciferol',
                       'Aluminium Acetate BP',
                       'Aluminium Acetate Aqueous APF',
                       'Analgesic Calmative',
                       'Analgesic and Calmative',
                       'Antiseptic',
                       'Betadine Antiseptic',
                       'Calamine Oily',
                       'Calamine Aqueous',
                       'Cepacaine Oral Solution',
                       'Clotrimazole Antifungal',
                       'Clotrimazole Anti-Fungal',
                       'Cocaine Hydrochloride and Adrenaline Acid Tartrate APF',
                       'Codeine Phosphate Linctus APF',
                       'Combantrin-1 with Mebendazole',
                       'Cough Suppressant',
                       'Decongestant Medicine',
                       'Dermatitis and Psoriasis Relief',
                       'Dexamphetamine Sulfate',
                       'Diclofenac Sodium Anti-Inflammatory Pain Relief',
                       'Disinfectant Hand Rub',
                       'Emulsifying Ointment BP',
                       'Epsom Salts',
                       'Esomeprazole Hp',
                       'Gentian Alkaline Mixture BP',
                       'Homatropine Hydrobromide and Cocaine Hydrochloride APF',
                       'Hypurin Isophane',
                       'Ibuprofen and Codeine',
                       'Ipecacuanha Syrup',
                       'Kaolin Mixture BPC',
                       'Kaolin and Opium Mixture APF',
                       'Lamivudine and Zidovudine',
                       'Laxative with Senna',
                       'Magnesium Trisilicate Mixture BPC',
                       'Magnesium Trisilicate and Belladonna Mixture BPC',
                       'Menthol and Eucalyptus BP',
                       'Mentholaire Vaporizer Fluid',
                       'Methylated Spirit Specially',
                       'Nasal Decongestant',
                       'Natural Laxative with Softener',
                       'Paraffin Soft White BP',
                       'Perindopril and Indapamide',
                       'Pholcodine Linctus APF',
                       'Rh(D) Immunoglobulin-VF',
                       'Ringer-Lactate',
                       'Sodium Bicarbonate BP',
                       'Sodium Bicarbonate APF',
                       'Zinc, Starch and Talc Dusting Powder BPC',
                       'Zinc, Starch and Talc Dusting Powder APF',
                       'Zinc Paste APF');

TRUNCATE TABLE drug_concept_stage;
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                possible_excipient, domain_id, valid_start_date, valid_end_date, invalid_reason,
                                source_concept_class_id)
SELECT concept_name, 'AMT', NEW_CONCEPT_CLASS_ID, NULL, CONCEPT_CODE, NULL, 'Drug',
       TO_DATE('20161101', 'yyyymmdd') AS valid_start_date, TO_DATE('20991231', 'yyyymmdd') AS valid_end_date, NULL,
       CONCEPT_CLASS_ID
FROM (
     SELECT concept_name, 'Ingredient' AS NEW_CONCEPT_CLASS_ID, CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM concept_stage_sn
     WHERE CONCEPT_CLASS_ID = 'AU Substance'
       AND concept_code NOT IN ('52990011000036102', '48158011000036109')-- Aqueous Cream ,Cotton Wool
     UNION
     SELECT concept_name, 'Brand Name' AS NEW_CONCEPT_CLASS_ID, CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM dcs_bn
     UNION
     SELECT concept_name, NEW_CONCEPT_CLASS_ID, CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM form
     UNION
     SELECT supplier, 'Supplier', concept_code, ''
     FROM supplier_2
     UNION
     SELECT concept_name, NEW_CONCEPT_CLASS_ID, initcap(concept_name), CONCEPT_CLASS_ID
     FROM unit
     UNION
     SELECT concept_name, 'Drug Product', CONCEPT_CODE, CONCEPT_CLASS_ID
     FROM concept_stage_sn
     WHERE CONCEPT_CLASS_ID IN
           ('Containered Pack', 'Med Product Pack', 'Trade Product Pack', 'Med Product Unit', 'Trade Product Unit')
       AND concept_name NOT LIKE '%(&)%'
       AND (SELECT count(*) FROM regexp_matches(concept_name, '\sx\s', 'g')) <= 1
       AND concept_name NOT LIKE '%Trisequens, 28%'--exclude packs
     UNION
     SELECT concat(substr(concept_name, 1, 242), ' [Drug Pack]') AS concept_name, 'Drug Product', CONCEPT_CODE,
            CONCEPT_CLASS_ID
     FROM concept_stage_sn
     WHERE CONCEPT_CLASS_ID IN
           ('Containered Pack', 'Med Product Pack', 'Trade Product Pack', 'Med Product Unit', 'Trade Product Unit')
       AND (concept_name LIKE '%(&)%' OR (SELECT count(*) FROM regexp_matches(concept_name, '\sx\s', 'g')) > 1 OR
            concept_name LIKE '%Trisequens, 28%')
     ) AS s0;

DELETE
FROM DRUG_CONCEPT_STAGE
WHERE CONCEPT_CODE IN (SELECT CONCEPT_CODE FROM non_drug);

INSERT INTO drug_concept_stage (concept_name, VOCABULARY_ID, CONCEPT_CLASS_ID, STANDARD_CONCEPT, CONCEPT_CODE,
                                POSSIBLE_EXCIPIENT, domain_id, VALID_START_DATE, VALID_END_DATE, INVALID_REASON,
                                SOURCE_CONCEPT_CLASS_ID)
SELECT DISTINCT concept_name, 'AMT', 'Device', 'S', CONCEPT_CODE, NULL, 'Device',
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
                           JOIN sources.amt_rf2_full_relationships b
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
