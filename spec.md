# swifty-gr 要件定義・仕様書

## 概要

RICOH GR IV の Wi-Fi モードを Mac から BLE 経由で起動するための CLI ツール。

## 背景

- GR IV は Wi-Fi 経由で HTTP API を提供し、写真のダウンロードが可能
- ただし Wi-Fi AP の起動には GR World アプリ（iOS）からの BLE 接続が必要
- Mac から直接 BLE 経由で Wi-Fi を起動できるようにしたい

## 技術スタック

- 言語: Swift
- フレームワーク: Core Bluetooth, Foundation
- 形式: CLI (Swift Package Manager)
- 対応 OS: macOS 15.0+

## 機能要件

### Phase 1: カメラ検出

```bash
swifty-gr scan
```

BLE でカメラをスキャンし、検出された GR IV の情報を出力する。

**出力例（成功）:**
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

**出力例（デバイスなし）:**
```json
{
  "success": true,
  "devices": []
}
```

### Phase 2: カメラ接続

```bash
swifty-gr connect <uuid>
```

指定した UUID のカメラに BLE 接続し、ペアリングを行う。

**出力例（成功）:**
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

### Phase 3: Wi-Fi 起動

```bash
swifty-gr wifi-start <uuid>
```

接続済みのカメラに Wi-Fi AP 起動コマンドを送信する。

**出力例（成功）:**
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

## エラー出力形式

すべてのエラーは以下の JSON 形式で出力する。

```json
{
  "success": false,
  "error": "<error_code>",
  "message": "<human_readable_message>"
}
```

### エラーコード一覧

| コード | 説明 |
|--------|------|
| `bluetooth_off` | Bluetooth が無効 |
| `bluetooth_unauthorized` | Bluetooth のアクセス権限がない |
| `device_not_found` | 指定したカメラが見つからない |
| `connection_failed` | BLE 接続に失敗 |
| `connection_timeout` | 接続タイムアウト（30秒） |
| `pairing_failed` | ペアリングに失敗 |
| `command_failed` | Wi-Fi 起動コマンドの送信に失敗 |
| `unknown` | 不明なエラー |

## 非機能要件

- タイムアウト: 30秒
- 終了コード: 成功時 0、失敗時 1
- 出力: stdout に JSON のみ（ログは stderr）

## BLE 仕様（参考）

RICOH GR の BLE API（ricoh-gr-bluetooth-api より）:

- Service UUID: `47FE55D8-447F-43EF-9AD9-FE6325E17C47`
- WLAN Control Characteristic UUID: `4213FA42-1F1F-4E79-BE44-77E2F6F59963`

### WLAN Control Commands

| Command | Value | Description |
|---------|-------|-------------|
| Start AP | `0x01` | Wi-Fi AP を起動 |
| Stop AP | `0x00` | Wi-Fi AP を停止 |

## ディレクトリ構成

```
swifty-gr/
├── Package.swift
├── Sources/
│   └── swifty-gr/
│       ├── main.swift
│       ├── Commands/
│       │   ├── ScanCommand.swift
│       │   ├── ConnectCommand.swift
│       │   └── WifiStartCommand.swift
│       ├── BLE/
│       │   └── BLEManager.swift
│       └── Models/
│           ├── Device.swift
│           └── Output.swift
└── README.md
```

## 依存ライブラリ

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - CLI 引数パース

## 実装優先順位

1. プロジェクトセットアップ（Package.swift）
2. JSON 出力モデル
3. BLEManager（スキャン機能）
4. `scan` コマンド
5. BLEManager（接続機能）
6. `connect` コマンド
7. BLEManager（Wi-Fi 起動）
8. `wifi-start` コマンド

## 参考資料

- [ricoh-gr-bluetooth-api](https://github.com/dm-zharov/ricoh-gr-bluetooth-api) - BLE API 仕様
- [GRSync](https://github.com/clyang/GRsync) - HTTP API 参考
- RICOH GR IV HTTP API: `http://192.168.0.1/v1/props`, `/v1/photos`