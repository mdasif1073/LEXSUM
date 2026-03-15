from __future__ import annotations

import ast
import json
import re
from typing import Any, Dict, List

from .llm import generate_text


def _extract_json_blob(text: str) -> str:
    """
    Best-effort extraction of a single JSON object from an LLM response.
    Handles code fences and leading/trailing commentary.
    """
    s = text.strip()
    # Strip code fences if present
    if s.startswith("```"):
        s = re.sub(r"^```[a-zA-Z0-9_-]*\s*\n", "", s)
        if s.endswith("```"):
            s = s[: -3]
        s = s.strip()

    # Extract between the first "{" and the last "}"
    start = s.find("{")
    end = s.rfind("}")
    if start != -1 and end != -1 and end > start:
        return s[start : end + 1].strip()
    return s


def _json_loads_relaxed(raw: str) -> Any:
    """
    Try parsing JSON with a few safe relaxations (trailing commas, python literals).
    """
    s = raw.strip()
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        pass

    # Remove trailing commas like: {"a":1,} or [1,2,]
    s2 = re.sub(r",\s*([}\]])", r"\1", s)
    try:
        return json.loads(s2)
    except json.JSONDecodeError:
        pass

    # Fall back to parsing as a Python literal (handles single quotes, trailing commas)
    py = s2
    py = re.sub(r"\bnull\b", "None", py)
    py = re.sub(r"\btrue\b", "True", py, flags=re.IGNORECASE)
    py = re.sub(r"\bfalse\b", "False", py, flags=re.IGNORECASE)
    return ast.literal_eval(py)


def _simple_fallback_quiz(notes_md: str, lecture_id: str, n_mcq: int) -> dict:
    base_text = (notes_md or "").strip()
    lines = [ln.strip("-• ").strip() for ln in base_text.splitlines() if ln.strip()]
    concepts: List[str] = []
    for ln in lines:
        if 12 <= len(ln) <= 120:
            concepts.append(ln)
        if len(concepts) >= n_mcq:
            break
    if not concepts:
        concepts = [base_text[:120] or "Lecture concept"]

    questions: List[dict] = []
    for i, concept in enumerate(concepts[:n_mcq], start=1):
        questions.append(
            {
                "id": f"q{i}",
                "type": "mcq",
                "prompt": f"Which statement best matches this lecture point?\n\n{concept}",
                "options": [
                    "Unrelated option (placeholder)",
                    "Opposite meaning (placeholder)",
                    concept,
                    "Different topic (placeholder)",
                ],
                "answer_index": 2,
                "explanation": "Based on the lecture notes.",
            }
        )

    questions.append(
        {
            "id": f"q{n_mcq+1}",
            "type": "short",
            "prompt": "Write a short answer based on the lecture notes.",
            "ideal_answer": "Answer will vary; use the lecture notes as reference.",
        }
    )

    return {
        "version": 1,
        "lecture_id": lecture_id,
        "generated_by": "fallback",
        "questions": questions,
    }


def _sanitize_quiz_obj(obj: Any, lecture_id: str, n_mcq: int, notes_md: str) -> dict:
    """
    Ensure the object matches the expected schema well enough for the app.
    If it doesn't, fall back to a simple deterministic quiz.
    """
    if not isinstance(obj, dict):
        return _simple_fallback_quiz(notes_md, lecture_id, n_mcq)

    questions = obj.get("questions")
    if not isinstance(questions, list):
        return _simple_fallback_quiz(notes_md, lecture_id, n_mcq)

    # Normalize questions and enforce counts
    mcqs: List[Dict[str, Any]] = []
    shorts: List[Dict[str, Any]] = []
    for q in questions:
        if not isinstance(q, dict):
            continue
        qtype = str(q.get("type") or "").strip().lower()
        if qtype == "mcq":
            mcqs.append(q)
        elif qtype == "short":
            shorts.append(q)

    if len(mcqs) < 1:
        return _simple_fallback_quiz(notes_md, lecture_id, n_mcq)

    mcqs = mcqs[:n_mcq]
    short_q = shorts[0] if shorts else {}

    out_questions: List[dict] = []
    # MCQs
    for i, q in enumerate(mcqs, start=1):
        prompt = str(q.get("prompt") or f"Question {i}").strip()
        options = q.get("options")
        if isinstance(options, dict):
            # allow {"A":"..","B":"..",...}
            options = [options.get(k) for k in ("A", "B", "C", "D")]
        if not isinstance(options, list):
            options = []
        opts = [str(x).strip() for x in options if x is not None and str(x).strip()]
        # pad/trim to 4 options
        while len(opts) < 4:
            opts.append(f"Option {len(opts)+1}")
        opts = opts[:4]

        ai = q.get("answer_index")
        try:
            answer_index = int(ai)
        except Exception:
            answer_index = 0
        if answer_index < 0 or answer_index > 3:
            answer_index = 0

        explanation = str(q.get("explanation") or "").strip()
        if not explanation:
            explanation = "Based on the lecture notes."

        out_questions.append(
            {
                "id": str(q.get("id") or f"q{i}"),
                "type": "mcq",
                "prompt": prompt,
                "options": opts,
                "answer_index": answer_index,
                "explanation": explanation,
            }
        )

    # Short answer
    short_prompt = str(short_q.get("prompt") or "Short answer question").strip()
    ideal = str(short_q.get("ideal_answer") or "Answer will vary; use the lecture notes as reference.").strip()
    out_questions.append(
        {
            "id": str(short_q.get("id") or f"q{len(out_questions)+1}"),
            "type": "short",
            "prompt": short_prompt,
            "ideal_answer": ideal,
        }
    )

    return {
        "version": 1,
        "lecture_id": lecture_id,
        "generated_by": str(obj.get("generated_by") or "llm"),
        "questions": out_questions,
    }


