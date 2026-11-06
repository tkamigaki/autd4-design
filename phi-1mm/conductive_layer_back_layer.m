function conductive_layer_back_layer()
% Phi1 mm・19個/六角形の背面導電層。既存ファイルの設定に合わせる。
% 円を横方向につなぎ、行間も接続した外周輪郭を作る。
% ビアは六角形中心から数式で配置。Phi1版では右上/左下方向に統一。
% ビア2個をまとめて囲む四角い張り出し。赤線の指定に対応。
% 全列で同じ配置を使い、ビア中点とペア方向を格子探索する。
% ビア外周間300um・隣接導電層間300umを固定する。
% 条件不成立なら出力前に停止する。元DWGの固定ビア座標は使用しない。
% SCRはPLINE近似。円弧の最大弦誤差はcurve_tolerance_um以下。
% 外形はmerge_layer_drawings.mで追加する。

%% 変更可能な設定（mm、ただし *_um はum）
emitter_radius = 0.5;
emitter_gap = 0.3;
hex_count = [16,10];
tile_count = [1,1];
reference_radius = 1;
reference_l_s = 0.15;

% back_layer.mと共通：穴配列全幅から導電層の基準円径を決める。
square_size_um = 300;
square_pitch_um = 350;
square_count = [3,3];
conductive_diameter_margin_um = 0;

via_diameter = 0.30;
adhesive_diameter = 0.60;
% 接着層用開口同士はつながってよい。別ペア・背面穴とは離す。
via_land_margin_um = 0;      % Phi2同様、初期値はビア外周に接する張り出し。余裕を加える場合に変更
pattern_clearance_um = 300;   % 隣の導電層との最小隙間（Phi2の設計値）
hole_clearance_um = 20;       % 開口と周囲の穴、ビア同士の最小隙間
lower_conductive_radius = 0.55; % 下部電極側の導電層半径（直径1.1 mm）
via_edge_gap_um = 300;        % ビア外周同士の隙間（固定）
search.coarse_step = 0.025;   % 中点の粗探索ピッチ [mm]
search.fine_step = 0.002;     % 中点の局所精査ピッチ [mm]
search.angle_degrees = [0,30,45,60,90,120,135,150];
search.fine_angle_step = 1;   % 局所精査の角度ピッチ [deg]
search.fine_angle_range = 5;  % 最良方向の前後を精査 [deg]
curve_tolerance_um = 0.1;    % 曲線をPLINE化するときの最大弦誤差

%% 設定確認
validateattributes(square_size_um,{'numeric'},{'scalar','finite','positive'});
validateattributes(square_pitch_um,{'numeric'},{'scalar','finite','positive'});
validateattributes(square_count,{'numeric'},{'vector','numel',2,'integer','positive'});
validateattributes(conductive_diameter_margin_um,{'numeric'},{'scalar','finite','nonnegative'});
validateattributes(via_diameter,{'numeric'},{'scalar','finite','positive'});
validateattributes(adhesive_diameter,{'numeric'},{'scalar','finite','positive'});
validateattributes(via_edge_gap_um,{'numeric'},{'scalar','finite','positive'});
validateattributes(pattern_clearance_um,{'numeric'},{'scalar','finite','positive'});
validateattributes(hole_clearance_um,{'numeric'},{'scalar','finite','positive'});
validateattributes(lower_conductive_radius,{'numeric'},{'scalar','finite','positive'});
validateattributes(via_land_margin_um,{'numeric'},{'scalar','finite','nonnegative'});
validateattributes(curve_tolerance_um,{'numeric'},{'scalar','finite','positive'});
assert(square_pitch_um>square_size_um,'背面穴のピッチは一辺より大きくしてください。');
span_um = (square_count-1)*square_pitch_um+square_size_um;
conductive_radius = (max(span_um)+conductive_diameter_margin_um)/2000;
assert(2*conductive_radius<2*emitter_radius+emitter_gap, ...
    '導電層の基準円が発音体の中心間隔以上になっています。');
via_radius = via_diameter/2;
adhesive_radius = adhesive_diameter/2;
tol = curve_tolerance_um/1000;
required_pattern_gap = pattern_clearance_um/1000;
required_hole_gap = hole_clearance_um/1000;
via_pair_center_distance = via_diameter+via_edge_gap_um/1000;

