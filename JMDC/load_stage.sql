/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Christian Reich, Anna Ostropolets
* Date: 01-23-2017
**************************************************************************/

/*************************************************
* 0. Clean the data and extract non drugs *
*************************************************/
DROP SEQUENCE IF EXISTS new_vocab ;
CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH 10000000 CACHE 20;

-- Radiopharmaceuticals, scintigraphic material and blood products
insert into non_drug
select distinct
  substr(general_name||' '||standardized_unit||' ['||brand_name||']', 1, 255) as concept_name, 'JMDC', 'Device', 'S', drug_code, null, 'Device', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null
  from jmdc
  where
  general_name ~* '(99mTc)|(131I)|(89Sr)|capsule|(123I)|(9 Cl)|(111In)|(13C)|(123I)|(51Cr)|(201Tl)|(133Xe)|(90Y)|(81mKr)|(90Y)|(67Ga)|gadoter|gadopent|manganese chloride tetrahydrate|amino acid|barium sulfate|cellulose,oxidized|purified tuberculin|blood|plasma|diagnostic|nutrition|patch test|free milk|vitamin/|white ointment|simple syrup|electrolyte|allergen extract(therapeutic)|simple ointment' -- cellulose = Surgicel Absorbable Hemostat
  and not general_name ~* 'coagulation|an extract from hemolysed blood' -- coagulation factors

-- Create copy of input data
drop table if exists j;
create table j as
select * from jmdc
where drug_code not in (
  select concept_code from non_drug
);

delete from j
where general_name in ('allergen extract(therapeutic)');

drop table if exists supplier;
create table supplier
as
select trim(substring(brand_name,' \w+$')) as concept_name,drug_code from j -- upper case suppliers in the end of the line
where substring(brand_name,' \w+$')=upper(substring(brand_name,' \w+$'))
and length(substring(brand_name,' \w+$'))>4 and trim(substring(brand_name,' \w+$')) not in ('A240','VIII')
UNION
select trim(substring(brand_name,'^\w+ ')) as concept_name,drug_code from j -- upper case suppliers in the beginning of the line
where substring(brand_name,'^\w+ ')=upper(substring(brand_name,'^\w+ '))
and length(substring(brand_name,'^\w+ '))>4 and trim(substring(brand_name,'^\w+ ')) not in ('A240','VIII')
;
--ingredient
delete from supplier
where drug_code='100000049525'
and concept_name = 'GHRP';

update j
set brand_name = replace(brand_name,substring(brand_name,' \w+$'),'')
where substring(brand_name,' \w+$')=upper(substring(brand_name,' \w+$'))
and length(substring(brand_name,' \w+$'))>4 and trim(substring(brand_name,' \w+$')) not in ('A240','VIII')
;
update j
set brand_name = replace(brand_name,substring(brand_name,'^\w+ '),'')
where substring(brand_name,'^\w+ ')=upper(substring(brand_name,'^\w+ '))
and length(substring(brand_name,'^\w+ '))>4 and trim(substring(brand_name,'^\w+ ')) not in ('A240','VIII')
;
-- Remove pseudo brands
update j
set brand_name = null
where brand_name in (
  'Acrinol and Zinc Oxide Oil',
  'Caffeine and Sodium Benzoate',
  'Compound Oxycodone and Atropine',
  'Crude Drugs',
  'Deleted NHI price',
  'Glycerin and Potash',
  'Morphine and Atropine',
  'Opium Alkaloids and Atropine',
  'Opium Alkaloids and Scopolamine',
  'Phenol and Zinc Oxide Liniment',
  'Scopolia Extract and Tannic Acid',
  'Sulfur and Camphor',
  'Sulfur,Salicylic Acid and Thianthol',
  'Swertia and Sodium Bicarbonate',
  'Weak Opium Alkaloids and Scopolamine',
  '5-FU'
)
or lower(brand_name)=lower(general_name)
or brand_name ~* 'Sulfate|Nitrate|Oxide|Chloride|/|Acid|Sodium|Aluminum|Potassium|Water for Injection|Globulin|Absorptive Ointment|Allergen|Water'
;
update j
set brand_name = null
where brand_name in (
select brand_name
from j
join devv5.concept c on lower(j.brand_name)=lower(c.concept_name)
where c.concept_class_id like '%Ingredient' );

