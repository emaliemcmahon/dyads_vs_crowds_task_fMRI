#
from glob import glob
import argparse
from pathlib import Path
import pandas as pd
from random import shuffle
from tqdm import tqdm
import numpy as np


def load_optseq(input_path, task, shuffle_seq=True):
    out = []
    files = glob(f'{input_path}/{task}*.par')
    if shuffle_seq:
        shuffle(files)
    else:
        files = sorted(files)

    for sample, file in enumerate(files):
        df = pd.read_csv(file, sep=r'\s+', header=None,
                            names=['onset', 'cond_num', 'duration',
                                'blank', 'condition'])
        df.fillna('ISI', inplace=True)
        df.drop(columns=['blank'], inplace=True)
        df['seq_sample'] = sample
        out.append(df)
    df_out = pd.concat(out).reset_index(drop=True)
    return df_out.set_index(['seq_sample'])


def load_trials(input_file):
    df_vis = pd.read_csv(input_file)
    df_vis = df_vis.loc[df_vis.condition != 'crowd'].reset_index(drop=True)
    df_lang = df_vis.copy()
    df_vis['modality'] = 'vision'
    df_lang['modality'] = 'language'
    df_out = pd.concat([df_vis, df_lang]).reset_index(drop=True)
    return df_out[['video_name', 'condition', 'modality']]


def split_conditions(df, n_stim_per_cond, n_splits, shuffle_vids=True):
    # Create a copy to avoid modifying the original DataFrame
    df_ = df.copy()
    
    # Number the videos
    df_['vid_count'] = df_.groupby(['condition', 'modality']).cumcount()
    vid_idx = np.arange(n_stim_per_cond)
    
    if shuffle_vids:
        np.random.shuffle(vid_idx)

    vid_idx = vid_idx.reshape(n_splits, -1)

    # Initialize empty lists for each run
    runs = {f'run{i+1}': [] for i in range(n_splits)}
    for (_, modality), cond_df in df_.groupby(['condition', 'modality']): 
        for i in range(n_splits):
            run = f'run{(i + 1 + (0 if modality == 'vision' else 2) - 1) % n_splits + 1}'
            cur_split = cond_df.loc[cond_df.vid_count.isin(vid_idx[i])]
            runs[run].append(cur_split.drop(columns=['vid_count']))

    return tuple(pd.concat(runs[run]).reset_index(drop=True) for run in runs)


def assign_videos(seq, vids):
    vids['condition'] = vids['condition'] + '_' + vids['modality']
    vids['vid_count'] = vids.groupby('condition').cumcount()
    seq['vid_count'] = seq.groupby('condition').cumcount()
    seq = seq.merge(vids, on=['condition', 'vid_count'], how='left')
    seq.drop(columns=['modality', 'vid_count'], inplace=True)
    return seq


def fill_crowd_trials(seq, input_file, shuffle_vids=True):
    df = pd.read_csv(input_file)
    df = df.loc[df.condition.str.contains('crowd')].reset_index(drop=True)
    files = df.video_name.to_list()
    if shuffle_vids:
        shuffle(files)
    else:
        files = sorted(files)
    files = [Path(file).name for file in files]

    crowd_indices = seq[seq.condition.str.contains('crowd')].index
    
    # Assign videos to these rows from the list, in order
    for i, index in enumerate(crowd_indices):
        if i < len(files):
            seq.at[index, 'video_name'] = files[i]
        else:
            break  # Stop if there are more rows than videos

    return seq


def split_rows(df, TR=2):
    df['added_TRs'] = 0.0  # Initialize with 0

    # Iterate through rows to identify where a non-zero cond_num is followed by cond_num == 0
    for i in range(len(df) - 1):
        if df.loc[i, 'cond_num'] != 0 and df.loc[i + 1, 'cond_num'] == 0:
            df.loc[i, 'added_TRs'] = (df.loc[i + 1, 'duration'] / TR) - 1
    return df.loc[df.cond_num != 0].reset_index(drop=True)


def add_condition(df):
    df['response_trial'] = 0
    df.loc[df.condition.str.contains('crowd'), 'response_trial'] = 1
    return df 


def format_conditions(df):
    df_ = df.copy()
    split_df = df_['condition'].str.split('_', expand=True)
    df_['condition'] = split_df[0]
    df_['modality'] = split_df[1]
    return df_


class AssignSentConditions:
    def __init__(self, args):
        self.sid = args.sid
        self.task = args.task
        self.n_splits = 4 if self.task == 'sentences' else 3
        self.n_videos_per_condition = 36
        self.optseq_path = args.optseq_path
        self.video_csv = args.video_csv
        self.n_repeats = args.n_repeats
        self.top_out = args.top_out
        self.out_dir = f'{self.top_out}/sub-{str(self.sid).zfill(2)}/runfiles'
        self.shuffle = True
        Path(self.out_dir).mkdir(parents=True, exist_ok=True)
        Path(self.out_dir.replace('runfiles', 'matfiles')).mkdir(parents=True, exist_ok=True)
        Path(self.out_dir.replace('runfiles', 'timingfiles')).mkdir(parents=True, exist_ok=True)

    def run(self):
        seq_df = load_optseq(self.optseq_path, self.task, shuffle_seq=self.shuffle)
        vid_df = load_trials(self.video_csv)
        run_counter = 0 
        for n_repeat in range(self.n_repeats): 
            run_splits = split_conditions(vid_df, 
                                          n_stim_per_cond=self.n_videos_per_condition,
                                          n_splits=self.n_splits,
                                          shuffle_vids=self.shuffle)
            for run_df in run_splits:
                run_name = str(run_counter+1).zfill(2)
                cur_seq_df = seq_df.loc[run_counter].reset_index(drop=True)

                cur_seq_df = assign_videos(cur_seq_df, run_df)
                cur_seq_df = fill_crowd_trials(cur_seq_df, self.video_csv,
                                               shuffle_vids=self.shuffle)
                cur_seq_df = split_rows(cur_seq_df)
                cur_seq_df = add_condition(cur_seq_df)
                cur_seq_df = format_conditions(cur_seq_df)
                cur_seq_df.drop(columns=['duration'], inplace=True)
                cur_seq_df['trial_type'] = cur_seq_df['condition'] + '_' + cur_seq_df['modality']
                cur_seq_df.to_csv(f'{self.out_dir}/{self.task}-{run_name}.csv', index=False)
                run_counter += 1


def getArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sid', '-s', type=int, default=77, 
                        help='id of the subject')
    parser.add_argument('--task', '-t', type=str, default='videos', 
                        help='the task to assign')
    parser.add_argument('--optseq_path', type=str, help='path with optseq par files',
                        default='optseq')
    parser.add_argument('--video_csv', type=str, help='list of videos and conditions',
                        default='sentence_captions.csv')
    parser.add_argument('--n_repeats', '-n', type=int, default=5,
                        help='number of unique video repetitions in experiment. \n Number of runs will be 5 * n_repeats')
    parser.add_argument('--top_out', '-o', type=str, help='directory to save the run files', 
                        default='data')
    args = parser.parse_args()
    return args

if __name__ == "__main__":
    args = getArgs()
    AssignSentConditions(args).run()
