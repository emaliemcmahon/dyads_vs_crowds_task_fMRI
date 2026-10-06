function files = assign_conditions(subjName, task, varargin)
% Makes the run files for a subject and task.
%
%   assign_conditions(subjName, task)
%   assign_conditions(subjName, task, 'NRepeats', n, 'OutRoot', root, 'Seed', s)
%
% Writes <OutRoot>/sub-XX/runfiles/<task>-NN.csv and a generation log.
% Refuses to overwrite existing run files.
%
% Defaults: NRepeats = 8 for videos (24 runs), 5 for sentences (20 runs).
%           OutRoot  = <repo>/data
%
% %%Written by EG McMahon

here = fileparts(mfilename('fullpath'));
p = inputParser;
addParameter(p, 'NRepeats', []);
addParameter(p, 'OutRoot', fullfile(here, 'data'));
addParameter(p, 'Seed', []);
parse(p, varargin{:});
opt = p.Results;

if isempty(opt.NRepeats)
    if strcmp(task, 'videos'); opt.NRepeats = 8; else; opt.NRepeats = 5; end
end

topout = fullfile(opt.OutRoot, ['sub-', sprintf('%02d', subjName)]);
runfiles = fullfile(topout, 'runfiles');

[runs, info] = generate_run_tables(task, opt.NRepeats, 'Seed', opt.Seed);

files = cell(numel(runs), 1);
for irun = 1:numel(runs)
    files{irun} = fullfile(runfiles, sprintf('%s-%02d.csv', task, irun));
end
existing = files(cellfun(@(f) exist(f, 'file') == 2, files));
if ~isempty(existing)
    error('Run files already exist and will not be overwritten:\n%s', ...
        strjoin(existing, newline));
end

for d = {runfiles, fullfile(topout, 'matfiles'), fullfile(topout, 'timingfiles')}
    if ~exist(d{1}, 'dir'); mkdir(d{1}); end
end
for irun = 1:numel(runs)
    writetable(runs{irun}, files{irun});
end

write_generation_log(fullfile(runfiles, ['generation_log_', task, '.json']), ...
    info, subjName, files);
fprintf('Wrote %d %s run files for sub-%02d (seed %d).\n', ...
    numel(runs), task, subjName, info.seed);
end


function write_generation_log(fname, info, subjName, files)
[~, commit] = system(['git -C "', fileparts(mfilename('fullpath')), ...
    '" rev-parse HEAD 2>/dev/null']);
log.subject = subjName;
log.created = datestr(datetime('now'), 'yyyy-mm-ddTHH:MM:SS');
log.git_commit = strtrim(commit);
log.generation = info;
[~, names, ext] = cellfun(@fileparts, files, 'UniformOutput', false);
log.files = strcat(names, ext);
fid = fopen(fname, 'w');
fprintf(fid, '%s', jsonencode(log, 'PrettyPrint', true));
fclose(fid);
end
