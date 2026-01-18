# ICML 20265 OpenReview Matcher

`matching.sh` will carry out the ICML 2026 reviewer-submission matching process end-to-end.

## Test Phase
Outside the ICML2026 directory, run
```
sh ICML2026/matching_test.sh
```
This will create a "Reviewers" folder in ```ICML2026/```. For testing, you need to prepare the data in the following format:

```
Reviewers - data/ - constraints/ - conflict_constraints.csv
                  - bids.csv
          - assignments/
          - affinity_scores.csv
          - emergency-4plus-reviewers.csv
          - reciprocal-reviewer-noBid.csv
          - paper_test.csv
          - quota_test.csv
```