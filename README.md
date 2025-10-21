# HNG DevOps Stage 1 — Automated Docker Deployment Script

## 👤 Author
- **Name:** Victor Efunwa  
- **Slack Username:** @Ballack  
- **GitHub Username:** BallackB
- ## Developer
viktorballack@gmail.com
-  ## API Endpoint
http://34.79.138.102
## GitHub Repository
https://github.com/BallackB/hng-stage1-devops

---

## 📌 Project Description
This project automates the deployment of a Dockerized application to a remote Ubuntu server (Google Cloud VM) using a single Bash script `deploy.sh`.  

It includes:
- Git repo cloning/pulling using a GitHub PAT
- SSH server validation
- Automatic Docker, Docker Compose & NGINX setup
- App deployment using Docker / Docker Compose
- NGINX reverse proxy on port 80
- Idempotent redeployment support
- Optional cleanup flag to remove containers & NGINX config

---

## ✅ Requirements Before Running

Make sure you have:
- Ubuntu-based local machine or WSL (Windows OK)
- Remote server (GCP/AWS/DO) running **Ubuntu 22.04 LTS**
- SSH key access to server (`~/.ssh/id_rsa`)
- GitHub Personal Access Token (PAT)
- Public repo with Dockerfile or docker-compose.yml

---

## ⚙️ Make Script Executable

```bash
chmod +x deploy.sh
