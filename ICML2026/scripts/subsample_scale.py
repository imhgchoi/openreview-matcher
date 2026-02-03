# Subsample bids and constraints
import pandas as pd
import argparse
import numpy as np

# N = 12000

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser()

    arg_parser.add_argument('--scores', type=str, required=True)
    arg_parser.add_argument('--reviewer', type=str, required=True)
    arg_parser.add_argument('--submission', type=str, required=True)
    arg_parser.add_argument('--qualification', type=str, required=True)
    arg_parser.add_argument('--N', type=int, default=1000)
    arg_parser.add_argument('--files', type=str, nargs="+", help="List of files to subsample")

    args = arg_parser.parse_args()

    # N_subs = args.N
    # N_revs = int(args.N * 1.4)

    N_subs = int(args.N * 1.0)
    N_revs = args.N

    print("\nSubsampling files for debugging...")

    print("\nLoading scores...")
    scores = pd.read_csv(args.scores, header=None)
    submissions = scores[0].unique()
    reviewers = scores[1].unique()
    print(f"Loaded {len(submissions)} submissions and {len(reviewers)} reviewers.")
    
    print(f"\nSubsampling scores to {N_subs} submissions and {N_revs} reviewers...")
    # Subsample the number of papers to N for debugging purposes
    try:
        sampled_submissions = np.random.choice(submissions, N_subs, replace=False)
    except ValueError:
        print(f"Number of submissions is less than {N_subs}.")
        sampled_submissions = submissions
    scores = scores[scores[0].isin(sampled_submissions)]

    submission_df = pd.read_csv(args.submission)
    submission_df = submission_df[submission_df['submission'].isin(sampled_submissions)]
    submission_df.to_csv(args.submission.split(".")[0] + "_subsampled.csv", index=False)

    # Subsample the number of reviewers to N for debugging purposes
    try:
        sampled_reviewers = np.random.choice(reviewers, N_revs, replace=False)
    except ValueError:
        print(f"Number of reviewers is less than {N_revs}.")
        sampled_reviewers = reviewers
    scores = scores[scores[1].isin(sampled_reviewers)]
    scores.to_csv(args.scores.split(".")[0] + "_subsampled.csv", header=False, index=False)

    reviewer_df = pd.read_csv(args.reviewer)
    reviewer_df = reviewer_df[reviewer_df['user'].isin(sampled_reviewers)]
    reviewer_df.to_csv(args.reviewer.split(".")[0] + "_subsampled.csv", index=False)

    print(f"Subsampled {len(scores)} scores from {N_subs} submissions and {N_revs} reviewers.")

    qualification_df = pd.read_csv(args.qualification)
    qualification_df = qualification_df[qualification_df['user'].isin(sampled_reviewers)]
    qualification_df.to_csv(args.qualification.split(".")[0] + "_subsampled.csv", index=False)


    for file in args.files:
        print(f"\nSubsampling {file.split('/')[-1]}...")
        df = pd.read_csv(file, header=None)
        num_items = len(df)

        file = file.split(".")[0] + "_subsampled.csv"

        if len(df.columns) == 3:
            # Three columns: submission, reviewer, score
            df = df[df[0].isin(sampled_submissions) & df[1].isin(sampled_reviewers)]
            num_submissions, num_reviewers = df[0].nunique(), df[1].nunique()
            df.to_csv(file, header=False, index=False)
            print(f"Subsampled {len(df)}/{num_items} rows from {num_submissions} submissions and {num_reviewers} reviewers.")
        elif len(df.columns) == 2:
            # Two columns: reviewer, supply
            df = df[df[0].isin(sampled_reviewers)]
            num_reviewers = df[0].nunique()
            df.to_csv(file, header=False, index=False)
            print(f"Subsampled {len(df)}/{num_items} rows from {num_reviewers} reviewers.")
        else:
            raise ValueError(f"Invalid number of columns in {file}.")