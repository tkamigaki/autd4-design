# AUTD4 Design

AUTD4 のフェーズドアレイ図面を生成する MATLAB プログラムと CAD データを管理するリポジトリ

## フォルダ構成

| フォルダ | 内容 |
| --- | --- |
| `phi-1mm/` | 発音体径 φ1 mm のパターン生成プログラムと出力データ |
| `phi-2mm/` | 発音体径 φ2 mm のパターン生成プログラム、各層の CAD データ、マスクデータ |
| `outline-rectangle/` | 発音体・駆動回路などの矩形外形データ（SCR / DWG） |

## 使用環境

- MATLAB（スクリプト内のローカル関数に対応したバージョン）
- AutoCAD など、出力された SCR のコマンドを実行できる CAD ソフト
- DWG / DXF の閲覧・編集には、それぞれの形式に対応した CAD ソフト

座標・寸法の基本単位は **mm**（`*_um` の設定値は **µm** で指定し、プログラム内で mm に変換）

## φ1 mm 版

### 主なプログラム

以下の出力先は `phi-1mm/` からの相対パス

| プログラム | 用途 | 出力先 |
| --- | --- | --- |
| `emitter_positions.m` | 六角形内に発音体を配置 | `scr-emitters/emitter_positions.scr` |
| `lower_electrode.m` | 発音体の円内に収まる下部電極の円穴を生成 | `scr-lower-electrode/lower_electrode.scr` |
| `back_layer.m` | 各発音体位置に背面層の正方形穴を生成 | `scr-back-layer/back_layer.scr` |
| `conductive_layer_lower_electrode.m` | 下部電極側の導電層を生成 | `scr-conductive-layer-lower-electrode/conductive_layer_lower_electrode.scr` |
| `conductive_layer_back_layer.m` | 背面導電層の輪郭、ビア、接着層用開口を生成 | `scr-conductive-layer-back-layer/` |
| `mask_gap_resist.m` | 発音体と同じ中心位置にレジスト用のマスク円を生成 | `scr-mask-gap-resist/mask_gap_resist.scr` |
| `merge_layer_drawings.m` | 生成済みの各層に外形を追加し、レイヤー別・全層の図面を出力 | `scr-merged/` |

### 実行方法

MATLAB の現在のフォルダをリポジトリ直下にして、次を実行します。

```matlab
cd phi-1mm

emitter_positions
lower_electrode
back_layer
conductive_layer_lower_electrode
conductive_layer_back_layer
mask_gap_resist

merge_layer_drawings
```

各プログラムは SCR を出力し、確認用の図を表示する。

出力フォルダは必要に応じて作成され、同名の出力ファイルは上書きされる。

発音体 SCR との整合性を確認するため、`conductive_layer_back_layer` は `emitter_positions` 実行後にコードを走らせること。


### 外形との合成

`merge_layer_drawings` は `outline-rectangle/outline_rectangle_pattern_Emitter.scr` を外形として読み込む。
登録された層のうち SCR が存在するものだけを合成し、未生成の層はスキップする。

- 各層と外形：`scr-merged/<層名>_with_outline.scr`
- 読み込めた全層と外形：`scr-merged/available_layers_with_outline.scr`

全層の確認図では、凡例をクリックして各レイヤーの表示を切り替えられます。`mask_gap_resist.scr` は合成対象に含まれていないため、個別に扱います。

## φ2 mm 版
実行する `.m` ファイルを MATLAB で開き、パラメータと出力先を確認してから実行すること。
`emitter_positions.m` の出力先は `scr-emitter-position/emitter_positions.scr` 。
ほかのプログラムは、それぞれのコードに定義されたフォルダへ出力する。

## CAD での利用

1. CAD ソフトで新規図面を開き、mm 単位で扱えることを確認。
2. AutoCAD の場合は `SCRIPT` コマンドで対象の `.scr` ファイルを実行。
3. 寸法・配置・レイヤーを確認し、必要に応じて DWG / DXF 形式で保存。

CAD 上で外形との関係や各層の位置合わせを確認すること。
