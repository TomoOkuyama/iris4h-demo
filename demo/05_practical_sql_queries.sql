-- ============================================================
-- 実務 SQL クエリ集 — 臨床・業務シチュエーション別
-- Management Portal > System Explorer > SQL
-- ネームスペース: FHIRSERVER
-- ============================================================


-- ================================================================
-- ■ シチュエーション1: 外来受付 — 患者検索
--   来院した患者を素早く特定する。名前の一部、診察券番号、
--   住所など様々な切り口で検索できることを示す。
-- ================================================================

-- 1-1. 姓で患者を検索（「田」を含む患者）
--   想定: 受付スタッフが「田…さん」と聞き取った名前で検索。
--   漢字・カナどちらでも検索できるが、ここではカナ表記を除外。
SELECT DISTINCT f.Key AS PatientID, f.value AS "姓"
FROM HSFHIR_X0001_S_Patient.family f
WHERE f.value LIKE '%田%'
  AND f.value NOT LIKE '%ナ%' AND f.value NOT LIKE '%カ%'

-- 1-2. 診察券番号で患者を特定
--   想定: 患者が診察券を提示。番号で即座に一意に特定する。
SELECT i.Key AS PatientID, i.value_Value AS "診察券番号"
FROM HSFHIR_X0001_S_Patient.identifier i
WHERE i.value_Value = '1002'

-- 1-3. 住所で患者を検索（地域医療・訪問看護の対象抽出）
--   想定: 訪問看護ステーションが、東京都在住の担当患者を一括抽出。
--   郵便番号を除外して住所テキストのみで検索。
SELECT DISTINCT a.Key AS PatientID, a.value AS "住所"
FROM HSFHIR_X0001_S_Patient.address a
WHERE a.value LIKE '%東京都%'
  AND a.value NOT LIKE '%[0-9]%'


-- ================================================================
-- ■ シチュエーション2: 診察室 — 患者の全体像を把握
--   医師が診察前に、対象患者の病歴・アレルギー・バイタル・
--   検査結果を一覧で確認する。
-- ================================================================

-- 2-1. 特定患者の病名一覧（Patient/1 山田太郎）
--   想定: 診察開始前に、この患者が持つ全疾患を確認。
--   既往歴・現病歴の把握に使う。ICD-10コードと発症日で時系列を追える。
SELECT DISTINCT
    cc.value_Value AS "ICD-10",
    cc.value_Text AS "病名",
    od.value_StartRaw AS "発症日"
FROM HSFHIR_X0001_S_Condition.code cc
JOIN HSFHIR_X0001_S.Condition c ON c.Key = cc.Key
LEFT JOIN HSFHIR_X0001_S_Condition.onsetDate od ON od.Key = c.Key
WHERE c.subject_Reference = 'Patient/1'


-- 2-2. 特定患者のアレルギー情報
--   想定: 処方を出す前に、薬剤アレルギーがないか確認。
--   ペニシリンアレルギーがあればβラクタム系全般を避ける判断材料になる。
SELECT DISTINCT
    ac.value_Text AS "アレルゲン",
    a.criticality AS "重症度"
FROM HSFHIR_X0001_S_AllergyIntolerance.code ac
JOIN HSFHIR_X0001_S.AllergyIntolerance a ON a.Key = ac.Key
WHERE a.patient_Reference = 'Patient/1'


-- 2-3. 特定患者のバイタルサイン履歴（SpO2の推移）
--   想定: 肺炎で入院中の山田太郎のSpO2を時系列で確認。
--   97%→88%への急落を把握し、酸素投与の判断に使う。
SELECT DISTINCT
    vq.value_ValueLowRaw AS "SpO2(%)",
    o.date_StartRaw AS "測定日時"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE o.subject_Reference = 'Patient/1'
  AND oc.value_Value = '2708-6'
ORDER BY o.date_StartRaw

-- 2-4. 特定患者の全検査結果一覧
--   想定: 山田太郎の直近の採血結果を一覧で確認。
--   血糖値112→186の上昇（肺炎によるストレス性高血糖）を発見できる。
SELECT DISTINCT
    oc.value_Text AS "検査項目",
    vq.value_ValueLowRaw AS "値",
    vq.value_Unit AS "単位",
    o.date_StartRaw AS "検査日時"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE o.subject_Reference = 'Patient/1'

ORDER BY o.date_StartRaw


-- ================================================================
-- ■ シチュエーション3: 病棟 — 異常値アラート・モニタリング
--   看護師・当直医が病棟全体の患者を横断的にモニタリングし、
--   緊急対応が必要な患者を素早く特定する。
-- ================================================================

