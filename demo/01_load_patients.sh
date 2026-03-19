#!/bin/bash
# デモ用: FHIR R4 データのインポート
# 患者20名 + 各種Observation/Condition/AllergyIntolerance を登録

FHIR_URL="http://localhost:11202/csp/healthshare/fhirserver/fhir/r4"
AUTH="_SYSTEM:SYS"
CT="Content-Type: application/fhir+json"

post() {
  local label="$1"
  local data="$2"
  echo -n "  $label ... "
  local code=$(curl -s -u $AUTH -X POST "$FHIR_URL" -H "$CT" -d "$data" -w "%{http_code}" -o /dev/null)
  echo "$code"
}

post_resource() {
  local label="$1"
  local type="$2"
  local data="$3"
  echo -n "  $label ... "
  local code=$(curl -s -u $AUTH -X POST "$FHIR_URL/$type" -H "$CT" -d "$data" -w "%{http_code}" -o /dev/null)
  echo "$code"
}

echo "============================================================"
echo " FHIR R4 デモデータ インポート"
echo " 患者20名 + Observation / Condition / AllergyIntolerance"
echo "============================================================"
echo ""

# ============================================================
# 患者登録（20名）
# ============================================================
echo "=== 患者登録（20名）==="

PATIENTS=(
  '1001|山田|太郎|ヤマダ|タロウ|male|1970-01-01|1600023|東京都新宿区西新宿6丁目|03-1234-5678'
  '1002|佐藤|花子|サトウ|ハナコ|female|1985-05-15|1500001|東京都渋谷区神宮前1丁目|03-9876-5432'
  '1003|田中|一郎|タナカ|イチロウ|male|1960-12-20|1060032|東京都港区六本木3丁目|03-5555-1234'
  '1004|鈴木|美咲|スズキ|ミサキ|female|1992-08-10|2200011|神奈川県横浜市西区高島2丁目|045-111-2222'
  '1005|高橋|健太|タカハシ|ケンタ|male|1978-03-25|5300001|大阪府大阪市北区梅田1丁目|06-3333-4444'
  '1006|伊藤|由美|イトウ|ユミ|female|1988-11-03|4600008|愛知県名古屋市中区栄3丁目|052-555-6666'
  '1007|渡辺|大輔|ワタナベ|ダイスケ|male|1955-07-14|8100001|福岡県福岡市中央区天神1丁目|092-777-8888'
  '1008|中村|さくら|ナカムラ|サクラ|female|1995-02-28|6000008|京都府京都市下京区四条通|075-999-0000'
  '1009|小林|翔太|コバヤシ|ショウタ|male|1982-06-18|3300846|埼玉県さいたま市大宮区大門町|048-111-3333'
  '1010|加藤|恵|カトウ|メグミ|female|1973-09-22|9800021|宮城県仙台市青葉区中央1丁目|022-444-5555'
  '1011|吉田|拓也|ヨシダ|タクヤ|male|1968-04-05|7300011|広島県広島市中区基町6丁目|082-222-3333'
  '1012|山口|真理|ヤマグチ|マリ|female|1990-12-15|3500056|山口県下関市大和町1丁目|083-666-7777'
  '1013|松本|隆|マツモト|タカシ|male|1945-01-30|0600061|北海道札幌市中央区南一条西|011-888-9999'
  '1014|井上|あかり|イノウエ|アカリ|female|2000-07-07|9000015|沖縄県那覇市久茂地3丁目|098-111-2222'
  '1015|木村|誠|キムラ|マコト|male|1958-10-12|7600023|香川県高松市寿町1丁目|087-333-4444'
  '1016|林|千尋|ハヤシ|チヒロ|female|1997-03-20|9500087|新潟県新潟市中央区東大通1丁目|025-555-6666'
  '1017|斎藤|勇気|サイトウ|ユウキ|male|1975-08-08|3100015|茨城県水戸市宮町1丁目|029-777-8888'
  '1018|前田|愛|マエダ|アイ|female|1983-05-25|6300008|奈良県奈良市二条大路南1丁目|0742-99-0000'
  '1019|藤田|龍一|フジタ|リュウイチ|male|1962-11-11|7700016|徳島県徳島市助任橋2丁目|088-111-2222'
  '1020|岡田|優子|オカダ|ユウコ|female|2005-09-01|3900871|長野県松本市桐1丁目|0263-33-4444'
)

