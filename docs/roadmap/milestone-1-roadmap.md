# Detailed Roadmap: Milestone 1

This document provides a granular, step-by-step implementation plan for Milestone 1.

## Task T1.1: GCP Project Setup

1.  **[ ]** Go to the Google Cloud Console.
2.  **[ ]** Create a new project named `appflowy-studios-prod`.
3.  **[ ]** Link the project to the organization's billing account.
4.  **[ ]** In the "Billing" section, create a new budget and set a monthly amount.
5.  **[ ]** Configure budget alerts for 50%, 90%, and 100% of the budget.
6.  **[ ]** In the "APIs & Services" dashboard, enable the Kubernetes Engine, Cloud SQL Admin, Cloud Storage, and Cloud Build APIs.

## Task T1.2: Infrastructure as Code (IaC) with Terraform

1.  **[ ]** Create a new private Git repository named `appflowy-infra`.
2.  **[ ]** Initialize a new Terraform project in the repository.
3.  **[ ]** Create a `backend.tf` file to configure the GCS backend for Terraform state.
4.  **[ ]** Create a `providers.tf` file to define the Google Cloud provider.
5.  **[ ]** In a `main.tf` file, define the GKE cluster resource.
6.  **[ ]** In a `database.tf` file, define the Cloud SQL for PostgreSQL instance and a Secret Manager secret for the password.
7.  **[ ]** In a `storage.tf` file, define the GCS bucket.
8.  **[ ]** Run `terraform init`, `terraform plan`, and `terraform apply` to create the infrastructure.

## Task T1.3: Authentication Service

1.  **[ ]** Create a new private Git repository named `appflowy-auth-service`.
2.  **[ ]** Initialize a new Go module.
3.  **[ ]** Add the Gin framework as a dependency (`go get github.com/gin-gonic/gin`).
4.  **[ ]** Create a `main.go` file.
5.  **[ ]** In `main.go`, set up a basic Gin router with a single endpoint: `POST /auth/google/login`.
6.  **[ ]** Create a `Dockerfile` that builds the Go application and creates a minimal container image.

## Task T1.4: Google Workspace Integration

1.  **[ ]** In the GCP console, navigate to "APIs & Services" -> "Credentials".
2.  **[ ]** Create a new OAuth 2.0 Client ID for a web application.
3.  **[ ]** Add the authorized redirect URIs for the Authentication Service.
4.  **[ ]** In the Authentication Service, add the `golang.org/x/oauth2` and `google.golang.org/api/oauth2/v2` packages.
5.  **[ ]** Implement the OAuth 2.0 flow to exchange an authorization code for a token.
6.  **[ ]** Use the token to get the user's profile information (specifically their email).
7.  **[ ]** Add logic to check if the user's email domain is `42galaxies.studio`.
8.  **[ ]** Add a JWT library (e.g., `github.com/golang-jwt/jwt`) and implement JWT generation.
9.  **[ ]** If the user is valid, return a signed JWT in the API response.

## Task T1.5: Basic CI/CD Pipeline

1.  **[ ]** In the `appflowy-auth-service` repository, create a `cloudbuild.yaml` file.
2.  **[ ]** Define the build steps in the YAML file (test, build, dockerize, push).
3.  **[ ]** In the GCP console, navigate to Cloud Build and create a new trigger.
4.  **[ ]** Connect the trigger to the `appflowy-auth-service` repository.
5.  **[ ]** Configure the trigger to execute on pushes to the `main` branch.
6.  **[ ]** Push a change to the repository to test the trigger.
