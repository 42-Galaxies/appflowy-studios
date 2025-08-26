# Technical PRD: Milestone 1 - Foundation & Authentication

## 1. Overview

This document provides a detailed, actionable guide for completing Milestone 1. Each section outlines a specific task with a clear objective, a verifiable outcome, implementation steps including code snippets, and links for further research.

**Reference:** [Main Roadmap](../roadmap.md)

---

## Task T1.1: GCP Project Setup [task-id: T1.1]

*   **Objective:** To create and configure a new, dedicated Google Cloud Platform project to house all resources for AppFlowy-Studios.
*   **Outcome:** A GCP project is created, linked to billing, and has all necessary APIs enabled. The project ID is exported as an environment variable for subsequent commands.

*   **Implementation Steps:**

    1.  **Create the project:**
        ```bash
        gcloud projects create appflowy-studios-prod --name="AppFlowy Studios Production"
        ```
        *   **Documentation:** [gcloud projects create](https://cloud.google.com/sdk/gcloud/reference/projects/create)

    2.  **Set the project for the current session:**
        ```bash
        export PROJECT_ID="appflowy-studios-prod"
        gcloud config set project $PROJECT_ID
        ```

    3.  **Link to a billing account:**
        *First, list your available billing accounts:*
        ```bash
        gcloud beta billing accounts list
        ```
        *Then, link the project to your chosen billing account (replace `BILLING_ACCOUNT_ID`):*
        ```bash
        gcloud beta billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
        ```
        *   **Documentation:** [gcloud beta billing projects link](https://cloud.google.com/sdk/gcloud/reference/beta/billing/projects/link)

    4.  **Enable required APIs:**
        ```bash
        gcloud services enable compute.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com
        ```
        *   **Documentation:** [gcloud services enable](https://cloud.google.com/sdk/gcloud/reference/services/enable)

---

--- 

## Task T1.3: Configure Google Workspace Authentication [task-id: T1.3]

*   **Objective:** To configure the AppFlowy-Cloud instance to use Google Workspace for authentication.
*   **Outcome:** An `.env` file is created with the necessary credentials to enable Google authentication, and the `docker-compose.yml` is configured to use it.

*   **Implementation Steps:**

    1.  **Create a Google OAuth 2.0 Client ID:**
        *   Follow the Google Cloud documentation to create an OAuth 2.0 Client ID for a web application.
        *   Set the authorized redirect URI to `https://workspace.42galaxies.studio/api/auth/callback`.
        *   **Documentation:** [Setting up OAuth 2.0](https://support.google.com/cloud/answer/6158849)

    2.  **Create the `.env` file:**
        *   Create a file named `.env` in the root of the AppFlowy-Cloud project.
        *   Add the following environment variables to the file, replacing the values with your own:
            ```
            GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
            GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID="your-google-client-id"
            GOTRUE_EXTERNAL_GOOGLE_SECRET="your-google-client-secret"
            GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI="https://workspace.42galaxies.studio/api/auth/callback"
            ```
        *   **Documentation:** [AppFlowy-Cloud README](https://github.com/AppFlowy-IO/AppFlowy-Cloud/blob/main/README.md)

    3.  **Update `docker-compose.yml`:**
        *   Ensure that the `docker-compose.yml` file is configured to use the `.env` file.
        *   The `appflowy-cloud` service should have the `env_file` property set to `./.env`.

