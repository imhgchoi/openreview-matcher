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
export DEBUG_N=4000

export PRUNE_EDGES=False
export PRUNE_K=50
export PRUNE_R=10


export PREPROCESS_DATA=False # Preprocess data
export EXPERIMENT=True # Experimental Manipulation
export FLIP_RATE=0.1 # Ratio of "Okay with Policy B" Papers to be flipped to Policy A.
export FILTER_UNREGISTERED=True # Filter out unregistered reviewers (Set to False for testing)
export COUNTRY_CONSTRAINTS=True # Use country constraints
export QUALITY_CONSTRAINTS=False # Use quality constraints
export COMPUTE_FINAL_POLICY=False

export Q=.7


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

export GROUP="Reviewers_Main"
export TYPE=2 # 1: unconstrained / 2: hard policy constraint / 3: soft policy constraint

export MAX_PAPERS=6 # Maximum number of papers each reviewer can review
export NUM_REVIEWS=4 # Number of reviewers per paper
export MIN_POS_BIDS=10 # minimum number of positive bids in order to take them into account
export MATCHER_SOLVER="MinMax"

if [ -z "$SLURM_JOB_NAME" ] && [ -z "$SLURM_JOB_ID" ]; then
    # Local execution (not running under SLURM or in an interactive session)
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export CONSTRAINTS_FOLDER="ICML2026/$GROUP/data/constraints"
    export ASSIGNMENTS_FOLDER="ICML2026/$GROUP/assignments"
elif [ -z "$SLURM_JOB_NAME" ]; then
    # Interactive session
    export ROOT_FOLDER="ICML2026/$GROUP"
    export DATA_FOLDER="ICML2026/$GROUP/data"
	export CONSTRAINTS_FOLDER="ICML2026/$GROUP/data/constraints"
    export ASSIGNMENTS_FOLDER="ICML2026/$GROUP/assignments"
else
    # sbatch job
    export ROOT_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID"
    export DATA_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/data"
	export CONSTRAINTS_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/data/constraints"
    export ASSIGNMENTS_FOLDER="ICML2026/$GROUP/jobs/$SLURM_JOB_ID/assignments"
fi
SCORES_FILE="affinity_scores.csv"
BIDS_FILE="bids.csv"
SUBMISSION_FILE="submission.csv"
REVIEWER_FILE="reviewer.csv"
NORMAL_CONFLICTS_FILE="conflict_constraints.csv"
QUALIFICATION_FILE="qualifications.csv"
UNQUALIFIED_REVIEWERS_FILE="unqualified_reviewers.csv"
ROUND1_REVIEWERS_FILE="round1_reviewers.csv"
ROUND2_REVIEWERS_FILE="round2_reviewers.csv"
EMERGENCY_REVIEWERS_FILE="emergency_reviewers.csv"
EXCLUDE_SUBMISSIONS_FILE="submissions_to_exclude.csv"

HARD_POLICY_CONSTRAINTS_FILE="hard_policy_constraints.csv"
SOFT_POLICY_CONSTRAINTS_FILE="soft_policy_constraints.csv"
AGG_CONSTRAINTS_FILE="agg_constraints.csv"

# Output files 
# experimented_submissions.csv: Policy B papers, including the ones flipped to Policy A.

mkdir -p $ROOT_FOLDER # create the scores folder
mkdir -p $DATA_FOLDER # create the data folder
mkdir -p $CONSTRAINTS_FOLDER # create the constraints folder
mkdir -p $ASSIGNMENTS_FOLDER # create the output folder


# printf "All required files exist."

printf "\n========================================"
printf "\nStarting Matching Script..."
printf "\n========================================\n"


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
printf "\nASSIGNMENTS_FOLDER: $ASSIGNMENTS_FOLDER"



# ----------------------------------------------------------------------------------
# Pre-process data
# ----------------------------------------------------------------------------------

script_start_time=$(date +"%T")
printf "\n\n\nScript start time: $script_start_time"

