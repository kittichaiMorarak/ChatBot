# น้องซิม (Simsimi Chatbot)

แชทบอท AI ภาษาไทย บุคลิกเป็นกันเอง กวน ๆ ขี้เล่น
Flutter (client) + Python FastAPI (backend) + Ollama (local LLM)

## โครงสร้าง

```
lib/
  main.dart                   จุดเริ่มแอป + config
  theme.dart                  สีและธีมทั้งหมด (AppColors)
  models/
    message.dart              Message + Conversation (มี JSON)
    character.dart            AiCharacter + CharacterStats
  services/
    chat_api.dart             ยิง backend + อ่าน stream
    chat_storage.dart         เก็บประวัติแชทในเครื่อง
    character_api.dart        ดึงรายการตัวละครจาก backend
    character_storage.dart    เก็บตัวละครที่ผู้ใช้สร้างเอง (ในเครื่อง)
  screens/
    chat_page.dart            หน้าหลัก + logic ทั้งหมด
    sim_home_page.dart        หน้าซิม (หน้าแรก) + ตัวละครของคุณ
    character_edit_page.dart  ฟอร์มสร้าง / แก้ไขตัวละคร
    character_profile_page.dart โปรไฟล์ตัวละคร
  widgets/
    avatar.dart               ShimAvatar / UserAvatar / CharacterAvatar
    chat_drawer.dart          เมนูข้าง + รายการประวัติแชท
    message_bubble.dart       กล่องข้อความ + จุดกำลังพิมพ์

server.py              FastAPI backend -> Ollama
characters.json        ข้อมูลตัวละครทั้งหมด
requirements.txt       Python deps
```

## API

| Endpoint | รายละเอียด |
|---|---|
| `GET /` | ข้อความตอบกลับ บอกว่า backend ทำงานไหม |
| `GET /health` | เช็ค 3 ชั้น: backend / Ollama / โมเดลพร้อมไหม |
| `GET /characters` | รายการตัวละครที่เลือกคุยได้ |
| `POST /chat` | ตอบเต็มข้อความทีเดียว (ไม่ streaming) |
| `POST /chat/stream` | **ตัวที่แอปใช้** — ส่งคำตอบทีละชิ้นแบบ SSE |

`POST /chat` และ `POST /chat/stream` รับ body เหมือนกัน:

```json
{
  "messages": [{ "role": "user", "content": "สวัสดี" }],
  "character_id": "nongsim",
  "persona": null
}
```

`persona` = system prompt จากตัวละครที่ผู้ใช้สร้างเองในแอป (ยาวเกิน 4000 ตัวอักษรจะถูกตัด)
ถ้าไม่ส่ง ระบบจะไล่หาจาก `characters.json` → ถ้ายังว่าง → ใช้ของน้องซิม

`POST /chat/stream` ตอบเป็น Server-Sent Events:
```
data: {"token": "เรา"}
data: {"token": "เคย"}
data: {"token": "เล"}
...
data: {"done": true, "elapsed": 3.42}
```
ถ้ามี error จะได้ `data: {"error": "..."}`

## ตัวละคร

**หน้าแรกของแอป = หน้าซิม** แบ่งเป็น 2 ส่วน

- **หน้าซิม (บน)** — การ์ดน้องซิมเต็มจอ กดที่การ์ดเพื่อดูโปรไฟล์ หรือกด "เริ่มแชท" เพื่อคุยเลย
- **ตัวละครของคุณ (ล่าง)** — ตัวละครที่ผู้ใช้สร้างเอง กด "สร้างตัวละครใหม่" เพื่อสร้าง

### 1. ตัวละครจาก server (`characters.json`)

ข้อมูลตัวละครที่มากับแอปอยู่ใน **`characters.json`** (ไม่ต้องแตะโค้ด)
ตอนนี้มีแค่ **น้องซิม** ตัวเดียว

```json
{
  "id": "nongsim",
  "name": "น้องซิม",
  "tagline": "คำโปรยสั้นๆ ที่แสดงใต้ชื่อ",
  "emoji": "🤖",
  "color": "#FFC107",
  "creator": "ทีมพัฒนา",
  "quote": "คำคมของตัวละคร",
  "description": "เรื่องย่อของตัวละคร",
  "tags": ["เพื่อนคุย", "ภาษาไทย"],
  "stats": { "worlds": 0, "chats": 0, "messages": 0, "gifts": 0 },
  "greeting": null,
  "persona": ""
}
```