for i in "${!PATIENTS[@]}"; do
  IFS='|' read -r id family given kfamily kgiven gender birth zip addr tel <<< "${PATIENTS[$i]}"
  pnum=$((i+1))
  post_resource "Patient $pnum: $family $given" "Patient" "{
    \"resourceType\": \"Patient\",
    \"identifier\": [{\"value\": \"$id\"}],
    \"name\": [
      {\"extension\": [{\"url\": \"http://hl7.org/fhir/StructureDefinition/iso21090-EN-representation\", \"valueCode\": \"IDE\"}], \"use\": \"official\", \"text\": \"$family $given\", \"family\": \"$family\", \"given\": [\"$given\"]},
      {\"extension\": [{\"url\": \"http://hl7.org/fhir/StructureDefinition/iso21090-EN-representation\", \"valueCode\": \"SYL\"}], \"use\": \"official\", \"text\": \"$kfamily $kgiven\", \"family\": \"$kfamily\", \"given\": [\"$kgiven\"]}
    ],
    \"gender\": \"$gender\",
    \"birthDate\": \"$birth\",
    \"address\": [{\"postalCode\": \"$zip\", \"text\": \"$addr\"}],
    \"telecom\": [{\"system\": \"phone\", \"value\": \"$tel\"}]
  }"
done

echo ""

# ============================================================
# Observation: SpO2（血中酸素飽和度）
# ============================================================
echo "=== Observation: SpO2（血中酸素飽和度）==="

# 臨床整合性:
#   P1(糖尿病+高血圧+肺炎): 肺炎合併で SpO2低下
#   P3(糖尿病+高血圧+CKD3): CKDで軽度低下のみ
#   P5(糖尿病+COPD): COPD増悪で SpO2低下
#   P7(心不全+CKD4+高血圧): 心不全増悪で SpO2急落
#   P9(喘息): 喘息発作で SpO2低下
#   P13(心不全+CKD5+糖尿病): 重症心不全で SpO2低下
#   P17(喘息): 喘息で軽度低下
SPO2_DATA=(
  "1|97|2026-03-15T09:00:00+09:00"
  "1|88|2026-03-16T14:30:00+09:00"
  "2|98|2026-03-15T10:00:00+09:00"
  "3|94|2026-03-15T11:00:00+09:00"
  "4|98|2026-03-15T09:30:00+09:00"
  "5|93|2026-03-15T09:00:00+09:00"
  "5|88|2026-03-16T15:00:00+09:00"
  "7|91|2026-03-15T13:00:00+09:00"
  "7|78|2026-03-16T03:00:00+09:00"
  "9|97|2026-03-15T09:00:00+09:00"
  "9|89|2026-03-16T22:00:00+09:00"
  "10|97|2026-03-15T08:00:00+09:00"
  "13|89|2026-03-15T10:30:00+09:00"
  "13|82|2026-03-16T22:00:00+09:00"
  "15|96|2026-03-15T14:00:00+09:00"
  "17|95|2026-03-15T09:00:00+09:00"
  "17|91|2026-03-16T16:00:00+09:00"
  "19|96|2026-03-16T10:00:00+09:00"
  "19|87|2026-03-17T03:00:00+09:00"
)

for entry in "${SPO2_DATA[@]}"; do
  IFS='|' read -r pid val dt <<< "$entry"
  post_resource "Patient/$pid SpO2=$val%" "Observation" "{
    \"resourceType\": \"Observation\",
    \"meta\": {\"profile\": [\"http://hl7.org/fhir/StructureDefinition/vitalsigns\"]},
    \"status\": \"final\",
    \"category\": [{\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/observation-category\", \"code\": \"vital-signs\", \"display\": \"Vital Signs\"}]}],
    \"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"2708-6\", \"display\": \"Oxygen saturation in Arterial blood\"}, {\"system\": \"http://loinc.org\", \"code\": \"59408-5\", \"display\": \"Oxygen saturation in Arterial blood by Pulse oximetry\"}], \"text\": \"動脈血酸素飽和度 (SpO2)\"},
    \"subject\": {\"reference\": \"Patient/$pid\"},
    \"effectiveDateTime\": \"$dt\",
    \"valueQuantity\": {\"value\": $val, \"unit\": \"%\", \"system\": \"http://unitsofmeasure.org\", \"code\": \"%\"}
  }"
done

echo ""

# ============================================================
# Observation: 体温
# ============================================================
echo "=== Observation: 体温 ==="

