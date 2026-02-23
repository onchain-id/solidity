#!/bin/bash

FAIL=0

echo "Generating coverage report..."
COVERAGE_OUTPUT=$(forge coverage --no-match-coverage "(test|script|dependencies)" --report summary)

# Display the coverage report
echo "=== Coverage Report ==="
echo "$COVERAGE_OUTPUT"
echo "======================="

TOTAL_LINE=$(echo "$COVERAGE_OUTPUT" | grep "| Total.*|")

if [ -z "$TOTAL_LINE" ]; then
    echo "❌ Could not find Total coverage line"
    exit 1
fi

LINE_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $3}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')
STMT_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $4}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')
BRANCH_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $5}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')
FUNC_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $6}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')

if [ "$(echo "$LINE_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Line coverage ($LINE_COV%) is below 100%"
    FAIL=1
fi

if [ "$(echo "$STMT_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Statement coverage ($STMT_COV%) is below 100%"
    FAIL=1
fi

if [ "$(echo "$BRANCH_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Branch coverage ($BRANCH_COV%) is below 100%"
    FAIL=1
fi

if [ "$(echo "$FUNC_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Function coverage ($FUNC_COV%) is below 100%"
    FAIL=1
fi

if [ $FAIL = 1 ]; then
    echo ""
    echo "Coverage check failed! All coverage metrics must be 100%"
    exit 1
else
    echo "✅ Coverage requirements met!"
fi
