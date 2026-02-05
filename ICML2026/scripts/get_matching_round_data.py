import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import json
if __name__ == "__main__":

    argparser = argparse.ArgumentParser()
    argparser.add_argument("--scores", type=str, help="Scores CSV file")
    argparser.add_argument("--bids", type=str, help="Bids CSV file")
    argparser.add_argument("--constraints", type=str, help="Constraints CSV file")
    argparser.add_argument("--round1_reviewers", type=str, help="Round 1 reviewers CSV file")
    argparser.add_argument("--round2_reviewers", type=str, help="Round 2 reviewers CSV file")
    argparser.add_argument("--outputs", nargs="+", type=str, help="Output CSV files")
    args = argparser.parse_args()

    scores_df = pd.read_csv(args.scores, header=None)
    bids_df = pd.read_csv(args.bids, header=None)
    constraints_df = pd.read_csv(args.constraints, header=None)
    round1_reviewers_df = pd.read_csv(args.round1_reviewers)
    round2_reviewers_df = pd.read_csv(args.round2_reviewers)

    round1_scores_df = scores_df[scores_df.loc[:, 1].isin(round1_reviewers_df['reviewer_id'])]
    round1_bids_df = bids_df[bids_df.loc[:, 1].isin(round1_reviewers_df['reviewer_id'])]
    round1_constraints_df = constraints_df[constraints_df.loc[:, 1].isin(round1_reviewers_df['reviewer_id'])]
    round2_scores_df = scores_df[scores_df.loc[:, 1].isin(round2_reviewers_df['reviewer_id'])]
    round2_bids_df = bids_df[bids_df.loc[:, 1].isin(round2_reviewers_df['reviewer_id'])]
    round2_constraints_df = constraints_df[constraints_df.loc[:, 1].isin(round2_reviewers_df['reviewer_id'])]

    round1_scores_df.to_csv(args.outputs[0], index=False, header=False)
    round1_bids_df.to_csv(args.outputs[1], index=False, header=False)
    round1_constraints_df.to_csv(args.outputs[2], index=False, header=False)
    round2_scores_df.to_csv(args.outputs[3], index=False, header=False)
    round2_bids_df.to_csv(args.outputs[4], index=False, header=False)
    round2_constraints_df.to_csv(args.outputs[5], index=False, header=False)
    
