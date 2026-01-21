# ICML 2026 OpenReview Matcher

`matching.sh` will carry out the ICML 2026 reviewer-submission matching process end-to-end.

## Test Phase
Outside the ICML2026 directory, run
```
sh ICML2026/matching_test.sh
```
This will create a "Reviewers" folder in ```ICML2026/```. For testing, you need to prepare the data in the following format:

```
Reviewers - data/ - constraints/ - conflict_constraints.csv (<- conflict_test.csv)
                  - bids.csv  (<- bid_test.csv)
                  - affinity_scores.csv  (<- affinity_score_test.csv)
                  - submission.csv   (<- paper_test.csv)
                  - reviewer.csv   (<- reviewer_test.csv)
                  - emergency-4plus-reviewers.csv  (create a blank file for now)
                  - reciprocal-reviewer-noBid.csv  (create a blank file for now)
``` 

The script will create three separate folders containing the data for each iteratation of unconstrained/hard/soft policy constraints.