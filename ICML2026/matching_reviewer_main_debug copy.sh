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


export DEBUG=True # Used to subsample submission and reviewer data
export PREPROCESS_DATA=False # Preprocess data

export EXPERIMENT=True # Experimental Manipulation
export FLIP_RATE=0.1 # Ratio of "Okay with Policy B" Papers to be flipped to Policy A.
export FILTER_UNREGISTERED=True # Filter out unregistered reviewers (Set to False for testing)
export COUNTRY_CONSTRAINTS=True # Use country constraints
export QUALITY_CONSTRAINTS=False # Use quality constraints

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

export GROUP="Reviewers_Main_Debug"

export MAX_PAPERS=5 # Maximum number of papers each reviewer can review
export NUM_REVIEWS=4 # Number of reviewers per paper
export MIN_POS_BIDS=4 # minimum number of positive bids in order to take them into account

if [ -z "$SLURM_JOB_NAME" ] && [ -z "$SLURM_JOB_ID" ]; then
    # Local execution (not running under SLURM or in an interactive session)
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export REVIEWER_FILE="reviewer.csv"
	export SUBMISSION_FILE="submission.csv"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/iter1_data"
	export ITER2_DATA_FOLDER="ICML2026/$GROUP/iter2_data"
	export ITER3_DATA_FOLDER="ICML2026/$GROUP/iter3_data"
    export ITER1_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter1_assignments"
	export ITER2_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter2_assignments"
	export ITER3_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter3_assignments"
	export SCORES_FILE="affinity_scores.csv"
elif [ -z "$SLURM_JOB_NAME" ]; then
    # Interactive session
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export REVIEWER_FILE="reviewer.csv"
	export SUBMISSION_FILE="submission.csv"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/iter1_data"
	export ITER2_DATA_FOLDER="ICML2026/$GROUP/iter2_data"
	export ITER3_DATA_FOLDER="ICML2026/$GROUP/iter3_data"
    export ITER1_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter1_assignments"
    export ITER2_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter2_assignments"
    export ITER3_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/iter3_assignments"
	export SCORES_FILE="affinity_scores.csv"
else
    # sbatch job
    export ROOT_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID"
    export DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/data"
	export REVIEWER_FILE="reviewer.csv"
	export SUBMISSION_FILE="submission.csv"
	export ITER1_DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter1_data"
	export ITER2_DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter2_data"
	export ITER3_DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter3_data"
    export ITER1_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter1_assignments"
    export ITER2_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter2_assignments"
    export ITER3_ASSIGNMENTS_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/iter3_assignments"
	export SCORES_FILE="affinity_scores.csv"
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
# for file in $DATA_FOLDER/bids.csv \
# 	$DATA_FOLDER/emergency-4plus-reviewers.csv \
# 	$DATA_FOLDER/reciprocal-reviewer-noBid.csv 
# do
# 	if [ ! -f $file ]; then
# 		echo "File $file does not exist."
# 		exit 1
# 	fi
# done

# printf "All required files exist."

printf "\n----------------------------------------"
printf "\nStarting Algorithm..."
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
printf "\nASSIGNMENTS_FOLDER ITER1: $ITER1_ASSIGNMENTS_FOLDER"
printf "\nASSIGNMENTS_FOLDER ITER2: $ITER2_ASSIGNMENTS_FOLDER"
printf "\nASSIGNMENTS_FOLDER ITER3: $ITER3_ASSIGNMENTS_FOLDER"

# Copy data to the scratch folder
# THIS SEEMS TO BE NEEDED WITH SLURM
# rsync -av --exclude 'archives' ICML2026/$GROUP/data/ $DATA_FOLDER


# Copy emergency reviewers to the root folder - they are ignored in the matching
# cp ICML2026/$GROUP/data/emergency-4plus-reviewers.csv $ROOT_FOLDER/data/emergency-4plus-reviewers.csv
# cp ICML2026/$GROUP/data/reciprocal-reviewer-noBid.csv $ROOT_FOLDER/data/reciprocal-reviewer-noBid.csv

# Copy scores to the root folder
# cp ICML2026/$GROUP/$SCORES_FILE $ROOT_FOLDER/scores.csv


# ----------------------------------------------------------------------------------
# Pre-process data
# ----------------------------------------------------------------------------------

