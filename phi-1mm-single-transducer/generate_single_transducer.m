function layout = generate_single_transducer(options)
% 外形、各層、および重ね合わせ図を SCR / DXF R12 で出力する。
% 寸法の初期値は以下で編集できる。*_um は µm、それ以外の寸法は mm。
arguments
    options.cell_size (1,1) double {mustBeFinite,mustBePositive} = 6
    options.cell_pitch (1,1) double {mustBeFinite,mustBePositive} = 7
    options.lower_hole_diameter_um (1,1) double {mustBeFinite,mustBePositive} = 70
    options.lower_hole_pitch_um (1,1) double {mustBeFinite,mustBePositive} = 90
    options.back_hole_size_um (1,1) double {mustBeFinite,mustBePositive} = 300
    options.back_hole_pitch_um (1,1) double {mustBeFinite,mustBePositive} = 350
    options.back_hole_count (1,2) double {mustBeFinite,mustBeInteger,mustBePositive} = [3,3]
    options.outline_file (1,1) string = fullfile(fileparts(mfilename('fullpath')), ...
        '..','outline-rectangle','outline_rectangle_pattern_Emitter.scr')
    options.output_dir (1,1) string = fullfile(fileparts(mfilename('fullpath')),'cad')
end

emitter_radius = 0.5;
lower_conductive_radius = 0.55;
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

% 外周ポリラインの外接矩形を使い、右辺の凹みと四隅の円は反映しない。
[outline_min,outline_max] = read_outline_bounds(options.outline_file);
outline = [outline_min; outline_max(1),outline_min(2); ...
    outline_max; outline_min(1),outline_max(2)];
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

layers = [ ...
    make_layer('OUTLINE',7,[],{outline}), ...
    make_layer('CELL_GRID',8,[],squares(centers,cell_size)), ...
    make_layer('EMITTER',3,circles(centers,emitter_radius),{}), ...
    make_layer('LOWER_ELECTRODE',1,circles(lower_centers,lower_radius),{}), ...
    make_layer('BACK_LAYER',5,[],squares(back_centers,back_size)), ...
    make_layer('COND_LAYER_LOWER_ELECTRODE',6,circles(centers,lower_conductive_radius),{}), ...
    make_layer('CONDUCTIVE_LAYER_BACK_LAYER',2,[],{outline})];

scr_dir = fullfile(options.output_dir,'scr');
dxf_dir = fullfile(options.output_dir,'dxf');
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
fprintf('出力先: %s\n',options.output_dir);
end

function [bounds_min,bounds_max] = read_outline_bounds(filename)
assert(isfile(filename),'外形SCRがありません: %s',filename);
% CIRCLEは対象外。閉じたPLINEのXY座標だけを読む。
parts = regexp(fileread(filename), ...
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
bounds_min = min(xy,[],1);
bounds_max = max(xy,[],1);
assert(size(xy,1)>=3 && all(isfinite(xy(:))) && all(bounds_max>bounds_min), ...
    '外形SCRのポリラインが不正です: %s',filename);
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
    'circles',circle_data,'polygons',{polygons});
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
        fprintf(fid,vertex_format,layer.polygons{i}.');
        fprintf(fid,'0\nSEQEND\n8\n%s\n',name);
    end
end
fprintf(fid,'0\nENDSEC\n0\nEOF\n');
end