update j
set brand_name = null
where lower(brand_name) in (
select lower(concept_name)
from supplier);

update j
set brand_name = null
where lower(brand_name)||' extract' in (
select lower(general_name)
from j);

update j
set brand_name = null
where length(brand_name)<3;

update j
set brand_name = null
where brand_name like '% %' and brand_name ~ 'NIPPON-ZOKI|KANADA|BIKEN|Antivenom|KITASATO|NICHIIKO|JPS | Equine|Otsujito|Bitter Tincture|Syrup| SW|Concentrate| MED| DSP$| DK$| KN$| KY$| YP$| UJI$| TTS$| MDP$| JG$| KN$|SEIKA|KYOWA|SHOWA|NikP| JCR| NK$| HK$|Japanese Strain| CH$| TCK| FM| Na | Na$| AFP|Gargle|Injection| Ca | Ca$|KOBAYASI| TYK| NIKKO| YD| KOG| FFP| NP| NS| TSU| KOG| SN| TS| NP| YD';

update j
set brand_name = null
where  brand_name ~ 'Tosufloxacin Tosilate|Succinate|OTSUKA|Kenketsu|Ethanol|Powder|JANSSEN|Disinfection|Oral|Gluconate| TN$|FUSO|Sugar| TOA$|Prednisolone Acetate T|I''ROM| BMD$|^KTS |Taunus Aqua|Cefamezin alfa|Bromide|Vaccine';

update j
set brand_name = null
where  brand_name ~ 'ASAHI| CMX|Lawter Leaf|Kakkontokasenkyushin| HMT|Saikokeishito|Dibasic Calcium Phosphate| Hp$| F$| HT$| TC$| AA$| MP$|Freeze-dried| AY$| KTB| CEO|Ethyl Aminobenzoate| QQ$|Viscous|Tartrate|NIPPON| EE$|Tincture';

-- multi-ingredients fixes
update j
set general_name = 'ampicillin sodium/sulbactam sodium'
where general_name = 'sultamicillin tosilate hydrate';

update j
set general_name = 'follicle stimulating hormone/luteinizing hormone'
where general_name = 'human menopausal gonadotrophin';

update j
set general_name = 'human normal immunoglobulin/histamine'
where general_name = 'immunoglobulin with histamine';

update j
set general_name = 'human normal immunoglobulin/histamine'
where general_name = 'immunoglobulin with histamine';

