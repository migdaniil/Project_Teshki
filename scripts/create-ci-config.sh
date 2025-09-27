#!/bin/bash
# create-ci-config.sh - Генератор конфигурации CI/CD для проекта

set -e

CONFIG_FILE=".ci-config.yaml"
BACKUP_FILE=".ci-config.yaml.backup.$(date +%Y%m%d)"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для определения типа проекта
detect_project_type() {
    echo -e "${YELLOW}🔍 Detecting project type...${NC}"
    
    if [ -f "pom.xml" ]; then
        echo "java"
    elif [ -f "build.gradle" ]; then
        echo "java" 
    elif [ -f "package.json" ]; then
        echo "javascript"
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
        echo "python"
    elif [ -f "go.mod" ]; then
        echo "go"
    else
        echo "unknown"
    fi
}

# Функция для определения структуры проекта
detect_project_structure() {
    local language=$1
    
    case $language in
        "java")
            if [ -d "src/main/java" ]; then
                echo "src/main/java"
            else
                echo "."
            fi
            ;;
        "python")
            if [ -d "src" ]; then
                echo "src"
            elif [ -d "app" ]; then
                echo "app"
            else
                echo "."
            fi
            ;;
        "javascript")
            if [ -d "src" ]; then
                echo "src"
            elif [ -d "lib" ]; then
                echo "lib"
            else
                echo "."
            fi
            ;;
        *)
            echo "."
            ;;
    esac
}

# Функция для бэкапа существующего конфига
backup_existing_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}⚠️  Existing config found. Creating backup: $BACKUP_FILE${NC}"
        cp "$CONFIG_FILE" "$BACKUP_FILE"
    fi
}

# Функция генерации конфига
generate_config() {
    local language=$1
    local project_name=$(basename $(pwd))
    local source_path=$(detect_project_structure $language)
    
    echo -e "${GREEN}🚀 Generating .ci-config.yaml for $language project${NC}"
    
    case $language in
        "java")
            cat > $CONFIG_FILE << EOF
# CI/CD Configuration for Java Project
project:
  name: "$project_name"
  language: "java"
  version: "17"
  build_tool: "$([ -f "pom.xml" ] && echo "maven" || echo "gradle")"

paths:
  source: "$source_path"
  tests: "$([ -d "src/test/java" ] && echo "src/test/java" || echo ".")"
  requirements: "$([ -f "pom.xml" ] && echo "pom.xml" || echo "build.gradle")"
  output: "target/"

commands:
  install: "$([ -f "pom.xml" ] && echo "mvn clean compile" || echo "./gradlew compileJava")"
  test: "$([ -f "pom.xml" ] && echo "mvn test" || echo "./gradlew test")"
  package: "$([ -f "pom.xml" ] && echo "mvn package -DskipTests" || echo "./gradlew build -x test")"

docker:
  enabled: true
  dockerfile: "Dockerfile"
  context: "."
  image_name: "$project_name"

deploy:
  enabled: false
  target: "kubernetes"
  environments: ["dev"]

quality:
  test_coverage: 80
  security_scan: true
EOF
            ;;
            
        "python")
            cat > $CONFIG_FILE << EOF
# CI/CD Configuration for Python Project
project:
  name: "$project_name"
  language: "python"
  version: "3.11"
  build_tool: "pip"

paths:
  source: "$source_path"
  tests: "tests"
  requirements: "requirements.txt"

commands:
  install: "pip install -r requirements.txt"
  test: "pytest tests/ -v --cov=src --cov-report=xml"
  package: "$([ -f "setup.py" ] && echo "python setup.py sdist" || echo "echo 'No packaging needed'")"

docker:
  enabled: true
  dockerfile: "Dockerfile"
  context: "."
  image_name: "$project_name"

deploy:
  enabled: false
  target: "kubernetes" 
  environments: ["dev"]

quality:
  test_coverage: 70
  security_scan: true
EOF
            ;;
            
        "javascript")
            cat > $CONFIG_FILE << EOF
# CI/CD Configuration for JavaScript Project
project:
  name: "$project_name"
  language: "javascript" 
  version: "18"
  build_tool: "npm"

paths:
  source: "$source_path"
  tests: "test"
  requirements: "package.json"

commands:
  install: "npm ci"
  test: "npm test"
  package: "npm run build"

docker:
  enabled: true
  dockerfile: "Dockerfile"
  context: "."
  image_name: "$project_name"

deploy:
  enabled: false
  target: "kubernetes"
  environments: ["dev"]

quality:
  test_coverage: 80
  security_scan: true
EOF
            ;;
            
        *)
            echo -e "${RED}❌ Unsupported project type. Please specify manually.${NC}"
            exit 1
            ;;
    esac
}

# Функция проверки Dockerfile
check_dockerfile() {
    if [ ! -f "Dockerfile" ]; then
        echo -e "${YELLOW}⚠️  No Dockerfile found. You may need to create one or set docker.enabled: false${NC}"
    fi
}

# Основная логика
echo -e "${GREEN}🎯 CI/CD Configuration Generator${NC}"
echo ""

backup_existing_config

PROJECT_TYPE=$(detect_project_type)

if [ "$PROJECT_TYPE" == "unknown" ]; then
    echo -e "${YELLOW}❓ Could not auto-detect project type.${NC}"
    read -p "Please specify language (java/python/javascript/go): " PROJECT_TYPE
fi

generate_config $PROJECT_TYPE
check_dockerfile

echo -e "${GREEN}✅ Configuration generated: $CONFIG_FILE${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Review and edit $CONFIG_FILE if needed"
echo "2. Ensure Dockerfile exists or set docker.enabled: false"
echo "3. Commit and push to trigger CI/CD pipeline"
echo ""
echo -e "${GREEN}🚀 Your project is now CI/CD ready!${NC}"
