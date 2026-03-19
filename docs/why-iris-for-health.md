# エンジニアのための IRIS for Health ガイド — 「自分で作らなくていいもの」一覧

## このドキュメントの目的

医療システムの開発では、FHIR サーバー、データ変換、用語マッピング、監査ログ、相互運用性レイヤーなど、
ドメイン固有の「インフラ層」を大量に構築する必要がある。

IRIS for Health は、これらの多くを**プラットフォーム側で吸収**する。
このドキュメントでは「自分で作ると何が必要か」と「IRIS に任せると何が起こるか」を対比して説明する。

---

## 1. FHIR リポジトリ — 自分で作ると大変なもの

### 自分で作る場合

```
FHIR サーバーを自前実装すると必要なもの:

  □ FHIR R4 仕様の全リソースタイプ（150+種類）の JSON スキーマ理解
  □ RESTful API の実装（CRUD + Search + Transaction Bundle）
  □ 検索パラメータの実装（文字列/トークン/日付/数量/参照 × 修飾子）
  □ チェイン検索・逆チェイン検索の実装
  □ _include / _revinclude の実装
  □ ページネーション（Bundle.link の next/prev）
  □ バージョニング（ETag, If-Match, If-None-Match）
  □ Conditional CRUD（If-None-Exist, If-Match）
  □ CapabilityStatement の自動生成
  □ Content Negotiation（JSON/XML）
  □ バリデーション（プロファイル適合性チェック）
  □ ストレージの設計（RDB? ドキュメントDB? どうインデックスする?）
  □ 検索インデックスの設計・保守
```

→ HAPI FHIR を使っても、PostgreSQL の運用、Elasticsearch の運用、JVM のチューニングが必要。

### IRIS for Health の場合

```objectscript
// これだけで FHIR R4 サーバーが完成する
Do ##class(HS.FHIRServer.Installer).InstallNamespace()
Do ##class(HS.FHIRServer.Installer).InstallInstance("/fhir/r4",
    "HS.FHIRServer.Storage.JsonAdvSQL.InteractionsStrategy",
    $lb("hl7.fhir.r4.core@4.0.1"))
```

**3行で得られるもの:**
- 全150+リソースタイプ対応の FHIR R4 サーバー
- 全検索パラメータ対応（チェイン検索、`_include`/`_revinclude` 含む）
- JSON + SQL テーブルの自動生成（JsonAdvSQL）
- CapabilityStatement の自動生成
- バージョニング、Conditional CRUD 対応済み
- Bulk FHIR（インポート/エクスポート）対応

---

## 2. FHIR データの SQL アクセス — 書かなくていいコード

### 自分で作る場合（HAPI FHIR + PostgreSQL）

```
FHIR データを SQL でクエリ可能にするには:

  □ FHIR リソースの JSON をパースする ETL パイプラインの構築
  □ リソースタイプごとのテーブル設計（Patient, Observation, Condition...）
  □ ネストされた FHIR 要素のフラット化（name[0].family → family カラム）
  □ CodeableConcept の展開（coding[].system, coding[].code）
  □ 多重度の処理（1患者が複数の address を持つケース）
  □ FHIR リソース更新時の ETL 再実行
  □ テーブルスキーマと FHIR 仕様変更の同期保守
```

### IRIS for Health（FHIR SQL Builder）の場合

FHIR SQL Builder（2023.1 以降正式サポート）を使えば、Management Portal の GUI で
分析対象の FHIR リソースと要素を選択するだけで、SQL テーブル（プロジェクション）が生成される。

```
FHIR SQL Builder へのアクセス:
  Management Portal > Health > FHIR SQL Builder
```

**書かなくて済んだコード:**
- ETL パイプライン全体（設計・実装・テスト・保守）
- テーブル設計・マイグレーション
- FHIR 要素のフラット化ロジック
- データ同期のスケジューラー

---

## 3. データ変換 — HL7 v2 ↔ FHIR ↔ CDA

### 自分で作る場合

```
HL7 v2 メッセージを FHIR に変換するには:

  □ HL7 v2 パーサーの実装（セグメント/フィールド/コンポーネントの分解）
  □ MLLP プロトコルの実装（TCP ソケット、ACK/NAK 応答）
  □ v2 → FHIR のマッピング定義（ADT_A01 → Patient + Encounter + ...）
  □ コード体系の変換（HL7 テーブル → FHIR ValueSet）
  □ 日付フォーマット変換（HL7: YYYYMMDD → FHIR: YYYY-MM-DD）
  □ 文字コード変換（ISO-2022-JP → UTF-8）
  □ エラーハンドリング（不正メッセージ、マッピング失敗）
  □ 再送制御、デッドレターキュー
```

同様に CDA → FHIR、FHIR → HL7 v2 の変換もそれぞれ実装が必要。

### IRIS for Health の場合

```
HL7 v2 メッセージ
  → Production の HL7 TCP アダプタが受信（MLLP 対応済み）
    → DTL（Data Transformation Language）で変換
      → ドラッグ&ドロップの GUI でマッピング定義
        → FHIR リソースとして出力

逆方向（FHIR → HL7 v2）も同じ仕組み
```

