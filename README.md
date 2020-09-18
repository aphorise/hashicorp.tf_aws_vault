# Terraform Vault Cluster 

An AWS Vault setup using RAFT and with TLS Certificates & NLB


## TODO:
- [ ] - Complete network routes, target-groups & listeners for connecting WAN / net based consumption (externally) - ie `curl http://...fqdn...` 

- [ ] - TLS Certificate for NLB & same certs for re-use in Vault with either wildcard or SAN to include LB address FQDN as well Vault instances (vault1, vault2, vault3 .*.tld) - ie `curl https://...fqdn...` 

- [ ] - Enhance network with future multi-clusters in-mind (API & RPC externally) to allow for WAN / externally connectivity (eg allowing for a DR cluster from laptop locally) - `nc -w 1 -z ...fqnd... 8201 ; echo $?` 

---