# AUTD4 Design

AUTD4 のフェーズドアレイ図面とデバッグ用図面を生成する MATLAB プログラム、CAD データを管理するリポジトリ

## フォルダ構成

| フォルダ | 内容 |
| --- | --- |
| `phi-1mm/` | アレイデバイス　発音体径 φ1 mm のパターン生成プログラムと出力データ（SCR / DXF） |
| `phi-2mm/` | アレイデバイス　発音体径 φ2 mm のパターン生成プログラム、各層の CAD データ、マスクデータ（SCR / DXF） |
| `outline-rectangle/` | 発音体・駆動回路などの外形データ（SCR / DWG） |
| `phi-1mm-single-transducer/` | デバッグ用　発音体径 φ1 mm の単体発音体パターン生成プログラムと出力データ（SCR / DXF） |

## 使用環境

- MATLAB（スクリプト内のローカル関数に対応したバージョン。単体発音体版では `arguments` ブロックによる名前付き引数にも対応していること）
- AutoCAD など、出力された SCR のコマンドを実行できる CAD ソフト
- DWG / DXF の閲覧・編集には、それぞれの形式に対応した CAD ソフト

座標・寸法の基本単位は **mm**（`*_um` の設定値は **µm** で指定し、プログラム内で mm に変換）

## φ1 mm アレイ版

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
| `merge_layer_drawings.m` | 生成済みの各層に外形を追加し、レイヤー別・全層の図面を出力 | `scr-merged-trimmed/`、`dxf-merged-trimmed-r12/` |

### 実行方法

MATLAB の現在のフォルダをリポジトリ直下にして、以下を実行。

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

各プログラムは SCR を出力し、確認用の図を表示する。`merge_layer_drawings` は DXF R12 も出力する。

出力フォルダは必要に応じて作成され、同名の出力ファイルは上書きされる。

`conductive_layer_back_layer` は、発音体 SCR があれば中心と半径を照合する。整合性を確認する場合は `emitter_positions` を先に実行すること。発音体 SCR が未生成の場合は設定値から配置を計算する。

### 外形との合成

`merge_layer_drawings` は `outline-rectangle/outline_rectangle_pattern_Emitter.scr` を読み込み、外形の四隅を円弧で切り欠く。

登録された層のうち SCR が存在するものだけを合成し、未生成の層はスキップする。

| 図面 | SCR | DXF R12 |
| --- | --- | --- |
| 各層と外形 | `scr-merged-trimmed/<層名>_with_outline.scr` | `dxf-merged-trimmed-r12/<層名>_with_outline.dxf` |
| 読み込めた全層と外形 | `scr-merged-trimmed/available_layers_with_outline.scr` | `dxf-merged-trimmed-r12/available_layers_with_outline.dxf` |

全層の確認図では、凡例をクリックして各レイヤーの表示を切り替えられます。`mask_gap_resist.scr` は合成対象に含まれていないため、個別に扱います。

## φ1 mm 単体発音体版

6 mm 角の中心に φ1 mm の発音体を1個ずつ配置する。初期値は中心間ピッチ 7 mm（隙間 1 mm）で、横14列 × 縦11行の計154個。

下部電極の円穴、背面層の正方形穴、下部電極側の導電層は φ1 mm アレイ版と同じ形状。

背面側の導電層はベタ。

外形は `outline-rectangle/outline_rectangle_pattern_Emitter.scr` の外周ポリラインから読み取った外接矩形（103.8 × 76 mm）で、四隅の円形切り欠きは省略された形状。

### 実行方法

MATLAB の現在のフォルダをリポジトリ直下にして、以下を実行する。

```matlab
cd phi-1mm-single-transducer
generate_single_transducer
```

各層と外形を重ねた図面、および全層を重ねた `available_layers_with_outline` を `cad/scr/` と `cad/dxf/` に出力する。

正方形の一辺と中心間ピッチ、下部電極の円穴径とピッチ、背面層の正方形穴の一辺・ピッチ・縦横の個数は、`generate_single_transducer.m` の冒頭で変更できる。

## φ2 mm アレイ版

実行する `.m` ファイルを MATLAB で開き、パラメータと出力先を確認してから実行すること。

`emitter_positions.m` の出力先は `scr-emitter-position/emitter_positions.scr`。ほかのプログラムは、それぞれのコードに定義されたフォルダへ出力する。

## CAD での利用

1. DXF は CAD ソフトで直接開く。SCR を使う場合は新規図面を開く。
2. 図面の単位が mm であることを確認する。AutoCAD で SCR を使う場合は、`SCRIPT` コマンドで対象の `.scr` ファイルを実行する。
3. 寸法・配置・レイヤーを確認し、必要に応じて DWG / DXF 形式で保存する。

CAD 上で外形との関係や各層の位置合わせを確認すること。