# 臨床整合性:
#   P1: 肺炎合併 → 発熱(38.2)
#   P5: COPD増悪 → 高熱(39.1)
#   P7: 心不全+感染 → 発熱(38.5)
#   P9: 喘息発作 → 微熱(37.4) ← 喘息発作自体では高熱にならない
#   P13: 心不全+感染 → 発熱(38.8)
#   P17: 喘息 → 微熱(37.1)
TEMP_DATA=(
  "1|36.5|2026-03-15T09:00:00+09:00"
  "1|38.2|2026-03-16T14:30:00+09:00"
  "2|36.8|2026-03-15T10:00:00+09:00"
  "3|36.9|2026-03-15T11:00:00+09:00"
  "5|37.0|2026-03-15T09:00:00+09:00"
  "5|39.1|2026-03-16T15:00:00+09:00"
  "7|37.2|2026-03-15T13:00:00+09:00"
  "7|38.5|2026-03-16T03:00:00+09:00"
  "8|36.4|2026-03-15T09:30:00+09:00"
  "9|36.5|2026-03-15T09:00:00+09:00"
  "9|37.4|2026-03-16T22:00:00+09:00"
  "10|36.7|2026-03-15T08:00:00+09:00"
  "13|37.5|2026-03-15T10:30:00+09:00"
  "13|38.8|2026-03-16T22:00:00+09:00"
  "14|36.3|2026-03-15T10:00:00+09:00"
  "16|36.6|2026-03-15T09:00:00+09:00"
  "17|36.4|2026-03-15T09:00:00+09:00"
  "17|37.1|2026-03-16T16:00:00+09:00"
  "20|36.6|2026-03-15T11:00:00+09:00"
)

for entry in "${TEMP_DATA[@]}"; do
  IFS='|' read -r pid val dt <<< "$entry"
  post_resource "Patient/$pid 体温=${val}℃" "Observation" "{
    \"resourceType\": \"Observation\",
    \"meta\": {\"profile\": [\"http://hl7.org/fhir/StructureDefinition/vitalsigns\"]},
    \"status\": \"final\",
    \"category\": [{\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/observation-category\", \"code\": \"vital-signs\", \"display\": \"Vital Signs\"}]}],
    \"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"8310-5\", \"display\": \"Body temperature\"}], \"text\": \"体温\"},
    \"subject\": {\"reference\": \"Patient/$pid\"},
    \"effectiveDateTime\": \"$dt\",
    \"valueQuantity\": {\"value\": $val, \"unit\": \"Cel\", \"system\": \"http://unitsofmeasure.org\", \"code\": \"Cel\"}
  }"
done

echo ""

# ============================================================
# Observation: 血圧（収縮期/拡張期）
# ============================================================
echo "=== Observation: 血圧 ==="

BP_DATA=(
  "1|120|80|2026-03-15T09:00:00+09:00"
  "1|145|95|2026-03-16T14:30:00+09:00"
  "3|155|100|2026-03-15T11:00:00+09:00"
  "5|138|88|2026-03-16T15:00:00+09:00"
  "6|118|75|2026-03-15T10:00:00+09:00"
  "7|162|105|2026-03-16T03:00:00+09:00"
  "9|125|82|2026-03-15T09:00:00+09:00"
  "10|130|85|2026-03-15T08:00:00+09:00"
  "11|142|92|2026-03-15T14:00:00+09:00"
  "13|170|110|2026-03-16T22:00:00+09:00"
  "15|135|87|2026-03-15T14:00:00+09:00"
  "17|128|80|2026-03-15T09:00:00+09:00"
  "19|148|96|2026-03-16T16:00:00+09:00"
)

for entry in "${BP_DATA[@]}"; do
  IFS='|' read -r pid sys dia dt <<< "$entry"
  post_resource "Patient/$pid BP=${sys}/${dia}" "Observation" "{
    \"resourceType\": \"Observation\",
    \"meta\": {\"profile\": [\"http://hl7.org/fhir/StructureDefinition/vitalsigns\"]},
    \"status\": \"final\",
    \"category\": [{\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/observation-category\", \"code\": \"vital-signs\", \"display\": \"Vital Signs\"}]}],
    \"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"85354-9\", \"display\": \"Blood pressure panel\"}], \"text\": \"血圧\"},
    \"subject\": {\"reference\": \"Patient/$pid\"},
    \"effectiveDateTime\": \"$dt\",
    \"component\": [
      {\"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"8480-6\", \"display\": \"Systolic blood pressure\"}], \"text\": \"収縮期血圧\"}, \"valueQuantity\": {\"value\": $sys, \"unit\": \"mmHg\", \"system\": \"http://unitsofmeasure.org\", \"code\": \"mm[Hg]\"}},
      {\"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"8462-4\", \"display\": \"Diastolic blood pressure\"}], \"text\": \"拡張期血圧\"}, \"valueQuantity\": {\"value\": $dia, \"unit\": \"mmHg\", \"system\": \"http://unitsofmeasure.org\", \"code\": \"mm[Hg]\"}}
    ]
  }"
