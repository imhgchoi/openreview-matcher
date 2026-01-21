import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import random


    
if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--match_group", type=str, help="Match group")
    argparser.add_argument("--submission", type=str, help="Submission file")
    argparser.add_argument("--flip_rate", type=float, help="Ratio of papers to flip from Policy B to Policy A")

    args = argparser.parse_args()

    print(f"Flipping papers from Policy B to Policy A for match group {args.match_group}")

    submission_df = pd.read_csv(args.submission)
    flip_rate = args.flip_rate

    # get the indices of the papers that allow policy B
    policy_b_indices = submission_df[submission_df['policy'] == 'This submission allows Policy B.'].index
    num_papers_to_flip = int(len(policy_b_indices) * flip_rate)
    papers_to_flip = np.random.default_rng(42).choice(policy_b_indices, size=num_papers_to_flip, replace=False)
    submission_df.loc[papers_to_flip, 'policy'] = 'This submission requires Policy A.'

    # get the submission ids of flipped papers
    flipped_submission_ids = submission_df.loc[papers_to_flip, 'submission']

    # save the updated submission file
    submission_df.to_csv(args.submission, index=False)
    flipped_submission_ids.to_csv("/".join(args.submission.split("/")[:-1]) + "/flipped_submission_ids.csv", index=False)

    print(f"Flipped {len(papers_to_flip)} papers from Policy B to Policy A")