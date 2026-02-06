import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import random


    
    
if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--reviewer", type=str, help="Submission file")
    argparser.add_argument("--output", nargs='+', type=str, help="Output file")
    argparser.add_argument("--filter_unregistered", type=str, help="Filter out unregistered reviewers")
    argparser.add_argument("--registered", type=str, help="Registered reviewers file")

    args = argparser.parse_args()

    print(f"Removing reviewers that have not registered...")

    orig_reviewer_df = pd.read_csv(args.reviewer)
    print(f"Original {len(orig_reviewer_df)} reviewers")

    # remove reviewers whose country and policy are NaN
    reviewer_df = orig_reviewer_df[orig_reviewer_df['country'].notna() & orig_reviewer_df['policy'].notna()]
    unregistered_reviewer_df = orig_reviewer_df[orig_reviewer_df['country'].isna() | orig_reviewer_df['policy'].isna()]
    
    if args.registered is not None:
        print(f"Keeping only registered reviewers with IDs in {args.registered}")
        registered_reviewers_df = pd.read_csv(args.registered)
        reviewer_df = reviewer_df[reviewer_df['user'].isin(registered_reviewers_df['reviewer_id'])]
        print(f"Kept {len(reviewer_df)} registered reviewers")

    if args.filter_unregistered == "True":
        # save the updated reviewer file and unregistered reviewers
        reviewer_df.to_csv(args.output[0], index=False)
        unregistered_reviewer_df.to_csv(args.output[1], index=False)

        print(f"Removed {len(unregistered_reviewer_df)} reviewers that have not registered")

    else : # This is for testing only - unregistered reviewers should be filtered out in actual matching
        orig_reviewer_df.to_csv(args.output[0], index=False)
        unregistered_reviewer_df.iloc[:0].to_csv(args.output[1], index=False)

        print("Did not filter out unregistered reviewers for testing purposes")


