"""
Usage:
export GROUP=Revieweres
python ICML2026/scripts/split_groups.py \
    --scores ICML2026/$GROUP/data/affinity_scores.csv \
    --reviewer ICML2026/$GROUP/data/reviewer.csv \
    --submission ICML2026/$GROUP/data/submission.csv \
    --qualification ICML2026/$GROUP/data/qualification.csv \
    --files ICML2026/$GROUP/data/constraints/conflict_constraints.csv ICML2026/$GROUP/data/bids.csv ICML2026/$GROUP/data/quota.csv \
    --output_dir ICML2026/$GROUP/data/split_groups \
    --seed 42
"""

# Split reviewers, papers, and edges into two disconnected groups for parallel matching
import pandas as pd
import argparse
import numpy as np
import os

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(
        description="Split matching data into two disconnected groups for parallel processing"
    )

    arg_parser.add_argument('--scores', type=str, required=True, help="Path to affinity_scores.csv (paper, reviewer, score)")
    arg_parser.add_argument('--reviewer', type=str, required=True, help="Path to reviewer.csv (must have 'user' column)")
    arg_parser.add_argument('--submission', type=str, required=True, help="Path to submission.csv (must have 'submission' column)")
    arg_parser.add_argument('--qualification', type=str, default=None, help="Path to qualification CSV (must have 'user' column)")
    arg_parser.add_argument('--files', type=str, nargs="+", default=[], help="Additional edge files to split (e.g., bids.csv, conflict_constraints.csv, quota.csv)")
    arg_parser.add_argument('--output_dir', type=str, required=True, help="Base output directory (will create group1/ and group2/ subdirectories)")
    arg_parser.add_argument('--seed', type=int, default=42, help="Random seed for reproducibility")

    args = arg_parser.parse_args()
    np.random.seed(args.seed)

    # Create output directories
    group1_dir = os.path.join(args.output_dir, "group1")
    group2_dir = os.path.join(args.output_dir, "group2")
    os.makedirs(group1_dir, exist_ok=True)
    os.makedirs(group2_dir, exist_ok=True)

    print("\n=== Splitting data into two disconnected groups ===")
    print(f"Random seed: {args.seed}")
    print(f"Output directories: {group1_dir}, {group2_dir}")

    # Load scores to get unique papers and reviewers
    print("\nLoading scores...")
    scores = pd.read_csv(args.scores, header=None)
    all_submissions = scores[0].unique()
    all_reviewers = scores[1].unique()
    print(f"Found {len(all_submissions)} submissions and {len(all_reviewers)} reviewers")
    print(f"Total edges: {len(scores)}")

    # Randomly split papers and reviewers into two groups
    print("\nSplitting into two groups...")
    np.random.shuffle(all_submissions)
    np.random.shuffle(all_reviewers)

    mid_subs = len(all_submissions) // 2
    mid_revs = len(all_reviewers) // 2

    subs_group1 = set(all_submissions[:mid_subs])
    subs_group2 = set(all_submissions[mid_subs:])
    revs_group1 = set(all_reviewers[:mid_revs])
    revs_group2 = set(all_reviewers[mid_revs:])

    print(f"Group 1: {len(subs_group1)} submissions, {len(revs_group1)} reviewers")
    print(f"Group 2: {len(subs_group2)} submissions, {len(revs_group2)} reviewers")

    def get_filename(filepath):
        """Extract just the filename from a path"""
        return os.path.basename(filepath)

    def split_edge_file(df, subs1, revs1, subs2, revs2):
        """Split edge file (paper, reviewer, value) into two groups"""
        group1 = df[df[0].isin(subs1) & df[1].isin(revs1)]
        group2 = df[df[0].isin(subs2) & df[1].isin(revs2)]
        return group1, group2

    # Split and save scores (affinity_scores.csv)
    print("\nSplitting affinity_scores.csv...")
    scores_g1, scores_g2 = split_edge_file(scores, subs_group1, revs_group1, subs_group2, revs_group2)
    scores_g1.to_csv(os.path.join(group1_dir, get_filename(args.scores)), header=False, index=False)
    scores_g2.to_csv(os.path.join(group2_dir, get_filename(args.scores)), header=False, index=False)
    print(f"  Group 1: {len(scores_g1)} edges ({len(scores_g1[0].unique())} papers, {len(scores_g1[1].unique())} reviewers)")
    print(f"  Group 2: {len(scores_g2)} edges ({len(scores_g2[0].unique())} papers, {len(scores_g2[1].unique())} reviewers)")

    # Split reviewer metadata (reviewer.csv)
    print("\nSplitting reviewer.csv...")
    reviewer_df = pd.read_csv(args.reviewer)
    reviewer_g1 = reviewer_df[reviewer_df['user'].isin(revs_group1)]
    reviewer_g2 = reviewer_df[reviewer_df['user'].isin(revs_group2)]
    reviewer_g1.to_csv(os.path.join(group1_dir, get_filename(args.reviewer)), index=False)
    reviewer_g2.to_csv(os.path.join(group2_dir, get_filename(args.reviewer)), index=False)
    print(f"  Group 1: {len(reviewer_g1)} reviewers")
    print(f"  Group 2: {len(reviewer_g2)} reviewers")

    # Split submission metadata (submission.csv)
    print("\nSplitting submission.csv...")
    submission_df = pd.read_csv(args.submission)
    submission_g1 = submission_df[submission_df['submission'].isin(subs_group1)]
    submission_g2 = submission_df[submission_df['submission'].isin(subs_group2)]
    submission_g1.to_csv(os.path.join(group1_dir, get_filename(args.submission)), index=False)
    submission_g2.to_csv(os.path.join(group2_dir, get_filename(args.submission)), index=False)
    print(f"  Group 1: {len(submission_g1)} submissions")
    print(f"  Group 2: {len(submission_g2)} submissions")

    # Split qualification if provided
    if args.qualification:
        print("\nSplitting qualification.csv...")
        qual_df = pd.read_csv(args.qualification)
        qual_g1 = qual_df[qual_df['user'].isin(revs_group1)]
        qual_g2 = qual_df[qual_df['user'].isin(revs_group2)]
        qual_g1.to_csv(os.path.join(group1_dir, get_filename(args.qualification)), index=False)
        qual_g2.to_csv(os.path.join(group2_dir, get_filename(args.qualification)), index=False)
        print(f"  Group 1: {len(qual_g1)} entries")
        print(f"  Group 2: {len(qual_g2)} entries")

    # Split additional edge files (bids.csv, conflict_constraints.csv, quota.csv, etc.)
    for filepath in args.files:
        filename = get_filename(filepath)
        print(f"\nSplitting {filename}...")
        df = pd.read_csv(filepath, header=None)
        num_items = len(df)

        if len(df.columns) == 3:
            # Three columns: submission, reviewer, value (e.g., bids.csv, conflict_constraints.csv)
            g1, g2 = split_edge_file(df, subs_group1, revs_group1, subs_group2, revs_group2)
            g1.to_csv(os.path.join(group1_dir, filename), header=False, index=False)
            g2.to_csv(os.path.join(group2_dir, filename), header=False, index=False)
            print(f"  Group 1: {len(g1)}/{num_items} edges")
            print(f"  Group 2: {len(g2)}/{num_items} edges")
        elif len(df.columns) == 2:
            # Two columns: reviewer, value (e.g., quota.csv)
            g1 = df[df[0].isin(revs_group1)]
            g2 = df[df[0].isin(revs_group2)]
            g1.to_csv(os.path.join(group1_dir, filename), header=False, index=False)
            g2.to_csv(os.path.join(group2_dir, filename), header=False, index=False)
            print(f"  Group 1: {len(g1)}/{num_items} rows")
            print(f"  Group 2: {len(g2)}/{num_items} rows")
        else:
            print(f"  WARNING: Skipping file with {len(df.columns)} columns (expected 2 or 3)")

    # Print summary with supply/demand check
    print("\n=== Summary ===")
    print(f"Group 1: {len(subs_group1)} papers, {len(revs_group1)} reviewers, {len(scores_g1)} edges")
    print(f"Group 2: {len(subs_group2)} papers, {len(revs_group2)} reviewers, {len(scores_g2)} edges")
    
    # Warn about potential issues
    dropped_edges = len(scores) - len(scores_g1) - len(scores_g2)
    print(f"\nDropped cross-group edges: {dropped_edges} ({100*dropped_edges/len(scores):.1f}%)")
    
    print(f"\nOutput files created in:")
    print(f"  {group1_dir}/")
    print(f"  {group2_dir}/")
    print("Done!")
