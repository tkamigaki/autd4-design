function merge_layer_drawings()
% phi-1mm フォルダに保存して実行。
% 登録済みの層のうち、SCRが存在するものだけ読み込む。
% 未生成の層は名前とパスを表示してスキップする。SCRは再生成しない。
% 入力の座標・円半径は変更しない。外形でのトリミングは行わない。
root = fileparts(mfilename('fullpath'));
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
output_dir = fullfile(root,'scr-merged');
if ~exist(output_dir,'dir'), mkdir(output_dir); end

% 各層＋外形、および全層＋外形のSCRを保存。
for i = 1:n_layers
    filename = fullfile(output_dir,[lower(names{i}) '_with_outline.scr']);
    write_merged(filename,texts([1,i+1]), ...
        [{'OUTLINE'},names(i)],[7,cad_colors(i)]);
end
write_merged(fullfile(output_dir,'available_layers_with_outline.scr'), ...
    texts,[{'OUTLINE'},names],[7,cad_colors]);

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
fprintf('凡例クリックで各層の表示を切り替えられます。\n');
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
fprintf(fid,'_ZOOM\n_Extents\n');
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
axis(ax,'equal'); grid(ax,'on'); box(ax,'on');
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