-- remove junk from standard_unit
update j set standardized_unit = regexp_replace(standardized_unit, '\(forGeneralDiagnosis\)', '') where standardized_unit like '%(forGeneralDiagnosis)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(forGeneralDiagnosis/forOnePerson\)', '') where standardized_unit like '%(forGeneralDiagnosis/forOnePerson)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(forStrongResponsePerson\)', '') where standardized_unit like '%(forStrongResponsePerson)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(MixedPreparedInjection\)', '') where standardized_unit like '%(MixedPreparedInjection)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'w/NS', '') where standardized_unit like '%w/NS%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Soln\)', '') where standardized_unit like '%(w/Soln)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asSoln\)', '') where standardized_unit like '%(asSoln)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/DrainageBag\)', '') where standardized_unit like '%(w/DrainageBag)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Sus\)', '') where standardized_unit like '%(w/Sus)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asgoserelin\)', '') where standardized_unit like '%(asgoserelin)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(Amountoftegafur\)', '') where standardized_unit like '%(Amountoftegafur)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(as levofloxacin\)', '') where standardized_unit like '%(as levofloxacin)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(as phosphorus\)', '') where standardized_unit like '%(as phosphorus)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asActivatedform\)', '') where standardized_unit like '%(asActivatedform)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'teriparatideacetate', '') where standardized_unit like '%teriparatideacetate%';
update j set standardized_unit = regexp_replace(standardized_unit, 'Elcatonin', '') where standardized_unit like '%Elcatonin%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asSuspendedLiquid\)', '') where standardized_unit like '%(asSuspendedLiquid)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(mixedOralLiquid\)', '') where standardized_unit like '%(mixedOralLiquid)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Soln,Dil\)', '') where standardized_unit like '%(w/Soln,Dil)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'DomesticStandard', '') where standardized_unit like '%DomesticStandard%';
update j set standardized_unit = regexp_replace(standardized_unit, 'million', '000000') where standardized_unit like '%million%';
update j set standardized_unit = regexp_replace(standardized_unit, 'U\.S\.P\.', '') where standardized_unit like '%U.S.P.%';
update j set standardized_unit = regexp_replace(standardized_unit, 'about', '') where standardized_unit like '%about%';
update j set standardized_unit = regexp_replace(standardized_unit, 'iron', '') where standardized_unit like '%iron%';
update j set standardized_unit = regexp_replace(standardized_unit, ':240times', '') where standardized_unit like '%:240times%';
update j set standardized_unit = regexp_replace(standardized_unit, 'low\-molecularheparin', '') where standardized_unit like '%low-molecularheparin%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asCalculatedamountofD\-arabinose\)', '') where standardized_unit like '%(asCalculatedamountofD-arabinose)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'w/5%GlucoseInjection', '') where standardized_unit like '%w/5\%GlucoseInjection%' escape '\';
update j set standardized_unit = regexp_replace(standardized_unit, 'w/WaterforInjection', '') where standardized_unit like '%w/WaterforInjection%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/SodiumBicarbonate\)', '') where standardized_unit like '%(w/SodiumBicarbonate)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'potassium', '') where standardized_unit like '%potassium%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(Amountoftrifluridine\)', '') where standardized_unit like '%(Amountoftrifluridine)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'FRM', '') where standardized_unit like '%FRM%';
update j set standardized_unit = regexp_replace(standardized_unit, 'NormalHumanPlasma', '') where standardized_unit like '%NormalHumanPlasma%';
update j set standardized_unit = regexp_replace(standardized_unit, 'Anti-factorXa', '') where standardized_unit like '%Anti-factorXa%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/SodiumBicarbonateSoln\)', '') where standardized_unit like '%(w/SodiumBicarbonateSoln)%';
update j set standardized_unit = regexp_replace(standardized_unit, ',CorSoln', '') where standardized_unit like '%,CorSoln%';
update j set standardized_unit = regexp_replace(standardized_unit, '1Set', '') where standardized_unit like '%1Set%';
update j set standardized_unit = regexp_replace(standardized_unit, 'AmountforOnce', '') where standardized_unit like '%AmountforOnce%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Dil\)', '') where standardized_unit like '%(w/Dil)%';

/*************************************************
* 1. Create parsed Ingredients and relationships *
*************************************************/
DROP TABLE if exists PI;
CREATE TABLE pi
AS
SELECT drug_code, general_name AS ing_name
FROM j
WHERE general_name NOT LIKE '%/%' AND general_name NOT LIKE '% and %'
UNION
SELECT drug_code, ing_name
FROM (SELECT drug_code, REPLACE(general_name,' and ','/') AS concept_name
      FROM j) j,
     UNNEST(STRING_TO_ARRAY(j.concept_name,'/')) AS ing_name;

delete from pi
where ing_name = 'rhizome'--eliminating wrong parsing
;
update pi
set ing_name = trim(regexp_replace (ing_name,'\(genetical recombination\)',''))
where ing_name ~ 'genetical recombination';

insert into pi
select drug_code, concept_name
from pi join aut_parsed_ingr
using (ing_name);

/************************************
* 2. Populate drug concept stage *
*************************************/
-- Drugs
insert into drug_concept_stage
select distinct
  case when brand_name is not null then substr(general_name||' '||standardized_unit||' ['||brand_name||']', 1, 255) else substr(general_name||' '||standardized_unit, 1, 255)  end as concept_name,
  'JMDC' as vocabulary_id,
  'Drug Product' as concept_class_id,
  null as standard_concept,
  drug_code as concept_code,
  null as possible_excipient,
   'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from j;

