"""
ai_service.py
Service for OpenAI-compatible LLM streaming, vision prompt composition, and schedule proposal parsing.
"""

import sys
import os
import json
import ssl
import http.client
import base64
import mimetypes
import datetime
import urllib.request
import urllib.error
import re
from typing import Dict, Any, List, Optional, Tuple
from .provider_service import ProviderService

DEFAULT_SYSTEM_PROMPT = """你是一个内嵌在 Linux 桌面顶栏中的智能日历与待办排程专家 (Dank Calendar Plus AI Assistant)。
你的核心使命是帮助用户从杂乱的文字、笔记或图片中分析需求，主动追问缺失细节，并制作最科学的日程 (Event) 与待办 (Task) 规划。

【分类决策规则】：
1. 📅 日程 (Event)：具有明确的起止时间段（如 14:00-15:30）、强时间独占性、需与他人协同（如会议、约会、就医门诊、课程表、航班火车）。
2. 📋 待办 (Task)：结果导向、关注是否完成、利用碎片时间处理、带截止日期（Due Date）与优先级（如 买牛奶、交周报、阅读章节）。
3. 🔄 复合拆解：当用户提出复杂目标时，合理拆解为“准备待办 (Task)”与“执行日程 (Event)”。

【日期与截止时间严格对齐规则（极度重要）】：
- 待办 (Task) 的截止日期 `due` 必须与该事件发生的具体日期完全一致！
- 如果用户要求安排“明天”的事务，且当前系统时间为 2026-08-25，则明天就是 2026-08-26。
- 此时日程的 start/end 日期为 2026-08-26，待办的 due 也必须是 2026-08-26，绝对不要写成 2026-08-25！

【排程提案输出格式 (必须严格遵守)】：
当信息完备并生成具体排程建议时，请在回复文本最后附带一个 ```json:schedule 格式的代码块（不要有多余字段），格式如下：
```json:schedule
{
  "title": "精炼的主题标题（4-8个汉字，如：明日午休排程 / 图书馆自习安排 / 项目周会规划）",
  "explanation": "简短的一句话排程说明",
  "events": [
    {
      "title": "📚 每日阅读：《原子习惯》",
      "start": "YYYY-MM-DDTHH:MM:SS",
      "end": "YYYY-MM-DDTHH:MM:SS",
      "calendarName": "默认日历"
    }
  ],
  "tasks": [
    {
      "summary": "整理第一章读书笔记",
      "due": "YYYY-MM-DD",
      "priority": 1,
      "calendarName": "默认任务"
    }
  ]
}
```
"""

class AiService:
    @staticmethod
    def get_current_time_str() -> str:
        now = datetime.datetime.now()
        weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return f"{now.strftime('%Y-%m-%d %H:%M:%S')} ({weekdays[now.weekday()]})"

    @staticmethod
    def encode_image(image_path: str) -> Optional[str]:
        if not os.path.exists(image_path):
            return None
        try:
            mime_type, _ = mimetypes.guess_type(image_path)
            if not mime_type:
                mime_type = "image/png"
            with open(image_path, "rb") as f:
                encoded = base64.b64encode(f.read()).decode("utf-8")
                return f"data:{mime_type};base64,{encoded}"
        except Exception:
            return None

    @classmethod
    def resolve_provider_and_model(cls, model_override: Optional[str] = None) -> Tuple[str, str, str]:
        cfg = ProviderService.load_config()
        if model_override:
            for p in cfg.get("providers", []):
                for m in p.get("models", []):
                    if m.get("id") == model_override:
                        return p.get("baseUrl", ""), p.get("apiKey", ""), model_override
        active_p_id = cfg.get("activeProvider", "agnes")
        active_m_id = cfg.get("activeModel", "agnes-2.5-flash")
        for p in cfg.get("providers", []):
            if p.get("id") == active_p_id:
                return p.get("baseUrl", ""), p.get("apiKey", ""), (model_override or active_m_id)
        return "https://apihub.agnes-ai.com/v1", "", (model_override or "agnes-2.5-flash")

    @classmethod
    def stream_chat(
        cls,
        messages: List[Dict[str, Any]],
        model_override: Optional[str] = None,
        custom_system_prompt: Optional[str] = None
    ):
        base_url, api_key, model_name = cls.resolve_provider_and_model(model_override)
        time_str = cls.get_current_time_str()
        sys_prompt = (custom_system_prompt or DEFAULT_SYSTEM_PROMPT) + f"\n\n【当前系统真实时间】：{time_str}\n请所有排程与计算均以此时间为基准。"

        formatted_messages = [{"role": "system", "content": sys_prompt}]
        for m in messages:
            role = m.get("role", "user")
            content = m.get("content", "")
            img_path = m.get("imagePath")
            if img_path and role == "user":
                img_data = cls.encode_image(img_path)
                if img_data:
                    formatted_messages.append({
                        "role": "user",
                        "content": [
                            {"type": "text", "text": content},
                            {"type": "image_url", "image_url": {"url": img_data}}
                        ]
                    })
                    continue
            formatted_messages.append({"role": role, "content": content})

        clean_base = base_url.rstrip("/")
        req_url = f"{clean_base}/chat/completions"

        headers = {
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "User-Agent": "DankCalendar/3.0"
        }
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        payload = {
            "model": model_name,
            "messages": formatted_messages,
            "stream": True,
            "temperature": 0.3
        }

        ctx = ssl.create_default_context()
        req = urllib.request.Request(req_url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")

        try:
            with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
                accumulated_text = ""
                while True:
                    line_bytes = resp.readline()
                    if not line_bytes:
                        break
                    line = line_bytes.decode("utf-8", errors="replace").strip()
                    if not line:
                        continue
                    if line.startswith("data:"):
                        data_str = line[5:].strip()
                        if data_str == "[DONE]":
                            break
                        try:
                            chunk = json.loads(data_str)
                            choices = chunk.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                text_chunk = delta.get("content", "")
                                if text_chunk:
                                    accumulated_text += text_chunk
                                    print(json.dumps({"type": "chunk", "text": text_chunk}, ensure_ascii=False), flush=True)
                        except Exception:
                            pass

                # Extract proposal if present
                proposal = cls.extract_proposal(accumulated_text)
                print(json.dumps({
                    "type": "done",
                    "fullText": accumulated_text,
                    "proposal": proposal
                }, ensure_ascii=False), flush=True)
        except urllib.error.HTTPError as e:
            err_body = ""
            try:
                err_body = e.read().decode("utf-8", errors="replace")
                err_json = json.loads(err_body)
                err_msg = err_json.get("error", {}).get("message") or str(err_json)
            except Exception:
                err_msg = err_body or str(e)
            print(json.dumps({"type": "error", "message": f"HTTP {e.code}: {err_msg}"}, ensure_ascii=False), flush=True)
        except Exception as e:
            print(json.dumps({"type": "error", "message": f"连接失败: {str(e)}"}, ensure_ascii=False), flush=True)

    @staticmethod
    def extract_proposal(text: str) -> Optional[Dict[str, Any]]:
        m = re.search(r"```json:schedule\s*(\{[\s\S]*?\})\s*```", text)
        if m:
            try:
                return json.loads(m.group(1))
            except Exception:
                pass
        return None

    @classmethod
    def generate_smart_title(cls, payload_dict: Dict[str, Any]) -> str:
        prompt = payload_dict.get("prompt", "")
        if not prompt:
            return "新排程会话"
        clean_prompt = prompt.strip()
        if len(clean_prompt) <= 12:
            return clean_prompt
        return clean_prompt[:12] + "..."
