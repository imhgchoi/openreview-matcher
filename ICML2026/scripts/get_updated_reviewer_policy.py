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
    argparser.add_argument("--assignments", type=str, help="Assignment JSON file")
    argparser.add_argument("--reviewer", type=str, help="Reviewer CSV file")
    argparser.add_argument("--submission", type=str, help="Submission CSV file")
    argparser.add_argument("--output", type=str, help="Output CSV file")

    args = argparser.parse_args()

    print(f"Getting updated reviewer policy...")
    
    assignments = pd.read_csv(args.assignments, header=None)
    submission_df = pd.read_csv(args.submission)
    reviewer_df = pd.read_csv(args.reviewer)

    unique_reviewers_assigned = list(set(assignments.loc[:,1].tolist()))

    experimented_reviewers = []
    final_policies = []
    for assigned_reviewer in unique_reviewers_assigned:
        submission_ids = assignments.loc[assignments.loc[:,1] == assigned_reviewer, 0].tolist()
        submission_policies = submission_df.loc[submission_df['submission'].isin(submission_ids), 'policy'].tolist()


        if "This submission requires Policy A." in submission_policies: # there is at least one paper that requires Policy A

            if reviewer_df.loc[reviewer_df['user'] == assigned_reviewer].policy.item() == "I strongly prefer Policy A.":
                chosen_policy = "A"
                assigned_policy = "A"
                case_id = '(a)'
            elif reviewer_df.loc[reviewer_df['user'] == assigned_reviewer].policy.item() == "I strongly prefer Policy B.":
                chosen_policy = "B"
                assigned_policy = "A"
                case_id = '(b)'
            elif reviewer_df.loc[reviewer_df['user'] == assigned_reviewer].policy.item() == "I am okay with either A or B.":
                chosen_policy = "A+B"
                assigned_policy = "A"
                case_id = '(c)'
            else:
                raise ValueError

        else: # all papers allow Policy B

            if reviewer_df.loc[reviewer_df['user'] == assigned_reviewer].policy.item() == "I strongly prefer Policy A.":
                chosen_policy = "A"
                assigned_policy = "A"
                case_id = '(a)'
            elif reviewer_df.loc[reviewer_df['user'] == assigned_reviewer].policy.item() == "I strongly prefer Policy B.":
                chosen_policy = "B"
                assigned_policy = "B"
                case_id = '(d)'
            elif reviewer_df.loc[reviewer_df['user'] == assigned_reviewer].policy.item() == "I am okay with either A or B.":
                chosen_policy = "A+B"
                assigned_policy = None
                experimented_reviewers.append(assigned_reviewer)
            else:
                raise ValueError

        
        if assigned_policy is not None:
            final_policies.append((assigned_reviewer, chosen_policy, assigned_policy, case_id))
    
        
    # Experimental Manipulation
    assign_A_num = len(experimented_reviewers) // 2
    policy_A_experiment_reviewers = np.random.default_rng(42).choice(experimented_reviewers, size=assign_A_num, replace=False)
    policy_B_experiment_reviewers = [reviewer for reviewer in experimented_reviewers if reviewer not in policy_A_experiment_reviewers]
    
    experimental_final_policies = []
    for reviewer in policy_A_experiment_reviewers:
        experimental_final_policies.append((reviewer, "A+B", "A", "(e)"))
    for reviewer in policy_B_experiment_reviewers:
        experimental_final_policies.append((reviewer, "A+B", "B", "(f)"))
    
    # save experimental final policies
    experimental_final_policies_df = pd.DataFrame(experimental_final_policies, columns=['reviewer', 'chosen_policy', 'assigned_policy', 'case_id'])
    experimental_final_policies_df.to_csv(args.output.replace(".csv", "_experimental.csv"), index=False)
    
    # save final policies
    final_policies = final_policies + experimental_final_policies
    final_policies_df = pd.DataFrame(final_policies, columns=['reviewer', 'chosen_policy', 'assigned_policy', 'case_id'])
    final_policies_df.to_csv(args.output, index=False)