-- Devices
insert into drug_concept_stage
select * from non_drug;

-- Ingredients
insert into drug_concept_stage
select
  ing_name as concept_name,
  'JMDC' as vocabulary_id,
  'Ingredient' as concept_class_id,
  null as standard_concept,
  'OMOP'||nextval('new_vocab') as concept_code,
  null as possible_excipient,
  'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
  from ( select distinct ing_name
from pi) a;

-- Brand Name
insert into drug_concept_stage
select
  brand_name as concept_name,
  'JMDC' as vocabulary_id,
  'Brand Name' as concept_class_id,
  null as standard_concept,
  'OMOP'||nextval('new_vocab') as concept_code,
  null as possible_excipient,
  'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from
(select distinct brand_name from j where brand_name is not null) a
;

-- Dose Forms
-- Create rough dose forms
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
  values ('Inhalant', 'JMDC', 'Dose Form', null, 'Inhalant', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
  values ('Capsule', 'JMDC', 'Dose Form', null, 'Capsule', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
  values ('Tablet', 'JMDC', 'Dose Form', null, 'Tablet', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
  values ('Injectant', 'JMDC', 'Dose Form', null, 'Injectant', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
  values ('Topical', 'JMDC', 'Dose Form', null, 'Topical', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
  values ('Patch', 'JMDC', 'Dose Form', null, 'Patch', 'Drug',to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
--insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
--  values ('Unknown', 'JMDC', 'Dose Form', null, 'OMOP'||nextval('new_vocab'), null, to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);

-- Units
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('u', 'JMDC', 'Unit', null, 'u', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('iu', 'JMDC', 'Unit', null, 'iu', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('g', 'JMDC', 'Unit', null, 'g', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('mg', 'JMDC', 'Unit', null, 'mg', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('mlv', 'JMDC', 'Unit', null, 'mlv', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('ml', 'JMDC', 'Unit', null, 'ml', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('%', 'JMDC', 'Unit', null, '%', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('%', 'JMDC', 'Unit', null, 'mcg', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('%', 'JMDC', 'Unit', null, 'actuat', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('%', 'JMDC', 'Unit', null, 'mol', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);

--Supplier
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
select
  concept_name,
  'JMDC' as vocabulary_id,
  'Supplier' as concept_class_id,
  null as standard_concept,
   'OMOP'||nextval('new_vocab') as concept_code,
   'Drug',
  to_date('19700101','YYYYMMDD'),
  to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from (
  select distinct concept_name from supplier) s;

/*************************************************
* 3. Populate IRS *
*************************************************/

-- 3.1 create relationship between products and ingredients
insert into internal_relationship_stage
select distinct
  pi.drug_code as concept_code_1,
  dcs.concept_code as concept_code_2
from pi join drug_concept_stage dcs on dcs.concept_name=pi.ing_name and dcs.concept_class_id='Ingredient';


-- 3.2 create relationship between products and BN
insert into internal_relationship_stage
select distinct
  j.drug_code as concept_code_1,
  dcs.concept_code as concept_code_2
from j join drug_concept_stage dcs on dcs.concept_name=j.brand_name and dcs.concept_class_id='Brand Name'
;
-- 3.3 create relationship between products and DF
insert into internal_relationship_stage
with u as (
  select drug_code,
    case
      when u2='bls' then 'Inhalant'
      when u2='c' then 'Capsule'
      when u2='t' then 'Tablet'
      when u1='u' and u2='mlv' then 'Injectant'
      when u2 in ('kit', 'syg', 'a', 'v') then 'Injectant'
      when u3 in ('kit', 'syg', 'a', 'v') then 'Injectant'
      when u1='g' and u2 is null and u3 is null then 'Topical'
      when u3='bot' then 'Topical'
      when u1='mg' and u2='ml' and u3 is null then 'Topical'
      when u1='mg' and u2='g' and u3 is null then 'Topical'
      else 'Unknown'
    end as df
  from (
    select
      drug_code,
      replace(cast(substr(dose, s1+1, s2-s1) as varchar(20)),'|','') as u1,
      replace(cast(substr(dose, s3+1, s4-s3) as varchar(20)),'|','') as u2,
      cast(substr(dose, s5+1) as varchar(20)) as u3
    from (
      select
        drug_code, dose,
        instr(dose, '|', 1, 1) as s1, instr(dose, '|', 1, 2) as s2, instr(dose, '|', 1, 3) as s3, instr(dose, '|', 1, 4) as s4, instr(dose, '|', 1, 5) as s5
      from (
        select
          drug_code,
          regexp_replace(lower(translate(standardized_unit, 'a(),', 'a')), '([0-9\.,]+)([a-z%]+)([0-9\.,]+)?([a-z%]+)?([0-9\.,]+)?([a-z%]+)?', '\1|\2|\3|\4|\5|\6') as dose
        from j -- join drug_concept_stage dcs on dcs.concept_code=j.drug_code
        where standardized_unit not like '%Sheet%' and standardized_unit not like '%cm*%' and standardized_unit not like '%mm*%'
        and drug_code not in ('100000063966', '100000013362') -- immunoglobulin with histamine, bacitracin/fradiomycin sulfate - ??????????
      ) a
    ) b
  ) c
)
select distinct
  u.drug_code as concept_code_1,
  df.concept_code as concept_code_2
from u join drug_concept_stage df on df.concept_name=u.df and df.concept_class_id='Dose Form'
;

-- 3.3.1. Patches
insert into internal_relationship_stage
select distinct
  drug_code as concept_code_1,
  (select concept_code from drug_concept_stage where concept_name='Patch') as concept_code_2
from j where standardized_unit like '%Sheet%' or standardized_unit like '%cm*%' or standardized_unit like '%mm*%'
;

-- 3.3.2 Manual ones
insert into internal_relationship_stage (concept_code_1, concept_code_2)
  values ('100000063966', (select concept_code from drug_concept_stage where concept_name='Injectant')); -- immunoglobulin with histamine
insert into internal_relationship_stage (concept_code_1, concept_code_2)
  values ('100000013362', (select concept_code from drug_concept_stage where concept_name='Topical')); -- bacitracin/fradiomycin sulfate

-- 3.3.3 Suppliers
insert into internal_relationship_stage (concept_code_1, concept_code_2)
    select drug_code,concept_code
    from supplier join drug_concept_stage using (concept_name)
where concept_class_id = 'Supplier';

/*********************************
* 4. Create and link Drug Strength
*********************************/
--g|mg|ug|mEq|MBq|IU|KU|U
INSERT into ds_stage
SELECT DISTINCT j.drug_code,
                dcs.concept_code,
                CAST(substring(regexp_replace(standardized_unit, '[,()]', '', 'g') from '^(\d+\.*\d*)(?=(g|mg|ug|mEq|MBq|IU|KU|U)(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($))') as double precision),
                substring(regexp_replace(standardized_unit, '[,()]', '', 'g') from '(?<=^(\d+\.*\d*))(g|mg|ug|mEq|MBq|IU|KU|U)(?=(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($))')
FROM j
         JOIN pi ON j.drug_code = pi.drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name
WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, '[,()]', '', 'g') ~ '^(\d+\.*\d*)(g|mg|ug|mEq|MBq|IU|KU|U)(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($)'
  AND dcs.concept_class_id = 'Ingredient';

--liquid % / ml|l
INSERT into ds_stage
SELECT DISTINCT j.drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(standardized_unit from '^(\d+\.*\d*)(?=(%)(\d+\.*\d*)(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') as double precision)
                    * CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)' THEN 10
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'  THEN 10000 END,
                'mg',
                CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)' THEN 1
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'  THEN 1000 END,
                'ml'
FROM j
         JOIN pi ON j.drug_code = pi.drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'
  AND dcs.concept_class_id = 'Ingredient';

--solid % / g|mg
INSERT into ds_stage
SELECT DISTINCT j.drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(standardized_unit from '^(\d+\.*\d*)(?=(%)(\d+\.*\d*)(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') as double precision)
                    * CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(g)(|1Pack|1Bot|1can|1V|1Pc)($)' THEN 10
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg)(|1Pack|1Bot|1can|1V|1Pc)($)'  THEN 0.01 END,
                'mg',
                CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(g)(|1Pack|1Bot|1can|1V|1Pc)($)' THEN 1000
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg)(|1Pack|1Bot|1can|1V|1Pc)($)'  THEN 1 END,
                'mg'
FROM j
         JOIN pi ON j.drug_code = pi.drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($)'
  AND dcs.concept_class_id = 'Ingredient';

--mg|mol|ug|g|IU|U|mEq / mL|uL|g
INSERT into ds_stage
SELECT DISTINCT j.drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(regexp_replace(standardized_unit, ',', '', 'g') from '^(\d+\.*\d*)(?=(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))') as double precision),
                substring(regexp_replace(standardized_unit, ',', '', 'g') from '(?<=^(\d+\.*\d*))(mg|mol|ug|g|IU|U|mEq)(?=(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))'),
                CAST(substring(regexp_replace(standardized_unit, ',', '', 'g') from '(?<=^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq))(\d+\.*\d*)(?=(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))') as double precision),
                substring(regexp_replace(standardized_unit, ',', '', 'g') from '(?<=^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*))(mL|uL|g)(?=(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))')
FROM j
         JOIN pi ON j.drug_code = pi.drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, ',', '', 'g') ~ '^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- ug/actuat1
INSERT into ds_stage
SELECT DISTINCT j.drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(standardized_unit from '^(\d+\.*\d*)(?=(ug)(\d+\.*\d*)(Bls)(1Pc|1Kit)($))') as double precision)
                    * CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(ug))(\d+\.*\d*)(?=(Bls)(1Pc|1Kit)($))') as double precision),
                substring(standardized_unit from '(?<=^(\d+\.*\d*))(ug)(?=(\d+\.*\d*)(Bls)(1Pc|1Kit)($))'),
                CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(ug))(\d+\.*\d*)(?=(Bls)(1Pc|1Kit)($))') as double precision),
                'actuat'
FROM j
         JOIN pi ON j.drug_code = pi.drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(ug)(\d+\.*\d*)(Bls)(1Pc|1Kit)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- ug/actuat2
INSERT into ds_stage
SELECT DISTINCT j.drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '^(\d+\.*\d*)(?=(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($))') as double precision),
                substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '(?<=^(\d+\.*\d*))(mg|ug)(?=(1Bot|1Kit)(\d+\.*\d*)(ug)($))'),
                CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '^(\d+\.*\d*)(?=(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($))') as double precision)
                    * CASE  WHEN regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($)' THEN 1
                            WHEN regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(mg)(1Bot|1Kit)(\d+\.*\d*)(ug)($)'  THEN 1000 END
                    / CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '(?<=^(\d+\.*\d*)(mg|ug)(1Bot|1Kit))(\d+\.*\d*)(?=(ug)($))') as double precision),
                'actuat'
