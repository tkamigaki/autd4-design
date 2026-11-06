clear; clc; close all;

% 単位 mm。元の六角形寸法・V2配置は固定し、発音体だけを小径化する。
radius = 0.5;
gap = 0.3;                    % 円の縁同士の最小間隔
hex_count = [16, 10];          % [横, 縦]
tile_count = [1, 1];
reference_radius = 1;
reference_l_s = 0.15;

s = reference_radius + reference_l_s;
hex_radii = [2*s + 2/sqrt(3)*reference_radius, ...
             2*s + 2/sqrt(3)*s]; % 内側・外側六角形の中心〜頂点
hex_centers = make_hex_centers(s, hex_count, tile_count);
local_centers = pack_hexagon(hex_radii(1), radius, gap);

% 各六角形に同じ局所配置を平行移動して配置する。
count_per_hex = size(local_centers, 1);
circle_centers = repmat(local_centers, size(hex_centers, 1), 1) ...
    + repelem(hex_centers, count_per_hex, 1);

output_folder = fullfile(fileparts(mfilename('fullpath')), ...
    'scr-emitters');
if ~exist(output_folder, 'dir'), mkdir(output_folder); end
scr_filename = fullfile(output_folder, 'emitter_positions.scr');
write_scr(scr_filename, circle_centers, radius);
fprintf('%d 個/六角形 × %d 六角形 = %d 個\n', ...
    count_per_hex, size(hex_centers, 1), size(circle_centers, 1));
fprintf('半径 %.3f mm、縁間隔 %.3f mm、中心間隔 %.3f mm\n', ...
    radius, gap, 2*radius + gap);
fprintf('SCR出力: %s\n', scr_filename);

draw_layout(circle_centers, hex_centers, radius, hex_radii, '全体配置');
draw_layout(local_centers, [0, 0], radius, hex_radii, ...
    sprintf('六角形1個：%d 個（赤点は固定中心）', count_per_hex));
plot(0, 0, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 4);

function centers = make_hex_centers(s, counts, tiles)
    % ndgridの先頭の次元を最内周とし、元コードと同じ配置順を保つ。
    [iy, ix, ty, tx] = ndgrid(0:counts(2)-1, 0:counts(1)-1, ...
        0:tiles(2)-1, 0:tiles(1)-1);
    x_pitch = (3 + sqrt(3))*s;
    y_pitch = (2 + 2*sqrt(3))*s;
    x = tx + ix*x_pitch + 2*s + 2/sqrt(3)*s;
    y = ty + iy*y_pitch - ((1-mod(ix, 2))*y_pitch/2 - y_pitch);
    centers = [x(:), y(:)];
    % 元の7個配置は各中心に対して対称なので、全発音体の平均は
    % 六角形中心の平均と一致。7個ずつ再生成せずに原点移動できる。
    centers = centers - mean(centers, 1);
end

function centers = pack_hexagon(hex_radius, radius, gap)
    assert(isscalar(radius) && isfinite(radius) && radius > 0 ...
        && isscalar(gap) && isfinite(gap) && gap >= 0, ...
        '半径は正、隙間は0以上の有限値にしてください。');
    pitch = 2*radius + gap;
    apothem = hex_radius*cos(pi/6);
    assert(radius <= apothem, '中央の発音体が六角形に収まりません。');
    limit = ceil(2*hex_radius/pitch) + 1;
    [col, row] = ndgrid(-limit:limit);
    candidates = pitch*[col(:) + row(:)/2, sqrt(3)/2*row(:)];
    angles = (0:5)*pi/3 + pi/6;
    normals = [cos(angles); sin(angles)];
    % 6辺すべてから半径以上離れた点を選ぶ（円全体が内側に収まる）。
    inside = all(candidates*normals <= apothem-radius+1e-10, 2);
    centers = candidates(inside, :);
    [~, order] = sort(sum(centers.^2, 2));
    centers = centers(order, :);
end

function write_scr(filename, centers, radius)
    fid = fopen(filename, 'w');
    assert(fid ~= -1, 'SCRファイルを開けません: %s', filename);
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'circle %.8f,%.8f %.8f\n', ...
        [centers, repmat(radius, size(centers, 1), 1)].');
end

function draw_layout(centers, hex_centers, radius, hex_radii, caption)
    figure; hold on; axis equal;
    t = linspace(0, 2*pi, 100).';
    % 列ごとに1つの円を描画し、円ごとのplot呼び出しを省く。
    plot(centers(:, 1).' + radius*cos(t), ...
        centers(:, 2).' + radius*sin(t), 'k-', 'LineWidth', 0.5);
    angles = (0:6).'*pi/3;
    styles = {'b-', 'b:'};
    for i = 1:numel(hex_radii)
        plot(hex_centers(:, 1).' + hex_radii(i)*cos(angles), ...
            hex_centers(:, 2).' + hex_radii(i)*sin(angles), ...
            styles{i}, 'LineWidth', 0.5);
    end
    title(caption); xlabel('X [mm]'); ylabel('Y [mm]');
end
