# 仕様書: CLIプロジェクトの初期化

## 1. プロジェクト構成

### 1.1 Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swifty-gr",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "swifty-gr",
            targets: ["swifty-gr"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.5.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "swifty-gr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "swifty-grTests",
            dependencies: ["swifty-gr"]
        )
    ]
)
```

### 1.2 ディレクトリ構造

```
swifty-gr/
├── Package.swift
├── README.md
├── Sources/
│   └── swifty-gr/
│       ├── main.swift
│       ├── Commands/
│       │   ├── ScanCommand.swift
│       │   ├── ConnectCommand.swift
│       │   └── WifiStartCommand.swift
│       ├── BLE/
│       │   ├── BLEManagerProtocol.swift
│       │   ├── BLEManager.swift
│       │   ├── BLEError.swift
│       │   └── GRService.swift
│       └── Models/
│           ├── Device.swift
│           ├── Output.swift
│           └── ErrorInfo.swift
└── Tests/
    └── swifty-grTests/
        ├── BLEManagerTests.swift
        └── MockBLEManager.swift
```

## 2. CLI コマンド仕様

### 2.1 コマンド構造

```swift
@main
struct SwiftyGR: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "swifty-gr",
        abstract: "RICOH GR IV Wi-Fi controller via BLE",
        version: "1.0.0",
        subcommands: [
            ScanCommand.self,
            ConnectCommand.self,
            WifiStartCommand.self
        ]
    )
}
```

### 2.2 scan コマンド

**構文:**
```bash
swifty-gr scan [--timeout <seconds>]
```

**オプション:**
- `--timeout`: スキャンタイムアウト（デフォルト: 30秒）

**出力（成功）:**
```json
{
  "success": true,
  "devices": [
    {
      "name": "GR_CAC691",
      "uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
      "rssi": -45
    }
  ]
}
```

**出力（デバイスなし）:**
```json
{
  "success": true,
  "devices": []
}
```

**終了コード:**
- 0: 成功（デバイスなしも含む）
- 1: エラー

### 2.3 connect コマンド

**構文:**
```bash
swifty-gr connect <uuid> [--timeout <seconds>]
```

**引数:**
- `<uuid>`: 接続先デバイスの UUID（必須、UUID 形式で自動バリデーション）

**オプション:**
- `--timeout`: 接続タイムアウト（デフォルト: 30秒）

**実装:**
```swift
struct ConnectCommand: AsyncParsableCommand {
    @Argument var uuid: UUID  // ArgumentParser が自動的に UUID をバリデーション
    @Option var timeout: TimeInterval = 30
}
```

**出力（成功）:**
```json
{
  "success": true,
  "device": {
    "name": "GR_CAC691",
    "uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
  },
  "message": "Connected and paired"
}
```

**終了コード:**
- 0: 成功
- 1: エラー

### 2.4 wifi-start コマンド

**構文:**
```bash
swifty-gr wifi-start <uuid> [--timeout <seconds>]
```

**引数:**
- `<uuid>`: 接続先デバイスの UUID（必須、UUID 形式で自動バリデーション）

**オプション:**
- `--timeout`: タイムアウト（デフォルト: 30秒）

**実装:**
```swift
struct WifiStartCommand: AsyncParsableCommand {
    @Argument var uuid: UUID  // ArgumentParser が自動的に UUID をバリデーション
    @Option var timeout: TimeInterval = 30
}
```

**出力（成功）:**
```json
{
  "success": true,
  "wifi": {
    "ssid": "GR_CAC690",
    "password": "gHyDDm^8"
  },
  "message": "Wi-Fi AP started"
}
```

**終了コード:**
- 0: 成功
- 1: エラー

## 3. データモデル

### 3.1 Device（Models/Device.swift）

```swift
struct Device: Codable {
    let name: String
    let uuid: String
    let rssi: Int
}
```

### 3.2 Output（Models/Output.swift）

```swift
protocol JSONOutput: Codable {
    func printJSON()
}

extension JSONOutput {
    func printJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self),
           let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
    }
}

struct ScanOutput: JSONOutput {
    let success: Bool
    let devices: [Device]?
    let error: ErrorInfo?
}

struct ConnectOutput: JSONOutput {
    let success: Bool
    let device: Device?
    let message: String?
    let error: ErrorInfo?
}

struct WifiOutput: JSONOutput {
    struct WifiInfo: Codable {
        let ssid: String
        let password: String
    }
    
    let success: Bool
    let wifi: WifiInfo?
    let message: String?
    let error: ErrorInfo?
}
```

### 3.3 ErrorInfo（Models/ErrorInfo.swift）

```swift
struct ErrorInfo: Codable {
    let error: String
    let message: String
}

