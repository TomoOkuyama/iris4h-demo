# IRIS for Health FHIR R4 デモ環境

InterSystems IRIS for Health 2025.3 を使った FHIR R4 デモ環境です。
Docker Compose で起動するだけで、FHIR リポジトリ・電子カルテ UI・Interoperability プロダクションが一式動作します。

元テンプレート: [Intersystems-jp/IRIS-FHIR-Oximeter-Template](https://github.com/Intersystems-jp/IRIS-FHIR-Oximeter-Template)

---

## 構成

| コンテナ | ホスト名 | ポート | 説明 |
|---------|---------|--------|------|
| iris4h | iris | 11201:1972 (SuperServer) | IRIS for Health 2025.3 |
| webgw4h | webgw | 11202:80, 11203:443 | Web Gateway 2025.3 |

## クイックスタート

### 1. 事前準備

- Docker Desktop がインストールされていること
- `dockerfiles/iris/iris.key` に IRIS ライセンスキーファイルを配置

### 2. ビルド・起動

```bash
docker compose up -d --build
```

### 3. デモデータ投入

```bash
# IRIS 起動完了まで約20秒待ってから実行
bash demo/01_load_patients.sh
```

患者20名・Observation（SpO2/体温/血圧/検査結果）・Condition（病名）・AllergyIntolerance（アレルギー）が登録されます。

### 4. アクセス

| 画面 | URL |
|------|-----|
| 電子カルテ UI | http://localhost:11202/csp/emr/index.html |
| FHIR R4 エンドポイント | http://localhost:11202/csp/healthshare/fhirserver/fhir/r4 |
| Management Portal | http://localhost:11202/csp/sys/%25CSP.Portal.Home.zen |

認証情報: `_SYSTEM` / `SYS`

---

## デモシナリオ

### シナリオ1: FHIR R4 データのインポート & SQL クエリ

FHIRリソースを POST するだけで、SQL テーブルに自動マッピングされることを実演します。

```bash
# デモデータ投入（患者20名 + 各種臨床データ）
bash demo/01_load_patients.sh
```

Management Portal > System Explorer > SQL（ネームスペース: FHIRSERVER）で SQL を実行:

```sql
-- 患者一覧
SELECT Key, BirthDate, Gender FROM HSFHIR_X0001_S.Patient

-- SpO2 < 90% の患者を抽出
SELECT o.subject_Reference, vq.value_ValueLowRaw AS "SpO2(%)"
FROM HSFHIR_X0001_S_Observation.valueQuantity vq
JOIN HSFHIR_X0001_S.Observation o ON o.Key = vq.Key
JOIN HSFHIR_X0001_S_Observation.code oc ON oc.Key = o.Key
WHERE oc.value_Value = '2708-6' AND CAST(vq.value_ValueLowRaw AS NUMERIC) < 90
```

実務的な SQL クエリ集（22本・8業務シチュエーション対応）: `demo/05_practical_sql_queries.sql`

### シナリオ2: SQL + ObjectScript 同時クエリ

同じデータに FHIR API / SQL / ObjectScript / グローバル変数の 4 つの方法でアクセスできることを示します。

```bash
docker exec -it iris4h iris session IRIS -U FHIRSERVER
```

実行例は `demo/03_objectscript_queries.txt` を参照。

### シナリオ3: パルスオキシメーターデモ（Interoperability 連携）

SpO2 < 90% のデータが送信されると、Interoperability プロダクションが自動で HL7 v2.5 SIU_S12 メッセージを生成・ファイル出力します。

```bash
bash demo/04_oximeter_test.sh
```

**処理フロー:**
```
FHIR Bundle POST
  → HS.FHIRServer.Interop.Service
    → Solution.FHIRBPL（SpO2 < 90% を判定）
      → Solution.FromFhirObsToSIUS12（DTL: HL7変換）
        → EnsLib.HL7.Operation.FileOperation（./Out/ にHL7ファイル出力）
```

Management Portal のビジュアルトレースでフローを確認:
`http://localhost:11202/csp/healthshare/fhirserver/EnsPortal.MessageViewer.zen`

---

## ファイル構成

```
iris4h-demo/
├── docker-compose.yml           # Docker Compose 定義
├── readme.md                    # このファイル
│
├── dockerfiles/
│   ├── iris/
│   │   ├── dockerfile           # IRIS for Health イメージ定義
│   │   ├── iris.script          # IRIS 初期化スクリプト
│   │   ├── Setup.cls            # FHIRサーバー・プロダクションのセットアップクラス
│   │   └── iris.key             # ライセンスキー（※git管理外）
│   └── webgw/
│       ├── dockerfile           # Web Gateway イメージ定義
│       └── opt/iris/
│           ├── CSP.conf         # Apache CSP モジュール設定
│           └── CSP.ini          # Web Gateway 接続設定
│
├── src/
│   ├── emr/
│   │   └── index.html           # 電子カルテ UI（FHIR fetch API ベース）
│   └── Solution/
│       ├── FHIRBPL.cls          # ビジネスプロセス（BPL: SpO2チェック）
│       ├── FoundationProduction.cls  # プロダクション定義
│       └── FromFhirObsToSIUS12.cls   # データ変換（DTL: FHIR→HL7 SIU_S12）
│
├── demo/
│   ├── 00_agenda.md             # デモ Agenda（勉強会用）
│   ├── 01_load_patients.sh      # デモデータ投入（患者20名+臨床データ）
│   ├── 02_sql_queries.sql       # 基本 SQL クエリ集
│   ├── 03_objectscript_queries.txt  # ObjectScript クエリ集
│   ├── 04_oximeter_test.sh      # パルスオキシメーター デモスクリプト
│   └── 05_practical_sql_queries.sql # 実務 SQL クエリ集（22本）
│
├── SampleResource/              # サンプル FHIR リソース（JSON）
│   ├── test_Patient.json
│   └── test_Bundle_Patient_Observation.json
│
└── Out/                         # HL7 メッセージ出力先（実行時に生成）
    └── .gitkeep
```

## 各ファイルの詳細

### dockerfiles/iris/Setup.cls

Docker イメージビルド時に `iris.script` から呼び出される初期化クラス。以下を自動実行します:

1. **FHIRSERVER ネームスペース作成** — `HS.Util.Installer.Foundation.Install()` で Interoperability 対応ネームスペースを作成
2. **ObjectScript ソースのインポート** — `src/Solution/` 配下の BPL・DTL・プロダクション定義をコンパイル
3. **FHIR R4 サーバーのインストール** — `JsonAdvSQL` ストレージ戦略（SQL テーブル自動生成）でFHIRエンドポイントを構築
4. **Interop 連携の設定** — FHIR リクエストが `HS.FHIRServer.Interop.Service` を経由するよう設定
5. **CSP アプリケーション登録** — 電子カルテ UI 用の `/csp/emr` を登録
6. **プロダクション開始** — `Solution.FoundationProduction` を自動開始に設定

### src/Solution/FHIRBPL.cls

Interoperability のビジネスプロセス（BPL）。FHIR リクエストを受け取り、以下の処理を行います:

- FHIR CRUD を `HS.FHIRServer.Interop.Operation` に委譲
- POST リクエストの Bundle から Observation の `valueQuantity.value`（SpO2）を抽出
- SpO2 < 90% の場合、DTL 変換を呼び出して HL7 メッセージを生成

### src/Solution/FromFhirObsToSIUS12.cls

データ変換（DTL）。BPL のコンテキスト（SpO2値・患者名・患者ID）から HL7 v2.5 SIU_S12（スケジューリング）メッセージを組み立てます。

### src/emr/index.html

FHIR R4 API を直接呼び出す電子カルテ風 UI（単体 HTML、外部依存は CDN のみ）。

**機能:**
- 患者一覧（20名、検索フィルタ付き）
- 患者選択 → サマリ表示（病名・アレルギー・バイタル・検査結果）
- 異常値のハイライト（SpO2 < 90%, 体温 >= 38.0℃, HbA1c >= 7.0% 等）
- アラートバッジ表示（SpO2低下、発熱、高血圧、アレルギー注意）
- SpO2 入力 → Bundle POST（Interop 連携で HL7 出力をトリガー可能）
- FHIR JSON 生データ表示

### demo/01_load_patients.sh

デモ用データ投入スクリプト。臨床的に整合性のあるダミーデータを生成します:

| リソース | 件数 | 内容 |
|---------|------|------|
| Patient | 20名 | 全国各地の日本人（20代〜80代、男女各10名） |
| Observation (SpO2) | 19件 | 正常値(97%)〜重症(78%)まで |
| Observation (体温) | 19件 | 平熱(36.3℃)〜高熱(39.1℃)まで |
| Observation (血圧) | 13件 | 正常(118/75)〜重症高血圧(170/110) |
| Observation (検査) | 20件 | 血糖値・HbA1c・ヘモグロビン・クレアチニン |
| Condition | 23件 | 糖尿病・高血圧・CKD・心不全・COPD・喘息・肺炎・睡眠時無呼吸 |
| AllergyIntolerance | 10件 | 薬剤（ペニシリン等）・食物（そば等）・環境（花粉等） |

### demo/05_practical_sql_queries.sql

8つの業務シチュエーションに対応した SQL クエリ集（22本）:

| # | シチュエーション | 例 |
|---|-----------------|-----|
| 1 | 外来受付 — 患者検索 | 姓で検索、診察券番号で特定、住所で抽出 |
| 2 | 診察室 — 患者の全体像把握 | 病名一覧、アレルギー、バイタル履歴、検査結果 |
| 3 | 病棟 — 異常値アラート | SpO2 < 90% 抽出、発熱患者、SpO2低下+発熱の感染症疑い |
| 4 | 処方チェック — アレルギー確認 | ペニシリン系アレルギー、薬剤/食物アレルギー一覧 |
| 5 | 慢性疾患管理 — 糖尿病外来 | HbA1c一覧、7.0%以上の治療強化対象、糖尿病性腎症の早期発見 |
| 6 | 腎臓内科 — CKD管理 | CKDステージ一覧、Cr/Hbの相関（腎性貧血の評価） |
| 7 | 経営・レポート — 統計 | 疾患別患者数、検査実施件数、併存疾患数 |
| 8 | 多職種連携 — 横断検索 | 重症患者の病名+アレルギー横断ビュー |

---

## 技術情報

### JsonAdvSQL ストレージ戦略

IRIS for Health 2024.1 で導入された FHIR ストレージ戦略（`HS.FHIRServer.Storage.JsonAdvSQL.InteractionsStrategy`）。2024.1 以降の新規インストールではデフォルトのストレージ戦略となっている。従来の `HS.FHIRServer.Storage.Json` を置き換える位置づけ。

#### メリット

- **FHIR → SQL の自動マッピング** — FHIRリソースを POST するだけで、検索パラメータに基づいた SQL テーブルが自動生成される。追加設定不要。
- **マルチモデルアクセス** — 同じデータに FHIR REST API / SQL / ObjectScript / グローバル変数の 4 つの方法で同時アクセス可能。
- **検索性能の向上** — コンパートメント検索（ワイルドカード・`_type` 対応）、`_include` / `_revinclude`（`:iterate` 対応）、日付/数量の拡張プレフィックス（`sa`, `eb`, `ap`）をフルサポート。
- **BI/分析ツール連携** — JDBC/ODBC 経由で Tableau、Power BI 等から FHIR データを直接クエリ可能。

#### 従来の Json ストレージとの比較

| 項目 | Json（レガシー） | JsonAdvSQL（推奨） |
|------|-----------------|-------------------|
| 導入バージョン | 2024.1 より前 | **2024.1 以降（デフォルト）** |
| SQL テーブル生成 | なし | **自動生成** |
| コンパートメント検索 | 制限あり | **フルサポート**（ワイルドカード・`_type`） |
| `_include` / `_revinclude` | 制限あり | **フルサポート**（`:iterate` 対応） |
| 検索プレフィックス | 基本のみ | **`sa`, `eb`, `ap` 対応** |
| パフォーマンス | 標準 | **大幅に改善** |
| ステータス | レガシー（互換性維持） | **現行推奨** |

#### テーブル構造

```
HSFHIR_X0001_S.Patient                        ← メインテーブル（1患者=1行）
HSFHIR_X0001_S_Patient.family                 ← 姓の検索用サブテーブル
HSFHIR_X0001_S_Patient.address                ← 住所の検索用サブテーブル
HSFHIR_X0001_S_Patient.identifier             ← 識別子のサブテーブル
HSFHIR_X0001_S.Observation                    ← Observationメインテーブル
HSFHIR_X0001_S_Observation.valueQuantity      ← 測定値のサブテーブル
HSFHIR_X0001_S_Observation.code               ← LOINCコードのサブテーブル
HSFHIR_X0001_S.Condition                      ← 病名メインテーブル
HSFHIR_X0001_S_Condition.code                 ← ICD-10コードのサブテーブル
HSFHIR_X0001_S.AllergyIntolerance             ← アレルギーメインテーブル
HSFHIR_X0001_S_AllergyIntolerance.code        ← アレルゲンのサブテーブル
```

- `X0001` — FHIR サーバーインスタンスの番号（複数エンドポイント作成時に `X0002`, `X0003`... と増加）
- `S` — Search テーブル（検索パラメータベースのインデックス）
- メインテーブルには全リソース共通の検索パラメータ（`_id`, `_lastUpdated`, `subject` 等）が格納
- サブテーブルにはリソース固有の検索パラメータ（`family`, `address`, `valueQuantity` 等）が展開

### Interoperability プロダクション構成

```
HS.FHIRServer.Interop.Service（ビジネスサービス）
  → Solution.FHIRBPL（ビジネスプロセス: SpO2判定）
    → HS.FHIRServer.Interop.Operation（FHIR CRUD実行）
    → Solution.FromFhirObsToSIUS12（DTL: HL7変換）
      → To_Scheduling / EnsLib.HL7.Operation.FileOperation（HL7ファイル出力）
```

---

## 参考リンク

### InterSystems 公式ドキュメント

- [FHIR Server: An Introduction](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIR_SERVER_INTRO) — FHIR サーバーのアーキテクチャと JsonAdvSQL の概要
- [Installing a New FHIR Server](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIRINS_server_install_new) — FHIR サーバーのインストール手順
- [Customizing a FHIR Server](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIR_SERVER_CUSTOMIZE_ARCH) — FHIR サーバーのカスタマイズ
- [FHIR SQL Builder](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIR_fsb) — FHIR SQL Builder の概要

### クラスリファレンス

- [HS.FHIRServer.Storage.JsonAdvSQL.Interactions](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=HSSYS&CLASSNAME=HS.FHIRServer.Storage.JsonAdvSQL.Interactions)
- [HS.FHIRServer.Storage.JsonAdvSQL.SearchTable](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=HSLIB&CLASSNAME=HS.FHIRServer.Storage.JsonAdvSQL.SearchTable)

### リリースノート

- [New in IRIS for Health 2024.1](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXIHRN_new20241) — JsonAdvSQL の導入
- [New in IRIS for Health 2024.3](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXIHRN_new20243) — JsonAdvSQL の検索パフォーマンス改善

### その他

- [エンジニアのための IRIS for Health ガイド](docs/why-iris-for-health.md) — 「自分で作らなくていいもの」一覧
- [電子カルテ UI アーキテクチャ（スライド用）](docs/emr-architecture-slides.md) — FHIR API だけで動く電子カルテのデータフロー・技術スタック
- [IRIS for Health がサポートする医療標準規格](docs/iris-healthcare-standards.md) — HL7 v2/FHIR/CDA/DICOM/IHE 等の対応一覧
- [症例検索アーキテクチャ（Embedding + Vector Search）](docs/case-search-architecture.md) — 自然言語による類似症例検索の設計
- [FHIR R4 仕様](https://hl7.org/fhir/R4/)
- [元テンプレート: IRIS-FHIR-Oximeter-Template](https://github.com/Intersystems-jp/IRIS-FHIR-Oximeter-Template)
- [iris-fhir-portal（UI アセット元）](https://github.com/diashenrique/iris-fhir-portal)
