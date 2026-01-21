#!/bin/bash
#SBATCH --reservation=ICML2026              # Reservation name
#SBATCH --output=/home/mila/j/juan.ramirez/output/%x-%j.out           # Output file
#SBATCH --error=/home/mila/j/juan.ramirez/output/%x-%j.err            # Error file
#SBATCH --time=48:00:00                     # Time limit hrs:min:sec
#SBATCH --ntasks=1                          # Number of tasks (cores)
#SBATCH --cpus-per-task=10			        # Number of CPUs per task
#SBATCH --mem=150GB                         # Memory limit
#SBATCH --mail-type=ALL                     # Email notifications
#SBATCH --mail-user=juan.ramirez@mila.quebec

# Redirect stderr to stdout so both logs go to the same file
exec 2>&1

# ----------------------------------------------------------------------------------
# Outline of the matching process for ICML 2025 Reviewers
# * Aggregate Affinity Scores (see aggregate_scores.sh)
# * Pre-process bids
# * Initial Matching of 3 reviewers per paper, with the following constraints:
#   * Conflicts
#   * No first-time reviewers
# * Second Matching. Assign a 4th reviewer to each paper, with the following constraints:
#   * Conflicts
#   * Geographical diversity
#   * Enforce the previous matching of 3 reviewers per paper
# ----------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------------------

# # For the matcher
# module load anaconda
# conda create -n openreview-matcher python=3.10
# conda activate openreview-matcher
# pip install .

# # For other scripts
# pip install pandas tqdm openreview-py dask pyarrow

# module load anaconda
# conda activate openreview-matcher

# ----------------------------------------------------------------------------------
# NOTE: the OpenReview matcher requires a Gurobi license.
# ----------------------------------------------------------------------------------

set -e  # Exit immediately if a command exits with a non-zero status

# Measure execution time and print in hours, minutes, and seconds
print_time() {
	local elapsed=$1
	printf "Elapsed time: %02d:%02d:%02d\n" $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60))
}

start_time=$SECONDS

# ----------------------------------------------------------------------------------
# Hyper-parameters
# ----------------------------------------------------------------------------------

# -------------------------------- Edit these variables --------------------------------

export DEBUG=False # Used to subsample submission and reviewer data

# ICML26: TODO - check Q values
export Q=.7
export SCORES_FILE=affinity_scores.csv


# # Max score: 1, 1, .55
# export Q=.55 # Upper bound on the marginal probability of each reviewer-paper pair being matched, for "Randomized" matcher
# export SCORES_FILE=aggregated_scores_max.csv

# # Least conservative: .75, .5, .55
# export Q=0.55
# export SCORES_FILE=least_conservative.csv

# # Moderately conservative: .825, .7, .7 (USED IN ICML 2025)
# export Q=0.7
# export SCORES_FILE=moderately_conservative.csv

# # Most conservative: .9, .9, .9
# export Q=0.9
# export SCORES_FILE=most_conservative.csv

# # Emphasizing randomization: .825, .7, .55
# export Q=0.55
# export SCORES_FILE=emphasizing_randomization.csv

# # Emphasizing non-OR weight: .825, .5, .7
# export Q=0.7
# export SCORES_FILE=emphasizing_non_or_weight.csv

# # Emphasizing quantiles: .75, .7, .7
# export Q=0.7
# export SCORES_FILE=emphasizing_quantiles.csv

export OPENREVIEW_USERNAME=''
export OPENREVIEW_PASSWORD=''

# ---------------------------- Do not edit these variables ----------------------------

export GROUP="Reviewers"

export MAX_PAPERS=5 # Maximum number of papers each reviewer can review
export NUM_REVIEWS=4 # Number of reviewers per paper
export MIN_POS_BIDS=4 # minimum number of positive bids in order to take them into account

if [ -z "$SLURM_JOB_NAME" ] && [ -z "$SLURM_JOB_ID" ]; then
    # Local execution (not running under SLURM or in an interactive session)
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/iter1_data"
	export ITER2_DATA_FOLDER="ICML2026/$GROUP/iter2_data"
	export ITER3_DATA_FOLDER="ICML2026/$GROUP/iter3_data"
    export ITER1_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter1_assignments"
	export ITER2_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter2_assignments"
	export ITER3_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter3_assignments"
elif [ -z "$SLURM_JOB_NAME" ]; then
    # Interactive session
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/iter1_data"
	export ITER2_DATA_FOLDER="ICML2026/$GROUP/iter2_data"
	export ITER3_DATA_FOLDER="ICML2026/$GROUP/iter3_data"
    export ITER1_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter1_assignments"
    export ITER2_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter2_assignments"
    export ITER3_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter3_assignments"
