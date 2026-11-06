% function create_back_layer_conductive()
% % 旧Phi2 mm版の背面導電層。
% %
% % 出力：
% %   back_layer_conductive.scr     完成輪郭＋外形
% %   comparison_detail.png         左上の拡大比較
% %   comparison_full.png           全体比較
% %
% % 元DWGを読み込まずに、円弧と線分から輪郭を計算する。
% % ビアの円そのものは完成輪郭に含めず、確認図に表示する。

% %% ========================================================
% %  パラメータ（単位 mm）
% % =========================================================

% % 元の発音体配置
% emitter_radius = 1;
% spacing_parameter = 0.15;
% hex_count = [16, 10];         % [横, 縦]

% % 導電層の円弧半径
% % 旧コード：直径 = 0.85*2 + 0.15 = 1.85 mm
% conductive_radius = 0.925;

% % ビア配置：旧コードと同じ値
% via_diameter = 0.30;
% via_base = [-38.093, 28.27675];
% via_count = [8, 10];
% via_pitch = [10.88, -6.28];
% via_second_shift = [-5.4418, 3.1419];
% via_pair_offset = 0.195;

% % 外形をSCR・全体図に含める
% include_outline = true;

% % 表示用。SCRは近似多角形ではなく、正確なLINE/ARCで出力する。
% circle_plot_points = 160;

% %% ========================================================
% %  元コードと同じ円・六角形中心を生成
% % =========================================================

% s = emitter_radius + spacing_parameter;

% x_pitch = 3*s + 3/sqrt(3)*s;
% y_pitch = 2*s + 2*sqrt(3)*s;
% ring_radius = 2*s;

% [iy, ix] = ndgrid(0:hex_count(2)-1, 0:hex_count(1)-1);

% x = ix*x_pitch + 2*s + 2/sqrt(3)*s;
% y_shift = mod(ix, 2)*y_pitch/2 - y_pitch;
% y = iy*y_pitch - y_shift;

% hex_centers = [x(:), y(:)];

% % 元の7円配置は各六角形中心について対称なので、
% % 六角形中心の平均で原点移動しても同じ座標になる。
% hex_centers = hex_centers - mean(hex_centers, 1);

% angles = (0:5)'*pi/3;
% ring_offsets = ring_radius*[cos(angles), sin(angles)];
% local_circle_centers = [0, 0; ring_offsets];

% circle_centers = ...
%     repmat(local_circle_centers, size(hex_centers,1), 1) ...
%     + repelem(hex_centers, 7, 1);

% % 元のSCR出力と同じ丸め。
% circle_centers = unique(round(circle_centers, 6), 'rows');

% %% ========================================================
% %  ビア中心と、ビア2個をまとめたセル中心
% % =========================================================

% [jy, jx] = ndgrid(0:via_count(2)-1, 0:via_count(1)-1);

% cells_first = via_base + ...
%     [jx(:)*via_pitch(1), jy(:)*via_pitch(2)];

% cells_second = cells_first + via_second_shift;
% via_cell_centers = [cells_first; cells_second];

% % 第1配列：右上・左下
% % 第2配列：左上・右下
% d = via_pair_offset;

% via_centers = [
%     cells_first  + [ d,  d]
%     cells_first  + [-d, -d]
%     cells_second + [-d,  d]
%     cells_second + [ d, -d]
% ];

% via_centers = unique(round(via_centers, 6), 'rows');

% %% ========================================================
% %  完成輪郭を生成
% %
% %  lines : [始点X, 始点Y, 終点X, 終点Y]
% %  arcs  : [中心X, 中心Y, 半径, 開始角, 終了角]
% %
% %  円弧の方向は反時計回り。角度の単位はrad。
% % =========================================================

% pattern_lines = zeros(0, 4);
% pattern_arcs = zeros(0, 5);

% % 各六角形に対応するビアセルは重複なく選ばれているか確認する。
% assigned_cells = zeros(size(hex_centers,1), 1);

% for i = 1:size(hex_centers,1)
%     center = hex_centers(i,:);

