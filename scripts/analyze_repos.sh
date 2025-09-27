#!/bin/bash
# analyze_repos.sh - Анализ репозиториев для миграции на универсальный CI/CD

set -e

# Конфигурация
GITHUB_ORG="your-organization"
OUTPUT_FILE="repository-analysis-$(date +%Y%m%d).csv"
TEMP_DIR="temp_analysis"

# Создаем заголовок CSV
echo "Repository,Language,BuildTool,HasDockerfile,HasCICD,Structure,ReadyForMigration,Issues" > $OUTPUT_FILE

# Функция для анализа одного репозитория
analyze_repository() {
    local repo=$1
    echo "🔍 Analyzing $repo..."
    
    # Временное клонирование
    git clone -q --depth 1 "https://github.com/$GITHUB_ORG/$repo.git" "$TEMP_DIR/$repo" 2>/dev/null || return
    
    cd "$TEMP_DIR/$repo"
    
    # Определяем язык и инструменты
    local language="unknown"
    local build_tool="unknown"
    local has_dockerfile="no"
    local has_cicd="no"
    local structure="custom"
    local ready="no"
    local issues=""
    
    # Определяем язык по файлам
    if [ -f "pom.xml" ]; then
        language="java"
        build_tool="maven"
    elif [ -f "build.gradle" ]; then
        language="java" 
        build_tool="gradle"
    elif [ -f "package.json" ]; then
        language="javascript"
        build_tool="npm"
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
        language="python"
        build_tool="pip"
    elif [ -f "go.mod" ]; then
        language="go"
        build_tool="go"
    fi
    
    # Проверяем Dockerfile
    if [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
        has_dockerfile="yes"
    fi
    
    # Проверяем наличие CI/CD
    if [ -d ".github/workflows" ] || [ -f ".gitlab-ci.yml" ] || [ -f "Jenkinsfile" ]; then
        has_cicd="yes"
    fi
    
    # Проверяем структуру проекта
    case $language in
        "java")
            if [ -d "src/main/java" ] && [ -d "src/test/java" ]; then
                structure="standard"
                ready="yes"
            else
                issues="Non-standard Java structure"
            fi
            ;;
        "python")
            if [ -d "src" ] || [ -f "setup.py" ]; then
                structure="standard"
                ready="yes"
            else
                issues="Flat Python structure"
            fi
            ;;
        "javascript")
            if [ -d "src" ] || [ -d "lib" ]; then
                structure="standard" 
                ready="yes"
            else
                issues="Simple JS structure"
            fi
            ;;
        *)
            issues="Unsupported language or cannot detect"
            ;;
    esac
    
    # Если есть существующий CI/CD, отмечаем необходимость миграции
    if [ "$has_cicd" = "yes" ]; then
        issues="${issues} Needs migration from existing CI/CD"
        ready="no"
    fi
    
    # Записываем результат
    echo "$repo,$language,$build_tool,$has_dockerfile,$has_cicd,$structure,$ready,$issues" >> ../../$OUTPUT_FILE
    
    cd ../..
    rm -rf "$TEMP_DIR/$repo"
}

# Основной цикл
mkdir -p $TEMP_DIR

# Получаем список репозиториев (упрощенная версия)
REPOS=("auth-service" "user-api" "frontend-app" "payment-service" "legacy-system")

for repo in "${REPOS[@]}"; do
    analyze_repository $repo || echo "$repo,error,error,error,error,error,no,Clone failed" >> $OUTPUT_FILE
done

# Генерируем отчет
echo ""
echo "📊 Analysis Complete!"
echo "📁 Results saved to: $OUTPUT_FILE"
echo ""
echo "📈 Summary:"
echo "Total repositories: ${#REPOS[@]}"
echo "Ready for migration: $(grep -c ",yes," $OUTPUT_FILE || true)"
echo "Need attention: $(grep -c ",no," $OUTPUT_FILE || true)"

# Очистка
rm -rf $TEMP_DIR
