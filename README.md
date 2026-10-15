# Northstar Student Placement Portal

A static student placement portal with a Docker image, a two-replica Kubernetes Deployment, a NodePort Service, and a Jenkins CI/CD pipeline. The Jenkins pipeline pushes versioned images and automatically restores the prior Deployment revision when a candidate fails its rollout.

## Files

- `index.html` - Responsive student placement dashboard with student profiles, placement outcomes, recruiter profiles, and upcoming drives.
- `Dockerfile` - Packages the page with nginx. `APP_FAULTY=true` deliberately omits the health endpoint so Kubernetes readiness fails during the rollback exercise.
- `deployment.yaml` - Two-replica rolling Deployment and NodePort Service on port `30080`.
- `Jenkinsfile` - Build, push, deploy, rollout verification, rollback, and post-deployment page check.

## Build and verify locally

Install Docker Desktop and start its Docker engine. From this repository directory:

```powershell
docker build -t <dockerhub-username>/student-placement-portal:1 .
docker run --rm -d --name placement-portal -p 8080:80 <dockerhub-username>/student-placement-portal:1
```

Open <http://localhost:8080> and confirm the placement dashboard loads. Then stop the local container:

```powershell
docker stop placement-portal
```

Log in and push the image to a public Docker Hub repository:

```powershell
docker login
docker push <dockerhub-username>/student-placement-portal:1
```

## Kubernetes and NodePort

In Docker Desktop, enable Kubernetes under **Settings > Kubernetes** and wait for the cluster to report ready. Replace `your-dockerhub-username` in `deployment.yaml` with the Docker Hub account that owns the public image, then run:

```powershell
kubectl apply -f deployment.yaml
kubectl set image deployment/student-placement-portal portal=<dockerhub-username>/student-placement-portal:1
kubectl rollout status deployment/student-placement-portal --timeout=120s
kubectl get pods -l app=student-placement-portal
kubectl get service student-placement-portal
```

Both Pods should show `Running` and `READY 1/1`. Open <http://localhost:30080> to verify the app through the assigned NodePort. The NodePort is fixed at `30080` in the manifest.

## Jenkins setup

Use a Jenkins agent with Docker Engine, `kubectl`, `curl`, and access to the Docker Desktop Kubernetes API. Configure these Jenkins credentials:

- **Docker Hub:** credential ID `dockerhub-credentials`, kind **Username with password**. Use a Docker Hub access token as the password.
- **Kubernetes:** credential ID `placement-kubeconfig`, kind **Secret file**. Upload a kubeconfig for the Docker Desktop cluster and verify it works from the Jenkins agent.

Create a Pipeline job pointing at this Git repository and its `Jenkinsfile`. Ensure the Jenkins agent can access the Docker daemon and the kubeconfig has permission to manage the `student-placement-portal` Deployment and Service. The pipeline tags images with the Jenkins build number, pushes to `docker.io/<credential-username>/student-placement-portal`, substitutes that exact versioned image into the Deployment manifest before applying it, waits up to 120 seconds, and checks the served page. Applying the candidate image as a single Deployment revision ensures rollback restores the previous release tag.

## Exercise automatic rollback

Run the Jenkins job once with the default `SIMULATE_FAULTY_RELEASE=false` to establish a healthy stable release. Run it again with `SIMULATE_FAULTY_RELEASE=true`. That build deliberately omits `/healthz`; the replacement Pods fail readiness, the rollout times out, and Jenkins runs `kubectl rollout undo` to restore the previous revision. The exercise build is marked failed after the rollback so the failed release is visible in Jenkins history.

Confirm recovery from a terminal with cluster access:

```powershell
kubectl rollout history deployment/student-placement-portal
kubectl rollout status deployment/student-placement-portal --timeout=120s
kubectl get pods -l app=student-placement-portal
kubectl get service student-placement-portal
```

Both Pods should be `Running` and `READY 1/1`. Refresh <http://localhost:30080>; the portal should still serve the prior stable release. A subsequent normal Jenkins run publishes and deploys the next healthy build-number tag.