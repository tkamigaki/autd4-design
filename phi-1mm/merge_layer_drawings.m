function merge_layer_drawings()
% 冒頭の設定を編集して実行する。距離と径の単位は mm。
% phi-1mm に保存。各層＋外形と全層＋外形をSCR・DXFで出力。
% 登録済みの層のうち、SCRが存在するものだけ読み込む。
% 未生成の層は名前とパスを表示してスキップする。SCRは再生成しない。
% 外形の四隅だけを円で切り欠く。内部レイヤーは元の形状のまま重ねる。
root = fileparts(mfilename('fullpath'));
% 穴付き版の配置 [mm]。径は左上で上から、右下で下からの順。
add_corner_holes = true; % false にすると従来の穴なし図面を出力。
diameters = [1.00 1.01 1.02 1.03 1.04];
pitch = 5;
side_inset = 2; % 左右共通。左列は外形左端から右へ、右列は中央の切り欠きの奥の縦辺から左へ測る距離 [mm]。
top_inset = 8;  % 縦距離：左列の最上穴は上端から下へ、右列の最下穴は下端から上へ。
group_inset = 2; % 中央の2×2穴セットの中心までの水平距離 [mm]。左端・右の切り欠き基準。
outline_file = fullfile(root,'..','outline-rectangle', ...
    'outline_rectangle_pattern_Emitter.scr');
input_files = {
    fullfile(root,'scr-back-layer','back_layer.scr')
    fullfile(root,'scr-emitters','emitter_positions.scr')
    fullfile(root,'scr-lower-electrode','lower_electrode.scr')
    fullfile(root,'scr-conductive-layer-lower-electrode','conductive_layer_lower_electrode.scr')
    fullfile(root,'scr-conductive-layer-back-layer','conductive_layer_back_layer.scr')
    fullfile(root,'scr-conductive-layer-back-layer','substrate_via.scr')
    fullfile(root,'scr-conductive-layer-back-layer','adhesive_via_openings.scr')
};
names = {'BACK_LAYER','EMITTER','LOWER_ELECTRODE','CONDUCTIVE_LAYER_LOWER_ELECTRODE','CONDUCTIVE_LAYER_BACK_LAYER','SUBSTRATE_VIA','ADHESIVE_VIA_OPENINGS'};
colors = [0.10 0.45 0.90; 0.15 0.65 0.25; 0.90 0.20 0.15; 0.65 0.20 0.80; 0.95 0.55 0.10;0.10 0.70 0.75;0.60 0.35 0.10];
cad_colors = [5,3,1,6,2,4,30];
% 内部の図形は設計時の向きで統一。旧形式のSCRも同じ向きで読める。
idx = find(strcmp(names,'CONDUCTIVE_LAYER_BACK_LAYER'));
design_file = fullfile(fileparts(input_files{idx}),'conductive_layer_back_layer_reverse.scr');
if isfile(design_file)
    input_files{idx} = design_file;
end
% 存在する層を自動選択。外形は従来どおり必要。
assert(isfile(outline_file),'外形SCRがありません: %s',outline_file);
available = cellfun(@isfile,input_files);
for i = find(~available(:)).'
    fprintf(2,'スキップ（SCRなし）: %s\n  %s\n',names{i},input_files{i});
end
assert(any(available),'読み込める層のSCRがありません。');
input_files = input_files(available);
names = names(available);
colors = colors(available,:);
cad_colors = cad_colors(available);
n_layers = numel(input_files);
fprintf('読み込む層 (%d): %s\n',n_layers,strjoin(names,', '));
circle_segments = 32; % 表示のみの分割数。SCRでは正確なCIRCLEを維持。

% 存在する入力を解析する。存在しても形式が不正な場合はエラーで通知。
files = [{outline_file};input_files];
texts = cell(n_layers+1,1);
geometry = cell(n_layers+1,1);
for i = 1:numel(files)
    assert(isfile(files{i}),'入力SCRがありません: %s',files{i});
    texts{i} = fileread(files{i});
    geometry{i} = read_geometry(texts{i},files{i});
end
% 四隅の元の円を、外形につながる1/4円弧に置き換える。
geometry{1} = trim_outline_corners(geometry{1});
outline_points = geometry{1}.polygons{1};
outline_min = min(outline_points,[],1);
outline_max = max(outline_points,[],1);
fprintf('外形寸法: 幅 %.3f mm × 高さ %.3f mm\n', outline_max-outline_min);
fprintf('外形座標: X %.3f ～ %.3f mm、Y %.3f ～ %.3f mm\n', ...
    outline_min(1),outline_max(1),outline_min(2),outline_max(2));

