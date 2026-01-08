# 調査結果: CLIプロジェクトの初期化

## プロジェクト現状

### ディレクトリ構造
```
swifty-gr/
├── .git/               # Git リポジトリ（初期化済み）
├── spec.md             # 仕様書（既存）
└── Tasks/              # タスク管理ディレクトリ
    └── 1c990897/
```

### 状態分析
- **Swift プロジェクト**: 未初期化
- **Package.swift**: 存在しない
- **ソースコード**: 存在しない
- **README**: 存在しない

**結論**: 完全な新規プロジェクトとして初期化が必要

## Swift Package Manager (SPM) 調査

### 必要なファイル構成
```
swifty-gr/
├── Package.swift           # SPM マニフェストファイル
├── Sources/
│   └── swifty-gr/
│       └── main.swift      # エントリーポイント
└── Tests/
    └── swifty-grTests/
```

### Package.swift の要件
- **製品タイプ**: `.executable`（CLI ツール）
- **プラットフォーム**: macOS 15.0+
- **依存関係**: swift-argument-parser

## 依存ライブラリ調査

### swift-argument-parser
- **リポジトリ**: https://github.com/apple/swift-argument-parser
- **最新バージョン**: 1.5.0（2024年時点）
- **用途**: CLI コマンド・引数のパース
- **特徴**:
  - 宣言的な API
  - 自動ヘルプ生成
  - サブコマンドサポート
  - バリデーション機能

### コマンド構造案
```swift
@main
struct SwiftyGR: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "swifty-gr",
        abstract: "RICOH GR IV Wi-Fi controller via BLE",
        subcommands: [ScanCommand.self, ConnectCommand.self, WifiStartCommand.self]
    )
}
```

## Core Bluetooth フレームワーク調査

### 基本的な使用パターン

#### 1. BLE マネージャーの初期化
```swift
import CoreBluetooth

class BLEManager: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}
```

#### 2. デバイススキャン
- `CBCentralManager.scanForPeripherals(withServices:options:)`
- サービス UUID でフィルタリング可能
- `didDiscover peripheral` デリゲートで検出

#### 3. 接続処理
- `CBCentralManager.connect(_:options:)`
- `didConnect` / `didFailToConnect` デリゲート
- サービス・キャラクタリスティックの探索

#### 4. データ送受信
- `CBPeripheral.writeValue(_:for:type:)` でコマンド送信
- `CBPeripheralDelegate.didUpdateValue` で応答受信

### 非同期処理の課題
- Core Bluetooth はデリゲートパターン
- CLI は同期的な実行が必要
- **解決策**: Swift Concurrency（async/await）+ Continuation

## RICOH GR BLE API 仕様

### サービス UUID
- **GR Service**: `47FE55D8-447F-43EF-9AD9-FE6325E17C47`

### キャラクタリスティック
- **WLAN Control**: `4213FA42-1F1F-4E79-BE44-77E2F6F59963`
  - Write: Wi-Fi AP 制御コマンド
  - Notify: SSID/パスワード情報

### コマンド仕様
| コマンド | 値 | 説明 |
|---------|-----|------|
| Start AP | `0x01` | Wi-Fi AP 起動 |
| Stop AP | `0x00` | Wi-Fi AP 停止 |

### 応答データ形式
- SSID: 可変長文字列
- Password: 可変長文字列
- フォーマット: 要調査（ricoh-gr-bluetooth-api 参照）

## JSON 出力設計

### Codable を使用した実装
```swift
struct ScanOutput: Codable {
    let success: Bool
    let devices: [Device]?
    let error: ErrorInfo?
}

struct Device: Codable {
    let name: String
    let uuid: String
    let rssi: Int
}
```

### 標準出力/エラー出力の分離
- stdout: JSON のみ
- stderr: ログ・デバッグ情報

## 実装上の技術課題

### 1. デリゲートパターンと async/await の統合
**課題**: Core Bluetooth はデリゲートベース、CLI は同期実行が必要

**解決策**: 
```swift
func scanDevices() async throws -> [Device] {
    return try await withCheckedThrowingContinuation { continuation in
        // デリゲートで継続を解決
    }
}
```

### 2. タイムアウト処理
**課題**: BLE 操作は時間がかかる可能性がある

**解決策**: `Task.timeout` または `withThrowingTaskGroup`

### 3. Bluetooth 権限管理
**課題**: macOS の Bluetooth 権限が必要

**対処**:
- Info.plist に `NSBluetoothAlwaysUsageDescription` 追加
- 権限状態のチェックとエラーハンドリング

### 4. ペアリング状態の管理
**課題**: ペアリング済みデバイスの再接続

**調査必要事項**:
- macOS のペアリング情報の保存場所
- 再接続時の挙動

## ディレクトリ構成（実装予定）

```
swifty-gr/
├── Package.swift                    # SPM マニフェスト
├── README.md                        # ドキュメント
├── Sources/
│   └── swifty-gr/
│       ├── main.swift              # エントリーポイント
│       ├── Commands/               # コマンド実装
│       │   ├── ScanCommand.swift
│       │   ├── ConnectCommand.swift
│       │   └── WifiStartCommand.swift
│       ├── BLE/                    # BLE 処理
│       │   ├── BLEManager.swift
│       │   ├── BLEError.swift
│       │   └── GRService.swift     # GR 固有の定義
│       └── Models/                 # データモデル
│           ├── Device.swift
│           ├── Output.swift
│           └── ErrorInfo.swift
└── Tests/
    └── swifty-grTests/
        └── BLEManagerTests.swift
```

## 参考リソース

### 必須
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - CLI フレームワーク
- [ricoh-gr-bluetooth-api](https://github.com/dm-zharov/ricoh-gr-bluetooth-api) - BLE API 仕様
- Apple Core Bluetooth Programming Guide

### 参考
- [GRSync](https://github.com/clyang/GRsync) - HTTP API 実装例

## 次のステップへの推奨事項

仕様策定（spec）段階では、以下を明確にする必要があります:

1. **Package.swift の具体的な定義**
2. **各コマンドの詳細な I/O 仕様**
3. **BLEManager の API 設計**
4. **エラーハンドリングの詳細**
5. **async/await と Continuation の実装パターン**
6. **タイムアウト処理の実装方法**
