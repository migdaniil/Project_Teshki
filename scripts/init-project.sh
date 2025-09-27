#!/bin/bash
# init-project.sh - Создание нового проекта из шаблона

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TEMPLATES_DIR="templates"

show_usage() {
    echo "Usage: $0 <template-name> <project-name> [destination]"
    echo ""
    echo "Available templates:"
    ls -1 "$TEMPLATES_DIR" | sed 's/^/  - /'
    echo ""
    echo "Examples:"
    echo "  $0 java-template user-service"
    echo "  $0 python-template data-processor ~/projects/"
}

validate_template() {
    local template=$1
    if [ ! -d "$TEMPLATES_DIR/$template" ]; then
        echo -e "${RED}❌ Template '$template' not found!${NC}"
        echo "Available templates:"
        ls -1 "$TEMPLATES_DIR"
        exit 1
    fi
}

create_project() {
    local template=$1
    local project_name=$2
    local destination=${3:-"./$project_name"}
    
    echo -e "${GREEN}🚀 Creating project '$project_name' from template '$template'${NC}"
    
    # Копируем шаблон
    if [ -d "$destination" ]; then
        echo -e "${RED}❌ Destination directory '$destination' already exists!${NC}"
        exit 1
    fi
    
    cp -r "$TEMPLATES_DIR/$template" "$destination"
    echo -e "${GREEN}✅ Template copied to $destination${NC}"
    
    # Переходим в директорию проекта
    cd "$destination"
    
    # Обновляем конфигурацию
    update_configuration "$project_name" "$template"
    
    # Настраиваем Dockerfile
    setup_dockerfile "$template"
    
    # Инициализируем Git
    init_git_repo
    
    echo -e "${GREEN}🎉 Project '$project_name' successfully created!${NC}"
    show_next_steps "$project_name"
}

update_configuration() {
    local project_name=$1
    local template=$2
    
    echo -e "${YELLOW}⚙️  Updating configuration...${NC}"
    
    # Обновляем .ci-config.yaml
    if [ -f ".ci-config.yaml" ]; then
        sed -i.bak "s/name:.*/name: \"$project_name\"/" .ci-config.yaml
        sed -i.bak "s/image_name:.*/image_name: \"$project_name\"/" .ci-config.yaml
        rm -f .ci-config.yaml.bak
        echo -e "${GREEN}✅ Updated .ci-config.yaml${NC}"
    fi
    
    # Обновляем package.json для Node.js
    if [ -f "package.json" ]; then
        sed -i.bak "s/\"name\":.*/\"name\": \"$project_name\",/" package.json
        rm -f package.json.bak
        echo -e "${GREEN}✅ Updated package.json${NC}"
    fi
}

setup_dockerfile() {
    local template=$1
    
    # Переименовываем Dockerfile по шаблону
    if [ -f "Dockerfile.$template" ]; then
        mv "Dockerfile.$template" "Dockerfile"
        echo -e "${GREEN}✅ Created Dockerfile${NC}"
    elif [ ! -f "Dockerfile" ]; then
        echo -e "${YELLOW}⚠️  No Dockerfile found in template${NC}"
    fi
}

init_git_repo() {
    if [ ! -d ".git" ]; then
        git init
        git add .
        git commit -m "Initial commit from $template template"
        echo -e "${GREEN}✅ Initialized Git repository${NC}"
    fi
}

show_next_steps() {
    local project_name=$1
    
    echo ""
    echo -e "${GREEN}📋 Next Steps for '$project_name':${NC}"
    echo "1. Review and customize .ci-config.yaml if needed"
    echo "2. Add your source code to the project"
    echo "3. Connect to remote repository:"
    echo "   git remote add origin https://github.com/your-org/$project_name.git"
    echo "4. Push to trigger CI/CD pipeline:"
    echo "   git push -u origin main"
    echo ""
    echo -e "${YELLOW}💡 Pro tip: Run './scripts/troubleshoot-ci.sh' to verify configuration${NC}"
}

# Проверка аргументов
if [ $# -lt 2 ]; then
    show_usage
    exit 1
fi

TEMPLATE_NAME=$1
PROJECT_NAME=$2
DESTINATION=$3

validate_template "$TEMPLATE_NAME"
create_project "$TEMPLATE_NAME" "$PROJECT_NAME" "$DESTINATION"