if [ "$PREPROCESS_DATA" = "True" ]; then
	printf "\n----------------------------------------"
	printf "\nPre-processing data..."
	printf "\n----------------------------------------\n"


	printf "Excluding desk-rejected submissions from full submission file..."
	python ICML2026/scripts/exclude_submissions.py \
		--final_submissions $DATA_FOLDER/submissions_after_deskreject.csv \
		--submission $DATA_FOLDER/$SUBMISSION_FILE


	# ICML26: Experimental Manipulation - Flip some papers from Policy B to Policy A
	if [ "$EXPERIMENT" = "True" ]; then
		printf "\n\nEXPERIMENTAL MANIPULATION: Flipping papers from Policy B to Policy A..."

		python ICML2026/scripts/flip_paper_policy.py \
			--match_group $GROUP \
			--submission $DATA_FOLDER/$SUBMISSION_FILE \
			--output $DATA_FOLDER/submission_flipped.csv \
			--flip_rate $FLIP_RATE
		export SUBMISSION_FILE="submission_flipped.csv"
	fi

	# ICML26: Get rid of reviewers that have not registered
	printf "\n\nFiltering out unregistered reviewers..."
	python ICML2026/scripts/filter_reviewers.py \
		--reviewer $DATA_FOLDER/$REVIEWER_FILE \
		--output $DATA_FOLDER/reviewer_filtered.csv $DATA_FOLDER/unregistered_reviewers.csv \
		--filter_unregistered $FILTER_UNREGISTERED
	export REVIEWER_FILE="reviewer_filtered.csv"

	printf "\n\nProcessing qualifications..."
	python ICML2026/scripts/process_qualifications.py \
		--qualification $DATA_FOLDER/$QUALIFICATION_FILE \
		--outputs $DATA_FOLDER/$EMERGENCY_REVIEWERS_FILE \
			$DATA_FOLDER/$UNQUALIFIED_REVIEWERS_FILE \
			$DATA_FOLDER/$ROUND1_REVIEWERS_FILE \
			$DATA_FOLDER/$ROUND2_REVIEWERS_FILE 

	# TODO: Filter out suspicious bids
	# Filter out bids from reviewers that do not have at least MIN_POS_BIDS positive bids
	printf "\n\nFiltering out suspicious bids..."
	python ICML2026/scripts/filter_bids.py \
		--input $DATA_FOLDER/$BIDS_FILE \
		--output $DATA_FOLDER/bids_filtered.csv \
		--min-pos-bids $MIN_POS_BIDS
	export BIDS_FILE="bids_filtered.csv"

	# Commented out to fix policy constraints
	# ICML26: fetch policy constraints
	# printf "\n\nFetching policy constraints..."
	# python ICML2026/scripts/fetch_policy_constraints.py \
	# 	--match_group $GROUP \
	# 	--submission $DATA_FOLDER/$SUBMISSION_FILE \
	# 	--reviewer $DATA_FOLDER/$REVIEWER_FILE \
	# 	--outputs $DATA_FOLDER/constraints/$HARD_POLICY_CONSTRAINTS_FILE \
	# 			$DATA_FOLDER/constraints/$SOFT_POLICY_CONSTRAINTS_FILE

	# Remove emergency reviewers from scores, bids, and constraints. 
	printf "\n\nExcluding unregistered, unqualified, and emergency reviewers from scores, bids, and constraints..."
	python ICML2026/scripts/exclude_reviewers.py \
		--exclude_reviewer_files $DATA_FOLDER/$EMERGENCY_REVIEWERS_FILE \
						$DATA_FOLDER/$UNQUALIFIED_REVIEWERS_FILE \
						$DATA_FOLDER/unregistered_reviewers.csv \
		--files $DATA_FOLDER/$SCORES_FILE \
			$DATA_FOLDER/$BIDS_FILE \
			$DATA_FOLDER/constraints/$NORMAL_CONFLICTS_FILE

	printf "\n\nExcluding desk-rejected submissions from scores, bids, and constraints..."
	python ICML2026/scripts/exclude_submissions.py \
		--final_submissions $DATA_FOLDER/submissions_after_deskreject.csv \
		--files $DATA_FOLDER/$SCORES_FILE \
			$DATA_FOLDER/$BIDS_FILE \
			$DATA_FOLDER/constraints/$NORMAL_CONFLICTS_FILE

else
	if [ "$EXPERIMENT" = "True" ]; then
		export SUBMISSION_FILE="submission_flipped.csv"
	fi
	export REVIEWER_FILE="reviewer_filtered.csv"
	export BIDS_FILE="bids_filtered.csv"
fi


after_preprocess_time=$(date +"%T")
printf "\n\n\nAfter pre-processing time: $after_preprocess_time"
printf "\n========================================\n"

