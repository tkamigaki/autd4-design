clear; clc; close all;

% === 設定（単位 mm） ===
% 中心座標の計算条件は emitter_positions.m と同じにする。
emitter_radius = 0.5;
emitter_gap = 0.3;             % 発音体の縁同士の最小間隔
mask_diameter_margin = 0.1;    % 発音体直径に加えるマスク余裕
mask_radius = emitter_radius + mask_diameter_margin/2;

hex_count = [16, 10];          % 六角形の個数 [横, 縦]
tile_count = [1, 1];
reference_radius = 1;
reference_l_s = 0.15;

% === 元の六角形寸法と中心配置を維持 ===
s = reference_radius + reference_l_s;
hex_radii = [ ...
    2*s + 2/sqrt(3)*reference_radius, ...
    2*s + 2/sqrt(3)*s ...
];                            % 内側・外側六角形の中心〜頂点

hex_centers = make_hex_centers(s, hex_count, tile_count);

% マスク半径ではなく、発音体半径で配置を決める。
local_centers = pack_hexagon( ...
    hex_radii(1), emitter_radius, emitter_gap);

count_per_hex = size(local_centers, 1);
circle_centers = repmat(local_centers, size(hex_centers, 1), 1) ...
    + repelem(hex_centers, count_per_hex, 1);

% === CAD出力：中心はそのまま、円だけ直径1.1 mmに拡大 ===
output_folder = fullfile( ...
    fileparts(mfilename('fullpath')), 'scr-mask-gap-resist');

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

scr_filename = fullfile(output_folder, 'mask_gap_resist.scr');
write_scr(scr_filename, circle_centers, mask_radius);

fprintf('%d 個/六角形 × %d 六角形 = %d 個\n', ...
    count_per_hex, size(hex_centers, 1), size(circle_centers, 1));
fprintf('発音体直径: %.3f mm\n', 2*emitter_radius);
fprintf('マスク円直径: %.3f mm\n', 2*mask_radius);
fprintf('最隣接の中心間隔: %.3f mm\n', ...
    2*emitter_radius + emitter_gap);
fprintf('マスク円の最小縁間隔: %.3f mm\n', ...
    emitter_gap - mask_diameter_margin);
fprintf('SCR出力: %s\n', scr_filename);

% === 確認図：CAD出力と同じマスク円を表示 ===
draw_layout(circle_centers, hex_centers, mask_radius, ...
    hex_radii, 'マスク円の全体配置（直径1.1 mm）');

draw_layout(local_centers, [0, 0], mask_radius, hex_radii, ...
    sprintf('六角形1個：%d 個（赤点は固定中心）', count_per_hex));

plot(0, 0, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 4);


% === 六角形中心の生成 ===
function centers = make_hex_centers(s, counts, tiles)
    % 元の emitter_positions.m と同じ配置順・V2のずらし方。
    [iy, ix, ty, tx] = ndgrid( ...
        0:counts(2)-1, 0:counts(1)-1, ...
        0:tiles(2)-1, 0:tiles(1)-1);

    x_pitch = (3 + sqrt(3))*s;
    y_pitch = (2 + 2*sqrt(3))*s;

    x = tx + ix*x_pitch + 2*s + 2/sqrt(3)*s;
    y = ty + iy*y_pitch ...
        - ((1-mod(ix, 2))*y_pitch/2 - y_pitch);

    centers = [x(:), y(:)];
    centers = centers - mean(centers, 1);
end


% === 六角形内の三角格子配置 ===
function centers = pack_hexagon(hex_radius, radius, gap)
    assert(isscalar(radius) && isfinite(radius) && radius > 0 ...
        && isscalar(gap) && isfinite(gap) && gap >= 0, ...
        '半径は正、隙間は0以上の有限値にしてください。');

    pitch = 2*radius + gap;
    apothem = hex_radius*cos(pi/6);

    assert(radius <= apothem, ...
        '中央の発音体が六角形に収まりません。');

    limit = ceil(2*hex_radius/pitch) + 1;
    [col, row] = ndgrid(-limit:limit);

    candidates = pitch*[ ...
        col(:) + row(:)/2, ...
        sqrt(3)/2*row(:) ...
    ];

    angles = (0:5)*pi/3 + pi/6;
    normals = [cos(angles); sin(angles)];

    % 発音体の円全体が内側六角形に収まる中心だけを採用。
    inside = all( ...
        candidates*normals <= apothem-radius+1e-10, 2);

    centers = candidates(inside, :);

    % 中央、内周、外周の順に整列。
    [~, order] = sort(sum(centers.^2, 2));
    centers = centers(order, :);
end


% === SCRファイル出力 ===
function write_scr(filename, centers, radius)
    fid = fopen(filename, 'w');
    assert(fid ~= -1, ...
        'SCRファイルを開けません: %s', filename);

    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, 'circle %.8f,%.8f %.8f\n', ...
        [centers, repmat(radius, size(centers, 1), 1)].');
end


% === 配置図の描画 ===
function draw_layout(centers, hex_centers, radius, ...
        hex_radii, caption)

    figure; hold on; axis equal;

    t = linspace(0, 2*pi, 100).';

    plot(centers(:, 1).' + radius*cos(t), ...
        centers(:, 2).' + radius*sin(t), ...
        'k-', 'LineWidth', 0.5);

    angles = (0:6).'*pi/3;
    styles = {'b-', 'b:'};

    for i = 1:numel(hex_radii)
        plot( ...
            hex_centers(:, 1).' + hex_radii(i)*cos(angles), ...
            hex_centers(:, 2).' + hex_radii(i)*sin(angles), ...
            styles{i}, 'LineWidth', 0.5);
    end

    title(caption);
    xlabel('X [mm]');
    ylabel('Y [mm]');
end