if [ "$PREPROCESS_DATA" = "True" ]; then
	printf "\n----------------------------------------"
	printf "\nPre-processing data..."
	printf "\n----------------------------------------\n"


	# ICML26: Experimental Manipulation - Flip some papers from Policy B to Policy A
	# NOTE: submission.csv will be overwritten, and the original file will be saved with the suffix "_original".
	if [ "$EXPERIMENT" = "True" ]; then
		printf "\n----------------------------------------"
		printf "\nEXPERIMENTAL MANIPULATION: Flipping papers from Policy B to Policy A..."

		cp $DATA_FOLDER/submission.csv $DATA_FOLDER/submission_flipped.csv
		export SUBMISSION_FILE="submission_flipped.csv"

		python ICML2026/scripts/flip_paper_policy.py \
			--match_group $GROUP \
			--submission $DATA_FOLDER/$SUBMISSION_FILE \
			--flip_rate $FLIP_RATE
	fi


	# ICML26: Get rid of reviewers that have not registered
	cp $DATA_FOLDER/reviewer.csv $DATA_FOLDER/reviewer_filtered.csv
	export REVIEWER_FILE="reviewer_filtered.csv"

	python ICML2026/scripts/filter_reviewers.py \
		--reviewer $DATA_FOLDER/$REVIEWER_FILE \
			--output $DATA_FOLDER/unregistered_reviewers.csv \
			--filter_unregistered $FILTER_UNREGISTERED


	# TODO: Filter out suspicious bids

	# Filter out bids from reviewers that do not have at least MIN_POS_BIDS positive bids
	python ICML2026/scripts/filter_bids.py \
		--input $DATA_FOLDER/bids.csv \
		--output $DATA_FOLDER/filtered_bids.csv \
		--min-pos-bids $MIN_POS_BIDS
	print_time $((SECONDS - start_time))

	# ICML26: TODO - check if this is needed
	# Prepare conflict constraints
	# printf "\n----------------------------------------"
	# python ICML2026/scripts/fetch_conflict_constraints.py \
	# 	--match_group $GROUP \
	# 	--output $DATA_FOLDER/constraints/conflict_constraints.csv

	# ICML26: fetch policy constraints
	printf "\n----------------------------------------"
	python ICML2026/scripts/fetch_policy_constraints.py \
		--match_group $GROUP \
		--submission $DATA_FOLDER/$SUBMISSION_FILE \
		--reviewer $DATA_FOLDER/$REVIEWER_FILE \
		--outputs $DATA_FOLDER/constraints/hard_policy_constraints.csv \
				$DATA_FOLDER/constraints/soft_policy_constraints.csv


	# Remove emergency reviewers from scores, bids, and constraints. NOTE: this will
	# overwrite the original files.
	printf "\n----------------------------------------"
	python ICML2026/scripts/exclude_reviewers.py \
		--exclude_reviewer_files $DATA_FOLDER/emergency-4plus-reviewers.csv \
			$DATA_FOLDER/reciprocal-reviewer-noBid.csv \
			$DATA_FOLDER/unregistered_reviewers.csv \
		--files $DATA_FOLDER/affinity_scores.csv \
			$DATA_FOLDER/filtered_bids.csv \
			$DATA_FOLDER/constraints/conflict_constraints.csv 

else
	if [ "$EXPERIMENT" = "True" ]; then
		export SUBMISSION_FILE="submission_flipped.csv"
	fi
	export REVIEWER_FILE="reviewer_filtered.csv"
fi

if [ "$DEBUG" = "True" ]; then
	printf "\n----------------------------------------"

	# UNCOMMENT
	python ICML2026/scripts/subsample_scale.py \
	--N 1000 \
	--scores $DATA_FOLDER/affinity_scores.csv \
	--reviewer $DATA_FOLDER/$REVIEWER_FILE \
	--submission $DATA_FOLDER/$SUBMISSION_FILE \
	--files $DATA_FOLDER/filtered_bids.csv \
		$DATA_FOLDER/constraints/conflict_constraints.csv \
		$DATA_FOLDER/constraints/hard_policy_constraints.csv \
		$DATA_FOLDER/constraints/soft_policy_constraints.csv

	export REVIEWER_FILE="reviewer_filtered_subsampled.csv"
	if [ "$EXPERIMENT" = "True" ]; then
		export SUBMISSION_FILE="submission_flipped_subsampled.csv"
	else
		export SUBMISSION_FILE="submission_subsampled.csv"
	fi
fi


