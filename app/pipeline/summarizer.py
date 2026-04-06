from __future__ import annotations

from dataclasses import dataclass
from typing import List

from .llm import generate_text


@dataclass
class SummarizeResult:
    notes_md: str
    summary_md: str


def _chunk_text(text: str, max_chars: int = 12000) -> List[str]:
    text = text.strip()
    if len(text) <= max_chars:
        return [text]
    chunks = []
    start = 0
    while start < len(text):
        end = min(len(text), start + max_chars)
        chunks.append(text[start:end])
        start = end
    return chunks


def _llm_generate(prompt: str, model_name: str, max_new_tokens: int = 900) -> str:
    return generate_text(
        prompt=prompt,
        model_name=model_name,
        max_new_tokens=max_new_tokens,
        temperature=0.0,
        repetition_penalty=1.05,
    )


def summarize_lecture(transcript: str, model_name: str) -> SummarizeResult:
    """
    Produces:
    - notes_md: detailed, structured lecture notes
    - summary_md: short summary
    """
    transcript = transcript.strip()
    if len(transcript) < 40:
        return SummarizeResult(
            notes_md="## Notes\n\n(Not enough transcript to summarize.)",
            summary_md="## Summary\n\n(Not enough transcript to summarize.)",
        )

    chunks = _chunk_text(transcript, max_chars=12000)

    # 1) Create per-chunk notes
    chunk_notes = []
    for i, ch in enumerate(chunks, start=1):
        prompt = f"""
You are an expert note-taker for college lectures.

Task:
Convert the transcript into detailed, structured Markdown notes.

Rules:
- Use short mobile-friendly Markdown sections and bullet points.
- Prefer headings, bullet points, definitions, examples, steps, and formulas if present.
- Do NOT use markdown tables.
- For comparisons, use labeled bullet lists instead of table format.
- Keep it readable and complete ("what teacher taught").
- Do NOT invent content.
- If the transcript is messy (Thanglish, code-switching), infer meaning but stay faithful.

Transcript chunk ({i}/{len(chunks)}):
\"\"\"{ch}\"\"\"

Output ONLY Markdown notes:
""".strip()
        chunk_notes.append(_llm_generate(prompt, model_name, max_new_tokens=900))

    merged_notes = "\n\n---\n\n".join(chunk_notes).strip()

    # 2) Now summarize the merged notes into short summary
    prompt2 = f"""
You are an expert summarizer.

Task:
Write a short, high-quality Markdown summary (5–10 bullets max) from the lecture notes.

Rules:
- Focus on key concepts, takeaways, and what was covered.
- Keep it concise and easy to scan on mobile.
- Use short bullets and mini-sections only.
- Do NOT use markdown tables.
- Do NOT invent.

Lecture notes:
\"\"\"{merged_notes}\"\"\"

Output ONLY Markdown summary:
""".strip()

    summary = _llm_generate(prompt2, model_name, max_new_tokens=450)

    # Ensure headings exist (nice for UI)
    if not merged_notes.lstrip().startswith("#"):
        merged_notes = "## Notes\n\n" + merged_notes
    if not summary.lstrip().startswith("#"):
        summary = "## Summary\n\n" + summary

    return SummarizeResult(notes_md=merged_notes, summary_md=summary.strip())
