# IRIS for Health がサポートする医療標準規格

InterSystems IRIS for Health が対応する医療標準規格の一覧です。

---

## 1. データ交換規格

### HL7 v2.x

- **対応状況**: ネイティブサポート（組み込みスキーマ・パーサー・ルーティングエンジン）
- **サポートバージョン**: v2.1 〜 v2.8
- **主な機能**:
  - ADT, ORM, ORU, MDM 等の標準メッセージタイプをネイティブ処理
  - カスタムスキーマの定義・拡張が可能
  - TCP/IP（MLLP）およびファイルベースの送受信アダプタ
  - HL7 v2 → FHIR の組み込み変換（SDA経由）
  - HL7 Message Analyzer、DTL Generator 等の生産性ツール

### HL7 FHIR

- **対応状況**: ネイティブサポート（FHIRリポジトリ・FHIRサーバー内蔵）
- **サポートバージョン**:
  - DSTU2 (`hl7.fhir.r2`)
  - STU3 (`hl7.fhir.r3`)
  - **R4** (`hl7.fhir.r4.core@4.0.1`) — フルサポート（SDA変換含む）
  - R5 (`hl7.fhir.r5.core@5.0.0`) — リポジトリサポート（SDA変換はR4以前のみ）
- **主な機能**:
  - FHIR RESTful API（JSON/XML）
  - Bulk FHIR（インポート/エクスポート）
  - FHIR Terminology Service（CodeSystem, ValueSet, ConceptMap）
  - FHIRパッケージの追加による実装ガイド対応
  - JsonAdvSQL ストレージ戦略による検索性能・標準準拠性の向上（2024.1〜）
  - FHIR SQL Builder による SQL 分析用プロジェクション定義

### HL7 v3 / CDA / C-CDA

- **対応状況**: ネイティブサポート（組み込みXSLT変換）
- **主な機能**:
  - CDA → SDA 変換（XSLT 1.0）
  - SDA → CDA/C-CDA 生成
  - C-CDA 2.1 のインポート変換
  - CDA → SDA → FHIR のパイプライン変換
  - HL7 v2 メッセージからの C-CDA ドキュメント生成

### SDA（Summary Data Architecture）

- **対応状況**: ネイティブサポート（InterSystems独自の中間データモデル）
- CDA、HL7 v2、FHIR 間の変換における中間フォーマットとして機能
- カスタマイズ可能

---

## 2. 用語・コード体系

| コード体系 | 対応状況 | 用途 |
|-----------|---------|------|
| **ICD-10** | サポート | 診断コード（Condition リソース等） |
| **SNOMED CT** | サポート | 臨床用語（Problem, Procedure 等） |
| **LOINC** | サポート | 検査・バイタルサインコード（Observation 等） |
| **RxNorm** | サポート | 薬剤コード（MedicationRequest 等） |
| **CPT** | サポート | 処置コード |
| **NIC / NOC / NANDA** | サポート | 看護標準コード（Goal リソース等） |
| **MEDIS標準マスター** | カスタム実装 | カスタム CodeSystem/ValueSet として実装可能 |

FHIR Terminology Service 仕様に準拠し、CodeSystem・ValueSet・ConceptMap リソースの操作をサポート。ObjectScript の永続クラスを FHIR CodeSystem/ValueSet として公開する拡張機構も提供。

---

## 3. 画像・放射線

### DICOM

- **対応状況**: ネイティブサポート（組み込みアダプタ）
- **主な機能**:
  - DICOM メッセージの送受信（双方向）
  - バーチャルドキュメントとして Production 内でルーティング
  - メタデータ（コマンドセット）と画像データ（データセット）の処理
  - MRI、CTスキャナー等の医療画像機器との統合

---

## 4. 保険・請求

| 規格 | 対応状況 | 詳細 |
|------|---------|------|
| **X12** | ネイティブサポート | EDI標準、組み込みコンポーネントとデータウィザード |
| **EDIFACT** | ネイティブサポート | 国際EDI標準、ファイルサービス/オペレーション提供 |

---

## 5. セキュリティ・認証