if [ "$DEBUG" = "True" ]; then

	python ICML2026/scripts/subsample_scale.py \
		--N $DEBUG_N \
		--scores $DATA_FOLDER/$SCORES_FILE \
		--reviewer $DATA_FOLDER/$REVIEWER_FILE \
		--submission $DATA_FOLDER/$SUBMISSION_FILE \
		--qualification $DATA_FOLDER/$QUALIFICATION_FILE \
		--files $DATA_FOLDER/$BIDS_FILE \
			$DATA_FOLDER/constraints/$NORMAL_CONFLICTS_FILE \
			$DATA_FOLDER/constraints/$HARD_POLICY_CONSTRAINTS_FILE
			# $DATA_FOLDER/constraints/$SOFT_POLICY_CONSTRAINTS_FILE

	if [ "$EXPERIMENT" = "True" ]; then
		export SUBMISSION_FILE="submission_flipped_subsampled.csv"
	else
		export SUBMISSION_FILE="submission_subsampled.csv"
	fi
	export SCORES_FILE="affinity_scores_subsampled.csv"
	export REVIEWER_FILE="reviewer_filtered_subsampled.csv"
	export BIDS_FILE="bids_filtered_subsampled.csv"
	export QUALIFICATION_FILE="qualifications_subsampled.csv"
	export NORMAL_CONFLICTS_FILE="conflict_constraints_subsampled.csv"
	export HARD_POLICY_CONSTRAINTS_FILE="hard_policy_constraints_subsampled.csv"
	export SOFT_POLICY_CONSTRAINTS_FILE="soft_policy_constraints_subsampled.csv"
	
fi



printf "\n\n\n========================================"
printf "\nMATCHING BEGINS..."
printf "\n========================================\n"


# Matching
printf "\n----------------------------------------"
printf "\nStarting first matching..."
printf "\n----------------------------------------\n"

phase_one_start_time=$(date +"%T")
printf "\n\nPhase one matching start time: $phase_one_start_time"

printf "\n\nJoining constraints into a single file..."
if [ "$DEBUG" = "True" ]; then
	# Join constraints into a single file
	python ICML2026/scripts/join_constraints.py \
		--files $DATA_FOLDER/constraints/$NORMAL_CONFLICTS_FILE \
			$DATA_FOLDER/constraints/$HARD_POLICY_CONSTRAINTS_FILE \
		--output $DATA_FOLDER/constraints/agg_constraints_subsampled.csv
	export AGG_CONSTRAINTS_FILE="agg_constraints_subsampled.csv"
else
	if [ $PREPROCESS_DATA = "True" ]; then
		# Join constraints into a single file
		python ICML2026/scripts/join_constraints.py \
			--files $DATA_FOLDER/constraints/$NORMAL_CONFLICTS_FILE \
				$DATA_FOLDER/constraints/$HARD_POLICY_CONSTRAINTS_FILE \
			--output $DATA_FOLDER/constraints/$AGG_CONSTRAINTS_FILE
	fi
fi

if [ "$PRUNE_EDGES" = "True" ]; then
	# This will overwrite the original scores file
	printf "\n----------------------------------------"
	printf "\nPruning edges from the graph..."
	printf "\n----------------------------------------\n"

	python ICML2026/scripts/prune_edges.py \
		--affinity $DATA_FOLDER/$SCORES_FILE \
		--bids $DATA_FOLDER/$BIDS_FILE \
		--conflict $DATA_FOLDER/constraints/$AGG_CONSTRAINTS_FILE \
		--K $PRUNE_K \
		--slack $PRUNE_R \
		--output $DATA_FOLDER/affinity_scores_pruned.csv 
	export SCORES_FILE="affinity_scores_pruned.csv"
fi


printf "\n\nGetting matching round data..."
python ICML2026/scripts/get_matching_round_data.py \
	--scores $DATA_FOLDER/$SCORES_FILE \
	--bids $DATA_FOLDER/$BIDS_FILE \
	--constraints $DATA_FOLDER/constraints/$AGG_CONSTRAINTS_FILE \
	--round1_reviewers $DATA_FOLDER/$ROUND1_REVIEWERS_FILE \
	--round2_reviewers $DATA_FOLDER/$ROUND2_REVIEWERS_FILE \
	--outputs $DATA_FOLDER/round1_affinity_scores.csv  \
			$DATA_FOLDER/round1_bids.csv \
			$DATA_FOLDER/constraints/round1_constraints.csv \
			$DATA_FOLDER/round2_affinity_scores.csv \
			$DATA_FOLDER/round2_bids.csv \
			$DATA_FOLDER/constraints/round2_constraints.csv


