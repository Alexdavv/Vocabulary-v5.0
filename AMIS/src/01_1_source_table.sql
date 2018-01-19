DROP TABLE SOURCE_TABLE CASCADE CONSTRAINTS PURGE;

CREATE TABLE SOURCE_TABLE
(
   ENR        VARCHAR2(1023 Byte),
   ZNR        VARCHAR2(1023 Byte),
   REGNR      VARCHAR2(1023 Byte),
   KENNZ      VARCHAR2(1023 Byte),
   ZNRION     VARCHAR2(1023 Byte),
   AM         VARCHAR2(1023 Byte),
   RUH        VARCHAR2(1023 Byte),
   DFO        VARCHAR2(1023 Byte),
   BDZUL      VARCHAR2(1023 Byte),
   SZ         VARCHAR2(1023 Byte),
   ANTR       VARCHAR2(1023 Byte),
   SANTR      VARCHAR2(1023 Byte),
   IND        VARCHAR2(1023 Byte),
   LNRTEILO1  VARCHAR2(1023 Byte),
   BM1        VARCHAR2(1023 Byte),
   WSSTF1_1   VARCHAR2(1023 Byte),
   WSSTF1_2   VARCHAR2(1023 Byte),
   WSSTF1_3   VARCHAR2(1023 Byte),
   WSSTF1_4   VARCHAR2(1023 Byte),
   WSSTF1_5   VARCHAR2(1023 Byte),
   WSSTF1_6   VARCHAR2(1023 Byte),
   WSSTF1_7   VARCHAR2(1023 Byte),
   WSSTF1_8   VARCHAR2(1023 Byte),
   WSSTF1_9   VARCHAR2(1023 Byte),
   WSSTF1_10  VARCHAR2(1023 Byte),
   WSSTF1_11  VARCHAR2(1023 Byte),
   WSSTF1_12  VARCHAR2(1023 Byte),
   WSSTF1_13  VARCHAR2(1023 Byte),
   WSSTF1_14  VARCHAR2(1023 Byte),
   WSSTF1_15  VARCHAR2(1023 Byte),
   WSSTF1_16  VARCHAR2(1023 Byte),
   WSSTF1_17  VARCHAR2(1023 Byte),
   WSSTF1_18  VARCHAR2(1023 Byte),
   WSSTF1_19  VARCHAR2(1023 Byte),
   WSSTF1_20  VARCHAR2(1023 Byte),
   WSSTF1_21  VARCHAR2(1023 Byte),
   WSSTF1_22  VARCHAR2(1023 Byte),
   WSSTF1_23  VARCHAR2(1023 Byte),
   WSSTF1_24  VARCHAR2(1023 Byte),
   WSSTF1_25  VARCHAR2(1023 Byte),
   WSSTF1_26  VARCHAR2(1023 Byte),
   WSSTF1_27  VARCHAR2(1023 Byte),
   WSSTF1_28  VARCHAR2(1023 Byte),
   WSSTF1_29  VARCHAR2(1023 Byte),
   WSSTF1_30  VARCHAR2(1023 Byte),
   LNRTEILO2  VARCHAR2(1023 Byte),
   BM2        VARCHAR2(1023 Byte),
   WSSTF2_1   VARCHAR2(1023 Byte),
   WSSTF2_2   VARCHAR2(1023 Byte),
   WSSTF2_3   VARCHAR2(1023 Byte),
   WSSTF2_4   VARCHAR2(1023 Byte),
   WSSTF2_5   VARCHAR2(1023 Byte),
   WSSTF2_6   VARCHAR2(1023 Byte),
   WSSTF2_7   VARCHAR2(1023 Byte),
   WSSTF2_8   VARCHAR2(1023 Byte),
   WSSTF2_9   VARCHAR2(1023 Byte),
   WSSTF2_10  VARCHAR2(1023 Byte),
   WSSTF2_11  VARCHAR2(1023 Byte),
   WSSTF2_12  VARCHAR2(1023 Byte),
   WSSTF2_13  VARCHAR2(1023 Byte),
   WSSTF2_14  VARCHAR2(1023 Byte),
   WSSTF2_15  VARCHAR2(1023 Byte),
   WSSTF2_16  VARCHAR2(1023 Byte),
   WSSTF2_17  VARCHAR2(1023 Byte),
   WSSTF2_18  VARCHAR2(1023 Byte),
   WSSTF2_19  VARCHAR2(1023 Byte),
   WSSTF2_20  VARCHAR2(1023 Byte),
   WSSTF2_21  VARCHAR2(1023 Byte),
   WSSTF2_22  VARCHAR2(1023 Byte),
   LNRTEILO3  VARCHAR2(1023 Byte),
   BM3        VARCHAR2(1023 Byte),
   WSSTF3_1   VARCHAR2(1023 Byte),
   WSSTF3_2   VARCHAR2(1023 Byte),
   WSSTF3_3   VARCHAR2(1023 Byte),
   WSSTF3_4   VARCHAR2(1023 Byte),
   WSSTF3_5   VARCHAR2(1023 Byte),
   WSSTF3_6   VARCHAR2(1023 Byte),
   WSSTF3_7   VARCHAR2(1023 Byte),
   WSSTF3_8   VARCHAR2(1023 Byte),
   WSSTF3_9   VARCHAR2(1023 Byte),
   WSSTF3_10  VARCHAR2(1023 Byte),
   WSSTF3_11  VARCHAR2(1023 Byte),
   WSSTF3_12  VARCHAR2(1023 Byte),
   WSSTF3_13  VARCHAR2(1023 Byte),
   WSSTF3_14  VARCHAR2(1023 Byte),
   WSSTF3_15  VARCHAR2(1023 Byte),
   WSSTF3_16  VARCHAR2(1023 Byte),
   WSSTF3_17  VARCHAR2(1023 Byte),
   WSSTF3_18  VARCHAR2(1023 Byte),
   WSSTF3_19  VARCHAR2(1023 Byte),
   WSSTF3_20  VARCHAR2(1023 Byte),
   WSSTF3_21  VARCHAR2(1023 Byte),
   WSSTF3_22  VARCHAR2(1023 Byte),
   WSSTF3_23  VARCHAR2(1023 Byte),
   LNRTEILO4  VARCHAR2(1023 Byte),
   BM4        VARCHAR2(1023 Byte),
   WSSTF4_1   VARCHAR2(1023 Byte),
   WSSTF4_2   VARCHAR2(1023 Byte),
   WSSTF4_3   VARCHAR2(1023 Byte),
   WSSTF4_4   VARCHAR2(1023 Byte),
   WSSTF4_5   VARCHAR2(1023 Byte),
   WSSTF4_6   VARCHAR2(1023 Byte),
   WSSTF4_7   VARCHAR2(1023 Byte),
   WSSTF4_8   VARCHAR2(1023 Byte),
   WSSTF4_9   VARCHAR2(1023 Byte),
   WSSTF4_10  VARCHAR2(1023 Byte),
   WSSTF4_11  VARCHAR2(1023 Byte),
   WSSTF4_12  VARCHAR2(1023 Byte),
   WSSTF4_13  VARCHAR2(1023 Byte),
   WSSTF4_14  VARCHAR2(1023 Byte),
   WSSTF4_15  VARCHAR2(1023 Byte),
   WSSTF4_16  VARCHAR2(1023 Byte),
   WSSTF4_17  VARCHAR2(1023 Byte),
   WSSTF4_18  VARCHAR2(1023 Byte),
   WSSTF4_19  VARCHAR2(1023 Byte),
   WSSTF4_20  VARCHAR2(1023 Byte),
   WSSTF4_21  VARCHAR2(1023 Byte),
   WSSTF4_22  VARCHAR2(1023 Byte),
   WSSTF4_23  VARCHAR2(1023 Byte),
   WSSTF4_24  VARCHAR2(1023 Byte),
   WSSTF4_25  VARCHAR2(1023 Byte),
   LNRTEILO5  VARCHAR2(1023 Byte),
   BM5        VARCHAR2(1023 Byte),
   WSSTF5_1   VARCHAR2(1023 Byte),
   WSSTF5_2   VARCHAR2(1023 Byte),
   ADRANTL    VARCHAR2(1023 Byte),
   PAGR       VARCHAR2(1023 Byte),
   TPACK_1    VARCHAR2(1023 Byte),
   TPACK_2    VARCHAR2(1023 Byte),
   TPACK_3    VARCHAR2(1023 Byte),
   TPACK_4    VARCHAR2(1023 Byte),
   TPACK_5    VARCHAR2(1023 Byte),
   TPACK_6    VARCHAR2(1023 Byte),
   TPACK_7    VARCHAR2(1023 Byte),
   TPACK_8    VARCHAR2(1023 Byte),
   TPACK_9    VARCHAR2(1023 Byte),
   TPACK_10   VARCHAR2(1023 Byte),
   TPACK_11   VARCHAR2(1023 Byte),
   TPACK_12   VARCHAR2(1023 Byte),
   TPACK_13   VARCHAR2(1023 Byte),
   TPACK_14   VARCHAR2(1023 Byte),
   TPACK_15   VARCHAR2(1023 Byte),
   TPACK_16   VARCHAR2(1023 Byte),
   TPACK_17   VARCHAR2(1023 Byte),
   TPACK_18   VARCHAR2(1023 Byte),
   TPACK_19   VARCHAR2(1023 Byte),
   TPACK_20   VARCHAR2(1023 Byte),
   TPACK_21   VARCHAR2(1023 Byte),
   TPACK_22   VARCHAR2(1023 Byte),
   TPACK_23   VARCHAR2(1023 Byte),
   TPACK_24   VARCHAR2(1023 Byte),
   TPACK_25   VARCHAR2(1023 Byte),
   TPACK_26   VARCHAR2(1023 Byte),
   TPACK_27   VARCHAR2(1023 Byte),
   TPACK_28   VARCHAR2(1023 Byte),
   TPACK_29   VARCHAR2(1023 Byte),
   TPACK_30   VARCHAR2(1023 Byte),
   TPACK_31   VARCHAR2(1023 Byte),
   TPACK_32   VARCHAR2(1023 Byte),
   TPACK_33   VARCHAR2(1023 Byte),
   TPACK_34   VARCHAR2(1023 Byte),
   TPACK_35   VARCHAR2(1023 Byte),
   TPACK_36   VARCHAR2(1023 Byte),
   TPACK_37   VARCHAR2(1023 Byte),
   TPACK_38   VARCHAR2(1023 Byte),
   TPACK_39   VARCHAR2(1023 Byte),
   TPACK_40   VARCHAR2(1023 Byte),
   TPACK_41   VARCHAR2(1023 Byte),
   TPACK_42   VARCHAR2(1023 Byte),
   TPACK_43   VARCHAR2(1023 Byte),
   TPACK_44   VARCHAR2(1023 Byte),
   TPACK_45   VARCHAR2(1023 Byte),
   TPACK_46   VARCHAR2(1023 Byte),
   TPACK_47   VARCHAR2(1023 Byte),
   TPACK_48   VARCHAR2(1023 Byte),
   TPACK_49   VARCHAR2(1023 Byte),
   TPACK_50   VARCHAR2(1023 Byte),
   TPACK_51   VARCHAR2(1023 Byte),
   TPACK_52   VARCHAR2(1023 Byte),
   TPACK_53   VARCHAR2(1023 Byte),
   TPACK_54   VARCHAR2(1023 Byte),
   TPACK_55   VARCHAR2(1023 Byte),
   TPACK_56   VARCHAR2(1023 Byte),
   TPACK_57   VARCHAR2(1023 Byte),
   TPACK_58   VARCHAR2(1023 Byte),
   TPACK_59   VARCHAR2(1023 Byte),
   TPACK_60   VARCHAR2(1023 Byte),
   TPACK_61   VARCHAR2(1023 Byte),
   TPACK_62   VARCHAR2(1023 Byte),
   TPACK_63   VARCHAR2(1023 Byte),
   TPACK_64   VARCHAR2(1023 Byte),
   TPACK_65   VARCHAR2(1023 Byte),
   TPACK_66   VARCHAR2(1023 Byte),
   TPACK_67   VARCHAR2(1023 Byte),
   TPACK_68   VARCHAR2(1023 Byte),
   TPACK_69   VARCHAR2(1023 Byte),
   TPACK_70   CLOB,
   INVD       VARCHAR2(1023 Byte)
);
