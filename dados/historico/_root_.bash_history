apt install -y sudo systemd-timesyncd
usermod -aG sudo pesquisador
adduser alvo
usermod -aG sudo alvo
ip -br link
nano /etc/network/interfaces
ifup enp0s8
ip -br addr
ping -c 2 deb.debian.org
cd /root/tcc-scripts
./01_medir_overhead.sh 5000 5
cat /root/tcc/overhead_resumo.txt
auditctl -l | wc -l
