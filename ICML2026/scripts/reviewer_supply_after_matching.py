import argparse
import pandas as pd
import json
import csv

if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--assignments", type=str, required=True)
    argparser.add_argument("--max_papers", type=int, help="Default max papers per reviewer (used if --quota not provided or for reviewers not in quota file)")
    argparser.add_argument("--quota", type=str, help="Quota file (CSV with header row: user,quota) with individual quotas per reviewer")
    argparser.add_argument("--supply_output", type=str, required=True, help="Output file with reviewer supply")
    argparser.add_argument("--exhausted_reviewers_output", type=str, required=True, help="Output file with exhausted reviewers")
    argparser.add_argument("--remaining_reviewer_constraints_output", type=str, required=True, help="Output file with remaining reviewer constraints")

    args = argparser.parse_args()

    # Validate arguments
    if not args.quota and not args.max_papers:
        argparser.error("Either --quota or --max_papers must be provided")

    print(f"\nGathering reviewer supply after first matching")

    # Load quota mapping if provided
    quota_map = {}
    if args.quota:
        print(f"Loading quota file: {args.quota}")
        with open(args.quota, "r") as f:
            reader = csv.reader(f)
            next(reader, None)  # Skip header row
            for row in reader:
                if len(row) >= 2:
                    reviewer_id = row[0].strip()
                    quota = int(row[1].strip())
                    quota_map[reviewer_id] = quota
        print(f"Loaded quotas for {len(quota_map)} reviewers")

    # assignments is a json file with the following format:
    # {
    #     "paper_id": {
    #         "reviewer_id",
    #         "score",
    #      },
    #  ...
    # }
    with open(args.assignments, "r") as f:
        data = json.load(f)

    # output is a CSV file with the following format:
    # reviewer_id, supply

    # Count number of reviews per reviewer
    assignment_counts = {}
    constraints = []
    for paper_id, reviews in data.items():
        for review in reviews:
            reviewer_id = review["user"]
            assignment_counts[reviewer_id] = assignment_counts.get(reviewer_id, 0) + 1
            constraints.append((paper_id, reviewer_id, -1)) # -1 is a conflict

    # -------------------------------------------------------
    # Build complete list of reviewers to consider
    # Include all reviewers from quota file (if provided) and all reviewers with assignments
    # -------------------------------------------------------
    
    # Start with all reviewers who have assignments
    all_reviewers = set(assignment_counts.keys())
    
    # If quota file is provided, include all reviewers from quota file
    if args.quota:
        all_reviewers.update(quota_map.keys())
    
    # Create DataFrame with all reviewers
    reviewer_data = []
    for reviewer_id in sorted(all_reviewers):
        num_assignments = assignment_counts.get(reviewer_id, 0)
        reviewer_data.append({
            "reviewer_id": reviewer_id,
            "num_assignments": num_assignments
        })
    
    counts = pd.DataFrame(reviewer_data)

    # -------------------------------------------------------
    # Save the remainder supply for each reviewer
    # -------------------------------------------------------

    # Supply is quota (or max_papers) - number of reviews
    # Use individual quota if available, otherwise fall back to max_papers
    def get_max_papers(reviewer_id):
        if reviewer_id in quota_map:
            return quota_map[reviewer_id]
        elif args.max_papers:
            return args.max_papers
        else:
            raise ValueError(f"No quota or max_papers specified for reviewer {reviewer_id}")

    counts["max_papers"] = counts["reviewer_id"].apply(get_max_papers)
    counts["supply"] = counts["max_papers"] - counts["num_assignments"]

    total_supply = counts["supply"].sum()
    total_max_papers = counts["max_papers"].sum()
    avg_max_papers = counts["max_papers"].mean()
    avg_supply = counts["supply"].mean()
    num_reviewers_with_assignments = (counts["num_assignments"] > 0).sum()
    print(f"\nTotal reviewers considered: {len(counts)}")
    print(f"Reviewers with assignments: {num_reviewers_with_assignments}")
    print(f"Total reviewer supply: {total_supply}, as opposed to {total_max_papers} in the beginning.")
    print(f"Average reviewer supply: {avg_supply:.2f}, as opposed to {avg_max_papers:.2f} in the beginning.")

    print(f"\nSaving reviewer supply to {args.supply_output}")
    # Save only reviewer_id and supply columns
    counts[["reviewer_id", "supply"]].to_csv(args.supply_output, index=False, header=False)

    # -------------------------------------------------------
    # Save list of reviewers without supply; these will be excluded from the next matching
    # -------------------------------------------------------
    exhausted_reviewers = counts[counts["supply"] <= 0]

    num_exhausted_reviewers = len(exhausted_reviewers)
    print(f"\nNumber of reviewers without supply: {num_exhausted_reviewers}")
    print(f"Saving exhausted reviewers to {args.exhausted_reviewers_output}")

    exhausted_reviewers[["reviewer_id"]].to_csv(args.exhausted_reviewers_output, index=False, header=False)

    # -------------------------------------------------------
    # For each existing assignment of a reviewer with supply, set a constraint to ensure
    # that the reviewer can not be assigned to papers that they have already review
    # -------------------------------------------------------
    print(f"\nCreating constraints for reviewers with supply so they are not assigned to papers they have already reviewed")

    constraints_df = pd.DataFrame(constraints)

    # Filter out reviewers without supply
    constraints_df = constraints_df[~constraints_df[1].isin(exhausted_reviewers["reviewer_id"])]
    num_constraints = len(constraints_df)
    nun_constraints_reviewers = len(constraints_df[1].unique())

    print(f"Saving {len(constraints_df)} constraints for {nun_constraints_reviewers} reviewers to {args.remaining_reviewer_constraints_output}")

    constraints_df.to_csv(args.remaining_reviewer_constraints_output, index=False, header=False)

    print("\nDone!")
