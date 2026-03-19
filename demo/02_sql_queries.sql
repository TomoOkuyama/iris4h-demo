-- ============================================================
-- デモ シナリオ1: FHIR R4 データの SQL クエリ（基本編）
-- Management Portal > System Explorer > SQL で実行
-- ネームスペース: FHIRSERVER を選択すること
--
-- ※実務的なクエリ集は 05_practical_sql_queries.sql を参照
-- ============================================================

-- 1. 患者一覧（メインテーブル）
--   FHIRリソースがSQLテーブルに自動マッピングされている
SELECT Key, BirthDate, Gender
FROM HSFHIR_X0001_S.Patient

-- 2. 患者の姓を検索（サブテーブル）
--   FHIR検索パラメータ "family" が専用サブテーブルに展開される
SELECT Key, value AS "姓"
FROM HSFHIR_X0001_S_Patient.family

-- 3. 患者の住所を検索（サブテーブル）
--   postalCode と text が別の行に展開される
SELECT Key, value AS "住所情報"
FROM HSFHIR_X0001_S_Patient.address

-- 4. Observation の SpO2 値（valueQuantity サブテーブル）
--   測定値はサブテーブルに格納される
SELECT DISTINCT
    vq.Key AS "Observation ID",
    o.subject_Reference AS "患者",
    vq.value_ValueLowRaw AS "SpO2(%)",
    vq.value_Unit AS "単位",
    o.date_StartRaw AS "測定日時"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE oc.value_Value = '2708-6'

-- 5. 病名一覧（Condition + code サブテーブル）
--   DISTINCT で coding 行と text 行の重複を防止
SELECT DISTINCT
    c.subject_Reference AS "患者",
    cc.value_Value AS "ICD-10",
    cc.value_Text AS "病名"
FROM HSFHIR_X0001_S_Condition.code cc
JOIN HSFHIR_X0001_S.Condition c ON c.Key = cc.Key

-- 6. アレルギー一覧
SELECT DISTINCT
    a.patient_Reference AS "患者",
    ac.value_Text AS "アレルゲン",
    a.criticality AS "重症度"
FROM HSFHIR_X0001_S_AllergyIntolerance.code ac
JOIN HSFHIR_X0001_S.AllergyIntolerance a ON a.Key = ac.Key

-- ============================================================
-- テーブル構造のポイント:
--
-- HSFHIR_X0001_S.Patient           ← メインテーブル（1患者=1行）
-- HSFHIR_X0001_S_Patient.family    ← 姓の検索用サブテーブル
-- HSFHIR_X0001_S_Patient.address   ← 住所の検索用サブテーブル
-- HSFHIR_X0001_S.Observation       ← Observationメインテーブル
-- HSFHIR_X0001_S_Observation.valueQuantity  ← 測定値のサブテーブル
-- HSFHIR_X0001_S_Observation.code  ← LOINCコードのサブテーブル
-- HSFHIR_X0001_S.Condition         ← 病名メインテーブル
-- HSFHIR_X0001_S_Condition.code    ← ICD-10コードのサブテーブル
--
-- X0001 = FHIRサーバーインスタンス番号、S = Search テーブル
--
-- code サブテーブルの注意点:
--   FHIR の code 要素は coding（コード体系+display）と text（自由テキスト）で構成される。
--   JsonAdvSQL では両方が別の行として格納されるため、
--   SELECT DISTINCT で重複行を除去する。
-- ============================================================
