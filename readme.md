# IRIS for Health デモ環境

IRIS for Health / Web Gateway 用の docker-compose テンプレート。

## 構成

| コンテナ | ホスト名 | ポート | 説明 |
|---------|---------|--------|------|
| iris4h | iris | 11201:1972 | IRIS for Health 2025.3 |
| webgw4h | webgw | 11202:80, 11203:443 | Web Gateway 2025.3 |

## セットアップ手順

### 1. 事前準備

- `dockerfiles/iris/iris.key` にライセンスキーファイルを配置
- venv 環境の準備

### 2. 起動

```bash
docker compose up -d
```

### 3. Management Portal へのアクセス

```
http://localhost:11202/csp/sys/%25CSP.Portal.Home.zen?$NAMESPACE=%25SYS&
```

デフォルト認証情報: `_SYSTEM` / `SYS`

## FHIR R4 サーバー構成

### 自動セットアップ内容

Docker イメージビルド時に `iris.script` により以下が自動実行される：

1. **システム設定**（%SYS ネームスペース）
   - 事前定義ユーザのパスワード無期限化
   - 日本語ロケール（jpuw）の設定

2. **FHIR R4 サーバーの構築**（HSLIB → FHIRSERVER ネームスペース）
   - `HS.Util.Installer.Foundation` による `FHIRSERVER` ネームスペースの作成
   - `HS.FHIRServer.Installer` による FHIR サーバーのインストール
   - エンドポイント: `/fhir/r4`
   - FHIRバージョン: `hl7.fhir.r4.core@4.0.1`
   - ストレージ: `HS.FHIRServer.Storage.JsonAdvSQL.InteractionsStrategy`

### FHIR データのインポート方法

#### REST API 経由

```bash
# 個別リソース
curl -u _SYSTEM:SYS -X POST http://localhost:11202/fhir/r4/Patient \
  -H "Content-Type: application/fhir+json" \
  -d @patient.json

# Bundle（Transaction）
curl -u _SYSTEM:SYS -X POST http://localhost:11202/fhir/r4 \
  -H "Content-Type: application/fhir+json" \
  -d @bundle.json
```

#### IRIS ターミナルから DataLoader API

```objectscript
zn "FHIRSERVER"
Set sc = ##class(HS.FHIRServer.Tools.DataLoader).SubmitResourceFiles("/path/to/data", "FHIRServer", "/fhir/r4")
```

## カスタマイズ

このフォルダを名前を変えてコピーし、以下を編集：
- `docker-compose.yml` 内の `container_name` とポート番号
- `.vscode/settings.json`
