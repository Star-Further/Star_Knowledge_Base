# 🌟 星知库 (Star Knowledge Base) - AI 智能学习管家

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/Python-3.10+-green.svg" alt="Python">
  <img src="https://img.shields.io/badge/AI-DeepSeek-orange.svg" alt="DeepSeek">
  <img src="https://img.shields.io/badge/License-MIT-purple.svg" alt="License">
</p>

星知库是一个基于 **Flutter + Python FastAPI + DeepSeek** 开发的跨平台（Windows / Android）个人智能知识库软件。它旨在解决学生使用 AI 搜题时“知识点碎片化、难以复习”的痛点，将每次搜题转化为个人专属的结构化学习卡片。

## 🌟 核心功能

- **🔗 一键解析**：粘贴 DeepSeek 分享链接，云端自动抓取题目内容。
- **🧠 AI 深度归纳**：调用大模型，自动生成结构化的**概念解释、使用方法、核心公式、解题思路**。
- **🚀 举一反三**：AI 自动生成 2 道同类变式题及答案。
- **🌳 知识树沉淀**：按“学科-章节”自动分类，构建清晰的树状目录。
- **🔍 全局搜索**：快速检索题库中的任何知识点或题目内容。
- **⭐ 错题本收藏**：遇到重点题目一键收藏，随时在“错题本”中集中复习。
- **🗑️ 记录管理**：支持删除无用记录，保持知识库干净整洁。
- **🧮 完美公式渲染**：原生支持 LaTeX 复杂数学公式混合排版。

## 🏗️ 技术架构

- **前端 (Client)**: Flutter 3.x (支持 Windows, Android, Web)
- **后端 (Server)**: Python, FastAPI, Playwright, SQLite
- **AI 引擎**: DeepSeek API (JSON Mode)

## 🚀 快速开始

### 1. 后端部署 (Server)
进入 `Server` 目录：
```bash
cd Server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
playwright install chromium
playwright install-deps

# 配置环境变量
# 复制 .env.example 为 .env，并填入你的 DEEPSEEK_API_KEY
cp .env.example .env
# 编辑 .env 填入真实密钥

# 启动服务 (默认监听 8081 端口)
python study_agent_api.py