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
    for _, row in tqdm(submission_df.iterrows(), total=len(submission_df), desc="Getting policy A authors"):
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

    policy_a_authors = set(get_policy_A_authors(submission_df))  # Convert to set for O(1) lookup
    
    # ---------------------------------------------------------
    # Get constraints
    # ---------------------------------------------------------
    
    # below this is a more efficient version of this.
    # for index, row in tqdm(submission_df.iterrows(), total=len(submission_df), desc="Fetching policy constraints"):
    #     if "This submission requires Policy A" in row['policy']:
    #         paper_policy = 'A'
    #         submission_id = row['submission']
        
    #         for reviewer_index, reviewer_row in reviewer_df.iterrows():
    #             reviewer_id = reviewer_row['user']
                
    #             # hard constraint
    #             if "I strongly prefer Policy B" in str(reviewer_row['policy']):
    #                 hard_constraints.append((submission_id, reviewer_id, -1))

    #                 # soft constraint
    #                 if reviewer_id not in policy_a_authors:
    #                     soft_constraints.append((submission_id, reviewer_id, -1))

    print('Fetching Policy A submissions and Policy B reviewers...')
    # Pre-filter submissions that require Policy A
    policy_a_submissions = submission_df[
        submission_df['policy'].str.contains("This submission requires Policy A", na=False)
    ]['submission'].values
    
    # Pre-filter reviewers who strongly prefer Policy B
    policy_b_reviewers = reviewer_df[
        reviewer_df['policy'].astype(str).str.contains("I strongly prefer Policy B", na=False)
    ][['user', 'policy']].copy()
    
    # Create all combinations using merge (vectorized)
    if len(policy_a_submissions) > 0 and len(policy_b_reviewers) > 0:
        print('Creating all combinations using merge...')
        # Create DataFrame with all Policy A submissions
        submissions_df = pd.DataFrame({'submission': policy_a_submissions})
        submissions_df['key'] = 1  # For cartesian product

        # Create DataFrame with Policy B reviewers
        reviewers_df = policy_b_reviewers.copy()
        reviewers_df['key'] = 1  # For cartesian product
        
        # Cartesian product to get all combinations
        combinations = submissions_df.merge(reviewers_df, on='key', how='outer')
        combinations = combinations.drop('key', axis=1)

        print('Generating hard constraints DataFrame...')
        # Generate hard constraints DataFrame (all Policy A submissions with Policy B reviewers)
        hard_constraints_df = combinations[['submission', 'user']].copy()
        hard_constraints_df['constraint'] = -1
        hard_constraints_df = hard_constraints_df[['submission', 'user', 'constraint']]
        
        print('Generating soft constraints DataFrame...')
        # Generate soft constraints DataFrame (exclude Policy A authors)
        soft_constraints_df = combinations[~combinations['user'].isin(policy_a_authors)][['submission', 'user']].copy()
        soft_constraints_df['constraint'] = -1
        soft_constraints_df = soft_constraints_df[['submission', 'user', 'constraint']]
    else:
        # Create empty DataFrames with correct columns
        hard_constraints_df = pd.DataFrame(columns=['submission', 'user', 'constraint'])
        soft_constraints_df = pd.DataFrame(columns=['submission', 'user', 'constraint'])
    
    # Write constraints file - work directly with DataFrames (more efficient)
    if len(hard_constraints_df) > 0:
        print('Writing hard constraints DataFrame to file...')
        # Calculate stats before writing
        num_papers = hard_constraints_df['submission'].nunique()
        num_reviewers = hard_constraints_df['user'].nunique()
        # Write CSV directly without creating intermediate DataFrame
        hard_constraints_df.to_csv(args.outputs[0], index=False, header=False)
        print(f"Done. Extracted {len(hard_constraints_df)} policy constraints for {num_papers} papers and {num_reviewers} reviewers")
    else:
        # Create empty file
        hard_constraints_df.to_csv(args.outputs[0], index=False, header=False)
        print(f"Done. No policy constraints found. Created empty constraint file.")

    if len(soft_constraints_df) > 0:
        print('Writing soft constraints DataFrame to file...')
        # Calculate stats before writing
        num_papers = soft_constraints_df['submission'].nunique()
        num_reviewers = soft_constraints_df['user'].nunique()
        # Write CSV directly without creating intermediate DataFrame
        soft_constraints_df.to_csv(args.outputs[1], index=False, header=False)
        print(f"Done. Extracted {len(soft_constraints_df)} soft policy constraints for {num_papers} papers and {num_reviewers} reviewers")
    else:
        # Create empty file
        soft_constraints_df.to_csv(args.outputs[1], index=False, header=False)
        print(f"Done. No soft policy constraints found. Created empty constraint file.")