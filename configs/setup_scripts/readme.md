# A script to clean and set up network configurations using Open vSwitch (OVS) (drogon1_setup.sh).
## Usage:
- sudo ./drogon1_setup.sh clean
- sudo ./drogon1_setup.sh setup --delay <delay_ms> --ecn <0|1|2|3> --cc <cubic|bbr|reno|prague> --dualpi2 <1|0> --htb_rate <rate>
- Same for drogon2
- drogon1 and drogon2 are devices

# A script to verify network configurations by printing sysctl variables and tc qdisc settings on both the host and the network namespace 'router_ns' (verify_drogon1.sh).
- sudo verify_drogon1.sh
- sudo verify_drogon2.sh

# Script to run video call is ./run_video.sh
- More details in the script
- Run this after setting up drogon1 and drogon2