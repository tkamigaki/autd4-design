function layout = generate_single_transducer(options)
% 外形、各層、および重ね合わせ図を SCR / DXF R12 で出力する。
% 寸法の初期値は以下で編集できる。*_um は µm、それ以外の寸法は mm。
arguments
    options.notched_outline (1,1) logical = false % false: 長方形、true: 四隅・右側に切り欠き
    options.cell_size (1,1) double {mustBeFinite,mustBePositive} = 6.2 % 正方形の一辺
    options.cell_pitch (1,1) double {mustBeFinite,mustBePositive} = 6.2 % 正方形の中心間ピッチ
    options.lower_hole_diameter_um (1,1) double {mustBeFinite,mustBePositive} = 70 % 下部電極の円穴径
    options.lower_hole_pitch_um (1,1) double {mustBeFinite,mustBePositive} = 90 % 下部電極の穴ピッチ
    options.back_hole_size_um (1,1) double {mustBeFinite,mustBePositive} = 300 % 背面層の穴の一辺
    options.back_hole_pitch_um (1,1) double {mustBeFinite,mustBePositive} = 350 % 背面層の穴ピッチ
    options.back_hole_count (1,2) double {mustBeFinite,mustBeInteger,mustBePositive} = [3,3] % 背面層の穴の数
    options.add_corner_holes (1,1) logical = true % 端の列と中央の2×2セットを追加
    options.diameters (1,:) double {mustBeFinite,mustBePositive} = [1.00 1.01 1.02 1.03 1.04]
    options.pitch (1,1) double {mustBeFinite,mustBePositive} = 5 % 端の列の穴ピッチ
    options.side_inset (1,1) double {mustBeFinite,mustBeNonnegative} = 2 % 左端・右の切り欠きから端の列まで
    options.top_inset (1,1) double {mustBeFinite,mustBeNonnegative} = 8 % 上下端から最初の穴まで
    options.group_inset (1,1) double {mustBeFinite,mustBeNonnegative} = 2 % 左端・右の切り欠きからセット中心まで
    options.outline_file (1,1) string = fullfile(fileparts(mfilename('fullpath')), ...
        '..','outline-rectangle','outline_rectangle_pattern_Emitter.scr')
    options.output_dir (1,1) string = "" % 省略時はこの .m ファイルと同じフォルダ
end

emitter_radius = 0.5; % 発音体の半径
lower_conductive_radius = 0.55; % 下部電極の導電層
cell_size = options.cell_size; 
cell_pitch = options.cell_pitch;
lower_radius = options.lower_hole_diameter_um/2000;
lower_pitch = options.lower_hole_pitch_um/1000;
back_size = options.back_hole_size_um/1000;
back_pitch = options.back_hole_pitch_um/1000;

assert(cell_pitch >= cell_size,'正方形の中心間ピッチは一辺以上にしてください。');
assert(cell_size >= 2*lower_conductive_radius,'正方形に下部電極側の導電層が収まりません。');
assert(lower_radius <= emitter_radius,'下部電極の円穴が発音体に収まりません。');
assert(lower_pitch > 2*lower_radius,'下部電極の穴ピッチは穴径より大きくしてください。');
assert(back_pitch > back_size,'背面層の穴ピッチは穴の一辺より大きくしてください。');
back_span = (options.back_hole_count-1)*back_pitch + back_size;
assert(all(back_span <= cell_size),'背面層の穴パターンが正方形に収まりません。');

% マークの基準は元のSCRから取得し、出力する外形だけを切り替える。
[outline_points,outline,dxf_outline] = read_outline(options.outline_file);
outline_min = min(outline_points,[],1);
outline_max = max(outline_points,[],1);
if ~options.notched_outline
    outline = [outline_min; outline_max(1),outline_min(2); ...
        outline_max; outline_min(1),outline_max(2)];
    dxf_outline = [outline,zeros(4,1)];
end
outline_center = (outline_min + outline_max)/2;
tolerance = 1e-9;
counts = floor((outline_max-outline_min-cell_size+tolerance)/cell_pitch)+1;
assert(all(counts >= 1),'正方形が外形に収まりません。');
centers = centered_grid(counts,cell_pitch) + outline_center;

% 下部電極は円穴全体が発音体の円内にあるものだけを採用。
n = ceil(emitter_radius/lower_pitch);
lower_offsets = centered_grid([2*n+1,2*n+1],lower_pitch);
lower_offsets = lower_offsets(hypot(lower_offsets(:,1),lower_offsets(:,2)) ...
    + lower_radius <= emitter_radius,:);

% 背面層の角穴は既存と同じく、発音体の円で切り取らない。
back_offsets = centered_grid(options.back_hole_count,back_pitch);
lower_centers = translate_pattern(centers,lower_offsets);
back_centers = translate_pattern(centers,back_offsets);

