SELECT pid, family, protocol, local_address, local_port, remote_address, remote_port, state FROM process_open_sockets WHERE remote_port != 0;
