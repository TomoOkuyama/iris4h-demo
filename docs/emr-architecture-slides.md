# IRIS 電子カルテ デモ — スライドアウトライン

---

## スライド1: タイトル

**IRIS 電子カルテ デモ**
FHIR R4 API だけで動く電子カルテ UI のアーキテクチャ

InterSystems IRIS for Health 2025.3

---

## スライド2: このデモで見せること

- FHIR REST API だけで電子カルテ UI を構築
- カスタム API サーバー（Express, NestJS 等）不要
- サーバーサイドのアプリケーションコード = ゼロ
- 異常値検出 → HL7 メッセージ自動生成（Interoperability）

---

## スライド3: 全体アーキテクチャ

```
ブラウザ（単体 HTML ファイル）
  │
  │ fetch() + Basic認証
  │
  ▼
Web Gateway (port 11202)
  │
  ▼
IRIS for Health
  ├── FHIR R4 エンドポイント（REST API）
  ├── JsonAdvSQL ストレージ（JSON + SQL 自動生成）
  └── Interoperability Production（BPL → DTL → HL7）
```

**ポイント:** ブラウザ ↔ IRIS の間に中間サーバーがない

---

## スライド4: 技術スタック

| レイヤー | 技術 | 備考 |
|---------|------|------|
| フロントエンド | HTML + CSS + JavaScript | 単体ファイル、フレームワーク不使用 |
| CSS | Bootstrap 4.6（ローカル同梱） | レスポンシブ対応 |
| アイコン | Font Awesome 5（ローカル同梱） | 医療系アイコン |
| データ取得 | ブラウザ標準 fetch API | jqFhir 等のライブラリ不使用 |
| 認証 | Basic認証（Authorization ヘッダー） | デモ用。本番は OAuth 2.0 / SMART on FHIR |
| バックエンド | なし（IRIS の FHIR API が直接応答） | カスタム API サーバー不要 |
| データベース | IRIS for Health（JsonAdvSQL） | FHIR リポジトリ + FHIR SQL Builder で SQL 分析 |

---

## スライド5: 画面構成

```
┌──────────────────────────────────────────────────┐
│  ヘッダーバー（病院名・ログインユーザー・時刻）        │
├──────────┬───────────────────────────────────────┤
│          │  患者ヘッダー（名前・年齢・住所・ID）      │
│  患者    │───────────────────────────────────────│
│  一覧    │  タブ: サマリ | バイタル | 検査 | SpO2 | FHIR│
│          │───────────────────────────────────────│
│  検索    │  病名・既往歴（タグ表示）                  │
│  フィルタ │  アレルギー（重症度別色分け）               │
│          │  最新バイタル（タイル表示・異常値ハイライト）  │
│  20名    │  検査結果（テーブル・異常値ハイライト）       │
│          │                                       │
├──────────┴───────────────────────────────────────┤
│  [左パネル: 270px固定]  [右パネル: 残り全幅]          │
└──────────────────────────────────────────────────┘
```

---

## スライド6: データ取得フロー — 患者一覧

**画面起動時:**

```
① fetch('/csp/healthshare/fhirserver/fhir/r4/Patient?_sort=-_lastUpdated&_count=100')

② FHIR Bundle（searchset）が返る
   {
     "resourceType": "Bundle",
     "total": 20,
     "entry": [
       { "resource": { "resourceType": "Patient", "id": "1", "name": [...], ... } },
       ...
     ]
   }

③ 左パネルに 20名の患者リストを描画
   - 名前（漢字 + カナ）
   - 性別・年齢
   - 診察券番号
```

---

## スライド7: データ取得フロー — 患者選択時

**患者をクリック → 4つの FHIR API を Promise.all で並列呼び出し:**

```javascript
const [patient, conditions, allergies, vitals, labs] = await Promise.all([
  fhirGet('/Patient?_id=19'),
  fhirGet('/Condition?patient=19'),
  fhirGet('/AllergyIntolerance?patient=19'),
  fhirGet('/Observation?patient=19&category=vital-signs&_sort=-date'),
  fhirGet('/Observation?patient=19&category=laboratory&_sort=-date')
]);
```

**5つの API を並列実行 → 全データが揃ってから画面を描画**

---

## スライド8: 取得データと画面表示の対応

| FHIR リソース | API | 画面表示 |
|--------------|-----|---------|
| Patient | `GET /Patient?_id=N` | ヘッダー（名前・年齢・住所・電話・ID） |
| Condition | `GET /Condition?patient=N` | 病名タグ（ICD-10 コード付き） |
| AllergyIntolerance | `GET /AllergyIntolerance?patient=N` | アレルギータグ（重症度別色分け） |
| Observation (vital-signs) | `GET /Observation?patient=N&category=vital-signs` | バイタルタイル + 履歴テーブル |
| Observation (laboratory) | `GET /Observation?patient=N&category=laboratory` | 検査結果テーブル |

**全て FHIR 標準の検索パラメータのみ使用 — カスタム API なし**

---

## スライド9: 異常値の判定ロジック（クライアント側）

| 項目 | 正常 | 注意（黄） | 危険（赤） |
|------|------|-----------|-----------|
| SpO2 | >= 95% | 90〜94% | < 90% |
| 体温 | < 37.5℃ | 37.5〜37.9℃ | >= 38.0℃ |
| 収縮期血圧 | < 140 | 140〜159 | >= 160 |
| 拡張期血圧 | < 90 | 90〜99 | >= 100 |
| HbA1c | < 7.0% | 7.0〜7.9% | >= 8.0% |
| クレアチニン | < 1.5 | 1.5〜1.9 | >= 2.0 |
| ヘモグロビン | >= 10 | 8.0〜9.9 | < 8.0 |

