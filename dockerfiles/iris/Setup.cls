/// FHIRリポジトリ（FHIRSERVER）用ネームスペース作成／初期設定用クラス
/// 元テンプレート: https://github.com/Intersystems-jp/IRIS-FHIR-Oximeter-Template
/// IRIS for Health 2025.3 環境向けに調整
Class ISJ.Setup
{

/// FHIR R4リポジトリを作成するため、ネームスペースとFHIR用構成（RESTのベースURLなど）を作成
/// アプリケーションサンプル（Interoperabilityメニューのプロダクション）をインポート
ClassMethod setUpFHIR(ns As %String = "fhirserver") As %Status
{
    #dim ex As %Exception.AbstractException
    set status=$$$OK

    try {
        // ネームスペース作成（ユーティリティがあるHSLIBに移動してユーティリティ実行）
        set $namespace = "HSLIB"
        // サンプルインポートのためのベースディレクトリのパスを設定
        set baseDir = "/opt/app/"
        // ネームスペース作成
        set status = ##class(HS.Util.Installer.Foundation).Install(ns)
        $$$ThrowOnError(status)

        // 作成したネームスペースに移動し、src以下のソースコードをインポート
        set $namespace = ns
        do $system.OBJ.LoadDir(baseDir_ "src/Solution/", "ck")
        do $system.OBJ.Compile("Solution.FromFhirObsToSIUS12","ck")

        // FHIR対応用ネームスペース作成のために必要なインストールを実施
        do ##class(HS.FHIRServer.Installer).InstallNamespace()

        // FHIRリポジトリ用RESTのベースパス作成準備
        set tFHIRApp = "/csp/healthshare/"_ns_"/fhir/r4"
        set tStrategyClass = "HS.FHIRServer.Storage.JsonAdvSQL.InteractionsStrategy"
        set tMetadataPackages = $lb("hl7.fhir.r4.core@4.0.1")

        // FHIRサーバ機能を作成したネームスペースにインストール（JsonAdvSQL ストレージ戦略）
        do ##class(HS.FHIRServer.Installer).InstallInstance(tFHIRApp, tStrategyClass, tMetadataPackages,"",0)

        // FHIRアプリケーション用の構成
        set strategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(tFHIRApp)
        set configData = strategy.GetServiceConfigData()
        set configData.DebugMode = 4

        set cspApp = ##class(HS.Util.RESTCSPConfig).URLIndexOpen(tFHIRApp)
        set cspApp.ServiceConfigName = "HS.FHIRServer.Interop.Service"

        set status = cspApp.%Save()
        $$$ThrowOnError(status)

        do strategy.SaveServiceConfigData(configData)

        // Webアプリ用CSPアプリケーションを登録
        set $namespace = "%SYS"
        // /csp/emr — 電子カルテUI
        if '##class(Security.Applications).Exists("/csp/emr") {
            kill props
            set props("AutheEnabled") = 64
            set props("NameSpace") = "FHIRSERVER"
            set props("Path") = "/usr/irissys/csp/emr"
            set props("IsNameSpaceDefault") = 0
            set props("Recurse") = 1
            set props("ServeFiles") = 1
            set props("Type") = 2
            set props("Enabled") = 1
            set status = ##class(Security.Applications).Create("/csp/emr", .props)
            $$$ThrowOnError(status)
        }
        set $namespace = ns

        // プロダクションの開始
        do ##class(Ens.Director).StartProduction("Solution.FoundationProduction")
        // 自動開始の設定
        do ##class(Ens.Director).SetAutoStart("Solution.FoundationProduction")
    }
    catch ex {
        set status=ex.AsStatus()
    }
    return status
}

}