% 追加穴の右側基準は元の外周から求める。
common_holes = zeros(0,3);
if options.add_corner_holes
    mid_y = outline_center(2);
    next_point = circshift(outline_points,-1,1);
    crosses_mid = (outline_points(:,2)>mid_y) ~= (next_point(:,2)>mid_y);
    vertical = outline_points(:,1) == next_point(:,1);
    right_edge = max(outline_points(vertical & crosses_mid,1));
    assert(~isempty(right_edge) && right_edge > outline_center(1), ...
        '外形中央の右側に基準となる縦辺がありません。');
    offsets = (0:numel(options.diameters)-1).' * options.pitch;
    radii = options.diameters(:)/2;
    common_holes = [repmat(outline_min(1)+options.side_inset,size(offsets)), ...
        outline_max(2)-options.top_inset-offsets, radii;
        repmat(right_edge-options.side_inset,size(offsets)), ...
        outline_min(2)+options.top_inset+offsets, radii];

    groups = [outline_min(1)+options.group_inset, mid_y; ...
        right_edge-options.group_inset, mid_y];
    lower_centers = [lower_centers; translate_pattern(groups,centered_grid([2,2],lower_pitch))];
    back_centers = [back_centers; translate_pattern(groups,centered_grid([2,2],back_pitch))];
end

layers = [ ...
    make_layer('OUTLINE',7,[],{outline}), ...
    make_layer('CELL_GRID',8,[],squares(centers,cell_size)), ...
    make_layer('EMITTER',3,circles(centers,emitter_radius),{}), ...
    make_layer('LOWER_ELECTRODE',1,[circles(lower_centers,lower_radius); common_holes],{}), ...
    make_layer('BACK_LAYER',5,common_holes,squares(back_centers,back_size)), ...
    make_layer('COND_LAYER_LOWER_ELECTRODE',6,circles(centers,lower_conductive_radius),{})];
layers(1).dxf_outline = dxf_outline;

output_dir = options.output_dir;
if output_dir == ""
    output_dir = string(fileparts(mfilename('fullpath')));
end
scr_dir = fullfile(output_dir,'scr');
dxf_dir = fullfile(output_dir,'dxf');
for folder = [scr_dir,dxf_dir]
    if ~isfolder(folder)
        [ok,message] = mkdir(folder);
        assert(ok,'出力フォルダを作成できません: %s',message);
    end
end

for i = 2:numel(layers)
    stem = lower(layers(i).name) + "_with_outline";
    write_scr(fullfile(scr_dir,stem + ".scr"),layers([1,i]));
    write_dxf(fullfile(dxf_dir,stem + ".dxf"),layers([1,i]));
end
write_scr(fullfile(scr_dir,'available_layers_with_outline.scr'),layers);
write_dxf(fullfile(dxf_dir,'available_layers_with_outline.dxf'),layers);

layout = struct('grid_counts',counts,'emitter_centers',centers, ...
    'lower_holes_per_emitter',size(lower_offsets,1), ...
    'back_holes_per_emitter',size(back_offsets,1));
fprintf('発音体: %d 個、下部電極: %d 穴/個、背面層: %d 穴/個\n', ...
    size(centers,1),layout.lower_holes_per_emitter,layout.back_holes_per_emitter);
fprintf('SCR出力先: %s\nDXF出力先: %s\n',scr_dir,dxf_dir);
end

function [xy,outline,dxf_outline] = read_outline(filename)
assert(isfile(filename),'外形SCRがありません: %s',filename);
source = fileread(filename);
parts = regexp(source, ...
    '(?im)^[ \t]*_?PLINE\s+([\s\S]*?)\s+_?C(?:LOSE)?(?=\s|$)', ...
    'tokens','once');
assert(~isempty(parts),'外形SCRに閉じたPLINEがありません: %s',filename);
tokens = regexp(strtrim(parts{1}),'\s+','split');
tokens(strcmpi(tokens,'_NON')) = [];
xy = zeros(numel(tokens),2);
for i = 1:numel(tokens)
    pair = strsplit(tokens{i},',','CollapseDelimiters',false);
    assert(numel(pair)==2,'外形SCRのXY座標が不正です: %s',tokens{i});
    xy(i,:) = str2double(pair);
end
if isequal(xy(1,:),xy(end,:))
    xy(end,:) = [];
end
assert(size(xy,1)>=3 && all(isfinite(xy(:))) && all(max(xy)>min(xy)), ...
    '外形SCRのポリラインが不正です: %s',filename);