%     % ビアセルは六角形中心の左上付近にある。
%     % これは対応関係の選択だけに使用し、座標の補正には使わない。
%     expected_cell = center + [-x_pitch/2, y_pitch/4];

%     distance_squared = sum( ...
%         (via_cell_centers - expected_cell).^2, 2);

%     [distance_squared_min, cell_index] = min(distance_squared);
%     assert(sqrt(distance_squared_min) < 0.1, ...
%         '対応するビアセルが見つかりません。');

%     assigned_cells(i) = cell_index;
%     via_cell = via_cell_centers(cell_index,:);

%     [local_lines, local_arcs] = make_contour( ...
%         center, via_cell, ring_radius, conductive_radius, ...
%         via_pair_offset, via_diameter/2);

%     pattern_lines = [pattern_lines; local_lines]; %#ok<AGROW>
%     pattern_arcs = [pattern_arcs; local_arcs]; %#ok<AGROW>
% end

% assert(numel(unique(assigned_cells)) == size(hex_centers,1), ...
%     'ビアセルと六角形の対応に重複があります。');

% %% ========================================================
% %  外形
% % =========================================================

% outline_lines = zeros(0, 4);
% outline_arcs = zeros(0, 5);

% if include_outline
%     [outline_lines, outline_arcs] = make_outline();
% end

% all_lines = [pattern_lines; outline_lines];
% all_arcs = [pattern_arcs; outline_arcs];

% %% ========================================================
% %  SCR出力
% % =========================================================

% output_folder = fullfile( ...
%     fileparts(mfilename('fullpath')), ...
%     'scr-back-layer-conductive-recreated');

% if ~exist(output_folder, 'dir')
%     mkdir(output_folder);
% end

% scr_filename = fullfile( ...
%     output_folder, 'back_layer_conductive.scr');

% write_scr(scr_filename, all_lines, all_arcs);

% fprintf('六角形の組数: %d\n', size(hex_centers,1));
% fprintf('円弧の半径: %.3f mm\n', conductive_radius);
% fprintf('比較用の円: %d 個\n', size(circle_centers,1));
% fprintf('比較用のビア: %d 個\n', size(via_centers,1));
% fprintf('SCR出力: %s\n', scr_filename);

% %% ========================================================
% %  拡大比較：左上の六角形
% % =========================================================

% detail_center = hex_centers(hex_count(2), :);

% detail_limits = [
%     detail_center(1)-3.65, detail_center(1)+3.65
%     detail_center(2)-3.25, detail_center(2)+3.25
% ];

% fig_detail = figure( ...
%     'Name', '左上の輪郭と重ね合わせ', 'Color', 'w');

% layout = tiledlayout(fig_detail, 1, 2, ...
%     'TileSpacing', 'compact', 'Padding', 'compact');

% ax1 = nexttile(layout);
% draw_contour(ax1, pattern_lines, pattern_arcs);
% format_axes(ax1, '完成輪郭');
% xlim(ax1, detail_limits(1,:));
% ylim(ax1, detail_limits(2,:));

% ax2 = nexttile(layout);
% draw_reference_circles(ax2, circle_centers, ...
%     conductive_radius, via_centers, via_diameter/2, ...
%     circle_plot_points);
% draw_contour(ax2, pattern_lines, pattern_arcs);
% format_axes(ax2, '元の円との重ね合わせ');
% xlim(ax2, detail_limits(1,:));
% ylim(ax2, detail_limits(2,:));
% add_overlay_legend(ax2);

% exportgraphics(fig_detail, ...
%     fullfile(output_folder, 'comparison_detail.png'), ...
%     'Resolution', 200);

% %% ========================================================
% %  全体比較
% % =========================================================

% fig_full = figure( ...
%     'Name', '全体の輪郭と重ね合わせ', 'Color', 'w');

% layout = tiledlayout(fig_full, 1, 2, ...
%     'TileSpacing', 'compact', 'Padding', 'compact');

% ax1 = nexttile(layout);
% draw_contour(ax1, all_lines, all_arcs);
% format_axes(ax1, '完成輪郭：全体');

