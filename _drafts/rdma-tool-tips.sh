# \note We use Mellanox's RNIC as an example.

# List all network devices
sudo lshw -businfo -c network

# List RNIC's PCIe devices
lspci | grep Mellanox

# \note This can help us to figure out a PCIe device's route to CPU.
# List PCIe bus tree
lspci -t

# Show capbilities of a PCIe device, e.g. whether support SR-IOV, ARI, etc.
# \note ARI is used to extend number of VFs from 8 to 256 in one PCIe bus.
lspci -v[vv] -s <B:D.F>

# Show driver for a PCIe device
lspci -k -s <B:D.F>

# \note Tool ibv_device and ibv_devinfo is provided by libibverbs.
# List IB devices and their GUIDs
ibv_devices

# Show all attributes for a IB device
ibv_devinfo -v -d mlx4_0 -p 1

# Do micro-benchmarks with tools provided by perftests.
ib_send_bw -d mlx4_0 -p 1 -x 1 -q 1000 -s 65535 --report_gbits --run_infinitely -D 1 <server_ip>

# Use RoCEv2 instead of IB
cat >/etc/modprobe.d/mlx4_core.conf <<EOF
options mlx4_core roce_mode=2
EOF

# Enable SR-IOV
cat >/etc/modprobe.d/mlx4_core.conf <<EOF
options mlx4_core port_type_array=2,2 num_vfs=4,0,0 log_num_entry_size=-1 enable_vfs_qos=1
EOF

# Reload drivers
sudo /etc/init.d/openibd restart

# Dump RoCE traffic
sudo ethtool--set-priv-flags eth0 sniffer on
sudo tcpdump -i eht0 -vv -XX

# Install userspace tools on Ubuntu
sudo apt install rdma-core ibverbs-utils

# Enable Soft-RoCE
sudo rxe_cfg start
sudo rxe_cfg add eno1
