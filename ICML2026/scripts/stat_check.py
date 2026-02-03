# import final_assignments.csv and final_assignments.json
import pandas as pd
import json
import matplotlib.pyplot as plt
import numpy as np
from tqdm import tqdm
import argparse


if __name__ == "__main__":

    argparser = argparse.ArgumentParser()
    argparser.add_argument("--output_folder", type=str, required=True)
    argparser.add_argument("--assignments", nargs="+", type=str, required=True)
    argparser.add_argument("--reviewers", type=str, required=True)
    argparser.add_argument("--bids", type=str, required=True)

    args = argparser.parse_args()

    # Set style for cleaner plots
    plt.style.use('default')
    plt.rcParams['figure.figsize'] = (10, 6)
    plt.rcParams['font.size'] = 11

    final_assignments = pd.read_csv(args.assignments[0], header=None)
    reviewers = pd.read_csv(args.reviewers)
    final_assignments_json = json.load(open(args.assignments[1]))
    bids = pd.read_csv(args.bids, header=None)
    bids.columns = ['submission', 'user', 'bid']

    # distribution of final_assignment scores (column 3)
    scores = final_assignments.iloc[:,2]
    mean_score = np.mean(scores)
    fig, ax = plt.subplots(figsize=(10, 6))
    n, bins, patches = ax.hist(scores, bins=40, range=(0, 2.10), edgecolor='black', linewidth=0.5, alpha=0.7)
    # Add count labels on top of each bar
    for i, count in enumerate(n):
        if count > 0:  # Only label bars with counts > 0
            bin_center = (bins[i] + bins[i+1]) / 2
            ax.text(bin_center, count, f'{int(count)}', ha='center', va='bottom', fontsize=8)
    ax.set_title(f"Distribution of Assignments by Scores (mean: {mean_score:.3f})", fontsize=12, fontweight='bold')
    ax.set_xlabel("Score", fontsize=11)
    ax.set_ylabel("Frequency", fontsize=11)
    # Set fine-grained x-axis ticks (every 0.1)
    ax.set_xticks(np.arange(0, 2.2, 0.1))
    ax.tick_params(axis='x', labelsize=9)
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    plt.tight_layout()
    plt.savefig(args.output_folder + "/distribution_of_assignments_by_scores.png", dpi=150)
    plt.close()

    # distribution of mean score per submission
    mean_scores = []
    for paper_id in final_assignments_json.keys():
        mean_score = np.mean([x['aggregate_score'] for x in final_assignments_json[paper_id]])
        mean_scores.append(mean_score)
    mean_of_means = np.mean(mean_scores)
    quantile_10 = np.quantile(mean_scores, 0.1)
    quantile_25 = np.quantile(mean_scores, 0.25)
    quantile_50 = np.quantile(mean_scores, 0.50)

    fig, ax = plt.subplots(figsize=(10, 6))
    n, bins, patches = ax.hist(mean_scores, bins=20, range=(0, 2.0), edgecolor='black', linewidth=0.5, alpha=0.7)
    # Add count labels on top of each bar
    for i, count in enumerate(n):
        if count > 0:  # Only label bars with counts > 0
            bin_center = (bins[i] + bins[i+1]) / 2
            ax.text(bin_center, count, f'{int(count)}', ha='center', va='bottom', fontsize=8)
    ax.set_title(f"Distribution of Number of Papers by Mean Scores\n(Mean: {mean_of_means:.3f} | Median: {quantile_50:.3f} | 25P: {quantile_25:.3f} | 10P: {quantile_10:.3f})", fontsize=12, fontweight='bold')
    ax.set_xlabel("Mean Score", fontsize=11)
    ax.set_ylabel("Number of Papers", fontsize=11)
    # Set fine-grained x-axis ticks (every 0.1)
    ax.set_xticks(np.arange(0, 2.1, 0.1))
    ax.tick_params(axis='x', labelsize=9)
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    plt.tight_layout()
    plt.savefig(args.output_folder + "/distribution_of_number_of_papers_by_mean_scores.png", dpi=150)
    plt.close()


    mean_scores_per_reviewer = []
    num_paper_per_reviewer = []
    for reviewer_id in final_assignments.iloc[:,1].unique():
        reviewer_scores = final_assignments[final_assignments.iloc[:,1] == reviewer_id].iloc[:,2]
        mean_score = np.mean(reviewer_scores)
        num_paper_per_reviewer.append(len(reviewer_scores))
        mean_scores_per_reviewer.append(mean_score)
    reviewer_list = reviewers['user'].tolist()
    unassigned_reviewers_num = len(set(reviewer_list) - set(final_assignments.iloc[:,1].unique()))

    mean_of_means_per_reviewer = np.mean(mean_scores_per_reviewer)
    mean_of_num_paper_per_reviewer = np.mean(num_paper_per_reviewer)
    quantile_10_per_reviewer = np.quantile(mean_scores_per_reviewer, 0.1)
    quantile_25_per_reviewer = np.quantile(mean_scores_per_reviewer, 0.25)
    quantile_50_per_reviewer = np.quantile(mean_scores_per_reviewer, 0.50)
    mean_scores_per_reviewer = mean_scores_per_reviewer + [0] * unassigned_reviewers_num
    fig, ax = plt.subplots(figsize=(10, 6))
    n, bins, patches = ax.hist(mean_scores_per_reviewer, bins=20, range=(0, 2.0), edgecolor='black', linewidth=0.5, alpha=0.7)
    # Add count labels on top of each bar
    for i, count in enumerate(n):
        if count > 0:  # Only label bars with counts > 0
            bin_center = (bins[i] + bins[i+1]) / 2
            ax.text(bin_center, count, f'{int(count)}', ha='center', va='bottom', fontsize=8)
    ax.set_title(f"Distribution of Number of Users by Mean Scores\n(Mean: {mean_of_means_per_reviewer:.3f} | Median: {quantile_50_per_reviewer:.3f} | 25P: {quantile_25_per_reviewer:.3f} | 10P: {quantile_10_per_reviewer:.3f})", fontsize=12, fontweight='bold')
    ax.set_xlabel("Score", fontsize=11)
    ax.set_ylabel("Frequency", fontsize=11)
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    plt.tight_layout()
    plt.savefig(args.output_folder + "/distribution_of_number_of_users_by_mean_scores.png", dpi=150)
    plt.close()

    fig, ax = plt.subplots(figsize=(10, 6))
    num_paper_per_reviewer = num_paper_per_reviewer + [0] * unassigned_reviewers_num
    n, bins, patches = ax.hist(num_paper_per_reviewer, bins=20, range=(0, 5), edgecolor='black', linewidth=0.5, alpha=0.7)

    # Add count labels on top of each bar
    for i, count in enumerate(n):
        if count > 0:  # Only label bars with counts > 0
            bin_center = (bins[i] + bins[i+1]) / 2
            ax.text(bin_center, count, f'{int(count)}', ha='center', va='bottom', fontsize=8)
    ax.set_title(f"Distribution of Number of Papers Assigned (mean: {mean_of_num_paper_per_reviewer:.3f})", fontsize=12, fontweight='bold')
    ax.set_xlabel("Number of Users", fontsize=11)
    ax.set_ylabel("Frequency", fontsize=11)
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    plt.tight_layout()
    plt.savefig(args.output_folder + "/distribution_of_number_of_papers_assigned.png", dpi=150)
    plt.close()

    bid_list = []
    for row in tqdm(final_assignments.itertuples(), total=len(final_assignments)):
        paper_id = row[1]
        reviewer_id = row[2]
        score = row[3]
        
        # get row from bids where bids['submission']==paper_id & bids['user']==reviewer_id
        bid_row = bids[(bids['submission']==paper_id) & (bids['user']==reviewer_id)]
        if len(bid_row) == 0:
            bid_list.append(0)
        else:
            if bid_row.iloc[0,:]['bid'] in ['High', "Very High"]:
                bid_list.append(1)
            else:
                bid_list.append(0)
    final_assignments['bid'] = bid_list

    num_positive_bids_per_reviewer = []
    for reviewer_id in final_assignments.iloc[:,1].unique():
        reviewer_bids = final_assignments[final_assignments.iloc[:,1] == reviewer_id]
        num_positive_bids = sum(list(reviewer_bids['bid']))
        num_positive_bids_per_reviewer.append(num_positive_bids)

    mean_of_num_positive_bids_per_reviewer = np.mean(num_positive_bids_per_reviewer)
    fig, ax = plt.subplots(figsize=(10, 6))
    n, bins, patches = ax.hist(num_positive_bids_per_reviewer, bins=20, range=(0, 5), edgecolor='black', linewidth=0.5, alpha=0.7)
    # Add count labels on top of each bar
    for i, count in enumerate(n):
        if count > 0:  # Only label bars with counts > 0
            bin_center = (bins[i] + bins[i+1]) / 2
            ax.text(bin_center, count, f'{int(count)}', ha='center', va='bottom', fontsize=8)
    ax.set_title(f"Distribution of Number of Positive Bids per Reviewer (mean: {mean_of_num_positive_bids_per_reviewer:.3f})", fontsize=12, fontweight='bold')
    ax.set_xlabel("Number of Positive Bids", fontsize=11)
    ax.set_ylabel("Frequency", fontsize=11)
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    plt.tight_layout()
    plt.savefig(args.output_folder + "/distribution_of_number_of_positive_bids_per_reviewer.png", dpi=150)
    plt.close()