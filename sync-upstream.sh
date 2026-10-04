#!/usr/bin/env bash
set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}>>> [1/5] 检查当前本地分支状态...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    echo -e "${RED}错误：无法获取当前分支名，请确认处于 git 仓库中。${NC}"
    exit 1
fi

# 确保当前工作区没有未提交的脏代码
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}错误：本地工作区有未提交的修改，请先 git commit 或 git stash 暂存后再执行合并。${NC}"
    exit 1
fi

echo -e "${YELLOW}>>> [2/5] 自动检测上游（Fork 来源）仓库...${NC}"
# 1. 如果本地已经配置了 upstream，直接使用
if git remote | grep -q "^upstream$"; then
    echo -e "${GREEN}检测到已配置的 upstream 远程仓库。${NC}"
else
    # 2. 如果没有 upstream，利用 Codespaces 自带的 gh 工具全自动查询父仓库
    if command -v gh >/dev/null 2>&1; then
        PARENT_REPO=$(gh repo view --json parent -q '.parent.nameWithOwner' 2>/dev/null || true)
        if [ -n "$PARENT_REPO" ] && [ "$PARENT_REPO" != "null" ]; then
            UPSTREAM_URL="https://github.com/${PARENT_REPO}.git"
            echo -e "${GREEN}自动检测到上游仓库: ${PARENT_REPO}${NC}"
            git remote add upstream "$UPSTREAM_URL"
        else
            echo -e "${RED}错误：通过 GitHub API 未检测到当前仓库的 Fork 父仓库，请确认当前仓库是否为 Fork 仓库。${NC}"
            exit 1
        fi
    else
        echo -e "${RED}错误：未找到 upstream 且环境中未安装 gh 工具。${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}>>> [3/5] 拉取上游最新提交...${NC}"
git fetch upstream

# 自动获取上游的默认分支（通常是 main 或 master）
UPSTREAM_DEFAULT_BRANCH=$(git remote show upstream | sed -n '/HEAD branch/s/.*: //p' || echo "main")
echo -e "${GREEN}上游默认分支为: ${UPSTREAM_DEFAULT_BRANCH}${NC}"

echo -e "${YELLOW}>>> [4/5] 合并上游更新（冲突时以当前我的代码为准）...${NC}"
# -X ours: 自动吸收上游的新文件和非冲突更新；凡是代码重叠/冲突处，100% 保留我的修改
git merge "upstream/${UPSTREAM_DEFAULT_BRANCH}" -X ours -m "Sync upstream/${UPSTREAM_DEFAULT_BRANCH} with local changes preferred"

echo -e "${YELLOW}>>> [5/5] 推送合并结果到你的远程仓库...${NC}"
git push origin "$CURRENT_BRANCH"

echo -e "\n${GREEN}✔ 合并完成并已推送到 origin/${CURRENT_BRANCH}！${NC}"