**→ 異常値はテーブル行の背景色 + バッジ で表示**
**→ 患者ヘッダーにアラートバッジ（SpO2低下・発熱・高血圧・アレルギー注意）**

---

## スライド10: SpO2 記録 → Interoperability 連携

**SpO2 入力タブで値を設定 → 「記録する」ボタン:**

```
① ブラウザが FHIR Bundle を POST
   Bundle = Patient PUT + Observation POST

② IRIS の Interoperability Production がトリガー

③ BPL（ビジネスプロセス）が SpO2 値を判定

④ SpO2 < 90% の場合:
   → DTL が HL7 v2.5 SIU_S12 メッセージに変換
   → ファイル出力（./Out/）

⑤ 画面が自動リロード → 新しいバイタル値が反映
```

---

## スライド11: Interoperability 処理フロー

```
FHIR Bundle POST
  │
  ▼
HS.FHIRServer.Interop.Service（ビジネスサービス）
  │
  ▼
Solution.FHIRBPL（ビジネスプロセス）
  ├── FHIR CRUD を実行（HS.FHIRServer.Interop.Operation）
  │
  └── SpO2 < 90% ?
       │
       ├── Yes → Solution.FromFhirObsToSIUS12（DTL: HL7変換）
       │           │
       │           ▼
       │         To_Scheduling（HL7 ファイル出力 → ./Out/）
       │
       └── No → 何もしない
```

**BPL も DTL もコード不要 — Management Portal の GUI で定義**

---

## スライド12: なぜこのアーキテクチャが成立するか

### 従来のアプローチ

```
ブラウザ → カスタム API サーバー → ORM → RDB
           (Express/NestJS等)    (Prisma等)
           ↑ ここの開発が大変
```

### IRIS のアプローチ

```
ブラウザ → FHIR REST API → IRIS（データ + ロジック）
           ↑ 標準 API     ↑ プラットフォームが提供
```

**カスタム API サーバーが不要な理由:**
- FHIR REST API が標準で全 CRUD + 検索を提供
- 検索パラメータ（部分一致、範囲、JOIN相当の_include）が豊富
- Interoperability でサーバーサイドロジックを Production 内に定義

---

## スライド13: 開発者が書いたもの / 書かなかったもの

### 書いたもの

| ファイル | 行数 | 内容 |
|---------|------|------|
| `index.html` | 約350行 | HTML + CSS + JavaScript（全部入り） |

### 書かなかったもの（IRIS が提供）

| 通常必要なもの | IRIS での対応 |
|--------------|-------------|
| API サーバー（Express等） | FHIR エンドポイント（組み込み） |
| DB スキーマ定義 | FHIR SQL Builder（GUI定義） |
| ORM / データアクセス層 | FHIR REST API |
| 認証・認可 | OAuth 2.0 / Basic認証（組み込み） |
| メッセージキュー | Production（組み込み） |
| 異常値通知ロジック | BPL（GUI定義） |
| HL7 変換 | DTL（GUI定義） |

---

## スライド14: デモ用データ

| リソース | 件数 | 内容 |
|---------|------|------|
| Patient | 20名 | 全国各地の日本人（20代〜80代） |
| Observation (SpO2) | 19件 | 正常(97%)〜重症(78%) |
| Observation (体温) | 19件 | 平熱(36.3℃)〜高熱(39.1℃) |
| Observation (血圧) | 13件 | 正常〜重症高血圧 |
| Observation (検査) | 20件 | 血糖値・HbA1c・Hb・Cr |
| Condition | 23件 | 糖尿病・高血圧・CKD・心不全・COPD 等 |
| AllergyIntolerance | 10件 | 薬剤・食物・環境 |

**臨床的に整合性のあるストーリー付きダミーデータ**
（例: 心不全 + CKD4 の患者は SpO2低下 + Cr高値 + 貧血）

---

## スライド15: まとめ

### この電子カルテ UI が証明すること

1. **FHIR API だけで電子カルテが作れる** — カスタム API サーバー不要
2. **1つの HTML ファイルで完結** — フレームワーク依存なし
3. **データは全て FHIR 標準** — ベンダーロックインなし
4. **異常値検出 → HL7 連携が自動** — Interoperability Production
5. **同じデータに SQL でもアクセス可能** — FHIR SQL Builder でプロジェクション定義（別途 Vector Search も利用可能）

### 次のステップ

- この UI をベースに、プロダクトに必要な機能を追加
- FHIR API + SQL + Vector Search の組み合わせで症例検索を PoC
- 電子カルテ情報共有サービス（FHIR必須）への対応基盤として検証

---

## スライド16: アクセス情報

| 項目 | URL / コマンド |
|------|---------------|
| 電子カルテ UI | `http://localhost:11202/csp/emr/index.html` |
| FHIR エンドポイント | `http://localhost:11202/csp/healthshare/fhirserver/fhir/r4` |
| Management Portal | `http://localhost:11202/csp/sys/%25CSP.Portal.Home.zen` |
| ビジュアルトレース | `http://localhost:11202/csp/healthshare/fhirserver/EnsPortal.MessageViewer.zen` |
| 認証 | `_SYSTEM` / `SYS` |
| GitHub | `https://github.com/TomoOkuyama/iris4h-demo` |