FROM j
         JOIN pi ON j.drug_code = pi.drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($)'
  AND dcs.concept_class_id = 'Ingredient';

--g|mg from kits
INSERT into ds_stage
SELECT DISTINCT j.drug_code,
                dcs.concept_code,
                CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '^(\d+\.*\d*)(?=(g|mg)(1Kit)(\d+\.*\d*)(mL))') as double precision),
                substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '(?<=^(\d+\.*\d*))(g|mg)(?=(1Kit)(\d+\.*\d*)(mL))')
FROM j
         JOIN pi ON j.drug_code = pi.drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(g|mg)(1Kit)(\d+\.*\d*)(mL)'
  AND dcs.concept_class_id = 'Ingredient';

update ds_stage
set amount_unit = lower(amount_unit),
    numerator_unit = lower(numerator_unit),
    denominator_unit = lower(denominator_unit);

update ds_stage
  set amount_unit = 'mcg'
    where amount_unit = 'ug';

update ds_stage
  set numerator_unit = 'mcg'
    where numerator_unit = 'ug';

/************************************************
* 5. Populate relationship to concept *
************************************************/

-- Write mappings to RxNorm Dose Forms

Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082225, 1); --Topical Lotion
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082224, 2); --Topical Cream
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 40228565, 3); --Oil
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082228, 4); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095912, 5); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 46234410, 6); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082227, 7); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082226, 8); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095972, 9); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095973, 10); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082628, 11); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19135438, 12); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19135446, 13); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19135439, 14); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19135440, 15); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19129401, 16); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082287, 17); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19135925, 18); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082194, 19); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095975, 20); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082164, 21); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19110977, 22); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082161, 23); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082576, 24); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082169, 25); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082193, 26); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082197, 27); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19010878, 28); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19112544, 29); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082163, 30); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082166, 31); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095916, 32); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095917, 33); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095974, 34); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19010880, 35); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19011932, 36); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095900, 37); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19011167, 38); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095911, 39); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082281, 40); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082199, 41); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095899, 42); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19112649, 43); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082110, 44); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082165, 45); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082195, 46); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 45775488, 47); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19095977, 48); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082167, 49); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082196, 50); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19082102, 51); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'JMDC', 19010879, 52); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19127579, 1); --Dry Powder Inhaler
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19082259, 2); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19095898, 3); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19126918, 4); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19082162, 5); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19126919, 6); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19082258, 7); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'JMDC', 19018195, 8); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Capsule', 'JMDC', 19082168, 1); --Oral Capsule
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Capsule', 'JMDC', 19082077, 2); --Extended Release Oral Capsule
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Capsule', 'JMDC', 19082255, 3); --Delayed Release Oral Capsule
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Capsule', 'JMDC', 19103220, 4); --12 hour Extended Release Capsule
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Capsule', 'JMDC', 19082256, 5); --24 Hour Extended Release Capsule
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Capsule', 'JMDC', 19021887, 6); --Capsule
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082573, 1); --Oral Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082076, 2); --Disintegrating Oral Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19001949, 3); --Delayed Release Oral Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082079, 4); --Extended Release Oral Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19135866, 5); --Chewable Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082285, 6); --Sublingual Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19010962, 7); --Vaginal Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082253, 8); --Oral Lozenge
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 40175589, 9); --Buccal Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082050, 10); --24 Hour Extended Release Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082048, 11); --12 hour Extended Release Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 44817840, 12); --Effervescent Oral Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19001943, 13); --Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Tablet', 'JMDC', 19082222, 14); --Sustained Release Buccal Tablet
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19082103, 2); --Injectable Solution
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 46234469, 1); --Injection
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19082104, 3); --Injectable Suspension
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19126920, 4); --Prefilled Syringe
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 46234467, 5); --Pen Injector
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 46234466, 6); --Auto-Injector
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 44784844, 7); --Injectable Foam
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 46234468, 8); --Cartridge
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19095913, 9); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19095914, 10); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19082105, 11); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 46275062, 12); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19095915, 13); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injectant', 'JMDC', 19082260, 14); --
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'JMDC', 19082229, 1); -- transdermal system
Insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'JMDC', 19130307, 2); -- medicated pad

