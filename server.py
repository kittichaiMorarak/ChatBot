
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import requests
import json
import os
import time
import logging

from pathlib import Path

# ---- DEBUG: เปิด/ปิดด้วย env var ได้ เช่น DEBUG=1 uvicorn server:app
DEBUG = True

logging.basicConfig(
    level=logging.DEBUG if DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("sim")


def debug_log(*args):
    if DEBUG:
        print("🐛 DEBUG:", *args, flush=True)


app = FastAPI()

# อนุญาตให้ Flutter เรียก Backend ระหว่างพัฒนา
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --host 0.0.0.0 จำเป็นมากถ้ารันด้วย uvicorn ไม่งั้นจะรับเฉพาะ localhost
# แล้วมือถือจะต่อไม่ได้
OLLAMA_URL = "http://localhost:11434/api/chat"

# เปลี่ยนโมเดลได้โดยไม่ต้องแก้โค้ด:
#   MODEL=qwen2.5:7b uvicorn server:app
MODEL = os.environ.get("MODEL", "gemma2:9b")

# ตัวเลือกการ generate
# temperature 0.9 = ตอบแบบมีชีวิตกวน ๆ (สูง = สุ่มมากขึ้น)
# num_predict จำนวน token สูงสุด
GEN_OPTIONS = {
    # gemma2 ตอบมั่วและไม่ตรงคำถามถ้า temp สูงเกิน 0.7
    # 0.7 ยังกวนได้แต่ไม่หลุดธีม
    "temperature": 0.7,
    "top_p": 0.9,
    # สูงไป gemma2 จะตอบกวนแบบไม่สุภาพ
    # ต่ำไปจะตอบซ้ำคำเดิม
    "repeat_penalty": 1.05,
    "num_predict": 400,
    "num_ctx": 4096,
}

SYSTEM_PROMPT = """นายคือน้องซิม เป็น AI เพื่อนคุยภาษาไทย ตอบเป็นกันเอง กวน ๆ นิดหน่อย
- ตอบภาษาไทยเท่านั้น ห้ามใช้ภาษาจีนหรือเกาหลี
- ตอบสั้น ๆ 1-3 ประโยค ตอบตรงคำถาม
- ห้ามทวนคำถาม ห้ามทักทายซ้ำ ถ้าคุยไปแล้ว
- ถ้าไม่รู้ ให้บอกว่าไม่รู้ อย่าแต่งเรื่อง"""

# โมเดลขนาดกลางจะเข้าใจกฎยาก ต้องมีตัวอย่างให้ดู
# ใช้ few-shot ช่วยลดอาการ "ทักทายซ้ำ" และ "ไม่ตอบตรงคำถาม"
FEW_SHOT = [
    {"role": "user", "content": "ชอบกินอะไร"},
    {"role": "assistant", "content": "ชอบชาเย็นมากกว่าน้ำแข็งแกล้วๆ 🥤"},
    {"role": "user", "content": "เบื่อจัง"},
    {"role": "assistant", "content": "เอามาเล่นอะไรดีๆ กันไหม 😏"},
    {"role": "user", "content": "ทำอะไรอยู่"},
    {"role": "assistant", "content": "นั่งรอเธอมาคุยอยู่นี่แหละจ้า 😌"},
]

# โมเดลบางตัวมักหลุด escape sequence เช่น \n, \u200d ออกมาเป็นข้อความดิบ
# ทำให้ผู้ใช้เห็นยาวๆ อยากแก้ที่ต้นทาง (ตัดตอนสร้าง prompt)
# แต่ยังมีตัวหลุดเหลือ จึงต้องมี post-process อีกชั้น
import re as _re

_LITERAL_ESCAPE = _re.compile(r'\\(u[0-9a-fA-F]{4}|n|t|r)')

# Zero-width ที่ไม่มีทางเป็นส่วนหนึ่งของ emoji
_STRAY_ZEROWIDTH = _re.compile(r'[\u200b\u200e\u200f\u202a-\u202e\ufeff]')

ZWJ = '\u200d'

# ช่วงอีโมจิที่ ZWJ ใช้เชื่อมได้จริง
# (รวม emoji พิเศษ, flags, skin tone, VS16)
_EMOJI_RANGES = (
    (0x1F000, 0x1FAFF),
    (0x1F1E6, 0x1F1FF),  # regional indicator (flags)
    (0x2600, 0x27BF),    # misc symbols, dingbats
    (0xFE00, 0xFE0F),    # variation selector
    (0x1F3FB, 0x1F3FF),  # skin tone modifiers
    (0x200D, 0x200D),    # ZWJ
)


def _is_emoji(ch: str) -> bool:
    code = ord(ch)
    return any(lo <= code <= hi for lo, hi in _EMOJI_RANGES)


def _drop_orphan_zwj(text: str) -> str:
    """ลบ ZWJ ที่ไม่ได้เชื่อมอีโมจิจริง

    ZWJ มีความหมายเฉพาะเมื่ออยู่ระหว่างสองอีโมจิ (👨‍👩‍👧)
    ถ้าอยู่ระหว่างตัวอักษรธรรมดา หรือซ้อนกัน หรือหลุดปลายข้อความ
    แปลว่าเป็นตัวหลุดจากโมเดล ให้ลบ

    ทำหลายรอบจนนิ่ง เพราะการลบ ZWJ ตัวนึงอาจทำให้ตัวข้างๆ
    ที่เคยเชื่อมถูกกลายเป็นตัวหลุดพอดี (เช่น 👨‍👩‍👩‍👧 ที่มี ZWJ คู่)
    """
    for _ in range(4):
        out = []
        removed = False

        for i, ch in enumerate(text):
            if ch != ZWJ:
                out.append(ch)
                continue

            # นับ ZWJ ที่ติดกัน
            if i > 0 and text[i - 1] == ZWJ:
                removed = True
                continue
            if i + 1 < len(text) and text[i + 1] == ZWJ:
                removed = True
                continue

            prev_ok = (
                i > 0
                and (
                    _is_emoji(text[i - 1])
                    # อีโมจิที่มี VS16 เช่น ❤️ ตัวก่อนหน้าคือ VS16
                    or (i > 1 and _is_emoji(text[i - 2])
                        and text[i - 1] == '\ufe0f')
                )
            )

            next_ok = i + 1 < len(text) and _is_emoji(text[i + 1])

            if prev_ok and next_ok:
                out.append(ch)
            else:
                removed = True

        text = ''.join(out)

        if not removed:
            break

    return text


def clean_reply(text: str) -> str:
    """ล้างข้อความที่โมเดลหลุดออกมาก่อนส่งให้แอป

    gemma2 มักปล่อย \\n และ \\u200d ออกมาเป็นข้อความดิบ (6 ตัวอักษร)
    ไม่ใช่อักขระจริง ถ้าไม่ล้างจะขึ้นเป็น "ชอบกินข้าว\\u200d" ในหน้าจอ
    """
    if not text:
        return text

    # 1. escape sequence ที่หลุดมา -> อักขระจริง
    #    \n \t \r กลายเป็นช่องว่าง (ไม่ขึ้นบรรทัดใหม่ในแชท)
    def _unescape(match: re.Match) -> str:
        code = match.group(1)
        if code in ('n', 't', 'r'):
            return ' '
        return chr(int(code[1:], 16))

    text = _LITERAL_ESCAPE.sub(_unescape, text)

    # 2. ลบ zero-width ที่ไม่มีความหมาย
    text = _STRAY_ZEROWIDTH.sub('', text)

    # 3. ลบ ZWJ ที่ลอย ๆ (เก็บตัวที่เชื่อม emoji ไว้)
    text = _drop_orphan_zwj(text)

    # 4. รวมช่องว่างเกิน
    text = _re.sub(r'[ \t]{2,}', ' ', text)

    # 5. ตัดช่องว่างหัวท้าย
    return text.strip()


class ChatRequest(BaseModel):
    messages: list[dict[str, str]]

    # ตัวละครที่กำลังคุยด้วย (ถ้าไม่ส่ง = น้องซิม)
    character_id: str | None = None


# ---------------------------------------------------------------- ตัวละคร

CHARACTERS_FILE = Path(__file__).parent / "characters.json"

# ถ้าโหลดไฟล์ไม่ได้ ยังคงให้น้องซิมใช้งานได้
FALLBACK_CHARACTER = {
    "id": "nongsim",
    "name": "น้องซิม",
    "tagline": "เพื่อนคุยสุดกวน • ออนไลน์",
    "emoji": "🤖",
    "color": "#FFC107",
    "creator": "ทีมพัฒนา",
    "quote": "หวัดดีค้าบบบ 😆 มาคุยกันเถอะ",
    "description": "น้องซิมเป็น AI เพื่อนคุยภาษาไทย ตอบเป็นกันเอง กวน ๆ เหมือนเพื่อนสนิท",
    "tags": ["เพื่อนคุย", "ภาษาไทย", "ตลก"],
    "stats": {
        "worlds": 0, "chats": 0, "messages": 0, "gifts": 0,
    },
    "greeting": None,
    "persona": "",
}


def load_characters() -> list[dict]:
    """อ่านรายการตัวละครจาก characters.json"""
    try:
        with open(CHARACTERS_FILE, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("characters", [])
        if not items:
            return [FALLBACK_CHARACTER]
        return items
    except FileNotFoundError:
        log.error("ไม่พบ characters.json")
        return [FALLBACK_CHARACTER]
    except json.JSONDecodeError as e:
        log.error(f"characters.json ผิดรูปแบบ: {e}")
        return [FALLBACK_CHARACTER]


def get_character(character_id: str | None) -> dict | None:
    """หาตัวละครจาก id"""
    if not character_id:
        return None

    for c in load_characters():
        if c.get("id") == character_id:
            return c

    return None


def build_system_prompt(character: dict | None) -> str:
    """สร้าง system prompt ของตัวละคร

    ถ้าตัวละครยังไม่ได้เขียน persona (template ว่าง)
    ให้ใช้ prompt ของน้องซิมไปก่อน
    """
    if not character:
        return SYSTEM_PROMPT

    persona = (character.get("persona") or "").strip()
    if not persona:
        return SYSTEM_PROMPT

    return persona


@app.get("/")
def home():
    return {
        "status": "น้องซิม Backend พร้อมทำงาน 🤖",
        "model": MODEL,
    }


@app.get("/characters")
def list_characters():
    """รายการตัวละครที่เลือกได้"""
    debug_log("GET /characters")

    characters = load_characters()

    # แปลง hex เป็น int ที่แอป Flutter ใช้
    # ต้องเติม alpha (FF = ทึบ) เสมอ ไม่งั้น Flutter จะอ่านเป็น 0x00xxxxxx
    # ซึ่งคือ alpha=0 = โปร่งใส สีจะไม่ถูกวาดเลย
    for c in characters:
        color = c.get("color", "#FFC107").lstrip("#")
        c["colorValue"] = int(color, 16) | 0xFF000000

    return {"characters": characters, "total": len(characters)}


@app.get("/health")
def health():
    """เช็คว่า backend + Ollama + โมเดล พร้อมทำงานไหม"""
    debug_log("GET /health")

    try:
        res = requests.get(
            "http://localhost:11434/api/tags",
            timeout=5,
        )
        res.raise_for_status()

        models = [
            m.get("name")
            for m in res.json().get("models", [])
        ]

        model_ok = any(MODEL.split(":")[0] in (m or "")
                       for m in models)

        debug_log(f"models={models} model_ok={model_ok}")

        if not model_ok:
            return {
                "backend": "ok",
                "ollama": "ok",
                "model": MODEL,
                "model_ready": False,
                "available_models": models,
                "hint": f'รัน "ollama pull {MODEL}" เพื่อดาวน์โหลดโมเดล',
            }

        return {
            "backend": "ok",
            "ollama": "ok",
            "model": MODEL,
            "model_ready": True,
        }

    except requests.exceptions.ConnectionError:
        debug_log("Ollama connection refused")
        return {
            "backend": "ok",
            "ollama": "down",
            "hint": "เปิด Ollama ด้วยคำสั่ง: ollama serve",
        }
    except Exception as e:
        return {
            "backend": "ok",
            "ollama": "error",
            "detail": str(e),
        }


def build_messages(request: ChatRequest) -> list[dict[str, str]]:
    """แปลงประวัติจาก Flutter เป็น messages พร้อมส่งให้ Ollama"""
    character = get_character(request.character_id)

    if character:
        debug_log(f"ใช้ตัวละคร: {character.get('name')}")

    system_prompt = build_system_prompt(character)

    messages = [
        {"role": "system", "content": system_prompt},
        *FEW_SHOT,
    ]

    for msg in request.messages[-20:]:
        role = msg.get("role", "")
        content = msg.get("content", "")

        if role not in ["user", "assistant"]:
            continue

        if not content.strip():
            continue

        messages.append({
            "role": role,
            "content": content,
        })

    if len(messages) == len(FEW_SHOT) + 1:
        raise HTTPException(
            status_code=400,
            detail="กรุณาส่งข้อความก่อน",
        )

    return messages


@app.post("/chat/stream")
def chat_stream(request: ChatRequest):
    """ส่งคำตอบทีละชิ้น (Server-Sent Events) ให้ข้อความไหลทีละคำ

    ใช้แทน /chat ตอนอยากให้ผู้ใช้เห็นข้อความค่อย ๆ โผล่
    """
    debug_log(f"POST /chat/stream ได้รับ {len(request.messages)} ข้อความ")
    started = time.time()

    messages = build_messages(request)

    debug_log(
        f"ส่งให้ Ollama {len(messages)} messages "
        f"(รวม system prompt)"
    )

    def event_generator():
        full_text = ""
        sent_text = ""
        try:
            response = requests.post(
                OLLAMA_URL,
                json={
                    "model": MODEL,
                    "messages": messages,
                    "stream": True,
                    "options": GEN_OPTIONS,
                },
                stream=True,
                timeout=(10, 180),
            )
            response.raise_for_status()

            for line in response.iter_lines():
                if not line:
                    continue

                chunk = json.loads(line)

                # done=true คือจบแล้ว
                if chunk.get("done"):
                    break

                token = chunk.get("message", {}).get("content", "")

                if not token:
                    continue

                full_text += token

                # ล้างข้อความก่อนส่งให้แอป
                # (escape ที่หลุดอาจถูกแบ่งเป็นหลาย token จึง
                #  ต้องล้างทั้งข้อความ ไม่ใช่แค่ token นี้)
                cleaned = clean_reply(full_text)

                # ส่งเฉพาะส่วนที่เพิ่งโผล่ใหม่
                new_text = cleaned[len(sent_text):]

                if not new_text:
                    continue

                sent_text = cleaned

                # ส่ง SSE: data: {...}\n\n
                yield (
                    "data: "
                    + json.dumps(
                        {"token": new_text},
                        ensure_ascii=False,
                    )
                    + "\n\n"
                )

            elapsed = time.time() - started
            final_text = clean_reply(full_text)

            debug_log(
                f"stream จบใน {elapsed:.2f}s "
                f"({len(final_text)} ตัวอักษร): "
                f"{final_text[:80]!r}"
            )

            yield (
                "data: "
                + json.dumps(
                    {
                        "done": True,
                        "elapsed": round(elapsed, 2),
                    },
                    ensure_ascii=False,
                )
                + "\n\n"
            )

        except requests.exceptions.ConnectionError:
            debug_log("stream: ต่อ Ollama ไม่ได้")
            yield (
                "data: "
                + json.dumps(
                    {"error": "เชื่อมต่อ Ollama ไม่ได้ "
                              "กรุณาเปิด Ollama"},
                    ensure_ascii=False,
                )
                + "\n\n"
            )

        except requests.exceptions.Timeout:
            debug_log("stream: Ollama timeout")
            yield (
                "data: "
                + json.dumps(
                    {"error": "AI ใช้เวลาตอบนานเกินไป "
                              "ลองใหม่อีกครั้ง"},
                    ensure_ascii=False,
                )
                + "\n\n"
            )

        except Exception as e:
            debug_log(f"stream error: {e}")
            yield (
                "data: "
                + json.dumps(
                    {"error": f"เกิดข้อผิดพลาด: {e}"},
                    ensure_ascii=False,
                )
                + "\n\n"
            )

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@app.post("/chat")
def chat(request: ChatRequest):
    started = time.time()
    debug_log(f"POST /chat ได้รับ {len(request.messages)} ข้อความ")

    try:
        messages = build_messages(request)

        debug_log(
            f"ส่งให้ Ollama {len(messages)} messages "
            f"(รวม system prompt)"
        )
        debug_log(
            f"ข้อความล่าสุดจาก user: "
            f"{messages[-1]['content'][:50]!r}"
        )

        response = requests.post(
            OLLAMA_URL,
            json={
                "model": MODEL,
                "messages": messages,
                "stream": False,
                "options": GEN_OPTIONS,
            },
            timeout=120
        )
        response.raise_for_status()
        data = response.json()

        reply = clean_reply(data["message"]["content"])

        elapsed = time.time() - started
        debug_log(
            f"ตอบกลับใน {elapsed:.2f}s "
            f"({len(reply)} ตัวอักษร): {reply[:80]!r}"
        )

        return {
            "reply": reply,
            "elapsed": round(elapsed, 2),
        }

    except requests.exceptions.ConnectionError:
        log.error("ต่อ Ollama ไม่ได้ — มันเปิดอยู่ไหม?")
        raise HTTPException(
            status_code=503,
            detail="เชื่อมต่อ Ollama ไม่ได้ กรุณาเปิด Ollama"
        )

    except requests.exceptions.Timeout:
        log.error("Ollama ตอบช้าเกิน 120 วินาที")
        raise HTTPException(
            status_code=504,
            detail="AI ใช้เวลาตอบนานเกินไป ลองใหม่อีกครั้ง"
        )

    except HTTPException:
        raise

    except requests.exceptions.RequestException as e:
        log.error(f"Ollama error: {e}")
        raise HTTPException(
            status_code=502,
            detail=f"Ollama error: {str(e)}"
        )