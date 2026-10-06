# SIdyads_presentation
 Presenting the dyad videos stimuli for the fMRI experiment

## `dyads_v_crowds.m`
Main presentation script used for the fMRI experiment. Usually you only pass the subject number: `dyads_v_crowds(subjName)`. The script works out the rest from the saved data:
- **Task:** sentences until 8 sentence runs are finished, then videos.
- **Run:** the next run; if the last run was stopped with Esc, it asks whether to re-run it or continue.
- **Session:** each date with saved data is a new session.

If a subject has no run files for the task yet, it makes them with `assign_conditions`. Press Esc to stop a run; what was shown is saved with an `_incomplete` suffix.

## `assign_conditions.m`
Makes the run files for a subject: `assign_conditions(subjName, task)` with task `'videos'` (24 runs) or `'sentences'` (20 runs). It never overwrites existing run files. The seed and optseq files used are saved to `runfiles/generation_log_<task>.json`.

## `make_session3_runfiles.m`
Makes video runs whose order is uncorrelated with what the participant already saw: `make_session3_runfiles(subjName)` (24 runs by default). `dyads_v_crowds` uses it for a new participant's first video run, once their sentence runs are done. `dyads_v_crowds` runs it automatically, once, for the first video run of session 3 or later. The new runs start after the last completed video run. Never-run video run files are moved to `runfiles/archive_<timestamp>/`. The order is chosen to be uncorrelated with the sentence order (and, less heavily weighted, the earlier video order) the participant already saw. Use `'DryRun', true` to preview.

## `generate_run_tables.m`
Shared randomization used by both scripts above. It writes nothing.
