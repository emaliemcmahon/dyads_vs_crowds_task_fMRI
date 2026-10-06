function result = make_session3_runfiles(subjName, varargin)
% Makes new video run files for a returning participant (session 3).
%
%   make_session3_runfiles(subjName)
%   make_session3_runfiles(subjName, 'NRuns', 12, 'DryRun', true, ...)
%
% The new runs continue from the last completed video run, so
% dyads_v_crowds(subjName, [], 'videos') picks up where the participant
% left off. Run files that were never run (no timing file) are moved to
% runfiles/archive_<timestamp>/ before the new files are written. Files for
% completed runs and all sentence files are never touched.
%
% The presentation order is chosen to be as uncorrelated as possible with
% the order the participant already saw the sentences (weight WSent) and,
% secondarily, the videos (weight WVid). Two kinds of order are compared:
%   - pairwise temporal proximity: for every pair of items, how close in
%     time they were shown within a run (0 if never in the same run)
%   - item position: mean position within a run and mean run index
% Random draws from generate_run_tables are improved by swapping
% same-condition items within a repeat, which keeps the optseq timing and
% the balance of each repeat.
%
% Options
%   NRuns     : number of new video runs (default 12 = 4 repeats)
%   DataRoot  : folder containing sub-XX folders (default <repo>/data)
%   WSent     : weight on decorrelation from sentence order (default 1)
%   WVid      : weight on decorrelation from earlier video order (default 0.25)
%   NRestarts : number of random starting draws (default 5)
%   NSwaps    : swap attempts per start (default 5000)
%   Seed      : random seed (default: shuffled and recorded)
%   DryRun    : report what would be moved/written without writing (default false)
%
% %%Written by EG McMahon

here = fileparts(mfilename('fullpath'));
p = inputParser;
addParameter(p, 'NRuns', 12);
addParameter(p, 'DataRoot', fullfile(here, 'data'));
addParameter(p, 'WSent', 1);
addParameter(p, 'WVid', 0.25);
addParameter(p, 'NRestarts', 5);
addParameter(p, 'NSwaps', 5000);
addParameter(p, 'Seed', []);
addParameter(p, 'DryRun', false);
parse(p, varargin{:});
opt = p.Results;

topout = fullfile(opt.DataRoot, ['sub-', sprintf('%02d', subjName)]);
runfiles = fullfile(topout, 'runfiles');
timingout = fullfile(topout, 'timingfiles');
matout = fullfile(topout, 'matfiles');
if ~exist(topout, 'dir')
    error('No data folder for subject %g: %s', subjName, topout);
end

if isempty(opt.Seed)
    rng('shuffle');
    s = rng;
    opt.Seed = s.Seed;
end
rng(opt.Seed, 'twister');

%% Items
copts = detectImportOptions(fullfile(here, 'sentence_captions.csv'));
copts.SelectedVariableNames = {'video_name', 'condition'};
copts = setvartype(copts, {'video_name', 'condition'}, 'char');
captions = readtable(fullfile(here, 'sentence_captions.csv'), copts);
items = captions.video_name(~contains(captions.condition, 'crowd'));
n_items = numel(items);

%% What the participant has already seen
hist = struct();
hist.sent = read_history(timingout, 'sentences', items);
hist.vid = read_history(timingout, 'videos', items);
weights = struct('sent', opt.WSent, 'vid', opt.WVid);
if hist.sent.n_runs == 0
    warning('sub-%02d has no completed sentence runs.', subjName);
    weights.sent = 0;
end
if hist.vid.n_runs == 0
    weights.vid = 0;
end

last = max([0, completed_runs(timingout, matout, 'videos')]);
if last == 0
    warning('sub-%02d has no completed video runs; new runs will start at 1.', subjName);
end
fprintf('sub-%02d: %d sentence runs and %d video runs completed (last video run %02d).\n', ...
    subjName, hist.sent.n_runs, hist.vid.n_runs, last);

