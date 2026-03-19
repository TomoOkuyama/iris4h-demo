# 症例検索アーキテクチャ — Embedding + IRIS Vector Search

## 概要

診療データや検査データから、自然言語による症状記述をもとに類似症例を検索するアーキテクチャ。
IRIS for Health の Vector Search 機能（2024.1〜）と JsonAdvSQL を組み合わせることで、
ベクトル検索と FHIR 臨床データの JOIN を同一エンジン内で完結させる。

---

## 1. 課題 — なぜベクトル検索が必要か

「頭が重くて目の奥が痛い」のような自然言語の症状記述から、類似の過去症例を検索したい。
従来の SQL キーワード検索（`WHERE code = 'R51'`）では、以下に対応できない：

- **表現の揺れ** — 「頭痛」「頭が痛い」「頭が重い」は同じ意味だが、キーワード一致しない
- **曖昧な記述** — 「なんとなくだるい」をどの ICD-10 で検索すべきか判断できない
- **複数症状の組み合わせ** — 「頭痛 + 吐き気 + 光過敏」→ 片頭痛を示唆するが、個別検索では見つからない
- **コードを知らない利用者** — 医療事務や研修医が ICD-10 コードなしで検索したい場面

**解決策:** 症状テキストを Embedding（ベクトル化）し、意味的な類似度で検索する。

---

## 2. 前提 — FHIR データはどこにあるか

本デモ環境では、FHIR R4 リソースを POST すると JsonAdvSQL ストレージ戦略により FHIR リポジトリにデータが格納される。FHIR データを SQL で分析する場合は、FHIR SQL Builder でプロジェクション（SQL ビュー）を定義する。

**しかし、FHIR SQL Builder のプロジェクションには VECTOR 型のカラムを追加できない。**
FHIR 仕様にないベクトルカラムは、標準的な FHIR のデータモデルに含まれないためである。

つまり、**FHIR データのプロジェクションだけではベクトル検索ができない**。

---

## 3. CaseRecord テーブル — ベクトル検索のための中間テーブル

### CaseRecord とは

FHIR リソース（Condition, Observation 等）から**症例検索に必要な情報だけを抜き出し**、
Embedding ベクトルと一緒に格納する**独自テーブル**。FHIR 標準のリソースではない。

```
CaseRecord（1行 = 1症例）
├── SymptomText    ← Condition.code.text 等から組み立てた症状テキスト
├── SymptomVector  ← ↑を Embedding したベクトル（検索用）
├── DiagnosisText  ← 確定診断名
├── ICD10Code      ← ICD-10コード
├── PatientRef     ← Patient/123（FHIR データへの参照キー）
├── ConditionRef   ← Condition/456（FHIR データへの参照キー）
└── Outcome        ← 転帰（軽快、入院継続 等）
```

### なぜ必要か

```
FHIR テーブル（JsonAdvSQL）          CaseRecord テーブル（独自）
┌─────────────────────┐            ┌─────────────────────────┐
│ Patient              │            │ SymptomText（テキスト）    │
│ Observation          │←─参照キー──│ SymptomVector（ベクトル）  │
│ Condition            │   で JOIN  │ PatientRef              │
│ AllergyIntolerance   │            │ ConditionRef            │
│                      │            │ ICD10Code               │
│ ※ VECTOR型カラムなし  │            │ ※ VECTOR型カラムあり      │
└─────────────────────┘            └─────────────────────────┘
```

- **FHIR データ** = 臨床データの本体（FHIR SQL Builder のプロジェクション経由で SQL アクセス）
- **CaseRecord** = ベクトル検索用のインデックス（独自テーブル、FHIR への参照キーを持つ）
- 検索時は CaseRecord でベクトル検索し、参照キーで FHIR データに JOIN して臨床詳細を取得

### テーブル定義（概念）

```sql
CREATE TABLE CaseRecord (
    CaseId        INT PRIMARY KEY,
    PatientRef    VARCHAR(64),           -- Patient/123
    ConditionRef  VARCHAR(64),           -- Condition/456
    SymptomText   VARCHAR(2000),         -- 「頭痛、嘔気、視覚異常」
    ICD10Code     VARCHAR(10),           -- G43.909
    DiagnosisText VARCHAR(500),          -- 「片頭痛」
    Outcome       VARCHAR(500),          -- 「3日で軽快」
    SymptomVector VECTOR(DOUBLE, 1536)   -- Embedding ベクトル
)
```

