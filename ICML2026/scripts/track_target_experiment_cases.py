import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import random
import json

    
if __name__ == "__main__":
    argparser = argparse.ArgumentParser()   
    argparser.add_argument("--reviewer_policy", type=str, help="Reviewer policy CSV file")
    argparser.add_argument("--assignments", type=str, help="Assignment JSON file")
    argparser.add_argument("--output", type=str, help="Output CSV file")

    args = argparser.parse_args()

    print(f"Getting updated reviewer policy...")
    
    with open(args.assignments, 'r') as f:
        assignments = json.load(f)
    
    reviewer_policy_df = pd.read_csv(args.reviewer_policy)

    e_reviewers = reviewer_policy_df[reviewer_policy_df['case_id'] == '(e)']['reviewer'].tolist()
    f_reviewers = reviewer_policy_df[reviewer_policy_df['case_id'] == '(f)']['reviewer'].tolist()

    target_experiment_cases = []
    target_e_reviewers = []
    target_f_reviewers = []
    target_assignments = {}
    for submission_id in assignments.keys():
        submission_info = assignments[submission_id]
        assigned_reviewers = [x['user'] for x in submission_info]

        has_e, has_f = False, False
        for reviewer in assigned_reviewers:
            if reviewer in e_reviewers:
                e_reviewer = reviewer
                has_e = True
            if reviewer in f_reviewers:
                f_reviewer = reviewer
                has_f = True
            
        if has_e and has_f:
            target_experiment_cases.append(submission_id)
            target_assignments[submission_id] = submission_info
            target_e_reviewers.append(e_reviewer)
            target_f_reviewers.append(f_reviewer)
    
    print(f"Found {len(target_experiment_cases)} target experiment cases with at least one reviewer A+B -> A and at least one reviewer A+B -> B")

    with open(args.output, 'w') as f:
        json.dump(target_assignments, f)

    df = pd.DataFrame({
        'submission_id': target_experiment_cases,
        'e_reviewer': target_e_reviewers,
        'f_reviewer': target_f_reviewers
    })
    df.to_csv(f"{args.output}".split(".")[0] + ".csv", index=False)