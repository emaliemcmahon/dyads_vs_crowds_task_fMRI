function info = session_info(topout, task, current_saved)
% Works out the session, task run, and BIDS run for a subject from the
% files already saved in topout (data/sub-XX).
%
%   info = session_info(topout, task)        % before a run starts
%   info = session_info(topout, task, true)  % after the current run's
%                                            % matfile has been saved
%
% session   : each unique date with a matfile (any task) is a session, so
%             the third unique date is session 3. Today counts as a new
%             session if nothing has been saved today.
% run       : next task run (runfiles/<task>-NN.csv) = last run with a
%             timing or mat file + 1. Before the run only.
% bids_run  : runs of this task saved today, including the current one.
%
% %%Written by EG McMahon

if nargin < 3; current_saved = false; end

today_ymd = datestr(datetime('now'), 'yyyymmdd');
mats = dir(fullfile(topout, 'matfiles', 'task-*_run-*_*.mat'));
timing = dir(fullfile(topout, 'timingfiles', 'task-*_run-*_*.csv'));
saved = [{mats.name}, {timing.name}];

tok = regexp(saved, '^task-(.+)_run-(\d+)_(\d{8})T\d{6}\.(mat|csv)$', 'tokens', 'once');
ok = ~cellfun('isempty', tok);
tok = vertcat(tok{ok});
if isempty(tok); tok = cell(0, 4); end
file_task = tok(:, 1);
file_run = str2double(tok(:, 2));
file_date = tok(:, 3);
is_mat = strcmp(tok(:, 4), 'mat');

info.past_dates = setdiff(unique(file_date(is_mat)), {today_ymd});
info.session = numel(info.past_dates) + 1;

this_task = strcmp(file_task, task);
info.last_run = max([0; file_run(this_task)]);
info.run = info.last_run + 1;

n_today = sum(this_task & is_mat & strcmp(file_date, today_ymd));
if current_saved
    info.bids_run = max(n_today, 1);
else
    info.bids_run = n_today + 1;
end
end