struct ErrorOutput: JSONOutput {
    let success: Bool = false
    let error: ErrorInfo
}
```

## 4. エラーハンドリング

### 4.1 エラーコード定義（BLE/BLEError.swift）

```swift
enum BLEError: Error {
    case bluetoothOff
    case bluetoothUnauthorized
    case deviceNotFound
    case connectionFailed
    case connectionTimeout
    case pairingFailed
    case commandFailed
    case unknown(Error)
    
    var code: String {
        switch self {
        case .bluetoothOff: return "bluetooth_off"
        case .bluetoothUnauthorized: return "bluetooth_unauthorized"
        case .deviceNotFound: return "device_not_found"
        case .connectionFailed: return "connection_failed"
        case .connectionTimeout: return "connection_timeout"
        case .pairingFailed: return "pairing_failed"
        case .commandFailed: return "command_failed"
        case .unknown: return "unknown"
        }
    }
    
    var message: String {
        switch self {
        case .bluetoothOff:
            return "Bluetooth is turned off"
        case .bluetoothUnauthorized:
            return "Bluetooth access is not authorized"
        case .deviceNotFound:
            return "Device not found"
        case .connectionFailed:
            return "Failed to connect to device"
        case .connectionTimeout:
            return "Connection timeout (30 seconds)"
        case .pairingFailed:
            return "Failed to pair with device"
        case .commandFailed:
            return "Failed to send Wi-Fi start command"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    func toErrorInfo() -> ErrorInfo {
        ErrorInfo(error: code, message: message)
    }
}
```

### 4.2 エラー出力フォーマット

すべてのエラーは以下の形式で stdout に出力:

```json
{
  "success": false,
  "error": "<error_code>",
  "message": "<human_readable_message>"
}
```

## 5. BLE 処理実装

### 5.1 GRService 定義（BLE/GRService.swift）

```swift
import CoreBluetooth

struct GRService {
    static let serviceUUID = CBUUID(string: "47FE55D8-447F-43EF-9AD9-FE6325E17C47")
    static let wlanControlUUID = CBUUID(string: "4213FA42-1F1F-4E79-BE44-77E2F6F59963")
    
    enum WLANCommand: UInt8 {
        case stop = 0x00
        case start = 0x01
    }
}
```

### 5.2 BLEManagerProtocol（BLE/BLEManagerProtocol.swift）

テスタビリティのため、プロトコルとして定義:

```swift
protocol BLEManagerProtocol {
    func scanDevices(timeout: TimeInterval) async throws -> [Device]
    func connect(uuid: UUID, timeout: TimeInterval) async throws -> Device
    func startWifi(uuid: UUID, timeout: TimeInterval) async throws -> (ssid: String, password: String)
    func disconnect()
}
```

### 5.3 BLEManager 実装（BLE/BLEManager.swift）

**重要**: CoreBluetooth のデリゲートパターンと Swift Concurrency の統合のため、actor ではなく class として実装:

```swift
final class BLEManager: NSObject, BLEManagerProtocol {
    private let queue = DispatchQueue(label: "com.swifty-gr.ble")
    private var centralManager: CBCentralManager!
    
    private var scanContinuation: CheckedContinuation<[Device], Error>? {
        willSet {
            if scanContinuation != nil {
                fatalError("Scan already in progress")
            }
        }
    }
    private var discoveredDevices: [UUID: (peripheral: CBPeripheral, rssi: Int)] = [:]
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }
    
    func scanDevices(timeout: TimeInterval) async throws -> [Device]
    func connect(uuid: UUID, timeout: TimeInterval) async throws -> Device
    func startWifi(uuid: UUID, timeout: TimeInterval) async throws -> (ssid: String, password: String)
    func disconnect()
}

extension BLEManager: CBCentralManagerDelegate {
    // デリゲートメソッド実装
}

extension BLEManager: CBPeripheralDelegate {
    // デリゲートメソッド実装
}
```

### 5.4 Bluetooth 状態チェック

すべての BLE 操作の前に Bluetooth 状態を確認:

```swift
private func ensureBluetoothReady() async throws {
    // Bluetooth 状態をチェック
    switch centralManager.state {
    case .poweredOn:
        return
    case .poweredOff:
        throw BLEError.bluetoothOff
    case .unauthorized:
        throw BLEError.bluetoothUnauthorized
    case .unknown, .resetting, .unsupported:
        // 少し待ってから再チェック
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        switch centralManager.state {
        case .poweredOn:
            return
        case .poweredOff:
            throw BLEError.bluetoothOff
        case .unauthorized:
            throw BLEError.bluetoothUnauthorized
        default:
            throw BLEError.unknown(NSError(domain: "BLE", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bluetooth state: \(centralManager.state.rawValue)"]))
        }
    @unknown default:
        throw BLEError.unknown(NSError(domain: "BLE", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown Bluetooth state"]))
    }
}

func scanDevices(timeout: TimeInterval) async throws -> [Device] {
    // 最初に Bluetooth 状態をチェック
    try await ensureBluetoothReady()
    
    return try await withCheckedThrowingContinuation { continuation in
        scanContinuation = continuation
        discoveredDevices.removeAll()
        
        centralManager.scanForPeripherals(
            withServices: [GRService.serviceUUID],
            options: nil
        )
        
        // タイムアウト処理
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            self.centralManager.stopScan()
            
            let devices = self.discoveredDevices.map { uuid, info in
                Device(
                    name: info.peripheral.name ?? "RICOH GR (Unknown)",
                    uuid: uuid.uuidString,
                    rssi: info.rssi
                )
            }
            self.scanContinuation?.resume(returning: devices)
            self.scanContinuation = nil
        }
    }
}
```

### 5.5 デバイス名のフォールバック処理

BLE アドバタイズにデバイス名がない場合のフォールバック:

```swift
// デバイス検出時
let deviceName = peripheral.name ?? "RICOH GR (Unknown)"
let device = Device(
    name: deviceName,
    uuid: peripheral.identifier.uuidString,
    rssi: rssi
)
```

**理由**: GR Service UUID で検出されたデバイスは RICOH GR であることが確定しているため、名前が不明でも "RICOH GR" と表示。

### 5.6 タイムアウト処理

すべての非同期操作に 30 秒のタイムアウトを設定:

```swift
func withTimeout<T>(
    _ timeout: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw BLEError.connectionTimeout
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

## 6. 実装優先順位

### Phase 1: プロジェクトセットアップ
1. Package.swift の作成
2. ディレクトリ構造の作成
3. README.md の作成

### Phase 2: データモデル
1. Device モデル
2. Output モデル群
3. ErrorInfo と BLEError

### Phase 3: BLE 基盤
1. GRService 定義
2. BLEManagerProtocol 定義
3. BLEManager の基本構造（Bluetooth 状態チェック含む）
4. async/await 統合パターン

### Phase 4: scan コマンド
1. ScanCommand 実装
2. BLEManager.scanDevices() 実装（デバイス名フォールバック含む）
3. デバイス検出のテスト

### Phase 5: connect コマンド
1. ConnectCommand 実装（UUID バリデーション含む）
2. BLEManager.connect() 実装
3. 接続・ペアリングのテスト

### Phase 6: wifi-start コマンド
1. WifiStartCommand 実装（UUID バリデーション含む）
2. BLEManager.startWifi() 実装
3. Wi-Fi 起動のテスト

### Phase 7: テスト整備
1. MockBLEManager 実装
2. コマンドのユニットテスト
3. 統合テスト（実機）

## 7. 非機能要件の実装

### 7.1 ログ出力
- すべてのログは stderr に出力
- stdout は JSON のみ
- デバッグ時は `DEBUG=1 swifty-gr scan` で詳細ログ

### 7.2 権限管理
- Bluetooth 権限の確認
- 権限がない場合は適切なエラーメッセージ

### 7.3 テスト戦略
- **ユニットテスト**: 
  - BLEError のエラーコード・メッセージ
  - データモデルの Codable
  - コマンドのロジック（MockBLEManager 使用）
- **統合テスト**: 
  - 実機での BLE 通信（手動）
  - 各コマンドのエンドツーエンドテスト

## 8. 実装上の注意事項

### 8.1 スレッドセーフティ
**重要**: BLEManager は actor ではなく class として実装し、専用の DispatchQueue を使用:

```swift
final class BLEManager: NSObject, BLEManagerProtocol {
    private let queue = DispatchQueue(label: "com.swifty-gr.ble")
    private var centralManager: CBCentralManager!
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }
}
```

**理由**: 
- CoreBluetooth のデリゲートメソッドは指定した queue で呼ばれる
- actor の isolation とデリゲートパターンが競合する
- 専用 queue を使用することでスレッドセーフを確保

### 8.2 リソース管理
- 接続後は必ず切断処理を実行
- スキャン中のキャンセル処理を適切に実装
- Continuation の二重解決を防止（willSet でチェック）

### 8.3 エラーハンドリング
- すべてのエラーを catch して JSON 形式で出力
- プログラムは異常終了せず、必ず終了コードを返す
- Bluetooth 状態を操作前に必ずチェック

### 8.4 テスタビリティ
- BLEManagerProtocol を使用してモック可能に
- コマンドは DI でマネージャーを注入できる設計
- ユニットテストで MockBLEManager を使用
