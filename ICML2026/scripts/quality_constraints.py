import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import json

    
if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--assignments", type=str, help="Matching assignments JSON file")
    argparser.add_argument("--qualification", type=str, help="Qualification CSV file")
    argparser.add_argument("--outputs", type=str, help="Output file for constraints")

    args = argparser.parse_args()

    print(f"Fetching Quality constraints")

    assignments = json.load(open(args.assignments))
    reviewer_df = pd.read_csv(args.qualification)
    unqualified_reviewers = reviewer_df[reviewer_df['qualification'] == 0]['user'].tolist()

    constraints = []
    for submission_id in assignments.keys():
        reviewers = [x["user"] for x in assignments[submission_id]]
        reviewer_quality = [reviewer_df[reviewer_df['user'] == reviewer_id]['qualification'].values[0] for reviewer_id in reviewers]
        
        if sum(reviewer_quality) == 0: # all reviewers are unqualified
            for reviewer in unqualified_reviewers:
                constraints.append((submission_id, reviewer, -1))
    
    # save constraints to csv
    if constraints:
        df = pd.DataFrame(constraints)
        df.to_csv(args.outputs, index=False, header=False)
        print(f"Done. Extracted {len(constraints)} quality constraints")
    else:
        df = pd.DataFrame(columns=[0, 1, 2])
        df.to_csv(args.outputs, index=False, header=False)
        print(f"Done. No quality constraints found. Created empty constraint file.")