%% Search
ut = triu(true(n_items), 1);
H = prepare_history(hist, ut);
n_repeats = ceil(opt.NRuns / 3);

best_cost = inf;
for irestart = 1:opt.NRestarts
    [runs, info] = generate_run_tables('videos', n_repeats, ...
        'Seed', opt.Seed + irestart - 1);
    runs = runs(1:opt.NRuns);
    c = make_candidate(runs, info.repeat_of_run(1:opt.NRuns), items);
    cost = candidate_cost(c, c.item, H, weights, ut);
    if irestart == 1
        random_corrs = candidate_corrs(c, c.item, H, ut);
    end

    for iswap = 1:opt.NSwaps
        a = randi(numel(c.item));
        partners = c.partners{a};
        b = partners(randi(numel(partners)));
        trial_item = c.item;
        trial_item([a b]) = trial_item([b a]);
        trial_cost = candidate_cost(c, trial_item, H, weights, ut);
        if trial_cost < cost
            c.item = trial_item;
            cost = trial_cost;
        end
    end

    if cost < best_cost
        best_cost = cost;
        best = c;
        best_runs = runs;
        best_info = info;
    end
end

best_corrs = candidate_corrs(best, best.item, H, ut);
for r = 1:opt.NRuns
    rows = best.row(best.run == r);
    best_runs{r}.video_name(rows) = items(best.item(best.run == r));
end

fprintf('\nCorrelation with past order     random draw   chosen\n');
names = fieldnames(best_corrs);
for i = 1:numel(names)
    fprintf('  %-28s %8.3f   %8.3f\n', names{i}, random_corrs.(names{i}), best_corrs.(names{i}));
end
fprintf('For reference, this subject''s sentence vs video item-position correlation so far: %.3f\n', ...
    H.sent_vs_vid_pos);

%% Write
stamp = datestr(datetime('now'), 'yyyymmddTHHMMSS');
targets = last + (1:opt.NRuns);
target_files = arrayfun(@(r) fullfile(runfiles, sprintf('videos-%02d.csv', r)), ...
    targets, 'UniformOutput', false);
unrun = dir(fullfile(runfiles, 'videos-*.csv'));
unrun_nums = cellfun(@(n) str2double(regexp(n, '\d+', 'match', 'once')), {unrun.name});
unrun = unrun(unrun_nums > last);
base_stamp = stamp;
k = 1;
while exist(fullfile(runfiles, ['archive_', stamp]), 'dir') || ...
        exist(fullfile(runfiles, ['session3_qa_', stamp, '.json']), 'file')
    k = k + 1;
    stamp = sprintf('%s_%d', base_stamp, k);
end
archive = fullfile(runfiles, ['archive_', stamp]);

result.subject = subjName;
result.created = stamp;
result.seed = opt.Seed;
result.options = rmfield(opt, 'DataRoot');
result.last_completed_video_run = last;
result.new_runs = targets;
result.archived = {unrun.name};
result.archive_folder = archive;
result.optseq_files = best_info.optseq_files(1:opt.NRuns);
result.n_sentence_runs_seen = hist.sent.n_runs;
result.n_video_runs_seen = hist.vid.n_runs;
result.corr_random_draw = random_corrs;
result.corr_chosen = best_corrs;
result.sent_vs_vid_position_corr_so_far = H.sent_vs_vid_pos;

if opt.DryRun
    fprintf('\nDRY RUN, nothing written.\n');
    fprintf('Would move %d never-run files to %s\n', numel(unrun), archive);
    fprintf('Would write videos-%02d to videos-%02d in %s\n', targets(1), targets(end), runfiles);
    return
end

% Safety: nothing at or after the first new run may have been run already
if any(completed_runs(timingout, matout, 'videos') >= targets(1))
    error('Found timing or mat files for run %02d or later. Nothing was changed.', targets(1));
end

