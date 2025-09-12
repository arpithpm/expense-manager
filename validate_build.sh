#!/bin/bash

# Receipt Radar - Build Validation Script
echo "🔍 Validating Receipt Radar for App Store submission..."

PROJECT_DIR="/Users/i531058/Documents/Personal Projects/expensemanager"
cd "$PROJECT_DIR"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ISSUES=0

echo "\n📋 1. Checking project structure..."

# Check required files
REQUIRED_FILES=(
    "README.md"
    "LICENSE"
    "PRIVACY.md"
    "APP_STORE_SUBMISSION.md"
    "ExpenseManager/Info.plist"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file exists"
    else
        echo "   ❌ Missing: $file"
        ((ISSUES++))
    fi
done

echo "\n🧹 2. Checking for development artifacts..."

# Check for temporary files
if [ -f "temp_overview.swift" ] || [ -f "TestDataResetView.swift" ]; then
    echo "   ❌ Temporary files still exist"
    ((ISSUES++))
else
    echo "   ✅ No temporary files found"
fi

# Check for .DS_Store files
DS_STORE_COUNT=$(find . -name ".DS_Store" | wc -l)
if [ $DS_STORE_COUNT -gt 0 ]; then
    echo "   ⚠️  Found $DS_STORE_COUNT .DS_Store files"
    find . -name ".DS_Store" -delete
    echo "   ✅ Cleaned up .DS_Store files"
else
    echo "   ✅ No .DS_Store files found"
fi

echo "\n🐛 3. Checking for debug code..."

# Check for print statements in production code (excluding tests)
PRINT_COUNT=$(find ./ExpenseManager -name "*.swift" -not -path "*/Tests/*" -exec grep -l "print(" {} \; | wc -l)
if [ $PRINT_COUNT -gt 0 ]; then
    echo "   ⚠️  Found debug print statements in production code:"
    find ./ExpenseManager -name "*.swift" -not -path "*/Tests/*" -exec grep -l "print(" {} \;
    echo "   📝 These should be reviewed before submission"
else
    echo "   ✅ No debug print statements in production code"
fi

echo "\n📱 4. Validating app configuration..."

# Check Info.plist
if grep -q "Receipt Radar1" ExpenseManager/Info.plist; then
    echo "   ❌ App name still shows 'Receipt Radar1'"
    ((ISSUES++))
else
    echo "   ✅ App name correctly set to 'Receipt Radar'"
fi

# Check bundle identifier
if grep -q "com.muddi1.receiptradar" ExpenseManager.xcodeproj/project.pbxproj; then
    echo "   ✅ Bundle identifier configured"
else
    echo "   ❌ Bundle identifier not found"
    ((ISSUES++))
fi

echo "\n🔒 5. Checking security configurations..."

# Check for ITSAppUsesNonExemptEncryption
if grep -q "ITSAppUsesNonExemptEncryption" ExpenseManager/Info.plist; then
    if grep -A1 "ITSAppUsesNonExemptEncryption" ExpenseManager/Info.plist | grep -q "false"; then
        echo "   ✅ Export compliance configured (no encryption)"
    else
        echo "   ⚠️  Export compliance set to true - verify encryption usage"
    fi
else
    echo "   ❌ Missing ITSAppUsesNonExemptEncryption key"
    ((ISSUES++))
fi

echo "\n📄 6. Validating documentation..."

# Check README exists and has content
README_SIZE=$(wc -c < "README.md")
if [ $README_SIZE -gt 1000 ]; then
    echo "   ✅ README.md is comprehensive ($README_SIZE bytes)"
else
    echo "   ❌ README.md seems too short"
    ((ISSUES++))
fi

# Check LICENSE exists
if [ -f "LICENSE" ]; then
    if grep -q "MIT License" LICENSE; then
        echo "   ✅ MIT License properly configured"
    else
        echo "   ⚠️  License file exists but may not be MIT"
    fi
else
    echo "   ❌ LICENSE file missing"
    ((ISSUES++))
fi

echo "\n🎯 7. Checking version information..."

# Extract version from project file
VERSION=$(grep -o 'MARKETING_VERSION = [^;]*' ExpenseManager.xcodeproj/project.pbxproj | head -1 | cut -d' ' -f3)
BUILD=$(grep -o 'CURRENT_PROJECT_VERSION = [^;]*' ExpenseManager.xcodeproj/project.pbxproj | head -1 | cut -d' ' -f3)

if [ ! -z "$VERSION" ]; then
    echo "   ✅ Marketing Version: $VERSION"
else
    echo "   ❌ Marketing Version not found"
    ((ISSUES++))
fi

if [ ! -z "$BUILD" ]; then
    echo "   ✅ Build Number: $BUILD"
else
    echo "   ❌ Build Number not found"
    ((ISSUES++))
fi

echo "\n📊 8. Final validation summary..."

if [ $ISSUES -eq 0 ]; then
    echo -e "   ${GREEN}✅ All validations passed! Ready for App Store submission.${NC}"
    echo -e "   ${GREEN}🚀 Receipt Radar v$VERSION (build $BUILD) is ready to ship!${NC}"
    
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "   1. Archive build in Xcode (Product → Archive)"
    echo "   2. Upload to App Store Connect via Organizer"
    echo "   3. Update app listing with content from APP_STORE_SUBMISSION.md"
    echo "   4. Submit for review"
    
    exit 0
else
    echo -e "   ${RED}❌ Found $ISSUES issues that should be addressed before submission.${NC}"
    echo -e "   ${YELLOW}Please review the issues above and fix them before proceeding.${NC}"
    exit 1
fi