-- input tables creation
DROP TABLE IF EXISTS DRUG_CONCEPT_STAGE;
CREATE TABLE DRUG_CONCEPT_STAGE
(
    CONCEPT_NAME            VARCHAR(255),
    VOCABULARY_ID           VARCHAR(20),
    CONCEPT_CLASS_ID        VARCHAR(25),
    STANDARD_CONCEPT        VARCHAR(1),
    CONCEPT_CODE            VARCHAR(50),
    POSSIBLE_EXCIPIENT      VARCHAR(1),
    DOMAIN_ID               VARCHAR(25),
    VALID_START_DATE        DATE,
    VALID_END_DATE          DATE,
    INVALID_REASON          VARCHAR(1),
    SOURCE_CONCEPT_CLASS_ID VARCHAR(20),
    BOX_SIZE                INT4
);

DROP TABLE IF EXISTS DS_STAGE;
CREATE TABLE DS_STAGE
(
    DRUG_CONCEPT_CODE       VARCHAR(255),
    INGREDIENT_CONCEPT_CODE VARCHAR(255),
    BOX_SIZE                INTEGER,
    AMOUNT_VALUE            FLOAT,
    AMOUNT_UNIT             VARCHAR(255),
    NUMERATOR_VALUE         FLOAT,
    NUMERATOR_UNIT          VARCHAR(255),
    DENOMINATOR_VALUE       FLOAT,
    DENOMINATOR_UNIT        VARCHAR(255)
);

DROP TABLE IF EXISTS INTERNAL_RELATIONSHIP_STAGE;
CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
    CONCEPT_CODE_1 VARCHAR(50),
    CONCEPT_CODE_2 VARCHAR(50)
);

DROP TABLE IF EXISTS RELATIONSHIP_TO_CONCEPT;
CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
    CONCEPT_CODE_1    VARCHAR(255),
    VOCABULARY_ID_1   VARCHAR(20),
    CONCEPT_ID_2      INTEGER,
    PRECEDENCE        INTEGER,
    CONVERSION_FACTOR FLOAT
);

DROP TABLE IF EXISTS PC_STAGE;
CREATE TABLE PC_STAGE
(
    PACK_CONCEPT_CODE VARCHAR(255),
    DRUG_CONCEPT_CODE VARCHAR(255),
    AMOUNT            FLOAT,
    BOX_SIZE          INT4
);

CREATE INDEX dcs_index ON drug_concept_stage (concept_code);