| ฟิลด์ | ความหมาย |
|---|---|
| `id` | ต้อง unique ใช้เป็นตัวระบุ |
| `emoji` + `color` | ใช้แทนรูปชั่วคราว (ยังไม่มีรูปจริง) |
| `persona` | system prompt — **ถ้าว่างจะใช้ของน้องซิมไปก่อน** |
| `greeting` | ข้อความต้อนรับ (ยังไม่ได้ใช้) |

### เพิ่มตัวละครใหม่ (ฝั่ง server)

1. เพิ่ม object ใน `characters.json`
2. ถ้าต้องการบุคลิกเฉพาะ ใส่ `persona` ด้วย
3. restart backend (`Ctrl+C` แล้วรันใหม่)

### 2. ตัวละครที่ผู้ใช้สร้างเอง

กด **"สร้างตัวละครใหม่"** บนหน้าซิม แล้วกรอก:

| ช่อง | บังคับ | หมายเหตุ |
|---|---|---|
| ชื่อตัวละคร | ✅ | ต้องไม่ว่าง |
| คำโปรยสั้น | | แสดงใต้ชื่อ |
| ผู้สร้าง | | ว่าง = "ผู้ใช้สร้างเอง" |
| คำคม / คำอธิบาย | | แสดงในหน้าโปรไฟล์ |
| แท็ก | | คั่นด้วย `,` ได้สูงสุด 8 แท็ก |
| สัญลักษณ์ | | เลือกอีโมจิจาก 32 ตัวที่มีให้ |
| สีประจำตัวละคร | | เลือกจาก 12 สี |
| บุคลิกและวิธีพูด | | = system prompt (ดูหมายเหตุข้างล่าง) |

ตัวละครที่สร้างเอง**เก็บในเครื่องผู้ใช้** (shared_preferences) ไม่ขึ้นไปที่ server
ลบแอป = หายทั้งหมด

**เรื่อง system prompt:** ตัวละครที่ผู้ใช้สร้างเอง backend ไม่รู้จัก แอปจึงส่ง `persona`
ไปกับทุกข้อความ (`POST /chat/stream` มีฟิลด์ `persona`) แล้วใช้แทน system prompt
ของน้องซิม — ถ้าเว้นว่างไว้จะใช้ของน้องซิมตามปกติ

> ⚠️ การยอมให้ client ส่ง system prompt ได้ = ใครก็เปลี่ยนพฤติกรรม AI ได้
> เหมาะกับแอปส่วนตัวที่ backend รันบนเครื่องตัวเอง
> **ถ้าจะเปิดใช้จริงบน server สาธารณะ ต้องเพิ่มการยืนยันสิทธิ์ก่อน**

```json
"persona": "คุณคือนักศึกษาแพทย์ พูดจริงจัง สุภาพ ใช้ภาษาไทย\n- ตอบสั้น ๆ 2-3 ประโยค\n- ไม่ต้องทวนคำถาม"
```

> **คำเตือน**: gemma2:9b ทำตาม system prompt ยาว ๆ ไม่ค่อยได้
> ควรเขียนสั้น ๆ 4-6 บรรทัดเหมือน `SYSTEM_PROMPT` ตอนนี้

## Setup

### 1. Ollama

```bash
ollama serve                      # เปิด (ถ้ายังไม่ได้เปิด)
ollama pull gemma2:9b             # ดาวน์โหลดโมเดล (~5.4GB)
ollama list                      # เช็คว่ามีโมเดลแล้ว
```

โมเดลอื่นที่ใช้ได้ (เปลี่ยนได้ ไม่ต้องแก้โค้ด):
```bash
ollama pull qwen2.5:7b            # ภาษาไทยดี, ตอบเร็วกว่า
ollama pull llama3.1:8b           # ภาษาอังกฤษดี
```

### 2. Backend

