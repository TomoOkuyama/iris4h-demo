-- ============================================================
-- デモ シナリオ1: FHIR R4 データの SQL クエリ
-- Management Portal > System Explorer > SQL で実行
-- ネームスペース: FHIRSERVER を選択すること
-- ============================================================

-- 1. 患者一覧（FHIRリソースがSQLテーブルに自動マッピング）
SELECT Key, BirthDate, Gender
FROM HSFHIR_X0001_S.Patient

-- 2. Observation一覧（検索パラメータがSQLカラムにマッピング）
SELECT Key, subject_Reference, date_StartRaw, status_Value
FROM HSFHIR_X0001_S.Observation

-- 3. 患者とObservationのJOIN
SELECT
    p.Key AS PatientID,
    o.Key AS ObservationID,
    o.subject_Reference,
    o.date_StartRaw AS MeasuredAt
FROM HSFHIR_X0001_S.Patient p
JOIN HSFHIR_X0001_S.Observation o
    ON o.subject_Reference = p.Key

-- 4. FHIRリソースのJSON本体もSQLから参照可能
-- （Rsrcテーブルにリソース全体が格納されている）
SELECT Key, VersionId
FROM HSFHIR_X0001_S.Rsrc
WHERE Key LIKE 'Observation%'

-- ============================================================
-- ポイント:
-- FHIRリソースを POST するだけで、自動的に
-- SQLテーブルにマッピングされ、即座にクエリ可能
-- ============================================================
