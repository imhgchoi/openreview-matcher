import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import json
if __name__ == "__main__":

    argparser = argparse.ArgumentParser()
    argparser.add_argument("--qualification", type=str, help="Qualification CSV file")
    argparser.add_argument("--outputs", nargs="+", type=str, help="Output CSV files")
    args = argparser.parse_args()

    qualification_df = pd.read_csv(args.qualification)
    
    emergency_reviewers_df = qualification_df[(qualification_df.type == 'emergency-medium') | (qualification_df.type == 'emergency-high')]
    unqualified_reviewers_df = qualification_df[(qualification_df.type == 'regular-low')]
    round1_reviewers_df = qualification_df[(qualification_df.type == 'regular-high')]
    round2_reviewers_df = qualification_df[(qualification_df.type == 'regular-high') | (qualification_df.type == 'regular-medium')]

    emergency_reviewers_df.to_csv(args.outputs[0], index=False)
    unqualified_reviewers_df.to_csv(args.outputs[1], index=False)
    round1_reviewers_df.to_csv(args.outputs[2], index=False)
    round2_reviewers_df.to_csv(args.outputs[3], index=False)