% ax2 = nexttile(layout);
% draw_reference_circles(ax2, circle_centers, ...
%     conductive_radius, via_centers, via_diameter/2, ...
%     circle_plot_points);
% draw_contour(ax2, all_lines, all_arcs);
% format_axes(ax2, '重ね合わせ：全体');
% add_overlay_legend(ax2);

% % 同じ表示範囲にそろえる。
% linkaxes([ax1, ax2], 'xy');

% exportgraphics(fig_full, ...
%     fullfile(output_folder, 'comparison_full.png'), ...
%     'Resolution', 200);

% fprintf('確認画像も同じフォルダに保存しました。\n');
% end


% %% ========================================================
% %  六角形1組の輪郭
% % =========================================================
% function [lines, arcs] = make_contour( ...
%         center, via_cell, ring_radius, r, pair_offset, via_radius)

% % 上下4円の中心
% a = ring_radius/2;
% h = sqrt(3)*ring_radius/2;

% % 上下の角丸部分につながる左右の縦線位置
% x_left = -a-r;
% x_right = a+r;

% % 左右の円と、その縦線が交わる高さ
% intersection_y = sqrt(r^2 - (x_right-ring_radius)^2);

% % 左上の張り出し：ビア2個の外接矩形の左端・上端。
% % 元のビア配列には丸められたピッチが使われているため、
% % 張り出しの寸法は組ごとにわずかに異なる。
% tab_left = via_cell(1)-pair_offset-via_radius-center(1);
% tab_top = via_cell(2)+pair_offset+via_radius-center(2);

% % 張り出し左辺と、左側の円との交点
% tab_relative_x = tab_left + ring_radius;

% assert(abs(tab_relative_x) < r, ...
%     '張り出しの左辺が左側の円と交わりません。');

% tab_intersection_y = sqrt(r^2 - tab_relative_x^2);

% assert(tab_left < x_left, ...
%     '張り出しの位置が不正です。');
% assert(tab_top > tab_intersection_y && tab_top <= h, ...
%     '張り出しの高さが想定範囲外です。');

% % 8本の接続線
% lines = [
%     x_left,  h,                   x_left,  tab_top
%     x_left,  tab_top,             tab_left, tab_top
%     tab_left, tab_top,            tab_left, tab_intersection_y
%     x_left, -intersection_y,      x_left, -h
%     -a,     -h-r,                 a,      -h-r
%     x_right,-h,                   x_right,-intersection_y
%     x_right, intersection_y,      x_right, h
%      a,      h+r,                -a,       h+r
% ];

% % 6個の外周円から残す円弧
% arcs = [
%      a, h, r, 0,      pi/2
%     -a, h, r, pi/2,   pi
%     -a,-h, r, pi,     3*pi/2
%      a,-h, r, 3*pi/2, 2*pi

%      ring_radius, 0, r, ...
%         atan2(-intersection_y, x_right-ring_radius), ...
%         atan2( intersection_y, x_right-ring_radius)

%     -ring_radius, 0, r, ...
%         atan2(tab_intersection_y, tab_relative_x), ...
%         atan2(-intersection_y, x_left+ring_radius)
% ];

% % 局所座標から全体座標へ変換
% lines = lines + [center, center];
% arcs(:,1:2) = arcs(:,1:2) + center;
% end


% %% ========================================================
% %  旧DWGの外形
% % =========================================================
% function [lines, arcs] = make_outline()

% lines = [
%     -49.4, -36.45, -49.4,  36.45
%     -47.85, 38,     52.85, 38

%      54.4,  36.45,  54.4,  28
%      54.4,  28,     51.4,  28
%      51.4,  28,     51.4, -28
%      51.4, -28,     54.4, -28
%      54.4, -28,     54.4, -36.45

%      52.85,-38,    -47.85,-38
% ];

% % 外形四隅の内向き円弧
% arcs = [
%     -49.4,  38, 1.55, 3*pi/2, 2*pi
%      54.4,  38, 1.55, pi,     3*pi/2
%      54.4, -38, 1.55, pi/2,   pi
%     -49.4, -38, 1.55, 0,      pi/2
% ];
% end


