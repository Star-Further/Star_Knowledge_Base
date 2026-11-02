import re
import json
import sqlite3
import asyncio
import os
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from playwright.async_api import async_playwright
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
if not DEEPSEEK_API_KEY:
    raise ValueError("请先在 .env 文件中配置 DEEPSEEK_API_KEY")

client = OpenAI(api_key=DEEPSEEK_API_KEY, base_url="https://api.deepseek.com")
app = FastAPI(title="星知库 API")

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
2. 在 LaTeX 公式内部，如果遇到大于号或小于号，请使用 `\\gt` 和 `\\lt`，绝对不要直接使用 `<` 和 `>`。
3. 绝对不要遗漏闭合的 `$` 符号。
4. 知识点必须详细解释：包括名称、核心概念、以及具体怎么使用。

{
  "subject": "学科",
  "chapter": "章节",
  "knowledge_points": [
    {
      "title": "知识点名称",
      "concept": "详细概念解释",
      "usage": "怎么用，用来求什么。"
    }
  ],
  "formulas": ["$公式1$"],
  "solution_method": "解题思路和方法",
  "similar_questions": [
    {"question": "变式题1", "answer": "解析1"}
  ]
}
"""

# 初始化数据库（新增 is_favorite 字段）
def init_db():
    conn = sqlite3.connect('knowledge.db')
    c = conn.cursor()
    # 尝试建表（带 is_favorite 字段）
    c.execute('''CREATE TABLE IF NOT EXISTS knowledge_records
                 (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                  source_url TEXT, subject TEXT, chapter TEXT, 
                  content_json TEXT, is_favorite INTEGER DEFAULT 0,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
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
        page.wait_for_timeout(2000)
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

# 获取知识树 (支持只看收藏)
@app.get("/api/knowledge_tree")
async def get_knowledge_tree(only_favorite: bool = False, keyword: str = ""):
    conn = sqlite3.connect('knowledge.db')
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    query = "SELECT * FROM knowledge_records WHERE 1=1"
    params = []
    
    if only_favorite:
        query += " AND is_favorite = 1"
    
    if keyword:
        query += " AND (content_json LIKE ? OR subject LIKE ? OR chapter LIKE ?)"
        kw = f"%{keyword}%"
        params.extend([kw, kw, kw])
        
    query += " ORDER BY created_at DESC"
    
    c.execute(query, params)
    rows = c.fetchall()
    conn.close()
    
    records = [dict(row) for row in rows]
    for r in records:
        r["content_json"] = json.loads(r["content_json"])
    return {"code": 200, "data": records}

# 删除记录
@app.delete("/api/record/{record_id}")
async def delete_record(record_id: int):
    try:
        conn = sqlite3.connect('knowledge.db')
        c = conn.cursor()
        c.execute("DELETE FROM knowledge_records WHERE id = ?", (record_id,))
        conn.commit()
        conn.close()
        return {"code": 200, "msg": "删除成功"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 切换收藏状态
@app.post("/api/record/{record_id}/favorite")
async def toggle_favorite(record_id: int):
    try:
        conn = sqlite3.connect('knowledge.db')
        c = conn.cursor()
        c.execute("SELECT is_favorite FROM knowledge_records WHERE id = ?", (record_id,))
        row = c.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="记录不存在")
            
        new_status = 0 if row[0] == 1 else 1
        c.execute("UPDATE knowledge_records SET is_favorite = ? WHERE id = ?", (new_status, record_id))
        conn.commit()
        conn.close()
        return {"code": 200, "msg": "状态更新成功", "is_favorite": new_status}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)