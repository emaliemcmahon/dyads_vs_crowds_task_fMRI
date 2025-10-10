% Call ONCE at the very end of the session (after the last run’s EDF is received).
try
    if Eyelink('IsConnected') == 1
        Eyelink('ShutDown');
        fprintf('[EyeLink] Link shut down.\n');
    end
catch
    % Safe to ignore if already closed
end