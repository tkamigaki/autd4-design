
clear; clc; close all;

% === パラメータ設定（変更禁止） ===
params = struct();
params.r_e = 1; % 発音体の半径[mm]
params.l_s = 0.15;
params.N_x_hex = 16;
params.N_y_hex = 10;
params.N_x_t = 1;
params.N_y_t = 1;

% === ジオメトリ計算 ===
geo = compute_geometry(params);

% === 図の保存フォルダ作成 ===
current_script_fullpath = mfilename('fullpath');
[current_folder, ~, ~] = fileparts(current_script_fullpath);
detail_str = ['CAD data lower electrode layer'];
fig_folder = fullfile(current_folder, detail_str);
if ~exist(fig_folder, 'dir')
    mkdir(fig_folder);
end

% === 配置生成 ===
% circle_centers = [];
% for i_tx = 0 : params.N_x_t - 1
%     for i_ty = 0 : params.N_y_t - 1
%         x_offset_tile = i_tx;
%         y_offset_tile = i_ty;
%         for i_x = 0 : params.N_x_hex - 1
%             x0 = x_offset_tile + i_x * geo.x_pitch + 2 *(params.r_e + params.l_s) + 2/sqrt(3)*(params.r_e + params.l_s);
%             y_shift = mod(i_x,2) * geo.y_pitch/2 - geo.y_pitch;
%             for i_y = 0 : params.N_y_hex - 1
%                 y0 = y_offset_tile + i_y * geo.y_pitch - y_shift;
%                 circle_centers(end+1, :) = [x0, y0]; %#ok<SAGROW>
%                 for k_hex = 0:5
%                     theta = k_hex * pi/3;
%                     cx = x0 + geo.r_c * cos(theta);
%                     cy = y0 + geo.r_c * sin(theta);
%                     circle_centers(end+1, :) = [cx, cy]; %#ok<SAGROW>
%                 end
%             end
%         end
%     end
% end
circle_centers = [];
for i_tx = 0 : params.N_x_t - 1
    for i_ty = 0 : params.N_y_t - 1
        x_offset_tile = i_tx;
        y_offset_tile = i_ty;
        for i_x = 0 : params.N_x_hex - 1
            x0 = x_offset_tile + i_x * geo.x_pitch + 2 *(params.r_e + params.l_s) + 2/sqrt(3)*(params.r_e + params.l_s);
            y_shift = (1 - mod(i_x,2)) * geo.y_pitch/2 - geo.y_pitch;
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

% === 指定円パターンの設定 ===
hole_diameter = 0.08; % mm
hole_pitch = 0.16;    % mm
num_cols = 12;
holes_per_col = [6, 8, 10, 12, 12, 12, 12, 12, 12, 10, 8, 6];

fixed_pattern = [];
x_start = -((num_cols-1)/2) * hole_pitch;
for i_col = 1:num_cols
    num_holes = holes_per_col(i_col);
    x = x_start + (i_col-1)*hole_pitch;
    y_start = -((num_holes-1)/2) * hole_pitch;
    for i_row = 1:num_holes
        y = y_start + (i_row-1)*hole_pitch;
        fixed_pattern(end+1,:) = [x, y]; %#ok<SAGROW>
    end
end

% === 全円にパターン配置 ===
all_holes = [];
for i = 1:size(circle_centers_shifted, 1)
    cx = circle_centers_shifted(i,1);
    cy = circle_centers_shifted(i,2);

    new_holes = fixed_pattern + [cx, cy];
    all_holes = [all_holes; new_holes, repmat(hole_diameter/2, size(new_holes,1), 1)]; %#ok<AGROW>
end

% === 図示 ===
figure; hold on; axis equal;
for i = 1:size(circle_centers_shifted, 1)
    draw_circle(circle_centers_shifted(i,1), circle_centers_shifted(i,2), params.r_e);
end
scatter(all_holes(:,1), all_holes(:,2), 10, 'r', 'filled');
title('円 + 指定XY格子穴パターン');

% === SCRファイル出力 ===
scr_filename = fullfile(fig_folder, 'lower_electrode_layer_pattern_V2.scr');
fid = fopen(scr_filename, 'w');
for i = 1:size(all_holes,1)
    fprintf(fid, 'CIRCLE %.4f,%.4f %.4f\n', all_holes(i,1), all_holes(i,2), all_holes(i,3));
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

function draw_circle(x, y, r, color)
    if nargin < 4
        color = 'k';
    end
    t = linspace(0, 2*pi, 100);
    plot(x + r*cos(t), y + r*sin(t), color, 'LineWidth', 0.5);
end