% %% ========================================================
% %  SCR出力
% % =========================================================
% function write_scr(filename, lines, arcs)

% fid = fopen(filename, 'w');
% assert(fid ~= -1, ...
%     'SCRファイルを開けません: %s', filename);
% cleanup = onCleanup(@() fclose(fid));

% % 元の座標をそのまま使用する。
% fprintf(fid, '_UCS\n_World\n_OSMODE\n0\n');

% for i = 1:size(lines,1)
%     fprintf(fid, ...
%         '_LINE\n%.12f,%.12f\n%.12f,%.12f\n\n', ...
%         lines(i,:));
% end

% for i = 1:size(arcs,1)
%     c = arcs(i,1:2);
%     r = arcs(i,3);
%     t1 = arcs(i,4);
%     t2 = arcs(i,5);

%     p = c + r*[cos(t1), sin(t1)];
%     q = c + r*[cos(t2), sin(t2)];

%     fprintf(fid, ...
%         '_ARC\n_Center\n%.12f,%.12f\n%.12f,%.12f\n%.12f,%.12f\n', ...
%         [c, p, q]);
% end

% fprintf(fid, '_ZOOM\n_Extents\n');
% end


% %% ========================================================
% %  完成輪郭の描画
% % =========================================================
% function draw_contour(ax, lines, arcs)

% hold(ax, 'on');

% if ~isempty(lines)
%     plot(ax, ...
%         [lines(:,1), lines(:,3)].', ...
%         [lines(:,2), lines(:,4)].', ...
%         'k-', 'LineWidth', 1);
% end

% % 円弧をNaNで区切り、まとめて描画。
% parts = cell(size(arcs,1), 1);

% for i = 1:size(arcs,1)
%     sweep = mod(arcs(i,5)-arcs(i,4), 2*pi);
%     t = linspace(arcs(i,4), arcs(i,4)+sweep, 120).';

%     xy = arcs(i,1:2) ...
%         + arcs(i,3)*[cos(t), sin(t)];

%     parts{i} = [xy; NaN, NaN];
% end

% if ~isempty(parts)
%     xy = vertcat(parts{:});
%     plot(ax, xy(:,1), xy(:,2), ...
%         'k-', 'LineWidth', 1);
% end
% end


% %% ========================================================
% %  元コードの円を重ねる
% % =========================================================
% function draw_reference_circles( ...
%         ax, centers, radius, via_centers, via_radius, n)

% hold(ax, 'on');
% t = linspace(0, 2*pi, n).';

% plot(ax, ...
%     centers(:,1).' + radius*cos(t), ...
%     centers(:,2).' + radius*sin(t), ...
%     '--', 'Color', [0.09, 0.51, 0.85], ...
%     'LineWidth', 0.8);

% plot(ax, ...
%     via_centers(:,1).' + via_radius*cos(t), ...
%     via_centers(:,2).' + via_radius*sin(t), ...
%     '--', 'Color', [0.88, 0.53, 0.04], ...
%     'LineWidth', 0.8);
% end


% %% ========================================================
% %  表示設定
% % =========================================================
% function format_axes(ax, caption)

% axis(ax, 'equal');
% grid(ax, 'on');
% box(ax, 'on');

% xlabel(ax, 'X [mm]');
% ylabel(ax, 'Y [mm]');
% title(ax, caption);
% end

% function add_overlay_legend(ax)

% h1 = plot(ax, NaN, NaN, '--', ...
%     'Color', [0.09, 0.51, 0.85], 'LineWidth', 1);

% h2 = plot(ax, NaN, NaN, '--', ...
%     'Color', [0.88, 0.53, 0.04], 'LineWidth', 1);

% h3 = plot(ax, NaN, NaN, 'k-', 'LineWidth', 1);

% legend(ax, [h1,h2,h3], ...
%     {'元の直径1.85 mm円', '元のビア穴', '完成輪郭'}, ...
%     'Location', 'best');
% end

