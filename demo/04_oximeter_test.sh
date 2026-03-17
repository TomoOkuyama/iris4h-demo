#!/bin/bash
# デモ シナリオ3: パルスオキシメーターデモ（Interoperability連携）
# O2Sat < 90% のデータを送信し、HL7 SIU_S12 メッセージが自動出力されることを確認

FHIR_URL="http://localhost:11202/csp/healthshare/fhirserver/fhir/r4"
AUTH="_SYSTEM:SYS"

echo "=== パルスオキシメーターデモ ==="
echo ""
echo "【フロー】"
echo "  FHIR Bundle POST → Interop Service → BPL（O2Satチェック）"
echo "  → O2Sat < 90% → DTL（HL7変換）→ HL7 SIU_S12 ファイル出力"
echo ""

echo "--- HL7出力ディレクトリをクリア ---"
rm -f ./Out/_* 2>/dev/null
echo "  クリア完了"
echo ""

echo "--- Bundle送信: 山田太郎 + O2Sat=85%（低値） ---"
curl -s -u $AUTH -X POST "$FHIR_URL" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Bundle",
    "type": "transaction",
    "entry": [
        {
            "resource": {
                "resourceType": "Patient",
                "id": "1",
                "identifier": [{"value": "1001"}],
                "name": [
                    {"extension": [{"url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-representation", "valueCode": "IDE"}], "use": "official", "text": "山田 太郎", "family": "山田", "given": ["太郎"]},
                    {"extension": [{"url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-representation", "valueCode": "SYL"}], "use": "official", "text": "ヤマダ タロウ", "family": "ヤマダ", "given": ["タロウ"]}
                ],
                "gender": "male",
                "birthDate": "1970-01-01",
                "address": [{"postalCode": "1600023", "text": "東京都新宿区西新宿6丁目"}]
            },
            "request": {"method": "PUT", "url": "Patient/1"}
        },
        {
            "resource": {
                "resourceType": "Observation",
                "meta": {"profile": ["http://hl7.org/fhir/StructureDefinition/vitalsigns"]},
                "status": "final",
                "category": [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "vital-signs", "display": "Vital Signs"}]}],
                "code": {"coding": [{"system": "http://loinc.org", "code": "2708-6", "display": "Oxygen saturation in Arterial blood"}, {"system": "http://loinc.org", "code": "59408-5", "display": "Oxygen saturation in Arterial blood by Pulse oximetry"}]},
                "subject": {"reference": "Patient/1"},
                "effectiveDateTime": "2026-03-17T16:00:00+09:00",
                "valueQuantity": {"value": 85, "unit": "%", "system": "http://unitsofmeasure.org", "code": "%"}
            },
            "request": {"method": "POST", "url": "Observation"}
        }
    ]
  }' -w "\n  → HTTP %{http_code}\n"

echo ""
echo "--- 2秒待機（HL7メッセージ生成を待つ）---"
sleep 2

echo ""
echo "--- HL7出力ファイル確認 ---"
HL7_FILE=$(ls -t ./Out/_* 2>/dev/null | head -1)
if [ -n "$HL7_FILE" ]; then
    echo "  HL7ファイルが出力されました: $HL7_FILE"
    echo ""
    echo "--- HL7 SIU_S12 メッセージ内容 ---"
    cat "$HL7_FILE" | tr '\r' '\n'
    echo ""
    echo ""
    echo "【確認ポイント】"
    echo "  - MSH: SIU^S12（スケジューリングメッセージ）"
    echo "  - SCH: 「飽和酸素度が低い数値です : 85」"
    echo "  - PID: 患者ID 1001（山田太郎）"
else
    echo "  HL7ファイルが出力されませんでした（エラーの可能性）"
fi

echo ""
echo "【次のステップ】"
echo "  Management Portal でビジュアルトレースを確認:"
echo "  http://localhost:11202/csp/healthshare/fhirserver/EnsPortal.MessageViewer.zen"
