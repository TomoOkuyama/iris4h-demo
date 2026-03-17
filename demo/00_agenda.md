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

### 2. デモ①：FHIR R4 データのインポート & SQL クエリ（10分）

**テーマ:** FHIRリソースを登録するだけで、SQLテーブルに自動マッピングされる

- FHIR R4 エンドポイントに Patient / Observation を POST
- Management Portal の SQL 実行画面で即座にクエリ
- JsonAdvSQL ストレージ戦略（2024.1〜）による自動テーブル生成

```
デモURL:
  FHIR API   http://localhost:11202/csp/healthshare/fhirserver/fhir/r4
  SQL実行     Management Portal > System Explorer > SQL（ネームスペース: FHIRSERVER）
```

**実行スクリプト:**
```bash
bash demo/01_load_patients.sh       # 患者3名 + Observation4件を登録
```
```sql
-- SQLクエリ例（demo/02_sql_queries.sql）
SELECT Key, BirthDate, Gender FROM HSFHIR_X0001_S.Patient
```

---

### 3. デモ②：SQL + ObjectScript 同時クエリ（10分）

**テーマ:** 同じデータに SQL / ObjectScript / FHIR API / グローバル変数の4つの方法でアクセス

- SQL: `SELECT` 文でリレーショナルアクセス
- ObjectScript: FHIR Server API でリソースをオブジェクトとして取得（`valueQuantity.value` 等）
- グローバル変数: データの物理的な実体を直接確認

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

- Web アプリで血中酸素飽和度（SpO2）を登録
- SpO2 < 90% → BPL（ビジネスプロセス）が検出
- DTL（データ変換）で HL7 v2.5 SIU_S12 メッセージに変換
- ファイル出力（`/ISC/Out/`）

```
デモURL:
  Webアプリ           http://localhost:11202/csp/fhir/portal/patientlist.html
  ビジュアルトレース   http://localhost:11202/csp/healthshare/fhirserver/EnsPortal.MessageViewer.zen
```

**実行スクリプト:**
```bash
bash demo/04_oximeter_test.sh       # SpO2=85% で HL7 出力をトリガー
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
| JsonAdvSQL | FHIRリソース → SQLテーブル自動マッピング |
| Interoperability | FHIR → BPL → DTL → HL7 のリアルタイム変換 |
| ビジュアルトレース | メッセージ処理フローの可視化 |

---

## 環境情報

| 項目 | 値 |
|------|-----|
| IRIS for Health | 2025.3 |
| FHIR エンドポイント | `http://localhost:11202/csp/healthshare/fhirserver/fhir/r4` |
| Management Portal | `http://localhost:11202/csp/sys/%25CSP.Portal.Home.zen` |
| Web アプリ | `http://localhost:11202/csp/fhir/portal/patientlist.html` |
| 認証 | `_SYSTEM` / `SYS` |

## 事前準備

```bash
docker compose up -d          # コンテナ起動
sleep 20                      # IRIS起動待ち
bash demo/01_load_patients.sh  # テストデータ登録
```
