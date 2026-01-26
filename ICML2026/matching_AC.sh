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
export FILTER_UNREGISTERED=False # Filter out unregistered reviewers (Set to False for testing)

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

export GROUP="Area_Chairs"

export MIN_PAPERS=6 # Minimum number of papers to assign to each reviewer
export MAX_PAPERS=12 # Maximum number of papers to assign to each reviewer
export MIN_POS_BIDS=10 # minimum number of positive bids in order to take them into account


if [ -z "$SLURM_JOB_NAME" ] && [ -z "$SLURM_JOB_ID" ]; then
    # Local execution (not running under SLURM or in an interactive session)
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export REVIEWER_FILE="reviewer.csv"
	export SUBMISSION_FILE="submission.csv"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/iter1_data"
    export ITER1_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter1_assignments"
elif [ -z "$SLURM_JOB_NAME" ]; then
    # Interactive session
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export REVIEWER_FILE="reviewer.csv"
	export SUBMISSION_FILE="submission.csv"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/iter1_data"
    export ITER1_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter1_assignments"
else
    # sbatch job
    export ROOT_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID"
    export DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/data"
	export REVIEWER_FILE="reviewer.csv"
	export SUBMISSION_FILE="submission.csv"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter1_data"
    export ASSIGNMENTS_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/assignments"
fi

mkdir -p $ROOT_FOLDER # create the scores folder
mkdir -p $DATA_FOLDER # create the data folder
mkdir -p $ITER1_ASSIGNMENTS_FOLDER # create the output folder
# mkdir -p $ITER2_ASSIGNMENTS_FOLDER # create the output folder
# mkdir -p $ITER3_ASSIGNMENTS_FOLDER # create the output folder

# Assert required files exist
# * ICML2026/$GROUP/data/bids.csv
# * ICML2026/$GROUP/no_or_paper_reviewers.csv
# * ICML2026/$GROUP/emergency-4plus-reviewers.csv
# * ICML2026/$GROUP/reciprocal-reviewer-noBid.csv
# * ICML2026/$GROUP/colluders.csv
# * ICML2026/$GROUP/$SCORES_FILE



printf "\n----------------------------------------"
printf "\nStarting matching..."
printf "\n----------------------------------------\n"

print_time $((SECONDS - start_time))

printf "\nHyper-parameters:"
printf "\n----------------------------------------"
printf "\nSCORES_FILE: $SCORES_FILE"
printf "\nQ: $Q"
printf "\nMAX_PAPERS: $MAX_PAPERS"
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


printf "\n\n\n----------------------------------------"
printf "\nSanitizing and preparing data..."
printf "\n----------------------------------------\n"



# ICML26: Get rid of reviewers that have not registered
cp $DATA_FOLDER/reviewer.csv $DATA_FOLDER/reviewer_filtered.csv
export REVIEWER_FILE="reviewer_filtered.csv"

python ICML2026/scripts/filter_reviewers.py \
	--reviewer $DATA_FOLDER/$REVIEWER_FILE \
		--output $DATA_FOLDER/unregistered_reviewers.csv \
		--filter_unregistered $FILTER_UNREGISTERED








# ITERATION 1: UNCONSTRAINED MATCHING

printf "\n\n\n========================================"
printf "\nAREA CHAIR MATCHING..."
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
	--exclude_reviewer_files $ITER1_DATA_FOLDER/unregistered_reviewers.csv \
	--files $ITER1_DATA_FOLDER/affinity_scores.csv \
		$ITER1_DATA_FOLDER/filtered_bids.csv \
		$ITER1_DATA_FOLDER/constraints/conflict_constraints.csv


# ---------------------------------------------------------------------------------
# Initial Matching of 3 reviewers per paper
# ---------------------------------------------------------------------------------



start_time=$SECONDS
python -m matcher \
	--scores $ITER1_DATA_FOLDER/affinity_scores.csv $ITER1_DATA_FOLDER/filtered_bids.csv \
	--weights 1 1 \
	--constraints $ITER1_DATA_FOLDER/constraints/conflict_constraints.csv \
	--min_papers_default $MIN_PAPERS \
	--max_papers_default $MAX_PAPERS \
	--num_reviewers 1 \
	--solver Randomized \
	--allow_zero_score_assignments \
	--probability_limits $Q \
	--output_folder $ITER1_ASSIGNMENTS_FOLDER

# mv $ITER1_ASSIGNMENTS_FOLDER/assignments.json $ITER1_ASSIGNMENTS_FOLDER/first_matching.json
# mv $ITER1_ASSIGNMENTS_FOLDER/alternates.json $ITER1_ASSIGNMENTS_FOLDER/first_matching_alternates.json
# print_time $((SECONDS - start_time))

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER1_ASSIGNMENTS_FOLDER/assignments.json \
	--output $ITER1_ASSIGNMENTS_FOLDER/assignments.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ITER1_ASSIGNMENTS_FOLDER/alternates.json \
	--output $ITER1_ASSIGNMENTS_FOLDER/alternates.csv
