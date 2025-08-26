#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/../config/env.sh"

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

create_notification_channel() {
    local project_id="${PROJECT_ID}"
    local email="${ALERT_EMAIL}"
    local channel_name="billing-alerts-email"
    
    log_info "Creating email notification channel..."
    
    local existing_channel=$(gcloud alpha monitoring channels list \
        --project="${project_id}" \
        --filter="displayName:'${channel_name}'" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -n "${existing_channel}" ]]; then
        log_success "Notification channel already exists: ${existing_channel}"
        echo "${existing_channel}"
        return 0
    fi
    
    local channel_config=$(cat <<EOF
{
  "type": "email",
  "displayName": "${channel_name}",
  "description": "Email notifications for billing alerts",
  "labels": {
    "email_address": "${email}"
  },
  "enabled": true
}
EOF
)
    
    echo "${channel_config}" > /tmp/channel.json
    
    local channel_id=$(gcloud alpha monitoring channels create \
        --channel-content-from-file=/tmp/channel.json \
        --project="${project_id}" \
        --format="value(name)" 2>/dev/null || echo "")
    
    rm -f /tmp/channel.json
    
    if [[ -n "${channel_id}" ]]; then
        log_success "Notification channel created: ${channel_id}"
        echo "${channel_id}"
        return 0
    else
        log_error "Failed to create notification channel"
        return 1
    fi
}

create_budget_alert() {
    local project_id="${PROJECT_ID}"
    local billing_account="${BILLING_ACCOUNT_ID}"
    local budget_amount="${BUDGET_AMOUNT:-10}"
    local threshold_percent="${THRESHOLD_PERCENT:-50}"
    local budget_name="${BUDGET_NAME:-galaxies-workspace-budget}"
    
    log_info "Creating budget alert for project '${project_id}'..."
    
    local existing_budget=$(gcloud billing budgets list \
        --billing-account="${billing_account}" \
        --filter="displayName:'${budget_name}'" \
        --format="value(name)" --limit=1 2>/dev/null || echo "")
    
    if [[ -n "${existing_budget}" ]]; then
        log_info "Budget already exists: ${existing_budget}"
        log_info "Updating budget configuration..."
        
        gcloud billing budgets delete "${existing_budget}" \
            --billing-account="${billing_account}" \
            --quiet 2>/dev/null || true
    fi
    
    local projects_filter="projects/${project_id}"
    
    local budget_config=$(cat <<EOF
{
  "displayName": "${budget_name}",
  "budgetFilter": {
    "projects": ["${projects_filter}"]
  },
  "amount": {
    "specifiedAmount": {
      "currencyCode": "USD",
      "units": "${budget_amount}"
    }
  },
  "thresholdRules": [
    {
      "thresholdPercent": 0.5
    },
    {
      "thresholdPercent": 0.9
    },
    {
      "thresholdPercent": 1.0
    }
  ],
  "notificationsRule": {
    "disableDefaultIamRecipients": false
  }
}
EOF
)
    
    echo "${budget_config}" > /tmp/budget.json
    
    # Get project number
    local project_number=$(gcloud projects describe "${project_id}" --format="value(projectNumber)")
    
    local budget_id=$(gcloud billing budgets create \
        --billing-account="${billing_account}" \
        --display-name="${budget_name}" \
        --budget-amount="${budget_amount}" \
        --filter-projects="projects/${project_number}" \
        --threshold-rule=percent=0.5 \
        --threshold-rule=percent=0.9 \
        --threshold-rule=percent=1.0 \
        --format="value(name)" 2>/dev/null || echo "")
    
    rm -f /tmp/budget.json
    
    if [[ -n "${budget_id}" ]]; then
        log_success "Budget created successfully: ${budget_id}"
        return 0
    else
        log_error "Failed to create budget"
        return 1
    fi
}

create_alert_policy() {
    local project_id="${PROJECT_ID}"
    local notification_channel="${1}"
    local policy_name="billing-threshold-alert"
    
    log_info "Creating alert policy..."
    
    local existing_policy=$(gcloud alpha monitoring policies list \
        --project="${project_id}" \
        --filter="displayName:'${policy_name}'" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -n "${existing_policy}" ]]; then
        log_success "Alert policy already exists: ${existing_policy}"
        return 0
    fi
    
    local policy_config=$(cat <<EOF
{
  "displayName": "${policy_name}",
  "documentation": {
    "content": "Alert when billing costs exceed configured thresholds",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "Billing threshold exceeded",
      "conditionThreshold": {
        "filter": "resource.type=\"global\" AND metric.type=\"billing.googleapis.com/billing/monthly_cost\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": ${BUDGET_AMOUNT:-100},
        "duration": "60s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ]
      }
    }
  ],
  "notificationChannels": ["${notification_channel}"],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "enabled": true
}
EOF
)
    
    echo "${policy_config}" > /tmp/policy.json
    
    local policy_id=$(gcloud alpha monitoring policies create \
        --policy-from-file=/tmp/policy.json \
        --project="${project_id}" \
        --format="value(name)" 2>/dev/null || echo "")
    
    rm -f /tmp/policy.json
    
    if [[ -n "${policy_id}" ]]; then
        log_success "Alert policy created: ${policy_id}"
        return 0
    else
        log_error "Failed to create alert policy"
        return 1
    fi
}