%% emitter_positions.mと同じ中心・局所配置
s = reference_radius+reference_l_s;
x_pitch = (3+sqrt(3))*s;
y_pitch = (2+2*sqrt(3))*s;
hex_radius = 2*s+2/sqrt(3)*reference_radius;
hex_centers = make_hex_centers(s,hex_count,tile_count);
local_centers = pack_hexagon(hex_radius,emitter_radius,emitter_gap);
emitter_centers = repmat(local_centers,size(hex_centers,1),1) ...
    + repelem(hex_centers,size(local_centers,1),1);
root = fileparts(mfilename('fullpath'));
check_emitter_scr(fullfile(root,'scr-emitters','emitter_positions.scr'), ...
    emitter_centers,emitter_radius);

%% ビア位置と方向を探索（穴径・ペア中心間距離は固定）
fprintf('ビア位置を探索しています...\n');
[mid,pair_offset,search_result] = find_fixed_pair(local_centers,conductive_radius, ...
    square_size_um/1000,square_pitch_um/1000,square_count, ...
    max(emitter_radius,lower_conductive_radius),adhesive_radius,via_radius, ...
    via_land_margin_um/1000,x_pitch,y_pitch,via_pair_center_distance, ...
    required_hole_gap,required_pattern_gap,search);
% 距離は固定。中点と方向のみ探索し、全列へ同じ配置を展開。
via_local = mid+[pair_offset;-pair_offset];
adhesive_local = via_local;
via_centers = repmat(via_local,size(hex_centers,1),1) ...
    + repelem(hex_centers,2,1);
adhesive_centers = via_centers;

%% 外周円を接続した輪郭
body = make_envelope(local_centers,conductive_radius,tol);
% ビア2個をまとめて囲む矩形を本体へつなぐ（斜めの接続部は作らない）。
% 位置の探索に応じて上側・左側へ張り出す。元の位置に限定しない。
land_margin = via_land_margin_um/1000;
tab_left = min([0;via_local(:,1)-via_radius-land_margin]);
tab_right = max([0;via_local(:,1)+via_radius+land_margin]);
tab_bottom = min([0;via_local(:,2)-via_radius-land_margin]);
tab_top = max([0;via_local(:,2)+via_radius+land_margin]);
assert(tab_left<tab_right && tab_bottom<tab_top,'張り出しの寸法が不正です。');
tab = polyshape([tab_left,tab_right,tab_right,tab_left], ...
    [tab_bottom,tab_bottom,tab_top,tab_top]);
body = union(body,tab);
assert(body.NumRegions==1 && body.NumHoles==0, ...
    '導電層が一続きの穴なし輪郭になっていません。');

%% 全体へ配置した後の確認（未達ならSCRを出力しない）
via_clearance = nearest_distance(via_centers,emitter_centers) ...
    - via_radius-emitter_radius;
adhesive_clearance = nearest_distance(adhesive_centers,emitter_centers) ...
    - adhesive_radius-max(emitter_radius,lower_conductive_radius);
[x,y] = ndgrid(((1:square_count(1))-(square_count(1)+1)/2)*square_pitch_um/1000, ...
             ((1:square_count(2))-(square_count(2)+1)/2)*square_pitch_um/1000);
square_local = [x(:),y(:)];
square_centers = repmat(square_local,size(emitter_centers,1),1) ...
    + repelem(emitter_centers,size(square_local,1),1);
backside_clearance = square_clearance(adhesive_centers,square_centers, ...
    square_size_um/1000,adhesive_radius);
via_pair_clearance = norm(via_local(1,:)-via_local(2,:))-via_diameter;
assert(abs(via_pair_clearance-via_edge_gap_um/1000)<1e-10, ...
    'ビアの外周間距離が指定値と一致しません。');
assert(min([via_clearance,adhesive_clearance,backside_clearance,via_pair_clearance]) ...
    >= required_hole_gap-1e-8, ...
    '全体配置で穴の最小隙間条件を満たしません。SCRは更新していません。');
