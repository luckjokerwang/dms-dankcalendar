"""
task_classifier.py
Intelligent Task Classifier using active LLM provider.
Analyzes task content and project context, dynamically generates concise,
meaningful project-level/domain-level tags, and persists tags in SQLite tags.db.
"""

import json
import re
import urllib.request
import urllib.error
import ssl
from typing import Dict, Any, List, Optional, Tuple

from .tag_service import TagService
from .provider_service import ProviderService

class TaskClassifier:
    @classmethod
    def _call_llm_json(cls, prompt: str, model_override: Optional[str] = None) -> Optional[str]:
        """Calls the configured LLM provider and returns the raw response text."""
        base_url, api_key, model_name = cls._resolve_provider_and_model(model_override)
        clean_base = base_url.rstrip("/")
        req_url = f"{clean_base}/chat/completions"

        messages = [
            {
                "role": "system",
                "content": (
                    "You are a specialized JSON task tagger. "
                    "Analyze the user's tasks and project context, and assign concise, highly informative, "
                    "project-level or domain-level tags (e.g. 'DankCalendar', 'BiliFlow', '音乐', '高数'). "
                    "AVOID generic broad buckets like '工作' or '学习'. "
                    "Respond ONLY with a valid, raw JSON array without markdown formatting."
                )
            },
            {"role": "user", "content": prompt}
        ]

        headers = {
            "Content-Type": "application/json",
            "User-Agent": "DankCalendar/3.0"
        }
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        payload = {
            "model": model_name,
            "messages": messages,
            "temperature": 0.2
        }

        ctx = ssl.create_default_context()
        req = urllib.request.Request(req_url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")

        try:
            with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                choices = data.get("choices", [])
                if choices:
                    return choices[0].get("message", {}).get("content", "").strip()
        except Exception as e:
            return None
        return None

    @classmethod
    def _resolve_provider_and_model(cls, model_override: Optional[str] = None) -> Tuple[str, str, str]:
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
    def classify_single(cls, task_text: str, model_override: Optional[str] = None) -> Dict[str, Any]:
        """
        Classifies a single task text.
        Returns:
            {
                "original": str,
                "cleanSummary": str,
                "tag": str,
                "isNew": bool,
                "taggedSummary": str,
                "color": str,
                "icon": str
            }
        """
        raw_text = (task_text or "").strip()
        existing_tags = TagService.list_tags()
        tag_map = {t["name"]: t for t in existing_tags}

        # Check if already tagged manually by user
        parsed_tags = TagService.extract_tags(raw_text)
        if parsed_tags:
            first_tag = parsed_tags[0]
            clean_sum = TagService.strip_tags(raw_text)
            if first_tag not in tag_map:
                TagService.add_tag(first_tag)
                tag_map = TagService.get_tag_map()
            t_info = tag_map.get(first_tag, {})
            return {
                "original": raw_text,
                "cleanSummary": clean_sum,
                "tag": first_tag,
                "isNew": False,
                "taggedSummary": TagService.inject_tag(clean_sum, first_tag),
                "color": t_info.get("color") or TagService.get_color_for_name(first_tag),
                "icon": t_info.get("icon") or "label"
            }

        # Classify via LLM
        res = cls.classify_batch([{"id": "single", "summary": raw_text}], model_override=model_override)
        if res:
            item = res[0]
            return {
                "original": raw_text,
                "cleanSummary": item["cleanSummary"],
                "tag": item["suggestedTag"],
                "isNew": item["isNew"],
                "taggedSummary": item["taggedSummary"],
                "color": item["color"],
                "icon": item["icon"]
            }

        clean_sum = TagService.strip_tags(raw_text)
        fallback_tag = "待办"
        return {
            "original": raw_text,
            "cleanSummary": clean_sum,
            "tag": fallback_tag,
            "isNew": False,
            "taggedSummary": TagService.inject_tag(clean_sum, fallback_tag),
            "color": tag_map.get(fallback_tag, {}).get("color", "#2563eb"),
            "icon": tag_map.get(fallback_tag, {}).get("icon", "label")
        }

    @classmethod
    def classify_batch(cls, tasks: List[Dict[str, Any]], model_override: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Classifies a list of tasks.
        tasks format: [{"id": "...", "summary": "..."}]
        """
        if not tasks:
            return []

        existing_tags = TagService.list_tags()
        tag_map = TagService.get_tag_map()
        existing_names = [t["name"] for t in existing_tags]
        existing_names_str = ", ".join(f"#{name}" for name in existing_names) if existing_names else "无"

        items_to_classify = []
        for t in tasks:
            tid = str(t.get("id") or "")
            summary = (t.get("summary") or "").strip()
            clean = TagService.strip_tags(summary)
            items_to_classify.append({"id": tid, "summary": clean})

        prompt = f"""请通读以下待办任务，提取出【简单明了、具有具体项目或领域辨识度】的短标签（2~5个字符，纯汉字或英文字符）。

【标签命名规范】：
1. 简单明了、紧扣实际内容：
   - 提取任务中的核心项目名、软件名、学科名或具体主题（例如：涉及日历插件的归为 "DankCalendar" 或 "dcal"；涉及B站扩展的归为 "BiliFlow"；涉及音乐设置的归为 "音乐"；涉及高数课程的归为 "高数"；涉及购物的归为 "生活" 或 "购物"）；
   - 严禁笼统粗暴使用“工作”或“学习”这类无区分度的泛词！
2. 相似聚合：属于同一项目或相关上下文的任务，务必归入相同的标签；
3. 参考已有标签：若已有标签 #{existing_names_str} 中有高度契合的，优先复用；
4. 纯 JSON 输出：严禁任何 Markdown 代码块（如 ```json）或任何多余文字。

【待分类任务列表】：
{json.dumps(items_to_classify, ensure_ascii=False, indent=2)}

【必须输出的标准 JSON 数组示例】：
[
  {{"id": "任务ID", "summary": "任务原标题", "tag": "标签名（不带#）", "isNew": false}}
]"""

        llm_raw = cls._call_llm_json(prompt, model_override=model_override)
        llm_results = {}
        if llm_raw:
            try:
                clean_json_str = re.sub(r'^```(?:json)?\s*', '', llm_raw.strip(), flags=re.IGNORECASE)
                clean_json_str = re.sub(r'\s*```$', '', clean_json_str).strip()
                parsed = json.loads(clean_json_str)
                if isinstance(parsed, list):
                    for item in parsed:
                        tid = str(item.get("id") or "")
                        tag_name = (item.get("tag") or "").strip().lstrip("#").strip()
                        # Clean tag name (max 10 chars, no special symbols)
                        tag_name = re.sub(r'[^\w\u4e00-\u9fa5\-_]', '', tag_name)[:16]
                        if tag_name:
                            llm_results[tid] = {
                                "tag": tag_name,
                                "isNew": tag_name not in tag_map
                            }
            except Exception:
                pass

        results = []
        for t in tasks:
            tid = str(t.get("id") or "")
            raw_summary = (t.get("summary") or "").strip()
            clean_sum = TagService.strip_tags(raw_summary)

            if tid in llm_results:
                tag_name = llm_results[tid]["tag"]
                is_new = llm_results[tid]["isNew"]
            else:
                tag_name = "待办"
                is_new = False

            # Auto-register new tag in SQLite if not existing
            if tag_name not in tag_map:
                TagService.add_tag(tag_name)
                tag_map = TagService.get_tag_map()
                is_new = True

            t_info = tag_map.get(tag_name, {})
            color = t_info.get("color") or TagService.get_color_for_name(tag_name)
            icon = t_info.get("icon") or "label"
            tagged_sum = TagService.inject_tag(clean_sum, tag_name)

            results.append({
                "id": tid,
                "summary": raw_summary,
                "cleanSummary": clean_sum,
                "suggestedTag": tag_name,
                "isNew": is_new,
                "taggedSummary": tagged_sum,
                "color": color,
                "icon": icon
            })

        return results