else
    # sbatch job
    export ROOT_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID"
    export DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/data"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter1_data"
	export ITER2_DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter2_data"
	export ITER3_DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter3_data"
    export ASSIGNMENTS_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/assignments"
fi

mkdir -p $ROOT_FOLDER # create the scores folder
mkdir -p $DATA_FOLDER # create the data folder
mkdir -p $ITER1_ASSIGNMENTS_FOLDER # create the output folder
mkdir -p $ITER2_ASSIGNMENTS_FOLDER # create the output folder
mkdir -p $ITER3_ASSIGNMENTS_FOLDER # create the output folder

# Assert required files exist
# * ICML2026/$GROUP/data/bids.csv
# * ICML2026/$GROUP/no_or_paper_reviewers.csv
# * ICML2026/$GROUP/emergency-4plus-reviewers.csv
# * ICML2026/$GROUP/reciprocal-reviewer-noBid.csv
# * ICML2026/$GROUP/colluders.csv
# * ICML2026/$GROUP/$SCORES_FILE

# ICML26: TODO - check which files are needed
# for file in ICML2026/$GROUP/data/bids.csv \
# 	ICML2026/$GROUP/no_or_paper_reviewers.csv \
# 	ICML2026/$GROUP/emergency-4plus-reviewers.csv \
# 	ICML2026/$GROUP/reciprocal-reviewer-noBid.csv \
# 	ICML2026/$GROUP/colluders.csv \
# 	ICML2026/$GROUP/$SCORES_FILE
for file in $DATA_FOLDER//bids.csv \
	$DATA_FOLDER/emergency-4plus-reviewers.csv \
	$DATA_FOLDER/reciprocal-reviewer-noBid.csv 
do
	if [ ! -f $file ]; then
		echo "File $file does not exist."
		exit 1
	fi
done

printf "All required files exist."

printf "\n----------------------------------------"
printf "\nStarting matching..."
printf "\n----------------------------------------\n"

print_time $((SECONDS - start_time))

printf "\nHyper-parameters:"
printf "\n----------------------------------------"
printf "\nSCORES_FILE: $SCORES_FILE"
printf "\nQ: $Q"
printf "\nMAX_PAPERS: $MAX_PAPERS"
printf "\nNUM_REVIEWS: $NUM_REVIEWS"
printf "\nMIN_POS_BIDS: $MIN_POS_BIDS"
printf "\nDEBUG: $DEBUG"
printf "\nROOT_FOLDER: $ROOT_FOLDER"
printf "\nDATA_FOLDER: $DATA_FOLDER"
printf "\nASSIGNMENTS_FOLDER: $ITER1_ASSIGNMENTS_FOLDER"

# Copy data to the scratch folder
# rsync -av --exclude 'archives' ICML2026/$GROUP/data/ $DATA_FOLDER

# # Copy first-time reviewer constraints to DATA_FOLDER/constraints
# mkdir -p $DATA_FOLDER/constraints
# cp ICML2026/$GROUP/no_or_paper_reviewers.csv $DATA_FOLDER/constraints

# Copy emergency reviewers to the root folder - they are ignored in the matching
# cp ICML2026/$GROUP/data/emergency-4plus-reviewers.csv $ROOT_FOLDER/data/emergency-4plus-reviewers.csv
# cp ICML2026/$GROUP/data/reciprocal-reviewer-noBid.csv $ROOT_FOLDER/data/reciprocal-reviewer-noBid.csv

# Copy scores to the root folder
# cp ICML2026/$GROUP/$SCORES_FILE $ROOT_FOLDER/scores.csv






# ITERATION 1: UNCONSTRAINED MATCHING

printf "\n\n\n========================================"
printf "\nITERATION 1: UNCONSTRAINED MATCHING..."
printf "\n========================================\n"


