
export FULL_RUN=True

export GROUP="Reviewers_Main"
export ORIGIN_DATA_FOLDER="ICML2026/$GROUP/data"

export SPLIT_GROUP="Reviewers_Main_Split"
export SPLIT_DATA_FOLDER="/nobackup2/froilan/ICML_Matching/$SPLIT_GROUP"
export SPLIT1_CONSTRAINTS_FOLDER="/nobackup2/froilan/ICML_Matching/$SPLIT_GROUP/group1/data/constraints"
export SPLIT1_ASSIGNMENTS_FOLDER="/nobackup2/froilan/ICML_Matching/$SPLIT_GROUP/group1/assignments"
export SPLIT2_CONSTRAINTS_FOLDER="/nobackup2/froilan/ICML_Matching/$SPLIT_GROUP/group2/data/constraints"
export SPLIT2_ASSIGNMENTS_FOLDER="/nobackup2/froilan/ICML_Matching/$SPLIT_GROUP/group2/assignments"

mkdir -p $SPLIT_DATA_FOLDER
mkdir -p $SPLIT1_CONSTRAINTS_FOLDER
mkdir -p $SPLIT1_ASSIGNMENTS_FOLDER
mkdir -p $SPLIT2_CONSTRAINTS_FOLDER
mkdir -p $SPLIT2_ASSIGNMENTS_FOLDER


if [ "$FULL_RUN" = "True" ]; then
    # required files
    # you need agg_constraints.csv ready
    python ICML2026/scripts/split_groups.py \
        --scores $ORIGIN_DATA_FOLDER/affinity_scores.csv \
        --reviewer $ORIGIN_DATA_FOLDER/reviewer.csv \
        --submission $ORIGIN_DATA_FOLDER/submission.csv \
        --qualification $ORIGIN_DATA_FOLDER/qualifications.csv \
        --files $ORIGIN_DATA_FOLDER/bids.csv \
            $ORIGIN_DATA_FOLDER/constraints/agg_constraints.csv \
        --output_dir $SPLIT_DATA_FOLDER \
        --seed 42
    mv $SPLIT_DATA_FOLDER/group1/affinity_scores.csv $SPLIT_DATA_FOLDER/group1/data/affinity_scores.csv
    mv $SPLIT_DATA_FOLDER/group1/reviewer.csv $SPLIT_DATA_FOLDER/group1/data/reviewer.csv
    mv $SPLIT_DATA_FOLDER/group1/submission.csv $SPLIT_DATA_FOLDER/group1/data/submission.csv
    mv $SPLIT_DATA_FOLDER/group1/qualifications.csv $SPLIT_DATA_FOLDER/group1/data/qualifications.csv
    mv $SPLIT_DATA_FOLDER/group1/bids.csv $SPLIT_DATA_FOLDER/group1/data/bids.csv
    mv $SPLIT_DATA_FOLDER/group1/agg_constraints.csv $SPLIT_DATA_FOLDER/group1/data/constraints/agg_constraints.csv

    mv $SPLIT_DATA_FOLDER/group2/affinity_scores.csv $SPLIT_DATA_FOLDER/group2/data/affinity_scores.csv
    mv $SPLIT_DATA_FOLDER/group2/reviewer.csv $SPLIT_DATA_FOLDER/group2/data/reviewer.csv
    mv $SPLIT_DATA_FOLDER/group2/submission.csv $SPLIT_DATA_FOLDER/group2/data/submission.csv
    mv $SPLIT_DATA_FOLDER/group2/qualifications.csv $SPLIT_DATA_FOLDER/group2/data/qualifications.csv
    mv $SPLIT_DATA_FOLDER/group2/bids.csv $SPLIT_DATA_FOLDER/group2/data/bids.csv
    mv $SPLIT_DATA_FOLDER/group2/agg_constraints.csv $SPLIT_DATA_FOLDER/group2/data/constraints/agg_constraints.csv
else    
    python ICML2026/scripts/split_groups.py \
        --scores $ORIGIN_DATA_FOLDER/affinity_scores.csv \
        --reviewer $ORIGIN_DATA_FOLDER/reviewer.csv \
        --submission $ORIGIN_DATA_FOLDER/submission.csv \
        --qualification $ORIGIN_DATA_FOLDER/qualifications.csv \
        --files $ORIGIN_DATA_FOLDER/bids.csv \
            $ORIGIN_DATA_FOLDER/constraints/conflict_constraints.csv \
            $ORIGIN_DATA_FOLDER/constraints/hard_policy_constraints.csv \
        --output_dir $SPLIT_DATA_FOLDER \
        --seed 42
fi

