---------------------------------------Diabetes and Obesity Cardiometabolic Global Project------------------------------------------------
-------Analysis 2b_HQ -------------------------HQ_DIABETES SOB--------------------------------------------------------------------------------
-- VERSION: v1.00
-- CHANGES FROM v0.99:
-- [New] QC CHECK 7 NEW : whole-dataset diagnostic for "Repeat patients
--                      don't have the focus brand in Before" -- flags
--                      any Repeat row, any brand, any month, where
--                      Before doesn't contain the focus brand's own
--                      token. Should return zero rows after the v0.96
--                      (gap-bridged Before) and v0.98 (cross-class Win)
--                      fixes; run it to confirm rather than trust the
--                      code alone.
-- CHANGES FROM v0.98:
-- [Fix] Steps 18/24/24b CHG : per Yipeng's decision on the Type/
--                      Indication question -- Type now only reflects the
--                      patient's own flag (DIABETES/OBESITY/UNKNOWN) on
--                      GLP-1 rows (Ozempic/Mounjaro/Wegovy). Every other
--                      regimen (Basal/Bolus/Premix Insulin, OAD, SGLT_2,
--                      DPP_IV) now ALWAYS shows DIABETES, regardless of
--                      the patient's underlying flag -- identical to
--                      what every past wave already showed, since those
--                      rows could only ever be Diabetes before Obesity-
--                      flagged patients were in scope at all. Applied
--                      uniformly across every category block: strength-
--                      level, Insulin naive (forced DIABETES directly,
--                      it's never GLP-1), Lose, Drop off, Off drug, End,
--                      and both CoMed/MonoUse outputs (keyed off
--                      FocusRegimen). The brand-level GLP-1 block needed
--                      no change -- it's already filtered to GLP-1 only.
-- CHANGES FROM v0.97:
-- [Fix] Step 11 CHG : Yipeng -- "Ozempic repeat patients don't have
--                      Ozempic in Before". Root cause: LastBrand is
--                      scoped PER DRUG CLASS, so a patient's first-ever
--                      GLP-1 fill always has LastBrand=NULL for that
--                      class, even when they are plainly switching in
--                      from a fully-dropped OTHER class (e.g. JARDIANCE,
--                      an SGLT-2). The old Win branch only fired when
--                      LastBrand IS NOT NULL (a same-class brand
--                      switch), so this genuinely cross-class win had
--                      nowhere to land -- it isn't Add-on either
--                      (nothing persists this month), so it fell all
--                      the way through to the 'Repeat' fallback. Before
--                      then correctly showed the dropped brand
--                      (JARDIANCE), making it look like "Repeat without
--                      the focus brand in Before" -- but the real
--                      problem was the Category, not Before: it should
--                      have read Win, not Repeat. Added a cross-class
--                      Win branch (LastBrand IS NULL, had other therapy
--                      last month, nothing else active this month).
-- CHANGES FROM v0.96:
-- [Fix] Step 8 CHG : Type/Indication naming resolved per your call answer
--                      (DIABETES / OBESITY / UNKNOWN). PatientType now
--                      collapses T1/T2 into one DIABETES value directly
--                      (was T1D/T2D), and every downstream
--                      NVL(pt.PatientType, 'T2D') default changed to
--                      NVL(pt.PatientType, 'UNKNOWN') -- a patient with no
--                      matching flag at all is now genuinely UNKNOWN
--                      instead of being silently mislabeled T2D. This also
--                      simplified every Ozempic/Mounjaro indication-suffix
--                      CASE (Steps 6b/18) down to a plain
--                      NVL(pt.PatientType,'UNKNOWN'), since PatientType now
--                      already holds the exact display value.
-- CHANGES FROM v0.95:
-- [Fix] Step 1  CHG : ATCLevel5Code/ATCLevel5Name/DrugClassName reverted to
--                      unqualified (not p.___) in the brand-normalization
--                      subquery -- they resolve from vISRDbatchItems, not
--                      DimProductMaster p; qualifying DrugClassName as
--                      p.DrugClassName broke Drugs_HQ_Diab with "Column
--                      p.DrugClassName does not exist".
-- [Fix] Step 11 CHG : the EXISTS(...) subquery added in v0.94 to fix Add-on
--                      detection sat in the SELECT list of a query that also
--                      has GROUP BY, which Vertica rejects (error 4818, "not
--                      supported if the subquery is not part of the GROUP
--                      BY"). Replaced with a precomputed ClassCountByMonth
--                      CTE (COUNT(DISTINCT DrugClass) per patient/month, no
--                      correlation) LEFT JOINed in instead of a correlated
--                      subquery -- same result, GROUP BY-safe.
-- [Fix] Step 11 CHG : "Repeat patient doesn't have focus brand in Before" --
--                      a SEPARATE bug from the Add-on/Win misclassification
--                      fixed in v0.94. SOB_Category is decided from a
--                      per-class LAG(BrandName) that bridges gaps (a patient
--                      who dropped a brand for a couple of months and came
--                      back is correctly Repeat), but the displayed Before
--                      combo came from a different, calendar-adjacent LAG
--                      (literally last calendar month) which, during that
--                      gap, never contained the brand at all -- so a gap-
--                      bridged Repeat row's Category was right and its
--                      Before was wrong. Before is now sourced from the
--                      combo at the patient's actual last active month IN
--                      THAT CLASS (LastMonthClass) when one exists, falling
--                      back to the calendar-adjacent combo only for Add-on/
--                      naive rows (which have no class history to anchor to
--                      by definition).
-- [Fix] Step 20/21/25 : "202407 (or any month) patient count all blank" --
--                      that symptom (an entire month blank across every
--                      row) is the signature of ProjectionFactors_HQ_Diab
--                      having no row for that effectiveMonth, nulling out
--                      LRx_Projected via the LEFT JOIN. Added a diagnostic
--                      query listing exactly which Date(s) are missing a
--                      Factor (fix the projection CSV itself for those), and
--                      changed the join to NVL(pf.Factor, 1) so a missing
--                      month falls back to the unprojected count instead of
--                      going blank.
-- CHANGES FROM v0.94:
-- [New] Step 22b/24b/25 NEW : Monotherapy view added alongside the existing
--                      co-medication view, per NN request. Metric='7_MonoUse',
--                      Category='Monotherapy', Before='TOTAL', Present=the
--                      focus brand itself. Sourced the same way as
--                      co-medication (on-drug patients from
--                      ClassDomDisplay_HQ_Diab) but as the exact complement
--                      of the "has co-medication" filter: patients with NO
--                      other active drug class that month. Rides the same
--                      05_CoMedications_HQ_Diabetes.csv export as the
--                      co-medication rows, distinguished by Metric/Category.
-- CHANGES FROM v0.93 (internal v0.6):
-- [Fix] Step 1  CHG : batch 453 pull extended to OZEMPIC + MOUNJARO (previously
--                      WEGOVY only) -- obesity-batch Rx for these two brands was
--                      being dropped entirely, not just mislabeled.
-- [Fix] Step 1b CHG : patient scope now includes PatientFlag='Obesity' (previously
--                      T1/T2 only). This is the actual reason Ozempic/Mounjaro/Wegovy
--                      Obesity usage was missing from the report -- obesity-flagged
--                      patients were excluded before drug classification ever ran.
-- [Fix] Step 1  NEW : BrandRegimenMap consolidates the two independently-maintained
--                      DrugClass / Regimen CASE lists (which re-inspected the same
--                      raw BrandName/GenericIngredientName twice, separately) into
--                      one canonical VALUES lookup keyed on the already-normalized
--                      brand. DrugClass and Regimen now both come from the same row,
--                      so a brand can never resolve to two different Regimen buckets
--                      (this is the class of bug behind HUMULIN/FIASP/ACTRAPID/ANY
--                      insulin showing under both Basal and Bolus, and behind blank
--                      Regimen -- a row could previously pass DrugClass IS NOT NULL
--                      while Regimen came out NULL from the other, independently
--                      maintained list).
-- [Fix] Step 8  CHG : PatientType now maps PatientFlag='Obesity' -> 'OBESITY'
--                      (previously fell through to the 'T2D' default, which is
--                      exactly why Ozempic/Mounjaro/Wegovy obesity usage was
--                      showing Type=T1D/T2D).
-- [Fix] Step 11 CHG : Add-on vs Repeat vs Win rebuilt on a proper per-class
--                      "does the patient still have another active class this
--                      month" check, replacing INSTR(PresentCombo,BeforeCombo)>0.
--                      Root cause of "Repeat patients' Before doesn't have the
--                      focus brand, looks like Add-on": combo strings are built by
--                      alphabetically concatenating brand names (Step 7), so
--                      inserting a new brand in the MIDDLE of the alphabetical
--                      order (e.g. LANTUS + TRAJENTA -> LANTUS + OZEMPIC + TRAJENTA)
--                      breaks the substring test even though nothing was dropped --
--                      that case fell through to the ELSE 'Repeat' fallback, with
--                      Before correctly NOT containing the new brand (it really
--                      wasn't there yet) but the Category wrongly saying Repeat
--                      instead of Add on.
-- [Fix] Step 12/13  : Lose / Drop off Focus_Brand now goes through the same
--                      indication-labeling as positive rows (previously bare
--                      BrandName with no strength or indication at all -- this is
--                      why Ozempic/Mounjaro had no indication label on negative SoB,
--                      and Ozempic Diabetes/Obesity appeared to have no negative SoB
--                      at all).
-- [Fix] Step 7/16/18/22 : Ozempic/Mounjaro/Wegovy display strings (Focus_Brand,
--                      Before, Present, Before/Present_MNIAD, co-medication combos)
--                      now carry an indication suffix built from PatientType:
--                      OZEMPIC/MOUNJARO -> "... DIABETES" or "... OBESITY" (from
--                      the patient's own T1/T2/Obesity flag); WEGOVY is always
--                      "... OBESITY" regardless of which flag prescribed it, since
--                      it is clinically obesity-only and showing T1D/T2D next to it
--                      was the reported bug. Brand-level GLP-1 rows (Focus_Brand =
--                      bare BrandName) now carry the same suffix, so Ozempic no
--                      longer blends Diabetes + Obesity into one brand-level total.
--                      Mounjaro Obesity rows are suppressed before 2026-05
--                      (launch month) instead of being backfilled.
-- [Fix] Step 19 CHG : On Drug rebuilt as SUM(LRx_Panel) over the 7 positive-category
--                      rows already computed for the category breakdown, instead of
--                      an independently recomputed COUNT(DISTINCT MasterPatientID).
--                      The distinct count silently deduped a patient who is both,
--                      say, Win and Insulin naive in the same month (Insulin naive
--                      is unioned in as an EXTRA row alongside the Win row for that
--                      same patient/brand/month), so On Drug came out lower than the
--                      sum of the 7 category rows it is supposed to equal. Switch
--                      away restructured the same way for consistency (its numbers
--                      are unchanged -- Lose/Drop off never had the double-row issue
--                      -- this just removes a redundant second scan of Base).
-- [Fix] Step 21/25  : UPPER() applied to every text output column ("capitalize all
--                      the variables"). Export delimiter made explicit (",") so the
--                      CSV can't pick up a locale-dependent list separator.
-- [Not changed -- needs your confirmation] "BYDUREON, BYETTA, SEGLUROMET and
--                      STEGLATRO are missing" / "on drug is still on distinct count
--                      for these very-low-volume brands": these four brands ARE
--                      present in the new BrandRegimenMap (they were already mapped
--                      in v0.93 too -- this wasn't a classification bug). The most
--                      likely cause is Step 6 (ClassDom_HQ_Diab): it keeps only ONE
--                      brand per patient per DrugClass per month (the one with the
--                      most supply days that month), so a patient who takes both,
--                      say, Bydureon and Ozempic in an overlap/switch month will
--                      always lose that contest to Ozempic and never surface as a
--                      Focus_Brand for that month at all, even though the raw
--                      dispense (and its LRx volume) is really there. Fixing this
--                      means changing the SOB methodology from "one dominant brand
--                      per class per patient per month" to something that can carry
--                      more than one -- that is a methodology change, not a bug fix,
--                      so I did not make it unilaterally. Confirm with me whether
--                      that is really what you want and I'll implement it.
------------------------------------------------------------------------------------------------------------------------------------------
@echo ${sDate||2024-07-01||||noshow}$;
@echo ${eDate||2026-07-01||||noshow}$;
@echo ${ISRDBatchID2||474||||noshow}$;
@echo ${ISRDBatchID1||453||||noshow}$;
@echo ${OutputPath||C:\Users\u1194544\OneDrive - IQVIA\Desktop\Novo Nordisk\Cardiometabolic GLP1 Analysis\Outputs\2026-06-16||||noshow}$;

-- ============================================================
-- DOCS TABLE [MJRO4 pattern]
-- Reads from DimHCPMaster and maps HCP specialty into grouped
-- labels. Written to ims schema first then pulled to local temp.
-- HCPMasterID joins directly to FactISRD.HCPMasterID in output.
-- ============================================================
DROP TABLE IF EXISTS ims.NovoGlobalAOM_Docsv2;
CREATE TABLE ims.NovoGlobalAOM_Docsv2 AS
SELECT
    HCPMasterID,
    CASE
        WHEN specialty IN ('GENERAL PRACTITIONER')                  THEN 'GPs'
        WHEN specialty IN ('OBSTETRICIAN AND GYNAECOLOGIST')        THEN 'Gynecologists'
        WHEN specialty IN ('CARDIOLOGIST')                          THEN 'Cardiologists'
        WHEN specialty IN ('DIABETOLOGIST','DIABETOLOGY',
                           'ENDOCRINOLOGIST','ENDOCRINOLOGY')       THEN 'Diabetologists/Endocrinologists'
        WHEN specialty IN ('NEPHROLOGIST')                          THEN 'Nephrologists'
        WHEN specialty IN ('GASTROENTEROLOGIST')                    THEN 'Gastroenterologists'
        ELSE 'Others'
    END                                                             AS Specialty
FROM DimHCPMaster;

DROP TABLE IF EXISTS Docs_HQ_Diab;
CREATE LOCAL TEMP TABLE Docs_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT * FROM ims.NovoGlobalAOM_Docsv2;
SELECT ANALYZE_STATISTICS('Docs_HQ_Diab');

-- ============================================================
-- STEP 1: DRUGS
-- Batch 474 = full diabetes market (insulins, GLP-1, SGLT2,
-- DPP4, OAD). Batch 453 = obesity batch -- OZEMPIC, MOUNJARO
-- and WEGOVY (was WEGOVY-only; Ozempic/Mounjaro obesity usage
-- was being dropped entirely, see v0.94 changelog above).
-- GLP-1 brands get ProductStrength = BrandName + StrengthCode
-- for Yipeng's requirement on Focus_Brand / MNIAD columns.
-- The indication suffix (Diabetes/Obesity) is NOT added here --
-- indication is a per-PATIENT attribute (from PatientFlag), not
-- a per-PRODUCT one, so it can only be resolved once patient
-- type is known. See Steps 7/16/18/22 where PatientType is
-- joined and the suffix is actually applied.
--
-- [Fix v0.94] DrugClass and Regimen used to come from two
-- separately hand-maintained CASE lists that both re-inspected
-- the raw BrandName/GenericIngredientName fields independently.
-- They agreed for most brands by coincidence of careful copy-
-- paste, but that's exactly the kind of duplication that drifts
-- silently (we found one real drift: SGLT-2 vs SGLT_2 spelling
-- differed between the two lists). Replaced with one
-- BrandRegimenMap lookup keyed on the already-normalized brand,
-- joined once, so DrugClass and Regimen always come from the
-- same row and can never disagree.
-- ============================================================
DROP TABLE IF EXISTS Drugs_HQ_Diab;
CREATE LOCAL TEMP TABLE Drugs_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT
    MasterProductID, BrandName, DrugClass, Regimen,
    SupplyDaysPerDIQ, StrengthCode, ATCLevel5Code, ATCLevel5Name,
    CASE
        WHEN BrandName IN ('OZEMPIC','TRULICITY','VICTOZA',
                           'MOUNJARO','BYETTA','BYDUREON','WEGOVY')
        THEN BrandName || ' ' || TRIM(StrengthCode)
        ELSE BrandName
    END                                                             AS ProductStrength
FROM (
    SELECT
        norm.MasterProductID, norm.ATCLevel5Code, norm.ATCLevel5Name,
        norm.BrandName,
        COALESCE(brm.Regimen,
            CASE WHEN norm.DrugClassNameTrim IN ('SU','MET','TZD',
                                                  'AGI','MEGLITINIDES') THEN 'OAD' END
        )                                                           AS DrugClass,
        COALESCE(brm.Regimen,
            CASE WHEN norm.DrugClassNameTrim IN ('SU','MET','TZD',
                                                  'AGI','MEGLITINIDES') THEN 'OAD' END
        )                                                           AS Regimen,
        CASE WHEN norm.BrandName = 'MOUNJARO'
                  AND norm.FormCode = 'INJ'                         THEN 7
             ELSE 28
        END                                                         AS SupplyDaysPerDIQ,
        CAST(norm.StrengthCode AS VARCHAR(100))                     AS StrengthCode
    FROM (
        -- Brand normalization: collapse raw source BrandName / GenericIngredientName
        -- text variants down to one canonical brand token. Unchanged from v0.93 --
        -- this step was not the source of any reported bug. Pulled into its own
        -- subquery (rather than a lateral join) purely so the brm lookup below can
        -- join on the already-normalized BrandName without depending on a Vertica
        -- LATERAL join, which this script does not otherwise rely on.
        SELECT
            -- [Fix v0.95] ATCLevel5Code/ATCLevel5Name and DrugClassName are NOT
            -- DimProductMaster columns -- v0.93 always referenced all three of
            -- them unqualified (unlike BrandName/GenericIngredientName/
            -- StrengthCode/FormCode/MasterProductID, which it always qualified
            -- as p.___). Qualifying DrugClassName as p.DrugClassName broke
            -- Drugs_HQ_Diab with "Column p.DrugClassName does not exist";
            -- ATCLevel5Code/ATCLevel5Name were the same risk, fixed here too
            -- before it could throw the same error one column later.
            p.MasterProductID, ATCLevel5Code, ATCLevel5Name,
            p.FormCode, p.StrengthCode,
            BTRIM(DrugClassName)                                    AS DrugClassNameTrim,
            CASE
                WHEN p.BrandName ILIKE '%ACTRAPID%'                     THEN 'ACTRAPID'
                WHEN p.BrandName ILIKE '%APIDRA%'                       THEN 'APIDRA'
                WHEN p.BrandName ILIKE '%BYDUREON%'                     THEN 'BYDUREON'
                WHEN p.BrandName ILIKE '%BYETTA%'                       THEN 'BYETTA'
                WHEN p.BrandName ILIKE '%FIASP%'                        THEN 'FIASP'
                WHEN p.BrandName ILIKE '%FORXIGA%'                      THEN 'FORXIGA'
                WHEN p.BrandName ILIKE '%GALVUMET%'                     THEN 'GALVUMET'
                WHEN p.BrandName ILIKE '%GALVUS%'                       THEN 'GALVUS'
                WHEN p.BrandName ILIKE '%GLYXAMBI%'                     THEN 'GLYXAMBI'
                WHEN p.BrandName ILIKE '%HUMALOG MIX50%'                THEN 'HUMALOG MIX50'
                WHEN p.BrandName ILIKE '%HUMALOG MIX25%'                THEN 'HUMALOG MIX25'
                WHEN p.BrandName ILIKE '%HUMALOG%'                      THEN 'HUMALOG'
                WHEN p.BrandName ILIKE '%HUMULIN%'                      THEN 'HUMULIN'
                WHEN p.BrandName ILIKE '%INVOKANA%'                     THEN 'INVOKANA'
                WHEN p.BrandName ILIKE '%JANUMET%'                      THEN 'JANUMET'
                WHEN p.BrandName ILIKE '%JANUVIA%'                      THEN 'JANUVIA'
                WHEN p.BrandName ILIKE '%JARDIAMET%'                    THEN 'JARDIAMET'
                WHEN p.BrandName ILIKE '%JARDIANCE%'                    THEN 'JARDIANCE'
                WHEN p.BrandName ILIKE '%KOMBIGLYZE%'                   THEN 'KOMBIGLYZE'
                WHEN p.BrandName ILIKE '%LANTUS%'                       THEN 'LANTUS'
                WHEN p.BrandName ILIKE '%LENTE%'                        THEN 'LENTE'
                WHEN p.BrandName ILIKE '%LEVEMIR%'                      THEN 'LEVEMIR'
                WHEN p.BrandName ILIKE '%MIXTARD NOVOLET%'              THEN 'MIXTARD NOVOLET'
                WHEN p.BrandName ILIKE '%MIXTARD%'                      THEN 'MIXTARD'
                WHEN p.BrandName ILIKE '%MONOTARD%'                     THEN 'MONOTARD'
                WHEN p.BrandName ILIKE '%MOUNJARO%'                     THEN 'MOUNJARO'
                WHEN p.BrandName ILIKE '%NESINA MET%'                   THEN 'NESINA MET'
                WHEN p.BrandName ILIKE '%NESINA%'                       THEN 'NESINA'
                WHEN p.BrandName ILIKE '%NOVOMIX%'                      THEN 'NOVOMIX'
                WHEN p.BrandName ILIKE '%NOVORAPID%'                    THEN 'NOVORAPID'
                WHEN p.BrandName ILIKE '%ONGLYZA%'                      THEN 'ONGLYZA'
                WHEN p.BrandName ILIKE '%OPTISULIN%'                    THEN 'OPTISULIN'
                WHEN p.BrandName ILIKE '%OZEMPIC%'                      THEN 'OZEMPIC'
                WHEN p.BrandName ILIKE '%QTERN%'                        THEN 'QTERN'
                WHEN p.BrandName ILIKE '%RYZODEG%'                      THEN 'RYZODEG'
                WHEN p.BrandName ILIKE '%SAXENDA%'                      THEN 'SAXENDA'
                WHEN p.BrandName ILIKE '%SEGLUROMET%'                   THEN 'SEGLUROMET'
                WHEN p.BrandName ILIKE '%SEMGLEE%'                      THEN 'SEMGLEE'
                WHEN p.BrandName ILIKE '%SIDAPVIA%'                     THEN 'SIDAPVIA'
                WHEN p.BrandName ILIKE '%SITAGLO-MET%'                  THEN 'SITAGLO-MET'
                WHEN p.BrandName ILIKE '%SITAGLO%'
                     AND p.BrandName NOT ILIKE '%SITAGLO-MET%'          THEN 'SITAGLO'
                WHEN p.BrandName ILIKE '%STEGLATRO%'                    THEN 'STEGLATRO'
                WHEN p.BrandName ILIKE '%STEGLUJAN%'                    THEN 'STEGLUJAN'
                WHEN p.BrandName ILIKE '%TOUJEO%'                       THEN 'TOUJEO'
                WHEN p.BrandName ILIKE '%TRAJENTAMET%'                  THEN 'TRAJENTA'
                WHEN p.BrandName ILIKE '%TRAJENTA%'                     THEN 'TRAJENTA'
                WHEN p.BrandName ILIKE '%TRULICITY%'                    THEN 'TRULICITY'
                WHEN p.BrandName ILIKE '%VELMETIA%'                     THEN 'VELMETIA'
                WHEN p.BrandName ILIKE '%VICTOZA%'                      THEN 'VICTOZA'
                WHEN p.BrandName ILIKE '%VILDAGLIPTIN%'
                     AND p.BrandName ILIKE '%METFORMIN%'                THEN 'VILDAGLIPTIN/METFORMIN'
                WHEN p.BrandName ILIKE '%SITAGLIPTIN%'
                     AND p.BrandName ILIKE '%METFORMIN%'                THEN 'SITAGLIPTIN/METFORMIN'
                WHEN p.BrandName ILIKE '%SITAGLIPTIN%'                  THEN 'SITAGLIPTIN'
                WHEN p.BrandName ILIKE '%WEGOVY%'                       THEN 'WEGOVY'
                WHEN p.BrandName ILIKE '%XELEVIA%'                      THEN 'XELEVIA'
                WHEN p.BrandName ILIKE '%XIGDUO%'                       THEN 'XIGDUO'
                WHEN p.GenericIngredientName ILIKE '%INSULIN ISOPHANE%'
                     AND p.GenericIngredientName NOT ILIKE '%/%'        THEN 'HUMAN_BASAL'
                WHEN (p.GenericIngredientName ILIKE '%INSULIN ISOPH%NEUT%'
                   OR p.GenericIngredientName ILIKE '%INSULIN NEUT%ISOP%') THEN 'HUMAN_BASAL'
                WHEN p.GenericIngredientName ILIKE '%INSULIN NEUTRAL%'  THEN 'HUMAN_BOLUS'
                WHEN p.GenericIngredientName ILIKE '%INSULIN LENTE%'    THEN 'LENTE'
                WHEN p.GenericIngredientName ILIKE '%INSULIN ULTRALENTE%' THEN 'HUMAN_BASAL'
                WHEN BTRIM(DrugClassName) IN ('SU','MET','TZD',
                                              'AGI','MEGLITINIDES')     THEN 'OAD'
                ELSE NULL
            END AS BrandName
        FROM DimProductMaster p
        JOIN vISRDbatchItems b474
            ON  p.MasterProductID = b474.MasterProductID
            AND b474.ISRDBatchID  = ${ISRDBatchID2}$
        WHERE BTRIM(DrugClassName) NOT IN ('','Not Applicable')
          AND DrugClassName IS NOT NULL
    ) norm
    -- [Fix v0.94] single canonical brand -> Regimen lookup. OAD (driven by
    -- DrugClassName, not brand) is handled separately via the COALESCE above,
    -- since it isn't a "brand" in the same sense. Written as UNION ALL SELECT
    -- literals rather than a VALUES(...) table constructor so it doesn't
    -- depend on that syntax being supported here.
    LEFT JOIN (
        SELECT 'ACTRAPID' AS Brand, 'BOLUS INSULIN' AS Regimen
        UNION ALL SELECT 'APIDRA',        'BOLUS INSULIN'
        UNION ALL SELECT 'FIASP',         'BOLUS INSULIN'
        UNION ALL SELECT 'NOVORAPID',     'BOLUS INSULIN'
        UNION ALL SELECT 'HUMALOG',       'BOLUS INSULIN'
        UNION ALL SELECT 'HUMALOG MIX25', 'BOLUS INSULIN'
        UNION ALL SELECT 'HUMULIN',       'BOLUS INSULIN'
        UNION ALL SELECT 'HUMAN_BOLUS',   'BOLUS INSULIN'
        UNION ALL SELECT 'HUMALOG MIX50',   'PREMIX INSULIN'
        UNION ALL SELECT 'MIXTARD',         'PREMIX INSULIN'
        UNION ALL SELECT 'MIXTARD NOVOLET', 'PREMIX INSULIN'
        UNION ALL SELECT 'NOVOMIX',         'PREMIX INSULIN'
        UNION ALL SELECT 'RYZODEG',         'PREMIX INSULIN'
        UNION ALL SELECT 'LANTUS',      'BASAL INSULIN'
        UNION ALL SELECT 'LEVEMIR',     'BASAL INSULIN'
        UNION ALL SELECT 'TOUJEO',      'BASAL INSULIN'
        UNION ALL SELECT 'SEMGLEE',     'BASAL INSULIN'
        UNION ALL SELECT 'OPTISULIN',   'BASAL INSULIN'
        UNION ALL SELECT 'MONOTARD',    'BASAL INSULIN'
        UNION ALL SELECT 'LENTE',       'BASAL INSULIN'
        UNION ALL SELECT 'HUMAN_BASAL', 'BASAL INSULIN'
        UNION ALL SELECT 'OZEMPIC',   'GLP-1'
        UNION ALL SELECT 'MOUNJARO',  'GLP-1'
        UNION ALL SELECT 'WEGOVY',    'GLP-1'
        UNION ALL SELECT 'SAXENDA',   'GLP-1'
        UNION ALL SELECT 'TRULICITY', 'GLP-1'
        UNION ALL SELECT 'VICTOZA',   'GLP-1'
        UNION ALL SELECT 'BYETTA',    'GLP-1'
        UNION ALL SELECT 'BYDUREON',  'GLP-1'
        UNION ALL SELECT 'JARDIANCE',  'SGLT_2'
        UNION ALL SELECT 'JARDIAMET',  'SGLT_2'
        UNION ALL SELECT 'FORXIGA',    'SGLT_2'
        UNION ALL SELECT 'INVOKANA',   'SGLT_2'
        UNION ALL SELECT 'GLYXAMBI',   'SGLT_2'
        UNION ALL SELECT 'XIGDUO',     'SGLT_2'
        UNION ALL SELECT 'QTERN',      'SGLT_2'
        UNION ALL SELECT 'STEGLUJAN',  'SGLT_2'
        UNION ALL SELECT 'STEGLATRO',  'SGLT_2'
        UNION ALL SELECT 'SEGLUROMET', 'SGLT_2'
        UNION ALL SELECT 'SIDAPVIA',   'SGLT_2'
        UNION ALL SELECT 'GALVUMET',                 'DPP_IV'
        UNION ALL SELECT 'KOMBIGLYZE',                'DPP_IV'
        UNION ALL SELECT 'NESINA MET',                'DPP_IV'
        UNION ALL SELECT 'VILDAGLIPTIN/METFORMIN',    'DPP_IV'
        UNION ALL SELECT 'SITAGLIPTIN/METFORMIN',     'DPP_IV'
        UNION ALL SELECT 'JANUMET',                   'DPP_IV'
        UNION ALL SELECT 'SITAGLO-MET',               'DPP_IV'
        UNION ALL SELECT 'GALVUS',                    'DPP_IV'
        UNION ALL SELECT 'JANUVIA',                   'DPP_IV'
        UNION ALL SELECT 'ONGLYZA',                   'DPP_IV'
        UNION ALL SELECT 'TRAJENTA',                  'DPP_IV'
        UNION ALL SELECT 'SITAGLIPTIN',                'DPP_IV'
        UNION ALL SELECT 'SITAGLO',                    'DPP_IV'
        UNION ALL SELECT 'NESINA',                     'DPP_IV'
        UNION ALL SELECT 'VELMETIA',                   'DPP_IV'
        UNION ALL SELECT 'XELEVIA',                    'DPP_IV'
    ) brm ON brm.Brand = norm.BrandName

    UNION

    -- [Fix v0.94] batch 453 (obesity batch) now pulls OZEMPIC and MOUNJARO
    -- in addition to WEGOVY -- previously only WEGOVY was selected here, so
    -- any obesity-context Ozempic/Mounjaro dispensing in this batch was
    -- dropped before it ever reached the report, not just mislabeled once it
    -- got there.
    SELECT DISTINCT p.MasterProductID, ATCLevel5Code, ATCLevel5Name,
        CASE
            WHEN p.BrandName ILIKE '%OZEMPIC%'  THEN 'OZEMPIC'
            WHEN p.BrandName ILIKE '%MOUNJARO%' THEN 'MOUNJARO'
            WHEN p.BrandName ILIKE '%WEGOVY%'   THEN 'WEGOVY'
        END                                                             AS BrandName,
        'GLP-1' AS DrugClass, 'GLP-1' AS Regimen,
        CASE WHEN p.BrandName ILIKE '%MOUNJARO%' AND p.FormCode = 'INJ' THEN 7
             ELSE 28
        END                                                             AS SupplyDaysPerDIQ,
        CAST(p.StrengthCode AS VARCHAR(100))                            AS StrengthCode
    FROM DimProductMaster p
    JOIN vISRDbatchItems b453
        ON  p.MasterProductID = b453.MasterProductID
        AND b453.ISRDBatchID  = ${ISRDBatchID1}$
    WHERE p.BrandName ILIKE '%OZEMPIC%'
       OR p.BrandName ILIKE '%MOUNJARO%'
       OR p.BrandName ILIKE '%WEGOVY%'
) inner_tbl
WHERE BrandName IS NOT NULL AND DrugClass IS NOT NULL
;
SELECT ANALYZE_STATISTICS('Drugs_HQ_Diab');


select * from Drugs_HQ_Diab;
-- ============================================================
-- STEP 1b: PATIENT FLAG  [NEW – Octavian]
-- Patient scope must come from ISRDPatientFlag algorithm table.
-- PatientFlag values: 'T1', 'T2', 'Obesity'.
-- [Fix v0.94] 'Obesity' added to scope. Previously the diabetes
-- market scope was T1/T2 only and obesity-flagged patients were
-- excluded outright ("covered in obesity SOB analysis" -- but
-- this report is now expected to carry Ozempic/Mounjaro/Wegovy
-- obesity usage too, so those patients can no longer be excluded
-- here). This is the actual root cause of "Mounjaro obesity and
-- Ozempic obesity is missing": they weren't misclassified, their
-- patients were filtered out before classification ever ran.
-- ============================================================
DROP TABLE IF EXISTS PatientFlag_HQ_Diab;
CREATE LOCAL TEMP TABLE PatientFlag_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT MasterPatientID
FROM FactISRDPatientFlag
WHERE ISRDBatchID IN (${ISRDBatchID2}$, ${ISRDBatchID1}$)
  AND PatientFlag   IN ('T1', 'T2', 'Obesity');
SELECT ANALYZE_STATISTICS('PatientFlag_HQ_Diab');


-- ============================================================
-- Type column should show DIABETES/OBESITY/UNKNOWN split.
-- Source: ISRDPatientFlag – same table as Step 1b.
-- PatientFlag = 'T1' or 'T2' ? Type = 'DIABETES'
-- PatientFlag = 'Obesity'    ? Type = 'OBESITY'
-- No matching flag at all    ? Type = 'UNKNOWN' (via NVL(pt.PatientType,
--   'UNKNOWN') wherever this table is LEFT JOINed downstream)
-- ============================================================
-- ============================================================
-- STEP 8: PATIENT TYPE CLASSIFICATION
-- [Yipeng] Type column = T1D/T2D from ISRDPatientFlag (v0.93 original
-- requirement). [Fix v0.96] Per your call request, collapsed T1/T2 into
-- one DIABETES value (keeping the T1D/T2D split elsewhere isn't needed
-- for this column) and every downstream NVL(pt.PatientType, 'UNKNOWN')
-- default changed to NVL(pt.PatientType, 'UNKNOWN') -- a patient with no
-- matching flag at all is now genuinely UNKNOWN instead of being
-- silently mislabeled DIABETES/T2D.
-- [FIX] A patient can appear in both batch 474 (diabetes) and
-- batch 453 (obesity). Without deduplication this would produce
-- two PatientType rows per patient causing double counting in
-- the LEFT JOIN in Step 18.
-- Fix: take one row per patient using batch 474 (diabetes) as
-- priority. If a patient only appears in batch 453 they are
-- included only if flagged T1/T2/Obesity.
-- ============================================================
DROP TABLE IF EXISTS PatientType_HQ_Diab;
CREATE LOCAL TEMP TABLE PatientType_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT
    MasterPatientID,
    -- Take the DIABETES/OBESITY label – same for a given patient across batches
    -- DISTINCT on MasterPatientID + PatientType handles deduplication
    -- for patients who appear in both batch 474 and 453 with same flag
    CASE
        WHEN PatientFlag IN ('T1','T2') THEN 'DIABETES'
        WHEN PatientFlag = 'Obesity'    THEN 'OBESITY'
        ELSE 'UNKNOWN'
    END                                                             AS PatientType
FROM factISRDPatientFlag
WHERE ISRDBatchID IN (${ISRDBatchID2}$, ${ISRDBatchID1}$)
  AND PatientFlag IN ('T1', 'T2', 'Obesity');
SELECT ANALYZE_STATISTICS('PatientType_HQ_Diab');
-- ============================================================
-- STEP 2: BASE FACT  [CHANGED – Octavian]
-- HCPMasterID from FactISRD directly (MJRO4 pattern).
-- Ozempic starter pack: first Rx = 2mg pen = 42 days supply.
-- JOIN to PatientFlag_HQ_Diab added to scope to T1/T2/Obesity only.
-- ============================================================
DROP TABLE IF EXISTS Fact_HQ_Diab;
CREATE LOCAL TEMP TABLE Fact_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH AllDisp AS (
    -- [Octavian] Group by patient + date + brand only.
    -- Same brand dispensed multiple times on same date ? merged via SUM(DIQ).
    -- MAX picks one value for Regimen, ProductStrength, HCPMasterID where
    -- these could differ across rows for the same brand+date combination.
    SELECT
        f.MasterPatientID,
        f.DispenseCalendarDate,
        d.BrandName,
        d.DrugClass,
        MAX(d.Regimen)                                              AS Regimen,
        MAX(d.ProductStrength)                                      AS ProductStrength,
        MAX(d.SupplyDaysPerDIQ)                                     AS SupplyDaysPerDIQ,
        MAX(f.HCPMasterID)                                          AS HCPMasterID,
        SUM(CASE WHEN f.DIQ IS NULL OR f.DIQ <= 0 THEN 1
                 ELSE f.DIQ END)                                    AS nDIQ
    FROM FactISRD f
    JOIN Drugs_HQ_Diab d        ON f.MasterProductID = d.MasterProductID
    JOIN PatientFlag_HQ_Diab pf ON f.MasterPatientID = pf.MasterPatientID
    WHERE f.ISRDBatchID IN (${ISRDBatchID2}$, ${ISRDBatchID1}$)
      AND f.DispenseCalendarDate <  DATE('${eDate}$')
      AND f.FactISRDID           > 0
      AND d.BrandName            IS NOT NULL
      AND d.DrugClass            IS NOT NULL
    -- [Octavian] GROUP BY patient + date + brand only (4 columns, not 8)
    GROUP BY 1,2,3,4
),
-- [Octavian] RowNum computed AFTER same-day collapsing.
-- Each row now represents one unique brand+date for this patient.
Numbered AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY MasterPatientID, BrandName
            ORDER BY DispenseCalendarDate
        )                                                           AS RowNum
    FROM AllDisp
),
Rolling AS (
    SELECT *,
        SUM(nDIQ) OVER (
            PARTITION BY MasterPatientID, BrandName
            ORDER BY RowNum
            RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                           AS RollingDIQ
    FROM Numbered
)
SELECT *,
    CASE
        WHEN RowNum = 1  AND nDIQ = 1  AND BrandName = 'OZEMPIC' THEN nDIQ * 2 / (2.0/42)
        WHEN RowNum > 1  AND nDIQ = 1  AND BrandName = 'OZEMPIC' THEN nDIQ * 28
        WHEN RowNum = 1  AND nDIQ > 1  AND BrandName = 'OZEMPIC' THEN (1 * 2 / (2.0/42) + (nDIQ - 1) * 28)
        WHEN RowNum > 1  AND nDIQ > 1  AND BrandName = 'OZEMPIC' THEN nDIQ * 28
        WHEN RowNum <= 5 AND nDIQ < 1  AND RollingDIQ <= 1
             AND BrandName = 'OZEMPIC'                             THEN nDIQ * 2 / (2.0/42)
        WHEN RowNum <= 5 AND nDIQ < 1  AND RollingDIQ > 1
             AND BrandName = 'OZEMPIC'                             THEN nDIQ * 28
        WHEN RowNum > 5  AND nDIQ < 1  AND BrandName = 'OZEMPIC' THEN nDIQ * 28
        ELSE nDIQ * SupplyDaysPerDIQ
    END                                                             AS SupplyDays
FROM Rolling
;
SELECT ANALYZE_STATISTICS('Fact_HQ_Diab');

-- ============================================================
-- STEP 3: TEMPFACT
-- Converts each dispense into a date range (start ? end supply).
-- End date = MIN(next dispense date, end of supply).
-- Implements PPTX Slide 5 link-or-cut rule.
-- ============================================================
DROP TABLE IF EXISTS TempFact_HQ_Diab;
CREATE LOCAL TEMP TABLE TempFact_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT tbl2.*,
    CASE
        WHEN nextDispenseDate IS NOT NULL THEN
            CASE WHEN nextDispenseDate > endOfSupplyDate THEN endOfSupplyDate + 1
                 ELSE nextDispenseDate END
        ELSE
            CASE WHEN endOfSupplyDate < DATE('${eDate}$') THEN endOfSupplyDate + 1
                 ELSE DATE('${eDate}$') END
    END                                                             AS endDurationDate
FROM (
    SELECT tbl.*,
        CAST(DispenseCalendarDate AS DATE) + SupplyDays             AS endOfSupplyDate,
        LEAD(CAST(DispenseCalendarDate AS DATE)) OVER (
            PARTITION BY MasterPatientID, DrugClass
            ORDER BY DispenseCalendarDate
        )                                                           AS nextDispenseDate
    FROM (
        -- [Octavian] RowNum removed. SUM(SupplyDays) collapses same-day
        -- dispensations correctly. LEAD window uses ORDER BY
        -- DispenseCalendarDate directly – RowNum not needed.
        SELECT DISTINCT
            MasterPatientID, BrandName, DrugClass, Regimen,
            ProductStrength, HCPMasterID, DispenseCalendarDate,
            SUM(SupplyDays) OVER (
                PARTITION BY MasterPatientID, BrandName, DispenseCalendarDate
            )                                                       AS SupplyDays
        FROM Fact_HQ_Diab
    ) tbl
) tbl2
;
SELECT ANALYZE_STATISTICS('TempFact_HQ_Diab');

-- ============================================================
-- STEP 4: CALENDAR SPINE
-- One row per calendar month from Jan 2011 to eDate.
-- ============================================================
DROP TABLE IF EXISTS Months_HQ_Diab;
CREATE LOCAL TEMP TABLE Months_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT CalendarPeriodStartDate AS Month
FROM prod_nd.DimDateMaster
WHERE CalendarDate >= '2011-01-01'
  AND CalendarDate <  DATE('${eDate}$')
;

-- ============================================================
-- STEP 5: ADJUSTED MONTHS
-- Active days per brand per patient per month.
-- Partial months prorated correctly.
-- HCPMasterID: MAX across dispenses in month as tiebreaker.
-- ============================================================
DROP TABLE IF EXISTS AdjMonths_HQ_Diab;
CREATE LOCAL TEMP TABLE AdjMonths_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH tbl AS (
    SELECT *
    FROM Months_HQ_Diab m
    JOIN TempFact_HQ_Diab f
        ON m.Month BETWEEN TRUNC(f.DispenseCalendarDate, 'MM')
                       AND TRUNC(f.endDurationDate, 'MM')
),
nDays AS (
    SELECT
        Month, MasterPatientID, BrandName, ProductStrength,
        DrugClass, Regimen, HCPMasterID,
        NVL(CAST(DATEDIFF('d',
            CASE WHEN Month = TRUNC(DispenseCalendarDate,'MM')
                 THEN GREATEST(Month, DispenseCalendarDate)
                 ELSE Month END,
            CASE WHEN Month = TRUNC(endDurationDate,'MM')
                 THEN LEAST(LAST_DAY(Month) + 1, endDurationDate)
                 ELSE LAST_DAY(Month) + 1 END
        ) AS INTEGER), 0)                                           AS nDays
    FROM tbl
)
SELECT DISTINCT
    Month, MasterPatientID, BrandName, DrugClass, Regimen,
    ProductStrength,
    MAX(HCPMasterID) OVER (PARTITION BY Month, MasterPatientID, BrandName) AS HCPMasterID,
    SUM(nDays)       OVER (PARTITION BY Month, MasterPatientID, BrandName) AS nDays
FROM nDays
;
SELECT ANALYZE_STATISTICS('AdjMonths_HQ_Diab');

-- ============================================================
-- STEP 6: CLASS-LEVEL DOMINANT BRAND
-- Per drug class per patient per month: brand with most supply
-- days wins. Alphabetical tiebreak. One row per patient per
-- class per month – the core treatment profile table.
--
-- [Not changed in v0.94 -- see the top-of-file note] this "one
-- brand per class per patient per month" design is the most
-- likely reason very-low-volume brands (BYDUREON, BYETTA,
-- SEGLUROMET, STEGLATRO) can go entirely missing from a month
-- where they really do have volume: they lose the nDays contest
-- to whatever bigger brand the same patient is also on that
-- month. Left as-is pending your confirmation since changing it
-- changes the SOB methodology, not just a bug.
-- ============================================================
DROP TABLE IF EXISTS ClassDom_HQ_Diab;
CREATE LOCAL TEMP TABLE ClassDom_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT
    Month, MasterPatientID, DrugClass, Regimen, BrandName, HCPMasterID,
    FIRST_VALUE(ProductStrength) OVER (
        PARTITION BY Month, MasterPatientID, DrugClass
        ORDER BY nDays DESC, BrandName ASC
    )                                                               AS ProductStrength
FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY Month, MasterPatientID, DrugClass
            ORDER BY nDays DESC, BrandName ASC
        )                                                           AS rnk
    FROM AdjMonths_HQ_Diab
    WHERE DrugClass IS NOT NULL
) ranked_adj
WHERE rnk = 1
;
SELECT ANALYZE_STATISTICS('ClassDom_HQ_Diab');

-- ============================================================
-- STEP 6b: PATIENT TYPE-AWARE GLP-1 DISPLAY NAME  [NEW v0.94]
-- Precomputes the indication-aware display token for every
-- ClassDom row so Steps 7, 16, 18 and 22 all build Before/
-- Present/Focus_Brand from the same source instead of repeating
-- this CASE four times and risking drift between them.
-- OZEMPIC/MOUNJARO -> "<ProductStrength> DIABETES" or "... OBESITY",
--   taken directly from the patient's own PatientType (T1/T2 flag ->
--   DIABETES, Obesity flag -> OBESITY, no matching flag -> UNKNOWN).
-- WEGOVY -> always "... OBESITY", regardless of which flag the
--   prescribing patient carries -- Wegovy is clinically obesity-
--   only, and showing a diabetes flag next to it was the reported bug.
-- Everything else: unchanged (GLP-1 non-indication-aware brands
--   keep ProductStrength as before; non-GLP-1 keeps BrandName).
-- ============================================================
DROP TABLE IF EXISTS ClassDomDisplay_HQ_Diab;
CREATE LOCAL TEMP TABLE ClassDomDisplay_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT
    c.Month, c.MasterPatientID, c.DrugClass, c.Regimen, c.BrandName,
    c.HCPMasterID, c.ProductStrength,
    CASE
        WHEN c.Regimen = 'GLP-1' AND c.BrandName IN ('OZEMPIC','MOUNJARO')
        THEN c.ProductStrength || ' ' ||
             NVL(pt.PatientType,'UNKNOWN')
        WHEN c.Regimen = 'GLP-1' AND c.BrandName = 'WEGOVY'
        THEN c.ProductStrength || ' OBESITY'
        WHEN c.Regimen = 'GLP-1'
        THEN c.ProductStrength
        ELSE c.BrandName
    END                                                             AS DisplayNameStrength,
    CASE
        WHEN c.BrandName IN ('OZEMPIC','MOUNJARO')
        THEN c.BrandName || ' ' ||
             NVL(pt.PatientType,'UNKNOWN')
        WHEN c.BrandName = 'WEGOVY'
        THEN c.BrandName || ' OBESITY'
        ELSE c.BrandName
    END                                                             AS DisplayNameBrand
FROM ClassDom_HQ_Diab c
LEFT JOIN PatientType_HQ_Diab pt ON c.MasterPatientID = pt.MasterPatientID
;
SELECT ANALYZE_STATISTICS('ClassDomDisplay_HQ_Diab');

-- ============================================================
-- STEP 7: BRAND COMBO STRING
-- Alphabetical concatenation of dominant brands per patient
-- per month. GLP-1 brands use the indication-aware display name
-- (Step 6b) so Before/Present show e.g. LANTUS + MOUNJARO 2.5mg
-- DIABETES, and Ozempic/Mounjaro/Wegovy carry their indication
-- suffix here too (strength level).
-- ============================================================
DROP TABLE IF EXISTS BrandCombo_HQ_Diab;
CREATE LOCAL TEMP TABLE BrandCombo_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH Ranked AS (
    SELECT
        Month, MasterPatientID,
        DisplayNameStrength                                         AS DisplayName,
        ROW_NUMBER() OVER (
            PARTITION BY Month, MasterPatientID
            ORDER BY DisplayNameStrength ASC
        )                                                           AS BrandRank,
        COUNT(*) OVER (PARTITION BY Month, MasterPatientID)        AS BrandCount
    FROM ClassDomDisplay_HQ_Diab
)
SELECT DISTINCT Month, MasterPatientID,
    TRIM(
        MAX(CASE WHEN BrandRank=1 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID)
        ||CASE WHEN BrandCount>=2 THEN ' + '||MAX(CASE WHEN BrandRank=2 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ||CASE WHEN BrandCount>=3 THEN ' + '||MAX(CASE WHEN BrandRank=3 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ||CASE WHEN BrandCount>=4 THEN ' + '||MAX(CASE WHEN BrandRank=4 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ||CASE WHEN BrandCount>=5 THEN ' + '||MAX(CASE WHEN BrandRank=5 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ||CASE WHEN BrandCount>=6 THEN ' + '||MAX(CASE WHEN BrandRank=6 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ||CASE WHEN BrandCount>=7 THEN ' + '||MAX(CASE WHEN BrandRank=7 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ||CASE WHEN BrandCount>=8 THEN ' + '||MAX(CASE WHEN BrandRank=8 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
    )                                                               AS CurrentCombo
FROM Ranked
;
SELECT ANALYZE_STATISTICS('BrandCombo_HQ_Diab');

-- ============================================================
-- STEP 8: DIABETES / OBESITY / UNKNOWN – see Step 8 above (PatientType).
-- Type column now comes from PatientType_HQ_Diab, not hardcoded.
-- ============================================================

-- ============================================================
-- STEP 9: PATIENT TRUE DATABASE ENTRY DATE  [CHANGED – Octavian]
-- Previous version used FactISRD filtered to batches 474/453.
-- Wrong because those batches only contain the drugs we included
-- so earliest date is biased by batch drug composition, not true
-- patient DB entry. A patient who entered IQVIA in 2021 for a
-- non-diabetes drug would not appear in FactISRD batch 474/453.
-- Correct source: FactScript – full dispensing table across all
-- products – gives true first observation date for any patient
-- regardless of drug class or batch.
-- Used for MonthsObservable in SOBClass to correctly classify
-- Treatment naive first vs New to database.
-- ============================================================
DROP TABLE IF EXISTS PatientDBEntry_HQ_Diab;
CREATE LOCAL TEMP TABLE PatientDBEntry_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT
    m.MasterPatient_ID                                              AS MasterPatientID,
    MIN(CAST(fs.DispenseCalendarDate AS DATE))                      AS DBEntryDate
FROM FactScript fs
JOIN DimMAIU m ON fs.MAIUID = m.MAIU_ID
WHERE fs.FactScriptID > 0
GROUP BY 1;
SELECT ANALYZE_STATISTICS('PatientDBEntry_HQ_Diab');

-- ============================================================
-- STEP 10: INSULIN HISTORY
-- Stores every individual insulin dispense date per patient.
-- Used for the 14-day window rule per Yipeng / AH methodology:
-- patient is insulin naive if no insulin dispense exists before
-- 14 days prior to the evaluated month start date.
-- [Octavian confirmed] NOT EXISTS in Step 11 correctly returns
-- IsInsulinNaive=1 for BOTH:
--   a) Patients with zero insulin records at all
--   b) Patients whose only insulin is within the 14-day window
-- Both cases are correctly treated as insulin naive.
-- ============================================================
DROP TABLE IF EXISTS InsulinHistory_HQ_Diab;
CREATE LOCAL TEMP TABLE InsulinHistory_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT
    f.MasterPatientID,
    CAST(f.DispenseCalendarDate AS DATE)                            AS InsulinDate
FROM FactISRD f
JOIN Drugs_HQ_Diab d ON f.MasterProductID = d.MasterProductID
WHERE f.ISRDBatchID IN (${ISRDBatchID2}$, ${ISRDBatchID1}$)
  AND d.Regimen IN ('BASAL INSULIN','BOLUS INSULIN','PREMIX INSULIN')
  AND f.FactISRDID > 0
;
SELECT ANALYZE_STATISTICS('InsulinHistory_HQ_Diab');

-- ============================================================
-- STEP 10b: PATIENT-LEVEL COMBO LAG
-- Materialises BeforeCombo at patient-month level BEFORE SOBClass.
-- BrandCombo has exactly 1 row per patient per month so LAG is
-- clean and genuinely NULL for a patient's first ever market month.
-- This fixed Treatment naive first / Treatment naive not appearing:
-- the old CTE computed LAG over ClassDom (N rows per patient-month)
-- which picked up combos from other drug class rows of same month.
-- ============================================================
DROP TABLE IF EXISTS PatientComboLag_HQ_Diab;
CREATE LOCAL TEMP TABLE PatientComboLag_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT
    MasterPatientID,
    Month,
    CurrentCombo                                                    AS PresentCombo,
    LAG(CurrentCombo) OVER (
        PARTITION BY MasterPatientID ORDER BY Month
    )                                                                AS BeforeCombo,
    LAG(Month) OVER (
        PARTITION BY MasterPatientID ORDER BY Month
    )                                                                AS LastMonthAny
FROM BrandCombo_HQ_Diab
;
SELECT ANALYZE_STATISTICS('PatientComboLag_HQ_Diab');

-- ============================================================
-- STEP 11: SOB CLASSIFICATION
-- [Octavian] Naive categories: GapMonthsAny + MonthsObservable only
-- [Octavian] IsInsulinNaive: LEFT JOIN + MIN
-- [Fix v0.94] Add-on vs Repeat vs Win:
--   Previously: Add-on required INSTR(PresentCombo, BeforeCombo) > 0,
--   i.e. the ENTIRE prior combo string had to appear as an exact
--   substring of the new combo string. Combo strings are built by
--   concatenating brand display names in ALPHABETICAL order (Step 7),
--   so adding a new brand that alphabetically sorts into the MIDDLE
--   of the existing combo breaks the substring test even though
--   nothing was actually dropped -- e.g. "LANTUS + TRAJENTA" is not
--   a substring of "LANTUS + OZEMPIC + TRAJENTA", even though the
--   patient's LANTUS and TRAJENTA are both still active and Ozempic
--   is a textbook Add-on. That case fell through to the final ELSE
--   'Repeat', which is exactly the reported bug: a patient who
--   should be Add-on showed up as Repeat, with Before correctly
--   missing the new brand (it wasn't there) but the Category wrong.
--   Fixed by replacing the string test with a real per-class check:
--   does the patient have at least one OTHER active drug class this
--   month (HasOtherActiveClassThisMonth, computed below via EXISTS
--   against ClassDom_HQ_Diab directly, not string matching)? This
--   matches the confirmed methodology (clarifying Q1: if OAD stays
--   active when Ozempic is added, that's still Add-on) and is
--   immune to alphabetical-ordering artifacts.
-- ============================================================
DROP TABLE IF EXISTS SOBClass_HQ_Diab;
CREATE LOCAL TEMP TABLE SOBClass_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH ClassHistory AS (
    SELECT
        c.Month, c.MasterPatientID, c.DrugClass, c.Regimen,
        c.BrandName, c.ProductStrength, c.HCPMasterID,
        LAG(c.BrandName) OVER (
            PARTITION BY c.MasterPatientID, c.DrugClass
            ORDER BY c.Month
        )                                                           AS LastBrand,
        LAG(c.Month) OVER (
            PARTITION BY c.MasterPatientID, c.DrugClass
            ORDER BY c.Month
        )                                                           AS LastMonthClass
    FROM ClassDom_HQ_Diab c
),
-- [Fix v0.95] Vertica rejects a correlated subquery in the SELECT list
-- of a query that has GROUP BY (error 4818) unless the subquery is part
-- of the GROUP BY -- BaseSOB below already has to GROUP BY (for the
-- MIN(ih.InsulinDate) aggregate), so the EXISTS subquery this used to be
-- doesn't fly there. Precomputed here instead as a plain per-(patient,
-- month) aggregate and LEFT JOINed into BaseSOB: if a patient has 2+
-- distinct active drug classes in a month, then whichever one BaseSOB's
-- row is for, there is necessarily at least one OTHER active class that
-- month -- same result as the EXISTS check, just expressed as a join.
ClassCountByMonth AS (
    SELECT MasterPatientID, Month, COUNT(DISTINCT DrugClass) AS NumActiveClasses
    FROM ClassDom_HQ_Diab
    GROUP BY MasterPatientID, Month
),
BaseSOB AS (
    SELECT
        ch.Month, ch.MasterPatientID, ch.DrugClass, ch.Regimen,
        ch.BrandName, ch.ProductStrength, ch.HCPMasterID,
        pcl.PresentCombo,
        -- [Fix v0.96] "Repeat patient doesn't have focus brand in Before":
        -- LastBrand/LastMonthClass (above) use a per-class LAG that bridges
        -- gaps -- a patient who dropped LANTUS for a couple of months then
        -- came back is correctly Repeat (gap bridged, per the confirmed
        -- methodology). But pcl.BeforeCombo is a DIFFERENT, calendar-
        -- adjacent LAG (literally last calendar month's combo) -- during
        -- that gap it never contained LANTUS at all, so a gap-bridged
        -- Repeat row's Before was silently missing the focus brand even
        -- though the category was right. When LastMonthClass exists (Win/
        -- Repeat), source Before from the combo AT that gap-bridged month
        -- instead -- consistent with what LastBrand/Category are actually
        -- based on. Add-on/naive rows have no LastMonthClass (first time in
        -- this class), so they correctly keep falling back to the
        -- calendar-adjacent pcl.BeforeCombo, which is what "did the patient
        -- have any other therapy last month" should mean for them.
        COALESCE(bc_lastclass.CurrentCombo, pcl.BeforeCombo)        AS BeforeCombo,
        ch.LastBrand, ch.LastMonthClass, pcl.LastMonthAny,
        -- [Octavian] IsInsulinNaive via LEFT JOIN + MIN.
        -- If no insulin exists before Month-14 ? MIN IS NULL ? naive=1
        CASE
            WHEN MIN(ih.InsulinDate) IS NULL THEN 1
            ELSE 0
        END                                                         AS IsInsulinNaive,
        DATEDIFF('month', dbe.DBEntryDate, ch.Month)               AS MonthsObservable,
        -- [Fix v0.94, adjusted v0.95] replaces INSTR(PresentCombo,BeforeCombo)
        -- -- see the Step 11 header comment above for why that broke.
        CASE WHEN ccm.NumActiveClasses > 1 THEN 1 ELSE 0 END        AS HasOtherActiveClassThisMonth
    FROM ClassHistory ch
    JOIN PatientComboLag_HQ_Diab pcl
        ON  ch.Month           = pcl.Month
        AND ch.MasterPatientID = pcl.MasterPatientID
    LEFT JOIN PatientDBEntry_HQ_Diab dbe
        ON  ch.MasterPatientID = dbe.MasterPatientID
    LEFT JOIN InsulinHistory_HQ_Diab ih
        ON  ih.MasterPatientID = ch.MasterPatientID
        AND ih.InsulinDate     < CAST(ch.Month AS DATE) - 14
    LEFT JOIN ClassCountByMonth ccm
        ON  ccm.MasterPatientID = ch.MasterPatientID
        AND ccm.Month           = ch.Month
    LEFT JOIN BrandCombo_HQ_Diab bc_lastclass
        ON  bc_lastclass.MasterPatientID = ch.MasterPatientID
        AND bc_lastclass.Month           = ch.LastMonthClass
    GROUP BY
        ch.Month, ch.MasterPatientID, ch.DrugClass, ch.Regimen,
        ch.BrandName, ch.ProductStrength, ch.HCPMasterID,
        pcl.PresentCombo, pcl.BeforeCombo, bc_lastclass.CurrentCombo,
        ch.LastBrand, ch.LastMonthClass, pcl.LastMonthAny,
        dbe.DBEntryDate, ccm.NumActiveClasses
),
WithGap AS (
    SELECT *,
        CASE WHEN LastMonthClass IS NULL THEN NULL
             ELSE CAST(DATEDIFF('month', LastMonthClass, Month) AS INTEGER)
        END                                                         AS GapMonths,
        CASE WHEN LastMonthAny IS NULL THEN NULL
             ELSE CAST(DATEDIFF('month', LastMonthAny, Month) AS INTEGER)
        END                                                         AS GapMonthsAny
    FROM BaseSOB
)
SELECT
    Month, MasterPatientID, DrugClass, Regimen,
    BrandName, ProductStrength, HCPMasterID,
    PresentCombo, BeforeCombo, LastBrand, IsInsulinNaive,
    CASE
        -- -------------------------------------------------------
        -- Naive categories: GapMonthsAny + MonthsObservable only
        -- -------------------------------------------------------

        -- Treatment naive first: no prior diabetes drugs at all
        WHEN GapMonthsAny IS NULL
         AND MonthsObservable >= 12
        THEN 'Treatment naive first'

        -- Treatment naive: had diabetes drugs but >= 12m ago
        WHEN GapMonthsAny >= 12
         AND MonthsObservable >= 12
        THEN 'Treatment naive'

        -- New to database: no prior or long gap, observable < 12m
        WHEN (GapMonthsAny IS NULL OR GapMonthsAny >= 12)
         AND MonthsObservable < 12
        THEN 'New to database'

        -- -------------------------------------------------------
        -- Repeat: same brand, gap bridged per Annika email.
        -- Checked before Add-on to prevent same-brand returns
        -- from falling into Add-on.
        -- -------------------------------------------------------
        WHEN LastBrand IS NOT NULL
         AND BrandName = LastBrand
        THEN 'Repeat'

        -- -------------------------------------------------------
        -- Win: different brand in same class where patient had a
        -- prior brand (LastBrand IS NOT NULL).
        -- [Yipeng] If LastBrand exists and brand changed = Win.
        -- Checked BEFORE Add-on to prevent brand switches within
        -- the same class from being classified as Add-on.
        -- e.g. HUMALOG ? HUMALOG MIX25 = Win not Add-on.
        -- -------------------------------------------------------
        WHEN LastBrand IS NOT NULL
         AND BrandName <> LastBrand
        THEN 'Win'

        -- -------------------------------------------------------
        -- Add-on: patient enters this class for the FIRST TIME
        -- (LastBrand IS NULL = no prior brand in this class ever)
        -- AND they already have other diabetes drugs active
        -- (BeforeCombo IS NOT NULL = existing therapy present)
        -- AND at least one other drug class is still active THIS
        -- month (HasOtherActiveClassThisMonth = 1) -- i.e. existing
        -- therapy persists, this is genuinely something new being
        -- added on top, not a full switch.
        -- [Fix v0.94] was INSTR(PresentCombo,BeforeCombo)>0 -- see
        -- Step 11 header comment for why that misfired.
        -- -------------------------------------------------------
        WHEN LastBrand IS NULL
         AND BeforeCombo IS NOT NULL AND BeforeCombo <> ''
         AND HasOtherActiveClassThisMonth = 1
        THEN 'Add on'

        -- -------------------------------------------------------
        -- Win (cross-class): patient's FIRST TIME EVER in this class
        -- (LastBrand IS NULL), they had other active therapy last
        -- month (BeforeCombo IS NOT NULL), but NOTHING else is active
        -- THIS month (HasOtherActiveClassThisMonth = 0) -- i.e. that
        -- other therapy was fully dropped and replaced by this brand.
        -- [Fix v0.98] Yipeng: "Ozempic repeat patients don't have
        -- Ozempic in Before" -- traced to this exact gap. LastBrand is
        -- scoped PER DRUG CLASS, so a patient's first-ever GLP-1 fill
        -- always has LastBrand=NULL for the GLP-1 class, even when
        -- they are plainly switching in from a fully-dropped OTHER
        -- class (e.g. JARDIANCE, an SGLT-2, replaced entirely by
        -- Ozempic). Win only checked LastBrand IS NOT NULL (a same-
        -- class brand switch), so this genuinely cross-class win had
        -- nowhere to land: it isn't Add-on (nothing persists), so it
        -- fell all the way through to the 'Repeat' fallback below --
        -- Before then correctly showed the dropped brand (JARDIANCE),
        -- but the Category was wrong, making it look like "Repeat
        -- without the focus brand in Before" instead of what it
        -- actually is: a Win from JARDIANCE.
        -- -------------------------------------------------------
        WHEN LastBrand IS NULL
         AND BeforeCombo IS NOT NULL AND BeforeCombo <> ''
         AND HasOtherActiveClassThisMonth = 0
        THEN 'Win'

        -- Fallback: Repeat
        -- Covers first-ever month in this class with no prior
        -- combo at all (LastBrand IS NULL, BeforeCombo IS NULL) --
        -- genuinely nothing to win from, nothing to add on to.
        ELSE 'Repeat'
    END                                                             AS SOB_Category
FROM WithGap
;
SELECT ANALYZE_STATISTICS('SOBClass_HQ_Diab');


-- ============================================================
-- STEP 12: LOSE DETECTION
-- Patient stopped a class and switched to something else.
-- Gap > 1 month to next active month in same class AND patient
-- has an active combo in M+1 (still in market = Lose not Drop off).
-- Mirror of Win on the losing brand's side.
-- ============================================================
DROP TABLE IF EXISTS DropOff_HQ_Diab;
CREATE LOCAL TEMP TABLE DropOff_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH ClassWithNext AS (
    SELECT
        c.Month, c.MasterPatientID, c.DrugClass, c.Regimen,
        c.BrandName AS LastBrand, c.HCPMasterID,
        LEAD(c.Month) OVER (
            PARTITION BY c.MasterPatientID, c.DrugClass
            ORDER BY c.Month
        )                                                           AS NextClassMonth
    FROM ClassDom_HQ_Diab c
)
SELECT
    ADD_MONTHS(cwn.Month, 1)                                        AS Month,
    cwn.MasterPatientID, cwn.DrugClass, cwn.Regimen,
    cwn.LastBrand, cwn.HCPMasterID,
    bc_last.CurrentCombo                                            AS BeforeCombo,
    bc_next.CurrentCombo                                            AS PresentCombo
FROM ClassWithNext cwn
JOIN BrandCombo_HQ_Diab bc_last
    ON  cwn.Month           = bc_last.Month
    AND cwn.MasterPatientID = bc_last.MasterPatientID
LEFT JOIN BrandCombo_HQ_Diab bc_next
    ON  ADD_MONTHS(cwn.Month, 1) = bc_next.Month
    AND cwn.MasterPatientID      = bc_next.MasterPatientID
WHERE
    (cwn.NextClassMonth IS NULL
     OR CAST(DATEDIFF('month', cwn.Month, cwn.NextClassMonth) AS INTEGER) > 1)
    -- [Octavian] Drop-off: patient still active in market (has other brands in M+1)
    AND bc_next.CurrentCombo IS NOT NULL
    AND bc_next.CurrentCombo <> ''
    AND ADD_MONTHS(cwn.Month, 1) >= DATE('${sDate}$')
    AND ADD_MONTHS(cwn.Month, 1) <  DATE('${eDate}$')
;
SELECT ANALYZE_STATISTICS('DropOff_HQ_Diab');



DROP TABLE IF EXISTS Lose_HQ_Diab;
CREATE LOCAL TEMP TABLE Lose_HQ_Diab ON COMMIT PRESERVE ROWS AS
SELECT
    s.Month,
    s.MasterPatientID,
    s.DrugClass,
    s.Regimen,
    -- [Octavian] Focus_Brand for Lose = LastBrand (the brand that was replaced)
    s.LastBrand,
    s.HCPMasterID,
    -- BeforeCombo = what patient was on before the Win/switch
    s.BeforeCombo,
    -- PresentCombo = what patient is on after the Win/switch
    s.PresentCombo
FROM SOBClass_HQ_Diab s
WHERE s.SOB_Category  = 'Win'
  AND s.LastBrand     IS NOT NULL
  AND s.Month         >= DATE('${sDate}$')
;
SELECT ANALYZE_STATISTICS('Lose_HQ_Diab');

-- ============================================================
-- STEP 13: DROP OFF DETECTION
-- Patient stopped a class and left the market entirely.
-- Same gap detection as Lose but patient has NO active combo
-- in M+1 (full market exit). Lose + Drop off = Switch away.
-- ============================================================
DROP TABLE IF EXISTS SwitchOut_HQ_Diab;
CREATE LOCAL TEMP TABLE SwitchOut_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH ClassWithNext AS (
    SELECT
        c.Month, c.MasterPatientID, c.DrugClass, c.Regimen,
        c.BrandName AS LastBrand, c.HCPMasterID,
        LEAD(c.Month) OVER (
            PARTITION BY c.MasterPatientID, c.DrugClass
            ORDER BY c.Month
        )                                                           AS NextClassMonth
    FROM ClassDom_HQ_Diab c
)
SELECT
    ADD_MONTHS(cwn.Month, 1)                                        AS Month,
    cwn.MasterPatientID, cwn.DrugClass, cwn.Regimen,
    cwn.LastBrand, cwn.HCPMasterID,
    bc_last.CurrentCombo                                            AS BeforeCombo,
    bc_next.CurrentCombo                                            AS PresentCombo
FROM ClassWithNext cwn
JOIN BrandCombo_HQ_Diab bc_last
    ON  cwn.Month           = bc_last.Month
    AND cwn.MasterPatientID = bc_last.MasterPatientID
LEFT JOIN BrandCombo_HQ_Diab bc_next
    ON  ADD_MONTHS(cwn.Month, 1) = bc_next.Month
    AND cwn.MasterPatientID      = bc_next.MasterPatientID
WHERE
    (cwn.NextClassMonth IS NULL
     OR CAST(DATEDIFF('month', cwn.Month, cwn.NextClassMonth) AS INTEGER) > 1)
    -- Patient left market entirely – no active brands in M+1
    AND (bc_next.CurrentCombo IS NULL OR bc_next.CurrentCombo = '')
    AND ADD_MONTHS(cwn.Month, 1) >= DATE('${sDate}$')
    AND ADD_MONTHS(cwn.Month, 1) <  DATE('${eDate}$')
;
SELECT ANALYZE_STATISTICS('SwitchOut_HQ_Diab');
-- ============================================================
-- STEP 14: OFF DRUG DETECTION
-- Last active month + 1 to 11 months after, patient absent.
-- Represents observation window before 12-month End threshold.
-- ============================================================
DROP TABLE IF EXISTS OffDrug_HQ_Diab;
CREATE LOCAL TEMP TABLE OffDrug_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH LastActive AS (
    -- Last month the patient was active in each drug class
    SELECT MasterPatientID, DrugClass, Regimen, BrandName, HCPMasterID,
        MAX(Month)                                                  AS LastActiveMonth
    FROM ClassDom_HQ_Diab
    GROUP BY 1,2,3,4,5
),
NextAnyDiabetes AS (
    -- [Octavian] Find first month after LastActive where patient returns
    -- to ANY diabetes drug (checks BrandCombo = all market activity)
    SELECT
        la.MasterPatientID,
        la.DrugClass,
        la.LastActiveMonth,
        MIN(bc.Month)                                               AS NextReturnMonth
    FROM LastActive la
    LEFT JOIN BrandCombo_HQ_Diab bc
        ON  bc.MasterPatientID = la.MasterPatientID
        AND bc.Month           > la.LastActiveMonth
    GROUP BY 1,2,3
)
SELECT
    -- [Octavian] Off Drug reported at M+1 (first month without supply)
    ADD_MONTHS(la.LastActiveMonth, 1)                               AS Month,
    la.MasterPatientID, la.DrugClass, la.Regimen,
    la.BrandName, la.HCPMasterID
FROM LastActive la
JOIN NextAnyDiabetes nd
    ON  la.MasterPatientID = nd.MasterPatientID
    AND la.DrugClass       = nd.DrugClass
WHERE ADD_MONTHS(la.LastActiveMonth, 1) >= DATE('${sDate}$')
  AND ADD_MONTHS(la.LastActiveMonth, 1) <  DATE('${eDate}$')
  AND (
      -- [Octavian] Condition A: less than 12 months of forward data available
      -- Cannot confirm End so classify as Off Drug
      ADD_MONTHS(la.LastActiveMonth, 12) >= DATE('${eDate}$')
      OR
      -- [Octavian] Condition B: patient returns to any diabetes drug within 12m
      (
          nd.NextReturnMonth IS NOT NULL
          AND CAST(DATEDIFF('month', la.LastActiveMonth,
                            nd.NextReturnMonth) AS INTEGER) <= 12
      )
  )
;
SELECT ANALYZE_STATISTICS('OffDrug_HQ_Diab');

-- ============================================================
-- STEP 15: END DETECTION
-- First month after last active (M+1), no return in 12 months.
-- Per Yipeng: End placed at M+1 not M+12.
-- ============================================================
DROP TABLE IF EXISTS End_HQ_Diab;
CREATE LOCAL TEMP TABLE End_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH LastActive AS (
    SELECT MasterPatientID, DrugClass, Regimen, BrandName, HCPMasterID,
        MAX(Month)                                                  AS LastActiveMonth
    FROM ClassDom_HQ_Diab
    GROUP BY 1,2,3,4,5
)
SELECT
    -- [Octavian] End placed at M+1 per Yipeng
    ADD_MONTHS(la.LastActiveMonth, 1)                               AS Month,
    la.MasterPatientID, la.DrugClass, la.Regimen,
    la.BrandName, la.HCPMasterID
FROM LastActive la
WHERE ADD_MONTHS(la.LastActiveMonth, 1) >= DATE('${sDate}$')
  AND ADD_MONTHS(la.LastActiveMonth, 1) <  DATE('${eDate}$')
  -- [Octavian] Must have 12 months of forward data to confirm End
  -- (otherwise it would be Off Drug, not End)
  AND ADD_MONTHS(la.LastActiveMonth, 12) < DATE('${eDate}$')
  -- [Octavian] No diabetes drugs in next 12 months – checks ALL classes
  -- via BrandCombo (market-wide), not just same DrugClass
  AND NOT EXISTS (
      SELECT 1 FROM BrandCombo_HQ_Diab bc
      WHERE bc.MasterPatientID = la.MasterPatientID
        AND bc.Month           > la.LastActiveMonth
        AND bc.Month           <= ADD_MONTHS(la.LastActiveMonth, 12)
  )
;
SELECT ANALYZE_STATISTICS('End_HQ_Diab');

-- ============================================================
-- STEP 16: REGIMEN COMBO STRINGS
-- Three combo strings per patient per month: Basal, Bolus, MNIAD.
-- MNIAD = GLP-1 + DPP_IV + SGLT_2.
-- [Fix v0.94] MNIAD now uses the same indication-aware display
-- name as Step 7 (ClassDomDisplay_HQ_Diab.DisplayNameStrength) so
-- Before_MNIAD/Present_MNIAD are consistent with Before/Present
-- and Focus_Brand -- previously this rebuilt the GLP-1 display
-- name from scratch without the indication suffix.
-- ============================================================
DROP TABLE IF EXISTS RegimenCombo_HQ_Diab;
CREATE LOCAL TEMP TABLE RegimenCombo_HQ_Diab ON COMMIT PRESERVE ROWS AS
WITH BasalRanked AS (
    SELECT Month, MasterPatientID, BrandName AS DisplayName,
        ROW_NUMBER() OVER (PARTITION BY Month,MasterPatientID ORDER BY BrandName) AS rn,
        COUNT(*)     OVER (PARTITION BY Month,MasterPatientID)                    AS cnt
    FROM ClassDom_HQ_Diab WHERE Regimen = 'BASAL INSULIN'
),
BolusRanked AS (
    SELECT Month, MasterPatientID, BrandName AS DisplayName,
        ROW_NUMBER() OVER (PARTITION BY Month,MasterPatientID ORDER BY BrandName) AS rn,
        COUNT(*)     OVER (PARTITION BY Month,MasterPatientID)                    AS cnt
    FROM ClassDom_HQ_Diab WHERE Regimen = 'BOLUS INSULIN'
),
MNIADRanked AS (
    SELECT Month, MasterPatientID,
        DisplayNameStrength                                         AS DisplayName,
        ROW_NUMBER() OVER (
            PARTITION BY Month, MasterPatientID
            ORDER BY DisplayNameStrength
        )                                                           AS rn,
        COUNT(*) OVER (PARTITION BY Month, MasterPatientID)        AS cnt
    FROM ClassDomDisplay_HQ_Diab WHERE Regimen IN ('GLP-1','DPP_IV','SGLT_2')
),
BasalPivot AS (
    SELECT DISTINCT Month, MasterPatientID,
        TRIM(
            MAX(CASE WHEN rn=1 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID)
            ||CASE WHEN cnt>=2 THEN ' + '||MAX(CASE WHEN rn=2 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=3 THEN ' + '||MAX(CASE WHEN rn=3 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=4 THEN ' + '||MAX(CASE WHEN rn=4 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ) AS BasalCombo FROM BasalRanked
),
BolusPivot AS (
    SELECT DISTINCT Month, MasterPatientID,
        TRIM(
            MAX(CASE WHEN rn=1 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID)
            ||CASE WHEN cnt>=2 THEN ' + '||MAX(CASE WHEN rn=2 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=3 THEN ' + '||MAX(CASE WHEN rn=3 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=4 THEN ' + '||MAX(CASE WHEN rn=4 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ) AS BolusCombo FROM BolusRanked
),
MNIADPivot AS (
    SELECT DISTINCT Month, MasterPatientID,
        TRIM(
            MAX(CASE WHEN rn=1 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID)
            ||CASE WHEN cnt>=2 THEN ' + '||MAX(CASE WHEN rn=2 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=3 THEN ' + '||MAX(CASE WHEN rn=3 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=4 THEN ' + '||MAX(CASE WHEN rn=4 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=5 THEN ' + '||MAX(CASE WHEN rn=5 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
            ||CASE WHEN cnt>=6 THEN ' + '||MAX(CASE WHEN rn=6 THEN DisplayName ELSE '' END) OVER (PARTITION BY Month,MasterPatientID) ELSE '' END
        ) AS MNIADCombo FROM MNIADRanked
),
AllPatientMonths AS (SELECT DISTINCT Month, MasterPatientID FROM ClassDom_HQ_Diab)
SELECT
    a.Month, a.MasterPatientID,
    NVL(b.BasalCombo,  '')                                          AS BasalCombo,
    NVL(bo.BolusCombo, '')                                          AS BolusCombo,
    NVL(m.MNIADCombo,  '')                                          AS MNIADCombo
FROM AllPatientMonths a
LEFT JOIN BasalPivot b  ON a.Month = b.Month  AND a.MasterPatientID = b.MasterPatientID
LEFT JOIN BolusPivot bo ON a.Month = bo.Month AND a.MasterPatientID = bo.MasterPatientID
LEFT JOIN MNIADPivot m  ON a.Month = m.Month  AND a.MasterPatientID = m.MasterPatientID
;
SELECT ANALYZE_STATISTICS('RegimenCombo_HQ_Diab');

-- ============================================================
-- STEP 17: LAST ACTIVE MONTH HELPERS
-- Pre-compute prior active month per patient per event month.
-- Avoids correlated subqueries in ON clauses (Vertica limitation).
-- Three tables: for SOB categories, for Lose, for Drop off.
-- ============================================================
DROP TABLE IF EXISTS LastActiveMonth_SOB;
CREATE LOCAL TEMP TABLE LastActiveMonth_SOB ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT s.MasterPatientID, s.Month,
    MAX(bc2.Month) OVER (PARTITION BY s.MasterPatientID, s.Month) AS LastMonth
FROM SOBClass_HQ_Diab s
JOIN BrandCombo_HQ_Diab bc2
    ON  bc2.MasterPatientID = s.MasterPatientID
    AND bc2.Month           < s.Month
WHERE s.SOB_Category IN ('Add on','Win','Insulin naive')
;

-- [Octavian] Lose now derived from Win – helper uses Lose_HQ_Diab
DROP TABLE IF EXISTS LastActiveMonth_Lose;
CREATE LOCAL TEMP TABLE LastActiveMonth_Lose ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT l.MasterPatientID, l.Month,
    MAX(bc2.Month) OVER (PARTITION BY l.MasterPatientID, l.Month) AS LastMonth
FROM Lose_HQ_Diab l
JOIN BrandCombo_HQ_Diab bc2
    ON  bc2.MasterPatientID = l.MasterPatientID
    AND bc2.Month           < l.Month
;

-- [Octavian] Drop-off helper uses DropOff_HQ_Diab (corrected from old Lose)
DROP TABLE IF EXISTS LastActiveMonth_Drop;
CREATE LOCAL TEMP TABLE LastActiveMonth_Drop ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT d.MasterPatientID, d.Month,
    MAX(bc2.Month) OVER (PARTITION BY d.MasterPatientID, d.Month) AS LastMonth
FROM DropOff_HQ_Diab d
JOIN BrandCombo_HQ_Diab bc2
    ON  bc2.MasterPatientID = d.MasterPatientID
    AND bc2.Month           < d.Month
;

-- ============================================================
-- STEP 18: BASE TABLE
-- [Yipeng] Brand-level rows added for GLP-1s in addition to
-- strength-level rows. For GLP-1 brands, two sets of rows:
--   1. Strength level: Focus_Brand = ProductStrength (existing)
--   2. Brand level:    Focus_Brand = BrandName (new)
-- Brand-level rows aggregate all strengths of the same brand.
-- SOB classification at brand level uses BrandName comparison
-- so DULAGLUTIDE_0p75 ? DULAGLUTIDE_1p5 = Repeat at brand level
-- (same brand, different strength = not a switch at brand level)
--
-- [Fix v0.94] Focus_Brand (strength AND brand level), Before,
-- Present, Before/Present_MNIAD all now use the indication-aware
-- display names from ClassDomDisplay_HQ_Diab / Step 6b, so
-- Ozempic/Mounjaro read "... DIABETES"/"... OBESITY" and Wegovy
-- always reads "... OBESITY", at both strength level (was
-- already correct on the brand itself, just missing on Before/
-- Present) and brand level (was bare BrandName with NO indication
-- split at all -- this is why "Ozempic" at brand level looked
-- like one blended total instead of two rows).
-- Mounjaro Obesity rows are suppressed before 2026-05 (launch
-- month) instead of being backfilled with fabricated history.
-- ============================================================
DROP TABLE IF EXISTS SOB_HQ_Diabetes_Base;
CREATE LOCAL TEMP TABLE SOB_HQ_Diabetes_Base ON COMMIT PRESERVE ROWS AS

-- -------------------------------------------------------
-- STRENGTH LEVEL: existing rows – GLP-1 uses indication-aware ProductStrength
-- -------------------------------------------------------
-- Active categories (strength level)
SELECT
    'AU'                                                            AS Country,
    CAST(TO_CHAR(s.Month,'YYYYMM') AS INTEGER)                      AS Date,
    'All'                                                           AS Region,
    '4_SoB'                                                         AS Metric,
    -- [Fix v0.99] Type only reflects the patient's own flag on GLP-1
    -- rows -- everywhere else it's forced to DIABETES, matching exactly
    -- what past waves always showed (those rows could only ever be
    -- Diabetes before Obesity-flagged patients were in scope at all).
    CASE WHEN s.Regimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END                                       AS Type,
    s.SOB_Category                                                  AS Category,
    s.Regimen,
    -- Strength level: GLP-1 uses the indication-aware display name
    CASE WHEN s.Regimen = 'GLP-1' AND s.BrandName IN ('OZEMPIC','MOUNJARO')
         THEN s.ProductStrength || ' ' || NVL(pt.PatientType,'UNKNOWN')
         WHEN s.Regimen = 'GLP-1' AND s.BrandName = 'WEGOVY'
         THEN s.ProductStrength || ' OBESITY'
         WHEN s.Regimen = 'GLP-1' THEN s.ProductStrength
         ELSE s.BrandName END                                       AS Focus_Brand,
    CASE WHEN s.SOB_Category IN ('Treatment naive first',
                                  'Treatment naive')
         THEN NULL
         ELSE NULLIF(s.BeforeCombo,'')
    END                                                             AS Before,
    NULLIF(s.PresentCombo,'')                                       AS Present,
    CASE WHEN s.SOB_Category IN ('Add on','Win','Insulin naive')
         THEN NULLIF(rc_bef.BasalCombo,'') ELSE NULL END            AS Before_Basal,
    NULLIF(rc_cur.BasalCombo,'')                                    AS Present_Basal,
    CASE WHEN s.SOB_Category IN ('Add on','Win','Insulin naive')
         THEN NULLIF(rc_bef.BolusCombo,'') ELSE NULL END            AS Before_Bolus,
    NULLIF(rc_cur.BolusCombo,'')                                    AS Present_Bolus,
    CASE WHEN s.SOB_Category IN ('Add on','Win','Insulin naive')
         THEN NULLIF(rc_bef.MNIADCombo,'') ELSE NULL END            AS Before_MNIAD,
    NULLIF(rc_cur.MNIADCombo,'')                                    AS Present_MNIAD,
    NVL(d.Specialty,'Others')                                       AS Specialty,
    s.MasterPatientID
FROM SOBClass_HQ_Diab s
LEFT JOIN PatientType_HQ_Diab pt  ON s.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc_cur
    ON  s.Month           = rc_cur.Month
    AND s.MasterPatientID = rc_cur.MasterPatientID
LEFT JOIN LastActiveMonth_SOB lam
    ON  s.MasterPatientID = lam.MasterPatientID
    AND s.Month           = lam.Month
LEFT JOIN RegimenCombo_HQ_Diab rc_bef
    ON  rc_bef.MasterPatientID = lam.MasterPatientID
    AND rc_bef.Month           = lam.LastMonth
LEFT JOIN Docs_HQ_Diab d ON s.HCPMasterID = d.HCPMasterID
WHERE s.Month >= DATE('${sDate}$')
  AND s.SOB_Category IN ('Treatment naive first','Treatment naive','New to database',
                          'Insulin naive','Add on','Win','Repeat')
  AND NOT (s.BrandName = 'MOUNJARO' AND NVL(pt.PatientType,'UNKNOWN') = 'OBESITY'
           AND s.Month < DATE('2026-05-01'))

UNION ALL

-- -------------------------------------------------------
-- BRAND LEVEL: new rows for GLP-1s only
-- [Yipeng] GLP-1 brands get additional brand-level rows
-- Focus_Brand = BrandName (e.g. DULAGLUTIDE not DULAGLUTIDE_1p5)
-- SOB classification re-derived at brand level:
-- Same brand = Repeat (regardless of strength change)
-- -------------------------------------------------------
SELECT
    'AU'                                                            AS Country,
    CAST(TO_CHAR(s.Month,'YYYYMM') AS INTEGER)                      AS Date,
    'All'                                                           AS Region,
    '4_SoB'                                                         AS Metric,
    NVL(pt.PatientType, 'UNKNOWN')                                      AS Type,
    -- [Yipeng] Brand-level SOB category:
    -- If LastBrand = BrandName at brand level ? Repeat
    -- (covers DULAGLUTIDE_0p75 ? DULAGLUTIDE_1p5 = Repeat)
    CASE
        WHEN s.SOB_Category IN ('Treatment naive first','Treatment naive',
                                 'New to database')
        THEN s.SOB_Category
        WHEN s.LastBrand = s.BrandName
          OR s.SOB_Category = 'Repeat'
        THEN 'Repeat'
        WHEN s.SOB_Category IN ('Add on')
        THEN 'Add on'
        -- Win at strength level but same brand = Repeat at brand level
        WHEN s.SOB_Category = 'Win'
          AND s.LastBrand = s.BrandName
        THEN 'Repeat'
        WHEN s.SOB_Category = 'Win'
          AND (s.LastBrand IS NULL OR s.LastBrand <> s.BrandName)
        THEN 'Win'
        ELSE s.SOB_Category
    END                                                             AS Category,
    s.Regimen,
    -- [Fix v0.94] Brand level: GLP-1 uses BrandName + indication suffix
    -- (was bare BrandName -- Ozempic Diabetes and Ozempic Obesity used
    -- to collapse into one "OZEMPIC" total row at this level).
    CASE WHEN s.BrandName IN ('OZEMPIC','MOUNJARO')
         THEN s.BrandName || ' ' || NVL(pt.PatientType,'UNKNOWN')
         WHEN s.BrandName = 'WEGOVY'
         THEN s.BrandName || ' OBESITY'
         ELSE s.BrandName END                                       AS Focus_Brand,
    CASE WHEN s.SOB_Category IN ('Treatment naive first',
                                  'Treatment naive')
         THEN NULL
         ELSE NULLIF(s.BeforeCombo,'')
    END                                                             AS Before,
    NULLIF(s.PresentCombo,'')                                       AS Present,
    CASE WHEN s.SOB_Category IN ('Add on','Win','Insulin naive')
         THEN NULLIF(rc_bef.BasalCombo,'') ELSE NULL END            AS Before_Basal,
    NULLIF(rc_cur.BasalCombo,'')                                    AS Present_Basal,
    CASE WHEN s.SOB_Category IN ('Add on','Win','Insulin naive')
         THEN NULLIF(rc_bef.BolusCombo,'') ELSE NULL END            AS Before_Bolus,
    NULLIF(rc_cur.BolusCombo,'')                                    AS Present_Bolus,
    CASE WHEN s.SOB_Category IN ('Add on','Win','Insulin naive')
         THEN NULLIF(rc_bef.MNIADCombo,'') ELSE NULL END            AS Before_MNIAD,
    NULLIF(rc_cur.MNIADCombo,'')                                    AS Present_MNIAD,
    NVL(d.Specialty,'Others')                                       AS Specialty,
    s.MasterPatientID
FROM SOBClass_HQ_Diab s
LEFT JOIN PatientType_HQ_Diab pt  ON s.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc_cur
    ON  s.Month           = rc_cur.Month
    AND s.MasterPatientID = rc_cur.MasterPatientID
LEFT JOIN LastActiveMonth_SOB lam
    ON  s.MasterPatientID = lam.MasterPatientID
    AND s.Month           = lam.Month
LEFT JOIN RegimenCombo_HQ_Diab rc_bef
    ON  rc_bef.MasterPatientID = lam.MasterPatientID
    AND rc_bef.Month           = lam.LastMonth
LEFT JOIN Docs_HQ_Diab d ON s.HCPMasterID = d.HCPMasterID
WHERE s.Month >= DATE('${sDate}$')
  AND s.Regimen = 'GLP-1'                                          -- GLP-1 only
  AND s.SOB_Category IN ('Treatment naive first','Treatment naive','New to database',
                          'Insulin naive','Add on','Win','Repeat')
  AND NOT (s.BrandName = 'MOUNJARO' AND NVL(pt.PatientType,'UNKNOWN') = 'OBESITY'
           AND s.Month < DATE('2026-05-01'))

UNION ALL

-- Insulin naive sub-category (strength level – unchanged, never GLP-1)
-- [Fix v0.99] Regimen here is always an insulin class, never GLP-1, so
-- Type is always DIABETES -- matches past waves exactly.
SELECT
    'AU', CAST(TO_CHAR(s.Month,'YYYYMM') AS INTEGER),
    'All','4_SoB',
    'DIABETES',
    'Insulin naive', s.Regimen,
    CASE WHEN s.Regimen = 'GLP-1' THEN s.ProductStrength
         ELSE s.BrandName END,
    NULLIF(s.BeforeCombo,''),
    NULLIF(s.PresentCombo,''),
    NULL, NULLIF(rc_cur.BasalCombo,''),
    NULL, NULLIF(rc_cur.BolusCombo,''),
    NULL, NULLIF(rc_cur.MNIADCombo,''),
    NVL(d.Specialty,'Others'), s.MasterPatientID
FROM SOBClass_HQ_Diab s
LEFT JOIN PatientType_HQ_Diab pt  ON s.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc_cur
    ON  s.Month           = rc_cur.Month
    AND s.MasterPatientID = rc_cur.MasterPatientID
LEFT JOIN Docs_HQ_Diab d ON s.HCPMasterID = d.HCPMasterID
WHERE s.Month >= DATE('${sDate}$')
  AND s.SOB_Category IN ('Win','Add on')
  AND s.IsInsulinNaive = 1
  AND s.Regimen IN ('BASAL INSULIN','BOLUS INSULIN','PREMIX INSULIN')

UNION ALL

-- Lose (strength level)
-- [Fix v0.94] Focus_Brand / Before now go through the same
-- indication-aware labeling as positive rows (previously bare
-- LastBrand with no strength or indication at all).
SELECT
    'AU', CAST(TO_CHAR(l.Month,'YYYYMM') AS INTEGER),
    'All','4_SoB',
    -- [Fix v0.99] Type only reflects the patient's flag when the
    -- dropped class was GLP-1; everything else forces DIABETES.
    CASE WHEN l.Regimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END,
    'Lose', l.Regimen,
    CASE WHEN l.LastBrand IN ('OZEMPIC','MOUNJARO')
         THEN l.LastBrand || ' ' || NVL(pt.PatientType,'UNKNOWN')
         WHEN l.LastBrand = 'WEGOVY'
         THEN l.LastBrand || ' OBESITY'
         ELSE l.LastBrand END                                       AS Focus_Brand,
    CASE
        WHEN l.BeforeCombo IS NULL OR l.BeforeCombo = ''
        THEN l.LastBrand
        WHEN INSTR(l.BeforeCombo, l.LastBrand) > 0
        THEN NULLIF(l.BeforeCombo,'')
        ELSE l.LastBrand || ' + ' || l.BeforeCombo
    END                                                             AS Before,
    NULLIF(l.PresentCombo,''),
    NULLIF(rc_bef.BasalCombo,''), NULLIF(rc_cur.BasalCombo,''),
    NULLIF(rc_bef.BolusCombo,''), NULLIF(rc_cur.BolusCombo,''),
    NULLIF(rc_bef.MNIADCombo,''), NULLIF(rc_cur.MNIADCombo,''),
    NVL(doc.Specialty,'Others'), l.MasterPatientID
FROM Lose_HQ_Diab l
LEFT JOIN PatientType_HQ_Diab pt  ON l.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc_cur
    ON  l.Month           = rc_cur.Month
    AND l.MasterPatientID = rc_cur.MasterPatientID
LEFT JOIN LastActiveMonth_Lose lam
    ON  l.MasterPatientID = lam.MasterPatientID
    AND l.Month           = lam.Month
LEFT JOIN RegimenCombo_HQ_Diab rc_bef
    ON  rc_bef.MasterPatientID = lam.MasterPatientID
    AND rc_bef.Month           = lam.LastMonth
LEFT JOIN Docs_HQ_Diab doc ON l.HCPMasterID = doc.HCPMasterID
WHERE l.Month >= DATE('${sDate}$')
  AND NOT (l.LastBrand = 'MOUNJARO' AND NVL(pt.PatientType,'UNKNOWN') = 'OBESITY'
           AND l.Month < DATE('2026-05-01'))

UNION ALL

-- Drop off
-- [Fix v0.94] Focus_Brand now goes through the same indication-aware
-- labeling as everywhere else (previously bare LastBrand).
SELECT
    'AU', CAST(TO_CHAR(d.Month,'YYYYMM') AS INTEGER),
    'All','4_SoB',
    -- [Fix v0.99] same GLP-1-only override as everywhere else.
    CASE WHEN d.Regimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END,
    'Drop off', d.Regimen,
    CASE WHEN d.LastBrand IN ('OZEMPIC','MOUNJARO')
         THEN d.LastBrand || ' ' || NVL(pt.PatientType,'UNKNOWN')
         WHEN d.LastBrand = 'WEGOVY'
         THEN d.LastBrand || ' OBESITY'
         ELSE d.LastBrand END                                       AS Focus_Brand,
    NULLIF(d.BeforeCombo,''), NULLIF(d.PresentCombo,''),
    NULLIF(rc_bef.BasalCombo,''), NULL,
    NULLIF(rc_bef.BolusCombo,''), NULL,
    NULLIF(rc_bef.MNIADCombo,''), NULL,
    NVL(doc.Specialty,'Others'), d.MasterPatientID
FROM DropOff_HQ_Diab d
LEFT JOIN PatientType_HQ_Diab pt  ON d.MasterPatientID = pt.MasterPatientID
LEFT JOIN LastActiveMonth_Drop lam
    ON  d.MasterPatientID = lam.MasterPatientID
    AND d.Month           = lam.Month
LEFT JOIN RegimenCombo_HQ_Diab rc_bef
    ON  rc_bef.MasterPatientID = lam.MasterPatientID
    AND rc_bef.Month           = lam.LastMonth
LEFT JOIN Docs_HQ_Diab doc ON d.HCPMasterID = doc.HCPMasterID
WHERE d.Month >= DATE('${sDate}$')
  AND NOT (d.LastBrand = 'MOUNJARO' AND NVL(pt.PatientType,'UNKNOWN') = 'OBESITY'
           AND d.Month < DATE('2026-05-01'))

UNION ALL

-- Off drug
-- [Fix v0.94] Focus_Brand now indication-aware for consistency.
SELECT
    'AU', CAST(TO_CHAR(od.Month,'YYYYMM') AS INTEGER),
    'All','4_SoB',
    -- [Fix v0.99] same GLP-1-only override as everywhere else.
    CASE WHEN od.Regimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END,
    'Off drug', od.Regimen,
    CASE WHEN od.BrandName IN ('OZEMPIC','MOUNJARO')
         THEN od.BrandName || ' ' || NVL(pt.PatientType,'UNKNOWN')
         WHEN od.BrandName = 'WEGOVY'
         THEN od.BrandName || ' OBESITY'
         ELSE od.BrandName END                                      AS Focus_Brand,
    'TOTAL', 'TOTAL',
    NULL,NULL,NULL,NULL,NULL,NULL,
    NVL(doc.Specialty,'Others'), od.MasterPatientID
FROM OffDrug_HQ_Diab od
LEFT JOIN PatientType_HQ_Diab pt  ON od.MasterPatientID = pt.MasterPatientID
LEFT JOIN Docs_HQ_Diab doc ON od.HCPMasterID = doc.HCPMasterID
WHERE od.Month >= DATE('${sDate}$')
  AND NOT (od.BrandName = 'MOUNJARO' AND NVL(pt.PatientType,'UNKNOWN') = 'OBESITY'
           AND od.Month < DATE('2026-05-01'))

UNION ALL

-- End
-- [Fix v0.94] Focus_Brand now indication-aware for consistency.
SELECT
    'AU', CAST(TO_CHAR(e.Month,'YYYYMM') AS INTEGER),
    'All','4_SoB',
    -- [Fix v0.99] same GLP-1-only override as everywhere else.
    CASE WHEN e.Regimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END,
    'End', e.Regimen,
    CASE WHEN e.BrandName IN ('OZEMPIC','MOUNJARO')
         THEN e.BrandName || ' ' || NVL(pt.PatientType,'UNKNOWN')
         WHEN e.BrandName = 'WEGOVY'
         THEN e.BrandName || ' OBESITY'
         ELSE e.BrandName END                                       AS Focus_Brand,
    'TOTAL', 'TOTAL',
    NULL,NULL,NULL,NULL,NULL,NULL,
    NVL(doc.Specialty,'Others'), e.MasterPatientID
FROM End_HQ_Diab e
LEFT JOIN PatientType_HQ_Diab pt  ON e.MasterPatientID = pt.MasterPatientID
LEFT JOIN Docs_HQ_Diab doc ON e.HCPMasterID = doc.HCPMasterID
WHERE e.Month >= DATE('${sDate}$')
  AND NOT (e.BrandName = 'MOUNJARO' AND NVL(pt.PatientType,'UNKNOWN') = 'OBESITY'
           AND e.Month < DATE('2026-05-01'))
;
SELECT ANALYZE_STATISTICS('SOB_HQ_Diabetes_Base');
-- ============================================================
-- STEP 19: FINAL AGGREGATION
-- Specialty rows + TOTAL rows from Base.
-- On drug = all active categories. Switch away = Lose + Drop off.
-- Category_short = Category_long = Category per Yipeng.
--
-- [Fix v0.94] On Drug and Switch away are now literal SUMs over
-- the category rows computed in CategoryRows below, instead of
-- separately recomputed COUNT(DISTINCT MasterPatientID) passes
-- over Base. The old On Drug count silently deduped a patient who
-- is both, say, Win and Insulin naive in the same month (Insulin
-- naive is unioned into Base as an EXTRA row for that same
-- patient/brand/month, alongside their Win row), so a fresh
-- DISTINCT COUNT across both rows counted them once, while the
-- category breakdown counted them once under Win AND once under
-- Insulin naive -- meaning On Drug came out LOWER than the sum of
-- the very categories it's supposed to total. On Drug is now
-- built as SUM(LRx_Panel) over exactly those 7 category rows, so
-- it always equals that sum by construction. Switch away is
-- unchanged in value (Lose/Drop off never had this double-row
-- issue) -- restructured for consistency and to avoid a second
-- full scan of Base.
-- ============================================================
DROP TABLE IF EXISTS SOB_HQ_Diabetes;
CREATE LOCAL TEMP TABLE SOB_HQ_Diabetes ON COMMIT PRESERVE ROWS AS
WITH CategoryRows AS (
    -- Specialty rows
    SELECT
        Country, Date, Region, Metric, Type,
        Category AS Category_short, Category AS Category_long, Category,
        Regimen, Focus_Brand, Before, Present,
        Before_Basal, Present_Basal, Before_Bolus, Present_Bolus,
        Before_MNIAD, Present_MNIAD, Specialty,
        'Pat' AS Count, COUNT(DISTINCT MasterPatientID) AS LRx_Panel
    FROM SOB_HQ_Diabetes_Base
    GROUP BY
        Country,Date,Region,Metric,Type,Category,Regimen,Focus_Brand,
        Before,Present,Before_Basal,Present_Basal,Before_Bolus,Present_Bolus,
        Before_MNIAD,Present_MNIAD,Specialty

    UNION ALL

    -- TOTAL rows
    SELECT
        Country, Date, Region, Metric, Type,
        Category, Category, Category,
        Regimen, Focus_Brand, Before, Present,
        Before_Basal, Present_Basal, Before_Bolus, Present_Bolus,
        Before_MNIAD, Present_MNIAD, 'TOTAL',
        'Pat', COUNT(DISTINCT MasterPatientID)
    FROM SOB_HQ_Diabetes_Base
    GROUP BY
        Country,Date,Region,Metric,Type,Category,Regimen,Focus_Brand,
        Before,Present,Before_Basal,Present_Basal,Before_Bolus,Present_Bolus,
        Before_MNIAD,Present_MNIAD
)
SELECT * FROM CategoryRows

UNION ALL

-- On drug specialty = SUM of the 7 positive-category specialty rows
SELECT
    Country, Date, Region, Metric, Type,
    'On drug','On drug','On drug',
    Regimen, Focus_Brand, NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    Specialty, 'Pat', SUM(LRx_Panel)
FROM CategoryRows
WHERE Category IN ('Treatment naive first','Treatment naive','New to database',
                    'Insulin naive','Add on','Win','Repeat')
  AND Specialty <> 'TOTAL'
GROUP BY Country,Date,Region,Metric,Type,Regimen,Focus_Brand,Specialty

UNION ALL

-- On drug TOTAL = SUM of the 7 positive-category TOTAL rows
SELECT
    Country, Date, Region, Metric, Type,
    'On drug','On drug','On drug',
    Regimen, Focus_Brand, NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    'TOTAL', 'Pat', SUM(LRx_Panel)
FROM CategoryRows
WHERE Category IN ('Treatment naive first','Treatment naive','New to database',
                    'Insulin naive','Add on','Win','Repeat')
  AND Specialty = 'TOTAL'
GROUP BY Country,Date,Region,Metric,Type,Regimen,Focus_Brand

UNION ALL

-- Switch away specialty = SUM of Lose+Drop off specialty rows
SELECT
    Country, Date, Region, Metric, Type,
    'Switch away','Switch away','Switch away',
    Regimen, Focus_Brand, Before, Present,
    NULL,NULL,NULL,NULL,NULL,NULL,
    Specialty, 'Pat', SUM(LRx_Panel)
FROM CategoryRows
WHERE Category IN ('Lose','Drop off')
  AND Specialty <> 'TOTAL'
GROUP BY Country,Date,Region,Metric,Type,Regimen,Focus_Brand,Before,Present,Specialty

UNION ALL

-- Switch away TOTAL = SUM of Lose+Drop off TOTAL rows
SELECT
    Country, Date, Region, Metric, Type,
    'Switch away','Switch away','Switch away',
    Regimen, Focus_Brand, Before, Present,
    NULL,NULL,NULL,NULL,NULL,NULL,
    'TOTAL', 'Pat', SUM(LRx_Panel)
FROM CategoryRows
WHERE Category IN ('Lose','Drop off')
  AND Specialty = 'TOTAL'
GROUP BY Country,Date,Region,Metric,Type,Regimen,Focus_Brand,Before,Present
;

--
---- ============================================================
---- EXPORT-------Unprojected
---- ============================================================
--@export on;
--@export set filename="${OutputPath}$\${dbvis-date||||||format=[yyyy-MM-dd]}$ 04_SOB_HQ_Diabetes.xlsx"
--    TimeStampFormat="yyyy-MM-dd" Format="XLS" AppendFile="clear" ExcelFileFormat="xlsx" ShowNullAs="";
--@set resultset name HQ_Diabetes;
--
--SELECT Country, Date, Region, Metric, Type,Category_short, Category_long, Category,Regimen, Focus_Brand, Before, Present,Before_Basal, Present_Basal, Before_Bolus, Present_Bolus,Before_MNIAD, Present_MNIAD, Specialty, Count, LRx_Panel
--FROM SOB_HQ_Diabetes
--ORDER BY Date, Regimen, Focus_Brand, Category, Specialty;
--
--@export off;

--------------------------------------------------------------------QC Check---------------------------------------------------------
--
---- CHECK 1: BrandCombo_HQ_Diab
---- Each patient should appear exactly ONCE per month in BrandCombo.
--
--SELECT
--    COUNT(*)                                                        AS TotalRows,
--    COUNT(DISTINCT MasterPatientID || '|' || CAST(Month AS VARCHAR)) AS UniquePatientMonths,
--    MAX(RowsPerPatientMonth)                                        AS MaxRowsPerPatientMonth
--FROM (
--    SELECT Month, MasterPatientID, COUNT(*) AS RowsPerPatientMonth
--    FROM BrandCombo_HQ_Diab
--    GROUP BY 1,2
--) x;
--
--
---- ============================================================
---- CHECK 2: ClassDom_HQ_Diab
---- Each patient should appear once per drug class per month.
---- TotalRows / UniquePatientMonths = avg classes per patient.
---- If max > number of drug classes something is wrong.
---- ============================================================
---- CHECK 2: ClassDom_HQ_Diab
--SELECT
--    COUNT(*)                                                        AS TotalRows,
--    COUNT(DISTINCT MasterPatientID || '|' || CAST(Month AS VARCHAR)) AS UniquePatientMonths,
--    COUNT(DISTINCT MasterPatientID || '|' || CAST(Month AS VARCHAR)
--          || '|' || DrugClass)                                      AS UniquePatientMonthClass,
--    MAX(RowsPerPatientMonth)                                        AS MaxRowsPerPatientMonth
--FROM (
--    SELECT Month, MasterPatientID, DrugClass,
--        COUNT(*) OVER (
--            PARTITION BY Month, MasterPatientID
--        )                                                           AS RowsPerPatientMonth
--    FROM ClassDom_HQ_Diab
--) x;
--
---- ============================================================
---- CHECK 2b: WHERE DID BYDUREON/BYETTA/SEGLUROMET/STEGLATRO GO?
---- [NEW v0.94] Run this for 202605 to see exactly which step
---- drops these four brands: if they show up in Fact_HQ_Diab but
---- not ClassDom_HQ_Diab, it's the Step 6 dominant-brand contest
---- (see the top-of-file note) and not a classification bug.
---- ============================================================
--SELECT 'Fact_HQ_Diab'    AS StepName, BrandName, COUNT(DISTINCT MasterPatientID) AS Pats
--FROM Fact_HQ_Diab
--WHERE BrandName IN ('BYDUREON','BYETTA','SEGLUROMET','STEGLATRO')
--  AND TO_CHAR(DispenseCalendarDate,'YYYYMM') = '202605'
--GROUP BY 1,2
--UNION ALL
--SELECT 'AdjMonths_HQ_Diab', BrandName, COUNT(DISTINCT MasterPatientID)
--FROM AdjMonths_HQ_Diab
--WHERE BrandName IN ('BYDUREON','BYETTA','SEGLUROMET','STEGLATRO')
--  AND TO_CHAR(Month,'YYYYMM') = '202605'
--GROUP BY 1,2
--UNION ALL
--SELECT 'ClassDom_HQ_Diab', BrandName, COUNT(DISTINCT MasterPatientID)
--FROM ClassDom_HQ_Diab
--WHERE BrandName IN ('BYDUREON','BYETTA','SEGLUROMET','STEGLATRO')
--  AND TO_CHAR(Month,'YYYYMM') = '202605'
--GROUP BY 1,2
--ORDER BY 1,2;
--
---- ============================================================
---- CHECK 3: SOBClass_HQ_Diab
---- Each patient should appear once per drug class per month.
---- This is the basis for the final output.
---- Row count here – specialty buckets – TOTAL rows ? final rows.
---- ============================================================
--SELECT
--    COUNT(*)                                                        AS TotalRows,
--    COUNT(DISTINCT MasterPatientID || '|' || CAST(Month AS VARCHAR)) AS UniquePatientMonths,
--    COUNT(DISTINCT MasterPatientID || '|' || CAST(Month AS VARCHAR)
--          || '|' || DrugClass)                                      AS UniquePatientMonthClass,
--    MAX(RowsPerPatientMonth)                                        AS MaxRowsPerPatientMonth,
--    SOB_Category
--FROM (
--    SELECT Month, MasterPatientID, DrugClass, SOB_Category,
--        COUNT(*) OVER (
--            PARTITION BY Month, MasterPatientID
--        ) AS RowsPerPatientMonth
--    FROM SOBClass_HQ_Diab
--    WHERE Month >= DATE('${sDate}$')
--) x
--GROUP BY SOB_Category
--ORDER BY TotalRows DESC;
--
---- ============================================================
---- CHECK 4: SOB_HQ_Diabetes_Base
---- This is where Before/Present combo strings create row expansion.
---- Check how many unique Before+Present combinations exist
---- per category – if this is large it explains the 8.8M rows.
---- ============================================================
--SELECT
--    Category,
--    COUNT(*)                                                        AS TotalRows,
--    COUNT(DISTINCT Before || '|' || COALESCE(Present,''))          AS UniqueBeforePresent,
--    COUNT(DISTINCT MasterPatientID)                                 AS UniquePats
--FROM SOB_HQ_Diabetes_Base
--GROUP BY 1
--ORDER BY 2 DESC;
--
--
---- ============================================================
---- CHECK 5: Final row count math
---- Specialty rows + TOTAL rows per category
---- This should explain where the 8.8M comes from.
---- ============================================================
--SELECT
--    Category,
--    Specialty,
--    COUNT(*)                                                        AS Rows,
--    SUM(LRx_Panel)                                                  AS TotalPats
--FROM SOB_HQ_Diabetes
--GROUP BY 1,2
--ORDER BY 3 DESC
--LIMIT 30;
--
--
---- CHECK 6: On Drug reconciles to the sum of the 7 category rows
---- [NEW v0.94] Confirms the Step 19 fix -- these two numbers must
---- match exactly for every (Date, Regimen, Focus_Brand, Specialty).
--SELECT
--    od.Date, od.Regimen, od.Focus_Brand, od.Specialty,
--    od.LRx_Panel                                                    AS OnDrug,
--    cat.SumOfCategoryRows,
--    od.LRx_Panel - cat.SumOfCategoryRows                            AS Diff
--FROM SOB_HQ_Diabetes od
--JOIN (
--    SELECT Date, Regimen, Focus_Brand, Specialty, SUM(LRx_Panel) AS SumOfCategoryRows
--    FROM SOB_HQ_Diabetes
--    WHERE Category IN ('Treatment naive first','Treatment naive','New to database',
--                        'Insulin naive','Add on','Win','Repeat')
--    GROUP BY 1,2,3,4
--) cat
--    ON  od.Date = cat.Date AND od.Regimen = cat.Regimen
--    AND od.Focus_Brand = cat.Focus_Brand AND od.Specialty = cat.Specialty
--WHERE od.Category = 'On drug'
--ORDER BY ABS(od.LRx_Panel - cat.SumOfCategoryRows) DESC
--LIMIT 30;
--
--
---- ============================================================
---- CHECK 7: Repeat rows missing the focus brand in Before
---- [NEW v0.99] Direct, whole-dataset version of "Ozempic repeat
---- patients don't have Ozempic in Before" -- run this across every
---- brand/month/specialty to confirm the v0.96 (gap-bridged Before)
---- and v0.98 (cross-class Win) fixes actually closed it out, rather
---- than just trusting the code. Should return ZERO rows. Any row
---- here is a genuine Repeat where Before doesn't contain the focus
---- brand's own token -- send those rows back and I'll dig into that
---- specific case.
---- ============================================================
--SELECT
--    Date, Regimen, Focus_Brand, Before, Present, Specialty
--FROM SOB_HQ_Diabetes_Projected
--WHERE Category = 'Repeat'
--  AND Before IS NOT NULL
--  AND INSTR(Before, SPLIT_PART(Focus_Brand, ' ', 1)) = 0
--ORDER BY Date, Regimen, Focus_Brand
--LIMIT 200;
--
--
---- Top 20 most common Before/Present combos for Repeat
---- Should show same value in Before and Present (same brand repeated)
--SELECT
--    Before,
--    Present,
--    COUNT(DISTINCT MasterPatientID)                                 AS Patients
--FROM SOB_HQ_Diabetes_Base
--WHERE Category = 'Repeat'
--GROUP BY 1,2
--ORDER BY 3 DESC
--LIMIT 20;
--
--
---- Total unique patients per month across all combos
---- Should be relatively stable month over month
---- Large jumps between months would indicate a data issue
--SELECT
--    CAST(TO_CHAR(Month,'YYYYMM') AS INTEGER)                        AS YearMonth,
--    COUNT(DISTINCT MasterPatientID)                                 AS TotalPatients,
--    COUNT(DISTINCT CurrentCombo)                                    AS UniqueCombos,
--    COUNT(*)                                                        AS TotalRows
--FROM BrandCombo_HQ_Diab
--WHERE Month >= DATE('${sDate}$')
--GROUP BY 1
--ORDER BY 1;
--
---- RECONCILIATION 1: Exact row count by category and specialty
---- This gives the precise breakdown adding up to 8.9M
--SELECT
--    Category,
--    CASE WHEN Specialty = 'TOTAL' THEN 'TOTAL' ELSE 'Specialty' END AS RowType,
--    COUNT(*)                                                        AS Rows
--FROM SOB_HQ_Diabetes
--GROUP BY 1,2
--ORDER BY 3 DESC;
--
---- RECONCILIATION 2: Check if Before/Present nulls are being
---- grouped correctly – null Before/Present should collapse to
---- fewer rows not more
--SELECT
--    Category,
--    CASE WHEN Before IS NULL THEN 'NULL' ELSE 'Populated' END       AS BeforeStatus,
--    CASE WHEN Present IS NULL THEN 'NULL' ELSE 'Populated' END      AS PresentStatus,
--    COUNT(*)                                                        AS Rows,
--    SUM(LRx_Panel)                                                  AS TotalPats
--FROM SOB_HQ_Diabetes
--WHERE Specialty = 'TOTAL'
--GROUP BY 1,2,3
--ORDER BY 4 DESC;
--
---- RECONCILIATION 3: Month by month row count
---- Total rows per month should be stable if patient counts are stable
---- Spike in any month = potential issue
--SELECT
--    Date,
--    COUNT(*)                                                        AS Rows,
--    SUM(LRx_Panel)                                                  AS TotalPats
--FROM SOB_HQ_Diabetes
--WHERE Specialty = 'TOTAL'
--GROUP BY 1
--ORDER BY 1;
--
---- RECONCILIATION 4: The key check
---- For each category, how many rows per month per Focus_Brand
---- This tells you if the Before/Present expansion is reasonable
--SELECT
--    Category,
--    COUNT(DISTINCT Date)                                            AS Months,
--    COUNT(DISTINCT Focus_Brand)                                     AS UniqueBrands,
--    COUNT(DISTINCT Before || '|' || COALESCE(Present,''))          AS UniqueBeforePresent,
--    COUNT(*)                                                        AS TotalRows,
--    -- Expected rows if each brand gets ~8 specialty rows per month
--    COUNT(DISTINCT Date) * COUNT(DISTINCT Focus_Brand) * 8         AS SimpleEstimate,
--    -- Actual vs simple estimate ratio – if >> 1 then Before/Present is expanding rows
--    CAST(COUNT(*) AS FLOAT) /
--        NULLIF(COUNT(DISTINCT Date) * COUNT(DISTINCT Focus_Brand) * 8, 0) AS ExpansionFactor
--FROM SOB_HQ_Diabetes
--GROUP BY 1
--ORDER BY 4 DESC;
--
---- What would row count look like if Repeat Before/Present
---- only showed the focus brand (not full market combo)?
--SELECT
--    Category,
--    COUNT(DISTINCT
--        Date || '|' || Type || '|' || Regimen || '|' ||
--        Focus_Brand || '|' || Specialty
--    )                                                               AS RowsIfNoBefore,
--    COUNT(*)                                                        AS CurrentRows,
--    CAST(COUNT(*) AS FLOAT) /
--        COUNT(DISTINCT
--            Date || '|' || Type || '|' || Regimen || '|' ||
--            Focus_Brand || '|' || Specialty
--        )                                                           AS ReductionFactor
--FROM SOB_HQ_Diabetes
--GROUP BY 1
--ORDER BY 3 DESC;


-- ============================================================
-- STEP 20: PROJECTION FACTORS
-- Coverage stored as VARCHAR to handle the % sign
-- Only Factor column is used for LRx_Projected calculation
-- ============================================================
DROP TABLE IF EXISTS ProjectionFactors_HQ_Diab;
CREATE LOCAL TEMP TABLE ProjectionFactors_HQ_Diab
(
    effectiveMonth                                                  INTEGER,
    DIQ                                                             FLOAT,
    nUnits                                                          FLOAT,
    Coverage                                                        VARCHAR(20),
    Factor                                                          FLOAT
)
ON COMMIT PRESERVE ROWS;

COPY ProjectionFactors_HQ_Diab
FROM LOCAL 'C:\Users\u1194544\OneDrive - IQVIA\Desktop\Novo Nordisk\Cardiometabolic GLP1 Analysis\Final Codes\Final Scripts\SOB_HQ_Diabetes_Projection_Values.csv'
DELIMITER ',' SKIP 1;

-- Verify all 25 months loaded
SELECT * FROM ProjectionFactors_HQ_Diab ORDER BY effectiveMonth;

-- [NEW v0.96] "202407 (or any month) patient count all blank" is the
-- exact symptom of this LEFT JOIN not finding a Factor for that month --
-- every row for a month missing from ProjectionFactors_HQ_Diab used to
-- come out NULL. Run this first: it lists every Date present in
-- SOB_HQ_Diabetes that has NO matching row in ProjectionFactors_HQ_Diab.
-- If 202407 (sDate's month) shows up here, the projection factors CSV
-- itself needs that month added -- that's a data file fix, not a SQL fix.
SELECT DISTINCT s.Date
FROM SOB_HQ_Diabetes s
LEFT JOIN ProjectionFactors_HQ_Diab pf ON s.Date = pf.effectiveMonth
WHERE pf.effectiveMonth IS NULL
ORDER BY 1;

-- ============================================================
-- STEP 21: FINAL OUTPUT WITH PROJECTIONS
-- LRx_Projected = LRx_Panel × Factor, no decimal places
-- [Fix v0.96] NVL(pf.Factor, 1) -- a month missing from the projection
-- factors CSV no longer blanks the whole month out; it now falls back to
-- the unprojected LRx_Panel count (Factor=1, i.e. no projection applied)
-- so the row is still there and visibly usable. This does not fix a
-- missing row in the CSV itself -- use the diagnostic query above to find
-- and add it -- it just stops one missing lookup row from silently
-- nulling out an entire month's worth of counts.
-- ============================================================
DROP TABLE IF EXISTS SOB_HQ_Diabetes_Projected;
CREATE LOCAL TEMP TABLE SOB_HQ_Diabetes_Projected ON COMMIT PRESERVE ROWS AS
SELECT
    s.*,
    CAST(FLOOR(s.LRx_Panel * NVL(pf.Factor, 1)) AS INTEGER)        AS LRx_Projected
FROM SOB_HQ_Diabetes s
LEFT JOIN ProjectionFactors_HQ_Diab pf
    ON  s.Date = pf.effectiveMonth;
SELECT ANALYZE_STATISTICS('SOB_HQ_Diabetes_Projected');

-- [Fix v0.94] "capitalize all the variables" -> UPPER() applied to every
-- text output column below. "export csv file using comma separated
-- format" -> Delimiter="," made explicit instead of relying on a
-- possibly locale-dependent CSV default.
@export on;
@export set filename="${OutputPath}$\${dbvis-date||||||format=[yyyy-MM-dd]}$ 04_SOB_HQ_Diabetes_Projected.csv"
    TimeStampFormat="yyyy-MM-dd"
    Format="CSV"
    Delimiter=","
    AppendFile="clear"
    ShowNullAs="";

@set resultset name HQ_Diabetes;

SELECT
    UPPER(Country)                                                  AS Country,
    Date,
    UPPER(Region)                                                   AS Region,
    UPPER(Metric)                                                   AS Metric,
    UPPER(Type)                                                     AS Type,
    UPPER(Category_short)                                           AS Category_short,
    UPPER(Category_long)                                            AS Category_long,
    UPPER(Category)                                                 AS Category,
    UPPER(Regimen)                                                  AS Regimen,
    UPPER(Focus_Brand)                                              AS Focus_Brand,
    UPPER(Before)                                                   AS Before,
    UPPER(Present)                                                  AS Present,
    UPPER(Before_Basal)                                             AS Before_Basal,
    UPPER(Present_Basal)                                            AS Present_Basal,
    UPPER(Before_Bolus)                                             AS Before_Bolus,
    UPPER(Present_Bolus)                                            AS Present_Bolus,
    UPPER(Before_MNIAD)                                             AS Before_MNIAD,
    UPPER(Present_MNIAD)                                            AS Present_MNIAD,
    UPPER(Specialty)                                                AS Specialty,
    UPPER(Count)                                                    AS Count,
    LRx_Projected
FROM SOB_HQ_Diabetes_Projected
ORDER BY Date, Regimen, Focus_Brand, Category, Specialty;

@export off;


-- ============================================================
-- CO-MEDICATION ANALYSIS (Analysis 6_CoUse) + MONOTHERAPY (7_MonoUse)
-- Methodology per Shubham (German HQ team):
-- For each patient-month, identify the focus brand (dominant
-- brand per class) and all OTHER concurrent drugs in that month.
-- Present = all other active drugs excluding the focus brand.
-- Works at ProductStrength level for GLP-1 brands.
-- Patients filtered to On drug only (active in market):
-- Drop off, Lose, Loss, End, Off drug excluded per Yipeng.
-- Output columns match SOB format with:
--   Metric         = '6_CoUse'
--   Category_short = 'Comedication'
--   Category_long  = 'Comedication'
--   Category       = 'Comedication'
--   Before         = 'TOTAL'
--   Present        = co-medication combo (focus brand excluded)
--
-- [NEW v0.95] NN request: alongside co-medication, also report
-- Monotherapy -- on-drug patients with NO co-medication at all
-- that month (the exact complement of the co-medication filter).
-- Same on-drug scope and same source table, so it's a natural
-- companion view, not a separate analysis:
--   Metric         = '7_MonoUse'
--   Category_short = 'Monotherapy'
--   Category_long  = 'Monotherapy'
--   Category       = 'Monotherapy'
--   Before         = 'TOTAL'
--   Present        = the focus brand itself (nothing else to show)
-- Built in Steps 22b/24b below and unioned into the same export as
-- co-medication (Step 25) so both views land in the same wave/file.
-- ============================================================

-- ============================================================
-- STEP 22: CO-MEDICATION BASE
-- For each patient-month-focusbrand combination, build the
-- Present combo string of all OTHER concurrent drugs.
-- Focus brand is removed from the combo string.
-- [Fix v0.94] GLP-1 brands now use the indication-aware display
-- name from ClassDomDisplay_HQ_Diab (same as the main SOB output)
-- instead of rebuilding a bare ProductStrength name here, so
-- Ozempic/Mounjaro/Wegovy read consistently across both outputs.
-- ============================================================
DROP TABLE IF EXISTS CoMed_HQ_Diab_Base;
CREATE LOCAL TEMP TABLE CoMed_HQ_Diab_Base ON COMMIT PRESERVE ROWS AS
WITH

-- Start from ClassDomDisplay – one row per patient per drug class per month
-- This gives us all active drugs per patient per month
ActiveDrugs AS (
    SELECT
        c.Month,
        c.MasterPatientID,
        c.DrugClass,
        c.Regimen,
        c.BrandName,
        c.HCPMasterID,
        -- Indication-aware display name (was: bare ProductStrength for GLP-1)
        c.DisplayNameStrength                                       AS DisplayName
    FROM ClassDomDisplay_HQ_Diab c
    WHERE c.Month >= DATE('${sDate}$')
),

-- For each patient-month, build the co-medication combo string
-- excluding the focus brand's own DrugClass
-- Self-join: focus brand (f) – all other drugs (o)
CoMedRanked AS (
    SELECT
        f.Month,
        f.MasterPatientID,
        f.DrugClass                                                 AS FocusDrugClass,
        f.Regimen                                                   AS FocusRegimen,
        f.BrandName                                                 AS FocusBrand,
        f.DisplayName                                               AS FocusDisplayName,
        f.HCPMasterID,
        -- Rank all other drugs alphabetically for the combo string
        o.DisplayName                                               AS OtherDrug,
        ROW_NUMBER() OVER (
            PARTITION BY f.Month, f.MasterPatientID, f.DrugClass
            ORDER BY o.DisplayName ASC
        )                                                           AS OtherRank,
        COUNT(*) OVER (
            PARTITION BY f.Month, f.MasterPatientID, f.DrugClass
        )                                                           AS OtherCount
    FROM ActiveDrugs f
    -- Join to all OTHER drugs the patient is on in the same month
    JOIN ActiveDrugs o
        ON  f.Month           = o.Month
        AND f.MasterPatientID = o.MasterPatientID
        -- Exclude the focus drug class itself
        AND f.DrugClass       <> o.DrugClass
),

-- Build the Present combo string (co-medication, excluding focus brand)
CoMedCombo AS (
    SELECT DISTINCT
        Month, MasterPatientID, FocusDrugClass, FocusRegimen,
        FocusBrand, FocusDisplayName, HCPMasterID,
        -- Concatenate all other drugs alphabetically
        TRIM(
            MAX(CASE WHEN OtherRank=1 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass)
            ||CASE WHEN OtherCount>=2 THEN ' + '||MAX(CASE WHEN OtherRank=2 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass) ELSE '' END
            ||CASE WHEN OtherCount>=3 THEN ' + '||MAX(CASE WHEN OtherRank=3 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass) ELSE '' END
            ||CASE WHEN OtherCount>=4 THEN ' + '||MAX(CASE WHEN OtherRank=4 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass) ELSE '' END
            ||CASE WHEN OtherCount>=5 THEN ' + '||MAX(CASE WHEN OtherRank=5 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass) ELSE '' END
            ||CASE WHEN OtherCount>=6 THEN ' + '||MAX(CASE WHEN OtherRank=6 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass) ELSE '' END
            ||CASE WHEN OtherCount>=7 THEN ' + '||MAX(CASE WHEN OtherRank=7 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass) ELSE '' END
            ||CASE WHEN OtherCount>=8 THEN ' + '||MAX(CASE WHEN OtherRank=8 THEN OtherDrug ELSE '' END) OVER (PARTITION BY Month,MasterPatientID,FocusDrugClass) ELSE '' END
        )                                                           AS CoMedCombo
    FROM CoMedRanked
)

SELECT
    cc.Month,
    cc.MasterPatientID,
    cc.FocusDrugClass,
    cc.FocusRegimen,
    cc.FocusBrand,
    cc.FocusDisplayName,
    cc.HCPMasterID,
    -- Only include patients who have at least one co-medication
    -- Patients on a single drug have no co-medication to report
    NULLIF(cc.CoMedCombo,'')                                        AS CoMedCombo
FROM CoMedCombo cc
WHERE NULLIF(cc.CoMedCombo,'') IS NOT NULL
;
SELECT ANALYZE_STATISTICS('CoMed_HQ_Diab_Base');

-- ============================================================
-- STEP 22b: MONOTHERAPY BASE  [NEW v0.95]
-- NN request: alongside the co-medication view (patients with at
-- least one OTHER concurrent drug class), also surface a
-- monotherapy view -- patients who are on exactly ONE drug class
-- that month, i.e. the exact complement of CoMed_HQ_Diab_Base's
-- "at least one co-medication" filter. Same source
-- (ClassDomDisplay_HQ_Diab, so already indication-aware for
-- Ozempic/Mounjaro/Wegovy and already scoped to on-drug patients
-- the same way the co-medication view is), same "on drug" scope,
-- just the opposite NOT EXISTS condition.
-- ============================================================
DROP TABLE IF EXISTS MonoUse_HQ_Diab_Base;
CREATE LOCAL TEMP TABLE MonoUse_HQ_Diab_Base ON COMMIT PRESERVE ROWS AS
SELECT
    c.Month,
    c.MasterPatientID,
    c.DrugClass                                                     AS FocusDrugClass,
    c.Regimen                                                       AS FocusRegimen,
    c.BrandName                                                     AS FocusBrand,
    c.DisplayNameStrength                                           AS FocusDisplayName,
    c.HCPMasterID
FROM ClassDomDisplay_HQ_Diab c
WHERE c.Month >= DATE('${sDate}$')
  -- No other active drug class this month -- true monotherapy.
  AND NOT EXISTS (
      SELECT 1 FROM ClassDom_HQ_Diab cur
      WHERE cur.MasterPatientID = c.MasterPatientID
        AND cur.Month           = c.Month
        AND cur.DrugClass      <> c.DrugClass
  )
;
SELECT ANALYZE_STATISTICS('MonoUse_HQ_Diab_Base');

-- ============================================================
-- STEP 23: CO-MEDICATION REGIMEN COMBOS
-- Build Present_Basal, Present_Bolus, Present_MNIAD from
-- the co-medication drugs (same logic as RegimenCombo but
-- only for the other drugs, not the focus brand)
-- Reuse RegimenCombo_HQ_Diab which already has all combos
-- per patient per month – just join on patient+month
-- ============================================================

-- ============================================================
-- STEP 24: CO-MEDICATION FINAL OUTPUT
-- Format matches SOB output exactly.
-- Specialty rows + TOTAL rows.
-- Before = 'TOTAL' per Yipeng/Shubham methodology.
-- Present = co-medication combo (focus brand excluded).
-- ============================================================
DROP TABLE IF EXISTS CoMed_HQ_Diab;
CREATE LOCAL TEMP TABLE CoMed_HQ_Diab ON COMMIT PRESERVE ROWS AS

-- Specialty rows
SELECT
    'AU'                                                            AS Country,
    CAST(TO_CHAR(cb.Month,'YYYYMM') AS INTEGER)                     AS Date,
    'All'                                                           AS Region,
    '6_CoUse'                                                       AS Metric,
    -- [Fix v0.99] same GLP-1-only override as the main SOB output.
    CASE WHEN cb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END                                       AS Type,
    'Comedication'                                                  AS Category_short,
    'Comedication'                                                  AS Category_long,
    'Comedication'                                                  AS Category,
    cb.FocusRegimen                                                 AS Regimen,
    -- Focus brand uses the indication-aware display name for GLP-1
    cb.FocusDisplayName                                             AS Focus_Brand,
    -- Before = TOTAL per methodology
    'TOTAL'                                                         AS Before,
    -- Present = co-medication combo (all other concurrent drugs)
    cb.CoMedCombo                                                   AS Present,
    -- Before regimen combos always NULL for co-medication
    NULL                                                            AS Before_Basal,
    -- Present regimen combos from RegimenCombo excluding focus class
    NULLIF(rc.BasalCombo,'')                                        AS Present_Basal,
    NULL                                                            AS Before_Bolus,
    NULLIF(rc.BolusCombo,'')                                        AS Present_Bolus,
    NULL                                                            AS Before_MNIAD,
    NULLIF(rc.MNIADCombo,'')                                        AS Present_MNIAD,
    NVL(d.Specialty,'Others')                                       AS Specialty,
    'Pat'                                                           AS Count,
    COUNT(DISTINCT cb.MasterPatientID)                              AS LRx_Panel
FROM CoMed_HQ_Diab_Base cb
LEFT JOIN PatientType_HQ_Diab pt  ON cb.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc
    ON  cb.Month           = rc.Month
    AND cb.MasterPatientID = rc.MasterPatientID
LEFT JOIN Docs_HQ_Diab d ON cb.HCPMasterID = d.HCPMasterID
GROUP BY
    CAST(TO_CHAR(cb.Month,'YYYYMM') AS INTEGER),
    CASE WHEN cb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType,'UNKNOWN') ELSE 'DIABETES' END,
    cb.FocusRegimen, cb.FocusDisplayName, cb.CoMedCombo,
    NULLIF(rc.BasalCombo,''), NULLIF(rc.BolusCombo,''), NULLIF(rc.MNIADCombo,''),
    NVL(d.Specialty,'Others')

UNION ALL

-- TOTAL rows
SELECT
    'AU',
    CAST(TO_CHAR(cb.Month,'YYYYMM') AS INTEGER),
    'All', '6_CoUse',
    CASE WHEN cb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END,
    'Comedication','Comedication','Comedication',
    cb.FocusRegimen,
    cb.FocusDisplayName,
    'TOTAL',
    cb.CoMedCombo,
    NULL,
    NULLIF(rc.BasalCombo,''),
    NULL,
    NULLIF(rc.BolusCombo,''),
    NULL,
    NULLIF(rc.MNIADCombo,''),
    'TOTAL',
    'Pat',
    COUNT(DISTINCT cb.MasterPatientID)
FROM CoMed_HQ_Diab_Base cb
LEFT JOIN PatientType_HQ_Diab pt  ON cb.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc
    ON  cb.Month           = rc.Month
    AND cb.MasterPatientID = rc.MasterPatientID
GROUP BY
    CAST(TO_CHAR(cb.Month,'YYYYMM') AS INTEGER),
    CASE WHEN cb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType,'UNKNOWN') ELSE 'DIABETES' END,
    cb.FocusRegimen, cb.FocusDisplayName, cb.CoMedCombo,
    NULLIF(rc.BasalCombo,''), NULLIF(rc.BolusCombo,''), NULLIF(rc.MNIADCombo,'')
;
SELECT ANALYZE_STATISTICS('CoMed_HQ_Diab');

-- Sense check
SELECT
    Date,
    COUNT(*)                                                        AS Rows,
    SUM(LRx_Panel)                                                  AS TotalPats
FROM CoMed_HQ_Diab
WHERE Specialty = 'TOTAL'
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- STEP 24b: MONOTHERAPY FINAL OUTPUT  [NEW v0.95]
-- Same shape as CoMed_HQ_Diab (Step 24) so it can ride the same
-- export: Metric='7_MonoUse', Category='Monotherapy', Before=
-- 'TOTAL', Present = the focus brand itself (there is nothing else
-- to show -- that's what makes it monotherapy). Present_Basal/
-- Bolus/MNIAD reuse RegimenCombo_HQ_Diab exactly like CoMed does;
-- for a monotherapy patient only the bucket matching their own
-- class will be populated, the other two come back empty.
-- ============================================================
DROP TABLE IF EXISTS MonoUse_HQ_Diab;
CREATE LOCAL TEMP TABLE MonoUse_HQ_Diab ON COMMIT PRESERVE ROWS AS

-- Specialty rows
SELECT
    'AU'                                                            AS Country,
    CAST(TO_CHAR(mb.Month,'YYYYMM') AS INTEGER)                     AS Date,
    'All'                                                           AS Region,
    '7_MonoUse'                                                     AS Metric,
    -- [Fix v0.99] same GLP-1-only override as the main SOB output.
    CASE WHEN mb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END                                       AS Type,
    'Monotherapy'                                                   AS Category_short,
    'Monotherapy'                                                   AS Category_long,
    'Monotherapy'                                                   AS Category,
    mb.FocusRegimen                                                 AS Regimen,
    mb.FocusDisplayName                                             AS Focus_Brand,
    'TOTAL'                                                         AS Before,
    mb.FocusDisplayName                                             AS Present,
    NULL                                                            AS Before_Basal,
    NULLIF(rc.BasalCombo,'')                                        AS Present_Basal,
    NULL                                                            AS Before_Bolus,
    NULLIF(rc.BolusCombo,'')                                        AS Present_Bolus,
    NULL                                                            AS Before_MNIAD,
    NULLIF(rc.MNIADCombo,'')                                        AS Present_MNIAD,
    NVL(d.Specialty,'Others')                                       AS Specialty,
    'Pat'                                                           AS Count,
    COUNT(DISTINCT mb.MasterPatientID)                              AS LRx_Panel
FROM MonoUse_HQ_Diab_Base mb
LEFT JOIN PatientType_HQ_Diab pt  ON mb.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc
    ON  mb.Month           = rc.Month
    AND mb.MasterPatientID = rc.MasterPatientID
LEFT JOIN Docs_HQ_Diab d ON mb.HCPMasterID = d.HCPMasterID
GROUP BY
    CAST(TO_CHAR(mb.Month,'YYYYMM') AS INTEGER),
    CASE WHEN mb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType,'UNKNOWN') ELSE 'DIABETES' END,
    mb.FocusRegimen, mb.FocusDisplayName,
    NULLIF(rc.BasalCombo,''), NULLIF(rc.BolusCombo,''), NULLIF(rc.MNIADCombo,''),
    NVL(d.Specialty,'Others')

UNION ALL

-- TOTAL rows
SELECT
    'AU',
    CAST(TO_CHAR(mb.Month,'YYYYMM') AS INTEGER),
    'All', '7_MonoUse',
    CASE WHEN mb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType, 'UNKNOWN')
         ELSE 'DIABETES' END,
    'Monotherapy','Monotherapy','Monotherapy',
    mb.FocusRegimen,
    mb.FocusDisplayName,
    'TOTAL',
    mb.FocusDisplayName,
    NULL,
    NULLIF(rc.BasalCombo,''),
    NULL,
    NULLIF(rc.BolusCombo,''),
    NULL,
    NULLIF(rc.MNIADCombo,''),
    'TOTAL',
    'Pat',
    COUNT(DISTINCT mb.MasterPatientID)
FROM MonoUse_HQ_Diab_Base mb
LEFT JOIN PatientType_HQ_Diab pt  ON mb.MasterPatientID = pt.MasterPatientID
LEFT JOIN RegimenCombo_HQ_Diab rc
    ON  mb.Month           = rc.Month
    AND mb.MasterPatientID = rc.MasterPatientID
GROUP BY
    CAST(TO_CHAR(mb.Month,'YYYYMM') AS INTEGER),
    CASE WHEN mb.FocusRegimen = 'GLP-1' THEN NVL(pt.PatientType,'UNKNOWN') ELSE 'DIABETES' END,
    mb.FocusRegimen, mb.FocusDisplayName,
    NULLIF(rc.BasalCombo,''), NULLIF(rc.BolusCombo,''), NULLIF(rc.MNIADCombo,'')
;
SELECT ANALYZE_STATISTICS('MonoUse_HQ_Diab');

-- Sense check
SELECT
    Date,
    COUNT(*)                                                        AS Rows,
    SUM(LRx_Panel)                                                  AS TotalPats
FROM MonoUse_HQ_Diab
WHERE Specialty = 'TOTAL'
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- STEP 25: ADD PROJECTION TO CO-MEDICATION + MONOTHERAPY
-- Join ProjectionFactors on Date = effectiveMonth
-- LRx_Projected = FLOOR(LRx_Panel × Factor)
-- [Fix v0.95] Monotherapy rows unioned in here so both views ride
-- the same export file, distinguished by Metric ('6_CoUse' vs
-- '7_MonoUse') and Category ('Comedication' vs 'Monotherapy').
-- [Fix v0.96] NVL(pf.Factor, 1) -- same fallback as Step 21, see that
-- comment for why.
-- ============================================================
DROP TABLE IF EXISTS CoMed_HQ_Diab_Projected;
CREATE LOCAL TEMP TABLE CoMed_HQ_Diab_Projected ON COMMIT PRESERVE ROWS AS
SELECT
    c.*,
    CAST(FLOOR(c.LRx_Panel * NVL(pf.Factor, 1)) AS INTEGER)        AS LRx_Projected
FROM (
    SELECT * FROM CoMed_HQ_Diab
    UNION ALL
    SELECT * FROM MonoUse_HQ_Diab
) c
LEFT JOIN ProjectionFactors_HQ_Diab pf
    ON  c.Date = pf.effectiveMonth;

-- ============================================================
-- EXPORT CO-MEDICATION + MONOTHERAPY
-- [Fix v0.94] UPPER() on every text column, explicit comma delimiter.
-- [Fix v0.95] Now also carries the Monotherapy rows (see Step 25).
-- ============================================================
@export on;
@export set filename="${OutputPath}$\${dbvis-date||||||format=[yyyy-MM-dd]}$ 05_CoMedications_HQ_Diabetes.csv"
    TimeStampFormat="yyyy-MM-dd"
    Format="CSV"
    Delimiter=","
    AppendFile="clear"
    ShowNullAs="";

@set resultset name HQ_Diabetes_CoMed;

SELECT
    UPPER(Country)                                                  AS Country,
    Date,
    UPPER(Region)                                                   AS Region,
    UPPER(Metric)                                                   AS Metric,
    UPPER(Type)                                                     AS Type,
    UPPER(Category_short)                                           AS Category_short,
    UPPER(Category_long)                                            AS Category_long,
    UPPER(Category)                                                 AS Category,
    UPPER(Regimen)                                                  AS Regimen,
    UPPER(Focus_Brand)                                              AS Focus_Brand,
    UPPER(Before)                                                   AS Before,
    UPPER(Present)                                                  AS Present,
    UPPER(Before_Basal)                                             AS Before_Basal,
    UPPER(Present_Basal)                                            AS Present_Basal,
    UPPER(Before_Bolus)                                             AS Before_Bolus,
    UPPER(Present_Bolus)                                            AS Present_Bolus,
    UPPER(Before_MNIAD)                                             AS Before_MNIAD,
    UPPER(Present_MNIAD)                                            AS Present_MNIAD,
    UPPER(Specialty)                                                AS Specialty,
    UPPER(Count)                                                    AS Count,
    LRx_Panel, LRx_Projected
FROM CoMed_HQ_Diab_Projected
ORDER BY Date, Regimen, Focus_Brand, Present, Specialty;

@export off;
