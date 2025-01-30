# Examples for manual configurations

https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/Enabling-remote-SSH-login-on-Mac-OS-X.html
https://phoenixnap.com/kb/ssh-port-forwarding

```bash
nc -zv splunk.eulisa.local 1024-9091
ssh -L 127.0.0.1:local_port:destination_server_ip:remote_port ssh_server_hostname
ssh -R remote_port:127.0.0.1:local_port ssh_server_hostname
```


```bash
# Host 1 - local laptop - host 2 on port 9997
ssh -L 127.0.0.1:9997:splunk.eulisa.local:9997 jerome@localhost
ssh -R 9997:127.0.0.1:9997 urgency@harbor2.ocpasset.local
```


```bash
# From kubernetes ServiceMonitor
ssh -L 127.0.0.1:9090:harbor2.ocpasset.local:9090 jerome@localhost

ssh -R 9090:127.0.0.1:9090 jerome@splunk.eulisa.local

ssh -L 127.0.0.1:9997:splunk.eulisa.local:9997 jerome@localhost
```

