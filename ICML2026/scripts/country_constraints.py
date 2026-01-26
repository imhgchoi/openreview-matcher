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
    argparser.add_argument("--reviewer", type=str, help="Reviewer CSV file")
    argparser.add_argument("--outputs", type=str, help="Output file for constraints")

    args = argparser.parse_args()

    print(f"Fetching Country constraints")

    assignments = json.load(open(args.assignments))
    reviewer_df = pd.read_csv(args.reviewer)

    constraints = []
    for submission_id in assignments.keys():
        reviewers = [x["user"] for x in assignments[submission_id]]
        reviewer_country = [reviewer_df[reviewer_df['user'] == reviewer_id]['country'].values[0] for reviewer_id in reviewers]
        
        if len(set(reviewer_country)) == 1: # all reviewers are from the same country
            country = reviewer_country[0]
            from_same_country = reviewer_df[reviewer_df.country==country].user.tolist()

            for reviewer in from_same_country:
                constraints.append((submission_id, reviewer, -1))
    
    # save constraints to csv
    if constraints:
        df = pd.DataFrame(constraints)
        df.to_csv(args.outputs, index=False, header=False)
        print(f"Done. Extracted {len(constraints)} country constraints")
    else:
        df = pd.DataFrame(columns=[0, 1, 2])
        df.to_csv(args.outputs, index=False, header=False)
        print(f"Done. No country constraints found. Created empty constraint file.")

