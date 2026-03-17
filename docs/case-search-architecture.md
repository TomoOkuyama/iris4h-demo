# 症例検索アーキテクチャ — Embedding + IRIS Vector Search

## 概要

診療データや検査データから、自然言語による症状記述をもとに類似症例を検索するアーキテクチャ。
IRIS for Health の Vector Search 機能（2024.1〜）と JsonAdvSQL を組み合わせることで、
ベクトル検索と FHIR 臨床データの JOIN を同一エンジン内で完結させる。

---

## 課題

「頭が重くて目の奥が痛い」のような自然言語の症状記述から、類似の過去症例を検索したい。
従来の SQL キーワード検索（`WHERE code = 'R51'`）では、以下に対応できない：

- 表現の揺れ（「頭痛」「頭が痛い」「頭が重い」）
- 曖昧な記述（「なんとなくだるい」）
- 複数症状の組み合わせ（「頭痛 + 吐き気 + 光過敏」→ 片頭痛を示唆）
- ICD-10 コードを知らない利用者による検索

---

## アーキテクチャ全体像

```
┌─────────────────────────────────────────────────────────┐
│                    症例検索フロー                          │
│                                                         │
│  ① 検索クエリ（自然言語）                                  │
│     「頭が重い、目の奥が痛い、吐き気」                       │
│            │                                            │
│            ▼                                            │
│  ② Embedding API（外部）                                 │
│     OpenAI / Azure OpenAI / ローカルモデル                  │
│     → 症状テキストをベクトル（1536次元等）に変換              │
│            │                                            │
│            ▼                                            │
│  ┌─────────┴──────────────────────────────────────┐      │
│  │         IRIS for Health                        │      │
│  │                                                │      │
│  │  ③ VECTOR_COSINE() で類似症例を検索              │      │
│  │     症例テーブル（VECTOR型カラム）                  │      │
│  │            │                                    │      │
│  │            ▼                                    │      │
│  │  ④ JsonAdvSQL テーブルと JOIN                     │      │
│  │     → 類似症例の臨床データ（検査値・処方・転帰）     │      │
│  │                                                │      │
│  └────────────────────────────────────────────────┘      │
│            │                                            │
│            ▼                                            │
│  ⑤ 検索結果                                              │
│     類似度スコア付きの症例リスト                             │
│     + 各症例の臨床データ                                   │
└─────────────────────────────────────────────────────────┘
```

---

## 各コンポーネントの詳細

### ① 検索クエリ

ユーザーが自然言語で症状を入力する。ICD-10 コードを知らなくてもよい。

```
入力例:
  「頭が重い、目の奥が痛い、吐き気がする」
  「2週間前から倦怠感と微熱が続く」
  「食後に胸焼けと右上腹部の鈍痛」
```

### ② Embedding 生成（外部 API）

症状テキストをベクトル（数値配列）に変換する。IRIS の外部で実行する。

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

### ③ IRIS Vector Search（コア）

IRIS 2024.1 以降で利用可能な `VECTOR` 型カラムと `VECTOR_COSINE()` 関数を使用する。

#### 症例テーブル定義（概念）

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

#### 類似検索クエリ（概念）

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

#### IRIS で実行するメリット

- ベクトル検索と SQL を**同じクエリ内**で実行できる
- 外部のベクトル DB（Pinecone, Weaviate 等）に接続する必要がない
- FHIR データ（JsonAdvSQL テーブル）と同じデータベース内で JOIN 可能

### ④ FHIR データとの JOIN

ベクトル検索で見つかった類似症例の臨床詳細を、JsonAdvSQL テーブルから取得する。

```sql
SELECT
    cr.SymptomText,
    cr.DiagnosisText,
    cr.similarity,
    p.BirthDate,
    p.Gender,
    vq.value_ValueLowRaw AS "検査値",
    oc.value_Text AS "検査項目"
FROM (
    SELECT TOP 5
        *,
        VECTOR_COSINE(SymptomVector, TO_VECTOR(:queryVector)) AS similarity
    FROM CaseRecord
    ORDER BY similarity DESC
) cr
JOIN HSFHIR_X0001_S.Patient p
    ON p.Key = cr.PatientRef
LEFT JOIN HSFHIR_X0001_S.Observation o
    ON o.subject_Reference = cr.PatientRef
LEFT JOIN HSFHIR_X0001_S_Observation.valueQuantity vq
    ON vq.Key = o.Key
LEFT JOIN HSFHIR_X0001_S_Observation.code oc
    ON oc.Key = o.Key
```

この SQL が示す最大のポイント：**ベクトル類似検索と FHIR 臨床データの JOIN が1つのクエリで完結する。**
外部ベクトル DB では、検索結果の ID で別途 FHIR サーバーにクエリする必要がある。

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

## データ蓄積フロー

FHIR リソースが POST されたタイミングで、Interoperability Production を通じて
症例テーブルへのベクトル格納を自動化する。

```
┌──────────────────────────────────────────────────┐
│          症例データの蓄積フロー                      │
│                                                  │
│  FHIR POST (Condition / Observation)             │
│       │                                          │
│       ▼                                          │
│  Interoperability Production                     │
│       │                                          │
│       ├─→ JsonAdvSQL テーブルに格納（自動）          │
│       │                                          │
│       └─→ BPL: 症例登録プロセス                     │
│              │                                   │
│              ├─ 症状テキストを組み立て               │
│              │   (Condition.code.text + 自由記述)   │
│              │                                   │
│              ├─ Embedding API を呼び出し            │
│              │   (Python Gateway or HTTP)         │
│              │                                   │
│              └─ CaseRecord テーブルに INSERT        │
│                  (テキスト + ベクトル + FHIR参照)     │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Embedding API の呼び出し方法

| 方法 | 説明 | 適用場面 |
|------|------|---------|
| **IRIS Embedded Python** | IRIS プロセス内で直接 Python を実行 | シンプル・低レイテンシ |
| **Python Gateway** | 外部 Python プロセスを Production から呼び出し | プロセス分離・スケーラビリティ |
| **HTTP アダプタ** | Production から REST API（OpenAI等）を直接呼び出し | 外部 API 利用時 |
| **バッチ処理** | 夜間に一括でベクトル化 | 大量データ移行時 |

---

## 他のアーキテクチャとの比較

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

## 実装時の検討事項

| 項目 | 検討内容 |
|------|---------|
| **Embedding モデル選択** | 日本語精度 vs コスト vs レイテンシのバランス。医療ドメインに特化したモデルの有無 |
| **ベクトル次元数** | 1536（OpenAI標準）vs 384（軽量モデル）— ストレージ・検索速度とのトレードオフ |
| **症例テキストの構成** | Condition.code.text のみか、Observation 値や自由記述（Clinical Note）も含めるか |
| **更新頻度** | リアルタイム（BPL トリガー）vs バッチ（夜間一括）|
| **Embedding API の配置** | Embedded Python / Python Gateway / 外部マイクロサービス |
| **既存データの移行** | 過去の Condition/Observation からバッチでベクトル化する初期ロード |
| **プライバシー** | Embedding API に送信するテキストの匿名化・最小化 |
| **精度評価** | 類似度閾値の調整、検索結果の臨床的妥当性の評価方法 |

---

## IRIS Vector Search の技術情報

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