```bash
# ครั้งแรก
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

# --host 0.0.0.0 จำเป็นมาก ไม่งั้นจะรับเฉพาะ localhost แล้วมือถือต่อไม่ได้
.venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8000

# เปลี่ยนโมเดลตอนรัน (ไม่ต้องแก้โค้ด)
MODEL=qwen2.5:7b .venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8000
```

เช็คว่าทุกอย่างพร้อม:

```bash
curl http://localhost:8000/health
```

จะได้ `{"backend":"ok","ollama":"ok","model_ready":true}` ถ้าทุกอย่างปกติ
ถ้า `model_ready: false` แปลว่ายังไม่ได้ pull โมเดล

### 3. Flutter

```bash
# ดู IP ของคอมก่อน
ipconfig getifaddr en1

flutter run --dart-define=API_URL=http://<IP-ของ-คอม>:8000/chat/stream
```

เช่น `flutter run --dart-define=API_URL=http://10.24.176.189:8000/chat/stream`

> ตอนรันบนมือถือ **ต้องใช้ IP ของคอม** ไม่ใช่ 127.0.0.1
> เพราะ 127.0.0.1 บนมือถือ = ตัวมือถือเอง ไม่ใช่คอม
>
> มือถือและคอมต้องอยู่ Wi-Fi เดียวกัน และถ้าเป็นเครือข่ายมหาวิทยาลัย/ออฟฟิศ
> อาจถูกบล็อก client isolation ต้องใช้ hotspot หรือเปิด firewall

## ปุ่มล้างแชท

อยู่มุมขวาบนของ AppBar

## โมเดล

ค่าเริ่มต้นคือ `gemma2:9b` กำหนดไว้ใน `server.py` (`MODEL`)

ข้อควรรู้เรื่อง prompt ของ `gemma2:9b`:
- **system prompt ต้องสั้น** โมเดลจะเสียบุคลิกและตอบไม่ตรงคำถามถ้ายาวเกิน
- **ต้องมี few-shot** (`FEW_SHOT` ใน `server.py`) ไม่งั้นจะ "ทักทายซ้ำ" แทนที่จะตอบ
- **ต้องกรม "ห้ามใช้ภาษาจีน/เกาหลี"** เพราะโมเดล multilingual หลุดจีน/เกาหลีง่ายมาก
- `temperature` ต้องไม่เกิน 0.7 ไม่งั้นจะตอบมั่ว
- `repeat_penalty` สูงเกิน 1.1 จะตอบกวนแบบไม่สุภาพ

ถ้าอยากลองโมเดลอื่น:
```bash
MODEL=qwen2.5:7b .venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8000
```
(`qwen2.5:7b` ไม่ต้องกังวลเรื่องหลุดจีนเท่า แต่จะกวนน้อยกว่า)

## ฟีเจอร์ในแอป

- **เมนูข้าง (drawer)** — รายการประวัติแชททั้งหมด เปิดด้วยปุ่ม ☰ มุมซ้ายบน
- **ประวัติแชตถาวร** — ปิดแอปแล้วแชทยังอยู่ เก็บได้ 50 ห้อง (เก่าสุดถูกตัดทิ้ง)
- **สร้างแชทใหม่** — ปุ่ม ➕ ในเมนูข้างหรือบน AppBar
- **เปิดแชทย้อนหลัง** — แตะรายการในเมนูข้าง ชื่อแชทมาจากข้อความแรกที่พิมพ์
- **ลบแชท** — กด ✕ ที่รายการ มี dialog ยืนยันก่อน
- **streaming** — ข้อความโผล่ทีละชิ้น ไม่ต้องรอเต็มข้อความ
- **ปุ่มหยุด** — กด ⏹ ตอน AI กำลังตอบเพื่อยกเลิก
- **thinking dots** — จุดสามจุดเต้นขึ้นลงตอน AI คิด
- **สลับแชทระหว่างรอ** — ถ้าสลับไปแชทอื่นขณะ AI ตอบ คำตอบจะไม่หลุดมาผินแชท

## Android Studio

### เปิดโปรเจกต์

1. เปิด Android Studio → **File → Open**
2. เลือกโฟลเดอร์ `Chatbot` (โฟลเดอร์ที่มี `pubspec.yaml`) — **อย่าเลือกเข้าไปใน `android/`**
3. รอให้ Gradle sync เสร็จ (ครั้งแรกนาน 2-5 นาที)

