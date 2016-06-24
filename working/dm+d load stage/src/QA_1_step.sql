--QA with minor issues, anyway working
  select error_type, count (1) from ( 
  select a.concept_code, 'different classes in concept_code_1 and concept_id_2' as error_type from relationship_to_concept r 
  join drug_concept_stage a on a.concept_code= r.concept_code_1 
  join devv5.concept c on c.concept_id = r.concept_id_2 and c.vocabulary_id = 'RxNorm'
  where  a.concept_class_id !=  c.concept_class_id
  and a.domain_id = 'Drug'
  union
  --concept_id's that don't exist
  select a.concept_code, 'concept_id_2 exists but doesnt belong to any concept' from relationship_to_concept r 
  join drug_concept_stage a on a.concept_code= r.concept_code_1 
  left join devv5.concept c on c.concept_id = r.concept_id_2  
  where  c.concept_name is  null
  and a.domain_id = 'Drug'
  union 
  -- 2. ds_stage
  --look if we have some strange amount_units
  --expand this table with units, need to think about
   select distinct drug_concept_code, 'amount_unit doesnt exist in concept_table' from ds_stage where amount_unit not in (select concept_name from drug_concept_stage where concept_class_id ='Unit')
   union
  select distinct drug_concept_code, 'amount_unit doesnt exist in expected list' from ds_stage where UPPER ( amount_unit) not in ('G', 'MG', 'KG', 'UNITS', 'UNIT','MIU','IU', 'MMOL', 'MOL','CELL','MU','L', 'ML', 'MEQ', 'MCG','CFU', 'MCCI','CH','DOSE','GALU','K','D','M','C','X','DH','B','PPM','TM','XMK')
  union
  select distinct drug_concept_code, 'numerator_unit doesnt exist in expected list'  from ds_stage where UPPER ( numerator_unit) not in (
  'LF','TUB','U','LOG10 PFU','KIU','CCID50','MCMOL','%','GAL','PFU','LOG10 TCID50','CMK','MCL','FFU',
  'G', 'MG', 'KG', 'UNITS', 'UNIT','MIU','IU', 'MMOL', 'MOL','CELL','MU','L', 'ML', 'MEQ', 'MCG','CFU', 'MCCI','CH','DOSE','GALU','K','D','M','C','X','DH','B','PPM','TM','XMK')
  union
  select distinct drug_concept_code, 'denominator_unit doesnt exist in expected list' from ds_stage where denominator_unit not in ('MG','Kg','ACT','SQ CM','CC','UNIT','CM','C','GM','TM','ML','L','G','HOUR','MCL')
  union
  -- drug codes are not exist in a drug_concept_stage but present in ds_stage
  select distinct s.drug_concept_code, 'ds_stage has drug_codes absent in drug_concept_stage' from ds_stage s 
  left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id like  '%Drug%'
  left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
  where a.concept_code is null and a.domain_id ='Drug'
  union
  -- ingredient codes not exist in a drug_concept_stage but present in ds_stage
  select distinct s.drug_concept_code, 'ds_stage has ingredient_codes absent in drug_concept_stage' from ds_stage s 
  left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id like '%Drug%'
  left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
  where b.concept_code is null 
  union
  --strange entries combinations in ds_stage table
  select distinct s.drug_concept_code, 'impossible combination of values and units in ds_stage' from ds_stage s where AMOUNT_VALUE is not null and AMOUNT_UNIT is null or 
  (denominator_VALUE is not null and denominator_UNIT is null) or (NUMERATOR_VALUE is not null and denominator_UNIT is null and DENOMINATOR_VALUE is null and NUMERATOR_UNIT !='%')
  or (AMOUNT_VALUE is  null and AMOUNT_UNIT is not null)
  union
  -- drugs aren't present in drug_strength table
  select distinct concept_code, 'Drug product doesnt have drug_strength info' from drug_concept_stage
   where concept_code not in (select drug_concept_code from ds_stage) and concept_class_id like '%Drug%' and concept_class_id not like '%Pack%' and domain_id ='Drug'
  union
  --Quantitive drugs don't have denominator value or DENOMINATOR_unit
  select distinct A.CONCEPT_CODE, 'Quantitive drug doesnt have denominator value or DENOMINATOR_unit'  from drug_concept_stage a join  ds_stage s on a.concept_code = s.drug_concept_code and a.concept_class_id like '%Quant%' 
  and (s.DENOMINATOR_VALUE is null or DENOMINATOR_unit is null) and domain_id ='Drug'
  union
  --Different DENOMINATOR_VALUE or DENOMINATOR_VALUE in the same drug
  select distinct a.drug_concept_code, 'Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug' 
   from ds_stage a join ds_stage b on a.drug_concept_code = b.drug_concept_code 
   and (a.DENOMINATOR_VALUE is null and b.DENOMINATOR_VALUE is not null  
   or a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
   or a.DENOMINATOR_unit != b.DENOMINATOR_unit)
  union
  --different values for the same ingredient and drug, look separately on numerator_value, DENOMINATOR_VALUE and Units
  select a.drug_concept_code, 'different dosage for the same drug-ingredient combination' 
  from ds_stage a join ds_stage b on a.drug_concept_code = b.drug_concept_code and a.INGREDIENT_CONCEPT_CODE = b.INGREDIENT_CONCEPT_CODE and (
  a.numerator_value != b.numerator_value or a.numerator_unit != b.numerator_unit or a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE or a.DENOMINATOR_unit != b.DENOMINATOR_unit
  or a.numerator_value is null and  b.numerator_value is not null or a.numerator_unit is null and  b.numerator_unit is not null or a.DENOMINATOR_VALUE is null and b.DENOMINATOR_VALUE is not null or 
  a.DENOMINATOR_unit is null and b.DENOMINATOR_unit is not null
  )
  union
  --3. internal_relationship
  --missing relationships:
  --Branded Drug to Brand Name
  select distinct concept_code,'Missing relationship to Brand Name'  from drug_concept_stage where concept_class_id like '%Branded%' and concept_code not in(
  select a.concept_code from  drug_concept_stage a 
  join internal_relationship_stage s on s.concept_code_1= a.concept_code  
  join drug_concept_stage b on b.concept_code = s.concept_code_2
   and  
   a.concept_class_id like '%Branded%' and b.concept_class_id ='Brand Name' 
  ) and  domain_id = 'Drug'
  union
  --Drug to Ingredient
  select distinct concept_code,'Missing relationship to Ingredient'  from drug_concept_stage where concept_class_id like '%Drug%' and concept_code not in(
  select a.concept_code from  drug_concept_stage a 
  join internal_relationship_stage s on s.concept_code_1= a.concept_code  
  join drug_concept_stage b on b.concept_code = s.concept_code_2
   and  a.concept_class_id like '%Drug%' and b.concept_class_id ='Ingredient'
  ) and concept_class_id not like '%Pack%'
  and domain_id = 'Drug'

  union
  --Drug (non Component) to Form
  select distinct concept_code,'Missing relationship to Dose Form'  from drug_concept_stage where concept_class_id like '%Drug%' and concept_class_id not like '%Comp%' and concept_code not in(
  select a.concept_code from  drug_concept_stage a 
  join internal_relationship_stage s on s.concept_code_1= a.concept_code  
  join drug_concept_stage b on b.concept_code = s.concept_code_2
   and  a.concept_class_id like '%Drug%' and a.concept_class_id not like '%Comp%' and b.concept_class_id ='Dose Form' 
  )
  and domain_id = 'Drug' and concept_class_id not like '%Pack%'
  union
  --several brand names
  select distinct a.concept_code,'Drug has more than one brand names' from drug_concept_stage a 
  join internal_relationship_stage s on a.concept_code = s.concept_code_1
  join drug_concept_stage b on b.concept_code =s.concept_code_2
  and b.concept_class_id = 'Brand Name'
  where a.concept_code in (
  select a.concept_code from drug_concept_stage a 
  join internal_relationship_stage s on a.concept_code = s.concept_code_1
  join drug_concept_stage b on b.concept_code =s.concept_code_2
  and b.concept_class_id = 'Brand Name'
  group by a.concept_code having count(1) >1)
  and b.domain_id = 'Drug'
  union
  --several Dose forms
  select distinct a.concept_code,'Drug has more than one Dose form'  from drug_concept_stage a 
  join internal_relationship_stage s on a.concept_code = s.concept_code_1
  join drug_concept_stage b on b.concept_code =s.concept_code_2
  and b.concept_class_id = 'Dose Form'
  where a.concept_code in (
  select a.concept_code from drug_concept_stage a 
  join internal_relationship_stage s on a.concept_code = s.concept_code_1
  join drug_concept_stage b on b.concept_code =s.concept_code_2
  and b.concept_class_id = 'Dose Form'
  group by a.concept_code having count(1) >1)
  union
  --4.drug_concept_stage
  --duplicates in drug_concept_stage table
  select distinct concept_code,'Duplicate concept' from drug_concept_stage  
  where concept_code in (
  select concept_code from drug_concept_stage group by concept_code having count(8)>1)
  union
  --same names for different drug classes
  select concept_code, 'same names for different non-drug concepts'  from drug_concept_stage where trim(lower(concept_name)) in (
    select trim(lower(concept_name)) as n from drug_concept_stage where concept_class_id in ('Brand Name', 'Dose Form', 'Unit', 'Ingredient') group by trim(lower(concept_name)) having count(8)>1)
    union
  --short names but not a Unit
  select concept_code, 'short names but not a Unit' from drug_concept_stage where length(concept_name)=1 and concept_class_id not in ('Unit')
  union 
  --concept_name is null
  select concept_code,'concept_name is null' from drug_concept_stage where concept_name is null
  union
  --same concept_code_1 - concept_id_2 relationship but different precedence
  select distinct a.concept_code_1, 'same concept_code_1 - concept_id_2 relationship but different precedence' from relationship_to_concept a 
  join relationship_to_concept b on a.CONCEPT_CODE_1 =b.CONCEPT_CODE_1 and a.CONCEPT_ID_2 = b.concept_id_2 and a.precedence !=b.precedence
  union
  --Brand Name doesnt relate to any drug
  select distinct a.concept_code, 'Brand Name doesnt relate to any drug' from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
  where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null
  union
  --Ingredient doesnt relate to any drug
  select distinct a.concept_code, 'Ingredient doesnt relate to any drug' from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
  where a.concept_class_id= 'Ingredient' and b.concept_code_1 is null
  union
  --Dose Form doesnt relate to any drug
  select distinct a.concept_code, 'Dose Form doesnt relate to any drug' from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
  where a.concept_class_id= 'Dose Form' and b.concept_code_1 is null
  union
  --duplicates in ds_stage
  select drug_concept_code, 'duplicates in ds_stage'  from (
  select drug_concept_code, ingredient_concept_code, count(*) as cnt
  from ds_stage 
  group by drug_concept_code, ingredient_concept_code having count(*)>1
  )
  union
  --Concept_code_1 - Precedence duplicates
  select concept_code_1, 'Concept_code_1 - precedence duplicates' from (
  select  concept_code_1,precedence from relationship_to_concept group by concept_code_1,precedence having count (1) >1 )
  union
  ----Concept_code_1 - Ingredient duplicates
  select concept_code_1, 'Concept_code_1 - precedence duplicates' from (
  select  concept_code_1,concept_id_2 from relationship_to_concept group by concept_code_1,concept_id_2 having count (1) >1 )
  union
  --Unit without mapping
  select CONCEPT_CODE, 'Unit without mapping' from 
  drug_concept_Stage a left join relationship_to_concept b on a.concept_code = b.concept_code_1
  where concept_class_id in('Unit') and b.concept_code_1 is null
  union
  --Dose Form without mapping
  select CONCEPT_CODE, 'Dose Form without mapping' from 
  drug_concept_Stage a left join relationship_to_concept b on a.concept_code = b.concept_code_1
  where concept_class_id in('Dose Form') and b.concept_code_1 is null
  union
  --duplicates will be present in drug_concept_stage, unable to summarize values
  select distinct   concept_code, 'concept overlaps with other one by target concept, please look also onto rigth sight of query result' from (
  select distinct a.amount_unit, a.numerator_unit ,cs.concept_code,  cs.concept_name as canada_name, rc.concept_name as RxName  , a.drug_concept_code from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
  join drug_Concept_stage cs on cs.concept_code = a.ingredient_concept_code
  join devv5.concept rc on rc.concept_id = b.concept_id_2
  join drug_Concept_stage rd on rd.concept_code = a.drug_concept_code
  join (
  select a.drug_concept_code, b.concept_id_2 from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
  group by a.drug_concept_code, b.concept_id_2 having count (1) > 1) c 
  on c.DRUG_CONCEPT_CODE= a.DRUG_CONCEPT_CODE and c.CONCEPT_ID_2 = b.CONCEPT_ID_2
  where precedence = 1) a
  join 
  (
  select distinct a.amount_unit, a.numerator_unit , cs.concept_name as canada_name, rc.concept_name  as RxName,a.drug_concept_code from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
  join drug_Concept_stage cs on cs.concept_code = a.ingredient_concept_code
  join devv5.concept rc on rc.concept_id = b.concept_id_2
  join drug_Concept_stage rd on rd.concept_code = a.drug_concept_code
  join (
  select a.drug_concept_code, b.concept_id_2 from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
  group by a.drug_concept_code, b.concept_id_2 having count (1) > 1) c 
  on c.DRUG_CONCEPT_CODE= a.DRUG_CONCEPT_CODE and c.CONCEPT_ID_2 = b.CONCEPT_ID_2
  where precedence = 1) b on a.RxName = b.RxName and a.drug_concept_code = b.drug_concept_code and (a.AMOUNT_UNIT !=b.amount_unit or a.NUMERATOR_UNIT != b.NUMERATOR_UNIT or a.NUMERATOR_UNIT is null and b.NUMERATOR_UNIT is not null
  or a.AMOUNT_UNIT is null and b.amount_unit is not null)
  union
  --Improper valid_end_date
  select concept_code, 'Improper valid_end_date' from drug_concept_stage where concept_code not in (
  select concept_code  from drug_concept_stage
  where  valid_end_date <=SYSDATE or valid_end_date = to_date ('2099-12-31', 'YYYY-MM-DD') )
  union
  --Improper valid_start_date
  select concept_code, 'Improper valid_start_date' from drug_concept_stage where valid_start_date >  SYSDATE
  ) a join drug_concept_stage b on a.concept_code = b.concept_code where b.invalid_reason is null and b.domain_id = 'Drug'  
   group by error_type