def generate_quiz_json(notes_md: str, lecture_id: str, model_name: str, n_mcq: int = 5) -> str:
    """
    Returns JSON string with:
    {
      "version": 1,
      "lecture_id": "...",
      "questions": [
        {"id":"q1","type":"mcq","prompt":"...","options":["A","B","C","D"],"answer_index":2,"explanation":"..."},
        {"id":"q2","type":"short","prompt":"...","ideal_answer":"..."}
      ]
    }
    """
    prompt = f"""
Create a quiz from the lecture notes.

Requirements:
- Output STRICT JSON only.
- Include exactly {n_mcq} MCQ questions + 1 short-answer question.
- Each MCQ must have 4 options and "answer_index" (0-3) and "explanation".
- Short-answer must have "ideal_answer".
- Do NOT include markdown, no extra text.

Schema:
{{
  "version": 1,
  "lecture_id": "{lecture_id}",
  "questions": [
    {{
      "id": "q1",
      "type": "mcq",
      "prompt": "question text",
      "options": ["A","B","C","D"],
      "answer_index": 0,
      "explanation": "why"
    }},
    {{
      "id": "qX",
      "type": "short",
      "prompt": "question text",
      "ideal_answer": "answer"
    }}
  ]
}}

Lecture notes:
\"\"\"{notes_md}\"\"\"
""".strip()

    raw = generate_text(
        prompt=prompt,
        model_name=model_name,
        max_new_tokens=700,
        temperature=0.0,
        repetition_penalty=1.05,
    )

    candidate = _extract_json_blob(raw)

    try:
        obj = _json_loads_relaxed(candidate)
    except Exception:
        # One retry: ask the model to repair its output into strict JSON.
        repair_prompt = f"""
You are a strict JSON repair tool.

Task:
Fix the following into STRICT JSON only, matching this exact schema:
- Exactly {n_mcq} MCQ questions + 1 short-answer question
- lecture_id MUST be "{lecture_id}"
- No markdown, no code fences, no extra text

Schema:
{{
  "version": 1,
  "lecture_id": "{lecture_id}",
  "questions": [
    {{
      "id": "q1",
      "type": "mcq",
      "prompt": "question text",
      "options": ["A","B","C","D"],
      "answer_index": 0,
      "explanation": "why"
    }},
    {{
      "id": "qX",
      "type": "short",
      "prompt": "question text",
      "ideal_answer": "answer"
    }}
  ]
}}

Bad output:
{candidate}
""".strip()

        fixed = generate_text(
            prompt=repair_prompt,
            model_name=model_name,
            max_new_tokens=700,
            temperature=0.0,
            repetition_penalty=1.05,
        )
        candidate2 = _extract_json_blob(fixed)
        try:
            obj = _json_loads_relaxed(candidate2)
        except Exception:
            obj = _simple_fallback_quiz(notes_md, lecture_id, n_mcq)

    sanitized = _sanitize_quiz_obj(obj, lecture_id, n_mcq, notes_md)
    return json.dumps(sanitized, ensure_ascii=False)