-- 3-1. SpO2 が 90% 未満の患者を緊急抽出
--   想定: 夜勤帯の看護師が、酸素化が悪化している患者を一覧で確認。
--   SpO2が低い順にソートし、最も重症な患者（渡辺大輔 78%）を最優先で対応。
SELECT DISTINCT
    o.subject_Reference AS "患者",
    vq.value_ValueLowRaw AS "SpO2(%)",
    o.date_StartRaw AS "測定日時"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE oc.value_Value = '2708-6'
  AND CAST(vq.value_ValueLowRaw AS NUMERIC) < 90
ORDER BY CAST(vq.value_ValueLowRaw AS NUMERIC) ASC

-- 3-2. 発熱患者の一覧（体温 37.5℃ 以上）
--   想定: 院内感染対策チーム（ICT）が、発熱患者を一括抽出。
--   複数患者の同時発熱があれば、院内感染アウトブレイクの早期発見に繋がる。
SELECT DISTINCT
    o.subject_Reference AS "患者",
    vq.value_ValueLowRaw AS "体温(℃)",
    o.date_StartRaw AS "測定日時"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE oc.value_Value = '8310-5'
  AND CAST(vq.value_ValueLowRaw AS NUMERIC) >= 37.5
ORDER BY CAST(vq.value_ValueLowRaw AS NUMERIC) DESC

-- 3-3. SpO2低下 かつ 発熱 を同時に起こしている患者（感染症疑い）
--   想定: 当直医が「呼吸状態悪化+発熱」の組み合わせで肺炎・敗血症を
--   疑う患者を横断検索。早期の抗菌薬投与や血液培養のトリガーとなる。
--   結果: P1(肺炎), P5(COPD増悪), P7(心不全+感染), P13(心不全+感染)
SELECT DISTINCT spo2_q.subject AS "患者"
FROM (
    SELECT o.subject_Reference AS subject
    FROM HSFHIR_X0001_S_Observation.valueQuantity vq
    JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
    JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
    WHERE oc.value_Value = '2708-6'
    
      AND CAST(vq.value_ValueLowRaw AS NUMERIC) < 90
) spo2_q
JOIN (
    SELECT o.subject_Reference AS subject
    FROM HSFHIR_X0001_S_Observation.valueQuantity vq
    JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
    JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
    WHERE oc.value_Value = '8310-5'
    
      AND CAST(vq.value_ValueLowRaw AS NUMERIC) >= 37.5
) temp_q ON spo2_q.subject = temp_q.subject


-- ================================================================
-- ■ シチュエーション4: 処方チェック — アレルギー確認
--   薬剤師・医師が処方を出す前に、患者のアレルギー情報を確認する。
--   交差反応（ペニシリン↔セフェム）も含めた安全チェック。
-- ================================================================

-- 4-1. ペニシリン系・セフェム系アレルギーの患者一覧
--   想定: 肺炎患者に抗生物質を処方する前に確認。
--   ペニシリンアレルギーの患者にはセフェム系も交差反応のリスクがあるため、
--   両方を一括検索。該当患者にはニューキノロン系等を選択する。
SELECT DISTINCT
    a.patient_Reference AS "患者",
    ac.value_Text AS "アレルゲン",
    a.criticality AS "重症度"
FROM HSFHIR_X0001_S_AllergyIntolerance.code ac
JOIN HSFHIR_X0001_S.AllergyIntolerance a ON a.Key = ac.Key
WHERE (ac.value_Text LIKE '%ペニシリン%'
   OR ac.value_Text LIKE '%セフェム%')

-- 4-2. 薬剤アレルギーのある全患者一覧
--   想定: 薬局で調剤時に注意が必要な患者のリストを作成。
--   入院時にリストバンドへのアレルギー表示を行う際の元データとしても使う。
SELECT DISTINCT
    a.patient_Reference AS "患者",
    ac.value_Text AS "アレルゲン",
    a.criticality AS "重症度"
FROM HSFHIR_X0001_S_AllergyIntolerance.code ac
JOIN HSFHIR_X0001_S.AllergyIntolerance a ON a.Key = ac.Key
JOIN HSFHIR_X0001_S_AllergyIntolerance.category cat ON cat.Key = a.Key
WHERE cat.value_Value = 'medication'


-- 4-3. 食物アレルギーのある患者一覧
--   想定: 栄養科が入院患者の食事オーダーを作成する際に確認。
--   そばアレルギー(重症度:high)の患者には、製造ラインの共用も避ける必要がある。
SELECT DISTINCT
    a.patient_Reference AS "患者",
    ac.value_Text AS "アレルゲン",
    a.criticality AS "重症度"
FROM HSFHIR_X0001_S_AllergyIntolerance.code ac
JOIN HSFHIR_X0001_S.AllergyIntolerance a ON a.Key = ac.Key
JOIN HSFHIR_X0001_S_AllergyIntolerance.category cat ON cat.Key = a.Key
WHERE cat.value_Value = 'food'