# If in DEBUG mode, subsample the scores, bids, and constraints. Will overwrite the
# original files.
# if [ "$DEBUG" = "True" ]; then
# 	export SCORES_FILE="affinity_scores_subsampled.csv"
# 	export BIDS_FILE="filtered_bids_subsampled.csv"
# 	export CONFLICT_CONSTRAINTS_FILE="conflict_constraints_subsampled.csv"
# 	export HARD_POLICY_CONSTRAINTS_FILE="hard_policy_constraints_subsampled.csv"
# 	export SOFT_POLICY_CONSTRAINTS_FILE="soft_policy_constraints_subsampled.csv"
# else
# 	export SCORES_FILE="affinity_scores.csv"
# 	export BIDS_FILE="filtered_bids.csv"
# 	export CONFLICT_CONSTRAINTS_FILE="conflict_constraints.csv"
# 	export HARD_POLICY_CONSTRAINTS_FILE="hard_policy_constraints.csv"
# 	export SOFT_POLICY_CONSTRAINTS_FILE="soft_policy_constraints.csv"
# fi









# Save original DATA_FOLDER
ORIGINAL_DATA_FOLDER=$DATA_FOLDER

# Loop through three iterations
for ITER_NUM in 1 2 3; do
	# Set iteration-specific variables
	case $ITER_NUM in
		1)
			ITER_NAME="UNCONSTRAINED MATCHING"
			ITER_DATA_FOLDER_VAR="ITER1_DATA_FOLDER"
			ITER_ASSIGNMENTS_FOLDER_VAR="ITER1_ASSIGNMENTS_FOLDER"
			FIRST_MATCHING_CONSTRAINTS="conflict_constraints.csv"
			TRACKING_POLICY_FILE="updated_reviewer_policy.csv"
			COPY_DATA_FILES=true
			SUBSAMPLE_AFTER_SECOND=false
			;;
		2)
			ITER_NAME="HARD Policy Constraints"
			ITER_DATA_FOLDER_VAR="ITER2_DATA_FOLDER"
			ITER_ASSIGNMENTS_FOLDER_VAR="ITER2_ASSIGNMENTS_FOLDER"
			FIRST_MATCHING_CONSTRAINTS="agg_constraints.csv"
			TRACKING_POLICY_FILE="updated_reviewer_policy_experimental.csv"
			COPY_DATA_FILES=false
			SUBSAMPLE_AFTER_SECOND=true
			;;
		3)
			ITER_NAME="SOFT Policy Constraints"
			ITER_DATA_FOLDER_VAR="ITER3_DATA_FOLDER"
			ITER_ASSIGNMENTS_FOLDER_VAR="ITER3_ASSIGNMENTS_FOLDER"
			FIRST_MATCHING_CONSTRAINTS="agg_constraints.csv"
			TRACKING_POLICY_FILE="updated_reviewer_policy.csv"
			COPY_DATA_FILES=false
			SUBSAMPLE_AFTER_SECOND=true
			;;
	esac
	
	# Get the actual folder paths
	eval "ITER_DATA_FOLDER=\$$ITER_DATA_FOLDER_VAR"
	eval "ITER_ASSIGNMENTS_FOLDER=\$$ITER_ASSIGNMENTS_FOLDER_VAR"
	
	printf "\n\n\n========================================"
	printf "\nITERATION $ITER_NUM: $ITER_NAME..."
	printf "\n========================================\n"

	# Adjust MAX_PAPERS if quality constraints are enabled
	if [ "$QUALITY_CONSTRAINTS" = "True" ]; then
		export MAX_PAPERS=$(($MAX_PAPERS - 1))
	fi
	
	# Copy data files if needed (only for iteration 1)
	if [ "$COPY_DATA_FILES" = "true" ]; then
		printf "\nCopying data to iter${ITER_NUM} data folder..."
		mkdir -p $ITER_DATA_FOLDER
		mkdir -p $ITER_DATA_FOLDER/constraints/
		
		if [ "$DEBUG" = "True" ]; then
			cp $ORIGINAL_DATA_FOLDER/constraints/conflict_constraints_subsampled.csv $ITER_DATA_FOLDER/constraints/conflict_constraints.csv
			cp $ORIGINAL_DATA_FOLDER/affinity_scores_subsampled.csv $ITER_DATA_FOLDER/affinity_scores.csv
			cp $ORIGINAL_DATA_FOLDER/unregistered_reviewers.csv $ITER_DATA_FOLDER/unregistered_reviewers.csv
			cp $ORIGINAL_DATA_FOLDER/filtered_bids_subsampled.csv $ITER_DATA_FOLDER/filtered_bids.csv
			cp $ORIGINAL_DATA_FOLDER/$REVIEWER_FILE $ITER_DATA_FOLDER/reviewer.csv
			cp $ORIGINAL_DATA_FOLDER/$SUBMISSION_FILE $ITER_DATA_FOLDER/submission.csv
			cp $ORIGINAL_DATA_FOLDER/quota.csv $ITER_DATA_FOLDER/quota.csv
			cp $ORIGINAL_DATA_FOLDER/qualification.csv $ITER_DATA_FOLDER/qualification.csv
			cp $ORIGINAL_DATA_FOLDER/emergency-4plus-reviewers.csv $ITER_DATA_FOLDER/emergency-4plus-reviewers.csv
			cp $ORIGINAL_DATA_FOLDER/reciprocal-reviewer-noBid.csv $ITER_DATA_FOLDER/reciprocal-reviewer-noBid.csv
			export REVIEWER_FILE="reviewer.csv"
			export SUBMISSION_FILE="submission.csv"
		else
			cp $ORIGINAL_DATA_FOLDER/constraints/conflict_constraints.csv $ITER_DATA_FOLDER/constraints/conflict_constraints.csv
			cp $ORIGINAL_DATA_FOLDER/affinity_scores.csv $ITER_DATA_FOLDER/affinity_scores.csv
			cp $ORIGINAL_DATA_FOLDER/unregistered_reviewers.csv $ITER_DATA_FOLDER/unregistered_reviewers.csv
			cp $ORIGINAL_DATA_FOLDER/filtered_bids.csv $ITER_DATA_FOLDER/filtered_bids.csv
			cp $ORIGINAL_DATA_FOLDER/$REVIEWER_FILE $ITER_DATA_FOLDER/reviewer.csv
			cp $ORIGINAL_DATA_FOLDER/$SUBMISSION_FILE $ITER_DATA_FOLDER/submission.csv
			cp $ORIGINAL_DATA_FOLDER/quota.csv $ITER_DATA_FOLDER/quota.csv
			cp $ORIGINAL_DATA_FOLDER/qualification.csv $ITER_DATA_FOLDER/qualification.csv
			cp $ORIGINAL_DATA_FOLDER/emergency-4plus-reviewers.csv $ITER_DATA_FOLDER/emergency-4plus-reviewers.csv
			cp $ORIGINAL_DATA_FOLDER/reciprocal-reviewer-noBid.csv $ITER_DATA_FOLDER/reciprocal-reviewer-noBid.csv
			export REVIEWER_FILE="reviewer.csv"
			export SUBMISSION_FILE="submission.csv"
		fi
		export DATA_FOLDER=$ITER_DATA_FOLDER
	else
		# For iterations 2 and 3, use original DATA_FOLDER
		export DATA_FOLDER=$ORIGINAL_DATA_FOLDER
	fi


