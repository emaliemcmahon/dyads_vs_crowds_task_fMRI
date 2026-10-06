function dyads_v_crowds(subjName, run_number, task)
% Runs one fMRI run of the dyads vs crowds task.
%
%   dyads_v_crowds(subjName)                      % usual call
%   dyads_v_crowds(subjName, run_number)          % force a run number
%   dyads_v_crowds(subjName, run_number, task)    % force run and task
%   dyads_v_crowds(subjName, [], task)            % force the task only
%
% subjName and run_number can be numbers or text: 7, '07', "7" and
% 'sub-07' all mean subject 7 and load the same data/sub-07 run files.
%
% You only need to pass the subject number. Everything else is worked out
% from the subject's saved data:
%   task       : 'sentences' until 8 sentence runs have been finished,
%                then 'videos' (sentences always come before videos).
%   run_number : the run after the last saved run of that task. If the
%                last run was stopped early, you are asked whether to
%                re-run it or continue to the next one.
%   session    : each date with saved data is a session (the third date
%                is session 3). BIDS runs restart at 1 in each session.
%
% Run files are made automatically if a subject has none, and new
% decorrelated video runs are made once at a returning participant's
% first video run of session 3 or later (make_session3_runfiles).
%
% Press Esc to stop a run. The trials shown so far are saved with an
% _incomplete suffix.
%
% Edited by Emalie McMahon June 20, 2025
% Update by EM October 6, 2026
% Updated: session, task run and BIDS run come from session_info and are passed to write_event_files
% Updated: subjName and run_number accept numbers or strings
%
%% Experiment setup
n_sentence_runs = 8;   % sentence runs each participant completes
if nargin < 1
    subjName = 77;
    run_number = [];
    task = 'videos';
    debug = 1;
    with_Eyelink = 0;
else
    if nargin < 2; run_number = []; end
    if nargin < 3; task = ''; end
    debug = 0;
    with_Eyelink = 0;
end

% Subject and run may be given as numbers or text (7, '07', "7", 'sub-07');
% everything below uses the number so the sub-XX folder is always the same
subjName = to_number(subjName, 'subjName');
if ~isempty(run_number); run_number = to_number(run_number, 'run_number'); end
task = char(task);

% make output directories
curr = pwd;
caption_file = fullfile(curr, 'sentence_captions.csv');
topout = fullfile(curr, 'data', ['sub-',sprintf('%02d', subjName)]);
matout = fullfile(topout, 'matfiles');
timingout = fullfile(topout, 'timingfiles');
runfiles = fullfile(topout,'runfiles');
edffiles = fullfile(topout,'edf');
if ~exist(matout, 'dir'); mkdir(matout); end
if ~exist(timingout, 'dir'); mkdir(timingout); end
if ~exist(edffiles, 'dir'); mkdir(edffiles); end

% Pick the task: sentences until n_sentence_runs are finished, then videos
if isempty(task)
    sent = session_info(topout, 'sentences');
    if sent.n_finished < n_sentence_runs
        task = 'sentences';
    else
        task = 'videos';
    end
    fprintf('Task: %s (%d of %d sentence runs finished).\n', task, ...
        min(sent.n_finished, n_sentence_runs), n_sentence_runs);
end


% Make run files if they do not exist yet for this task. A new subject's
% video runs are made once their sentence runs are done, ordered to be
% uncorrelated with the sentence order they saw.
if isempty(dir(fullfile(runfiles, [task, '-*.csv'])))
    fprintf('No %s run files for subject %g. Generating them now.\n', task, subjName);
    if strcmp(task, 'videos') && session_info(topout, 'sentences').n_finished > 0
        make_session3_runfiles(subjName, 'DataRoot', fullfile(curr, 'data'));
    else
        assign_conditions(subjName, task, 'OutRoot', fullfile(curr, 'data'));
    end
end


