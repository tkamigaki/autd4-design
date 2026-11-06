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
detail_str = 'CAD data Substrate Via';
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



%% === 追加：指定座標の四角形(1.29mm)・四角形A(0.99mm)と2種類の円 ===
ctr = [-38.093, 28.27675];   % 中心 (x,y) [mm]
a_outer = 1.29;              % 外側の四角の一辺 [mm]
insetA  = 0.15;              % 内側オフセット [mm]
a_A     = a_outer - 2*insetA; % 四角形Aの一辺 = 0.99mm

R_big   = 0.60/2;            % 大きい円の半径 [mm]
R_small = 0.30/2;            % 小さい円の半径 [mm]

% 四角形の頂点列
S_outer = get_square_points(ctr(1), ctr(2), a_outer);
S_A     = get_square_points(ctr(1), ctr(2), a_A);

% 四角形Aの半径（半辺長）
hA = a_A/2;

% 直径0.6mmの各円の中心：Aの対角線上かつ2辺に同時接触
% 右上接触: [cx+hA - R_big, cy+hA - R_big]
% 左下接触: [cx-hA + R_big, cy-hA + R_big]
d  = hA - R_big;                         % = 0.495 - 0.3 = 0.195
c_ru = ctr + [ d,  d];                   % 右上側の中心
c_ld = ctr + [-d, -d];                   % 左下側の中心

% 描画
% figure; hold on; axis equal;
% 四角形
plot(S_outer(:,1), S_outer(:,2), 'k-', 'LineWidth', 0.9);
plot(S_A(:,1),     S_A(:,2),     'k-', 'LineWidth', 0.9);

% 直径0.6mmの円（外接）
t = linspace(0, 2*pi, 200);
plot(c_ru(1) + R_big*cos(t), c_ru(2) + R_big*sin(t), 'k-', 'LineWidth', 0.9);
plot(c_ld(1) + R_big*cos(t), c_ld(2) + R_big*sin(t), 'k-', 'LineWidth', 0.9);

% 直径0.3mmの円（同じ中心）
plot(c_ru(1) + R_small*cos(t), c_ru(2) + R_small*sin(t), 'k-', 'LineWidth', 0.9);
plot(c_ld(1) + R_small*cos(t), c_ld(2) + R_small*sin(t), 'k-', 'LineWidth', 0.9);

% （任意）Aの対角線を確認用に表示
plot([ctr(1)-hA, ctr(1)+hA], [ctr(2)-hA, ctr(2)+hA], 'k--');
title('指定座標の四角形・四角形A・対角上の2円（0.6/0.3mm）');


%% === さらに追記：Figure2 に X×Y 配列で追加配置 ==========================
Nx = 8;           % x方向の個数
Ny = 10;          % y方向の個数
dx = 10.88;       % x方向ピッチ [mm]
dy = -6.28;        % y方向ピッチ [mm]

for ix = 0:Nx-1
  for iy = 0:Ny-1
    if ix==0 && iy==0
      continue; % 基準の1個はすでに描画済みなのでスキップ
    end
    c = ctr + [ix*dx, iy*dy];   % 新しい中心

    % 四角形（外側 & A）
    S_outer_ij = get_square_points(c(1), c(2), a_outer);
    S_A_ij     = get_square_points(c(1), c(2), a_A);
    plot(S_outer_ij(:,1), S_outer_ij(:,2), 'k-', 'LineWidth', 0.9);
    plot(S_A_ij(:,1),     S_A_ij(:,2),     'k-', 'LineWidth', 0.9);

    % 円（φ0.6 & φ0.3）— Aの対角線上で2辺に同時接触
    c_ru = c + [ d,  d];
    c_ld = c + [-d, -d];
    plot(c_ru(1)+R_big*cos(t),   c_ru(2)+R_big*sin(t),   'k-', 'LineWidth', 0.9);
    plot(c_ld(1)+R_big*cos(t),   c_ld(2)+R_big*sin(t),   'k-', 'LineWidth', 0.9);
    plot(c_ru(1)+R_small*cos(t), c_ru(2)+R_small*sin(t), 'k-', 'LineWidth', 0.9);
    plot(c_ld(1)+R_small*cos(t), c_ld(2)+R_small*sin(t), 'k-', 'LineWidth', 0.9);

    % （任意）対角線を各セルにも描く場合は次行を有効化
    % plot([c(1)-hA, c(1)+hA], [c(2)-hA, c(2)+hA], 'k--');
  end
end
% =======================================================================
%% === さらに追記：左上にシフトした同一配列（円は 左上・右下 で外接） ===
shift = [-5.4418, 3.1419];   % xをマイナス、yをプラス＝左上へ
ctr2  = ctr + shift;         % 新しい配列の基準中心