% phi-1mm と同じく、頂点にある円を1/4円の切り欠きに変換する。
entries = regexp(source,'(?im)^\s*_?CIRCLE\s+(?:_NON\s+)?(\S+)\s+(\S+)','tokens');
corner_circles = zeros(numel(entries),3);
for i = 1:numel(entries)
    center = sscanf(entries{i}{1},'%f,%f');
    radius = str2double(entries{i}{2});
    assert(numel(center)==2 && isfinite(radius) && radius>0,'外形SCRの円が不正です。');
    corner_circles(i,:) = [center.',radius];
end
[found,corner_index] = ismember(corner_circles(:,1:2),xy,'rows');
assert(all(found) && numel(unique(corner_index))==numel(entries),'外形SCRの円と頂点が一致しません。');
n = size(xy,1);
parts = num2cell(xy,2);
dxf_parts = cellfun(@(p) [p,0],parts,'UniformOutput',false);
segments = 64;
for i = 1:numel(corner_index)
    j = corner_index(i);
    center = xy(j,:);
    radius = corner_circles(i,3);
    incoming = xy(mod(j-2,n)+1,:) - center;
    outgoing = xy(mod(j,n)+1,:) - center;
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
outline = vertcat(parts{:});
dxf_outline = vertcat(dxf_parts{:});
end

function xy = centered_grid(counts,pitch)
x = ((1:counts(1))-(counts(1)+1)/2)*pitch;
y = ((1:counts(2))-(counts(2)+1)/2)*pitch;
[X,Y] = ndgrid(x,y);
xy = [X(:),Y(:)];
end

function xy = translate_pattern(centers,offsets)
xy = repelem(centers,size(offsets,1),1) + repmat(offsets,size(centers,1),1);
end

function data = circles(centers,radius)
data = [centers,repmat(radius,size(centers,1),1)];
end

function polygons = squares(centers,side)
offsets = side/2*[-1,-1; 1,-1; 1,1; -1,1];
vertices = translate_pattern(centers,offsets);
polygons = mat2cell(vertices,repmat(4,size(centers,1),1),2);
end

function layer = make_layer(name,color,circle_data,polygons)
layer = struct('name',string(name),'color',color, ...
    'circles',circle_data,'polygons',{polygons},'dxf_outline',[]);
end

function write_scr(filename,layers)
fid = fopen(filename,'w');
assert(fid ~= -1,'出力を開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'_UCS\n_World\n');
for layer = layers
    fprintf(fid,'_-LAYER\n_Make\n%s\n_Color\n%d\n%s\n\n', ...
        layer.name,layer.color,layer.name);
    if ~isempty(layer.circles)
        fprintf(fid,'_CIRCLE\n_NON %.12g,%.12g\n%.12g\n',layer.circles.');
    end
    for i = 1:numel(layer.polygons)
        fprintf(fid,'_PLINE\n');
        fprintf(fid,'_NON %.12g,%.12g\n',layer.polygons{i}.');
        fprintf(fid,'_Close\n');
    end
end
fprintf(fid,'_ZOOM\n_Extents\n');
end

function write_dxf(filename,layers)
% R12 の閉じた POLYLINE と真円の CIRCLE を使用する。
fid = fopen(filename,'w');
assert(fid ~= -1,'出力を開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'0\nSECTION\n2\nHEADER\n9\n$ACADVER\n1\nAC1009\n0\nENDSEC\n');
fprintf(fid,['0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLTYPE\n70\n1\n', ...
    '0\nLTYPE\n2\nCONTINUOUS\n70\n0\n3\nSolid line\n72\n65\n73\n0\n40\n0\n0\nENDTAB\n']);
fprintf(fid,'0\nTABLE\n2\nLAYER\n70\n%d\n',numel(layers)+1);
fprintf(fid,'0\nLAYER\n2\n0\n70\n0\n62\n7\n6\nCONTINUOUS\n');
for layer = layers
    fprintf(fid,'0\nLAYER\n2\n%s\n70\n0\n62\n%d\n6\nCONTINUOUS\n',layer.name,layer.color);
end
fprintf(fid,'0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nBLOCKS\n0\nENDSEC\n');
fprintf(fid,'0\nSECTION\n2\nENTITIES\n');
for layer = layers
    name = char(layer.name);
    if ~isempty(layer.circles)
        circle_format = ['0\nCIRCLE\n8\n',name,'\n10\n%.15g\n20\n%.15g\n30\n0\n40\n%.15g\n'];
        fprintf(fid,circle_format,layer.circles.');
    end
    vertex_format = ['0\nVERTEX\n8\n',name,'\n10\n%.15g\n20\n%.15g\n30\n0\n'];
    for i = 1:numel(layer.polygons)
        fprintf(fid,'0\nPOLYLINE\n8\n%s\n66\n1\n10\n0\n20\n0\n30\n0\n70\n1\n',name);
        if isempty(layer.dxf_outline)
            fprintf(fid,vertex_format,layer.polygons{i}.');
        else
            fprintf(fid,[vertex_format,'42\n%.15g\n'],layer.dxf_outline.');
        end
        fprintf(fid,'0\nSEQEND\n8\n%s\n',name);
    end
end
fprintf(fid,'0\nENDSEC\n0\nEOF\n');
end