function create_back_layer_conductive()
% 旧Phi2 mm配置の背面導電層。
%
% ビア位置は六角形中心と配置ピッチから計算する。
% 固定の基準座標・配列ピッチ・シフトは使用しない。
%
% 出力：
%   back_layer_conductive.scr  完成輪郭＋外形
%   substrate_via.scr          ビア穴
%   adhesive_via_openings.scr  接着層用開口
%   comparison_detail.png     左上の拡大比較
%   comparison_full.png       全体比較
%
% 単位：mm

%% ========================================================
%  設定
% =========================================================

% 発音体・六角形の配置
emitter_radius = 1;
spacing_parameter = 0.15;
hex_count = [16, 10];          % [横, 縦]

% 導電層輪郭に使用する円弧の半径
conductive_radius = 0.925;

% ビア穴と接着層用開口の寸法
via_diameter = 0.30;
adhesive_diameter = 0.60;

% ビアペアを配置する内側四角形の寸法
reference_square_size = 1.29;
square_inset = 0.15;

% V2と同様、ビアだけをペアの外側へ移動する距離
% 0     : 元の位置
% 0.025 : ペアの中心間距離が0.05 mm広がる
via_outward_shift = 0;

% 外形を完成輪郭に含める
include_outline = true;

% 確認図での円の分割数（CAD出力は正確な円・円弧）
plot_points = 160;

%% ========================================================
%  寸法確認
% =========================================================

validateattributes(emitter_radius, {'numeric'}, ...
    {'scalar','finite','positive'});
validateattributes(spacing_parameter, {'numeric'}, ...
    {'scalar','finite','nonnegative'});
validateattributes(hex_count, {'numeric'}, ...
    {'vector','numel',2,'integer','positive'});
validateattributes(conductive_radius, {'numeric'}, ...
    {'scalar','finite','positive'});
validateattributes(via_diameter, {'numeric'}, ...
    {'scalar','finite','positive'});
validateattributes(adhesive_diameter, {'numeric'}, ...
    {'scalar','finite','positive'});
validateattributes(reference_square_size, {'numeric'}, ...
    {'scalar','finite','positive'});
validateattributes(square_inset, {'numeric'}, ...
    {'scalar','finite','nonnegative'});
validateattributes(via_outward_shift, {'numeric'}, ...
    {'scalar','finite','nonnegative'});

via_radius = via_diameter/2;
adhesive_radius = adhesive_diameter/2;

%% ========================================================
%  六角形と発音体の中心
% =========================================================

s = emitter_radius + spacing_parameter;

x_pitch = (3 + sqrt(3))*s;
y_pitch = (2 + 2*sqrt(3))*s;
ring_radius = 2*s;

[iy, ix] = ndgrid( ...
    0:hex_count(2)-1, ...
    0:hex_count(1)-1);

% 元のCAD_BackLayerConductiveLayer.mと同じ列のずらし方
x = ix*x_pitch + 2*s + 2/sqrt(3)*s;
y = iy*y_pitch ...
    - (mod(ix,2)*y_pitch/2 - y_pitch);

hex_centers = [x(:), y(:)];
hex_centers = hex_centers - mean(hex_centers,1);

angles = (0:5)'*pi/3;

local_circles = [
    0, 0
    ring_radius*cos(angles), ring_radius*sin(angles)
];

circle_centers = ...
    repmat(local_circles, size(hex_centers,1), 1) ...
    + repelem(hex_centers, 7, 1);

%% ========================================================
%  ビア位置を数式で生成
% =========================================================

% 各ビアペアの中点
via_cell_centers = hex_centers ...
    + [-x_pitch/2, y_pitch/4];

% 内側四角形
inner_square_size = reference_square_size - 2*square_inset;

% 接着層用開口が内側四角形の2辺に接する配置
pair_axis_offset = inner_square_size/2 - adhesive_radius;

assert(pair_axis_offset > 0, ...
    '内側四角形と接着層用開口の寸法を確認してください。');

% 列番号は0始まり。
% 偶数列：左上・右下
% 奇数列：右上・左下
pair_direction = [
    2*mod(ix(:),2)-1, ones(numel(ix),1)
];

% 接着層用開口の中心
adhesive_offset = pair_axis_offset*pair_direction;