**書かなくて済んだコード:**
- HL7 v2 パーサー（組み込み済み、v2.1〜v2.8 全バージョン対応）
- MLLP プロトコル実装（TCP アダプタとして提供）
- マッピングロジック（GUI の DTL エディタで定義、コード不要）
- SDA を中間フォーマットとして HL7 v2 ↔ FHIR ↔ CDA の相互変換を提供
- 再送制御・デッドレターキュー（Production のメッセージキューで管理）

---

## 4. メッセージルーティング・相互運用性 — 自前で地獄を見るやつ

### 自分で作る場合

```
病院内の複数システムを連携させるには:

  □ メッセージキュー基盤（Kafka? RabbitMQ? SQS?）
  □ 各システムごとのアダプタ（接続方式: TCP, HTTP, ファイル, DB...）
  □ メッセージルーティングロジック
  □ コンテンツベースルーティング（メッセージの中身で振り分け）
  □ メッセージ変換（DTL 相当の処理）
  □ エラーリトライ・デッドレター管理
  □ メッセージの監査ログ・トレーサビリティ
  □ モニタリング・アラート
  □ スケーリング（複数ワーカー、バックプレッシャー制御）
```

→ 結局 Apache Camel や MuleSoft のような ESB を導入することになるが、
   医療固有のプロトコル（MLLP, DICOM, XDS 等）のアダプタは自作が必要。

### IRIS for Health（Interoperability Production）の場合

```
Production 定義（XML で宣言的に定義）:

  HS.FHIRServer.Interop.Service（FHIR リクエスト受信）
    → Solution.FHIRBPL（ビジネスロジック）
      → HS.FHIRServer.Interop.Operation（FHIR CRUD）
      → EnsLib.HL7.Operation.FileOperation（HL7 ファイル出力）
```

パルスオキシメーターデモがまさにこの例:
- FHIR Bundle を受信
- BPL で SpO2 < 90% を判定（GUI で定義、コード不要）
- DTL で HL7 SIU_S12 に変換（GUI で定義、コード不要）
- ファイルに出力

**書かなくて済んだコード:**
- メッセージキュー基盤（Production に組み込み済み）
- アダプタ群（TCP/MLLP, HTTP, ファイル, FTP, SOAP, SQL, DICOM が提供済み）
- ルーティングロジック（BPL で GUI 定義）
- メッセージ変換（DTL で GUI 定義）
- 監査ログ・トレーサビリティ（ビジュアルトレースで自動記録）
- リトライ・エラーハンドリング（Production フレームワークで管理）

---

## 5. マルチモデルアクセス — 別々に構築しなくていい

### 自分で作る場合

```
同じ患者データに REST API + SQL + 全文検索 でアクセスしたい:

  □ FHIR サーバー（HAPI FHIR + PostgreSQL）
  □ 分析用 DB（PostgreSQL / BigQuery）← ETL で同期
  □ 全文検索（Elasticsearch）← ETL で同期
  □ ベクトル検索（Pinecone / pgvector）← ETL で同期
  □ 4つのデータストアの同期・整合性管理
  □ 4つのインフラの運用・監視・スケーリング
```

### IRIS for Health の場合

```
1つのエンジンが全てを提供:

  同じデータに対して:
    1. FHIR REST API  → curl で JSON 取得
    2. SQL             → SELECT 文でクエリ
    3. ObjectScript     → オブジェクトとして操作
    4. グローバル変数    → 低レベルアクセス
    5. ベクトル検索      → VECTOR_COSINE() （2024.1〜）
```

**書かなくて済んだコード:**
- ETL パイプライン（4本分）
- データ同期のスケジューラー・監視
- 複数データストアのトランザクション整合性管理
- 複数インフラの運用ツール・スクリプト

---

## 6. 用語サービス — 思ったより面倒なやつ

### 自分で作る場合

```
ICD-10, SNOMED CT, LOINC のコード検索・バリデーションを実装するには:

  □ 各コード体系のマスターデータ取得・インポート
  □ CodeSystem 検索 API の実装（$lookup, $validate-code）
  □ ValueSet 展開 API の実装（$expand）
  □ ConceptMap 変換 API の実装（$translate）
  □ コード体系のバージョン管理
  □ 定期的なマスターデータ更新
```

### IRIS for Health の場合

```
FHIR Terminology Service が組み込み済み:

  GET /fhir/r4/CodeSystem/$lookup?system=http://loinc.org&code=2708-6
  GET /fhir/r4/ValueSet/$expand?url=...
  GET /fhir/r4/ConceptMap/$translate?...
```

CodeSystem、ValueSet、ConceptMap を FHIR リソースとして登録するだけで利用可能。

**書かなくて済んだコード:**
- コード体系ごとのマスターデータ管理ツール
- 検索・バリデーション・変換の API 実装
- マスターデータの定期更新パイプライン

---

## 7. セキュリティ・監査 — 忘れがちだが必須なもの

### 自分で作る場合

