%% init_eyelink_session.m  — run ONCE at the start of the session
% Opens PTB window, initializes EyeLink, sets recommended parameters,
% opens a legal EDF (<=8 chars) on the HOST, optionally runs full calibration,
% and stashes 'el' and 'edfFile' for other scripts (via setappdata).
%
% Customize 'edfBase' and 'doCalibration' below as needed.

AssertOpenGL;
Screen('Preference','VisualDebugLevel',0);

% --- Open a window for this session (use your preferred screen/bg) ---
screen = max(Screen('Screens'));
bg = [50 50 50];
fg = [255 255 255];
[win, winRect] = Screen('OpenWindow', screen, bg);
commandwindow;

% --- Choose EDF base name (<= 8 chars, no extension). Edit as you like. ---
% Example: 's01r01', 'sent001', etc.
edfBase = 'sent001';     % <-- change per subject/run plan if you want
doCalibration = true;    % true = run full calibration now (once per session)

% --- Make EyeLink-legal EDF name (8.3) ---
edfBase = regexprep(edfBase, '\.edf$', '', 'ignorecase');
if numel(edfBase) > 8, edfBase = edfBase(1:8); end
edfFile = [edfBase '.edf'];

% --- Defaults bound to this PTB window (must precede EyelinkInit) ---
el = EyelinkInitDefaults(win);
% Match your task’s colors
el.backgroundcolour        = bg;
el.foregroundcolour        = fg;
el.msgfontcolour           = fg;
el.imgtitlecolour          = fg;
el.calibrationtargetcolour = [255 255 255];
EyelinkUpdateDefaults(el);

% --- Start the link (no dummy), with messages onscreen for debugging ---
if EyelinkInit(0, 1) ~= 1
    Screen('CloseAll');
    error('EyelinkInit failed. Check network/IP (100.1.1.1), cable, and host power.');
end

% --- Tell tracker your display coordinates (important for calibration) ---
scrW = RectWidth(winRect);  scrH = RectHeight(winRect);
Eyelink('Command', 'screen_pixel_coords = 0 0 %d %d', scrW-1, scrH-1);
Eyelink('Message', 'DISPLAY_COORDS 0 0 %d %d', scrW-1, scrH-1);

% --- Your existing parameter set (do this once per session) ---
% Calibration/validation area (kept from your script)
Eyelink('command','calibration_area_proportion = 0.5 0.55');
Eyelink('command','validation_area_proportion  = 0.5 0.5');

% Parser + saccade thresholds
Eyelink('command','recording_parse_type = GAZE');
Eyelink('command','saccade_acceleration_threshold = 8000');
Eyelink('command','saccade_velocity_threshold = 30');
Eyelink('command','saccade_motion_threshold = 0.15');
Eyelink('command','saccade_pursuit_fixup = 60');

% File/link filters
Eyelink('command','file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
Eyelink('command','file_sample_data  = LEFT,RIGHT,GAZE,HREF,GAZERES,AREA,HTARGET,STATUS,INPUT');
Eyelink('command','file_event_data   = GAZE,GAZERES,AREA,VELOCITY,HREF');

Eyelink('command','link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
Eyelink('command','link_sample_data  = LEFT,RIGHT,GAZE,HREF,GAZERES,AREA,HTARGET,STATUS,INPUT');
Eyelink('command','link_event_data   = GAZE,GAZERES,AREA,VELOCITY,HREF');

% --- Open EDF on the HOST (not on your Ubuntu machine) ---
rc = Eyelink('OpenFile', edfFile);
if rc ~= 0
    Eyelink('Shutdown'); Screen('CloseAll');
    error('Could not open EDF "%s" on host (EyeLink requires <=8-char names).', edfFile);
end

% --- Optional one-time full calibration/validation ---
if doCalibration
    fprintf('[EyeLink] Running full calibration...\n');
    EyelinkDoTrackerSetup(el);
end

% --- Confirm link & stash shared state for other scripts ---
[~, trackerName] = Eyelink('GetTrackerVersion');
fprintf('[EyeLink] Connected to "%s". EDF: %s. Initialization complete.\n', trackerName, edfFile);

% Make available to all scripts in this MATLAB session:
setappdata(0,'el', el);
setappdata(0,'edfFile', edfFile);
setappdata(0,'win', win);
setappdata(0,'winRect', winRect);

sca;

% NOTE: Do NOT close the window here; leave it open for your run scripts.
% Your run scripts can now call:
%   el  = getappdata(0,'el');
%   rc  = EyelinkDoDriftCorrection(el); if rc==-1, EyelinkDoTrackerSetup(el); end
%   Eyelink('StartRecording');  ... trials ... Eyelink('StopRecording');

