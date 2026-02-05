import argparse
import pandas as pd
import json
import warnings

warnings.filterwarnings("ignore") # pandas deprecation warnings

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--assignments', type=str, help='Final assignment file')
    parser.add_argument('--output', type=str, help='Output file')

    args = parser.parse_args()

    with open(args.assignments) as f:
        df = pd.read_csv(f, header=None)
    
    # evaluate the quality of assignments: calculate average affinity of reviewers per submission, and then evaluate the average and variance of this quantity over all submissions
    average_affinity = df.groupby(0).mean(numeric_only=True)
    average_affinity_mean = average_affinity[2].mean()
    average_affinity_variance = average_affinity[2].var()

    # save to text file
    with open(args.output, 'w') as f:
        f.write(f"{average_affinity_mean}\n")
        f.write(f"{average_affinity_variance}\n")

    # print the average and variance of the average affinity
    print(f"Average affinity mean: {average_affinity_mean}")
    print(f"Average affinity variance: {average_affinity_variance}")