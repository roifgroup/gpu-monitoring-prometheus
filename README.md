**TL;DR: Not everyone needs a K8S environment where everything is automated and over engineered. Sometimes you just need a small prometheus & grafana to collect data. This is a little automated to start and destroy a monitoring solution.**

**Warnings:**
I tried to make a bit secure by using mTLS but, this is not a production level solution. I left some gaps by design:
* Single CA created by command line for 10yr.
* The server and client certificates are also set for 10yr.
* There is basic authentication left on the prometheus side - please do not expose it in production like this.
* I did not specify specific prometheus and grafana versions
* The nvidia node exporter is not a production level solution and does not get regular maintenance.

This little project is based on the work of Utku Özdemir:
[https://github.com/utkuozdemir/nvidia_gpu_exporter](https://github.com/utkuozdemir/nvidia_gpu_exporter)

**Quick Start:**
1. Change passwords. You can a reference in the install_grafana.sh file and the docker-compose file.
2. Change certificate information in the install_grafana.sh.
3. Run the install_grafana.sh script.
4. To install a monitoring solution on a system:
    * Copy the install_nvidia_exporter.sh file and node_exporter_installer folder to the system needed to be monitored.
    * Run the install_nvidia_exporter.sh script.
    * On the system running the prometheus container, run the add_gpu_node.sh to add the new system.
5. Optional: You can use the dashboard created in the gpu node exporter project in the Dashboards folder.
6. Cleanup: There are uninstallation scripts to clean up the env after you are done.

**Screenshot:**
![example dashboard](https://github.com/roifgroup/gpu-monitoring-prometheus/blob/main/examples/gpu-dashboard.png)
