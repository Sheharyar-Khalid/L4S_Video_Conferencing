import json
import matplotlib.pyplot as plt
import numpy as np

# Load the iperf3 JSON file
file_path = "./cubic_5flows.json"  # Update with the correct file path
with open(file_path, 'r') as file:
    iperf_data = json.load(file)

# Extract data for individual streams
streams = iperf_data.get('intervals', [])
stream_data = {}

# Collect RTT and bits per second data for each stream
for interval in streams:
    for stream in interval['streams']:
        stream_id = stream['socket']
        if stream_id not in stream_data:
            stream_data[stream_id] = {'time': [], 'rtt': [], 'bps': []}
        stream_data[stream_id]['time'].append(interval['sum']['start'])
        stream_data[stream_id]['rtt'].append(stream.get('rtt', 0) / 10**3)  # Convert RTT to seconds
        stream_data[stream_id]['bps'].append(stream['bits_per_second'] / 10**6)  # Convert bps to Mbps


# Function to compute averages over chunks
def compute_averages(data, chunk_size=10):
    avg_data = {
        'time': [],
        'rtt': [],
        'bps': []
    }
    for i in range(0, len(data['time']), chunk_size):
        chunk_time = data['time'][i:i + chunk_size]
        chunk_rtt = data['rtt'][i:i + chunk_size]
        chunk_bps = data['bps'][i:i + chunk_size]
        if chunk_time:
            avg_data['time'].append(np.mean(chunk_time))
            avg_data['rtt'].append(np.mean(chunk_rtt)-45)
            avg_data['bps'].append(np.mean(chunk_bps))
    return avg_data

# Plotting aggregated data
plt.figure()
stream = 1
for stream_id, data in stream_data.items():
    avg_data = compute_averages(data, chunk_size=10)
    
    # RTT vs Time
    
    plt.plot(avg_data['time'], avg_data['rtt'],label=f"Stream {stream}")
    stream+=1
plt.legend()
plt.title("Aggregated RTT vs Time (TCP Cubic)")
plt.xlabel("Time (seconds)")
plt.ylabel("RTT (ms)")
plt.axhline(y=50, color='r', linestyle='--', label="Base RTT 50ms")
# plt.ylim((48,52))
plt.grid()
plt.savefig('rtt_vs_time_cubic.png')
plt.show()

stream =1
plt.figure()
for stream_id, data in stream_data.items():
    avg_data = compute_averages(data, chunk_size=10)
    # Bits per Second vs Time
    
    plt.plot(avg_data['time'], avg_data['bps'],label=f"Steam {stream}")
    stream+=1
plt.legend()
plt.title(f"Aggregated Bits per Second vs Time (TCP Cubic)")
plt.xlabel("Time (seconds)")
plt.ylabel("Bits per Second")
plt.savefig('tput_vs_time_cubic.png')
plt.grid()
plt.show()