if [ "$QUALITY_CONSTRAINTS" = "True" ]; then
	export MAX_PAPERS=$(($MAX_PAPERS - 1))
fi


	# ---------------------------------------------------------------------------------
	# Initial Matching of 3 reviewers per paper
	# ---------------------------------------------------------------------------------
	
	# Prepare first matching constraints based on iteration
	if [ "$ITER_NUM" = "1" ]; then
		FIRST_CONSTRAINTS_FILE="$DATA_FOLDER/constraints/conflict_constraints.csv"
	elif [ "$ITER_NUM" = "2" ]; then
		# Join constraints for iteration 2 (hard policy)
		printf "\n----------------------------------------"
		python ICML2026/scripts/join_constraints.py \
			--files $DATA_FOLDER/constraints/conflict_constraints.csv \
				$DATA_FOLDER/constraints/hard_policy_constraints.csv \
			--output $DATA_FOLDER/constraints/agg_constraints.csv
		FIRST_CONSTRAINTS_FILE="$DATA_FOLDER/constraints/agg_constraints.csv"
	elif [ "$ITER_NUM" = "3" ]; then
		# Join constraints for iteration 3 (soft policy)
		printf "\n----------------------------------------"
		python ICML2026/scripts/join_constraints.py \
			--files $DATA_FOLDER/constraints/conflict_constraints.csv \
				$DATA_FOLDER/constraints/soft_policy_constraints.csv \
			--output $DATA_FOLDER/constraints/agg_constraints.csv
		FIRST_CONSTRAINTS_FILE="$DATA_FOLDER/constraints/agg_constraints.csv"
	fi
	
	# Matching
	printf "\n----------------------------------------"
	printf "\nStarting first matching..."
	printf "\n----------------------------------------\n"
	
	start_time=$SECONDS
	python -m matcher \
		--scores $DATA_FOLDER/affinity_scores.csv $DATA_FOLDER/filtered_bids.csv \
		--weights 1 1 \
		--constraints $FIRST_CONSTRAINTS_FILE \
		--min_papers_default 0 \
		--max_papers_default $MAX_PAPERS \
		--quota $DATA_FOLDER/quota.csv \
		--num_reviewers $(($NUM_REVIEWS - 1)) \
		--solver Randomized \
		--allow_zero_score_assignments \
		--probability_limits $Q \
		--output_folder $ITER_ASSIGNMENTS_FOLDER
	
	mv $ITER_ASSIGNMENTS_FOLDER/assignments.json $ITER_ASSIGNMENTS_FOLDER/first_matching.json
	mv $ITER_ASSIGNMENTS_FOLDER/alternates.json $ITER_ASSIGNMENTS_FOLDER/first_matching_alternates.json
	print_time $((SECONDS - start_time))

	# Convert assignments JSON to CSV for convenience
	python ICML2026/scripts/json_to_csv.py \
		--input $ITER_ASSIGNMENTS_FOLDER/first_matching.json \
		--output $ITER_ASSIGNMENTS_FOLDER/first_matching.csv
	
	# Convert alternates JSON to CSV for convenience
	python ICML2026/scripts/json_to_csv.py \
		--input $ITER_ASSIGNMENTS_FOLDER/first_matching_alternates.json \
		--output $ITER_ASSIGNMENTS_FOLDER/first_matching_alternates.csv
	
	if [ "$QUALITY_CONSTRAINTS" = "True" ]; then
		export MAX_PAPERS=$(($MAX_PAPERS + 1)) # previously left out a capacity for each reviewer if quality constraints are used
	fi
	
	# ---------------------------------------------------------------------------------
	# Second matching. Assign a 4th reviewer to each paper
	# ---------------------------------------------------------------------------------
	
	# Extract the number of papers each reviewer can review in the second matching as
	# MAX_PAPERS - number of papers assigned in the first matching
	printf "\n----------------------------------------"
	python ICML2026/scripts/reviewer_supply_after_matching.py \
		--assignments $ITER_ASSIGNMENTS_FOLDER/first_matching.json \
		--max_papers $MAX_PAPERS \
		--quota $DATA_FOLDER/quota.csv \
		--supply_output $DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
		--exhausted_reviewers_output $DATA_FOLDER/exhausted_reviewers.csv \
		--remaining_reviewer_constraints_output $DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
	print_time $((SECONDS - start_time))