texts{1} = ['_PLINE', newline, ...
    sprintf('_NON %.8f,%.8f\n',outline_points.'), '_C'];

if add_corner_holes
    offset = (0:numel(diameters)-1).' * pitch;
    radius = diameters(:)/2;
    upper_left = [repmat(outline_min(1)+side_inset,size(offset)), ...
        outline_max(2)-top_inset-offset, radius];
    % 外形の高さ中央を横切る右側の縦辺を切り欠きの基準とする。
    next_point = circshift(outline_points,-1,1);
    mid_y = (outline_min(2)+outline_max(2))/2;
    crosses_mid = (outline_points(:,2)>mid_y) ~= (next_point(:,2)>mid_y);
    vertical = outline_points(:,1) == next_point(:,1);
    notch_x = max(outline_points(vertical & crosses_mid,1));
    assert(~isempty(notch_x) && notch_x > (outline_min(1)+outline_max(1))/2 ...
        && notch_x < outline_max(1),'右側中央の切り欠きの縦辺が見つかりません。');
    lower_right = [repmat(notch_x-side_inset,size(offset)), ...
        outline_min(2)+top_inset+offset, radius];
    hole_scr = sprintf('CIRCLE %.8f,%.8f %.8f\n',[upper_left;lower_right].');
    group_centers = [outline_min(1)+group_inset, mid_y; notch_x-group_inset, mid_y];
    for i = find(ismember(names,{'BACK_LAYER','LOWER_ELECTRODE'}))
        group_scr = make_group_scr(root,names{i},group_centers);
        extra_scr = [hole_scr,group_scr];
        extra = read_geometry(extra_scr,names{i});
        texts{i+1} = [strtrim(texts{i+1}),newline,extra_scr];
        geometry{i+1}.circles = [geometry{i+1}.circles;extra.circles];
        geometry{i+1}.polygons = [geometry{i+1}.polygons;extra.polygons];
    end
end

output_dir = fullfile(root,'scr-merged-trimmed');
if ~exist(output_dir,'dir'), mkdir(output_dir); end
dxf_dir = fullfile(root,'dxf-merged-trimmed-r12');
if ~exist(dxf_dir,'dir'), mkdir(dxf_dir); end

% 各層＋外形、および全層＋外形のSCRを保存。
for i = 1:n_layers
    stem = [lower(names{i}) '_with_outline'];
    layer_names = [{'OUTLINE'},names(i)];
    layer_colors = [7,cad_colors(i)];
    pair_text = texts([1,i+1]);
    pair_geo = geometry([1,i+1]);
    if strcmp(names{i},'CONDUCTIVE_LAYER_BACK_LAYER')
        % 設計時の組をそのまま保存し、最終使用版では組全体を同じ軸で反転。
        write_merged(fullfile(output_dir,[stem '_reverse.scr']),pair_text,layer_names,layer_colors);
        write_dxf(fullfile(dxf_dir,[stem '_reverse.dxf']),pair_geo,layer_names,layer_colors);
        for j = 1:numel(pair_geo)
            [pair_geo{j},pair_text{j}] = mirror_contours(pair_geo{j},outline_min(1)+outline_max(1));
        end
    end
    write_merged(fullfile(output_dir,[stem '.scr']),pair_text,layer_names,layer_colors);
    write_dxf(fullfile(dxf_dir,[stem '.dxf']),pair_geo,layer_names,layer_colors);
end
write_merged(fullfile(output_dir,'available_layers_with_outline.scr'), ...
    texts,[{'OUTLINE'},names],[7,cad_colors]);
write_dxf(fullfile(dxf_dir,'available_layers_with_outline.dxf'), ...
    geometry,[{'OUTLINE'},names],[7,cad_colors]);

% 外形付きの各層を表示。
for i = 1:n_layers
    figure('Name',[names{i} ' + OUTLINE'],'Color','w');
    ax = axes; hold(ax,'on');
    draw_geometry(ax,geometry{1},[0.25 0.25 0.25],circle_segments);
    draw_geometry(ax,geometry{i+1},colors(i,:),circle_segments);
    finish_axes(ax,[names{i} ' + OUTLINE']);
end

% 読み込めた層を重ねて表示。凡例クリックでレイヤー表示を切り替えられる。
figure('Name','Available layers + OUTLINE','Color','w');
ax = axes; hold(ax,'on');
groups = gobjects(n_layers+1,1);
groups(1) = draw_geometry(ax,geometry{1},[0.25 0.25 0.25],circle_segments);
for i = 1:n_layers
    groups(i+1) = draw_geometry(ax,geometry{i+1},colors(i,:),circle_segments);
end
finish_axes(ax,'Available layers + OUTLINE');
lgd = legend(ax,groups,[{'OUTLINE'},names],'Interpreter','none');
lgd.ItemHitFcn = @toggle_layer;
fprintf('出力先: %s\n',output_dir);
fprintf('合成SCR: available_layers_with_outline.scr\n');
fprintf('DXF出力先: %s\n',dxf_dir);
fprintf('凡例クリックで各層の表示を切り替えられます。\n');
end

function [geo,scr] = mirror_contours(geo,x_sum)
% 外形・背面導電層はいずれも閉じた輪郭。DXFの円弧は反射で回転方向が逆になる。
assert(isempty(geo.circles),'外形・背面導電層には輪郭ポリラインが必要です。');
parts = cell(size(geo.polygons));
for i = 1:numel(parts)
    xy = geo.polygons{i};
    xy(:,1) = x_sum-xy(:,1);
    geo.polygons{i} = xy;
    parts{i} = ['_PLINE',newline,sprintf('_NON %.10f,%.10f\n',xy.'),'_C',newline];
end
scr = [parts{:}];
if isfield(geo,'dxf_outline')
    geo.dxf_outline(:,1) = x_sum-geo.dxf_outline(:,1);
    geo.dxf_outline(:,3) = -geo.dxf_outline(:,3);
end
end

function scr = make_group_scr(root,layer,group_centers)
% 各層の生成スクリプト冒頭の寸法設定 [um] を読み、mm に換算する。
source = fileread(fullfile(root,[lower(layer),'.m']));
is_round = strcmp(layer,'LOWER_ELECTRODE');
if is_round
    radius = setting_mm(source,'hole_radius_um');
    pitch = setting_mm(source,'hole_pitch_um');
else
    side = setting_mm(source,'square_size_um');
    pitch = setting_mm(source,'square_pitch_um');
end
corners = [-1,-1; 1,-1; 1,1; -1,1];
offsets = corners * (pitch/2);
centers = [group_centers(1,:) + offsets; group_centers(2,:) + offsets];
if is_round
    circles = [centers,repmat(radius,size(centers,1),1)];
    scr = sprintf('CIRCLE %.8f,%.8f %.8f\n',circles.');
else
    outlines = cell(size(centers,1),1);
    for j = 1:numel(outlines)
        vertices = centers(j,:) + corners * (side/2);
        outlines{j} = ['PLINE',newline,sprintf('%.8f,%.8f\n',vertices.'),'C',newline];
    end
    scr = [outlines{:}];
end
end

function value = setting_mm(source,name)
% 寸法は各層の設定欄に数値で指定する（例：hole_pitch_um = 90;）。
token = regexp(source,['(?m)^[ \t]*',name,'[ \t]*=[ \t]*([0-9.eE+-]+)[ \t]*;'],'tokens','once');
assert(~isempty(token),'設定 %s の数値を読み取れません。',name);
value = str2double(token{1})/1000;
validateattributes(value,{'numeric'},{'scalar','positive','finite'});
end

function geo = trim_outline_corners(geo)
% 角の中心と半径は元の外形SCRにある4つのCIRCLEから取得する。
assert(numel(geo.polygons) == 1 && size(geo.circles,1) == 4, ...
    '外形SCRに閉じたポリライン1本と四隅の円4個が必要です。');
vertices = geo.polygons{1};
if isequal(vertices(1,:),vertices(end,:))
    vertices(end,:) = [];
end

[found,corner_index] = ismember(geo.circles(:,1:2),vertices,'rows');
assert(all(found) && numel(unique(corner_index)) == 4, ...
    '四隅の円の中心が外形の頂点と一致しません。');
n = size(vertices,1);
parts = num2cell(vertices,2);
dxf_parts = cellfun(@(p) [p,0],parts,'UniformOutput',false);
segments = 64;
for i = 1:numel(corner_index)
    j = corner_index(i);
    center = vertices(j,:);
    radius = geo.circles(i,3);
    incoming = vertices(mod(j-2,n)+1,:) - center;
    outgoing = vertices(mod(j,n)+1,:) - center;
    assert(norm(incoming) > radius && norm(outgoing) > radius, ...
        '円の半径が隣接する辺に対して大きすぎます。');
    incoming = incoming/norm(incoming);
    outgoing = outgoing/norm(outgoing);
    assert(abs(dot(incoming,outgoing)) < 1e-10, ...
        '切り欠く外形の角は直角である必要があります。');
    start_angle = atan2(incoming(2),incoming(1));
    turn = sign(det([incoming;outgoing]))*pi/2;
    angles = start_angle + linspace(0,turn,segments+1).';
    parts{j} = center + radius*[cos(angles),sin(angles)];
    dxf_parts{j} = [parts{j}(1,:),tan(turn/4); parts{j}(end,:),0];
end
geo.polygons{1} = vertcat(parts{:});
geo.dxf_outline = vertcat(dxf_parts{:});
geo.circles = zeros(0,3);
end

function geo = read_geometry(text,filename)
% 現行出力のCIRCLE/PLINEを読む。改行・同一行のどちらにも対応。
tokens = regexp(strtrim(text),'\s+','split');
n = numel(tokens);
% 円用の作業配列は最後に有効部分だけ残す。
circles = zeros(ceil(n/3),3);
polygons = cell(0,1);
nc = 0; i = 1;
while i <= n
    command = upper(tokens{i});
    i = i+1;
    switch command
        case 'CIRCLE'
            assert(i+1 <= n,'円の記述が不完全です: %s',filename);
            xy = parse_xy(tokens{i},filename);
            r = str2double(tokens{i+1});
            assert(isfinite(r) && r > 0,'円の半径が不正です: %s',filename);
            nc = nc+1;
            circles(nc,:) = [xy,r];
            i = i+2;
        case 'PLINE'
            points = zeros(0,2);
            while i <= n && ~strcmpi(tokens{i},'C')
                points(end+1,:) = parse_xy(tokens{i},filename); %#ok<AGROW>
                i = i+1;
            end
            assert(i <= n && size(points,1) >= 3, ...
                '閉じたPLINEではありません: %s',filename);
            polygons{end+1,1} = points; %#ok<AGROW>
            i = i+1;
        otherwise
            error('未対応のSCRコマンド "%s": %s',command,filename);
    end
end
geo.circles = circles(1:nc,:);
geo.polygons = polygons;
end

function xy = parse_xy(token,filename)
xy = sscanf(token,'%f,%f').';
assert(numel(xy) == 2 && all(isfinite(xy)), ...
    'XY座標が不正です: %s (%s)',token,filename);
end

function write_merged(filename,texts,names,colors)
fid = fopen(filename,'w');
assert(fid ~= -1,'出力を開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));
% UCSをワールドにし、元の座標で配置。既存図面への追記ではなく新規図面で実行。
fprintf(fid,'_UCS\n_World\n');
for i = 1:numel(texts)
    fprintf(fid,'_-LAYER\n_Make\n%s\n_Color\n%d\n%s\n\n', ...
        names{i},colors(i),names{i});
    fprintf(fid,'%s\n',strtrim(texts{i}));
end
fprintf(fid,'_ZOOM\n_Extents\n\n');
fprintf('保存: %s\n',filename);
end

function write_dxf(filename,geometry,names,colors)
% ASCII DXF R12。座標の数値は mm。ポリラインの 42 で真円弧を保持。
% R12 のレイヤー名は31文字まで。
names(strcmp(names,'CONDUCTIVE_LAYER_LOWER_ELECTRODE')) = {'COND_LAYER_LOWER_ELECTRODE'};
fid = fopen(filename,'wb');
assert(fid ~= -1,'DXFを開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,['0\r\nSECTION\r\n2\r\nHEADER\r\n9\r\n$ACADVER\r\n1\r\nAC1009\r\n', ...
    '9\r\n$LUNITS\r\n70\r\n2\r\n0\r\nENDSEC\r\n']);

fprintf(fid,['0\r\nSECTION\r\n2\r\nTABLES\r\n0\r\nTABLE\r\n2\r\nLTYPE\r\n70\r\n1\r\n', ...
    '0\r\nLTYPE\r\n2\r\nCONTINUOUS\r\n70\r\n0\r\n3\r\nSolid line\r\n72\r\n65\r\n', ...
    '73\r\n0\r\n40\r\n0.0\r\n0\r\nENDTAB\r\n']);
layer_names = [{'0'},names];
layer_colors = [7,colors];
fprintf(fid,'0\r\nTABLE\r\n2\r\nLAYER\r\n70\r\n%d\r\n',numel(layer_names));
for i = 1:numel(layer_names)
    fprintf(fid,'0\r\nLAYER\r\n2\r\n%s\r\n70\r\n0\r\n62\r\n%d\r\n6\r\nCONTINUOUS\r\n', ...
        layer_names{i},layer_colors(i));
end
fprintf(fid,['0\r\nENDTAB\r\n0\r\nENDSEC\r\n0\r\nSECTION\r\n2\r\nBLOCKS\r\n', ...
    '0\r\nENDSEC\r\n0\r\nSECTION\r\n2\r\nENTITIES\r\n']);

for i = 1:numel(geometry)
    geo = geometry{i};
    layer = names{i};
    if ~isempty(geo.circles)
        circle_format = ['0\r\nCIRCLE\r\n8\r\n',layer, ...
            '\r\n10\r\n%.15g\r\n20\r\n%.15g\r\n30\r\n0\r\n40\r\n%.15g\r\n'];
        fprintf(fid,circle_format,geo.circles.');
    end
    vertex_format = ['0\r\nVERTEX\r\n8\r\n',layer, ...
        '\r\n10\r\n%.15g\r\n20\r\n%.15g\r\n30\r\n0\r\n42\r\n%.15g\r\n70\r\n0\r\n'];
    for j = 1:numel(geo.polygons)
        if isfield(geo,'dxf_outline')
            points = geo.dxf_outline;
        else
            xy = geo.polygons{j};
            if isequal(xy(1,:),xy(end,:))
                xy(end,:) = [];
            end
            points = [xy,zeros(size(xy,1),1)];
        end
        fprintf(fid,'0\r\nPOLYLINE\r\n8\r\n%s\r\n66\r\n1\r\n10\r\n0\r\n20\r\n0\r\n30\r\n0\r\n70\r\n1\r\n',layer);
        fprintf(fid,vertex_format,points.');
        fprintf(fid,'0\r\nSEQEND\r\n8\r\n%s\r\n',layer);
    end
end
fprintf(fid,'0\r\nENDSEC\r\n0\r\nEOF\r\n');
fprintf('保存: %s\n',filename);
end

function group = draw_geometry(ax,geo,color,segments)
group = hggroup('Parent',ax);
theta = linspace(0,2*pi,segments+1).';
% 多数の穴を1個ずつ描かず、NaNで区切ってまとめて描く。
batch = 5000;
for first = 1:batch:size(geo.circles,1)
    c = geo.circles(first:min(first+batch-1,end),:);
    x = c(:,1).' + cos(theta)*c(:,3).';
    y = c(:,2).' + sin(theta)*c(:,3).';
    x = [x;nan(1,size(x,2))];
    y = [y;nan(1,size(y,2))];
    line('Parent',group,'XData',x(:),'YData',y(:), ...
        'Color',color,'LineWidth',0.5);
end
if ~isempty(geo.polygons)
    parts = cellfun(@(p) [p;p(1,:);NaN,NaN], ...
        geo.polygons,'UniformOutput',false);
    xy = vertcat(parts{:});
    line('Parent',group,'XData',xy(:,1),'YData',xy(:,2), ...
        'Color',color,'LineWidth',0.5);
end
end

function finish_axes(ax,caption)
axis(ax,'equal');
axis(ax,'tight');
padding = [-3,3]; % 表示だけに加える余白 [mm]
xlim(ax,xlim(ax) + padding);
ylim(ax,ylim(ax) + padding);
grid(ax,'on'); box(ax,'on');
xlabel(ax,'X [mm]'); ylabel(ax,'Y [mm]');
title(ax,caption,'Interpreter','none');
end

function toggle_layer(~,event)
if strcmp(event.Peer.Visible,'on')
    event.Peer.Visible = 'off';
else
    event.Peer.Visible = 'on';
end
end
