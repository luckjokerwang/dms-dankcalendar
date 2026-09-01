"""
provider_service.py
Service for LLM provider configuration, preset management, model discovery, and connection testing.
"""

import os
import json
import time
import urllib.request
import urllib.error
import ssl
from typing import Dict, Any, List, Optional
from .types import ProviderConfig, ProviderStoreConfig

CONFIG_DIR = os.path.expanduser("~/.config/dms-ai")
CONFIG_FILE = os.path.join(CONFIG_DIR, "providers.json")

PRESET_PROVIDERS: List[Dict[str, Any]] = [
    {
        "id": "deepseek",
        "name": "DeepSeek",
        "baseUrl": "https://api.deepseek.com/v1",
        "icon": "smart_toy",
        "color": "#1565c0",
        "desc": "官方深度推理与排程模型",
        "models": [
            {"id": "deepseek-chat", "name": "DeepSeek-V3", "desc": "通用大模型", "vision": False},
            {"id": "deepseek-reasoner", "name": "DeepSeek-R1", "desc": "深度推理大模型", "vision": False}
        ]
    },
    {
        "id": "siliconflow",
        "name": "硅基流动 (SiliconFlow)",
        "baseUrl": "https://api.siliconflow.cn/v1",
        "icon": "auto_awesome",
        "color": "#7c3aed",
        "desc": "海量开源大模型高速中继",
        "models": [
            {"id": "deepseek-ai/DeepSeek-V3", "name": "DeepSeek V3", "desc": "高速中继", "vision": False},
            {"id": "deepseek-ai/DeepSeek-R1", "name": "DeepSeek R1", "desc": "深度思考中继", "vision": False}
        ]
    },
    {
        "id": "sensenova",
        "name": "商汤日日新 (SenseNova)",
        "baseUrl": "https://token.sensenova.cn/v1",
        "icon": "cloud",
        "color": "#0ea5e9",
        "desc": "商汤日日新官方大模型端点",
        "models": [
            {"id": "SenseChat-5", "name": "SenseChat 5.0", "desc": "旗舰模型", "vision": False},
            {"id": "SenseChat-5-Cantonese", "name": "SenseChat 5.0 粤语版", "desc": "多语言方言", "vision": False}
        ]
    },
    {
        "id": "qwen",
        "name": "通义千问 (DashScope)",
        "baseUrl": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "icon": "cloud",
        "color": "#ff6a00",
        "desc": "阿里云通义千问官方兼容端点",
        "models": [
            {"id": "qwen-plus", "name": "通义千问 Plus", "desc": "主力模型", "vision": False},
            {"id": "qwen-turbo", "name": "通义千问 Turbo", "desc": "极速推理", "vision": False},
            {"id": "qwen-max", "name": "通义千问 Max", "desc": "深度规划", "vision": False}
        ]
    },
    {
        "id": "openai",
        "name": "OpenAI",
        "baseUrl": "https://api.openai.com/v1",
        "icon": "psychology",
        "color": "#10a37f",
        "desc": "GPT-4o / o1 / o3 官方接口",
        "models": [
            {"id": "gpt-4o", "name": "GPT-4o", "desc": "全能多模态", "vision": True},
            {"id": "gpt-4o-mini", "name": "GPT-4o Mini", "desc": "极速轻量", "vision": True}
        ]
    },
    {
        "id": "claude",
        "name": "Anthropic Claude",
        "baseUrl": "https://api.anthropic.com/v1",
        "icon": "auto_awesome",
        "color": "#d97706",
        "desc": "Claude 3.7 Sonnet 官方与代理接口",
        "models": [
            {"id": "claude-3-7-sonnet-20250219", "name": "Claude 3.7 Sonnet", "desc": "混合推理", "vision": True},
            {"id": "claude-3-5-haiku-20241022", "name": "Claude 3.5 Haiku", "desc": "极速响应", "vision": True}
        ]
    },
    {
        "id": "gemini",
        "name": "Google Gemini",
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai/",
        "icon": "bolt",
        "color": "#4285f4",
        "desc": "Gemini 2.0 Flash / Pro 官方接口",
        "models": [
            {"id": "gemini-2.0-flash", "name": "Gemini 2.0 Flash", "desc": "新一代多模态", "vision": True},
            {"id": "gemini-2.0-pro-exp-02-05", "name": "Gemini 2.0 Pro", "desc": "高级规划推理", "vision": True}
        ]
    },
    {
        "id": "ollama",
        "name": "Ollama (本地)",
        "baseUrl": "http://localhost:11434/v1",
        "icon": "terminal",
        "color": "#212121",
        "desc": "本地离线私有化模型服务",
        "models": [
            {"id": "deepseek-r1:latest", "name": "DeepSeek-R1 (Local)", "desc": "本地离线推理", "vision": False},
            {"id": "qwen2.5:latest", "name": "Qwen 2.5 (Local)", "desc": "本地通用", "vision": False}
        ]
    },
    {
        "id": "openrouter",
        "name": "OpenRouter",
        "baseUrl": "https://openrouter.ai/api/v1",
        "icon": "hub",
        "color": "#6366f1",
        "desc": "全网大模型聚合路由",
        "models": []
    },
    {
        "id": "agnes",
        "name": "Agnes AI",
        "baseUrl": "https://apihub.agnes-ai.com/v1",
        "icon": "flash_on",
        "color": "#e65100",
        "desc": "Agnes 高速排程专用中继",
        "models": [
            {"id": "agnes-2.5-flash", "name": "Agnes 2.5 Flash", "desc": "高速排程 (推荐)", "vision": True},
            {"id": "agnes-2.5-pro", "name": "Agnes 2.5 Pro", "desc": "复杂深度规划", "vision": True}
        ]
    },
    {
        "id": "custom",
        "name": "自定义兼容端点",
        "baseUrl": "http://localhost:8000/v1",
        "icon": "tune",
        "color": "#546e7a",
        "desc": "兼容 OpenAI 规范的私有化端点",
        "models": []
    }
]