# ICML26: No geographical constraints for ICML 2026
# Extract geographical diversity constraints
# printf "\n----------------------------------------"
# python ICML2026/scripts/geographical_diversity.py \
# 	--assignments $ITER1_ASSIGNMENTS_FOLDER/first_matching.csv \
# 	--output $DATA_FOLDER/constraints/geographical_constraints.csv
# print_time $((SECONDS - start_time))

	# ICML26: Use country constraints and quality constraints
	printf "\n----------------------------------------"
	python ICML2026/scripts/country_constraints.py \
		--assignments $ITER_ASSIGNMENTS_FOLDER/first_matching.json \
		--reviewer $DATA_FOLDER/$REVIEWER_FILE \
		--output $DATA_FOLDER/constraints/country_constraints.csv
	
	python ICML2026/scripts/quality_constraints.py \
		--assignments $ITER_ASSIGNMENTS_FOLDER/first_matching.json \
		--qualification $DATA_FOLDER/qualification.csv \
		--output $DATA_FOLDER/constraints/quality_constraints.csv
	
	# Remove emergency reviewers and reviewers without more reviews left before the
	# second matching.
	printf "\n----------------------------------------"
	# Build exclude files list
	EXCLUDE_FILES="$DATA_FOLDER/emergency-4plus-reviewers.csv $DATA_FOLDER/reciprocal-reviewer-noBid.csv $DATA_FOLDER/exhausted_reviewers.csv $DATA_FOLDER/unregistered_reviewers.csv"
	
	# Build files to process list - use agg_constraints for iter 2/3, conflict_constraints for iter 1
	if [ "$ITER_NUM" = "1" ]; then
		CONSTRAINT_FILE="$DATA_FOLDER/constraints/conflict_constraints.csv"
	else
		CONSTRAINT_FILE="$DATA_FOLDER/constraints/agg_constraints.csv"
	fi
	
	python ICML2026/scripts/exclude_reviewers.py \
		--exclude_reviewer_files $EXCLUDE_FILES \
		--files $DATA_FOLDER/affinity_scores.csv \
			$DATA_FOLDER/filtered_bids.csv \
			$CONSTRAINT_FILE \
			$DATA_FOLDER/constraints/hard_policy_constraints.csv \
			$DATA_FOLDER/constraints/soft_policy_constraints.csv \
			$DATA_FOLDER/constraints/country_constraints.csv \
			$DATA_FOLDER/constraints/quality_constraints.csv \
			$DATA_FOLDER/constraints/reviewer_supply_after_matching.csv
	
	# If in DEBUG mode and SUBSAMPLE_AFTER_SECOND is true, subsample the new constraints
	if [ "$DEBUG" = "True" ] && [ "$SUBSAMPLE_AFTER_SECOND" = "true" ]; then
		printf "\n----------------------------------------"
		if [ "$ITER_NUM" = "2" ]; then
			python ICML2026/scripts/subsample.py \
				--N 1000 \
				--scores $DATA_FOLDER/affinity_scores.csv \
				--files $DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
					$DATA_FOLDER/constraints/country_constraints.csv \
					$DATA_FOLDER/constraints/quality_constraints.csv \
					$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv
			printf "\n subsample"
		elif [ "$ITER_NUM" = "3" ]; then
			python ICML2026/scripts/subsample.py \
				--scores $DATA_FOLDER/affinity_scores.csv \
				--files $DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
					$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
					$DATA_FOLDER/constraints/country_constraints.csv \
					$DATA_FOLDER/constraints/quality_constraints.csv
		fi
	fi

	# Join constraints into a single file
	# Use agg_constraints for iter 2/3, conflict_constraints for iter 1
	if [ "$ITER_NUM" = "1" ]; then
		BASE_CONSTRAINT="$DATA_FOLDER/constraints/conflict_constraints.csv"
	else
		BASE_CONSTRAINT="$DATA_FOLDER/constraints/agg_constraints.csv"
	fi
	
	printf "\n----------------------------------------"
	printf "\nJoining constraints into a single file..."
	
	if [ "$COUNTRY_CONSTRAINTS" = "True" ] && [ "$QUALITY_CONSTRAINTS" = "True" ]; then
		python ICML2026/scripts/join_constraints.py \
			--files $BASE_CONSTRAINT \
				$DATA_FOLDER/constraints/country_constraints.csv \
				$DATA_FOLDER/constraints/quality_constraints.csv \
				$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
			--output $DATA_FOLDER/constraints/constraints_for_second_matching.csv
		print_time $((SECONDS - start_time))
	elif [ "$COUNTRY_CONSTRAINTS" = "True" ] && [ "$QUALITY_CONSTRAINTS" = "False" ]; then
		python ICML2026/scripts/join_constraints.py \
			--files $BASE_CONSTRAINT \
				$DATA_FOLDER/constraints/country_constraints.csv \
				$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
			--output $DATA_FOLDER/constraints/constraints_for_second_matching.csv
		print_time $((SECONDS - start_time))
	elif [ "$COUNTRY_CONSTRAINTS" = "False" ] && [ "$QUALITY_CONSTRAINTS" = "True" ]; then
		python ICML2026/scripts/join_constraints.py \
			--files $BASE_CONSTRAINT \
				$DATA_FOLDER/constraints/quality_constraints.csv \
				$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
			--output $DATA_FOLDER/constraints/constraints_for_second_matching.csv
		print_time $((SECONDS - start_time))
	else
		python ICML2026/scripts/join_constraints.py \
			--files $BASE_CONSTRAINT \
				$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
			--output $DATA_FOLDER/constraints/constraints_for_second_matching.csv
		print_time $((SECONDS - start_time))
	fi
	
	# Matching
	printf "\n----------------------------------------"
	printf "\nStarting second matching..."
	printf "\n----------------------------------------\n"
	
	start_time=$SECONDS
	python -m matcher \
		--scores $DATA_FOLDER/affinity_scores.csv $DATA_FOLDER/filtered_bids.csv \
		--weights 1 1 \
		--constraints $DATA_FOLDER/constraints/constraints_for_second_matching.csv \
		--min_papers_default 0 \
		--max_papers_default $MAX_PAPERS \
		--max_papers $DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
		--num_reviewers 1 \
		--num_alternates 1 \
		--solver Randomized \
		--allow_zero_score_assignments \
		--probability_limits $Q \
		--output_folder $ITER_ASSIGNMENTS_FOLDER
	
	mv $ITER_ASSIGNMENTS_FOLDER/assignments.json $ITER_ASSIGNMENTS_FOLDER/second_matching.json
	mv $ITER_ASSIGNMENTS_FOLDER/alternates.json $ITER_ASSIGNMENTS_FOLDER/second_matching_alternates.json
	print_time $((SECONDS - start_time))
	
	# Convert assignments JSON to CSV for convenience
	python ICML2026/scripts/json_to_csv.py \
		--input $ITER_ASSIGNMENTS_FOLDER/second_matching.json \
		--output $ITER_ASSIGNMENTS_FOLDER/second_matching.csv
	
	# Convert alternates JSON to CSV for convenience
	python ICML2026/scripts/json_to_csv.py \
		--input $ITER_ASSIGNMENTS_FOLDER/second_matching_alternates.json \
		--output $ITER_ASSIGNMENTS_FOLDER/second_matching_alternates.csv

	# ---------------------------------------------------------------------------------
	printf "\n----------------------------------------"
	
	# Join first and second matching assignments
	python ICML2026/scripts/join_assignments.py \
		--files $ITER_ASSIGNMENTS_FOLDER/first_matching.csv \
			$ITER_ASSIGNMENTS_FOLDER/second_matching.csv \
		--output $ITER_ASSIGNMENTS_FOLDER/final_assignments.csv
	
	# get updated policy for reviewers
	python ICML2026/scripts/get_updated_reviewer_policy.py \
		--assignments $ITER_ASSIGNMENTS_FOLDER/final_assignments.csv \
		--reviewer $DATA_FOLDER/$REVIEWER_FILE \
		--submission $DATA_FOLDER/$SUBMISSION_FILE \
		--output $ITER_ASSIGNMENTS_FOLDER/updated_reviewer_policy.csv
	
	# track target experiment cases
	# Check if tracking policy file exists, if not use updated_reviewer_policy.csv
	TRACKING_FILE="$ITER_ASSIGNMENTS_FOLDER/$TRACKING_POLICY_FILE"
	if [ ! -f "$TRACKING_FILE" ]; then
		TRACKING_FILE="$ITER_ASSIGNMENTS_FOLDER/updated_reviewer_policy.csv"
	fi
	python ICML2026/scripts/track_target_experiment_cases.py \
		--reviewer_policy $TRACKING_FILE \
		--assignments $ITER_ASSIGNMENTS_FOLDER/final_assignments.json \
		--output $ITER_ASSIGNMENTS_FOLDER/tracked_final_assignments.json
	
	# python ICML2026/scripts/evaluate_assignments.py \
	# 	--assignments $ITER_ASSIGNMENTS_FOLDER/final_assignments.csv \
	# 	--output $ITER_ASSIGNMENTS_FOLDER/evaluation.txt
	
	python ICML2026/scripts/stat_check.py \
		--output_folder $ITER_ASSIGNMENTS_FOLDER \
		--assignments $ITER_ASSIGNMENTS_FOLDER/final_assignments.csv $ITER_ASSIGNMENTS_FOLDER/final_assignments.json \
		--reviewers $DATA_FOLDER/reviewer.csv \
		--bids $DATA_FOLDER/bids.csv
	
	printf "\nDone."
	printf "\nSCORES_FILE: $SCORES_FILE"
	printf "\nAssignments saved in $ITER_ASSIGNMENTS_FOLDER"
	
	print_time $((SECONDS - start_time))
	
	# Reset MAX_PAPERS for next iteration if quality constraints were adjusted
	if [ "$QUALITY_CONSTRAINTS" = "True" ]; then
		export MAX_PAPERS=5  # Reset to original value
	fi
	
done  # End of iteration loop
