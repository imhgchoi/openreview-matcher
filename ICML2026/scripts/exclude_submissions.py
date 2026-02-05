import argparse
import pandas as pd

if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--final_submissions", type=str, help="File with final submissions")
    argparser.add_argument("--submission", type=str, help="File with submissions")
    argparser.add_argument("--files", type=str, nargs="+", help="List of files to subsample")

    args = argparser.parse_args()

    print(f"\nExcluding submissions from files")

    if args.submission is not None:
        final_submissions = pd.read_csv(args.final_submissions)
        current_submissions = pd.read_csv(args.submission)

        final_submissions_set = set(final_submissions['id'].unique())
        current_submissions_set = set(current_submissions['submission'].unique())

        submissions_to_exclude = current_submissions_set - final_submissions_set

        print(f"Loaded {len(submissions_to_exclude)} submissions to exclude")

        # exclude submissions_to_exclude from current_submissions
        updated_submissions = current_submissions[~current_submissions['submission'].isin(submissions_to_exclude)]
        updated_submissions.to_csv(args.submission, index=False)

    if args.files is not None:
        final_submissions = pd.read_csv(args.final_submissions)['id'].unique().tolist()
        for file in args.files:
            df = pd.read_csv(file, header=None)
            assert len(df.columns) == 3, "Make sure the files have 3 columns"
            
            df = df[df.loc[:,0].isin(final_submissions)]
            df.to_csv(file, header=False, index=False)

        


    # import pdb;pdb.set_trace()

    # emergency_reviewers = set()
    # for file in args.exclude_reviewer_files:
    #     try:
    #         this_reviewers = set(pd.read_csv(file, header=None)[0])
    #     except pd.errors.EmptyDataError:
    #         this_reviewers = set()
    #     emergency_reviewers = emergency_reviewers.union(this_reviewers)

    # print(f"Loaded {len(emergency_reviewers)} reviewers to exclude")

    # for file in args.files:

    #     print(f"\nRemoving reviewers from {file}")
    #     try:
    #         df = pd.read_csv(file, header=None)
    #     except pd.errors.EmptyDataError:
    #         print(f"Warning: {file} is empty. Skipping.")
    #         continue

    #     if len(df.columns) == 3:
    #         # If file has 3 columns:
    #         reviewer_column = 1
    #     elif len(df.columns) == 2:
    #         # If file has 2 columns:
    #         reviewer_column = 0
    #     else:
    #         raise ValueError("File should have 2 or 3 columns")

    #     num_reviewers_in_file = len(df[reviewer_column].unique())
    #     print(f"Found {num_reviewers_in_file} reviewers")

    #     df = df[~df[reviewer_column].isin(emergency_reviewers)]
    #     num_reviewer_after_filter = len(df[reviewer_column].unique())

    #     print(f"Removed {num_reviewers_in_file - num_reviewer_after_filter} reviewers")
    #     print(f"Kept {num_reviewer_after_filter} reviewers")

    #     df.to_csv(file, header=False, index=False)
    #     print(f"Saved filtered file to {file}")

    # print("\nDone!")