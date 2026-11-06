clear; clc; close all;

%% 穴の設定（任意の値に変更可能）
hole_radius_um = 35;    % 円穴の半径 [um]
hole_pitch_um  = 90;    % 円穴の中心間ピッチ [um]

% 円穴全体が発音体の円内に収まるものだけを採用する。
% main.m の selectedMode = "fully_inside" と同じ条件。

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

%% 発音体1個あたりの円穴パターン
validateattributes(hole_radius_um, {'numeric'}, ...
    {'scalar', 'finite', 'positive'});
validateattributes(hole_pitch_um, {'numeric'}, ...
    {'scalar', 'finite', 'positive'});

hole_radius = hole_radius_um / 1000;
hole_pitch = hole_pitch_um / 1000;

assert(hole_pitch > 2*hole_radius, ...
    '穴の中心ピッチは穴の直径より大きくしてください。');
assert(hole_radius <= emitter_radius, ...
    '穴の半径が発音体の半径を超えています。');

N = ceil((emitter_radius + hole_radius) / hole_pitch);
[y, x] = ndgrid((-N:N)*hole_pitch);
candidates = [x(:), y(:)];

inside = hypot(candidates(:,1), candidates(:,2)) ...
    + hole_radius <= emitter_radius;

hole_centers_local = candidates(inside, :);

assert(~isempty(hole_centers_local), ...
    '穴が配置されません。穴のサイズを確認してください。');

%% CAD出力：円穴のみ
output_folder = fullfile( ...
    fileparts(mfilename('fullpath')), 'scr-lower-electrode');

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

scr_filename = fullfile(output_folder, 'lower_electrode.scr');
write_circle_holes( ...
    scr_filename, emitter_centers, hole_centers_local, hole_radius);

fprintf('穴直径: %.3f um\n', 2*hole_radius_um);
fprintf('穴の中心ピッチ: %.3f um\n', hole_pitch_um);
fprintf('穴の縁間隔: %.3f um\n', hole_pitch_um - 2*hole_radius_um);
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
title('下部電極：配置全体の発音体中心');

% 拡大図はCAD出力と同じ円穴を表示。
figure; hold on; axis equal;
t = linspace(0, 2*pi, 100).';

plot(emitter_radius*cos(t), emitter_radius*sin(t), 'b--');
plot(hole_centers_local(:,1).' + hole_radius*cos(t), ...
     hole_centers_local(:,2).' + hole_radius*sin(t), ...
     'k-', 'LineWidth', 0.5);

xlabel('X [mm]'); ylabel('Y [mm]');
title('下部電極：発音体1個の穴パターン');

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

function write_circle_holes(filename, emitter_centers, local, radius)
    fid = fopen(filename, 'w');
    assert(fid ~= -1, ...
        'SCRファイルを開けません: %s', filename);
    cleanup = onCleanup(@() fclose(fid));

    for i = 1:size(emitter_centers,1)
        holes = local + emitter_centers(i,:);

        fprintf(fid, 'CIRCLE %.8f,%.8f %.8f\n', ...
            [holes, repmat(radius, size(holes,1), 1)].');
    end
end