if ~isempty(unrun)
    mkdir(archive);
    for i = 1:numel(unrun)
        movefile(fullfile(runfiles, unrun(i).name), fullfile(archive, unrun(i).name));
    end
    fprintf('Moved %d never-run files to %s\n', numel(unrun), archive);
end
for r = 1:opt.NRuns
    if exist(target_files{r}, 'file')
        error('%s still exists after archiving. Stopping.', target_files{r});
    end
    writetable(best_runs{r}, target_files{r});
end
fid = fopen(fullfile(runfiles, ['session3_qa_', stamp, '.json']), 'w');
fprintf(fid, '%s', jsonencode(result, 'PrettyPrint', true));
fclose(fid);
fprintf('Wrote videos-%02d to videos-%02d for sub-%02d.\n', targets(1), targets(end), subjName);
end


function runs = completed_runs(timingout, matout, task)
% Run numbers with a timing or mat file (any attempt)
f = [dir(fullfile(timingout, ['task-', task, '_run-*'])); ...
    dir(fullfile(matout, ['task-', task, '_run-*']))];
tok = regexp({f.name}, '_run-(\d+)_', 'tokens', 'once');
tok = tok(~cellfun('isempty', tok));
runs = unique(cellfun(@(t) str2double(t{1}), tok));
end


function h = read_history(timingout, task, items)
% Presented order of non-crowd items from every timing file of a task
n = numel(items);
h.P = zeros(n);
pos_sum = zeros(n, 1); ord_sum = zeros(n, 1); count = zeros(n, 1);

files = dir(fullfile(timingout, ['task-', task, '_run-*.csv']));
tok = regexp({files.name}, '_run-(\d+)_', 'tokens', 'once');
run_num = cellfun(@(t) str2double(t{1}), tok);
run_list = unique(run_num);
h.n_runs = numel(run_list);

