# qgc-custom — ESC テレメトリグラフ (Fly View オーバーレイ)

QGroundControl の Fly View に、ESC ごとの **RPM / 電圧 / 電流** を時系列グラフで
重ねて表示する custom build オーバーレイです。

**QGC 本体のソースは 1 行も変更していません。** upstream の更新は
`git pull` するだけで取り込めます。

---

## 1. 仕組み (なぜ更新に強いのか)

QGC v5 は「カスタムビルド」を公式にサポートしています。ルートの `CMakeLists.txt` は
ソースルート直下に `custom/` ディレクトリ (正確には `QGC_CUSTOM_DIR`、既定値 `custom`)
が存在すると、自動的にカスタムビルドとして構成します。

このオーバーレイが使っている拡張点は 3 つだけで、いずれも upstream が
「カスタムビルド向け」と明示している公式インターフェースです。

| 拡張点 | 使い方 |
|---|---|
| `custom/CMakeLists.txt` + `custom/cmake/CustomOverrides.cmake` | ルート `CMakeLists.txt` が自動で検出・include する |
| `QGCCorePlugin` サブクラス (`CUSTOMCLASS`) | QML の import path 追加と、リソース上書き用 URL interceptor の登録のみ |
| `FlyViewCustomLayer.qml` | Fly View 用の公式オーバーレイ差し込み口。upstream 版は空の placeholder |

QML の差し替えは Qt リソースの上書きで行います。`custom.qrc` が自前の
`FlyViewCustomLayer.qml` を `:/Custom/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml`
に登録し、`CustomPlugin` の `CustomQmlOverrideInterceptor` が実行時に
`qrc:/<path>` → `qrc:/Custom/<path>` へ書き換えます (該当リソースが存在する場合のみ)。

データ取得は `Vehicle::escs` (`EscStatusFactGroupListModel`) を QML から読むだけです。
これは MAVLink の `ESC_STATUS` / `ESC_INFO` を QGC 本体がパースして Fact 化したもので、
`activeVehicle.escs.get(i).rpm / .voltage / .current` で参照できます。
独自の MAVLink 受信コードは一切ありません。

---

## 2. ディレクトリ構成

```
custom-qgc/
├── qgroundcontrol/          # upstream (無改変)。custom -> ../qgc-custom の symlink のみ
└── qgc-custom/              # ← このリポジトリ
    ├── CMakeLists.txt       # custom ビルドのエントリポイント
    ├── custom.qrc           # QML リソース上書きの定義
    ├── cmake/
    │   └── CustomOverrides.cmake
    ├── src/
    │   ├── CustomPlugin.h/.cc   # 最小限の QGCCorePlugin サブクラス
    │   └── qml/
    │       └── FlyViewCustomLayer.qml   # Fly View オーバーレイ本体
    └── res/Custom/EscTelemetry/         # QML モジュール Custom.EscTelemetry
        ├── EscTelemetryPanel.qml        # 折りたたみ可能なパネル + サンプリング
        └── EscTelemetryChart.qml        # 1 メトリクス分のストリップチャート
```

`qgroundcontrol/custom` は `../qgc-custom` への symlink です。
upstream の `.git/info/exclude` に `/custom` を追加してあるので `git status` は常にクリーンです。

セットアップし直す場合:

```bash
ln -sfn ../qgc-custom qgroundcontrol/custom
echo "/custom" >> qgroundcontrol/.git/info/exclude
```

---

## 3. ビルド

必要な Qt は **6.11.0 〜 6.11.1** です (`qgroundcontrol/.github/build-config.json` が正)。
必要モジュール: `qtgraphs qtlocation qtpositioning qtspeech qtmultimedia qtserialport
qtimageformats qtshadertools qtconnectivity qtquick3d qtsensors qtscxml qtwebsockets qthttpserver`

```bash
cd qgroundcontrol
cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH=$HOME/Qt/6.11.1/macos
cmake --build build --parallel
```

構成時に次のログが出れば custom ビルドとして認識されています:

```
QGC: Custom build directory detected: custom
QGC: Custom overlay - ESC telemetry graphs
```

> 既存の `build/` がある状態で custom を後付けした場合は、`QGC_RESOURCES` などが
> CMake キャッシュに残るため **build ディレクトリを消してから再構成** してください。

---

## 4. upstream の更新手順

```bash
cd qgroundcontrol
git fetch --tags
git checkout v5.x.y      # 新しいタグ
rm -rf build             # CACHE INTERNAL の変数が残るため
cmake -S . -B build ...  # 再構成・再ビルド
```

`qgc-custom/` は触りません。更新後に確認すべきなのは次の 4 点だけです。

1. `src/FlyView/FlyViewCustomLayer.qml` のプロパティ契約
   (`parentToolInsets` / `totalToolInsets` / `mapControl`) が変わっていないか
2. `Vehicle::escs` と `EscStatusFactGroup` の `rpm` / `voltage` / `current` が残っているか
3. `QGCCorePlugin::createQmlApplicationEngine` / `destroyQmlApplicationEngine` の
   シグネチャが変わっていないか
4. `custom-example/CMakeLists.txt` の作法 (`CACHE INTERNAL` か `PARENT_SCOPE` か、
   `custom.qrc` 方式か `qt_add_resources` 方式か) が変わっていないか
   — master ではすでに `PARENT_SCOPE` + `qt_add_resources` 方式へ移行済みなので、
   次のメジャー更新ではここだけ追従が必要になる可能性が高い

差分確認:

```bash
git diff v5.1.3..HEAD -- src/FlyView/FlyViewCustomLayer.qml \
                          src/API/QGCCorePlugin.h \
                          src/Vehicle/FactGroups/EscStatusFactGroupListModel.h \
                          custom-example/CMakeLists.txt
```

---

## 5. UI の使い方

- Fly View 左端、ツールストリップの下にパネルが出ます
  (ESC テレメトリを送ってこない機体では **非表示** になり、素の QGC と同じ見た目です)
- ヘッダをクリックで折りたたみ / 展開 (折りたたみ中はサンプリングも停止)
- 右上の `30s` をクリックで表示時間幅を 10 / 30 / 60 / 120 秒で切り替え
- 凡例の `M1`, `M2`, … の色が各グラフの線色に対応
- 各グラフのヘッダ右側に最新値を色付きで表示

### 調整ポイント (`EscTelemetryPanel.qml`)

| プロパティ | 既定値 | 意味 |
|---|---|---|
| `sampleIntervalMs` | 200 | サンプリング周期 (ms)。5 Hz |
| `windowSecs` | 30 | 初期表示時間幅 (秒) |
| `maxEscCount` | 8 | 描画する ESC の最大数 |
| `seriesColors` | 8 色 | ESC ごとの線色 |

表示位置を右側などに変えたい場合は `src/qml/FlyViewCustomLayer.qml` の
`anchors` と、`QGCToolInsets` で申告するインセットを合わせて変更してください
(インセットを正しく申告しないと、地図が機体をパネルの下に再センタリングします)。
