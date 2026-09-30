#!/bin/bash
# Query TYPO3 Forge project metadata via Redmine REST API
#
# Usage:
# 1. Get your API key from https://forge.typo3.org/my/account
# 2. Set environment variable: export FORGE_API_KEY="your-key-here"
# 3. Run: ./scripts/query-forge-metadata.sh [categories|trackers|all]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for API key
if [ -z "$FORGE_API_KEY" ]; then
    echo -e "${RED}Error: FORGE_API_KEY environment variable not set${NC}"
    echo ""
    echo "Get your API key from: https://forge.typo3.org/my/account"
    echo "Then set it: export FORGE_API_KEY=\"your-key-here\""
    exit 1
fi

# Check for required tools
for tool in curl jq; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}Error: $tool is required but not installed${NC}"
        exit 1
    fi
done

# Parse arguments
QUERY_TYPE=${1:-all}

# Fetch project metadata
echo -e "${YELLOW}Fetching TYPO3 Core project metadata...${NC}"
echo ""

RESPONSE=$(curl -s \
    -H "X-Redmine-API-Key: $FORGE_API_KEY" \
    https://forge.typo3.org/projects/typo3cms-core.json)

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo -e "${RED}Error querying Forge:${NC}"
    echo "$RESPONSE" | jq -r '.errors[]'
    exit 1
fi

# Display trackers
if [[ "$QUERY_TYPE" == "trackers" || "$QUERY_TYPE" == "all" ]]; then
    echo -e "${GREEN}=== Trackers ===${NC}"
    echo ""
    echo "$RESPONSE" | jq -r '.project.trackers[] | "\(.id)\t\(.name)"' | \
        awk -F'\t' '{printf "  %-4s %s\n", $1, $2}'
    echo ""
fi

# Display categories
if [[ "$QUERY_TYPE" == "categories" || "$QUERY_TYPE" == "all" ]]; then
    echo -e "${GREEN}=== Issue Categories ===${NC}"
    echo ""
    echo "$RESPONSE" | jq -r '.project.issue_categories[] | "\(.id)\t\(.name)"' | \
        awk -F'\t' '{printf "  %-6s %s\n", $1, $2}'
    echo ""
fi

# Display usage examples
if [[ "$QUERY_TYPE" == "all" ]]; then
    echo -e "${BLUE}=== Usage Examples ===${NC}"
    echo ""
    echo "Create bug in Backend API category:"
    # Quoted delimiter: the example is printed verbatim, $FORGE_API_KEY included.
    cat <<'EXAMPLE'
  curl -X POST \
    -H "Content-Type: application/json" \
    -H "X-Redmine-API-Key: $FORGE_API_KEY" \
    -d '{
      "issue": {
        "project_id": "typo3cms-core",
        "subject": "Issue title",
        "description": "Description",
        "tracker_id": 1,
        "category_id": 971,
        "priority_id": 4,
        "custom_fields": [{"id": 4, "value": "13"}]
      }
    }' \
    https://forge.typo3.org/issues.json
EXAMPLE
    echo ""
    echo "Or use the interactive script:"
    echo "  ./scripts/create-forge-issue.sh"
    echo ""
fi

# Save to file if requested
if [[ "$2" == "--save" ]]; then
    OUTPUT_FILE="forge-metadata-$(date +%Y%m%d).json"
    echo "$RESPONSE" > "$OUTPUT_FILE"
    echo -e "${GREEN}Metadata saved to: $OUTPUT_FILE${NC}"
fi
