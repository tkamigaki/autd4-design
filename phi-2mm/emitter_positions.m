
clear; clc; close all;

% === パラメータ設定 ===
params = struct();
params.r_e = 1; % 発音体の半径[mm]
params.l_s = 0.15; % 発音体間の隙間[mm]
params.N_x_hex = 16; % 六角形の個数（x方向）
params.N_y_hex = 10; % 六角形の個数（y方向）
params.N_x_t = 1;
params.N_y_t = 1;

% === ジオメトリ計算 ===
geo = compute_geometry(params);

% === 図の保存フォルダ作成 ===
current_script_fullpath = mfilename('fullpath');
[current_folder, ~, ~] = fileparts(current_script_fullpath);
detail_str = ['scr-emitter-position'];
fig_folder = fullfile(current_folder, detail_str);
mkdir(fig_folder);

% === 配置生成 ===
circle_centers = [];
hex_data = {};

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
                hex_data{end+1} = get_hex_points(x0, y0, geo.a_hex); %#ok<SAGROW>
                hex_data{end+1} = get_hex_points(x0, y0, geo.b_hex); %#ok<SAGROW>
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

for i = 1:length(hex_data)
    hex_data{i} = hex_data{i} - [x_center, y_center]; %#ok<SAGROW>
end

% === SCR file output ===
scr_filename = fullfile(fig_folder, 'emitter_positions.scr');
fid = fopen(scr_filename, 'w');
for i = 1:size(circle_centers_shifted, 1)
    fprintf(fid, 'circle %.4f,%.4f %.4f\n', circle_centers_shifted(i,1), circle_centers_shifted(i,2), params.r_e);
end
fclose(fid);

disp(['SCRファイルを作成しました: ' scr_filename]);

% === plot figure
figure; hold on; axis equal;
for i = 1:size(circle_centers_shifted, 1)
    draw_circle(circle_centers_shifted(i,1), circle_centers_shifted(i,2), params.r_e);
    % ★中心点をプロット（クリックできるようになる）
    plot(circle_centers_shifted(i,1), circle_centers_shifted(i,2), 'ro', 'MarkerSize', 3, 'MarkerFaceColor', 'r');
end
for i = 1:length(hex_data)
    plot(hex_data{i}(:,1), hex_data{i}(:,2), 'b-', 'LineWidth', 0.1);
end
xlabel('X [mm]');
ylabel('Y [mm]');

% ========= function ========= 
function geo = compute_geometry(p)
    r_e = p.r_e; l_s = p.l_s;
    geo.x_pitch = 3*(r_e + l_s) + 3/sqrt(3)*(r_e + l_s);
    geo.y_pitch = 2*(r_e + l_s) + 2*sqrt(3)*(r_e + l_s);
    geo.r_c     = 2*(r_e + l_s);
    geo.a_hex   = 2*(r_e + l_s) + 2/sqrt(3)*r_e;
    geo.b_hex   = 2*(r_e + l_s) + 2/sqrt(3)*(r_e + l_s);
end

function draw_circle(x, y, r)
    t = linspace(0, 2*pi, 100);
    plot(x + r*cos(t), y + r*sin(t), 'k', 'LineWidth', 0.1);
end

function pts = get_hex_points(x, y, r)
    angles = (0:6) * pi/3;
    pts = [x + r*cos(angles)', y + r*sin(angles)'];
end