```
医療データのセキュリティ要件:

  □ OAuth 2.0 / SMART on FHIR 認可サーバーの構築
  □ スコープベースのアクセス制御（patient/*.read 等）
  □ 監査ログ（誰が、いつ、どのデータに、何をしたか）
  □ 暗号化（保存時・通信時）
  □ 患者同意管理（Consent リソース）
```

### IRIS for Health の場合

```
  ✓ OAuth 2.0 サーバー内蔵（リソースサーバーとしても動作）
  ✓ SMART on FHIR 対応（EHR Launch フロー）
  ✓ 監査ログ自動記録（ATNA 準拠）
  ✓ 保存時暗号化・TLS 対応
  ✓ ロールベースアクセス制御
```

**書かなくて済んだコード:**
- OAuth 2.0 認可サーバーの構築・運用
- 監査ログの記録・保存・検索基盤
- 暗号化レイヤーの実装

---

## 8. DB 内での Python 実行 — データを動かさず処理する

### 自分で作る場合

```
DB のデータを Python で処理するには:

  □ DB からデータをエクスポート（SQL クエリ → CSV/JSON）
  □ アプリサーバーにデータ転送
  □ Python で処理（ML 推論、Embedding 生成、統計分析...）
  □ 結果を DB に書き戻し
  □ この一連のパイプラインの保守・エラーハンドリング
```

→ データ量が増えるほど転送コストが膨らみ、リアルタイム処理が難しくなる。

### IRIS for Health（Embedded Python）の場合

```python
# IRIS の中で Python がそのまま動く — データ移動ゼロ
import iris

# DB のデータに直接アクセスして処理
# ※ テーブル名は FHIR SQL Builder で定義したプロジェクションを使用
rs = iris.sql.exec("SELECT * FROM MyFHIRProjection.Patient")
for row in rs:
    # scikit-learn, transformers, pandas 等をそのまま使える
    # データは DB の外に出ていない
    pass
```

**Embedded Python** は IRIS のプロセス内で Python を直接実行する仕組み。
データを外部に取り出す必要がないため、大量の医療データを扱う場面で大きな差が出る。

**活用例:**
- 患者データから ML モデルでリスクスコアを算出
- 臨床テキストから Embedding を生成し、類似症例を検索
- pandas でバイタルデータを統計処理してダッシュボードに反映

**書かなくて済んだコード:**
- データ転送のパイプライン（エクスポート → 転送 → インポート）
- DB 接続・認証の管理（IRIS の中にいるので不要）
- 処理結果の書き戻しロジック

---

## 9. まとめ — 開発者が集中すべきこと

### IRIS に任せるもの（プラットフォームが吸収）

| レイヤー | 自前実装の場合 | IRIS for Health |
|---------|-------------|-----------------|
| FHIR サーバー | HAPI FHIR + RDB + 運用 | **3行で構築** |
| SQL アクセス | ETL パイプライン構築 | **FHIR SQL Builder で GUI 定義** |
| データ変換 | v2パーサー + マッピング実装 | **GUI（DTL）で定義** |
| メッセージング | Kafka/RabbitMQ + アダプタ | **Production に組み込み** |
| マルチモデル | FHIR + RDB + 検索エンジン + ETL | **1つのエンジンで5つのアクセス方法** |
| 用語サービス | マスター管理 + API 実装 | **Terminology Service 内蔵** |
| 監査・認証 | OAuth サーバー + 監査ログ | **組み込み済み** |
| DB 内 Python 実行 | データ転送 + 外部処理 | **Embedded Python でデータ移動ゼロ** |

### 開発者が集中すべきこと（ビジネスロジック）

```
✓ 臨床ワークフローの設計
✓ ユーザーインターフェース（電子カルテ UI 等）
✓ ビジネスルール（「SpO2 < 90% で通知」等の判定ロジック）
✓ データ分析・ダッシュボード
✓ 他システムとの統合仕様の調整
✓ ドメイン固有のバリデーションルール
```

**要するに:**
「FHIR サーバーの構築」「ETL の保守」「メッセージキューの運用」に時間を使わず、
**臨床的に価値のある機能の開発に集中できる**のが IRIS for Health の価値。

---

## 参考: 本デモ環境で体感できること

| 機能 | デモでの確認方法 |
|------|----------------|
| FHIR サーバー 3行構築 | `dockerfiles/iris/Setup.cls` を参照 |
| FHIR SQL Builder | Management Portal > Health > FHIR SQL Builder |
| マルチモデルアクセス | `demo/03_objectscript_queries.txt`（同じデータに4つの方法でアクセス）|
| BPL + DTL（GUI 定義のロジック） | `demo/04_oximeter_test.sh`（SpO2 → HL7 変換） |
| ビジュアルトレース | Management Portal > Interoperability > Message Viewer |
| 電子カルテ UI（FHIR API ベース） | `http://localhost:11202/csp/emr/index.html` |
| Embedded Python | `docker exec -it iris4h iris session IRIS -U FHIRSERVER` から `##class(%SYS.Python).Shell()` |