% Session = number of unique dates with data (today included), task run =
% last saved run of this task + 1, BIDS run = runs of this task today.
sinfo = session_info(topout, task);
session_number = sinfo.session;
bids_run_number = sinfo.bids_run;
if isempty(run_number)
    run_number = sinfo.run;
    if sinfo.last_run_incomplete
        % The last run was stopped early (Esc or error): re-run it or move on
        answer = '';
        while ~any(strcmpi(answer, {'r', 'c'}))
            answer = strtrim(input(sprintf(['Run %d was stopped before it finished.\n', ...
                'Type r to re-run run %d, or c to continue to run %d: '], ...
                sinfo.last_run, sinfo.last_run, sinfo.run), 's'));
        end
        if strcmpi(answer, 'r')
            run_number = sinfo.last_run;
        end
    end
end

% Returning participant (session 3+): make new video runs that are
% decorrelated from what they already saw. Only done once per subject;
% session3_qa_*.json marks that it has been done.
if strcmp(task, 'videos') && session_number >= 3 && ...
        isempty(dir(fullfile(runfiles, 'session3_qa_*.json')))
    fprintf('Session %g for subject %g: making session 3 video run files.\n', session_number, subjName);
    make_session3_runfiles(subjName, 'DataRoot', fullfile(curr, 'data'));
end

ftoread = fullfile(runfiles,[task, '-',sprintf('%02d', run_number),'.csv']);
if ~exist(ftoread, 'file')
    error('No run file %s. All prepared %s runs may be done.', ftoread, task);
end

s=sprintf('Subject number is %g. Session is %g. Run number is %g (BIDS run %g today). ', ...
    subjName, session_number, run_number, bids_run_number);
fprintf('\n%s\n\n ',WrapString(s));

%% Experiment variables
curr_date = datestr(datetime('now'), 'yyyymmddTHHMMSS');
async = 4;
preloadsecs = 2;
rate = 1;
sound = 0;
blocking = 1;

% Font
font_size = 40;
char_per_line = 30;

% Timing
video_duration = 2;
sentence_duration = 4;
frames_per_sec = 30;
total_frames = video_duration*frames_per_sec;
TR_duration = 2;

%Window
background_color = [50 50 50];

% Fixation cross
crossLength = 20; % Length of each line in pixels
crossWidth = 4;   % Width of lines in pixels
crossColor = [255 255 255]; % White color
crossCoords = [[-crossLength crossLength 0 0]; [0, 0, -crossLength crossLength]];

% TRs to wait at start
start_TRs = 3;
start_wait_duration = start_TRs * TR_duration;

% Input keys
KbName('UnifyKeyNames');
triggerKey = {'+'};                                    % The value of the key the scanner sends to the presentation computer
keysToAccept = KbName({'1','1!','2','2@','3','3#','B'}); % Which KbCheck keys to accept as a behavioral response
escapeKey = KbName('ESCAPE');                          % Stops the run; data so far are saved as incomplete

%% load video list
T = readtable(ftoread);
n_trials = height(T);

opts = detectImportOptions(caption_file);   % detect all available columns
opts.SelectedVariableNames = {'video_name','caption','condition'}; % pick only the columns you need
captions = readtable(caption_file, opts);
T = join(T, captions);

%% Make stimulus presentation table
%get filler videos
onset_time = zeros(n_trials, 1);
offset_time = zeros(n_trials, 1);
duration = zeros(n_trials, 1);
response = zeros(n_trials, 1);
response_time = nan(n_trials, 1);

T = addvars(T, onset_time, offset_time, duration, response, response_time);

%Get the name of the first movie
for itrial = 1:n_trials
    video_name = T.video_name{itrial};
    if ~contains(video_name, 'crowd')
        T.movie_path{itrial} = fullfile(curr, 'videos', video_name);
    else
        T.movie_path{itrial} = fullfile(curr, 'crowd_videos', video_name);
    end
end