for i = 1:numel(files)
    fname = fullfile(files(i).folder, files(i).name);
    o = detectImportOptions(fname);
    o.SelectedVariableNames = {'video_name', 'onset_time', 'response_trial'};
    o = setvartype(o, 'video_name', 'char');
    T = readtable(fname, o);
    T = T(T.response_trial == 0 & T.onset_time > 0, :);
    [shown, idx] = ismember(T.video_name, items);
    idx = idx(shown);
    t = T.onset_time(shown);
    [t, order] = sort(t);
    idx = idx(order);
    m = numel(idx);
    if m < 2; continue; end

    L = t(end) - t(1);
    h.P(idx, idx) = h.P(idx, idx) + (1 - abs(t - t') / L);
    pos_sum(idx) = pos_sum(idx) + (0:m-1)' / (m - 1);
    run_rank = find(run_list == run_num(i));
    ord_sum(idx) = ord_sum(idx) + (run_rank - 1) / max(1, numel(run_list) - 1);
    count(idx) = count(idx) + 1;
end
h.pos = pos_sum ./ count;   % NaN for items never shown
h.ord = ord_sum ./ count;
end


function H = prepare_history(hist, ut)
% Pre-normalized history vectors so each cost evaluation is cheap
for f = {'sent', 'vid'}
    k = f{1};
    v = hist.(k).P(ut);
    v = v - mean(v);
    H.(k).P = v / max(norm(v), eps);
    H.(k).valid = ~isnan(hist.(k).pos);
    H.(k).pos = standardize(rank_avg(hist.(k).pos(H.(k).valid)));
    H.(k).ord = standardize(rank_avg(hist.(k).ord(H.(k).valid)));
end
both = H.sent.valid & H.vid.valid;
H.sent_vs_vid_pos = sum(standardize(rank_avg(hist.sent.pos(both))) .* ...
    standardize(rank_avg(hist.vid.pos(both))));
end


function c = make_candidate(runs, repeat_of_run, items)
% Flattens the non-crowd slots of all runs into vectors
run = []; row = []; t = []; cond = {}; item = [];
for r = 1:numel(runs)
    rows = find(runs{r}.response_trial == 0);
    [~, it] = ismember(runs{r}.video_name(rows), items);
    run = [run; repmat(r, numel(rows), 1)]; %#ok<AGROW>
    row = [row; rows]; %#ok<AGROW>
    t = [t; runs{r}.onset(rows)]; %#ok<AGROW>
    cond = [cond; runs{r}.condition(rows)]; %#ok<AGROW>
    item = [item; it]; %#ok<AGROW>
end
c.run = run; c.row = row; c.t = t; c.item = item;
c.n_runs = numel(runs);
c.n_items = numel(items);
c.rep = repeat_of_run(run);

% Slots whose items can be swapped: same condition and same repeat
c.partners = cell(numel(item), 1);
for a = 1:numel(item)
    same = find(strcmp(cond, cond{a}) & c.rep == c.rep(a));
    c.partners{a} = same(same ~= a);
end

% Position of each slot within its run, and run index
c.slot_pos = zeros(numel(item), 1);
c.run_slots = cell(c.n_runs, 1);
c.prox = cell(c.n_runs, 1);
for r = 1:c.n_runs
    s = find(run == r);
    [~, order] = sort(t(s));
    s = s(order);
    c.run_slots{r} = s;
    c.slot_pos(s) = (0:numel(s)-1)' / (numel(s) - 1);
    ts = t(s);
    c.prox{r} = 1 - abs(ts - ts') / (ts(end) - ts(1));
end
c.slot_ord = (run - 1) / max(1, c.n_runs - 1);
end


function [P, pos, ord] = candidate_features(c, item)
P = zeros(c.n_items);
for r = 1:c.n_runs
    it = item(c.run_slots{r});
    P(it, it) = P(it, it) + c.prox{r};
end
count = accumarray(item, 1, [c.n_items 1]);
pos = accumarray(item, c.slot_pos, [c.n_items 1]) ./ count;
ord = accumarray(item, c.slot_ord, [c.n_items 1]) ./ count;
% Items left out of a partial final repeat get a neutral value
pos(count == 0) = 0.5;
ord(count == 0) = 0.5;
end


function r = feature_corrs(P, pos, ord, Hk, ut)
v = P(ut);
v = v - mean(v);
r.pair = sum(v / max(norm(v), eps) .* Hk.P);
r.pos = sum(standardize(rank_avg(pos(Hk.valid))) .* Hk.pos);
r.ord = sum(standardize(rank_avg(ord(Hk.valid))) .* Hk.ord);
end


function cost = candidate_cost(c, item, H, w, ut)
[P, pos, ord] = candidate_features(c, item);
cost = 0;
for f = {'sent', 'vid'}
    k = f{1};
    if w.(k) == 0; continue; end
    r = feature_corrs(P, pos, ord, H.(k), ut);
    cost = cost + w.(k) * (abs(r.pair) + abs(r.pos) + abs(r.ord));
end
end


function out = candidate_corrs(c, item, H, ut)
[P, pos, ord] = candidate_features(c, item);
s = feature_corrs(P, pos, ord, H.sent, ut);
v = feature_corrs(P, pos, ord, H.vid, ut);
out = struct('sent_pairwise_proximity', s.pair, 'sent_position_in_run', s.pos, ...
    'sent_run_index', s.ord, 'vid_pairwise_proximity', v.pair, ...
    'vid_position_in_run', v.pos, 'vid_run_index', v.ord);
end


function z = standardize(x)
% Unit-norm, zero-mean, so a dot product is a correlation
x = x - mean(x);
z = x / max(norm(x), eps);
end


function r = rank_avg(x)
% Ranks with ties averaged (as in Spearman's rho)
[xs, order] = sort(x(:));
n = numel(xs);
r = zeros(n, 1);
k = 1;
while k <= n
    j = k;
    while j < n && xs(j + 1) == xs(k)
        j = j + 1;
    end
    r(order(k:j)) = (k + j) / 2;
    k = j + 1;
end
end