| 規格 | 対応状況 | 詳細 |
|------|---------|------|
| **SMART on FHIR** | サポート | EHR Launch フロー対応 |
| **OAuth 2.0** | ネイティブサポート | FHIRサーバーをリソースサーバーとして構成可能 |
| **OpenID Connect** | ネイティブサポート | OAuth 2.0 と連携した認証・認可 |
| **ATNA** | サポート | 監査証跡・ノード認証（IHEプロファイル） |
| **XUA** | サポート | ユーザー認証アサーション（IHEプロファイル） |

---

## 6. IHE プロファイル

| プロファイル | 対応状況 | 説明 |
|------------|---------|------|
| **PIX** (Patient Identifier Cross-Referencing) | ネイティブ | 患者ID相互参照（EMPIへの確定的クエリ） |
| **PDQ** (Patient Demographics Query) | ネイティブ | 患者情報照会（EMPIへの確率的クエリ） |
| **XDS.b** (Cross-Enterprise Document Sharing) | ネイティブ | 施設間文書共有（Consumer/Source/Registry/Repository） |
| **XCA** (Cross-Community Access) | ネイティブ | コミュニティ間文書共有 |
| **XCA-I** (Cross-Community Access for Imaging) | ネイティブ | コミュニティ間画像共有（Imaging Gateway） |
| **MHD** (Mobile access to Health Documents) | ネイティブ | モバイルヘルスドキュメントアクセス |
| **XDS-I.b** (XDS for Imaging) | サポート | 画像ドキュメント共有 |

---

## 7. 日本固有の規格

| 規格 | 対応状況 | 詳細 |
|------|---------|------|
| **SS-MIX2** | サポート | HL7 v2 ベースのため、v2 ネイティブサポートが基盤。データ取り込み・FHIR変換が可能 |
| **JP Core FHIR** | パッケージ対応 | FHIR パッケージとしてインポート可能。Search Parameter の追加もサポート |
| **JAHIS** | 間接的サポート | IHE-ITI ベースであり、IHE プロファイル対応を通じて実装可能 |
| **MEDIS標準マスター** | カスタム実装 | カスタム CodeSystem/ValueSet として実装可能 |

---

## 8. 実装ガイド（Implementation Guides）

| フレームワーク | 対応状況 | 詳細 |
|--------------|---------|------|
| **US Core IG v3.1.0** | 組み込みサポート | FHIR エンドポイント構成時にパッケージとして選択可能 |
| **AU Base** | パッケージ対応 | FHIR パッケージとしてインポート可能 |
| **JP Core** | パッケージ対応 | FHIR パッケージとしてインポート可能 |
| **その他のIG** | パッケージ対応 | NPM 形式の FHIR パッケージを追加することで任意の IG に対応 |
| **OMOP** | サポート | 臨床研究データモデル |
| **i2b2** | サポート | 臨床研究インフラ |

---

## 9. その他の対応フォーマット

Production（統合エンジン）では、医療標準以外にも以下をサポート:

- XML / JSON
- CSV（区切り文字・固定長レコード）
- SOAP / REST
- TCP/IP / HTTP / FTP / ファイル

---

## 参考リンク

- [IRIS for Health 製品概要](https://www.intersystems.com/products/intersystems-iris-for-health/)
- [FHIR サポート概要](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIROVW_fhir)
- [HL7 v2 ルーティング](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EHL72)
- [CDA / C-CDA 変換](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXCDA_ch_cda)
- [DICOM 概要](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EDICOM_intro)
- [IHE プロファイル（PIX/PDQ）](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXIHE_IHE_scenarios_query_EMPI)
- [IHE プロファイル（XDS.b）](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXIHE_IHE_SCENARIOS_XDSB_QUERY)
- [FHIR サーバーセキュリティ（OAuth 2.0）](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIRADM_server_auth)
- [SDA-FHIR 変換](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIRPROD_transforms)
- [JP Core プロファイル検証方法](https://jp.community.intersystems.com/post/jp-core-%E3%81%AA%E3%81%A9%E3%81%AE%E3%82%AB%E3%82%B9%E3%82%BF%E3%83%A0%E3%83%97%E3%83%AD%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%82%92-iris-%E3%81%AE-fhir-%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA%E3%81%A7%E6%A4%9C%E8%A8%BC%E3%81%99%E3%82%8B%E6%96%B9%E6%B3%95)