for ix = 0:Nx-1
  for iy = 0:Ny-1
    c = ctr2 + [ix*dx, iy*dy];   % 各セルの中心

    % 四角形（外側 & A）
    S_outer_ij = get_square_points(c(1), c(2), a_outer);
    S_A_ij     = get_square_points(c(1), c(2), a_A);
    plot(S_outer_ij(:,1), S_outer_ij(:,2), 'k-', 'LineWidth', 0.9);
    plot(S_A_ij(:,1),     S_A_ij(:,2),     'k-', 'LineWidth', 0.9);

    % 円（φ0.6 & φ0.3）— Aの左上/右下の2辺に同時接触（対角線 TL-BR）
    %   左上:  (-d, +d),  右下: (+d, -d)
    c_tl = c + [-d,  d];
    c_br = c + [ d, -d];

    plot(c_tl(1)+R_big*cos(t),   c_tl(2)+R_big*sin(t),   'k-', 'LineWidth', 0.9);
    plot(c_br(1)+R_big*cos(t),   c_br(2)+R_big*sin(t),   'k-', 'LineWidth', 0.9);
    plot(c_tl(1)+R_small*cos(t), c_tl(2)+R_small*sin(t), 'k-', 'LineWidth', 0.9);
    plot(c_br(1)+R_small*cos(t), c_br(2)+R_small*sin(t), 'k-', 'LineWidth', 0.9);

    % （任意）Aの対角線（左上-右下）を表示したい場合
    % plot([c(1)-hA, c(1)+hA], [c(2)+hA, c(2)-hA], 'k--');
  end
end

%% === 追記：SCR出力（大きい円のみ / 小さい円のみ） =======================
% すべての円の中心を集約（基準セル + 右下方向配列 + 左上シフト配列）
centers_circle = [];

% 基準セル（右上＆左下に外接）
centers_circle = [centers_circle;
                  ctr + [ d,  d];   % 右上
                  ctr + [-d, -d]];  % 左下

% 右下方向への配列（(0,0) は基準セルなのでスキップ）
for ix = 0:Nx-1
  for iy = 0:Ny-1
    if ix==0 && iy==0, continue; end
    c = ctr + [ix*dx, iy*dy];
    centers_circle = [centers_circle;
                      c + [ d,  d];   % 右上
                      c + [-d, -d]];  % 左下
  end
end

% 左上シフト配列（左上＆右下に外接）
for ix = 0:Nx-1
  for iy = 0:Ny-1
    c = ctr2 + [ix*dx, iy*dy];
    centers_circle = [centers_circle;
                      c + [-d,  d];   % 左上
                      c + [ d, -d]];  % 右下
  end
end

% === SCR 書き出し（それぞれ半径だけ変更して同じ中心を出力） ===
scr_big   = fullfile(fig_folder, 'pattern_circles_AdhesiveLayer.scr'); %外形、空気穴は後から追加
scr_small = fullfile(fig_folder, 'pattern_circles_SubstrateVia.scr'); %外形、空気穴は後から追加

% 大きい円のみ（φ0.60）
fid = fopen(scr_big,'w');
for i = 1:size(centers_circle,1)
  fprintf(fid, 'CIRCLE\n%.6f,%.6f\n%.6f\n', centers_circle(i,1), centers_circle(i,2), R_big);
end
fclose(fid);

% 小さい円のみ（φ0.30）
fid = fopen(scr_small,'w');
for i = 1:size(centers_circle,1)
  fprintf(fid, 'CIRCLE\n%.6f,%.6f\n%.6f\n', centers_circle(i,1), centers_circle(i,2), R_small);
end
fclose(fid);

disp(['SCR出力: ', scr_big]);
disp(['SCR出力: ', scr_small]);
% =======================================================================


%------

% === Figure 3: 四角のみ ===
figure; hold on; axis equal;
for i = 1:length(all_squares)
    plot(all_squares{i}(:,1), all_squares{i}(:,2), 'r-', 'LineWidth', 0.5);
end
title('四角のみ');

% % === SCRファイル出力（四角のみ） ===
% scr_filename = fullfile(fig_folder, strcat('back_layer_pattern_gap_', num2str(gap), 'mm.scr'));

% fid = fopen(scr_filename, 'w');

% for i = 1:length(all_squares)
%     pts = all_squares{i};
%     fprintf(fid, 'PLINE\n');
%     for j = 1:size(pts,1)
%         fprintf(fid, '%.4f,%.4f\n', pts(j,1), pts(j,2));
%     end
%     fprintf(fid, 'C\n'); % 閉じる
% end

% fclose(fid);
% disp(['SCRファイルを作成しました: ' scr_filename]);

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