### ⚠️ ต้องติดตั้ง Flutter plugin ก่อน

Android Studio ไม่ได้มี Flutter plugin มาให้ในตัว ถ้าเปิดแล้วเห็นแต่โปรเจกต์ Kotlin ธรรมดา
แปลว่ายังไม่ได้ติดตั้ง:

1. **Settings** (`Cmd+,`) → **Plugins**
2. ค้นหา **Flutter** → **Install** → ตกลง Restart
3. เปิดโปรเจกต์ใหม่หลัง restart

### ⚙️ ตั้ง Flutter SDK path

ถ้า Android Studio ถามหา Flutter SDK ให้ใส่ path นี้:

```
/opt/homebrew/share/flutter
```

ดู path ปัจจุบันได้ด้วย:
```bash
cd "$(dirname $(which flutter))/.." && pwd -P
```

### Run configuration

ต้องส่ง `--dart-define=API_URL=...` ทุกครั้ง ไม่งั้นจะต่อ backend ไม่ได้

**Run → Edit Configurations → + → Flutter**

| ช่อง | ค่า (สำหรับ emulator) |
|---|---|
| Name | `Emulator (10.0.2.2)` |
| Target platform | `android-emulator` |
| Additional args | `--dart-define=API_URL=http://10.0.2.2:8000/chat/stream` |

ถ้าจะรันบนมือถือจริง ให้สร้างอีกตัวเป้าหมาย `android-arm64` และใช้ LAN IP แทน
(`ipconfig getifaddr en1`)

> `.idea/runConfigurations/` อยู่ใน `.gitignore` จึงไม่ถูก push ขึ้น GitHub
> คนอื่นที่ clone มาต้องสร้าง config เองตามข้างบน

## VS Code

โปรเจกต์ตั้งค่าไว้ให้แล้ว เปิดด้วย:
```bash
code .
```
แล้ว `Cmd+Shift+P` → **Developer: Reload Window** (ครั้งแรก)

### Run / Debug

เลือกจาก dropdown มุมขวาบนแล้วกด ▶ หรือ 🐛:

| Config | ใช้ทำอะไร |
|---|---|
| `1. Debug` | เลือกเครื่องเองตอนกด run (ต่อมือถือสลับไปมา) |
| `2. Debug (Android)` | Android emulator (ใช้ `10.0.2.2`) |
| `3. Debug (macOS)` | ทดสอบในเครื่อง (ต้องมี Xcode) |
| `4. Debug (Chrome)` | ทดสอบ logic ในเบราว์เซอร์ |
| `5. Release (macOS)` | เช็คว่า compile ผ่านจริง |

ทุก config ส่ง `--dart-define=API_URL=...` ให้อัตโนมัติ ไม่ต้องพิมพ์เอง

### ⚠️ IP ต่างกันตามเป้าหมาย

| เป้าหมาย | URL ที่ใช้ |
|---|---|
| Android emulator | `http://10.0.2.2:8000` ← **ทางลัดไป host** |
| มือถือ Android จริง | `http://<IP-ของคอม>:8000` |
| macOS / Chrome | `http://<IP-ของคอม>:8000` |

emulator ใช้ `10.0.2.2` เสมอ ไม่ต้องตาม IP คอม ทำให้ไม่ต้องแก้ตอนเปลี่ยนเน็ต

ถ้าเปลี่ยน IP คอม ต้องแก้ `API_URL` ใน `.vscode/launch.json` (เฉพาะ config ที่ใช้ LAN IP)
ดู IP ใหม่: `ipconfig getifaddr en1`

### Tasks

`Cmd+Shift+P` → **Tasks: Run Task**:

| Task | ทำอะไร |
|---|---|
| `Start Backend` | รัน uvicorn (รันอัตโนมัติตอนเปิดโฟลเดอร์) |
| `Backend + Flutter (macOS)` | รันทั้งคู่พร้อมกัน |
| `Ollama: Start` | เปิดแอป Ollama |
| `Ollama: Pull Model` | ดาวน์โหลด gemma2:9b |
| `Test: Flutter` | รันเทสต์ |
| `Analyze` | ตรวจ code ด้วย analyzer |

