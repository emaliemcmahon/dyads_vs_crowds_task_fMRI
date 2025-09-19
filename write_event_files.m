function write_event_files(subjName,run_number,data, task)
% % Makes the para files from the run of the localizer.
% %%Written by EG McMahon
%
if nargin < 1
    subjName=77;
    run_number=1;
end

%% BIDS

%TSV
%TSV files expected in BIDS format
bidsoutpath = fullfile('data', ['sub-',sprintf('%02d', subjName)], 'bids');
if ~exist(bidsoutpath); mkdir(bidsoutpath); end
bids_sname = ['sub-',sprintf('%02d', subjName)];

data = removevars(data, {'added_TRs', 'movie_path', 'offset_time', ...
    'cond_num', 'response_trial', 'condition', ...
    'modality', 'caption', 'onset', 'response'});
data = movevars(data, 'trial_type', 'After', 'duration');
data = movevars(data, 'video_name', 'After', 'response_time');

data.Properties.VariableNames = {'onset' 'duration' 'trial_type' 'response_time' 'stim_file'};

% Round values
data.onset = round(data.onset);
data.duration = round(data.duration);
data.response_time = round(data.response_time, 2);

bids_filename = fullfile(bidsoutpath, [bids_sname, '_ses-01_task-', task,'_run-', sprintf('%02d', run_number),'_events']);
writetable(data,[bids_filename,'.tsv'], 'FileType','text', 'Delimiter', '\t');

%% JSON

%onset
j.onset.LongName = 'Stimulus onset time';
j.onset.Description = 'Time of the stimulus onset in seconds relative to the beginning of the experiment t=0.';

%duration
j.duration.LongName = 'Stimulus duration';
j.duration.Description = 'Duration of the stimulus presentation in seconds.';

%trial_type
j.trial_type.LongName = 'Stimulus condition type';
j.trial_type.Description = 'The condition of the stimulus being presented in a given block';
if strcmp(task, 'vision')
    j.trial_type.Levels.crowd_vision = 'Target trials in which there is a crowd in a video';
    j.trial_type.Levels.communication_vision = 'Videos of two people communicating.';
    j.trial_type.Levels.independent_vision  = 'Videos of two people performing common actions independent of one another.';
    j.trial_type.Levels.joint_vision = 'Videos of two people performing social but non-communicative interactions (e.g., dancing, boxing).';
else
    j.trial_type.Levels.crowd_language = 'Target trials in which there is a crowd described in a sentence';
    j.trial_type.Levels.communication_language = 'Sentences describing two people communicating.';
    j.trial_type.Levels.independent_language = 'Sentences describing two people performing common actions independent of one another.';
    j.trial_type.Levels.joint_language = 'Sentences describing two people performing social but non-communicative interactions (e.g., dancing, boxing).';
end

%response_time
j.reseponse_time.LongName = 'Participant response in seconds relative to the start of the experiment';
j.response_time.Description = 'The participant responded during a trial. Participants should responded to crowd trials.';

%stim_file
j.stim_file.LongName = 'The stimulus file name';
j.stim_file.Descriptions = 'The name of the stimulus that was presented';

%Stimulus presentation
if ispc
    opsys = system_dependent('getwinsys');
elseif ismac
    opsys = system_dependent('getos');
elseif isunix
    opsys = computer;
end

j.StimulusPresentation.OperatingSystem = opsys;
j.StimulusPresentation.SoftwareName = 'Psychtoolbox';
j.StimulusPresentation.SoftwareRRID = 'SCR_002881';
v = split(PsychtoolboxVersion,' ');
j.StimulusPresentation.SoftwareVersion = v{1};
j.StimulusPresentation.MATLABVersion = version;

encodedJSON = jsonencode(j,'PrettyPrint',true); %encode JSON

fid = fopen([bids_filename, '.json'],'w');
fprintf(fid, encodedJSON);