% 別の六角形に属するビアペアどうしも確認する。
via_distances = hypot(via_centers(:,1)-via_centers(:,1).', ...
                      via_centers(:,2)-via_centers(:,2).');
cell_ids = repelem((1:size(hex_centers,1)).',2);
via_distances(cell_ids==cell_ids.') = inf;
other_opening_gap = min(via_distances,[],'all')-adhesive_diameter;
assert(other_opening_gap>=required_hole_gap-1e-8, ...
    '別セルの接着層用開口が近すぎます。SCRは更新していません。');
neighbor_shifts = [0,y_pitch;0,-y_pitch;x_pitch,y_pitch/2; ...
    x_pitch,-y_pitch/2;-x_pitch,y_pitch/2;-x_pitch,-y_pitch/2];
pattern_gaps = zeros(6,1);
for i=1:6
    neighbor = translate(body,neighbor_shifts(i,:));
    overlap = intersect(body,neighbor);
    assert(area(overlap)<1e-10,'導電層が重なっています。SCRは更新していません。');
    pattern_gaps(i)=polygon_gap(body,neighbor);
end
assert(min(pattern_gaps)>=required_pattern_gap-1e-8, ...
    '導電層間隔 %.3f um が設定 %.3f um 未満です。SCRは更新していません。', ...
    1000*min(pattern_gaps),pattern_clearance_um);

%% CAD出力（輪郭/ビア/接着層を分ける）
output_folder = fullfile(root,'scr-conductive-layer-back-layer');
if ~exist(output_folder,'dir'),mkdir(output_folder);end
write_patterns(fullfile(output_folder,'conductive_layer_back_layer.scr'), ...
    body,hex_centers);
write_circles(fullfile(output_folder,'substrate_via.scr'),via_centers,via_radius);
write_circles(fullfile(output_folder,'adhesive_via_openings.scr'), ...
    adhesive_centers,adhesive_radius);
fprintf('%d 個/六角形 × %d 組、ビア %d 個\n', ...
    size(local_centers,1),size(hex_centers,1),size(via_centers,1));
fprintf('ビアペア中点（六角形中心から）: X %.6f, Y %.6f mm\n',mid);
fprintf('ペアの中心間距離: %.6f mm、方向 %.1f 度\n', ...
    via_pair_center_distance,search_result.angle);
fprintf('導電層間の最小隙間: %.3f um（指定 %.3f）\n', ...
    1000*min(pattern_gaps),pattern_clearance_um);
fprintf('接着層開口と背面四角穴の最小隙間: %.3f um\n',1000*backside_clearance);
fprintf('接着層開口と下部導電円の最小隙間: %.3f um\n',1000*adhesive_clearance);
fprintf('ビア穴同士の最小隙間: %.3f um\n',1000*via_pair_clearance);
fprintf('出力先: %s\n',output_folder);
save(fullfile(output_folder,'via_layout_result.mat'),'mid','pair_offset','search_result', ...
    'via_centers','adhesive_centers','pattern_gaps','backside_clearance', ...
    'adhesive_clearance','via_pair_clearance');

%% 拡大比較：1組の輪郭/重ね合わせ
fig = figure('Name','Phi1 mm：背面導電層の拡大比較','Color','w');
tiledlayout(fig,1,2,'TileSpacing','compact');
ax1 = nexttile;hold(ax1,'on');plot(body,'FaceColor','none','EdgeColor','k');
format_axes(ax1,'背面導電層：完成輪郭');
ax2 = nexttile;hold(ax2,'on');
draw_circles(ax2,local_centers,emitter_radius,[0.10,0.50,0.85],'--');
vertices=square_size_um/2000*[-1,-1;1,-1;1,1;-1,1;-1,-1];
local_squares=repmat(square_local,size(local_centers,1),1) ...
    +repelem(local_centers,size(square_local,1),1);
plot(ax2,vertices(:,1)+local_squares(:,1).', ...
    vertices(:,2)+local_squares(:,2).','-','Color',[0.65,0.75,0.85],'LineWidth',0.3);
draw_circles(ax2,via_local,via_radius,[0.90,0.50,0.05],'--');
draw_circles(ax2,adhesive_local,adhesive_radius,[0.60,0.20,0.70],':');
plot(body,'FaceColor','none','EdgeColor','k');
format_axes(ax2,'発音体19個・ビアとの重ね合わせ');
h = [plot(ax2,NaN,NaN,'b--'),plot(ax2,NaN,NaN,'--','Color',[.9,.5,.05]), ...
     plot(ax2,NaN,NaN,':','Color',[.6,.2,.7]),plot(ax2,NaN,NaN,'k-')];
legend(ax2,h,{'発音体','ビア','接着層用開口','背面導電層'},'Location','best');
linkaxes([ax1,ax2],'xy');v = body.Vertices;
xlim(ax1,[min(v(:,1))-0.3,max(v(:,1))+0.3]);
ylim(ax1,[min(v(:,2))-0.3,max(v(:,2))+0.3]);
exportgraphics(fig,fullfile(output_folder,'comparison_detail.png'),'Resolution',200);

%% 全体表示
fig = figure('Name','Phi1 mm：背面導電層の全体配置','Color','w');
ax = axes(fig);hold(ax,'on');
[x,y] = boundary(body);
X = [x;NaN]+hex_centers(:,1).';Y = [y;NaN]+hex_centers(:,2).';
plot(ax,X(:),Y(:),'k-','LineWidth',0.5);
draw_circles(ax,via_centers,via_radius,[0.9,0.5,0.05],'-');
format_axes(ax,'背面導電層とビア：全体');
exportgraphics(fig,fullfile(output_folder,'comparison_full.png'),'Resolution',200);
end

function body = make_envelope(centers,r,tol)
% 各行の最外周円を横につなぎ、隣接行も狭い側の幅で接続。
% 旧7個配置では、外周6円をつないだ基本輪郭になる。
ys = unique(round(centers(:,2),12));
body = polyshape();previous = [];
for y = ys.'
    row = centers(abs(centers(:,2)-y)<1e-9,:);
    left = min(row(:,1));right = max(row(:,1));
    body = union(body,capsule([left,y],[right,y],r,tol));
    if ~isempty(previous)
        l = max(left-r,previous(1)-r);
        rr = min(right+r,previous(2)+r);
        assert(l<rr,'隣接する行が接続できません。');
        bridge = polyshape([l,rr,rr,l],[previous(3),previous(3),y,y]);
        body = union(body,bridge);
    end
    previous = [left,right,y];
end
end

function p = capsule(a,b,r,tol)
% 円2個の凸包＝両端が丸い接続領域。曲線を指定誤差以下で近似。
assert(tol>0 && tol<r,'曲線近似の許容誤差を半径未満にしてください。');
n = max(64,ceil(pi/acos(1-tol/r)));
t = (0:n-1)'*2*pi/n;
c = r*[cos(t),sin(t)];
points = [c+a;c+b];
k = convhull(points(:,1),points(:,2));
p = polyshape(points(k,1),points(k,2));
end

function dmin = nearest_distance(points,centers)
dmin = inf;
for first = 1:100:size(points,1)
    p = points(first:min(first+99,end),:);
    distance = hypot(p(:,1)-centers(:,1).',p(:,2)-centers(:,2).');
    dmin = min(dmin,min(distance,[],'all'));
end
end

function write_patterns(filename,body,centers)
fid = fopen(filename,'w');assert(fid~=-1,'出力を開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));
[x,y] = boundary(body);vertices = [x,y];
assert(all(isfinite(vertices),'all'),'輪郭に複数の境界があります。');
if norm(vertices(1,:)-vertices(end,:))<1e-10,vertices(end,:)=[];end
for i = 1:size(centers,1)
    fprintf(fid,'PLINE\n');
    fprintf(fid,'%.10f,%.10f\n',(vertices+centers(i,:)).');
    fprintf(fid,'C\n');
end
end

function write_circles(filename,centers,r)
fid = fopen(filename,'w');assert(fid~=-1,'出力を開けません: %s',filename);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'CIRCLE %.10f,%.10f %.10f\n', ...
    [centers,repmat(r,size(centers,1),1)].');
end

function check_emitter_scr(filename,centers,r)
% 古いSCRとの混在を避ける。存在すれば中心と半径を照合する。
if ~isfile(filename)
    fprintf('発音体SCRが未生成のため、設定値から配置を計算しました。\n');return;
end
t = regexp(fileread(filename),'(?i)circle\s+([-+\d.eE]+),([-+\d.eE]+)\s+([-+\d.eE]+)','tokens');
assert(~isempty(t),'発音体SCRから円を読み取れません。');
a = cellfun(@(x) str2double(x),t,'UniformOutput',false);a = vertcat(a{:});
assert(size(a,1)==size(centers,1),'発音体SCRの個数が設定と一致しません。');
p = sortrows(round(a(:,1:2),7));q = sortrows(round(centers,7));
assert(max(abs(p-q),[],'all')<2e-7 && max(abs(a(:,3)-r))<1e-8, ...
    'emitter_positions.scrと設定が一致しません。設定を合わせて再生成してください。');
end

function draw_circles(ax,centers,r,color,style)
t = linspace(0,2*pi,100).';
plot(ax,centers(:,1).'+r*cos(t),centers(:,2).'+r*sin(t), ...
    style,'Color',color,'LineWidth',0.6);
end

function format_axes(ax,caption)
axis(ax,'equal');grid(ax,'on');box(ax,'on');
xlabel(ax,'X [mm]');ylabel(ax,'Y [mm]');title(ax,caption);
end

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


function [mid,offset,best]=find_fixed_pair(local,r,side,pitch,counts, ...
        circle_r,opening_r,via_r,land,xp,yp,pair_distance, ...
        hole_gap,pattern_gap,search)
% 左上1/4領域の中点とペア方向を格子探索。全域最適性は保証しない。
shifts=[0,0;0,yp;0,-yp;xp,yp/2;xp,-yp/2;-xp,yp/2;-xp,-yp/2];
obstacles=zeros(0,2);
for k=1:size(shifts,1),obstacles=[obstacles;local+shifts(k,:)];end %#ok<AGROW>
[x,y]=ndgrid(((1:counts(1))-(counts(1)+1)/2)*pitch, ...
             ((1:counts(2))-(counts(2)+1)/2)*pitch);
small=[x(:),y(:)];
squares=repmat(small,size(obstacles,1),1)+repelem(obstacles,size(small,1),1);
ys=unique(round(local(:,2),12));rows=zeros(numel(ys),3);bridges=zeros(numel(ys)-1,4);
for k=1:numel(ys)
    row=local(abs(local(:,2)-ys(k))<1e-9,:);
    rows(k,:)=[min(row(:,1)),max(row(:,1)),ys(k)];
    if k>1
        bridges(k-1,:)=[max(rows(k-1,1),rows(k,1))-r, ...
            min(rows(k-1,2),rows(k,2))+r,rows(k-1,3),rows(k,3)];
    end
end
context=struct('obstacles',obstacles,'squares',squares,'side',side, ...
    'circle_r',circle_r,'opening_r',opening_r,'via_r',via_r,'land',land, ...
    'rows',rows,'bridges',bridges,'r',r,'shifts',shifts(2:end,:), ...
    'required_pattern_gap',pattern_gap);
[X,Y]=ndgrid(-xp/2:search.coarse_step:0,0:search.coarse_step:yp/2);
centers=[X(:),Y(:)];
best=struct('score',-inf,'mid',[NaN,NaN],'offset',[NaN,NaN],'angle',NaN);
for angle=search.angle_degrees
    fprintf('  ペア方向 %.1f 度を探索\n',angle);
    off=pair_distance/2*[cosd(angle),sind(angle)];
    best=scan_fixed_candidates(centers,off,angle,context,best);
end
assert(isfinite(best.score),'条件を満たす配置候補がありません。SCRは更新していません。');
old=best;
[X,Y]=ndgrid(-search.coarse_step:search.fine_step:search.coarse_step);
centers=old.mid+[X(:),Y(:)];
inside=centers(:,1)>=-xp/2 & centers(:,1)<=0 & centers(:,2)>=0 & centers(:,2)<=yp/2;
centers=centers(inside,:);
for angle=old.angle-search.fine_angle_range:search.fine_angle_step: ...
        old.angle+search.fine_angle_range
    off=pair_distance/2*[cosd(angle),sind(angle)];
    best=scan_fixed_candidates(centers,off,angle,context,best);
end
assert(best.score>=hole_gap, ...
    '探索結果の最小隙間 %.3f um が設定 %.3f um 未満です。SCRは更新していません。', ...
    best.score*1000,hole_gap*1000);
mid=best.mid;offset=best.offset;
end

function best=scan_fixed_candidates(centers,offset,angle,c,best)
pair_gap=2*norm(offset)-2*c.via_r;
for first=1:128:size(centers,1)
    mid=centers(first:min(first+127,end),:);
    % ペア2個のビアを含む矩形と、六角形中心を結ぶ矩形領域。
    left=min(0,mid(:,1)-abs(offset(1))-c.via_r-c.land);
    right=max(0,mid(:,1)+abs(offset(1))+c.via_r+c.land);
    bottom=min(0,mid(:,2)-abs(offset(2))-c.via_r-c.land);
    top=max(0,mid(:,2)+abs(offset(2))+c.via_r+c.land);
    tab_gap=inf(size(left));
    for k=1:size(c.shifts,1)
        sh=c.shifts(k,:);
        for j=1:size(c.rows,1)
            row=c.rows(j,:);
            dx=max(max(left-row(2)-sh(1),row(1)+sh(1)-right),0);
            dy=max(max(bottom-row(3)-sh(2),row(3)+sh(2)-top),0);
            tab_gap=min(tab_gap,hypot(dx,dy)-c.r);
        end
        for j=1:size(c.bridges,1)
            b=c.bridges(j,:);
            dx=max(max(left-b(2)-sh(1),b(1)+sh(1)-right),0);
            dy=max(max(bottom-b(4)-sh(2),b(3)+sh(2)-top),0);
            tab_gap=min(tab_gap,hypot(dx,dy));
        end
        dx=max(max(left-right-sh(1),left+sh(1)-right),0);
        dy=max(max(bottom-top-sh(2),bottom+sh(2)-top),0);
        tab_gap=min(tab_gap,hypot(dx,dy));
    end
    usable=tab_gap>=c.required_pattern_gap;
    if ~any(usable),continue;end
    ix=find(usable);selected=mid(ix,:);clearance=inf(numel(ix),1);
    for sign=[-1,1]
        p=selected+sign*offset;
        dc=min(hypot(p(:,1)-c.obstacles(:,1).',p(:,2)-c.obstacles(:,2).'),[],2) ...
            -c.circle_r-c.opening_r;
        dx=max(abs(p(:,1)-c.squares(:,1).')-c.side/2,0);
        dy=max(abs(p(:,2)-c.squares(:,2).')-c.side/2,0);
        ds=min(hypot(dx,dy),[],2)-c.opening_r;
        clearance=min(clearance,min(dc,ds));
    end
    score=min(clearance,pair_gap);
    [value,j]=max(score);k=ix(j);
    if value>best.score
        best=struct('score',value,'mid',mid(k,:),'offset',offset,'angle',angle, ...
            'opening_gap',clearance(j),'pattern_gap',tab_gap(k),'pair_gap',pair_gap);
    end
end
end

function distance=square_clearance(points,centers,side,radius)
distance=inf;
for first=1:32:size(points,1)
    p=points(first:min(first+31,end),:);
    dx=max(abs(p(:,1)-centers(:,1).')-side/2,0);
    dy=max(abs(p(:,2)-centers(:,2).')-side/2,0);
    distance=min(distance,min(hypot(dx,dy),[],'all')-radius);
end
end

function distance=polygon_gap(a,b)
[x,y]=boundary(a);p=[x,y];[x,y]=boundary(b);q=[x,y];
assert(all(isfinite(p),'all') && all(isfinite(q),'all'),'複数境界は未対応です。');
if norm(p(1,:)-p(end,:))>1e-10,p(end+1,:)=p(1,:);end
if norm(q(1,:)-q(end,:))>1e-10,q(end+1,:)=q(1,:);end
distance=min(points_to_segments(p,q),points_to_segments(q,p));
end

function distance=points_to_segments(p,q)
a=q(1:end-1,:);v=diff(q,1,1);vv=sum(v.^2,2).';
valid=vv>1e-20;a=a(valid,:);v=v(valid,:);vv=vv(valid);
distance=inf;
for first=1:64:size(p,1)
    c=p(first:min(first+63,end),:);
    dx=c(:,1)-a(:,1).';dy=c(:,2)-a(:,2).';
    t=max(0,min(1,(dx.*v(:,1).'+dy.*v(:,2).')./vv));
    distance=min(distance,min(hypot(dx-t.*v(:,1).',dy-t.*v(:,2).'),[],'all'));
end
end
