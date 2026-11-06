
clear; clc; close all;

% === パラメータ設定（変更禁止） ===
params = struct();
params.r_e = 1; % 発音体の半径[mm]
params.l_s = 0.15; % 発音体間の隙間[mm]
params.N_x_hex = 16; % 六角形の個数（x方向）
params.N_y_hex = 10; % 六角形の個数（y方向）
params.N_x_t = 1;
params.N_y_t = 1;

% 背面層に設ける四角穴の寸法
square_size = 0.85; % 一辺の長さ [mm]
gap = 0.15; % 四角と四角の間の残し幅 [mm] 

% === ジオメトリ計算 ===
geo = compute_geometry(params);

% === 図の保存フォルダ作成 ===
current_script_fullpath = mfilename('fullpath');
[current_folder, ~, ~] = fileparts(current_script_fullpath);
detail_str = 'CAD data back layer';
% detail_str = ['CAD data back layer'];
fig_folder = fullfile(current_folder, detail_str);
if ~exist(fig_folder, 'dir')
    mkdir(fig_folder);
end

% === 配置生成 ===
circle_centers = [];

for i_tx = 0 : params.N_x_t - 1
    for i_ty = 0 : params.N_y_t - 1
        x_offset_tile = i_tx;
        y_offset_tile = i_ty;
        for i_x = 0 : params.N_x_hex - 1
            x0 = x_offset_tile + i_x * geo.x_pitch + 2 *(params.r_e + params.l_s) + 2/sqrt(3)*(params.r_e + params.l_s);
            y_shift = mod(i_x,2) * geo.y_pitch/2 - geo.y_pitch;
            for i_y = 0 : params.N_y_hex - 1
                y0 = y_offset_tile + i_y * geo.y_pitch - y_shift;
                circle_centers(end+1, :) = [x0, y0]; %#ok<SAGROW>
                for k_hex = 0:5
                    theta = k_hex * pi/3;
                    cx = x0 + geo.r_c * cos(theta);
                    cy = y0 + geo.r_c * sin(theta);
                    circle_centers(end+1, :) = [cx, cy]; %#ok<SAGROW>
                end
            end
        end
    end
end

% === 中心を原点に移動 ===
x_center = mean(circle_centers(:,1));
y_center = mean(circle_centers(:,2));
circle_centers_shifted = circle_centers - [x_center, y_center];

% === 四角配置計算 ===
offset = (square_size + gap) / 2; 
all_squares = {};
for i = 1:size(circle_centers_shifted, 1)
    cx = circle_centers_shifted(i,1);
    cy = circle_centers_shifted(i,2);

    % 4方向（45度方向）
    centers = [
        cx - offset, cy - offset;
        cx + offset, cy - offset;
        cx - offset, cy + offset;
        cx + offset, cy + offset;
    ];

    for j = 1:size(centers,1)
        all_squares{end+1} = get_square_points(centers(j,1), centers(j,2), square_size); %#ok<SAGROW>
    end
end

% === Figure 1: 円のみ ===
figure; hold on; axis equal;
for i = 1:size(circle_centers_shifted, 1)
    draw_circle(circle_centers_shifted(i,1), circle_centers_shifted(i,2), params.r_e);
end
title('円のみ');

% === Figure 2: 円 + 四角 ===
figure; hold on; axis equal;
for i = 1:size(circle_centers_shifted, 1)
    draw_circle(circle_centers_shifted(i,1), circle_centers_shifted(i,2), params.r_e);
end
for i = 1:length(all_squares)
    plot(all_squares{i}(:,1), all_squares{i}(:,2), 'r-', 'LineWidth', 0.5);
end
title('円 + 四角');

% === Figure 3: 四角のみ ===
figure; hold on; axis equal;
for i = 1:length(all_squares)
    plot(all_squares{i}(:,1), all_squares{i}(:,2), 'r-', 'LineWidth', 0.5);
end
title('四角のみ');

% === SCRファイル出力（四角のみ） ===
scr_filename = fullfile(fig_folder, strcat('back_layer_pattern_gap_', num2str(gap), 'mm.scr'));

fid = fopen(scr_filename, 'w');

for i = 1:length(all_squares)
    pts = all_squares{i};
    fprintf(fid, 'PLINE\n');
    for j = 1:size(pts,1)
        fprintf(fid, '%.4f,%.4f\n', pts(j,1), pts(j,2));
    end
    fprintf(fid, 'C\n'); % 閉じる
end

fclose(fid);
disp(['SCRファイルを作成しました: ' scr_filename]);

% === Functions ===
function geo = compute_geometry(p)
    r_e = p.r_e; l_s = p.l_s;
    geo.x_pitch = 3*(r_e + l_s) + 3/sqrt(3)*(r_e + l_s);
    geo.y_pitch = 2*(r_e + l_s) + 2*sqrt(3)*(r_e + l_s);
    geo.r_c     = 2*(r_e + l_s);
end

function draw_circle(x, y, r)
    t = linspace(0, 2*pi, 100);
    plot(x + r*cos(t), y + r*sin(t), 'k', 'LineWidth', 0.1);
end

function pts = get_square_points(cx, cy, size)
    half = size/2;
    pts = [
        cx - half, cy - half;
        cx + half, cy - half;
        cx + half, cy + half;
        cx - half, cy + half;
        cx - half, cy - half;
    ];
end