adhesive_centers = [
    via_cell_centers + adhesive_offset
    via_cell_centers - adhesive_offset
];

% ビア穴の中心
% directionの長さはsqrt(2)なので、移動距離をsqrt(2)で割る。
via_offset = adhesive_offset ...
    + via_outward_shift/sqrt(2)*pair_direction;

via_centers = [
    via_cell_centers + via_offset
    via_cell_centers - via_offset
];

%% ========================================================
%  導電層輪郭
% =========================================================

pattern_lines = zeros(0,4);
pattern_arcs = zeros(0,5);

n_hex = size(hex_centers,1);

for i = 1:n_hex
    % この六角形に対応する実際のビア2個
    pair_centers = via_centers([i, i+n_hex], :);

    % ビア2個を囲む張り出しの左端・上端
    tab_left = min(pair_centers(:,1)) - via_radius;
    tab_top = max(pair_centers(:,2)) + via_radius;

    [lines, arcs] = make_contour( ...
        hex_centers(i,:), ring_radius, ...
        conductive_radius, tab_left, tab_top);

    pattern_lines = [pattern_lines; lines]; %#ok<AGROW>
    pattern_arcs = [pattern_arcs; arcs]; %#ok<AGROW>
end

all_lines = pattern_lines;
all_arcs = pattern_arcs;

if include_outline
    [outline_lines, outline_arcs] = make_outline();
    all_lines = [all_lines; outline_lines];
    all_arcs = [all_arcs; outline_arcs];
end

%% ========================================================
%  CAD出力
% =========================================================

output_folder = fullfile( ...
    fileparts(mfilename('fullpath')), ...
    'scr-back-layer-conductive-formula');

if ~exist(output_folder,'dir')
    mkdir(output_folder);
end

write_contour_scr( ...
    fullfile(output_folder,'back_layer_conductive.scr'), ...
    all_lines, all_arcs);

write_circles_scr( ...
    fullfile(output_folder,'substrate_via.scr'), ...
    via_centers, via_radius);

write_circles_scr( ...
    fullfile(output_folder,'adhesive_via_openings.scr'), ...
    adhesive_centers, adhesive_radius);

fprintf('六角形: %d 組\n', n_hex);
fprintf('ビア穴: %d 個、直径 %.3f mm\n', ...
    size(via_centers,1), via_diameter);
fprintf('接着層用開口: %d 個、直径 %.3f mm\n', ...
    size(adhesive_centers,1), adhesive_diameter);
fprintf('ビアの外向き移動量: %.3f mm\n', via_outward_shift);
fprintf('出力先: %s\n', output_folder);

%% ========================================================
%  左上の拡大比較
% =========================================================

detail_center = hex_centers(hex_count(2),:);

detail_limits = [
    detail_center(1)-3.65, detail_center(1)+3.65
    detail_center(2)-3.25, detail_center(2)+3.25
];

fig = figure( ...
    'Name','左上の輪郭と重ね合わせ', ...
    'Color','w');