n_video = 0;
n_sentence = 0;
for i = 1:n_trials
    if strcmp(T.modality{i}, 'vision')
        n_video = n_video + 1;
    else
        n_sentence = n_sentence + 1;
    end
end
total_video_duration = n_video * video_duration;
total_sentence_duration = n_sentence * sentence_duration;
total_isi = start_wait_duration + ((n_video + n_sentence) * TR_duration) ...
    + (sum(T.added_TRs) * TR_duration);

expected_duration_s = total_video_duration + total_sentence_duration + total_isi;
expected_duration_min = round(expected_duration_s/60, 2);
fprintf('Trials: %g\n', n_trials);
fprintf('Total expected duration (s): %g\n', expected_duration_s);
fprintf('Total expected duration (min): %g\n', expected_duration_min);
sca;

movie = zeros(n_trials, 1);

%% Adjust onset info in T
T.onset = T.onset + start_wait_duration; % Adjust start time
T(n_trials+1,:) = T(n_trials,:); % Duplicate last row
T.onset(n_trials+1) = expected_duration_s;

%% open window
commandwindow;
HideCursor;

% Uncomment for debugging with transparent screen
% PsychDebugWindowConfiguration;

%Suppress frogs
Screen('Preference','VisualDebugLevel', 0);

AssertOpenGL;
screen = max(Screen('Screens'));
[win, rect] = Screen('OpenWindow', screen, background_color);
[x0,y0] = RectCenter(rect);
dispSize = [x0-360 y0-270 x0+360 y0+270];
commandwindow;