done

echo ""

# ============================================================
# Observation: 検査結果（Laboratory）
# ============================================================
echo "=== Observation: 検査結果 ==="

LAB_DATA=(
  "1|2345-7|Glucose|血糖|112|mg/dL|2026-03-15T09:00:00+09:00"
  "1|2345-7|Glucose|血糖|186|mg/dL|2026-03-16T14:30:00+09:00"
  "2|2345-7|Glucose|血糖|95|mg/dL|2026-03-15T10:00:00+09:00"
  "3|2345-7|Glucose|血糖|210|mg/dL|2026-03-15T11:00:00+09:00"
  "5|2345-7|Glucose|血糖|145|mg/dL|2026-03-16T15:00:00+09:00"
  "1|718-7|Hemoglobin|ヘモグロビン|13.5|g/dL|2026-03-15T09:00:00+09:00"
  "2|718-7|Hemoglobin|ヘモグロビン|12.8|g/dL|2026-03-15T10:00:00+09:00"
  "3|718-7|Hemoglobin|ヘモグロビン|10.2|g/dL|2026-03-15T11:00:00+09:00"
  "7|718-7|Hemoglobin|ヘモグロビン|9.8|g/dL|2026-03-16T03:00:00+09:00"
  "13|718-7|Hemoglobin|ヘモグロビン|8.5|g/dL|2026-03-16T22:00:00+09:00"
  "1|2160-0|Creatinine|クレアチニン|0.9|mg/dL|2026-03-15T09:00:00+09:00"
  "3|2160-0|Creatinine|クレアチニン|1.8|mg/dL|2026-03-15T11:00:00+09:00"
  "7|2160-0|Creatinine|クレアチニン|2.3|mg/dL|2026-03-16T03:00:00+09:00"
  "13|2160-0|Creatinine|クレアチニン|3.1|mg/dL|2026-03-16T22:00:00+09:00"
  "15|2160-0|Creatinine|クレアチニン|1.1|mg/dL|2026-03-15T14:00:00+09:00"
  "4|4548-4|HbA1c|HbA1c|5.6|%|2026-03-15T09:30:00+09:00"
  "5|4548-4|HbA1c|HbA1c|8.2|%|2026-03-16T15:00:00+09:00"
  "3|4548-4|HbA1c|HbA1c|9.5|%|2026-03-15T11:00:00+09:00"
  "11|4548-4|HbA1c|HbA1c|7.1|%|2026-03-15T14:00:00+09:00"
  "19|4548-4|HbA1c|HbA1c|6.8|%|2026-03-16T16:00:00+09:00"
)

for entry in "${LAB_DATA[@]}"; do
  IFS='|' read -r pid code display textja val unit dt <<< "$entry"
  post_resource "Patient/$pid $textja=$val$unit" "Observation" "{
    \"resourceType\": \"Observation\",
    \"status\": \"final\",
    \"category\": [{\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/observation-category\", \"code\": \"laboratory\", \"display\": \"Laboratory\"}]}],
    \"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"$code\", \"display\": \"$display\"}], \"text\": \"$textja\"},
    \"subject\": {\"reference\": \"Patient/$pid\"},
    \"effectiveDateTime\": \"$dt\",
    \"valueQuantity\": {\"value\": $val, \"unit\": \"$unit\", \"system\": \"http://unitsofmeasure.org\", \"code\": \"$unit\"}
  }"
done

echo ""

# ============================================================
# Condition: 病名・症状
# ============================================================
echo "=== Condition: 病名・症状 ==="

