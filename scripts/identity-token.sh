#!/bin/bash
#
# Get ID token and test ODIN Protocol endpoints
# Usage: ./scripts/identity-token.sh <BASE_URL>
# Example: ./scripts/identity-token.sh "https://odin-gateway-xyz.run.app"

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <BASE_URL>"
    echo "Example: $0 https://odin-gateway-xyz.run.app"
    exit 1
fi

BASE_URL="$1"

echo "=== ODIN Protocol Endpoint Testing ==="
echo "Base URL: $BASE_URL"
echo ""

# Get ID token
echo "Getting ID token..."
if ID_TOKEN=$(gcloud auth print-identity-token 2>/dev/null); then
    echo "✅ ID token obtained"
    echo "Token: ${ID_TOKEN:0:50}..."
else
    echo "❌ Failed to get ID token"
    echo "Run: gcloud auth login"
    exit 1
fi

echo ""
echo "TOKEN=$ID_TOKEN"
echo ""

# Test 1: Health check
echo "🩺 Testing health endpoint..."
if RESPONSE=$(curl -s -H "Authorization: Bearer $ID_TOKEN" \
              -H "Content-Type: application/json" \
              -w "%{http_code}" \
              "$BASE_URL/health"); then
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Health check passed"
        echo "   Response: $BODY"
    else
        echo "⚠️  Health check returned HTTP $HTTP_CODE: $BODY"
    fi
else
    echo "❌ Health check failed"
fi

# Test 2: Discovery endpoint
echo ""
echo "🔍 Testing discovery endpoint..."
if RESPONSE=$(curl -s -H "Authorization: Bearer $ID_TOKEN" \
              -H "Content-Type: application/json" \
              -w "%{http_code}" \
              "$BASE_URL/.well-known/odin/discovery.json"); then
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Discovery endpoint working"
        echo "   Response: $BODY"
    else
        echo "⚠️  Discovery returned HTTP $HTTP_CODE: $BODY"
    fi
else
    echo "❌ Discovery failed"
fi

# Test 3: JWKS endpoint  
echo ""
echo "🔑 Testing JWKS endpoint..."
if RESPONSE=$(curl -s -H "Authorization: Bearer $ID_TOKEN" \
              -H "Content-Type: application/json" \
              -w "%{http_code}" \
              "$BASE_URL/.well-known/jwks.json"); then
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ JWKS endpoint working"
        echo "   Response: $BODY"
    else
        echo "⚠️  JWKS returned HTTP $HTTP_CODE: $BODY"
    fi
else
    echo "❌ JWKS failed"
fi

# Test 4: Envelope endpoint (POST)
echo ""
echo "📧 Testing envelope endpoint..."

# Generate test trace ID and CID
TRACE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
PAYLOAD_CID="bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TEST_ENVELOPE=$(cat <<EOF
{
  "recipient": "test-ai-agent",
  "message": "Test message from ODIN connector validation",
  "signature": "MEUCIQDKj9kExample",
  "public_key": "MCowBQYDK2VwAyEAExample",
  "timestamp": "$TIMESTAMP"
}
EOF
)

echo "   Trace ID: $TRACE_ID"
echo "   Payload CID: $PAYLOAD_CID"

if RESPONSE=$(curl -s -X POST \
              -H "Authorization: Bearer $ID_TOKEN" \
              -H "Content-Type: application/json" \
              -H "X-ODIN-Trace-Id: $TRACE_ID" \
              -H "X-ODIN-Payload-CID: $PAYLOAD_CID" \
              -d "$TEST_ENVELOPE" \
              -w "%{http_code}" \
              "$BASE_URL/v1/envelope"); then
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" = "201" ]; then
        echo "✅ Envelope endpoint working"
        echo "   Response: $BODY"
    elif [ "$HTTP_CODE" = "400" ]; then
        echo "✅ Envelope endpoint accessible (signature validation working)"
        echo "   Expected 400 due to test signature"
    else
        echo "⚠️  Envelope returned HTTP $HTTP_CODE: $BODY"
    fi
else
    echo "❌ Envelope failed"
fi

# Test 5: Receipt hops endpoint
echo ""
echo "📋 Testing receipt hops endpoint..."
if RESPONSE=$(curl -s -H "Authorization: Bearer $ID_TOKEN" \
              -H "Content-Type: application/json" \
              -w "%{http_code}" \
              "$BASE_URL/v1/receipts/hops?trace_id=$TRACE_ID"); then
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Receipt hops endpoint working"
        echo "   Response: $BODY"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "✅ Receipt hops endpoint accessible (404 expected for test trace)"
    else
        echo "⚠️  Receipt hops returned HTTP $HTTP_CODE: $BODY"
    fi
else
    echo "❌ Receipt hops failed"
fi

echo ""
echo "=== Test Summary ==="
echo "Tested endpoints against: $BASE_URL"
echo ""
echo "Next steps:"
echo "1. Import openapi/odin-connector.yaml into Integration Connectors"
echo "2. Create a Connection with base URL: $BASE_URL" 
echo "3. Use the token above for testing in the connector UI"
echo ""
echo "Token for copy/paste:"
echo "$ID_TOKEN"
