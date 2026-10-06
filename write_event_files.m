function write_event_files(subjName, run_number, data, task, session_number, bids_run_number, run_completed)
% Makes the BIDS events + JSON files for a run.
% Session (ses-XX) and BIDS run numbering come from session_info: each
% unique date with a matfile (any task) is a session.
%
% dyads_v_crowds passes session_number / bids_run_number in. If they are
% not passed, they are computed from the existing matfiles.
% run_completed (default true): false for a run stopped early; the JSON
% sidecar then notes that only the presented trials are listed.
%
% %%Written by EG McMahon
%
if nargin < 1
    subjName=77;
    run_number=1;
    data=readtable('/Users/emaliem/Dropbox/mit_projects/verbal_com/video_sentence_fMRI_tasks/dyads_vs_crowds_task_fMRI/data/sub-77/timingfiles/task-sentences_run-01_20250919T153436.csv');
    task='sentence'; 
end

if nargin < 7 || isempty(run_completed); run_completed = true; end

%% Paths
topout = fullfile('data', ['sub-',sprintf('%02d', subjName)]);
matout = fullfile(topout, 'matfiles');
timingout = fullfile(topout, 'timingfiles');

%% --- START: Session + BIDS run (see session_info.m) ---
% dyads_v_crowds passes these in. When called on its own, they are worked
% out from the saved files, counting the current run as already saved.
if nargin < 5 || isempty(session_number) || nargin < 6 || isempty(bids_run_number)
    sinfo = session_info(topout, task, true);
    computed_session = sinfo.session;
    computed_bidsrun = sinfo.bids_run;
end

% Respect passed-in values if provided; otherwise use computed
if nargin < 5 || isempty(session_number);   session_number  = computed_session;  end
if nargin < 6 || isempty(bids_run_number);  bids_run_number = computed_bidsrun; end

% Print to console
fprintf('[INFO] Task: %s | Subject: %02d | Input run (runfiles): %02d | Session: %02d | BIDS run today: %02d\n', ...
        task, subjName, run_number, session_number, bids_run_number);
%% --- END: Session + BIDS run ---

%% BIDS (TSV)
bidsoutpath = fullfile('data', ['sub-',sprintf('%02d', subjName)], 'bids');
if ~exist(bidsoutpath, 'dir'); mkdir(bidsoutpath); end
bids_sname = ['sub-',sprintf('%02d', subjName)];

% Strip/move variables to BIDS columns
data = removevars(data, {'added_TRs', 'movie_path', 'offset_time', ...
    'cond_num', 'response_trial', ...
    'modality', 'caption', 'onset', 'response'});
data = movevars(data, 'trial_type', 'After', 'duration');
data = movevars(data, 'video_name', 'After', 'response_time');
data = movevars(data, 'condition', 'After', 'video_name');

data.Properties.VariableNames = {'onset' 'duration' 'trial_type' 'response_time' 'stim_file' 'condition'};

% Round values
data.onset = round(data.onset);
data.duration = round(data.duration);
data.response_time = round(data.response_time, 2);

% Use per-session run numbering
bids_filename = fullfile(bidsoutpath, ...
    [bids_sname, '_ses-', sprintf('%02d', session_number), ...
     '_task-', task, '_run-', sprintf('%02d', bids_run_number), '_events']);

writetable(data,[bids_filename,'.tsv'], 'FileType','text', 'Delimiter', '\t');

%% BIDS (JSON sidecar)
% onset
j.onset.LongName = 'Stimulus onset time';
j.onset.Description = 'Time of the stimulus onset in seconds relative to the beginning of the experiment t=0.';

% duration
j.duration.LongName = 'Stimulus duration';
j.duration.Description = 'Duration of the stimulus presentation in seconds.';

% trial_type
j.trial_type.LongName = 'Stimulus condition type';
j.trial_type.Description = 'The condition of the stimulus being presented in a given block';
if strcmp(task, 'vision')
    j.trial_type.Levels.crowd_vision = 'Target trials in which there is a crowd in a video';
    j.trial_type.Levels.communication_vision = 'Videos of two people communicating.';
    j.trial_type.Levels.independent_vision  = 'Videos of two people performing common actions independent of one another.';
    j.trial_type.Levels.joint_vision = 'Videos of two people performing social but non-communicative interactions (e.g., dancing, boxing).';
    j.trial_type.Levels.object_vision = 'Videos of dynamic objects.';
else
    j.trial_type.Levels.crowd_language = 'Target trials in which there is a crowd described in a sentence';
    j.trial_type.Levels.communication_language = 'Sentences describing two people communicating.';
    j.trial_type.Levels.independent_language = 'Sentences describing two people performing common actions independent of one another.';
    j.trial_type.Levels.joint_language = 'Sentences describing two people performing social but non-communicative interactions (e.g., dancing, boxing).';
    j.trial_type.Levels.object_language = 'Sentences describing  dynamic objects.';
end

% response_time
j.reseponse_time.LongName = 'Participant response in seconds relative to the start of the experiment';
j.response_time.Description = 'The participant responded during a trial. Participants should responded to crowd trials.';

% stim_file
j.stim_file.LongName = 'The stimulus file name';
j.stim_file.Descriptions = 'The name of the stimulus that was presented';

% condition
j.condition.LongName = 'Stimulus condition type without modality information';
j.condition.Description = 'The condition of the stimulus being presented in a given block';
j.condition.Levels.crowd = 'Target trials in which there is a crowd in a video/sentence';
j.condition.Levels.communication = 'Videos/Sentences of two people communicating.';
j.condition.Levels.independent  = 'Videos/Sentences of two people performing common actions independent of one another.';
j.condition.Levels.joint = 'Videos/Sentences of two people performing social but non-communicative interactions (e.g., dancing, boxing).';
j.condition.Levels.object = 'Videos/Sentences of dynamic objects.';

% Runs stopped early (Esc or error)
if ~run_completed
    j.RunIncomplete = 'The run was stopped before the end. Only the trials that were presented are listed.';
end

% Stimulus presentation metadata
if ispc
    opsys = system_dependent('getwinsys');
elseif ismac
    opsys = system_dependent('getos');
elseif isunix
    opsys = computer;
else
    opsys = 'unknown';
end

j.StimulusPresentation.OperatingSystem = opsys;
j.StimulusPresentation.SoftwareName = 'Psychtoolbox';
j.StimulusPresentation.SoftwareRRID = 'SCR_002881';
v = split(PsychtoolboxVersion,' ');
j.StimulusPresentation.SoftwareVersion = v{1};
j.StimulusPresentation.MATLABVersion = version;

encodedJSON = jsonencode(j,'PrettyPrint',true); %encode JSON
fid = fopen([bids_filename, '.json'],'w');
fprintf(fid, '%s', encodedJSON);
fclose(fid);