---

## 4. データ蓄積 — CaseRecord はどうやって作られるか

FHIR リソースが登録されたタイミングで、自動的に CaseRecord を生成する。
3つのパターンが考えられる。

### パターン A: リアルタイム（推奨構成の一部）

FHIR POST 時に Interoperability Production が自動でトリガーする。
既存のパルスオキシメーターデモ（SpO2 → HL7 変換）と同じ仕組み。

```
医師が Condition を FHIR POST
  → HS.FHIRServer.Interop.Service が受信
    → BPL: 症例登録プロセス
      ├─ Condition.code.text から症状テキストを組み立て
      ├─ Embedding API を呼び出し（非同期）
      └─ CaseRecord に INSERT（テキスト + ベクトル + FHIR参照キー）
```

**メリット:** 登録直後から検索可能
**デメリット:** Embedding API 呼び出し分のレイテンシが加算される

### パターン B: バッチ／スケジュール

IRIS Task Manager で定期的に一括生成する。

```
FHIR POST → JsonAdvSQL に格納（通常通り、CaseRecord は作らない）

夜間バッチ（例: 毎日 AM 2:00）
  → SQL で「CaseRecord に未登録の Condition」を抽出
    → まとめて Embedding API を呼び出し
      → CaseRecord に一括 INSERT
```

**メリット:** FHIR POST のレスポンスに影響しない、API 呼び出しをまとめてコスト最適化
**デメリット:** 登録から検索可能になるまでタイムラグがある（最大24時間）

### パターン C: ハイブリッド（推奨）

FHIR POST 時に非同期でキューイングし、バックグラウンドで処理。夜間バッチで漏れを補完。

```
FHIR POST
  → JsonAdvSQL に格納（自動・同期）
  → BPL が非同期メッセージとして CaseRecord 生成をキューイング
    → 別プロセスが順次処理（Embedding → INSERT）

+ 夜間バッチで漏れ・エラーリカバリ
```

**メリット:** FHIR POST のレスポンスはブロックしない。ほぼリアルタイムで検索可能。エラー時も夜間バッチで補完。
**デメリット:** 構成がやや複雑

Production の非同期メッセージング（`async='1'`）がそのまま使える。
パルスオキシメーターデモの `To_Scheduling`（非同期 HL7 出力）と同じパターン。

### 症状テキストの組み立て方

CaseRecord の `SymptomText` は、FHIR リソースの複数フィールドから組み立てる。

| ソース | FHIR パス | 例 |
|--------|----------|-----|
| 病名テキスト | `Condition.code.text` | 「片頭痛」 |
| 病名コード表示 | `Condition.code.coding[0].display` | 「Migraine」 |
| 臨床メモ | `Condition.note[0].text` | 「光過敏あり、月2回の頻度」 |
| 主訴 | `Encounter.reasonCode[0].text` | 「頭が重い、目の奥が痛い」 |
| バイタル異常 | `Observation.valueQuantity` | 「SpO2: 85%, 体温: 38.5℃」 |

**組み立て例:**
```
SymptomText = "片頭痛。頭が重い、目の奥が痛い。光過敏あり。SpO2:97% 体温:36.5℃"
```

### 既存データの初期ロード

運用開始時に、過去の FHIR データからバッチで CaseRecord を生成する。

FHIR SQL Builder で定義したプロジェクション経由で、CaseRecord に未登録の Condition を抽出し、
Python スクリプトで Embedding → INSERT する。

> **注:** 以下は概念的な SQL であり、実際のテーブル名は FHIR SQL Builder で定義したプロジェクション名に置き換える。

```sql
-- CaseRecord に未登録の Condition を抽出（概念例）
SELECT
    ConditionId,
    PatientRef,
    ICD10Code,
    DiagnosisText
FROM MyProjection.Condition
WHERE ConditionId NOT IN (SELECT ConditionRef FROM CaseRecord)
```

---

## 5. 検索フロー — 類似症例の検索

### フロー全体像