python -m matcher \
	--scores $DATA_FOLDER/round1_affinity_scores.csv $DATA_FOLDER/round1_bids.csv \
	--weights 1 1 \
	--constraints $DATA_FOLDER/constraints/round1_constraints.csv \
	--min_papers_default 0 \
	--max_papers_default $(($MAX_PAPERS - 1)) \
	--quota $DATA_FOLDER/quota.csv \
	--num_reviewers 2 \
	--solver $MATCHER_SOLVER \
	--probability_limits $Q \
	--output_folder $ASSIGNMENTS_FOLDER
	# --allow_zero_score_assignments \

mv $ASSIGNMENTS_FOLDER/assignments.json $ASSIGNMENTS_FOLDER/first_matching.json
mv $ASSIGNMENTS_FOLDER/alternates.json $ASSIGNMENTS_FOLDER/first_matching_alternates.json

# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ASSIGNMENTS_FOLDER/first_matching.json \
	--output $ASSIGNMENTS_FOLDER/first_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ASSIGNMENTS_FOLDER/first_matching_alternates.json \
	--output $ASSIGNMENTS_FOLDER/first_matching_alternates.csv

phase_one_end_time=$(date +"%T")
printf "\n\nPhase one matching end time: $phase_one_end_time"

# Extract the number of papers each reviewer can review in the second matching as
# MAX_PAPERS - number of papers assigned in the first matching
python ICML2026/scripts/reviewer_supply_after_matching.py \
	--assignments $ASSIGNMENTS_FOLDER/first_matching.json \
	--reviewers $DATA_FOLDER/round2_reviewers.csv \
	--max_papers $MAX_PAPERS \
	--quota $DATA_FOLDER/quota.csv \
	--supply_output $DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--exhausted_reviewers_output $DATA_FOLDER/exhausted_reviewers.csv \
	--remaining_reviewer_constraints_output $DATA_FOLDER/constraints/remaining_reviewer_constraints.csv


printf "\n\n\nGetting ready for second matching..."
if [ "$COUNTRY_CONSTRAINTS" = "True" ]; then

	# ICML26: Use country constraints and quality constraints
	printf "\n----------------------------------------"
	python ICML2026/scripts/country_constraints.py \
		--assignments $ASSIGNMENTS_FOLDER/first_matching.json \
		--reviewer $DATA_FOLDER/$REVIEWER_FILE \
		--output $DATA_FOLDER/constraints/country_constraints.csv


	# Remove emergency reviewers and reviewers without more reviews left before the
	# second matching.
	printf "\n----------------------------------------"
	python ICML2026/scripts/exclude_reviewers.py \
		--exclude_reviewer_files $DATA_FOLDER/$EMERGENCY_REVIEWERS_FILE \
					$DATA_FOLDER/$UNQUALIFIED_REVIEWERS_FILE \
					$DATA_FOLDER/exhausted_reviewers.csv \
					$DATA_FOLDER/unregistered_reviewers.csv \
		--files $DATA_FOLDER/round2_affinity_scores.csv \
			$DATA_FOLDER/round2_bids.csv \
			$DATA_FOLDER/constraints/round2_constraints.csv \
			$DATA_FOLDER/constraints/country_constraints.csv \
			$DATA_FOLDER/constraints/reviewer_supply_after_matching.csv

	# Join constraints into a single file
	printf "\n----------------------------------------"
	python ICML2026/scripts/join_constraints.py \
		--files $DATA_FOLDER/constraints/round2_constraints.csv \
			$DATA_FOLDER/constraints/country_constraints.csv \
			$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
		--output $DATA_FOLDER/constraints/constraints_for_second_matching.csv
else

	# Remove emergency reviewers and reviewers without more reviews left before the
	# second matching.
	printf "\n----------------------------------------"
	python ICML2026/scripts/exclude_reviewers.py \
		--exclude_reviewer_files $DATA_FOLDER/$EMERGENCY_REVIEWERS_FILE \
					$DATA_FOLDER/$UNQUALIFIED_REVIEWERS_FILE \
					$DATA_FOLDER/exhausted_reviewers.csv \
					$DATA_FOLDER/unregistered_reviewers.csv \
		--files $DATA_FOLDER/round2_affinity_scores.csv \
			$DATA_FOLDER/round2_bids.csv \
			$DATA_FOLDER/constraints/round2_constraints.csv \
			$DATA_FOLDER/constraints/reviewer_supply_after_matching.csv


	# Join constraints into a single file
	printf "\n----------------------------------------"
	python ICML2026/scripts/join_constraints.py \
		--files $DATA_FOLDER/constraints/round2_constraints.csv \
			$DATA_FOLDER/constraints/remaining_reviewer_constraints.csv \
		--output $DATA_FOLDER/constraints/constraints_for_second_matching.csv
