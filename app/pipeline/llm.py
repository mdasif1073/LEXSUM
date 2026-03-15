from __future__ import annotations

from functools import lru_cache


@lru_cache(maxsize=2)
def _get_llm(model_name: str):
    from transformers import AutoTokenizer, AutoModelForCausalLM  # type: ignore
    import torch  # type: ignore

    tok = AutoTokenizer.from_pretrained(model_name, use_fast=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
        device_map="auto",
        low_cpu_mem_usage=True,
    )
    model.eval()

    # Ensure pad token is set to avoid generate() warnings
    if tok.pad_token_id is None and tok.eos_token_id is not None:
        tok.pad_token = tok.eos_token

    return tok, model


def _format_prompt(tok, prompt: str) -> str:
    # Use chat template when available (e.g., Mistral Instruct)
    if hasattr(tok, "apply_chat_template"):
        messages = [{"role": "user", "content": prompt}]
        return tok.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    return prompt


def generate_text(
    prompt: str,
    model_name: str,
    max_new_tokens: int = 900,
    temperature: float = 0.0,
    repetition_penalty: float = 1.05,
) -> str:
    tok, model = _get_llm(model_name)
    formatted = _format_prompt(tok, prompt)

    inputs = tok(formatted, return_tensors="pt").to(model.device)

    import torch  # type: ignore

    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=temperature > 0,
            temperature=temperature,
            repetition_penalty=repetition_penalty,
            pad_token_id=tok.eos_token_id,
        )

    gen_ids = out[0][inputs["input_ids"].shape[1] :]
    return tok.decode(gen_ids, skip_special_tokens=True).strip()
