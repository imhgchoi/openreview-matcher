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
    argparser.add_argument("--output", type=str, help="Output file")
    argparser.add_argument("--filter_unregistered", type=str, help="Filter out unregistered reviewers")

    args = argparser.parse_args()

    print(f"Removing reviewers that have not registered...")

    orig_reviewer_df = pd.read_csv(args.reviewer)

    # remove reviewers whose country and policy are NaN
    reviewer_df = orig_reviewer_df[orig_reviewer_df['country'].notna() & orig_reviewer_df['policy'].notna()]
    unregistered_reviewer_df = orig_reviewer_df[orig_reviewer_df['country'].isna() | orig_reviewer_df['policy'].isna()]
    
    if args.filter_unregistered == "True":
        # save the updated reviewer file and unregistered reviewers
        reviewer_df.to_csv(args.reviewer, index=False)
        unregistered_reviewer_df.to_csv(args.output, index=False)

        print(f"Removed {len(unregistered_reviewer_df)} reviewers that have not registered")

    else : # This is for testing only - unregistered reviewers should be filtered out in actual matching
        orig_reviewer_df.to_csv(args.reviewer, index=False)
        unregistered_reviewer_df.iloc[:0].to_csv(args.output, index=False)

        print("Did not filter out unregistered reviewers for testing purposes")


