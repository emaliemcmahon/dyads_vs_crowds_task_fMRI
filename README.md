# SIdyads_presentation
 Presenting the dyad videos stimuli for the fMRI experiment

## `dyads_v_crowds.m`
Main presentation script used for the fMRI experiment. If a subject has no run files for the task yet, it makes them with `assign_conditions`.

## `assign_conditions.m`
Makes the run files for a subject: `assign_conditions(subjName, task)` with task `'videos'` (24 runs) or `'sentences'` (20 runs). It never overwrites existing run files. The seed and optseq files used are saved to `runfiles/generation_log_<task>.json`.

## `make_session3_runfiles.m`
Makes new video runs for a returning participant: `make_session3_runfiles(subjName)` (12 runs by default). The new runs start after the last completed video run. Never-run video run files are moved to `runfiles/archive_<timestamp>/`. The order is chosen to be uncorrelated with the sentence order (and, less heavily weighted, the earlier video order) the participant already saw. Use `'DryRun', true` to preview.

## `generate_run_tables.m`
Shared randomization used by both scripts above. It writes nothing.