# 臨床整合性:
#   P1: 糖尿病+高血圧 → 肺炎合併でSpO2低下・発熱
#   P3: 糖尿病+高血圧+CKD3 → Cr1.8, HbA1c9.5（コントロール不良）
#   P5: 糖尿病+COPD → COPD増悪で高熱+SpO2低下
#   P7: 心不全+CKD4+高血圧 → 心不全増悪でSpO2急落、Cr高値、貧血
#   P9: 喘息 → 喘息発作でSpO2低下
#   P13: 心不全+CKD5+糖尿病 → 重症、Cr3.1、Hb8.5、SpO2低下
#   P17: 喘息 → 軽度のSpO2低下
#   P19: 糖尿病+高血圧+睡眠時無呼吸 → 夜間SpO2低下の説明
CONDITION_DATA=(
  "1|E11.9|2型糖尿病|2020-06-15"
  "1|I10|高血圧症|2018-03-20"
  "1|J18.9|肺炎|2026-03-16"
  "3|E11.9|2型糖尿病|2015-01-10"
  "3|I10|高血圧症|2015-01-10"
  "3|N18.3|慢性腎臓病 ステージ3|2019-08-05"
  "5|E11.9|2型糖尿病|2022-04-01"
  "5|J44.1|慢性閉塞性肺疾患（COPD）|2021-11-20"
  "7|I50.9|心不全|2023-02-14"
  "7|N18.4|慢性腎臓病 ステージ4|2022-07-30"
  "7|I10|高血圧症|2010-05-01"
  "9|J45.20|気管支喘息|2019-09-12"
  "10|I10|高血圧症|2020-01-15"
  "11|E11.9|2型糖尿病|2021-06-01"
  "11|I10|高血圧症|2019-03-10"
  "13|I50.9|心不全|2020-10-05"
  "13|N18.5|慢性腎臓病 ステージ5|2021-12-01"
  "13|E11.9|2型糖尿病|2010-04-15"
  "15|I10|高血圧症|2022-08-20"
  "17|J45.20|気管支喘息|2018-05-10"
  "19|E11.9|2型糖尿病|2023-01-08"
  "19|I10|高血圧症|2020-06-15"
  "19|G47.30|睡眠時無呼吸症候群|2024-02-10"
)

for entry in "${CONDITION_DATA[@]}"; do
  IFS='|' read -r pid code display onset <<< "$entry"
  post_resource "Patient/$pid $display" "Condition" "{
    \"resourceType\": \"Condition\",
    \"clinicalStatus\": {\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/condition-clinical\", \"code\": \"active\"}]},
    \"verificationStatus\": {\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/condition-ver-status\", \"code\": \"confirmed\"}]},
    \"category\": [{\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/condition-category\", \"code\": \"encounter-diagnosis\", \"display\": \"Encounter Diagnosis\"}]}],
    \"code\": {\"coding\": [{\"system\": \"http://hl7.org/fhir/sid/icd-10\", \"code\": \"$code\", \"display\": \"$display\"}], \"text\": \"$display\"},
    \"subject\": {\"reference\": \"Patient/$pid\"},
    \"onsetDateTime\": \"$onset\"
  }"
done

echo ""

# ============================================================
# AllergyIntolerance: アレルギー情報
# ============================================================
echo "=== AllergyIntolerance: アレルギー ==="

ALLERGY_DATA=(
  '1|allergy|medication|high|ペニシリン|764146007'
  '2|allergy|food|low|卵|91930004'
  '4|allergy|medication|high|セフェム系抗生物質|373270004'
  '6|allergy|food|high|そば|412071004'
  '8|allergy|food|low|牛乳|3718001'
  '9|allergy|medication|unable-to-assess|アスピリン|387458008'
  '12|allergy|food|high|ピーナッツ|762952008'
  '14|allergy|environment|low|ハウスダスト|264395009'
  '16|allergy|environment|low|花粉|418689008'
  '20|allergy|food|high|甲殻類|227037002'
)

for entry in "${ALLERGY_DATA[@]}"; do
  IFS='|' read -r pid type category crit display sctcode <<< "$entry"
  post_resource "Patient/$pid アレルギー:$display" "AllergyIntolerance" "{
    \"resourceType\": \"AllergyIntolerance\",
    \"clinicalStatus\": {\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical\", \"code\": \"active\"}]},
    \"verificationStatus\": {\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/allergyintolerance-verification\", \"code\": \"confirmed\"}]},
    \"type\": \"$type\",
    \"category\": [\"$category\"],
    \"criticality\": \"$crit\",
    \"code\": {\"coding\": [{\"system\": \"http://snomed.info/sct\", \"code\": \"$sctcode\", \"display\": \"$display\"}], \"text\": \"$display\"},
    \"patient\": {\"reference\": \"Patient/$pid\"}
  }"
done

echo ""
echo "============================================================"
echo " データ登録完了"
echo "  患者:           20名"
echo "  SpO2:           ${#SPO2_DATA[@]}件"
echo "  体温:           ${#TEMP_DATA[@]}件"
echo "  血圧:           ${#BP_DATA[@]}件"
echo "  検査結果:       ${#LAB_DATA[@]}件"
echo "  病名(Condition):${#CONDITION_DATA[@]}件"
echo "  アレルギー:     ${#ALLERGY_DATA[@]}件"
echo "============================================================"
