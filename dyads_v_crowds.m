function dyads_v_crowds(subjName, run_number, task)
% Edited by Emalie McMahon June 20, 2025
% Updated: Session/BIDS run handling moved to write_event_files (post-save, per-task)

%% Experiment setup
if nargin < 1
    subjName = 77;
    run_number = [];
    task = 'sentences';
    debug = 1;
    with_Eyelink = 0;
else
    debug = 0;
    with_Eyelink = 0;
end

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


% Check that run files exist
if ~exist(topout, 'dir')
    s=sprintf('Run files do not exist of subject %g. Make run files before continuing.', subjName);
    ME = MException('MyComponent:noSuchVariable', s);
    throw(ME);
end


if isempty(run_number)
    % If the run_number is not assigned, find the last run and increment by 1.
    files = dir(fullfile(timingout, [task, '*.csv']));
    if ~isempty(files)
        runs = [];
        for i=1:length(files)
            f = strsplit(files(i).name, '_');
            f = strsplit(f{1},'-');
            runs(i) = str2double(f{end});
        end
        run_number = max(runs) + 1;
    else
        run_number = 1;
    end
end

s=sprintf('Subject number is %g. Run number is %g. ', subjName, run_number);
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

%% load video list
ftoread = fullfile(runfiles,[task, '-',sprintf('%02d', run_number),'.csv']);
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
n_response = sum(T.response_trial == 1);
n_real = height(T) - n_response;

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
    text = 'Hit the button if the video depicts the actions of many people.';
else
    text='Hit the button if the sentence describes the actions of many people.';
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

                if ~response
                    [~,response_time,keyCode]=KbCheck();
                    button = intersect(keysToAccept, find(keyCode));
                    if ~isempty(button)
                        response = 1;
                        T.response(itrial) = 1;
                        T.response_time(itrial) = response_time - experiment_start;
                    end
                end
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
                if ~response
                    [~,response_time,keyCode]=KbCheck();
                    button = intersect(keysToAccept, find(keyCode));
                    if ~isempty(button)
                        response = 1;
                        T.response(itrial) = 1;
                        T.response_time(itrial) = response_time - experiment_start;
                    end
                end
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

            if ~response
                [~,response_time,keyCode]=KbCheck();
                button = intersect(keysToAccept, find(keyCode));
                if ~isempty(button)
                    response = 1;
                    T.response(itrial) = 1;
                    T.response_time(itrial) = response_time - experiment_start;
                end
            end
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
    actual_duration = T.offset_time(itrial);
    save(fullfile(matout,['task-', task, '_run-', sprintf('%02d', run_number) '_',curr_date,'.mat']));
    filename = fullfile(timingout,['task-', task, '_run-', sprintf('%02d', run_number), '_',curr_date,'.csv']);
    writetable(T, filename);
    ShowCursor;
    Screen('CloseAll');

    % Session + BIDS run handled (and printed) inside write_event_files:
    write_event_files(subjName, run_number, T(1:end-1, :), task);

    %% save eyelink and close (per-run EDF handling; keep link alive for next run)
    if with_Eyelink
        Eyelink('StopRecording');
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

         edffiles = fullfile(edffiles, [edfFile, '_', curr_date, '.edf']);
        try
            movefile([edfFile '.edf'], edffiles);
            fprintf('Moved EDF to %s\n', dest);
            delete(edfFile);
        catch
            warning('Could not move EDF file to %s', dest);
        end
    end



    %% Print participant performance
    false_alarms = sum(T.response(T.response_trial == 0) == 1);
    hits = sum(T.response(T.response_trial == 1) == 1);
    total_accuracy = mean(T.response_trial == T.response);
    s=sprintf('%g hits out of %g crowd events. %g false alarms out of %g dyad events. Overall accuracy is %0.2f.', hits, n_response, false_alarms, n_real, total_accuracy);
    fprintf('\n\n\n%s\n',WrapString(s));
    s=sprintf('Expected length was %g s. Actual length was %g s.', expected_duration_s, actual_duration);
    fprintf('\n%s\n\n ', WrapString(s));

catch e %#ok<NASGU>
    save(fullfile(matout,['task-', task, '_run-', sprintf('%02d', run_number) '_',curr_date,'.mat']));
    filename = fullfile(timingout,['task-', task, '_run-', sprintf('%02d', run_number), '_',curr_date,'.csv']);
    writetable(T, filename);
    ShowCursor;
    Screen('CloseAll');
    % Even on error, write events + print session/run info:
    write_event_files(subjName, run_number, T(1:end-1, :), task);

    if with_Eyelink
        try Eyelink('StopRecording'); catch e2; fprintf(e2); end
        try Eyelink('CloseFile'); catch e2; fprintf(e2); end
        try Eyelink('ReceiveFile', edfFile); catch e2; fprintf(e2); end
    end

end
