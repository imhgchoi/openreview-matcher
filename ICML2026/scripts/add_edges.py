import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import json

    
if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--conflict", type=str, help="Conflict constraints CSV file")

    args = argparser.parse_args()

    conflict_df = pd.read_csv(args.conflict, header=None)

    # randomly drop conflict edges
    conflict_df = conflict_df.sample(frac=0.5, random_state=42)
    conflict_df.to_csv(args.conflict, index=False, header=False)

