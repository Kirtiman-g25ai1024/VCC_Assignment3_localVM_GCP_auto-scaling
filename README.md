# 🚀 Auto-Scale Local VM to GCP

**Automatically provision cloud resources on Google Cloud Platform when local VM resource usage exceeds 75%.**

A hybrid cloud auto-scaling solution that monitors a local VirtualBox VM and bursts to GCP Compute Engine on demand using Prometheus, Terraform, and Ansible.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      LOCAL VM (VirtualBox)                   │
│                                                             │
│  ┌──────────┐   ┌─────────────┐   ┌───────────────────┐    │
│  │ Flask App │──▶│ Node        │──▶│ Prometheus        │    │
│  │ (Docker)  │   │ Exporter    │   │ + Alert Rules     │    │
│  └──────────┘   └─────────────┘   └────────┬──────────┘    │
│                                             │               │
│                                    ┌────────▼──────────┐    │
│                                    │  monitor.sh        │    │
│                                    │  (75% threshold)   │    │
│                                    └────────┬──────────┘    │
└─────────────────────────────────────────────┼───────────────┘
                                              │
                                    ┌─────────▼──────────┐
                                    │  autoscale.py       │
                                    │  (Scale Controller) │
                                    └─────────┬──────────┘
                                              │
                              ┌───────────────▼────────────────┐
                              │        GOOGLE CLOUD (GCP)       │
                              │                                 │
                              │  ┌────────────┐  ┌───────────┐ │
                              │  │ Terraform   │─▶│ GCE VM    │ │
                              │  │ (IaC)       │  │ + Docker  │ │
                              │  └────────────┘  └───────────┘ │
                              └─────────────────────────────────┘
```

### Flow

1. **DETECT** — Prometheus scrapes metrics every 15s; `monitor.sh` checks against the 75% threshold every 30s
2. **PROVISION** — When threshold is breached for >1 min, `autoscale.py` runs `terraform apply` to create a GCE instance
3. **DEPLOY** — The GCE startup script installs Docker and deploys the app (or Ansible handles it)
4. **VERIFY** — Health checks confirm the cloud VM is live (retries up to 5 minutes)
5. **SCALE DOWN** — When usage drops below 50% for 10 minutes, `terraform destroy` removes the cloud VM

---

## Prerequisites

| Component | Minimum    | Recommended |
| --------- | ---------- | ----------- |
| Host CPU  | 4 cores    | 8+ cores    |
| Host RAM  | 8 GB       | 16+ GB      |
| Host Disk | 50 GB free | 100+ GB SSD |

### Software

- [Oracle VirtualBox 7.0+](https://www.virtualbox.org/)
- [Ubuntu 22.04 LTS ISO](https://ubuntu.com/download/server)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform v1.5+](https://www.terraform.io/)
- [Ansible v2.14+](https://docs.ansible.com/)
- [Docker & Docker Compose](https://docs.docker.com/get-docker/)
- Python 3.10+
- Git

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/Kirtiman-g25ai1024/autoscale-demo.git
cd autoscale-demo
```

### 2. GCP Setup

```bash
# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
export GCP_PROJECT_ID="vm-autoscale-project"

gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
gcloud config set project $GCP_PROJECT_ID
```

> **Required GCP APIs:** Compute Engine, Cloud Resource Manager  
> **Service account roles:** Compute Admin, Storage Admin

### 3. Local VM Setup (VirtualBox)

1. Create a VM: **Name** `autoscale-local-vm` / **Type** Linux Ubuntu 64-bit / **2 CPU, 4 GB RAM, 20 GB disk**
2. Configure networking:
   - **Adapter 1 (NAT):** Internet access
   - **Adapter 2 (Host-Only):** Host ↔ VM communication at `192.168.56.10`
3. Install Ubuntu 22.04 and run the setup script:

```bash
sudo bash scripts/setup.sh
```

### 4. Start the Application

```bash
cd /opt/autoscale-demo
docker-compose up -d --build
curl http://localhost:5000/   # Verify
```

### 5. Start Monitoring

```bash
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

### 6. Start Auto-Scale Monitor

```bash
nohup bash scripts/monitor.sh &
```

---

## Dashboards

| Service     | URL                       | Credentials      |
| ----------- | ------------------------- | ---------------- |
| Application | http://192.168.56.10:5000 | —                |
| Prometheus  | http://192.168.56.10:9090 | —                |
| Grafana     | http://192.168.56.10:3000 | admin / admin123 |

---

## Testing — Trigger Auto-Scale

```bash
# CPU stress for 120 seconds
curl http://192.168.56.10:5000/stress/cpu/120

# Memory stress — allocate 3 GB on a 4 GB VM
curl http://192.168.56.10:5000/stress/memory/3072

# Or use the Linux stress tool
sudo apt install stress
stress --cpu 4 --timeout 120
```

### Expected Timeline

| Time   | Event                  | Action             |
| ------ | ---------------------- | ------------------ |
| T+0s   | Stress test started    | Monitoring         |
| T+30s  | First threshold check  | Alert logged       |
| T+60s  | Sustained >75%         | Scale-up triggered |
| T+90s  | Terraform provisioning | GCE VM creating    |
| T+180s | App deploying on GCP   | Docker building    |
| T+240s | Health check passes    | Cloud VM live      |

### Verify Cloud Deployment

```bash
cd terraform
CLOUD_IP=$(terraform output -raw instance_ip)
curl http://$CLOUD_IP:5000/
curl http://$CLOUD_IP:5000/health
tail -50 /var/log/autoscale.log
```

---

## Project Structure

```
autoscale-demo/
├── README.md
├── docker-compose.yml
├── .gitignore
├── app/
│   ├── app.py                 # Flask web application with stress endpoints
│   ├── Dockerfile
│   └── requirements.txt
├── monitoring/
│   ├── docker-compose.monitoring.yml
│   ├── prometheus.yml
│   ├── alert_rules.yml
│   └── grafana/dashboards/
├── terraform/
│   ├── main.tf                # GCE instance + firewall
│   ├── variables.tf
│   ├── outputs.tf
│   └── startup.sh             # Cloud VM bootstrap
├── ansible/
│   ├── deploy.yml             # Deployment playbook
│   ├── inventory.yml
│   └── roles/
└── scripts/
    ├── monitor.sh             # Resource monitoring loop
    ├── autoscale.py           # Scale controller (Terraform wrapper)
    └── setup.sh               # Initial VM setup script
```

---

## Troubleshooting

| Issue                   | Cause                       | Solution                                   |
| ----------------------- | --------------------------- | ------------------------------------------ |
| Terraform auth fails    | Missing/expired credentials | Re-export `GOOGLE_APPLICATION_CREDENTIALS` |
| VM won't start on GCP   | Quota exceeded in region    | Check GCP quotas; request increase         |
| Health check timeout    | App not yet ready           | Increase retry count or delay              |
| Prometheus no data      | Node Exporter not running   | Check `docker-compose logs`                |
| Firewall blocks traffic | Missing firewall rules      | Verify Terraform firewall resource         |
| Scale-up not triggering | Cooldown period active      | Remove `/tmp/autoscale_cooldown`           |

---

## Future Enhancements

- GCP Managed Instance Groups for multi-instance cloud scaling
- GCP Load Balancer for traffic distribution
- Cloud SQL for shared state management
- CI/CD pipelines for automated application updates

---

## License

This project is for educational/academic purposes.