-- ================================================================
-- ■ シチュエーション5: 慢性疾患管理 — 糖尿病外来
--   糖尿病専門外来で、患者群全体のコントロール状態を把握し、
--   治療介入が必要な患者を特定する。
-- ================================================================

-- 5-1. 糖尿病患者のHbA1c一覧（コントロール状態の把握）
--   想定: 糖尿病外来の医師が、担当患者のHbA1cを一覧で確認。
--   高い順にソートし、コントロール不良の患者から優先的に治療方針を見直す。
SELECT DISTINCT
    o.subject_Reference AS "患者",
    vq.value_ValueLowRaw AS "HbA1c(%)",
    o.date_StartRaw AS "検査日"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE oc.value_Value = '4548-4'
ORDER BY CAST(vq.value_ValueLowRaw AS NUMERIC) DESC

-- 5-2. HbA1c 7.0% 以上の患者を抽出（治療強化が必要）
--   想定: 日本糖尿病学会のガイドラインでは HbA1c 7.0% 未満が合併症予防の
--   目標値。これを超える患者をリストアップし、インスリン導入や薬剤変更を検討。
SELECT DISTINCT
    o.subject_Reference AS "患者",
    vq.value_ValueLowRaw AS "HbA1c(%)",
    o.date_StartRaw AS "検査日"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE oc.value_Value = '4548-4'
  AND CAST(vq.value_ValueLowRaw AS NUMERIC) >= 7.0
ORDER BY CAST(vq.value_ValueLowRaw AS NUMERIC) DESC

-- 5-3. 糖尿病患者の腎機能チェック（糖尿病性腎症の早期発見）
--   想定: 糖尿病の三大合併症の一つ「腎症」の進行を早期発見するため、
--   糖尿病の病名(E11.9)を持つ患者のうち、クレアチニンが1.5超の患者を抽出。
--   結果: P3(Cr1.8 CKD3), P13(Cr3.1 CKD5) → 腎症が進行している患者。
SELECT DISTINCT
    o.subject_Reference AS "患者",
    vq.value_ValueLowRaw AS "Cr(mg/dL)",
    o.date_StartRaw AS "検査日"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE oc.value_Value = '2160-0'
  AND CAST(vq.value_ValueLowRaw AS NUMERIC) > 1.5
  AND o.subject_Reference IN (
      SELECT c.subject_Reference
      FROM HSFHIR_X0001_S.Condition c
      JOIN HSFHIR_X0001_S_Condition.code cc ON cc.Key = c.Key
      WHERE cc.value_Value = 'E11.9'
      
  )
ORDER BY CAST(vq.value_ValueLowRaw AS NUMERIC) DESC


-- ================================================================
-- ■ シチュエーション6: 腎臓内科 — CKD患者管理
--   腎臓内科医が CKD（慢性腎臓病）患者のステージと
--   関連検査値を横断的に把握する。
-- ================================================================

-- 6-1. 慢性腎臓病の患者とステージ一覧
--   想定: 腎臓内科の外来で、CKD患者を ICD-10（N18.x）で一括抽出。
--   ステージ3→4→5の進行状況を確認し、透析導入のタイミングを検討する。
SELECT DISTINCT
    c.subject_Reference AS "患者",
    cc.value_Text AS "病名",
    cc.value_Value AS "ICD-10",
    od.value_StartRaw AS "診断日"
FROM HSFHIR_X0001_S_Condition.code cc
JOIN HSFHIR_X0001_S.Condition c ON c.Key = cc.Key
LEFT JOIN HSFHIR_X0001_S_Condition.onsetDate od ON od.Key = c.Key
WHERE cc.value_Value LIKE 'N18%'
ORDER BY cc.value_Value

-- 6-2. CKD患者のクレアチニン値と貧血（Hb）の相関
--   想定: CKDの進行に伴い腎性貧血が出現する。Cr上昇とHb低下の相関を確認し、
--   ESA（エリスロポエチン製剤）の投与開始を判断する。
--   結果: P7(Cr2.3/Hb9.8), P13(Cr3.1/Hb8.5) → CKD進行に伴う貧血を確認。
SELECT DISTINCT
    o.subject_Reference AS "患者",
    oc.value_Text AS "検査項目",
    vq.value_ValueLowRaw AS "値",
    vq.value_Unit AS "単位"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE o.subject_Reference IN (
    SELECT c.subject_Reference
    FROM HSFHIR_X0001_S.Condition c
    JOIN HSFHIR_X0001_S_Condition.code cc ON cc.Key = c.Key
    WHERE cc.value_Value LIKE 'N18%'
    
)
AND oc.value_Value IN ('2160-0', '718-7')
ORDER BY o.subject_Reference, oc.value_Text


-- ================================================================
-- ■ シチュエーション7: 経営・レポート — 統計分析
--   病院経営層・医事課・地域連携室が、患者統計や
--   疾患構成を分析する。DPC請求や施設基準の確認にも活用。
-- ================================================================

