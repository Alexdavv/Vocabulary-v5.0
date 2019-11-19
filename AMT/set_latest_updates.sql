DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                        pVocabularyName => 'AMT',
                        pVocabularyDate => (SELECT vocabulary_date FROM sources.product LIMIT 1),
                        pVocabularyVersion => (SELECT vocabulary_version FROM sources.product LIMIT 1),
                        pVocabularyDevSchema => 'DEV_AMT'
                    );
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                        pVocabularyName => 'RxNorm Extension',
                        pVocabularyDate => CURRENT_DATE,
                        pVocabularyVersion => 'RxNorm Extension ' || CURRENT_DATE,
                        pVocabularyDevSchema => 'DEV_AMT',
                        pAppendVocabulary => TRUE
                    );

    END
$_$;
