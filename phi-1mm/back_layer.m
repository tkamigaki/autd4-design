clear; clc; close all;

%% 穴の設定（任意の値に変更可能）
square_size_um  = 300;    % 正方形穴の一辺 [um]
square_pitch_um = 350;    % 正方形穴の中心間ピッチ [um]
square_count = [3, 3];    % 穴の個数 [横, 縦]

% 穴の縁同士の間隔 = square_pitch_um - square_size_um。
% main.m と同じく、隅の穴も正方形のまま出力する。
% 発音体の円をはみ出す部分も切り取らない。

%% 発音体の配置設定：emitter_positions.m と共通
emitter_radius = 0.5;   % 発音体半径 [mm]
emitter_gap = 0.3;      % 発音体の縁同士の最小間隔 [mm]
hex_count = [16, 10];   % 六角形の個数 [横, 縦]
tile_count = [1, 1];

% 六角形の位置・大きさを維持するための元の寸法。
reference_radius = 1;
reference_l_s = 0.15;

%% 発音体の中心座標
emitter_centers = make_emitter_centers( ...
    emitter_radius, emitter_gap, hex_count, tile_count, ...
    reference_radius, reference_l_s);

%% 発音体1個あたりの正方形穴パターン
validateattributes(square_size_um, {'numeric'}, ...
    {'scalar', 'finite', 'positive'});
validateattributes(square_pitch_um, {'numeric'}, ...
    {'scalar', 'finite', 'positive'});
validateattributes(square_count, {'numeric'}, ...
    {'vector', 'numel', 2, 'integer', 'positive'});

assert(square_pitch_um > square_size_um, ...
    '穴の中心ピッチは穴の一辺より大きくしてください。');

square_size = square_size_um / 1000;
square_pitch = square_pitch_um / 1000;

positions_x = ...
    ((1:square_count(1)) - (square_count(1)+1)/2)*square_pitch;

positions_y = ...
    ((1:square_count(2)) - (square_count(2)+1)/2)*square_pitch;

[y, x] = ndgrid(positions_y, positions_x);
hole_centers_local = [x(:), y(:)];

%% CAD出力：正方形穴のみ
output_folder = fullfile( ...
    fileparts(mfilename('fullpath')), 'scr-back-layer');

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

scr_filename = fullfile(output_folder, 'back_layer.scr');
write_square_holes( ...
    scr_filename, emitter_centers, hole_centers_local, square_size);

fprintf('正方形穴の一辺: %.3f um\n', square_size_um);
fprintf('穴の中心ピッチ: %.3f um\n', square_pitch_um);
fprintf('穴の縁間隔: %.3f um\n', square_pitch_um - square_size_um);
fprintf('発音体1個あたり: %d 穴\n', size(hole_centers_local,1));
fprintf('発音体数: %d 個\n', size(emitter_centers,1));
fprintf('全体: %d 穴\n', ...
    size(emitter_centers,1)*size(hole_centers_local,1));
fprintf('SCR出力: %s\n', scr_filename);

%% 確認図
% 全体図は発音体の中心を表示。
figure;
scatter(emitter_centers(:,1), emitter_centers(:,2), 3, 'filled');
axis equal;
xlabel('X [mm]'); ylabel('Y [mm]');
title('背面層：配置全体の発音体中心');

% 拡大図はCAD出力と同じ正方形穴を表示。
figure; hold on; axis equal;
t = linspace(0, 2*pi, 100).';

plot(emitter_radius*cos(t), emitter_radius*sin(t), 'b--');

vertices = square_size/2*[ ...
    -1, -1;
     1, -1;
     1,  1;
    -1,  1;
    -1, -1];

plot(vertices(:,1) + hole_centers_local(:,1).', ...
     vertices(:,2) + hole_centers_local(:,2).', ...
     'k-', 'LineWidth', 0.5);

xlabel('X [mm]'); ylabel('Y [mm]');
title('背面層：発音体1個の穴パターン');

%% 関数
function centers = make_emitter_centers( ...
        radius, gap, counts, tiles, reference_radius, reference_l_s)

    s = reference_radius + reference_l_s;

    % emitter_positions.m と同じV2配置。
    [iy, ix, ty, tx] = ndgrid( ...
        0:counts(2)-1, 0:counts(1)-1, ...
        0:tiles(2)-1, 0:tiles(1)-1);

    x_pitch = (3 + sqrt(3))*s;
    y_pitch = (2 + 2*sqrt(3))*s;

    x = tx + ix*x_pitch + 2*s + 2/sqrt(3)*s;
    y = ty + iy*y_pitch ...
        - ((1-mod(ix,2))*y_pitch/2 - y_pitch);

    hex_centers = [x(:), y(:)];
    hex_centers = hex_centers - mean(hex_centers,1);

    % 固定された六角形の中に発音体を三角格子で配置。
    hex_radius = 2*s + 2/sqrt(3)*reference_radius;
    apothem = hex_radius*cos(pi/6);
    pitch = 2*radius + gap;

    assert(radius > 0 && gap >= 0 && radius <= apothem, ...
        '発音体の半径・間隔を確認してください。');

    limit = ceil(2*hex_radius/pitch) + 1;
    [col, row] = ndgrid(-limit:limit);

    candidates = pitch*[ ...
        col(:) + row(:)/2, sqrt(3)/2*row(:)];

    angles = (0:5)*pi/3 + pi/6;
    normals = [cos(angles); sin(angles)];

    inside = all( ...
        candidates*normals <= apothem-radius+1e-10, 2);

    local = candidates(inside,:);
    [~, order] = sort(sum(local.^2,2));
    local = local(order,:);

    centers = repmat(local, size(hex_centers,1), 1) ...
        + repelem(hex_centers, size(local,1), 1);
end

function write_square_holes(filename, emitter_centers, local, side)
    fid = fopen(filename, 'w');
    assert(fid ~= -1, ...
        'SCRファイルを開けません: %s', filename);
    cleanup = onCleanup(@() fclose(fid));

    vertices = side/2*[ ...
        -1, -1;
         1, -1;
         1,  1;
        -1,  1];

    for i = 1:size(emitter_centers,1)
        for j = 1:size(local,1)
            xy = vertices + local(j,:) + emitter_centers(i,:);

            fprintf(fid, 'PLINE\n');
            fprintf(fid, '%.8f,%.8f\n', xy.');
            fprintf(fid, 'C\n');
        end
    end
end