# Create the iter1 data folder and copy the data to it
mkdir -p $ITER1_DATA_FOLDER # create the iter1 data folder
cp -r $DATA_FOLDER/* $ITER1_DATA_FOLDER/ # copy all files and folders to the iter1 data folder

# ----------------------------------------------------------------------------------
# Pre-process data
# ----------------------------------------------------------------------------------

printf "\n----------------------------------------"
printf "\nPre-processing data..."
printf "\n----------------------------------------\n"

# TODO: Filter out suspicious bids

# Filter out bids from reviewers that do not have at least MIN_POS_BIDS positive bids
python ICML2026/scripts/filter_bids.py \
	--input $ITER1_DATA_FOLDER/bids.csv \
	--output $ITER1_DATA_FOLDER/filtered_bids.csv \
	--min-pos-bids $MIN_POS_BIDS
print_time $((SECONDS - start_time))

# ICML26: TODO - check if this is needed
# Prepare conflict constraints
# printf "\n----------------------------------------"
# python ICML2026/scripts/fetch_conflict_constraints.py \
# 	--match_group $GROUP \
# 	--output $ITER1_DATA_FOLDER/constraints/conflict_constraints.csv


# If in DEBUG mode, subsample the scores, bids, and constraints. Will overwrite the
# original files.
if [ "$DEBUG" = "True" ]; then
	printf "\n----------------------------------------"
	python ICML2026/scripts/subsample.py \
	--scores $ITER1_DATA_FOLDER/affinity_scores.csv \
	--files $ITER1_DATA_FOLDER/filtered_bids.csv \
		$ITER1_DATA_FOLDER/constraints/conflict_constraints.csv
fi

# Remove emergency reviewers from scores, bids, and constraints. NOTE: this will
# overwrite the original files.
printf "\n----------------------------------------"
python ICML2026/scripts/exclude_reviewers.py \
	--exclude_reviewer_files $ITER1_DATA_FOLDER/emergency-4plus-reviewers.csv \
		$ITER1_DATA_FOLDER/reciprocal-reviewer-noBid.csv \
	--files $ITER1_DATA_FOLDER//affinity_scores.csv \
		$ITER1_DATA_FOLDER/bids.csv \
		$ITER1_DATA_FOLDER/constraints/conflict_constraints.csv



# ---------------------------------------------------------------------------------
# Initial Matching of 3 reviewers per paper
# ---------------------------------------------------------------------------------

# ICML26: Removing first-time reviewer constraint for ICML 2026
# Remove first-time reviewers from scores, bids, and constraints for the initial
# matching only. Will produce new files with the prefix "first_matching_".
# printf "\n----------------------------------------"
# python ICML2026/scripts/remove_first_time_reviewers.py \
# 	--no_or_paper_reviewers $ITER1_DATA_FOLDER/no_or_paper_reviewers.csv \
# 	--scores $ROOT_FOLDER/affinity_scores.csv \
# 	--bids $ITER1_DATA_FOLDER/filtered_bids.csv \
# 	--constraints $ITER1_DATA_FOLDER/constraints/conflict_constraints.csv \
# 	--output_prefix first_matching

# Matching
printf "\n----------------------------------------"
printf "\nStarting first matching..."
printf "\n----------------------------------------\n"

start_time=$SECONDS
python -m matcher \
	--scores $ITER1_DATA_FOLDER/affinity_scores.csv $ITER1_DATA_FOLDER/filtered_bids.csv \
	--weights 1 1 \
	--constraints $ITER1_DATA_FOLDER/constraints/conflict_constraints.csv \
	--min_papers_default 0 \
	--max_papers_default $MAX_PAPERS \
	--num_reviewers $(($NUM_REVIEWS - 1)) \
	--solver Randomized \
	--allow_zero_score_assignments \
	--probability_limits $Q \
	--output_folder $ITER1_ASSIGNMENTS_FOLDER

mv $ITER1_ASSIGNMENTS_FOLDER/assignments.json $ITER1_ASSIGNMENTS_FOLDER/first_matching.json
mv $ITER1_ASSIGNMENTS_FOLDER/alternates.json $ITER1_ASSIGNMENTS_FOLDER/first_matching_alternates.json
print_time $((SECONDS - start_time))

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER1_ASSIGNMENTS_FOLDER/first_matching.json \
	--output $ITER1_ASSIGNMENTS_FOLDER/first_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER1_ASSIGNMENTS_FOLDER/first_matching_alternates.json \
	--output $ITER1_ASSIGNMENTS_FOLDER/first_matching_alternates.csv

# ---------------------------------------------------------------------------------
# Second matching. Assign a 4th reviewer to each paper
# ---------------------------------------------------------------------------------

# Extract the number of papers each reviewer can review in the second matching as
# MAX_PAPERS - number of papers assigned in the first matching
printf "\n----------------------------------------"
python ICML2026/scripts/reviewer_supply_after_matching.py \
	--assignments $ITER1_ASSIGNMENTS_FOLDER/first_matching.json \
	--max_papers $MAX_PAPERS \
	--supply_output $ITER1_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--exhausted_reviewers_output $ITER1_DATA_FOLDER/exhausted_reviewers.csv \
	--remaining_reviewer_constraints_output $ITER1_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
print_time $((SECONDS - start_time))

# ICML26: No geographical constraints for ICML 2026
# Extract geographical diversity constraints
# printf "\n----------------------------------------"
# python ICML2026/scripts/geographical_diversity.py \
# 	--assignments $ITER1_ASSIGNMENTS_FOLDER/first_matching.csv \
# 	--output $ITER1_DATA_FOLDER/constraints/geographical_constraints.csv
# print_time $((SECONDS - start_time))

# Remove emergency reviewers and reviewers without more reviews left before the
# second matching.
printf "\n----------------------------------------"
python ICML2026/scripts/exclude_reviewers.py \
	--exclude_reviewer_files $ITER1_DATA_FOLDER/emergency-4plus-reviewers.csv \
		$ITER1_DATA_FOLDER/reciprocal-reviewer-noBid.csv \
		$ITER1_DATA_FOLDER/exhausted_reviewers.csv \
	--files $ITER1_DATA_FOLDER/affinity_scores.csv \
		$ITER1_DATA_FOLDER/filtered_bids.csv \
		$ITER1_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER1_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv

# If in DEBUG mode, subsample the new constraints. Will overwrite the original files.
if [ "$DEBUG" = "True" ]; then
	printf "\n----------------------------------------"
	python ICML2026/scripts/subsample.py \
	--scores $ITER1_DATA_FOLDER/affinity_scores.csv \
	--files $ITER1_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
		$ITER1_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
fi

# Join constraints into a single file
printf "\n----------------------------------------"
python ICML2026/scripts/join_constraints.py \
	--files $ITER1_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER1_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
	--output $ITER1_DATA_FOLDER/constraints/constraints_for_second_matching.csv
print_time $((SECONDS - start_time))

# Matching
printf "\n----------------------------------------"
printf "\nStarting second matching..."
printf "\n----------------------------------------\n"

start_time=$SECONDS
python -m matcher \
	--scores $ITER1_DATA_FOLDER/affinity_scores.csv $ITER1_DATA_FOLDER/filtered_bids.csv \
	--weights 1 1 \
	--constraints $ITER1_DATA_FOLDER/constraints/constraints_for_second_matching.csv \
	--min_papers_default 0 \
	--max_papers_default $MAX_PAPERS \
	--max_papers $ITER1_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--num_reviewers 1 \
	--num_alternates 1 \
	--solver Randomized \
	--allow_zero_score_assignments \
	--probability_limits $Q \
	--output_folder $ITER1_ASSIGNMENTS_FOLDER

mv $ITER1_ASSIGNMENTS_FOLDER/assignments.json $ITER1_ASSIGNMENTS_FOLDER/second_matching.json
mv $ITER1_ASSIGNMENTS_FOLDER/alternates.json $ITER1_ASSIGNMENTS_FOLDER/second_matching_alternates.json
print_time $((SECONDS - start_time))

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER1_ASSIGNMENTS_FOLDER/second_matching.json \
	--output $ITER1_ASSIGNMENTS_FOLDER/second_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER1_ASSIGNMENTS_FOLDER/second_matching_alternates.json \
	--output $ITER1_ASSIGNMENTS_FOLDER/second_matching_alternates.csv

# ---------------------------------------------------------------------------------
printf "\n----------------------------------------"

# Join first and second matching assignments
python ICML2026/scripts/join_assignments.py \
	--files $ITER1_ASSIGNMENTS_FOLDER/first_matching.csv \
		$ITER1_ASSIGNMENTS_FOLDER/second_matching.csv \
	--output $ITER1_ASSIGNMENTS_FOLDER/final_assignments.csv


python ICML2026/scripts/evaluate_assignments.py \
	--assignments $ITER1_ASSIGNMENTS_FOLDER/final_assignments.csv \
	--output $ITER1_ASSIGNMENTS_FOLDER/evaluation.txt

printf "\nDone."
printf "\nSCORES_FILE: $SCORES_FILE"
printf "\nAssignments saved in $ITER1_ASSIGNMENTS_FOLDER"

print_time $((SECONDS - start_time))

















printf "\n\n\n========================================"
printf "\nITERATION 2: HARD Policy Constraints..."
printf "\n========================================\n"

# Create the iter2 data folder and copy the data to it
mkdir -p $ITER2_DATA_FOLDER # create the iter2 data folder
cp -r $DATA_FOLDER/* $ITER2_DATA_FOLDER/ # copy all files and folders to the iter2 data folder

# ----------------------------------------------------------------------------------
# Pre-process data
# ----------------------------------------------------------------------------------

printf "\n----------------------------------------"
printf "\nPre-processing data..."
printf "\n----------------------------------------\n"

# TODO: Filter out suspicious bids

# Filter out bids from reviewers that do not have at least MIN_POS_BIDS positive bids
python ICML2026/scripts/filter_bids.py \
	--input $ITER2_DATA_FOLDER/bids.csv \
	--output $ITER2_DATA_FOLDER/filtered_bids.csv \
	--min-pos-bids $MIN_POS_BIDS
print_time $((SECONDS - start_time))

# ICML26: TODO - check if this is needed
# Prepare conflict constraints
# printf "\n----------------------------------------"
# python ICML2026/scripts/fetch_conflict_constraints.py \
# 	--match_group $GROUP \
# 	--output $ITER2_DATA_FOLDER/constraints/conflict_constraints.csv

# ICML26: fetch policy constraints
printf "\n----------------------------------------"
python ICML2026/scripts/fetch_policy_constraints.py \
	--match_group $GROUP \
	--submission $ITER2_DATA_FOLDER/submission.csv \
	--reviewer $ITER2_DATA_FOLDER/reviewer.csv \
	--outputs $ITER2_DATA_FOLDER/constraints/hard_policy_constraints.csv \
			$ITER2_DATA_FOLDER/constraints/soft_policy_constraints.csv

# If in DEBUG mode, subsample the scores, bids, and constraints. Will overwrite the
# original files.
if [ "$DEBUG" = "True" ]; then
	printf "\n----------------------------------------"
	python ICML2026/scripts/subsample.py \
	--scores $ITER2_DATA_FOLDER/affinity_scores.csv \
	--files $ITER2_DATA_FOLDER/filtered_bids.csv \
		$ITER2_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER2_DATA_FOLDER/constraints/hard_policy_constraints.csv \
		$ITER2_DATA_FOLDER/constraints/soft_policy_constraints.csv
fi

# Remove emergency reviewers from scores, bids, and constraints. NOTE: this will
# overwrite the original files.
printf "\n----------------------------------------"
python ICML2026/scripts/exclude_reviewers.py \
	--exclude_reviewer_files $ITER2_DATA_FOLDER/emergency-4plus-reviewers.csv \
		$ITER2_DATA_FOLDER/reciprocal-reviewer-noBid.csv \
	--files $ITER2_DATA_FOLDER//affinity_scores.csv \
		$ITER2_DATA_FOLDER/bids.csv \
		$ITER2_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER2_DATA_FOLDER/constraints/hard_policy_constraints.csv \
		$ITER2_DATA_FOLDER/constraints/soft_policy_constraints.csv

# Matching
printf "\n----------------------------------------"
printf "\nStarting first matching..."
printf "\n----------------------------------------\n"

# Join constraints into a single file
printf "\n----------------------------------------"
python ICML2026/scripts/join_constraints.py \
	--files $ITER2_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER2_DATA_FOLDER/constraints/hard_policy_constraints.csv \
	--output $ITER2_DATA_FOLDER/constraints/agg_constraints.csv


start_time=$SECONDS
python -m matcher \
	--scores $ITER2_DATA_FOLDER/affinity_scores.csv $ITER2_DATA_FOLDER/filtered_bids.csv \
	--weights 1 1 \
	--constraints $ITER2_DATA_FOLDER/constraints/agg_constraints.csv \
	--min_papers_default 0 \
	--max_papers_default $MAX_PAPERS \
	--num_reviewers $(($NUM_REVIEWS - 1)) \
	--solver Randomized \
	--allow_zero_score_assignments \
	--probability_limits $Q \
	--output_folder $ITER2_ASSIGNMENTS_FOLDER

mv $ITER2_ASSIGNMENTS_FOLDER/assignments.json $ITER2_ASSIGNMENTS_FOLDER/first_matching.json
mv $ITER2_ASSIGNMENTS_FOLDER/alternates.json $ITER2_ASSIGNMENTS_FOLDER/first_matching_alternates.json
print_time $((SECONDS - start_time))

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER2_ASSIGNMENTS_FOLDER/first_matching.json \
	--output $ITER2_ASSIGNMENTS_FOLDER/first_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER2_ASSIGNMENTS_FOLDER/first_matching_alternates.json \
	--output $ITER2_ASSIGNMENTS_FOLDER/first_matching_alternates.csv

# ---------------------------------------------------------------------------------
# Second matching. Assign a 4th reviewer to each paper
# ---------------------------------------------------------------------------------

# Extract the number of papers each reviewer can review in the second matching as
# MAX_PAPERS - number of papers assigned in the first matching
printf "\n----------------------------------------"
python ICML2026/scripts/reviewer_supply_after_matching.py \
	--assignments $ITER2_ASSIGNMENTS_FOLDER/first_matching.json \
	--max_papers $MAX_PAPERS \
	--supply_output $ITER2_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--exhausted_reviewers_output $ITER2_DATA_FOLDER/exhausted_reviewers.csv \
	--remaining_reviewer_constraints_output $ITER2_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
print_time $((SECONDS - start_time))

# ICML26: No geographical constraints for ICML 2026
# Extract geographical diversity constraints
# printf "\n----------------------------------------"
# python ICML2026/scripts/geographical_diversity.py \
# 	--assignments $ITER2_ASSIGNMENTS_FOLDER/first_matching.csv \
# 	--output $ITER2_DATA_FOLDER/constraints/geographical_constraints.csv
# print_time $((SECONDS - start_time))

# Remove emergency reviewers and reviewers without more reviews left before the
# second matching.
printf "\n----------------------------------------"
python ICML2026/scripts/exclude_reviewers.py \
	--exclude_reviewer_files $ITER2_DATA_FOLDER/emergency-4plus-reviewers.csv \
		$ITER2_DATA_FOLDER/reciprocal-reviewer-noBid.csv \
		$ITER2_DATA_FOLDER/exhausted_reviewers.csv \
	--files $ITER2_DATA_FOLDER/affinity_scores.csv \
		$ITER2_DATA_FOLDER/filtered_bids.csv \
		$ITER2_DATA_FOLDER/constraints/agg_constraints.csv \
		$ITER2_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv

# If in DEBUG mode, subsample the new constraints. Will overwrite the original files.
if [ "$DEBUG" = "True" ]; then
	printf "\n----------------------------------------"
	python ICML2026/scripts/subsample.py \
	--scores $ITER2_DATA_FOLDER/affinity_scores.csv \
	--files $ITER2_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
		$ITER2_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
fi

# Join constraints into a single file
printf "\n----------------------------------------"
python ICML2026/scripts/join_constraints.py \
	--files $ITER2_DATA_FOLDER/constraints/agg_constraints.csv \
		$ITER2_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
	--output $ITER2_DATA_FOLDER/constraints/constraints_for_second_matching.csv
print_time $((SECONDS - start_time))

# Matching
printf "\n----------------------------------------"
printf "\nStarting second matching..."
printf "\n----------------------------------------\n"

start_time=$SECONDS
python -m matcher \
	--scores $ITER2_DATA_FOLDER/affinity_scores.csv $ITER2_DATA_FOLDER/filtered_bids.csv \
	--weights 1 1 \
	--constraints $ITER2_DATA_FOLDER/constraints/constraints_for_second_matching.csv \
	--min_papers_default 0 \
	--max_papers_default $MAX_PAPERS \
	--max_papers $ITER2_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--num_reviewers 1 \
	--num_alternates 1 \
	--solver Randomized \
	--allow_zero_score_assignments \
	--probability_limits $Q \
	--output_folder $ITER2_ASSIGNMENTS_FOLDER

mv $ITER2_ASSIGNMENTS_FOLDER/assignments.json $ITER2_ASSIGNMENTS_FOLDER/second_matching.json
mv $ITER2_ASSIGNMENTS_FOLDER/alternates.json $ITER2_ASSIGNMENTS_FOLDER/second_matching_alternates.json
print_time $((SECONDS - start_time))

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER2_ASSIGNMENTS_FOLDER/second_matching.json \
	--output $ITER2_ASSIGNMENTS_FOLDER/second_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER2_ASSIGNMENTS_FOLDER/second_matching_alternates.json \
	--output $ITER2_ASSIGNMENTS_FOLDER/second_matching_alternates.csv

# ---------------------------------------------------------------------------------
printf "\n----------------------------------------"

# Join first and second matching assignments
python ICML2026/scripts/join_assignments.py \
	--files $ITER2_ASSIGNMENTS_FOLDER/first_matching.csv \
		$ITER2_ASSIGNMENTS_FOLDER/second_matching.csv \
	--output $ITER2_ASSIGNMENTS_FOLDER/final_assignments.csv


python ICML2026/scripts/evaluate_assignments.py \
	--assignments $ITER2_ASSIGNMENTS_FOLDER/final_assignments.csv \
	--output $ITER2_ASSIGNMENTS_FOLDER/evaluation.txt

printf "\nDone."
printf "\nSCORES_FILE: $SCORES_FILE"
printf "\nAssignments saved in $ITER2_ASSIGNMENTS_FOLDER"

print_time $((SECONDS - start_time))


















printf "\n\n\n========================================"
printf "\nITERATION 3: SOFT Policy Constraints..."
printf "\n========================================\n"

# Create the iter2 data folder and copy the data to it
mkdir -p $ITER3_DATA_FOLDER # create the iter2 data folder
cp -r $DATA_FOLDER/* $ITER3_DATA_FOLDER/ # copy all files and folders to the iter2 data folder

# ----------------------------------------------------------------------------------
# Pre-process data
# ----------------------------------------------------------------------------------

printf "\n----------------------------------------"
printf "\nPre-processing data..."
printf "\n----------------------------------------\n"

# TODO: Filter out suspicious bids

# Filter out bids from reviewers that do not have at least MIN_POS_BIDS positive bids
python ICML2026/scripts/filter_bids.py \
	--input $ITER3_DATA_FOLDER/bids.csv \
	--output $ITER3_DATA_FOLDER/filtered_bids.csv \
	--min-pos-bids $MIN_POS_BIDS
print_time $((SECONDS - start_time))

# ICML26: TODO - check if this is needed
# Prepare conflict constraints
# printf "\n----------------------------------------"
# python ICML2026/scripts/fetch_conflict_constraints.py \
# 	--match_group $GROUP \
# 	--output $ITER3_DATA_FOLDER/constraints/conflict_constraints.csv

# ICML26: fetch policy constraints
printf "\n----------------------------------------"
python ICML2026/scripts/fetch_policy_constraints.py \
	--match_group $GROUP \
	--submission $ITER3_DATA_FOLDER/submission.csv \
	--reviewer $ITER3_DATA_FOLDER/reviewer.csv \
	--outputs $ITER3_DATA_FOLDER/constraints/hard_policy_constraints.csv \
			$ITER3_DATA_FOLDER/constraints/soft_policy_constraints.csv

# If in DEBUG mode, subsample the scores, bids, and constraints. Will overwrite the
# original files.
if [ "$DEBUG" = "True" ]; then
	printf "\n----------------------------------------"
	python ICML2026/scripts/subsample.py \
	--scores $ITER3_DATA_FOLDER/affinity_scores.csv \
	--files $ITER3_DATA_FOLDER/filtered_bids.csv \
		$ITER3_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER3_DATA_FOLDER/constraints/hard_policy_constraints.csv \
		$ITER3_DATA_FOLDER/constraints/soft_policy_constraints.csv
fi

# Remove emergency reviewers from scores, bids, and constraints. NOTE: this will
# overwrite the original files.
printf "\n----------------------------------------"
python ICML2026/scripts/exclude_reviewers.py \
	--exclude_reviewer_files $ITER3_DATA_FOLDER/emergency-4plus-reviewers.csv \
		$ITER3_DATA_FOLDER/reciprocal-reviewer-noBid.csv \
	--files $ITER3_DATA_FOLDER//affinity_scores.csv \
		$ITER3_DATA_FOLDER/bids.csv \
		$ITER3_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER3_DATA_FOLDER/constraints/hard_policy_constraints.csv \
		$ITER3_DATA_FOLDER/constraints/soft_policy_constraints.csv

# Matching
printf "\n----------------------------------------"
printf "\nStarting first matching..."
printf "\n----------------------------------------\n"

# Join constraints into a single file
printf "\n----------------------------------------"
python ICML2026/scripts/join_constraints.py \
	--files $ITER3_DATA_FOLDER/constraints/conflict_constraints.csv \
		$ITER3_DATA_FOLDER/constraints/soft_policy_constraints.csv \
	--output $ITER3_DATA_FOLDER/constraints/agg_constraints.csv


start_time=$SECONDS
python -m matcher \
	--scores $ITER3_DATA_FOLDER/affinity_scores.csv $ITER3_DATA_FOLDER/filtered_bids.csv \
	--weights 1 1 \
	--constraints $ITER3_DATA_FOLDER/constraints/agg_constraints.csv \
	--min_papers_default 0 \
	--max_papers_default $MAX_PAPERS \
	--num_reviewers $(($NUM_REVIEWS - 1)) \
	--solver Randomized \
	--allow_zero_score_assignments \
	--probability_limits $Q \
	--output_folder $ITER3_ASSIGNMENTS_FOLDER

mv $ITER3_ASSIGNMENTS_FOLDER/assignments.json $ITER3_ASSIGNMENTS_FOLDER/first_matching.json
mv $ITER3_ASSIGNMENTS_FOLDER/alternates.json $ITER3_ASSIGNMENTS_FOLDER/first_matching_alternates.json
print_time $((SECONDS - start_time))

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER3_ASSIGNMENTS_FOLDER/first_matching.json \
	--output $ITER3_ASSIGNMENTS_FOLDER/first_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER3_ASSIGNMENTS_FOLDER/first_matching_alternates.json \
	--output $ITER3_ASSIGNMENTS_FOLDER/first_matching_alternates.csv

# ---------------------------------------------------------------------------------
# Second matching. Assign a 4th reviewer to each paper
# ---------------------------------------------------------------------------------

# Extract the number of papers each reviewer can review in the second matching as
# MAX_PAPERS - number of papers assigned in the first matching
printf "\n----------------------------------------"
python ICML2026/scripts/reviewer_supply_after_matching.py \
	--assignments $ITER3_ASSIGNMENTS_FOLDER/first_matching.json \
	--max_papers $MAX_PAPERS \
	--supply_output $ITER3_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--exhausted_reviewers_output $ITER3_DATA_FOLDER/exhausted_reviewers.csv \
	--remaining_reviewer_constraints_output $ITER3_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
print_time $((SECONDS - start_time))

# ICML26: No geographical constraints for ICML 2026
# Extract geographical diversity constraints
# printf "\n----------------------------------------"
# python ICML2026/scripts/geographical_diversity.py \
# 	--assignments $ITER3_ASSIGNMENTS_FOLDER/first_matching.csv \
# 	--output $ITER3_DATA_FOLDER/constraints/geographical_constraints.csv
# print_time $((SECONDS - start_time))

# Remove emergency reviewers and reviewers without more reviews left before the
# second matching.
printf "\n----------------------------------------"
python ICML2026/scripts/exclude_reviewers.py \
	--exclude_reviewer_files $ITER3_DATA_FOLDER/emergency-4plus-reviewers.csv \
		$ITER3_DATA_FOLDER/reciprocal-reviewer-noBid.csv \
		$ITER3_DATA_FOLDER/exhausted_reviewers.csv \
	--files $ITER3_DATA_FOLDER/affinity_scores.csv \
		$ITER3_DATA_FOLDER/filtered_bids.csv \
		$ITER3_DATA_FOLDER/constraints/agg_constraints.csv \
		$ITER3_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv

# If in DEBUG mode, subsample the new constraints. Will overwrite the original files.
if [ "$DEBUG" = "True" ]; then
	printf "\n----------------------------------------"
	python ICML2026/scripts/subsample.py \
	--scores $ITER3_DATA_FOLDER/affinity_scores.csv \
	--files $ITER3_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
		$ITER3_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
fi

# Join constraints into a single file
printf "\n----------------------------------------"
python ICML2026/scripts/join_constraints.py \
	--files $ITER3_DATA_FOLDER/constraints/agg_constraints.csv \
		$ITER3_DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
	--output $ITER3_DATA_FOLDER/constraints/constraints_for_second_matching.csv
print_time $((SECONDS - start_time))

# Matching
printf "\n----------------------------------------"
printf "\nStarting second matching..."
printf "\n----------------------------------------\n"

start_time=$SECONDS
python -m matcher \
	--scores $ITER3_DATA_FOLDER/affinity_scores.csv $ITER3_DATA_FOLDER/filtered_bids.csv \
	--weights 1 1 \
	--constraints $ITER3_DATA_FOLDER/constraints/constraints_for_second_matching.csv \
	--min_papers_default 0 \
	--max_papers_default $MAX_PAPERS \
	--max_papers $ITER3_DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--num_reviewers 1 \
	--num_alternates 1 \
	--solver Randomized \
	--allow_zero_score_assignments \
	--probability_limits $Q \
	--output_folder $ITER3_ASSIGNMENTS_FOLDER

mv $ITER3_ASSIGNMENTS_FOLDER/assignments.json $ITER3_ASSIGNMENTS_FOLDER/second_matching.json
mv $ITER3_ASSIGNMENTS_FOLDER/alternates.json $ITER3_ASSIGNMENTS_FOLDER/second_matching_alternates.json
print_time $((SECONDS - start_time))

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER3_ASSIGNMENTS_FOLDER/second_matching.json \
	--output $ITER3_ASSIGNMENTS_FOLDER/second_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER3_ASSIGNMENTS_FOLDER/second_matching_alternates.json \
	--output $ITER3_ASSIGNMENTS_FOLDER/second_matching_alternates.csv

# ---------------------------------------------------------------------------------
printf "\n----------------------------------------"

# Join first and second matching assignments
python ICML2026/scripts/join_assignments.py \
	--files $ITER3_ASSIGNMENTS_FOLDER/first_matching.csv \
		$ITER3_ASSIGNMENTS_FOLDER/second_matching.csv \
	--output $ITER3_ASSIGNMENTS_FOLDER/final_assignments.csv


python ICML2026/scripts/evaluate_assignments.py \
	--assignments $ITER3_ASSIGNMENTS_FOLDER/final_assignments.csv \
	--output $ITER3_ASSIGNMENTS_FOLDER/evaluation.txt

printf "\nDone."
printf "\nSCORES_FILE: $SCORES_FILE"
printf "\nAssignments saved in $ITER3_ASSIGNMENTS_FOLDER"

print_time $((SECONDS - start_time))