fi


printf "\n----------------------------------------"
printf "\nStarting second matching..."
printf "\n----------------------------------------\n"

phase_two_start_time=$(date +"%T")
printf "\n\n\nPhase two matching start time: $phase_two_start_time"

python -m matcher \
	--scores $DATA_FOLDER/round2_affinity_scores.csv $DATA_FOLDER/round2_bids.csv \
	--weights 1 1 \
	--constraints $DATA_FOLDER/constraints/constraints_for_second_matching.csv \
	--min_papers_default 0 \
	--max_papers_default $MAX_PAPERS \
	--max_papers $DATA_FOLDER/constraints/reviewer_supply_after_matching.csv \
	--num_reviewers $(($NUM_REVIEWS - 2)) \
	--num_alternates 1 \
	--solver $MATCHER_SOLVER \
	--probability_limits $Q \
	--output_folder $ASSIGNMENTS_FOLDER
	# --allow_zero_score_assignments \
sleep 10

mv $ASSIGNMENTS_FOLDER/assignments.json $ASSIGNMENTS_FOLDER/second_matching.json
mv $ASSIGNMENTS_FOLDER/alternates.json $ASSIGNMENTS_FOLDER/second_matching_alternates.json


# Convert assignments JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ASSIGNMENTS_FOLDER/second_matching.json \
	--output $ASSIGNMENTS_FOLDER/second_matching.csv

# Convert alternates JSON to CSV for convenience
python ICML2026/scripts/json_to_csv.py \
	--input $ASSIGNMENTS_FOLDER/second_matching_alternates.json \
	--output $ASSIGNMENTS_FOLDER/second_matching_alternates.csv

# ---------------------------------------------------------------------------------
printf "\n----------------------------------------"

# Join first and second matching assignments
python ICML2026/scripts/join_assignments.py \
	--files $ASSIGNMENTS_FOLDER/first_matching.csv \
		$ASSIGNMENTS_FOLDER/second_matching.csv \
	--output $ASSIGNMENTS_FOLDER/final_assignments.csv

# get updated policy for reviewers
python ICML2026/scripts/get_updated_reviewer_policy.py \
	--assignments $ASSIGNMENTS_FOLDER/final_assignments.csv \
	--reviewer $DATA_FOLDER/$REVIEWER_FILE \
	--submission $DATA_FOLDER/$SUBMISSION_FILE \
	--output $ASSIGNMENTS_FOLDER/updated_reviewer_policy.csv

# track papers with policy B with at least one reviewer A+B -> A and at least one reviewer A+B -> B
python ICML2026/scripts/track_target_experiment_cases.py \
	--reviewer_policy $ASSIGNMENTS_FOLDER/updated_reviewer_policy_experimental.csv \
	--assignments $ASSIGNMENTS_FOLDER/final_assignments.json \
	--output $ASSIGNMENTS_FOLDER/tracked_final_assignments.json

phase_two_end_time=$(date +"%T")
printf "\n\nPhase two matching end time: $phase_two_end_time"

python ICML2026/scripts/stat_check.py \
	--output_folder $ASSIGNMENTS_FOLDER \
	--assignments $ASSIGNMENTS_FOLDER/final_assignments.csv $ASSIGNMENTS_FOLDER/final_assignments.json \
	--reviewers $DATA_FOLDER/$REVIEWER_FILE \
	--bids $DATA_FOLDER/$BIDS_FILE

printf "\nDone."
printf "\nSCORES_FILE: $SCORES_FILE"
printf "\nAssignments saved in $ASSIGNMENTS_FOLDER"

end_time=$(date +"%T")


printf "\n\n Script start time: "
printf $script_start_time

printf "\n\n Preprocessing end time: "
printf $after_preprocess_time

printf "\n\n Phase 1 start time: "
printf $phase_one_start_time

printf "\n\n Phase 1 end time: "
printf $phase_one_end_time

printf "\n\n Phase 2 start time: "
printf $phase_two_start_time

printf "\n\n Phase 2 end time: "
printf $phase_two_end_time

printf "\n\n Script end time: "
printf $end_time

if [ "$COMPUTE_FINAL_POLICY" = "True" ]; then

	printf "\n\nFetching final policy constraints..."
	python ICML2026/scripts/get_final_policy_constraints.py \
		--submission $DATA_FOLDER/$SUBMISSION_FILE \
		--reviewer $ASSIGNMENTS_FOLDER/updated_reviewer_policy.csv \
		--outputs $DATA_FOLDER/constraints/final_policy_constraints.csv