Screen('Preference', 'ConserveVRAM', 64);
Screen('Preference', 'TextAntiAliasing', 1);
Screen('Preference', 'TextAlphaBlending', 1);
Screen('Preference','TextRenderer', 1);
Screen('TextSize', win, font_size);
Screen('TextStyle', win, 1);
Screen('Blendfunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

priorityLevel=MaxPriority(win);
Priority(priorityLevel);

% Task instructions and start with the trigger
if strcmp(task, 'videos')
    text = 'Hit the button if the video does not depict the actions of many people.';
else
    text='Hit the button if the sentence does not describe the actions of many people.';
end
DrawFormattedText2(text,'win', win, 'sx','center','sy','center', ...
    'xalign','center','yalign', 'center', ...
    'baseColor',[255, 255, 255], 'wrapat', char_per_line, ...
    'xlayout', 'center');
Screen('Flip', win);

%% Init EyeLink

%% Init EyeLink (per-run: rebind to this window, drift-only, per-run EDF)
if with_Eyelink
    % Ensure the link was initialized earlier this MATLAB session.
    % If you have a separate init script, it should have called EyelinkInit(...)
    % and stashed state. We allow a fallback here if not initialized.
    if Eyelink('IsConnected') ~= 1
        % Fallback: initialize link now (messages on); harmless if already up.
        if EyelinkInit(0,1) ~= 1
            error('EyeLink not connected and EyelinkInit failed. Check network (100.1.1.1), cable, host power.');
        end
    end

    % Rebind the EyeLink defaults to THIS run's PTB window so DC UI draws here.
    if isappdata(0,'el')
        baseEl = getappdata(0,'el'); %#ok<NASGU> % (kept for any future use)
    end
    el = EyelinkInitDefaults(win);
    % Match your task’s colors
    el.backgroundcolour        = background_color;
    el.foregroundcolour        = [255 255 255];
    el.msgfontcolour           = el.foregroundcolour;
    el.imgtitlecolour          = el.foregroundcolour;
    el.calibrationtargetcolour = [255 255 255];
    EyelinkUpdateDefaults(el);

    % (Re)tell the tracker your display coordinates for this window
    scrW = RectWidth(rect);  scrH = RectHeight(rect);
    Eyelink('Command','screen_pixel_coords = 0 0 %d %d', scrW-1, scrH-1);
    Eyelink('Message','DISPLAY_COORDS 0 0 %d %d',         scrW-1, scrH-1);

    % Use your existing session-wide parameters (idempotent; ok to repeat)
    Eyelink('command','calibration_area_proportion = 0.5 0.55');
    Eyelink('command','validation_area_proportion  = 0.5 0.5');
    Eyelink('command','recording_parse_type = GAZE');
    Eyelink('command','saccade_acceleration_threshold = 8000');
    Eyelink('command','saccade_velocity_threshold = 30');
    Eyelink('command','saccade_motion_threshold = 0.15');
    Eyelink('command','saccade_pursuit_fixup = 60');
    Eyelink('command','file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
    Eyelink('command','file_sample_data  = LEFT,RIGHT,GAZE,HREF,GAZERES,AREA,HTARGET,STATUS,INPUT');
    Eyelink('command','file_event_data   = GAZE,GAZERES,AREA,VELOCITY,HREF');
    Eyelink('command','link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
    Eyelink('command','link_sample_data  = LEFT,RIGHT,GAZE,HREF,GAZERES,AREA,HTARGET,STATUS,INPUT');
    Eyelink('command','link_event_data   = GAZE,GAZERES,AREA,VELOCITY,HREF');

    % Short per-run EDF name (<=8 chars total). Use task-based 3-letter prefix.
    if strcmp(task,'sentences'), edf_prefix = 'sent'; else, edf_prefix = 'vid'; end
    edfFile = [edf_prefix, sprintf('%03d', run_number)];   % e.g., sent001 / vid003
    if numel(edfFile) > 8, edfFile = edfFile(1:8); end     % ensure 8-char max

    % Open per-run EDF on the host (ok to do this every run)
    status = Eyelink('OpenFile', edfFile);
    if status ~= 0
        error('Could not open EDF file "%s" (must be <=8 chars).', edfFile);
    end

    Eyelink('StartRecording');
    Eyelink('Message','REC_START');
    WaitSecs(0.1);
end

%% WAIT FOR TRIGGER TO START
still_loading = 1;
if ~debug
    while 1
        FlushEvents;
        trig = GetChar;
        if any(strcmp(trig, triggerKey))
            break;
        end
        if double(trig) == 27
            % Esc before the trigger: nothing was presented, so nothing is saved
            if with_Eyelink
                Eyelink('StopRecording');
                Eyelink('CloseFile');
            end
            ShowCursor;
            Screen('CloseAll');
            fprintf('\nRun %d stopped with Esc before the scanner trigger. Nothing was saved.\n', run_number);
            return
        end

        if still_loading && strcmp(T.modality{1}, 'vision')
            movie(1) = Screen('OpenMovie', win, T.movie_path{1}, async, preloadsecs);
            if movie(1) > 0; still_loading = 0; end
        end
    end
else
    while still_loading  && strcmp(T.modality{1}, 'vision')
        movie(1) = Screen('OpenMovie', win, T.movie_path{1}, async, preloadsecs);
        if movie(1) > 0; still_loading = 0; end
    end
end

%% Experiment loop
try
    % experiment start time
    Screen('DrawLines', win, crossCoords, crossWidth, crossColor, [x0 y0]);
    experiment_start = Screen('Flip', win);

    while (GetSecs-experiment_start) < T.onset(1)
        while still_loading
            if strcmp(T.modality{1}, 'vision')
                movie(1) = Screen('OpenMovie', win, T.movie_path{1}, async, preloadsecs);
                if movie(1) > 0; still_loading = 0; end
            else
                text = T.caption{1};
                DrawFormattedText2(text,'win', win, 'sx','center','sy','center', ...
                    'xalign','center','yalign', 'center', ...
                    'baseColor',[255, 255, 255], 'wrapat', char_per_line, ...
                    'xlayout', 'center');
                still_loading = 0;
            end
        end
        check_keys(1, T, 1, keysToAccept, escapeKey, experiment_start);
    end

   if debug
       n_trials=2; 
   end 

    for itrial = 1:n_trials
        still_loading = 1;
        response = 0;
        if strcmp(T.modality{itrial}, 'vision')
            %% Video presentation
            Screen('SetMovieTimeIndex', movie(itrial), 0);
            Screen('PlayMovie', movie(itrial), rate, 1, sound);

            % Show the first frame to get onset time
            tex = Screen('GetMovieImage', win, movie(itrial), blocking);
            Screen('DrawTexture', win, tex, [], dispSize);
            trial_start = Screen('Flip', win);
            Screen('Close', tex);
            expected_trial_end = (trial_start + video_duration);

            if with_Eyelink %inside the trial function
                % these messages will be recorded in the output file determining the begining of the trial
                Eyelink('Message', ['TRIALID ', num2str(itrial)]);
                Eyelink('Message', ['TRIAL_VAR_DATA ', T.video_name{itrial}]);
                Eyelink('Message', 'STIMULUS_START');
            end

            % Show all the other frames
            frame_counter = 2; % Base 1 and count at end of loop.
            while GetSecs < (expected_trial_end-(1/frames_per_sec)) && frame_counter < (total_frames+1)
                tex = Screen('GetMovieImage', win, movie(itrial), blocking);
                Screen('DrawTexture', win, tex, [], dispSize);
                Screen('Flip', win);
                Screen('Close', tex);

                [response, T] = check_keys(response, T, itrial, keysToAccept, escapeKey, experiment_start);
                frame_counter = frame_counter + 1;
            end

            % Wait if needed
            while GetSecs < (expected_trial_end-(1/frames_per_sec))
            end
        else
            %% Sentence presentation
            trial_start = Screen('Flip', win);
            expected_trial_end = trial_start + sentence_duration;

            if with_Eyelink %inside the trial function
                % these messages will be recorded in the output file determining the begining of the trial
                Eyelink('Message', ['TRIALID ', num2str(itrial)]);
                Eyelink('Message', ['TRIAL_VAR_DATA ', T.video_name{itrial}]);
                Eyelink('Message', 'STIMULUS_START');
            end

            while GetSecs < (expected_trial_end-(1/frames_per_sec))
                [response, T] = check_keys(response, T, itrial, keysToAccept, escapeKey, experiment_start);
            end
        end

        %% Fixation
        Screen('DrawLines', win, crossCoords, crossWidth, crossColor, [x0 y0]);
        observed_trial_end = Screen('Flip', win);
        message_sent = 0;
        while (GetSecs-experiment_start) < T.onset(itrial+1)
            if with_Eyelink && ~message_sent
                Eyelink('Message','STIMULUS_OFF');
                message_sent = 1;
            end

            if strcmp(T.modality{itrial+1}, 'vision')
                if still_loading && itrial ~= n_trials
                    movie(itrial+1) = Screen('OpenMovie', win, T.movie_path{itrial+1}, async, preloadsecs);
                    if movie(itrial+1) > 0; still_loading = 0; end
                end
            else
                if still_loading
                    text = T.caption{itrial+1};
                    DrawFormattedText2(text,'win', win, 'sx','center','sy','center', ...
                        'xalign','center','yalign', 'center', ...
                        'baseColor',[255, 255, 255], 'wrapat', char_per_line, ...
                        'xlayout', 'center');
                    still_loading=0;
                end
            end

            [response, T] = check_keys(response, T, itrial, keysToAccept, escapeKey, experiment_start);
        end

        %% Trial ending details
        T.onset_time(itrial) = trial_start - experiment_start;
        T.offset_time(itrial) = observed_trial_end - experiment_start;
        T.duration(itrial) = observed_trial_end - trial_start;
        if strcmp(T.modality{itrial}, 'vision')
            Screen('CloseMovie', movie(itrial));
            movie(itrial) = 0; % Clear the movie handle
        end
    end

    T.offset_time(itrial) = GetSecs() - experiment_start;
    run_completed = true;
catch stop_error
    % Esc (or an error) during the run: keep what was presented
    run_completed = false;
end

%% Save
if run_completed
    suffix = '';
    presented = [true(n_trials, 1); false];          % not the duplicated last row
    actual_duration = T.offset_time(n_trials);
else
    suffix = '_incomplete';
    presented = [T.onset_time(1:end-1) > 0; false];  % trials that finished
end
save(fullfile(matout,['task-', task, '_run-', sprintf('%02d', run_number) '_',curr_date, suffix, '.mat']));
filename = fullfile(timingout,['task-', task, '_run-', sprintf('%02d', run_number), '_',curr_date, suffix, '.csv']);
writetable(T, filename);
ShowCursor;
Screen('CloseAll');

% Session + BIDS run are printed inside write_event_files
write_event_files(subjName, run_number, T(presented, :), task, session_number, bids_run_number, run_completed);

%% save eyelink and close (per-run EDF handling; keep link alive for next run)
if with_Eyelink
    try Eyelink('StopRecording'); catch; end
    Eyelink('Message','REC_END');
    Eyelink('CloseFile');

    try
        fprintf('Receiving data file ''%s''\n', edfFile);
        status = Eyelink('ReceiveFile', edfFile, [edfFile '.edf'], 1);
        if status <= 0
            warning('ReceiveFile returned %d. Check storage space/permissions.', status);
        end
    catch
        warning('Problem receiving EDF ''%s''.\n', edfFile);
    end

    edf_file_name = fullfile(edffiles, [edfFile, '_', curr_date, suffix, '.edf']);
    try
        movefile([edfFile '.edf'], edf_file_name);
        fprintf('Moved EDF to %s\n', edf_file_name);
    catch
        warning('Could not move EDF file to %s', edf_file_name);
    end
end

if ~run_completed
    if strcmp(stop_error.identifier, 'dyads:escape')
        fprintf(['\nRun %d stopped with Esc after %d of %d trials. The presented trials ', ...
            'were saved as incomplete.\n'], run_number, sum(presented), n_trials);
        return
    end
    rethrow(stop_error);
end

%% Print participant performance
% Participants press when the stimulus is NOT a crowd (i.e., dyad trials).
% Score only the presented trials, not the duplicated final row.
trials = T(1:n_trials, :);
is_target = trials.response_trial == 0;
hits = sum(trials.response(is_target) == 1);
false_alarms = sum(trials.response(~is_target) == 1);
total_accuracy = mean(trials.response == is_target);
s=sprintf('%g hits out of %g dyad events. %g false alarms out of %g crowd events. Overall accuracy is %0.2f.', hits, sum(is_target), false_alarms, sum(~is_target), total_accuracy);
fprintf('\n\n\n%s\n',WrapString(s));
s=sprintf('Expected length was %g s. Actual length was %g s.', expected_duration_s, actual_duration);
fprintf('\n%s\n\n ', WrapString(s));


function n = to_number(x, name)
% Converts 7, '07', "7" or 'sub-07' to the whole number 7.
if isstring(x) || ischar(x)
    n = str2double(regexprep(strtrim(char(x)), '^sub-?', '', 'ignorecase'));
else
    n = double(x);
end
if ~isscalar(n) || isnan(n) || n < 0 || n ~= round(n)
    error('%s must be a whole number (e.g. 7 or ''07''), not "%s".', name, strjoin(string(x)));
end


function [response, T] = check_keys(response, T, itrial, keysToAccept, escapeKey, experiment_start)
% Stops the run if Esc is down; otherwise records the first response of a trial.
[~, secs, keyCode] = KbCheck();
if keyCode(escapeKey)
    error('dyads:escape', 'Run stopped with Esc.');
end
if ~response && any(keyCode(keysToAccept))
    response = 1;
    T.response(itrial) = 1;
    T.response_time(itrial) = secs - experiment_start;
end
