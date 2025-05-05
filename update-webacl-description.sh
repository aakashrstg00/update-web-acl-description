#!/bin/bash

# --- Configuration ---
WEB_ACL_ARN="$1"
NEW_DESCRIPTION="$2"

# --- Argument Validation ---
if [ -z "$WEB_ACL_ARN" ] || [ -z "$NEW_DESCRIPTION" ]; then
  echo "Error: Missing arguments."
  echo "Usage: $0 <WEB_ACL_ARN> <NEW_DESCRIPTION>"
  return
fi

# Validate ARN format
if [[ ! "$WEB_ACL_ARN" =~ ^arn:aws:wafv2:[^:]+:[^:]+:[^/]+/webacl/[^/]+/[^/]+$ ]]; then
  echo "Error: Invalid ARN format."
  echo "Expected format: arn:aws:wafv2:REGION:ACCOUNT_ID:SCOPE/webacl/NAME/ID"
  return
fi

# Extract components from ARN
REGION=$(echo "$WEB_ACL_ARN" | cut -d ':' -f 4)
SCOPE=$(echo "$WEB_ACL_ARN" | cut -d ':' -f 6 | cut -d '/' -f 1 | tr '[:lower:]' '[:upper:]')
WEB_ACL_NAME=$(echo "$WEB_ACL_ARN" | cut -d '/' -f 3)
WEB_ACL_ID=$(echo "$WEB_ACL_ARN" | cut -d '/' -f 4)

echo "Parsed ARN:"
echo "  Region: ${REGION}"
echo "  Scope: ${SCOPE}"
echo "  Name: ${WEB_ACL_NAME}"
echo "  ID: ${WEB_ACL_ID}"
echo "----------------------------------------"

# --- Get Web ACL Details ---
WEB_ACL_DETAILS=$(aws wafv2 get-web-acl \
  --name "${WEB_ACL_NAME}" \
  --scope "${SCOPE}" \
  --id "${WEB_ACL_ID}" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
  echo "Error retrieving Web ACL details:"
  echo "${WEB_ACL_DETAILS}"
  return
fi

# Extract required fields using jq
LOCK_TOKEN=$(echo "${WEB_ACL_DETAILS}" | jq -r '.LockToken')
if [ -z "${LOCK_TOKEN}" ]; then
  echo "Error: Could not extract LockToken."
  return
fi

# Extract optional fields
extract_optional_field() {
  local field_name="$1"
  local field_value
  field_value=$(echo "${WEB_ACL_DETAILS}" | jq ".WebACL.${field_name}")
  if [ "$field_value" != "null" ] && [ "$field_value" != "{}" ] && [ "$field_value" != "[]" ]; then
    echo "$field_value"
  else
    echo ""
  fi
}

DEFAULT_ACTION=$(echo "${WEB_ACL_DETAILS}" | jq '.WebACL.DefaultAction')
RULES=$(echo "${WEB_ACL_DETAILS}" | jq '.WebACL.Rules')
VISIBILITY_CONFIG=$(echo "${WEB_ACL_DETAILS}" | jq '.WebACL.VisibilityConfig')
TOKEN_DOMAINS=$(extract_optional_field "TokenDomains")
CAPTCHA_CONFIG=$(extract_optional_field "CaptchaConfig")
CHALLENGE_CONFIG=$(extract_optional_field "ChallengeConfig")
ASSOCIATION_CONFIG=$(extract_optional_field "AssociationConfig")
CUSTOM_RESPONSE_BODIES=$(extract_optional_field "CustomResponseBodies")

# --- Update Web ACL ---
echo "Updating Web ACL: ${WEB_ACL_NAME}..."

aws wafv2 update-web-acl \
  --name "${WEB_ACL_NAME}" \
  --scope "${SCOPE}" \
  --id "${WEB_ACL_ID}" \
  --default-action "${DEFAULT_ACTION}" \
  --description "${NEW_DESCRIPTION}" \
  --rules "${RULES}" \
  --visibility-config "${VISIBILITY_CONFIG}" \
  --lock-token "${LOCK_TOKEN}" \
  ${TOKEN_DOMAINS:+--token-domains "${TOKEN_DOMAINS}"} \
  ${CAPTCHA_CONFIG:+--captcha-config "${CAPTCHA_CONFIG}"} \
  ${CHALLENGE_CONFIG:+--challenge-config "${CHALLENGE_CONFIG}"} \
  ${ASSOCIATION_CONFIG:+--association-config "${ASSOCIATION_CONFIG}"} \
  ${CUSTOM_RESPONSE_BODIES:+--custom-response-bodies "${CUSTOM_RESPONSE_BODIES}"} \
  --output json

if [ $? -ne 0 ]; then
  echo "Error updating Web ACL."
  return
fi

echo "Web ACL updated successfully!"
