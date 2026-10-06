function [runs, info] = generate_run_tables(task, n_repeats, varargin)
% Builds randomized run tables for the dyads vs crowds task. Writes nothing.
%
%   [runs, info] = generate_run_tables(task, n_repeats, 'Seed', s, ...)
%
% task      : 'videos' or 'sentences'
% n_repeats : number of full passes through all stimuli. Each pass is split
%             into 3 runs (videos) or 4 runs (sentences).
%
% Each repeat draws an independent permutation of the items in every
% condition, so run membership is not coupled across conditions, and the
% items are randomly ordered within each run. Every run uses a different
% optseq sequence.
%
% runs : cell array of tables with columns
%        onset, cond_num, condition, video_name, added_TRs, response_trial,
%        modality, trial_type
% info : struct with seed, optseq files used, and the repeat of each run
%
% %%Written by EG McMahon

p = inputParser;
here = fileparts(mfilename('fullpath'));
addParameter(p, 'Seed', []);
addParameter(p, 'OptseqPath', fullfile(here, 'optseq'));
addParameter(p, 'CaptionFile', fullfile(here, 'sentence_captions.csv'));
addParameter(p, 'TR', 2);
parse(p, varargin{:});
opt = p.Results;

%% Random seed
if isempty(opt.Seed)
    rng('shuffle');
    s = rng;
    seed = s.Seed;
else
    seed = opt.Seed;
end
rng(seed, 'twister');

%% Task settings
switch task
    case 'videos'
        modality = 'vision';
        n_splits = 3;
    case 'sentences'
        modality = 'language';
        n_splits = 4;
    otherwise
        error('Unknown task "%s". Use ''videos'' or ''sentences''.', task);
end

%% Stimuli
copts = detectImportOptions(opt.CaptionFile);
copts.SelectedVariableNames = {'video_name', 'condition'};
copts = setvartype(copts, {'video_name', 'condition'}, 'char');
captions = readtable(opt.CaptionFile, copts);

is_crowd = contains(captions.condition, 'crowd');
crowd_videos = captions.video_name(is_crowd);
conds = unique(captions.condition(~is_crowd), 'stable');
items = cell(numel(conds), 1);
for ic = 1:numel(conds)
    items{ic} = captions.video_name(strcmp(captions.condition, conds{ic}));
    if mod(numel(items{ic}), n_splits) ~= 0
        error('%d %s items cannot be split evenly into %d runs.', ...
            numel(items{ic}), conds{ic}, n_splits);
    end
end

%% Optseq sequences (sampled without replacement)
par_files = dir(fullfile(opt.OptseqPath, [task, '-*.par']));
par_files = sort({par_files.name});
n_runs = n_repeats * n_splits;
if n_runs > numel(par_files)
    error('%d runs requested but only %d optseq files exist for %s.', ...
        n_runs, numel(par_files), task);
end
par_files = par_files(randperm(numel(par_files), n_runs));

%% Build runs
runs = cell(n_runs, 1);
repeat_of_run = zeros(n_runs, 1);
irun = 0;
for irep = 1:n_repeats
    % Independent split of each condition into n_splits runs
    splits = cell(numel(conds), 1);
    for ic = 1:numel(conds)
        cur = items{ic};
        splits{ic} = reshape(cur(randperm(numel(cur))), [], n_splits);
    end

    for isplit = 1:n_splits
        irun = irun + 1;
        repeat_of_run(irun) = irep;
        seq = read_par(fullfile(opt.OptseqPath, par_files{irun}));
        seq.video_name = repmat({''}, height(seq), 1);

        for ic = 1:numel(conds)
            slots = find(strcmp(seq.condition, [conds{ic}, '_', modality]));
            vids = splits{ic}(:, isplit);
            if numel(slots) ~= numel(vids)
                error('%s has %d %s slots but %d items are assigned.', ...
                    par_files{irun}, numel(slots), conds{ic}, numel(vids));
            end
            seq.video_name(slots) = vids(randperm(numel(vids)));
        end

        slots = find(contains(seq.condition, 'crowd'));
        crowd_order = crowd_videos(randperm(numel(crowd_videos)));
        n_fill = min(numel(slots), numel(crowd_order));
        seq.video_name(slots(1:n_fill)) = crowd_order(1:n_fill);

        runs{irun} = format_run(seq, opt.TR);
    end
end

info.seed = seed;
info.task = task;
info.n_repeats = n_repeats;
info.optseq_files = par_files;
info.repeat_of_run = repeat_of_run;
end


function seq = read_par(file)
% Reads an optseq .par file: onset, cond_num, duration, weight, condition
fid = fopen(file, 'r');
c = textscan(fid, '%f %f %f %f %s');
fclose(fid);
seq = table(c{1}, c{2}, c{3}, c{5}, ...
    'VariableNames', {'onset', 'cond_num', 'duration', 'condition'});
end


function T = format_run(seq, TR)
% A trial followed by a NULL event gets the extra TRs of that NULL,
% then NULL rows are dropped.
n = height(seq);
added_TRs = zeros(n, 1);
for i = 1:n-1
    if seq.cond_num(i) ~= 0 && seq.cond_num(i+1) == 0
        added_TRs(i) = seq.duration(i+1) / TR - 1;
    end
end
keep = seq.cond_num ~= 0;
seq = seq(keep, :);
added_TRs = added_TRs(keep);

parts = split(seq.condition, '_', 2);
condition = parts(:, 1);
modality = parts(:, 2);
response_trial = double(strcmp(condition, 'crowd'));

T = table(seq.onset, seq.cond_num, condition, seq.video_name, added_TRs, ...
    response_trial, modality, seq.condition, ...
    'VariableNames', {'onset', 'cond_num', 'condition', 'video_name', ...
    'added_TRs', 'response_trial', 'modality', 'trial_type'});
end