```
┌─────────────────────────────────────────────────────────┐
│                    症例検索フロー                          │
│                                                         │
│  ① 検索クエリ（自然言語）                                  │
│     「頭が重い、目の奥が痛い、吐き気」                       │
│            │                                            │
│            ▼                                            │
│  ② Embedding API（外部）                                 │
│     → 症状テキストをベクトル（1536次元等）に変換              │
│            │                                            │
│            ▼                                            │
│  ┌─────────┴──────────────────────────────────────┐      │
│  │         IRIS for Health                        │      │
│  │                                                │      │
│  │  ③ VECTOR_COSINE() で CaseRecord を類似検索      │      │
│  │            │                                    │      │
│  │            ▼                                    │      │
│  │  ④ JsonAdvSQL テーブルと JOIN                     │      │
│  │     → Patient, Observation, Condition の詳細取得  │      │
│  │                                                │      │
│  └────────────────────────────────────────────────┘      │
│            │                                            │
│            ▼                                            │
│  ⑤ 検索結果                                              │
│     類似度スコア + 症例詳細 + 臨床データ                     │
└─────────────────────────────────────────────────────────┘
```

### ① 検索クエリ

ユーザーが自然言語で症状を入力する。ICD-10 コードを知らなくてもよい。

```
入力例:
  「頭が重い、目の奥が痛い、吐き気がする」
  「2週間前から倦怠感と微熱が続く」
  「食後に胸焼けと右上腹部の鈍痛」
```

### ② Embedding 生成（外部 API）

検索クエリのテキストをベクトルに変換する。
CaseRecord 蓄積時に使用したのと**同じモデル**を使う必要がある。

#### Embedding モデルの選択肢

| モデル | 次元数 | 日本語 | 特徴 |
|--------|-------|--------|------|
| OpenAI `text-embedding-3-small` | 1536 | 対応 | 高精度、API課金 |
| OpenAI `text-embedding-3-large` | 3072 | 対応 | 最高精度、コスト高 |
| Azure OpenAI Embedding | 1536 | 対応 | エンタープライズ向け、データ残留なし |
| `intfloat/multilingual-e5-small` | 384 | 対応 | ローカル実行可、軽量、API不要 |

#### Embedding 生成の概念コード（Python）

```python
import openai
vector = openai.embeddings.create(
    model="text-embedding-3-small",
    input="頭が重い、目の奥が痛い"
).data[0].embedding  # → 1536次元の float 配列
```

### ③ ベクトル類似検索

IRIS の `VECTOR_COSINE()` 関数で CaseRecord テーブルを検索する。

```sql
SELECT TOP 10
    CaseId,
    SymptomText,
    DiagnosisText,
    ICD10Code,
    VECTOR_COSINE(SymptomVector, TO_VECTOR(:queryVector)) AS similarity
FROM CaseRecord
ORDER BY similarity DESC
```

### ④ FHIR データとの JOIN

ベクトル検索で見つかった類似症例の臨床詳細を、FHIR SQL Builder で定義したプロジェクション経由で取得する。

> **注:** 以下は概念的な SQL であり、実際のテーブル名は FHIR SQL Builder で定義したプロジェクション名に置き換える。

```sql
SELECT
    cr.SymptomText,
    cr.DiagnosisText,
    cr.similarity,
    p.BirthDate,
    p.Gender,
    obs.Value AS "検査値",
    obs.TestName AS "検査項目"
FROM (
    SELECT TOP 5
        *,
        VECTOR_COSINE(SymptomVector, TO_VECTOR(:queryVector)) AS similarity
    FROM CaseRecord
    ORDER BY similarity DESC
) cr
JOIN MyProjection.Patient p
    ON p.PatientId = cr.PatientRef
LEFT JOIN MyProjection.Observation obs
    ON obs.PatientRef = cr.PatientRef
```

**ここが IRIS の最大の強み：ベクトル類似検索と FHIR 臨床データの JOIN が1つの SQL で完結する。**
外部ベクトル DB（Pinecone 等）を使う場合、検索結果の ID で別途 FHIR サーバーにクエリする必要がある。

### ⑤ 検索結果のイメージ

