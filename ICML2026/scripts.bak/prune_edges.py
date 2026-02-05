import argparse
import pandas as pd
import numpy as np
import openreview
import os
from tqdm import tqdm
import json
if __name__ == "__main__":

    argparser = argparse.ArgumentParser()
    argparser.add_argument("--affinity", type=str, help="Affinity CSV file")
    argparser.add_argument("--bids", type=str, help="Bids CSV file")
    argparser.add_argument("--conflict", type=str, help="Conflict constraints CSV file")
    argparser.add_argument("--num_reviewers", type=int, help="Number of reviewers")
    argparser.add_argument("--num_papers", type=int, help="Number of papers")
    argparser.add_argument("--K", type=int, help="Top K edges to keep")
    argparser.add_argument("--slack", type=int, help="Slack")


    args = argparser.parse_args()

    K = args.K
    R = args.slack

    affinity_df = pd.read_csv(args.affinity, header=None)
    bids_df = pd.read_csv(args.bids, header=None)
    conflict_df = pd.read_csv(args.conflict, header=None)

    # remove conflict edges
    conflict_keys = set(list(zip(conflict_df[0], conflict_df[1])))
    affinity_filtered = affinity_df[~pd.Series(list(zip(affinity_df[0], affinity_df[1]))).isin(conflict_keys).values]
    bids_filtered = bids_df[~pd.Series(list(zip(bids_df[0], bids_df[1]))).isin(conflict_keys).values]
    print('affinity_filtered: ', len(affinity_filtered))
    print('bids_filtered: ', len(bids_filtered))
    
    # filter bidding
    affinity_keys = set(list(zip(affinity_df[0], affinity_df[1])))
    bids_filtered = bids_filtered[pd.Series(list(zip(bids_filtered[0], bids_filtered[1]))).isin(affinity_keys).values]
    bids_filtered.to_csv(args.bids, index=False, header=False)
    bids_filtered = bids_filtered[bids_filtered.iloc[:,2] > 0]
    print('bids_filtered (after positive filtering): ', len(bids_filtered))

    ## REVIEWER SIDE
    # affinity edges in bids
    bids_keys = set(list(zip(bids_filtered[0], bids_filtered[1])))
    bids_edges = affinity_filtered[pd.Series(list(zip(affinity_filtered[0], affinity_filtered[1]))).isin(bids_keys).values]
    
    # edges from reviewer side
    affinity_filtered.columns = ['paper', 'reviewer', 'score']
    reviewer_edges = affinity_filtered.groupby('reviewer', group_keys=False).apply(lambda x: x.nlargest(K, "score")).reset_index(drop=True)

    # random sample R edges for each reviewer in affinity_filtered, which are not in reviewer_edges (df)
    reviewer_edges_keys = set(list(zip(reviewer_edges['paper'], reviewer_edges['reviewer'])))
    reviewer_affinity_filtered = affinity_filtered[~pd.Series(list(zip(affinity_filtered['paper'], affinity_filtered['reviewer']))).isin(reviewer_edges_keys).values]
    reviewer_edges_random = reviewer_affinity_filtered.groupby('reviewer', group_keys=False).apply(lambda x: x.sample(R, replace=True)).reset_index(drop=True)
    reviewer_edges_random = reviewer_edges_random.drop_duplicates()

    ## PAPER SIDE
    # edges from paper side
    paper_edges = affinity_filtered.groupby('paper', group_keys=False).apply(lambda x: x.nlargest(K, "score")).reset_index(drop=True)

    # random sample R edges for each paper in affinity_filtered, which are not in paper_edges (df)
    paper_edges_keys = set(list(zip(paper_edges['paper'], paper_edges['reviewer'])))
    paper_affinity_filtered = affinity_filtered[~pd.Series(list(zip(affinity_filtered['paper'], affinity_filtered['reviewer']))).isin(paper_edges_keys).values]
    paper_edges_random = paper_affinity_filtered.groupby('paper', group_keys=False).apply(lambda x: x.sample(R, replace=True)).reset_index(drop=True)
    paper_edges_random = paper_edges_random.drop_duplicates()


    # union of all edges
    bids_edges.columns = ['paper','reviewer','score']
    print('bid, reviewer, reviewer random, paper, paper random')
    print(len(bids_edges), len(reviewer_edges), len(reviewer_edges_random), len(paper_edges), len(paper_edges_random))
    edges = pd.concat([bids_edges, reviewer_edges, reviewer_edges_random, paper_edges, paper_edges_random])
    edges = edges.drop_duplicates()
    print('unioned: ', len(edges))

    # save to csv
    edges.to_csv(args.affinity, index=False, header=False)
