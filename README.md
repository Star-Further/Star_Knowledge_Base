# ☕ 星茶铺 (Star Tea Shop) - AI 智能学习知识管家

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/Python-3.10+-green.svg" alt="Python">
  <img src="https://img.shields.io/badge/AI-DeepSeek-orange.svg" alt="DeepSeek">
</p>

星茶铺是一个基于 **Flutter + Python FastAPI + DeepSeek** 开发的跨平台个人知识库软件。它旨在解决学生使用 AI 搜题时“知识点碎片化、难以复习”的痛点。

## 🌟 核心功能
- **一键解析**：粘贴 DeepSeek 分享链接，云端自动抓取题目内容。
- **AI 深度归纳**：生成结构化的**概念、用法、核心公式、解题思路**。
- **举一反三**：AI 自动生成 2 道同类变式题及答案。
- **知识树沉淀**：按“学科-章节”自动分类，构建个人专属学习卡片。
- **完美公式渲染**：支持 LaTeX 数学公式混合排版。

## 🏗️ 技术架构
- **前端 (Client)**: Flutter 3.x
- **后端 (Server)**: Python, FastAPI, Playwright, SQLite
- **AI 引擎**: DeepSeek API (JSON Mode)

## 🚀 快速开始

### 1. 后端部署 (server)
```bash
cd server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
playwright install chromium
playwright install-deps

# 配置环境变量
cp .env.example .env
# 用编辑器打开 .env，填入你的 DEEPSEEK_API_KEY

# 启动服务
python study_agent_api.py