layout = tiledlayout(fig,1,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

ax1 = nexttile(layout);
draw_contour(ax1,pattern_lines,pattern_arcs);
format_axes(ax1,'完成輪郭');

ax2 = nexttile(layout);
draw_reference(ax2, ...
    circle_centers,conductive_radius, ...
    via_centers,via_radius,plot_points);
draw_contour(ax2,pattern_lines,pattern_arcs);
format_axes(ax2,'元の円との重ね合わせ');
add_legend(ax2);

linkaxes([ax1,ax2],'xy');
xlim(ax1,detail_limits(1,:));
ylim(ax1,detail_limits(2,:));

exportgraphics(fig, ...
    fullfile(output_folder,'comparison_detail.png'), ...
    'Resolution',200);

%% ========================================================
%  全体比較
% =========================================================

fig = figure( ...
    'Name','全体の輪郭と重ね合わせ', ...
    'Color','w');

layout = tiledlayout(fig,1,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

ax1 = nexttile(layout);
draw_contour(ax1,all_lines,all_arcs);
format_axes(ax1,'完成輪郭：全体');

ax2 = nexttile(layout);
draw_reference(ax2, ...
    circle_centers,conductive_radius, ...
    via_centers,via_radius,plot_points);
draw_contour(ax2,all_lines,all_arcs);
format_axes(ax2,'重ね合わせ：全体');
add_legend(ax2);

linkaxes([ax1,ax2],'xy');

% 全図形を確実に表示するため、幾何形状から表示範囲を計算。
xy = contour_points(all_lines,all_arcs);
minimum = min(xy,[],1);
maximum = max(xy,[],1);
margin = 2;

xlim(ax1,[minimum(1)-margin, maximum(1)+margin]);
ylim(ax1,[minimum(2)-margin, maximum(2)+margin]);

exportgraphics(fig, ...
    fullfile(output_folder,'comparison_full.png'), ...
    'Resolution',200);
end


%% ========================================================
%  六角形1組の輪郭
% =========================================================
function [lines,arcs] = make_contour( ...
        center,ring_radius,r,tab_left_global,tab_top_global)

a = ring_radius/2;
h = sqrt(3)*ring_radius/2;

x_left = -a-r;
x_right = a+r;

assert(r > abs(x_right-ring_radius), ...
    '左右の円と接続線が交わりません。');

intersection_y = sqrt( ...
    r^2 - (x_right-ring_radius)^2);

% 張り出しを六角形中心からの局所座標に変換
tab_left = tab_left_global-center(1);
tab_top = tab_top_global-center(2);

relative_x = tab_left+ring_radius;

assert(abs(relative_x) < r, ...
    '張り出し左辺が外周円と交わりません。');

tab_intersection_y = sqrt(r^2-relative_x^2);

assert(tab_left < x_left, ...
    '張り出しの横位置が想定範囲外です。');
assert(tab_top > tab_intersection_y && tab_top <= h, ...
    '張り出しの高さが想定範囲外です。');

lines = [
    x_left,   h,                  x_left,   tab_top
    x_left,   tab_top,             tab_left, tab_top
    tab_left, tab_top,             tab_left, tab_intersection_y

    x_left,  -intersection_y,      x_left,  -h
    -a,      -h-r,                 a,       -h-r

    x_right, -h,                  x_right, -intersection_y
    x_right,  intersection_y,     x_right,  h

     a,       h+r,                -a,        h+r
];

arcs = [
     a, h, r, 0,      pi/2
    -a, h, r, pi/2,   pi
    -a,-h, r, pi,     3*pi/2
     a,-h, r, 3*pi/2, 2*pi

     ring_radius,0,r, ...
        atan2(-intersection_y,x_right-ring_radius), ...
        atan2( intersection_y,x_right-ring_radius)

    -ring_radius,0,r, ...
        atan2(tab_intersection_y,relative_x), ...
        atan2(-intersection_y,x_left+ring_radius)
];

lines = lines+[center,center];
arcs(:,1:2) = arcs(:,1:2)+center;
end


%% ========================================================
%  旧図面の外形
% =========================================================
function [lines,arcs] = make_outline()

lines = [
    -49.4, -36.45, -49.4,  36.45
    -47.85, 38,     52.85, 38

     54.4,  36.45,  54.4,  28
     54.4,  28,     51.4,  28
     51.4,  28,     51.4, -28
     51.4, -28,     54.4, -28
     54.4, -28,     54.4, -36.45

     52.85,-38,    -47.85,-38
];

arcs = [
    -49.4, 38,1.55,3*pi/2,2*pi
     54.4, 38,1.55,pi,3*pi/2
     54.4,-38,1.55,pi/2,pi
    -49.4,-38,1.55,0,pi/2
];
end


%% ========================================================
%  輪郭のSCR出力
% =========================================================
function write_contour_scr(filename,lines,arcs)

fid = fopen(filename,'w');
assert(fid ~= -1, ...
    'SCRファイルを開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));

fprintf(fid,'_UCS\n_World\n_OSMODE\n0\n');

for i = 1:size(lines,1)
    fprintf(fid, ...
        '_LINE\n%.12f,%.12f\n%.12f,%.12f\n\n', ...
        lines(i,:));
end

for i = 1:size(arcs,1)
    c = arcs(i,1:2);
    r = arcs(i,3);

    p = c+r*[cos(arcs(i,4)),sin(arcs(i,4))];
    q = c+r*[cos(arcs(i,5)),sin(arcs(i,5))];

    fprintf(fid, ...
        '_ARC\n_Center\n%.12f,%.12f\n%.12f,%.12f\n%.12f,%.12f\n', ...
        [c,p,q]);
end

fprintf(fid,'_ZOOM\n_Extents\n');
end


%% ========================================================
%  円のSCR出力
% =========================================================
function write_circles_scr(filename,centers,radius)

fid = fopen(filename,'w');
assert(fid ~= -1, ...
    'SCRファイルを開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));

fprintf(fid,'_UCS\n_World\n_OSMODE\n0\n');

fprintf(fid,'_CIRCLE\n%.12f,%.12f\n%.12f\n', ...
    [centers,repmat(radius,size(centers,1),1)].');

fprintf(fid,'_ZOOM\n_Extents\n');
end


%% ========================================================
%  輪郭の表示用座標
% =========================================================
function xy = contour_points(lines,arcs)

parts = cell(size(arcs,1)+1,1);

parts{1} = reshape( ...
    [lines(:,1:2),lines(:,3:4)].',2,[]).';

for i = 1:size(arcs,1)
    sweep = mod(arcs(i,5)-arcs(i,4),2*pi);

    t = linspace( ...
        arcs(i,4),arcs(i,4)+sweep,120).';

    parts{i+1} = arcs(i,1:2) ...
        + arcs(i,3)*[cos(t),sin(t)];
end

xy = vertcat(parts{:});
end


%% ========================================================
%  完成輪郭の描画
% =========================================================
function draw_contour(ax,lines,arcs)

hold(ax,'on');

if ~isempty(lines)
    plot(ax, ...
        [lines(:,1),lines(:,3)].', ...
        [lines(:,2),lines(:,4)].', ...
        'k-','LineWidth',1);
end

parts = cell(size(arcs,1),1);

for i = 1:size(arcs,1)
    sweep = mod(arcs(i,5)-arcs(i,4),2*pi);

    t = linspace( ...
        arcs(i,4),arcs(i,4)+sweep,120).';

    p = arcs(i,1:2) ...
        + arcs(i,3)*[cos(t),sin(t)];

    parts{i} = [p;NaN,NaN];
end

if ~isempty(parts)
    xy = vertcat(parts{:});

    plot(ax,xy(:,1),xy(:,2), ...
        'k-','LineWidth',1);
end
end


%% ========================================================
%  元の円とビアの描画
% =========================================================
function draw_reference( ...
        ax,centers,radius,via_centers,via_radius,n)

hold(ax,'on');
t = linspace(0,2*pi,n).';

plot(ax, ...
    centers(:,1).'+radius*cos(t), ...
    centers(:,2).'+radius*sin(t), ...
    '--','Color',[0.09,0.51,0.85], ...
    'LineWidth',0.8);

plot(ax, ...
    via_centers(:,1).'+via_radius*cos(t), ...
    via_centers(:,2).'+via_radius*sin(t), ...
    '--','Color',[0.88,0.53,0.04], ...
    'LineWidth',0.8);
end


%% ========================================================
%  表示設定
% =========================================================
function format_axes(ax,caption)

axis(ax,'equal');
grid(ax,'on');
box(ax,'on');

xlabel(ax,'X [mm]');
ylabel(ax,'Y [mm]');
title(ax,caption);
end

function add_legend(ax)

h1 = plot(ax,NaN,NaN,'--', ...
    'Color',[0.09,0.51,0.85],'LineWidth',1);

h2 = plot(ax,NaN,NaN,'--', ...
    'Color',[0.88,0.53,0.04],'LineWidth',1);

h3 = plot(ax,NaN,NaN,'k-','LineWidth',1);

legend(ax,[h1,h2,h3], ...
    {'元の直径1.85 mm円','ビア穴','完成輪郭'}, ...
    'Location','best');
end