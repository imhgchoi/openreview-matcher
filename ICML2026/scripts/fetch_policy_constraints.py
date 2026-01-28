import argparse
import pandas as pd
import openreview
import os
from tqdm import tqdm


def get_policy_A_authors(submission_df):
    """
    Get the authors of all submissions that require Policy A.
    """
    authors_set = set()
    for _, row in submission_df.iterrows():
        # Skip if authors field is NaN or empty
        if pd.isna(row['authors']) or str(row['authors']).strip() == '':
            continue
        
        # Authors are pipe-separated (e.g., "~Author1|~Author2|~Author3")
        authors_str = str(row['authors'])
        authors_list = authors_str.split('|')
        authors_set = authors_set.union(set(authors_list))
    
    return list(authors_set)

    
    
if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--match_group", type=str, help="Match group")
    argparser.add_argument("--submission", type=str, help="Submission file")
    argparser.add_argument("--reviewer", type=str, help="Reviewer file")
    argparser.add_argument("--outputs", type=str, nargs="+", help="Output file for constraints")

    args = argparser.parse_args()

    print(f"Fetching Policy constraints for match group {args.match_group}")

    submission_df = pd.read_csv(args.submission, usecols=['submission', 'authors', 'policy'])
    reviewer_df = pd.read_csv(args.reviewer, usecols=['user', 'policy'])

    policy_a_authors = get_policy_A_authors(submission_df)
    
    # ---------------------------------------------------------
    # Get constraints
    # ---------------------------------------------------------
    
    hard_constraints = []
    soft_constraints = []
    for index, row in submission_df.iterrows():
        if "This submission requires Policy A" in row['policy']:
            paper_policy = 'A'
            submission_id = row['submission']
        
            for reviewer_index, reviewer_row in reviewer_df.iterrows():
                reviewer_id = reviewer_row['user']
                
                # hard constraint
                if "I strongly prefer Policy B" in str(reviewer_row['policy']):
                    hard_constraints.append((submission_id, reviewer_id, -1))

                    # soft constraint
                    if reviewer_id not in policy_a_authors:
                        soft_constraints.append((submission_id, reviewer_id, -1))
    
    # Write constraints file
    if hard_constraints:
        df = pd.DataFrame(hard_constraints)
        df.to_csv(args.outputs[0], index=False, header=False)
        num_papers = len(df[0].unique())
        num_reviewers = len(df[1].unique())
        print(f"Done. Extracted {len(hard_constraints)} policy constraints for {num_papers} papers and {num_reviewers} reviewers")
    else:
        # Create empty file
        df = pd.DataFrame(columns=[0, 1, 2])
        df.to_csv(args.outputs[0], index=False, header=False)
        print(f"Done. No policy constraints found. Created empty constraint file.")

    if soft_constraints:
        df = pd.DataFrame(soft_constraints)
        df.to_csv(args.outputs[1], index=False, header=False)
        num_papers = len(df[0].unique())
        num_reviewers = len(df[1].unique())
        print(f"Done. Extracted {len(soft_constraints)} soft policy constraints for {num_papers} papers and {num_reviewers} reviewers")
    else:
        # Create empty file
        df = pd.DataFrame(columns=[0, 1, 2])
        df.to_csv(args.outputs[1], index=False, header=False)
        print(f"Done. No soft policy constraints found. Created empty constraint file.")