-- write mappings to real units
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('u', 'JMDC', 8510, 1, 1); -- to unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('iu', 'JMDC', 8510, 1, 1); -- to unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('g', 'JMDC', 8576, 1, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('g', 'JMDC', 8587, 2, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mg', 'JMDC', 8576, 1, 1); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mg', 'JMDC', 8587, 2, 0.001); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mlv', 'JMDC', 8587, 1, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mlv', 'JMDC', 8576, 2, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ml', 'JMDC', 8587, 1, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mcg', 'JMDC', 8576, 1, 0.001); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('%', 'JMDC', 8554, 2, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('actuat', 'JMDC', 45744809, 1, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mol', 'JMDC', 9573, 1, 0.01);


-- Ingredients
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',concept_id,rank() over (partition by dc.concept_code order by concept_id)
from aut_ingredient_mapped_2
join drug_concept_stage dc on dc.concept_name = source_concept_name and concept_class_id = 'Ingredient'
where flag!=0;

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',cast(concept_id_2 as int), case when precedence is null then 1 else precedence end
from aut_ingredient_mapped a
join drug_concept_stage dc on dc.concept_name = a.concept_name and concept_class_id = 'Ingredient'
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code)
;

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',concept_id, rank() over (partition by dc.concept_code order by concept_id)
from aut_parsed_ingr a
join drug_concept_stage dc
on lower(dc.concept_name) = lower(a.ing_name) and dc.concept_class_id = 'Ingredient'
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code);

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',concept_id, rank() over (partition by dc.concept_code order by concept_id)
from aut_parsed_ingr a
join drug_concept_stage dc
on lower(dc.concept_name) = lower(a.ing_name) and dc.concept_class_id = 'Ingredient'
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code);

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c2.concept_id, rank() over (partition by dc.concept_code order by c2.concept_id)
from drug_concept_stage dc
left join relationship_to_concept r on concept_code = concept_code_1
join concept c2 on lower(C2.concept_name) = lower(dc.concept_name)
where dc.concept_class_id = 'Ingredient' and concept_id_2 is  null
and c2.standard_concept = 'S' and c2.concept_class_id = 'Ingredient';

