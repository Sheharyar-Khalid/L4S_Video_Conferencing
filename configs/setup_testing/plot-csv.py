"""
Script: plot-csv.py
Description: Reads the sender-ss.csv file and generates plots for Throughput (in Mbps),
             RTT, Retransmissions, and Congestion Window over time.
             Handles empty columns and non-numeric data gracefully.
             Accepts a custom title for the plots and saves the plot image using the title.
Usage: python plot-csv.py <path_to_csv> <title>
Example: python plot-csv.py sender-ss.csv "Experiment 1: High Latency"
"""
# Used GPT To help generate some descriptions
import sys
import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import argparse

def parse_arguments():

    parser = argparse.ArgumentParser(description='Plot network metrics from CSV file.')
    parser.add_argument('csv_path', type=str, help='Path to the sender-ss.csv file.')
    parser.add_argument('title', type=str, nargs='+', help='Custom title for the plots. Use quotes if title contains spaces.')
    args = parser.parse_args()
    plot_title = ' '.join(args.title)
    if not os.path.isfile(args.csv_path):
        print(f"Error: File '{args.csv_path}' does not exist.")
        sys.exit(1)
    return args.csv_path, plot_title

def load_data(csv_path):
    """
    Loads the CSV data into a Pandas DataFrame and assigns column names.
    Handles variable number of columns by specifying all possible columns.
    """
    column_names = ['ts', 'sender', 'normalized_tput', 'rtt',
                    'retr_current', 'retr_total', 'cwnd', 'ssthresh']
    
    try:
        df = pd.read_csv(csv_path, names=column_names, header=None, 
                         na_values=['', ' ', 'NA', 'NaN'])
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        sys.exit(1)
    
    return df

def process_data(df):
    """
    Processes the DataFrame by converting data types and handling missing or malformed data.
    Converts 'normalized_tput' from Kbps to Mbps.
    """
    numeric_columns = ['ts', 'normalized_tput', 'rtt', 'retr_current',
                       'retr_total', 'cwnd', 'ssthresh']
    
    for col in numeric_columns:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    
    df['retr_total'] = pd.to_numeric(df['retr_total'], errors='coerce')
    
    df.fillna(method='ffill', inplace=True)
    
    df['normalized_tput'] = df['normalized_tput'] / 1000  # Convert Kbps to Mbps
    
    return df

def plot_metrics(df, plot_title):
    """
    Generates and saves plots for Throughput (Mbps), RTT, Retransmissions, and Congestion Window.
    Incorporates a custom title and saves the plot image using the title with underscores.
    """
    sns.set(style="whitegrid")
    fig, axs = plt.subplots(4, 1, figsize=(14, 24))
    sns.lineplot(ax=axs[0], x='ts', y='normalized_tput', data=df, color='blue')
    axs[0].set_title('Throughput over Time')
    axs[0].set_xlabel('Time (s)')
    axs[0].set_ylabel('Throughput (Mbps)')
    
    sns.lineplot(ax=axs[1], x='ts', y='rtt', data=df, color='green')
    axs[1].set_title('Round-Trip Time (RTT) over Time')
    axs[1].set_xlabel('Time (s)')
    axs[1].set_ylabel('RTT (ms)')
    
    sns.lineplot(ax=axs[2], x='ts', y='retr_current', data=df, color='red', label='Current Retransmissions')
    sns.lineplot(ax=axs[2], x='ts', y='retr_total', data=df, color='orange', label='Total Retransmissions')
    axs[2].set_title('Retransmissions over Time')
    axs[2].set_xlabel('Time (s)')
    axs[2].set_ylabel('Retransmissions')
    axs[2].legend()
    
    sns.lineplot(ax=axs[3], x='ts', y='cwnd', data=df, color='purple', label='Congestion Window')
    sns.lineplot(ax=axs[3], x='ts', y='ssthresh', data=df, color='brown', label='Slow Start Threshold')
    axs[3].set_title('Congestion Control Metrics over Time')
    axs[3].set_xlabel('Time (s)')
    axs[3].set_ylabel('Bytes')
    axs[3].legend()
    
    if plot_title:
        fig.suptitle(plot_title, fontsize=20, y=0.98)  
        plt.subplots_adjust(top=0.92)
    
    plt.tight_layout()
    
    safe_title = plot_title.replace(' ', '_') if plot_title else 'sender-ss'
    output_image = f"{safe_title}_plots.png"
    
    plt.savefig(output_image)
    print(f"Plots saved as '{output_image}'")
    
    plt.show()

def main():
    csv_path, plot_title = parse_arguments()
    df = load_data(csv_path)
    df = process_data(df)
    
    plot_metrics(df, plot_title)

if __name__ == "__main__":
    main()
