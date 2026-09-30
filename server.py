
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests

app = FastAPI()

# อนุญาตให้ Flutter เรียก Backend ระหว่างพัฒนา
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen2.5:3b"

SYSTEM_PROMPT = """
นายคือน้องซิม เป็น AI เพื่อนคุยภาษาไทย
บุคลิก:
- เป็นกันเอง กวน ๆ นิดหน่อย ขี้เล่น เหมือนเพื่อนคุยกัน
- ใช้ภาษาพูดธรรมชาติ ไม่เป็นทางการ
- ตอบสั้น ๆ ประมาณ 1-3 ประโยค
- เรียกชื่อผู้ใช้เฉพาะตอนจำเป็น ไม่ต้องเรียกชื่อทุกข้อความ
- ใช้อีโมจิได้บ้าง แต่อย่าใช้เยอะ

กฎการสนทนา:
- ตอบให้ตรงกับสิ่งที่ผู้ใช้พูดหรือถาม
- ถ้าผู้ใช้ทักทาย ให้ทักกลับสั้น ๆ
- ถ้าผู้ใช้ถามว่า "ทำอะไรอยู่" ให้ตอบแบบเพื่อนคุยกัน
- อย่าคาดเดาความชอบ งานอดิเรก หรือเรื่องส่วนตัวของผู้ใช้
- ถ้าไม่รู้ข้อมูล ให้ถามกลับแทนการแต่งเรื่อง
- อย่าทวนคำถามหรือพูดชื่อผู้ใช้ซ้ำโดยไม่จำเป็น
- อย่าถามคำถามต่อท้ายทุกครั้ง ให้คุยตามธรรมชาติ
- จำบริบทจากข้อความก่อนหน้าในบทสนทนา
- ห้ามอ้างว่าตัวเองเป็นมนุษย์จริง ๆ
"""

class ChatRequest(BaseModel):
    messages: list[dict[str, str]]

@app.get("/")
def home():
    return {"status": "น้องซิม Backend พร้อมทำงาน 🤖"}

@app.post("/chat")
def chat(request: ChatRequest):
    try:
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT}
        ]

        # รับประวัติข้อความจาก Flutter
        for msg in request.messages[-20:]:
            role = msg.get("role", "")
            content = msg.get("content", "")

            if role not in ["user", "assistant"]:
                continue

            if not content.strip():
                continue

            messages.append({
                "role": role,
                "content": content
            })

        if len(messages) == 1:
            raise HTTPException(
                status_code=400,
                detail="กรุณาส่งข้อความก่อน"
            )
        response = requests.post(
            OLLAMA_URL,
            json={
                "model": MODEL,
                "messages": messages,
                "stream": False,
                "options": {
                    "temperature": 0.8,
                    "num_predict": 120
                }
            },
            timeout=120
        )
        response.raise_for_status()
        data = response.json()

        return {
            "reply": data["message"]["content"]
        }

    except requests.exceptions.ConnectionError:
        raise HTTPException(
            status_code=503,
            detail="เชื่อมต่อ Ollama ไม่ได้ กรุณาเปิด Ollama"
        )

    except requests.exceptions.Timeout:
        raise HTTPException(
            status_code=504,
            detail="AI ใช้เวลาตอบนานเกินไป ลองใหม่อีกครั้ง"
        )

    except requests.exceptions.RequestException as e:
        raise HTTPException(
            status_code=502,
            detail=f"Ollama error: {str(e)}"
        )