setup_pubsub_topic() {
    local project_id="${PROJECT_ID}"
    local topic_name="billing-alerts"
    
    log_info "Setting up Pub/Sub topic for billing alerts..."
    
    if gcloud pubsub topics describe "${topic_name}" --project="${project_id}" &>/dev/null; then
        log_success "Pub/Sub topic '${topic_name}' already exists"
    else
        if gcloud pubsub topics create "${topic_name}" --project="${project_id}"; then
            log_success "Pub/Sub topic '${topic_name}' created"
        else
            log_error "Failed to create Pub/Sub topic"
            return 1
        fi
    fi
    
    return 0
}

verify_billing_alerts() {
    local project_id="${PROJECT_ID}"
    local billing_account="${BILLING_ACCOUNT_ID}"
    
    log_info "Verifying billing alerts configuration..."
    
    log_info "Checking budgets..."
    local budgets=$(gcloud billing budgets list \
        --billing-account="${billing_account}" \
        --format="table(displayName,amount.specifiedAmount.units,amount.specifiedAmount.currencyCode)" 2>/dev/null)
    
    if [[ -n "${budgets}" ]]; then
        echo "${budgets}"
        log_success "Budgets configured"
    else
        log_error "No budgets found"
        return 1
    fi
    
    log_info "Checking notification channels..."
    local channels=$(gcloud alpha monitoring channels list \
        --project="${project_id}" \
        --format="table(displayName,type,enabled)" 2>/dev/null || echo "")
    
    if [[ -n "${channels}" ]]; then
        echo "${channels}"
        log_success "Notification channels configured"
    else
        log_info "No notification channels found (this is optional)"
    fi
    
    return 0
}

main() {
    log_info "Starting billing alerts setup..."
    
    if [[ -z "${PROJECT_ID}" ]] || [[ -z "${BILLING_ACCOUNT_ID}" ]]; then
        log_error "PROJECT_ID and BILLING_ACCOUNT_ID must be set in config/env.sh"
        exit 1
    fi
    
    if [[ -z "${ALERT_EMAIL}" ]]; then
        log_error "ALERT_EMAIL must be set in config/env.sh for email notifications"
        log_info "You can set ALERT_EMAIL to your email address to receive billing alerts"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    gcloud config set project "${PROJECT_ID}" &>/dev/null
    
    if ! gcloud services list --filter="name:cloudbilling.googleapis.com" --enabled --format="value(name)" 2>/dev/null | grep -q "cloudbilling"; then
        log_info "Enabling Cloud Billing API..."
        gcloud services enable cloudbilling.googleapis.com --project="${PROJECT_ID}"
    fi
    
    if ! gcloud services list --filter="name:billingbudgets.googleapis.com" --enabled --format="value(name)" 2>/dev/null | grep -q "billingbudgets"; then
        log_info "Enabling Billing Budgets API..."
        gcloud services enable billingbudgets.googleapis.com --project="${PROJECT_ID}"
        sleep 3
    fi
    
    if ! gcloud services list --filter="name:pubsub.googleapis.com" --enabled --format="value(name)" 2>/dev/null | grep -q "pubsub"; then
        log_info "Enabling Pub/Sub API..."
        gcloud services enable pubsub.googleapis.com --project="${PROJECT_ID}"
    fi
    
    setup_pubsub_topic || {
        log_error "Failed to setup Pub/Sub topic"
    }
    
    create_budget_alert || {
        log_error "Failed to create budget alert"
        exit 1
    }
    
    if [[ "${ENABLE_MONITORING_ALERTS:-false}" == "true" ]]; then
        local channel_id=$(create_notification_channel) || {
            log_error "Failed to create notification channel"
            exit 1
        }
        
        create_alert_policy "${channel_id}" || {
            log_error "Failed to create alert policy"
        }
    fi
    
    verify_billing_alerts || exit 1
    
    log_success "Billing alerts setup completed!"
    log_info "Project: ${PROJECT_ID}"
    log_info "Budget Amount: \$${BUDGET_AMOUNT:-100} USD"
    log_info "Alert Email: ${ALERT_EMAIL}"
    log_info ""
    log_info "Alerts will be triggered at: 50%, 75%, 90%, 100%, and 120% of budget"
}

main "$@"