--precise ingredients
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code, 'JMDC',c3.concept_id, 1
from drug_concept_stage dc
left join relationship_to_concept r on concept_code = concept_code_1
join devv5.concept c2 on lower(C2.concept_name) = lower(dc.concept_name)
join devv5.concept_relationship cr on cr.concept_id_1 = c2.concept_id
join devv5.concept c3 on c3.concept_id = cr.concept_id_2
where dc.concept_class_id = 'Ingredient' and r.concept_id_2 is  null
and c2.concept_class_id = 'Precise Ingredient' and c3.concept_class_id = 'Ingredient'
and cr.invalid_reason is null and c3.standard_concept = 'S'
;

-- Brand Names
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c.concept_id, rank() over (partition by dc.concept_code order by c.concept_id)
from drug_concept_stage dc
join devv5.concept c on lower(c.concept_name) = lower(dc.concept_name)
where dc.concept_class_id = 'Brand Name'
and c.concept_class_id = 'Brand Name' and c.vocabulary_id like 'Rx%' and c.invalid_reason is null
;
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c2.concept_id, rank() over (partition by dc.concept_code order by c2.concept_id)
from drug_concept_stage dc
join devv5.concept c on lower(c.concept_name) = lower(dc.concept_name) and c.invalid_reason = 'U' and c.concept_class_id = 'Brand Name'
join devv5.concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.invalid_reason is null
join devv5.concept  c2 on cr.concept_id_2 = c2.concept_id and relationship_id = 'Concept replaced by'
where dc.concept_class_id = 'Brand Name'
and dc.concept_code not in (select concept_code_1 from relationship_to_concept);
;

-- supplier
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c.concept_id, rank() over (partition by dc.concept_code order by c.concept_id)
from drug_concept_stage dc
join devv5.concept c on lower(c.concept_name) = lower(dc.concept_name)and c.concept_class_id = 'Supplier'
and c.invalid_reason is null and c.vocabulary_id = 'RxNorm Extension'
where dc.concept_class_id = 'Supplier'
and dc.concept_code not in (select concept_code_1 from relationship_to_concept);


/*****POST-PROCESSING*****/
-- Delete Suppliers where DF or strength doesn't exist

DELETE
	FROM internal_relationship_stage
			where concept_code_1 in
	 (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
		WHERE drug_concept_code IS NULL

		UNION

		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		WHERE concept_code_1 NOT IN (
				SELECT concept_code_1
				FROM internal_relationship_stage
				JOIN drug_concept_stage ON concept_code_2 = concept_code
					AND concept_class_id = 'Dose Form'
				)
		)
and concept_code_2 in
			(select concept_code from drug_concept_stage where concept_class_id = 'Supplier')
;