-- 7-1. 疾患別の患者数（ICD-10コード別）
--   想定: 医事課がDPC対象疾患の患者数を集計。
--   高血圧(7名)・糖尿病(6名)が上位 → 生活習慣病クリニカルパスの整備を検討。
SELECT DISTINCT
    cc.value_Value AS "ICD-10",
    cc.value_Text AS "病名",
    COUNT(DISTINCT c.subject_Reference) AS "患者数"
FROM HSFHIR_X0001_S_Condition.code cc
JOIN HSFHIR_X0001_S.Condition c ON c.Key = cc.Key
GROUP BY cc.value_Value, cc.value_Text
ORDER BY COUNT(DISTINCT c.subject_Reference) DESC

-- 7-2. 検査種別ごとの実施件数
--   想定: 臨床検査部が月次の検査実施件数を集計。
--   LOINCコード別に件数を把握し、試薬の発注計画や人員配置の参考にする。
SELECT DISTINCT
    oc.value_Text AS "検査項目",
    oc.value_Value AS "LOINCコード",
    COUNT(*) AS "実施件数"
FROM HSFHIR_X0001_S_Observation.code oc
GROUP BY oc.value_Text, oc.value_Value
ORDER BY COUNT(*) DESC

-- 7-3. 患者あたりの併存疾患数（多疾患併存の把握）
--   想定: 地域包括ケア病棟の看護師長が、多疾患併存（マルチモビディティ）の
--   患者を把握。疾患数が多い患者ほどケアの複雑性が高く、退院調整に時間を要する。
--   結果: P7, P13が3疾患 → 退院前カンファレンスの優先対象。
SELECT DISTINCT
    c.subject_Reference AS "患者",
    COUNT(DISTINCT cc.value_Value) AS "疾患数"
FROM HSFHIR_X0001_S.Condition c
JOIN HSFHIR_X0001_S_Condition.code cc ON cc.Key = c.Key
GROUP BY c.subject_Reference
HAVING COUNT(DISTINCT cc.value_Value) >= 2
ORDER BY COUNT(DISTINCT cc.value_Value) DESC

-- 7-4. アレルギーカテゴリ別の件数
--   想定: 医療安全管理室が院内のアレルギー登録状況を把握。
--   薬剤アレルギーの登録率が低ければ、入院時のアレルギー聴取を強化する。
SELECT DISTINCT
    cat.value_Value AS "カテゴリ",
    COUNT(*) AS "件数"
FROM HSFHIR_X0001_S_AllergyIntolerance.category cat
GROUP BY cat.value_Value


-- ================================================================
-- ■ シチュエーション8: 多職種連携 — 患者サマリの横断検索
--   多職種カンファレンスで、重症患者の全体像を1つのクエリで
--   横断的に把握する。医師・看護師・薬剤師・栄養士が
--   同じデータを見ながら治療方針を議論する場面を想定。
-- ================================================================

-- 8-1. 重症患者の横断ビュー（SpO2<90 + 病名 + アレルギー）
--   想定: 毎朝の多職種カンファレンスで、SpO2低下中の重症患者について
--   病名とアレルギーを一画面で確認。
--   例: 渡辺大輔(SpO2:78%) → 心不全+CKD4+高血圧、アレルギーなし
--       → 利尿薬増量と酸素投与を検討。
--   例: 山田太郎(SpO2:88%) → 糖尿病+高血圧+肺炎、ペニシリンアレルギー
--       → ペニシリン以外の抗生物質を選択する必要あり。
SELECT DISTINCT
    o.subject_Reference AS "患者",
    vq.value_ValueLowRaw AS "SpO2(%)",
    cc.value_Text AS "病名",
    ac.value_Text AS "アレルギー"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
LEFT JOIN HSFHIR_X0001_S.Condition c ON c.subject_Reference = o.subject_Reference
LEFT JOIN HSFHIR_X0001_S_Condition.code cc ON cc.Key = c.KeyLEFT JOIN HSFHIR_X0001_S.AllergyIntolerance a ON a.patient_Reference = o.subject_Reference
LEFT JOIN HSFHIR_X0001_S_AllergyIntolerance.code ac ON ac.Key = a.KeyWHERE oc.value_Value = '2708-6'

  AND CAST(vq.value_ValueLowRaw AS NUMERIC) < 90
ORDER BY CAST(vq.value_ValueLowRaw AS NUMERIC) ASC


-- ============================================================
-- ポイント:
-- ・FHIRリソースをPOSTするだけで、これらの業務SQLが即座に使える
-- ・BI/分析ツール（Tableau, Power BI等）からJDBC/ODBC接続も可能
-- ・FHIR REST API と SQL を用途に応じて使い分けられる
-- ============================================================
