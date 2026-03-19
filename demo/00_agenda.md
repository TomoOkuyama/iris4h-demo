# InterSystems IRIS for Health ハンズオンデモ

**対象:** エンジニア向け
**環境:** IRIS for Health 2025.3 / Docker Compose

---

## Agenda

### 1. IRIS for Health 概要（5分）

- InterSystems IRIS for Health とは
- マルチモデルデータプラットフォーム — FHIR / SQL / オブジェクト / グローバルを1つのエンジンで処理
- 今日のデモ環境の構成（IRIS for Health + Web Gateway / Docker Compose）

---

### 2. デモ①：FHIR R4 データのインポート & SQL 分析（10分）

**テーマ:** FHIRリソースを登録し、SQL で分析可能な状態にする

- FHIR R4 エンドポイントに Patient / Observation / Condition / AllergyIntolerance を POST
- JsonAdvSQL ストレージ戦略（2024.1〜）による FHIR REST API の検索性能向上
- FHIR SQL Builder でプロジェクションを定義 → SQL / BI ツールからアクセス可能

```
デモURL:
  FHIR API          http://localhost:11202/csp/healthshare/fhirserver/fhir/r4
  FHIR SQL Builder  http://localhost:11202/csp/fhirsql/index.html
```

**実行スクリプト:**
```bash
bash demo/01_load_patients.sh       # 患者20名 + 各種臨床データを登録
```

---

### 3. デモ②：SQL + ObjectScript 同時クエリ（10分）

**テーマ:** 同じデータに SQL / ObjectScript / FHIR API / グローバル変数の4つの方法でアクセス

- SQL: `SELECT` 文でリレーショナルアクセス
- ObjectScript: FHIR Server API でリソースをオブジェクトとして取得（`valueQuantity.value` 等）
- グローバル変数: データの物理的な実体を直接確認（`%Dictionary.CompiledStorage` でグローバル名を動的取得）

```
IRISターミナル接続:
  docker exec -it iris4h iris session IRIS -U FHIRSERVER
```

**実行スクリプト:** `demo/03_objectscript_queries.txt`

**ポイント:**
> 「1回の FHIR POST で、4つのアクセス方法が同時に使える」
> → アプリケーション要件に応じて最適なアクセス方法を選択可能

---

### 4. デモ③：パルスオキシメーター連携 — Interoperability プロダクション（10分）

**テーマ:** FHIRデータをリアルタイムに処理し、条件に応じて HL7 メッセージを自動生成

- 電子カルテ UI または curl で血中酸素飽和度（SpO2）を登録
- SpO2 < 90% → BPL（ビジネスプロセス）が検出
- DTL（データ変換）で HL7 v2.5 SIU_S12 メッセージに変換
- ファイル出力（`./Out/`）
- Management Portal のビジュアルトレースで処理フローを可視化

```
デモURL:
  電子カルテ UI       http://localhost:11202/csp/emr/index.html
  ビジュアルトレース   http://localhost:11202/csp/healthshare/fhirserver/EnsPortal.MessageViewer.zen
```

**実行スクリプト:**
```bash
bash demo/04_oximeter_test.sh       # SpO2=85% で HL7 出力をトリガー
bash demo/view_hl7.sh               # 出力された HL7 メッセージを UTF-8 で表示
```

**処理フロー:**
```
FHIR Bundle POST
  → HS.FHIRServer.Interop.Service（ビジネスサービス）
    → Solution.FHIRBPL（ビジネスプロセス：SpO2 < 90% を判定）
      → Solution.FromFhirObsToSIUS12（DTL：HL7変換）
        → EnsLib.HL7.Operation.FileOperation（HL7ファイル出力）
```

**ポイント:**
> 「FHIR → Interoperability → HL7 の変換がノーコード（BPL/DTL）で実現」
> → Management Portal のビジュアルトレースで処理の流れを可視化

---

### 5. まとめ & Q&A（5分）

| 機能 | デモで見せたこと |
|------|-----------------|
| FHIR R4 リポジトリ | REST API でリソースのCRUD |
| マルチモデルアクセス | FHIR / SQL / ObjectScript / グローバル |
| JsonAdvSQL | FHIR REST API の検索性能・標準準拠性の向上 |
| SQL 分析 | FHIR SQL Builder でプロジェクション定義 → BI 連携 |
| Interoperability | FHIR → BPL → DTL → HL7 のリアルタイム変換 |
| ビジュアルトレース | メッセージ処理フローの可視化 |
| 電子カルテ UI | FHIR API ベースのWebアプリ（異常値ハイライト・アラートバッジ・オフライン対応） |

---

## 環境情報

| 項目 | 値 |
|------|-----|
| IRIS for Health | 2025.3 |
| FHIR エンドポイント | `http://localhost:11202/csp/healthshare/fhirserver/fhir/r4` |
| Management Portal | `http://localhost:11202/csp/sys/%25CSP.Portal.Home.zen` |
| 電子カルテ UI | `http://localhost:11202/csp/emr/index.html` |
| 認証 | `_SYSTEM` / `SYS` |

## 事前準備

```bash
docker compose up -d --build     # コンテナビルド・起動
sleep 20                         # IRIS起動待ち
bash demo/01_load_patients.sh    # デモデータ登録（患者20名+臨床データ）
```

## デモデータの内容

| リソース | 件数 | 内容 |
|---------|------|------|
| Patient | 20名 | 全国各地の日本人（20代〜80代、男女各10名） |
| Observation (SpO2) | 19件 | 正常(97%)〜重症(78%) |
| Observation (体温) | 19件 | 平熱(36.3℃)〜高熱(39.1℃) |
| Observation (血圧) | 13件 | 正常(118/75)〜重症高血圧(170/110) |
| Observation (検査) | 20件 | 血糖値・HbA1c・ヘモグロビン・クレアチニン |
| Condition | 23件 | 糖尿病・高血圧・CKD・心不全・COPD・喘息・肺炎・睡眠時無呼吸 |
| AllergyIntolerance | 10件 | 薬剤（ペニシリン等）・食物（そば等）・環境（花粉等） |