class ProviderService:
    @staticmethod
    def ensure_config_dir():
        os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)

    @classmethod
    def load_config(cls) -> ProviderStoreConfig:
        cls.ensure_config_dir()
        if not os.path.exists(CONFIG_FILE):
            default_cfg: ProviderStoreConfig = {
                "activeProvider": "agnes",
                "activeModel": "agnes-2.5-flash",
                "providers": [
                    {
                        "id": "agnes",
                        "name": "Agnes AI",
                        "baseUrl": "https://apihub.agnes-ai.com/v1",
                        "apiKey": "",
                        "enabled": True,
                        "icon": "flash_on",
                        "color": "#e65100",
                        "models": [
                            {"id": "agnes-2.5-flash", "name": "Agnes 2.5 Flash", "desc": "高速排程 (推荐)"},
                            {"id": "agnes-2.5-pro", "name": "Agnes 2.5 Pro", "desc": "复杂深度规划"}
                        ]
                    }
                ]
            }
            cls.save_config(default_cfg)
            return default_cfg

        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data
        except Exception:
            return {"activeProvider": "agnes", "activeModel": "agnes-2.5-flash", "providers": []}

    @classmethod
    def save_config(cls, cfg: ProviderStoreConfig) -> bool:
        cls.ensure_config_dir()
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=2, ensure_ascii=False)
            os.chmod(CONFIG_FILE, 0o600)
            return True
        except Exception:
            return False

    @classmethod
    def save_provider(cls, provider: ProviderConfig) -> bool:
        cfg = cls.load_config()
        provs = cfg.get("providers", [])
        found = False
        for i, p in enumerate(provs):
            if p.get("id") == provider.get("id"):
                provs[i] = provider
                found = True
                break
        if not found:
            provs.append(provider)
        cfg["providers"] = provs
        return cls.save_config(cfg)

    @classmethod
    def delete_provider(cls, provider_id: str) -> bool:
        cfg = cls.load_config()
        cfg["providers"] = [p for p in cfg.get("providers", []) if p.get("id") != provider_id]
        return cls.save_config(cfg)

    @classmethod
    def set_active(cls, provider_id: Optional[str] = None, model_id: Optional[str] = None) -> bool:
        cfg = cls.load_config()
        if provider_id:
            cfg["activeProvider"] = provider_id
        if model_id:
            cfg["activeModel"] = model_id
        return cls.save_config(cfg)

    @classmethod
    def fetch_models(cls, provider_id: str, custom_base_url: Optional[str] = None, custom_api_key: Optional[str] = None) -> Dict[str, Any]:
        cfg = cls.load_config()
        target_prov = None
        for p in cfg.get("providers", []):
            if p.get("id") == provider_id:
                target_prov = p
                break

        base_url = custom_base_url or (target_prov.get("baseUrl") if target_prov else "")
        api_key = custom_api_key or (target_prov.get("apiKey") if target_prov else "")

        if not base_url:
            for preset in PRESET_PROVIDERS:
                if preset["id"] == provider_id:
                    base_url = preset["baseUrl"]
                    break

        if not base_url:
            return {"status": "error", "message": "缺少 API Base URL 地址"}

        clean_base = base_url.rstrip("/")
        models_url = f"{clean_base}/models"

        headers = {
            "User-Agent": "DankCalendar/3.0",
            "Accept": "application/json"
        }
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        start_time = time.time()
        ctx = ssl.create_default_context()
        req = urllib.request.Request(models_url, headers=headers)

        try:
            with urllib.request.urlopen(req, context=ctx, timeout=8) as resp:
                latency = int((time.time() - start_time) * 1000)
                body = resp.read().decode("utf-8")
                data = json.loads(body)
                raw_models = []
                if isinstance(data, dict):
                    raw_models = data.get("data") or data.get("models") or []
                elif isinstance(data, list):
                    raw_models = data

                # Build vision map from target provider or presets
                existing_vision_map: Dict[str, bool] = {}
                if target_prov:
                    for em in target_prov.get("models", []):
                        if em.get("id"):
                            existing_vision_map[em["id"]] = em.get("vision", False)
                for preset in PRESET_PROVIDERS:
                    for pm in preset.get("models", []):
                        if pm.get("id") and pm["id"] not in existing_vision_map:
                            existing_vision_map[pm["id"]] = pm.get("vision", False)

                parsed_models = []
                for m in raw_models:
                    if isinstance(m, dict) and "id" in m:
                        m_id = m["id"]
                        is_vision = existing_vision_map.get(m_id, False)
                        parsed_models.append({
                            "id": m_id,
                            "name": m.get("name") or m_id,
                            "desc": f"上下文: {m.get('context_length')}" if m.get('context_length') else "通用大模型",
                            "vision": is_vision
                        })
                    elif isinstance(m, str):
                        is_vision = existing_vision_map.get(m, False)
                        parsed_models.append({"id": m, "name": m, "desc": "通用大模型", "vision": is_vision})

                return {
                    "status": "ok",
                    "latency": latency,
                    "count": len(parsed_models),
                    "models": parsed_models
                }
        except urllib.error.HTTPError as e:
            err_body = ""
            try:
                err_body = e.read().decode("utf-8", errors="replace")
                err_json = json.loads(err_body)
                err_msg = err_json.get("error", {}).get("message") or str(err_json)
            except Exception:
                err_msg = err_body or str(e)
            return {"status": "error", "message": f"HTTP {e.code}: {err_msg}"}
        except Exception as e:
            return {"status": "error", "message": f"连接失败: {str(e)}"}

    @classmethod
    def benchmark_model(
        cls,
        model_id: str,
        provider_id: Optional[str] = None,
        custom_base_url: Optional[str] = None,
        custom_api_key: Optional[str] = None,
        timeout: float = 12.0
    ) -> Dict[str, Any]:
        cfg = cls.load_config()
        target_prov = None
        if provider_id:
            for p in cfg.get("providers", []):
                if p.get("id") == provider_id:
                    target_prov = p
                    break

        if not target_prov and not custom_base_url:
            for p in cfg.get("providers", []):
                for m in p.get("models", []):
                    if m.get("id") == model_id:
                        target_prov = p
                        break
                if target_prov:
                    break

        base_url = custom_base_url or (target_prov.get("baseUrl") if target_prov else "")
        api_key = custom_api_key or (target_prov.get("apiKey") if target_prov else "")

        if not base_url and provider_id:
            for preset in PRESET_PROVIDERS:
                if preset["id"] == provider_id:
                    base_url = preset["baseUrl"]
                    break

        if not base_url:
            return {"status": "error", "model": model_id, "message": "缺少 API Base URL 地址"}

        clean_base = base_url.rstrip("/")
        req_url = f"{clean_base}/chat/completions"

        headers = {
            "Content-Type": "application/json",
            "Accept": "text/event-stream, application/json",
            "User-Agent": "DankCalendar/3.0"
        }
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        payload = {
            "model": model_id,
            "messages": [{"role": "user", "content": "Hi"}],
            "max_tokens": 10,
            "stream": True
        }

        start_time = time.time()
        ttfb = None
        ctx = ssl.create_default_context()
        req = urllib.request.Request(req_url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")

        try:
            with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
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
                                if delta.get("content") and ttfb is None:
                                    ttfb = int((time.time() - start_time) * 1000)
                        except Exception:
                            pass

                total_duration = int((time.time() - start_time) * 1000)
                if ttfb is None:
                    ttfb = total_duration

                return {
                    "status": "ok",
                    "model": model_id,
                    "latency": ttfb,
                    "totalMs": total_duration,
                    "message": f"测速成功: 首字 {ttfb}ms / 总计 {total_duration}ms"
                }
        except urllib.error.HTTPError as e:
            err_body = ""
            try:
                err_body = e.read().decode("utf-8", errors="replace")
                err_json = json.loads(err_body)
                err_msg = err_json.get("error", {}).get("message") or str(err_json)
            except Exception:
                err_msg = err_body or str(e)
            return {"status": "error", "model": model_id, "message": f"HTTP {e.code}: {err_msg}"}
        except Exception as e:
            return {"status": "error", "model": model_id, "message": f"测速失败: {str(e)}"}

