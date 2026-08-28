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
        "models": []
    },
    {
        "id": "siliconflow",
        "name": "硅基流动 (SiliconFlow)",
        "baseUrl": "https://api.siliconflow.cn/v1",
        "icon": "auto_awesome",
        "color": "#7c3aed",
        "desc": "海量开源大模型高速中继",
        "models": []
    },
    {
        "id": "sensenova",
        "name": "商汤日日新 (SenseNova)",
        "baseUrl": "https://token.sensenova.cn/v1",
        "icon": "cloud",
        "color": "#0ea5e9",
        "desc": "商汤日日新官方大模型端点",
        "models": []
    },
    {
        "id": "qwen",
        "name": "通义千问 (DashScope)",
        "baseUrl": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "icon": "cloud",
        "color": "#ff6a00",
        "desc": "阿里云通义千问官方兼容端点",
        "models": []
    },
    {
        "id": "openai",
        "name": "OpenAI",
        "baseUrl": "https://api.openai.com/v1",
        "icon": "psychology",
        "color": "#10a37f",
        "desc": "GPT-4o / o1 / o3 官方接口",
        "models": []
    },
    {
        "id": "claude",
        "name": "Anthropic Claude",
        "baseUrl": "https://api.anthropic.com/v1",
        "icon": "auto_awesome",
        "color": "#d97706",
        "desc": "Claude 3.7 Sonnet 官方与代理接口",
        "models": []
    },
    {
        "id": "gemini",
        "name": "Google Gemini",
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai/",
        "icon": "bolt",
        "color": "#4285f4",
        "desc": "Gemini 2.0 Flash / Pro 官方接口",
        "models": []
    },
    {
        "id": "ollama",
        "name": "Ollama (本地)",
        "baseUrl": "http://localhost:11434/v1",
        "icon": "terminal",
        "color": "#212121",
        "desc": "本地离线私有化模型服务",
        "models": []
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
        "models": []
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

                parsed_models = []
                for m in raw_models:
                    if isinstance(m, dict) and "id" in m:
                        m_id = m["id"]
                        parsed_models.append({
                            "id": m_id,
                            "name": m.get("name") or m_id,
                            "desc": f"上下文: {m.get('context_length')}" if m.get('context_length') else "通用大模型"
                        })
                    elif isinstance(m, str):
                        parsed_models.append({"id": m, "name": m, "desc": "通用大模型"})

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
