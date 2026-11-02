import re
import json
import sqlite3
import asyncio
import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from playwright.async_api import async_playwright
from openai import OpenAI
from dotenv import load_dotenv

# 加载 .env 文件中的环境变量
load_dotenv()

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
if not DEEPSEEK_API_KEY:
    raise ValueError("请先在 .env 文件中配置 DEEPSEEK_API_KEY")

client = OpenAI(api_key=DEEPSEEK_API_KEY, base_url="https://api.deepseek.com")

app = FastAPI(title="AI Study Agent API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SYSTEM_PROMPT = """
你是一个资深的全科教师，擅长将题目归纳整理成结构化的知识点。
请分析用户提供的题目，并严格按照以下 JSON 格式输出，不要包含任何额外的解释文字。

【极其重要的格式要求】：
1. 所有的数学公式必须使用 LaTeX 语法，并且必须使用单个 `$` 包裹（例如：$x^2$），独立公式用 `$$` 包裹。
2. 在 LaTeX 公式内部，如果遇到大于号或小于号，请使用 `\\gt` 和 `\\lt`，绝对不要直接使用 `<` 和 `>`（防止被网页识别为 HTML 标签）。
3. 绝对不要遗漏闭合的 `$` 符号。
4. 知识点必须详细解释：包括名称、核心概念、以及具体怎么使用。

{
  "subject": "学科（如：高中数学）",
  "chapter": "章节（如：概率与统计）",
  "knowledge_points": [
    {
      "title": "知识点名称",
      "concept": "该知识点的详细概念解释（包含公式需用 $ 包裹）",
      "usage": "这个知识点在解题时怎么用，用来求什么，有什么注意事项。"
    }
  ],
  "formulas": ["$公式1$", "$公式2$"],
  "solution_method": "解题思路和方法（详细步骤，包含的公式必须用 $ 包裹）",
  "similar_questions": [
    {"question": "举一反三题目1，包含 $公式$", "answer": "题目1的解析，包含 $公式$"},
    {"question": "举一反三题目2，包含 $公式$", "answer": "题目2的解析"}
  ]
}
"""

def init_db():
    conn = sqlite3.connect('knowledge.db')
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS knowledge_records
                 (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                  source_url TEXT, subject TEXT, chapter TEXT, 
                  content_json TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    conn.commit()
    conn.close()

init_db()

class ParseRequest(BaseModel):
    url: str

async def extract_text_from_url(url: str) -> str:
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True, args=["--no-sandbox"])
        page = await browser.new_page()
        await page.goto(url, wait_until="networkidle", timeout=60000)
        await page.wait_for_timeout(2000)
        full_text = await page.locator("body").inner_text()
        await browser.close()
        return re.sub(r'来自分享的对话|该对话来自分享，由 AI 生成，请仔细甄别。', '', full_text).strip()

@app.post("/api/parse")
async def parse_question(req: ParseRequest):
    try:
        text = await extract_text_from_url(req.url)
        response = client.chat.completions.create(
            model="deepseek-flash",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"请分析以下题目：\n\n{text}"}
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
        )
        result_json = json.loads(response.choices[0].message.content)
        
        conn = sqlite3.connect('knowledge.db')
        c = conn.cursor()
        c.execute("INSERT INTO knowledge_records (source_url, subject, chapter, content_json) VALUES (?, ?, ?, ?)",
                  (req.url, result_json["subject"], result_json["chapter"], json.dumps(result_json, ensure_ascii=False)))
        conn.commit()
        conn.close()
        
        return {"code": 200, "msg": "解析并保存成功", "data": result_json}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/knowledge_tree")
async def get_knowledge_tree():
    conn = sqlite3.connect('knowledge.db')
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM knowledge_records ORDER BY created_at DESC")
    rows = c.fetchall()
    conn.close()
    
    records = [dict(row) for row in rows]
    for r in records:
        r["content_json"] = json.loads(r["content_json"])
    return {"code": 200, "data": records}

@app.get("/", response_class=HTMLResponse)
async def read_index():
    return "<h1>API 服务已启动，请访问 /docs 查看接口文档或使用客户端连接。</h1>"

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)