```
類似度 0.94 — 「頭痛、眼痛、悪心」→ 片頭痛(G43.909)
  Patient/7 渡辺大輔 男性65歳
  検査: CT異常なし、血圧162/105
  処方: トリプタン製剤
  転帰: 3日で軽快

類似度 0.89 — 「頭重感、嘔吐、光過敏」→ 片頭痛(G43.909)
  Patient/3 田中一郎 男性65歳
  検査: MRI異常なし、血圧155/100
  処方: 予防薬（バルプロ酸）
  転帰: 発作頻度減少

類似度 0.82 — 「突然の激しい頭痛、嘔吐」→ くも膜下出血(I60.9)
  Patient/13 松本隆 男性80歳
  検査: CT出血あり、血圧170/110
  処方: 緊急手術
  転帰: 集中治療
```

---

## 6. Embedding API の呼び出し方法

CaseRecord 蓄積時・検索時の両方で Embedding API を呼び出す必要がある。

| 方法 | 説明 | 適用場面 |
|------|------|---------|
| **IRIS Embedded Python** | IRIS プロセス内で直接 Python を実行 | シンプル・低レイテンシ |
| **Python Gateway** | 外部 Python プロセスを Production から呼び出し | プロセス分離・スケーラビリティ |
| **HTTP アダプタ** | Production から REST API（OpenAI等）を直接呼び出し | 外部 API 利用時 |
| **バッチ処理** | IRIS Task Manager で定期実行 | 大量データ初期ロード・夜間補完 |

---

## 7. 他のアーキテクチャとの比較

| アーキテクチャ | ベクトル検索 | FHIR データ | JOIN | 運用複雑度 |
|--------------|------------|-----------|------|-----------|
| **IRIS 単体（本提案）** | VECTOR型 | JsonAdvSQL | **同一エンジン内** | 低 |
| IRIS + Pinecone | Pinecone | IRIS | ネットワーク越し | 中 |
| IRIS + pgvector | PostgreSQL | IRIS | ネットワーク越し | 中 |
| 外部 FHIR Server + Pinecone | Pinecone | 外部 FHIR | アプリ層で結合 | 高 |

### IRIS で実行する優位性

1. **マルチモデル** — FHIR + SQL + ベクトル が1つのエンジン内で処理される
2. **トランザクション一貫性** — FHIR データとベクトルが同じトランザクション内で更新される
3. **運用の単純さ** — 追加のベクトル DB サーバーが不要
4. **Interoperability 連携** — FHIR POST → Embedding → 格納を Production で自動化できる
5. **セキュリティ** — 患者データが IRIS の外に出ない（Embedding API 呼び出し時のテキストのみ外部送信）

---

## 8. 実装時の検討事項

| 項目 | 検討内容 |
|------|---------|
| **Embedding モデル選択** | 日本語精度 vs コスト vs レイテンシのバランス。医療ドメインに特化したモデルの有無 |
| **ベクトル次元数** | 1536（OpenAI標準）vs 384（軽量モデル）— ストレージ・検索速度とのトレードオフ |
| **症例テキストの構成** | Condition.code.text のみか、Observation 値や自由記述も含めるか |
| **蓄積パターン** | リアルタイム / バッチ / ハイブリッド — レイテンシ要件とコストで選択 |
| **Embedding API の配置** | Embedded Python / Python Gateway / HTTP / 外部マイクロサービス |
| **既存データの移行** | 過去の Condition/Observation からバッチでベクトル化する初期ロード |
| **プライバシー** | Embedding API に送信するテキストの匿名化・最小化。Azure OpenAI ならデータ残留なし |
| **精度評価** | 類似度閾値の調整、検索結果の臨床的妥当性の評価方法 |
| **モデル変更時の再ベクトル化** | Embedding モデルを変更した場合、全 CaseRecord の再生成が必要 |

---

## 9. IRIS Vector Search の技術情報

- **導入バージョン**: IRIS 2024.1 以降
- **データ型**: `VECTOR(DOUBLE, N)` — N は次元数
- **類似度関数**: `VECTOR_COSINE()` — コサイン類似度
- **インデックス**: ベクトルカラムに対するインデックスをサポート
- **SQL統合**: 通常の SQL クエリ内で `VECTOR_COSINE()` を `ORDER BY` に使用可能

### 参考リンク

- [IRIS Vector Search 概要](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_vecsearch)
- [VECTOR 型リファレンス](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_datatype#RSQL_datatype_vector)
- [Generative AI and Vector Search（Community）](https://community.intersystems.com/post/generative-ai-and-vector-search-intersystems-iris)
- [IRIS Vector Search サンプル（GitHub）](https://github.com/intersystems-community/iris-vector-search)