## Android Emulator

ติดตั้งไว้แล้วชื่อ `simsimi_api36` (Pixel 7, Android 16)

เปิดใหม่:
```bash
export ANDROID_HOME=~/Library/Android/sdk
$ANDROID_HOME/emulator/emulator -avd simsimi_api36
```

เช็คว่าบูตเสร็จ:
```bash
export ANDROID_HOME=~/Library/Android/sdk
$ANDROID_HOME/platform-tools/adb devices   # ต้องขึ้น "device" ไม่ใช่ "offline"
```

> **หมายเหตุ**: ถ้าเจอ dialog "Google Play services isn't responding" ซ้ำ ๆ
> แปลว่า system image แบบ `google_apis` มีปัญหา (ไม่เกี่ยวกับแอป)
> ให้สร้าง AVD ใหม่ด้วย image แบบ AOSP ที่ไม่มี Play services:
>
> ```bash
> export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
> export ANDROID_HOME=~/Library/Android/sdk
> export PATH=$PATH:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin
>
> sdkmanager "system-images;android-36;default;arm64-v8a"
> echo "no" | avdmanager create avd -n simsimi_aosp -k "system-images;android-36;default;arm64-v8a" -d pixel_7
> $ANDROID_HOME/emulator/emulator -avd simsimi_aosp
> ```
>
> แอปนี้ไม่ต้องใช้ Play services เลย จึงใช้ image ตัวไหนก็ได้

## Debug

`server.py` เปิด debug logging ไว้แล้ว (`DEBUG = True` บรรทัดบนสุด)
จะเห็น log ใน terminal ตอนมือถือส่งข้อความ:

```
15:37:42 [INFO] 127.0.0.1 - "POST /chat/stream HTTP/1.1" 200 OK
🐛 DEBUG: POST /chat/stream ได้รับ 2 ข้อความ
🐛 DEBUG: ส่งให้ Ollama 3 messages (รวม system prompt)
🐛 DEBUG: stream จบใน 3.42s (28 ตัวอักษร): 'วันนี้เป็นไงบ้างจ้ะ'
```

ปิด debug ได้ด้วย `DEBUG = False`

ทดสอบ streaming จาก terminal:
```bash
curl -N -X POST http://localhost:8000/chat/stream \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"สวัสดี"}]}'
```

## การล้างข้อความ (`clean_reply`)

โมเดลหลายตัว (รวมถึง gemma2) มักปล่อย escape sequence ออกมาเป็น**ข้อความดิบ**
เช่น `ชอบกินข้าว\u200d` หรือ `สวัสดี\n\n\n` ทำให้ผู้ใช้เห็นตัวอักษรแปลก ๆ ในแชท

`clean_reply()` ใน `server.py` ล้างให้:
- `\n` `\t` `\r` → ช่องว่าง
- `\uXXXX` → อักขระจริง
- อักขระ zero-width ที่ไม่มีความหมาย (`\u200b`, `\u202e`, BOM)
- ZWJ (`\u200d`) ที่ไม่ได้เชื่อมอีโมจิจริง — **เก็บตัวที่อยู่ระหว่างอีโมจิไว้** เพื่อไม่ให้ 👨‍👩‍👧 พัง
- ช่องว่างซ้ำ และช่องว่างหัวท้าย

## ข้อจำกัดตอนนี้

- แชทไม่ถูกเก็บ ปิดแอปแล้วหาย
- ประวัติส่งครั้งละ 20 ข้อความล่าสุด
- ยังไม่มีการป้องกัน prompt injection แบบลึก (ตอนนี้กรอง role ที่ไม่ใช่ user/assistant ออกแล้ว)
- `usesCleartextTraffic` + `NSAllowsLocalNetworking` เปิดไว้เพื่อ dev เท่านั้น ถ้าจะ deploy ต้องใช้ HTTPS แล้วปิดสองค่านี้

## ต้องมี Xcode สำหรับเป้าหมาย Apple

รันบน Chrome ได้เลย แต่ถ้าจะรันบน macOS / iOS ต้องติดตั้ง Xcode จาก
https://developer.apple.com/xcode/ (ถ้ามีแค่ Command Line Tools จะขึ้นว่า
`Error: Xcode not installed`)