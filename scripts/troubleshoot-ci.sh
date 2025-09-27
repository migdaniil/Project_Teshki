#!/bin/bash
# troubleshoot-ci.sh - Диагностический инструмент для CI/CD проблем

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Переменные
CONFIG_FILE=".ci-config.yaml"
TEMP_FILE="/tmp/cicd-diagnostic.txt"
ISSUES=0

# Функции проверок
check_config_exists() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ MISSING: $CONFIG_FILE not found${NC}"
        echo "   Solution: Run ./scripts/create-ci-config.sh to generate it"
        ((ISSUES++))
        return 1
    else
        echo -e "${GREEN}✅ FOUND: $CONFIG_FILE${NC}"
        return 0
    fi
}

check_yaml_syntax() {
    if ! python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
        echo -e "${RED}❌ ERROR: Invalid YAML syntax in $CONFIG_FILE${NC}"
        echo "   Solution: Check YAML syntax at https://yamllint.com/"
        ((ISSUES++))
        return 1
    else
        echo -e "${GREEN}✅ VALID: YAML syntax is correct${NC}"
        return 0
    fi
}

check_required_fields() {
    local config=$(cat $CONFIG_FILE)
    
    if ! echo "$config" | grep -q "language:"; then
        echo -e "${RED}❌ MISSING: 'language' field in config${NC}"
        ((ISSUES++))
    else
        local lang=$(echo "$config" | grep "language:" | awk '{print $2}' | tr -d '"')
        echo -e "${GREEN}✅ FOUND: language = $lang${NC}"
    fi
    
    if ! echo "$config" | grep -q "name:"; then
        echo -e "${YELLOW}⚠️  WARNING: 'name' field is recommended${NC}"
    fi
}

check_project_structure() {
    local config=$(cat $CONFIG_FILE)
    local lang=$(echo "$config" | grep "language:" | awk '{print $2}' | tr -d '"')
    
    case $lang in
        "java")
            if [ ! -f "pom.xml" ] && [ ! -f "build.gradle" ]; then
                echo -e "${RED}❌ STRUCTURE: Java project but no build file found${NC}"
                ((ISSUES++))
            else
                echo -e "${GREEN}✅ STRUCTURE: Java build file found${NC}"
            fi
            ;;
        "python")
            if [ ! -f "requirements.txt" ] && [ ! -f "setup.py" ] && [ ! -f "Pipfile" ]; then
                echo -e "${YELLOW}⚠️  STRUCTURE: Python project but no dependencies file${NC}"
            else
                echo -e "${GREEN}✅ STRUCTURE: Python dependencies file found${NC}"
            fi
            ;;
        "javascript")
            if [ ! -f "package.json" ]; then
                echo -e "${RED}❌ STRUCTURE: JavaScript project but no package.json${NC}"
                ((ISSUES++))
            else
                echo -e "${GREEN}✅ STRUCTURE: package.json found${NC}"
            fi
            ;;
    esac
}

check_dockerfile() {
    local config=$(cat $CONFIG_FILE)
    local docker_enabled=$(echo "$config" | grep "enabled:" | head -1 | awk '{print $2}' | tr -d '"')
    
    if [ "$docker_enabled" = "true" ] || [ "$docker_enabled" = "yes" ]; then
        if [ ! -f "Dockerfile" ]; then
            echo -e "${RED}❌ DOCKER: docker.enabled is true but no Dockerfile found${NC}"
            ((ISSUES++))
        else
            echo -e "${GREEN}✅ DOCKER: Dockerfile found${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  DOCKER: Docker build disabled${NC}"
    fi
}

check_github_workflow() {
    if [ ! -d ".github/workflows" ]; then
        echo -e "${YELLOW}⚠️  GITHUB: No .github/workflows directory${NC}"
        echo "   Note: Universal pipeline will be triggered from framework repository"
    else
        echo -e "${GREEN}✅ GITHUB: Workflows directory found${NC}"
    fi
}

# Главная функция
main() {
    echo -e "${BLUE}🔧 CI/CD Troubleshooting Tool${NC}"
    echo "=========================================="
    echo ""
    
    check_config_exists
    if [ $? -eq 0 ]; then
        check_yaml_syntax
        check_required_fields
        check_project_structure
        check_dockerfile
    fi
    check_github_workflow
    
    echo ""
    echo "=========================================="
    
    if [ $ISSUES -eq 0 ]; then
        echo -e "${GREEN}🎉 All checks passed! Your CI/CD configuration looks good.${NC}"
        echo ""
        echo -e "${GREEN}🚀 Next: Push your code to trigger the pipeline!${NC}"
    else
        echo -e "${RED}❌ Found $ISSUES issue(s) that need attention${NC}"
        echo ""
        echo -e "${YELLOW}📚 Solutions:${NC}"
        echo "1. Review the errors above"
        echo "2. Check documentation: docs/troubleshooting.md"
        echo "3. Run: ./scripts/create-ci-config.sh (to regenerate config)"
        exit 1
    fi
}

# Запуск
main
