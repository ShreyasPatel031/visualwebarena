from typing import Any

import tiktoken
from transformers import LlamaTokenizer  # type: ignore


# Fallback encodings for models not in older tiktoken's encoding_for_model
# o200k_base is for gpt-4o (newer tiktoken); cl100k_base is universal fallback
OPENAI_MODEL_ENCODINGS = {
    "gpt-4o": ["o200k_base", "cl100k_base"],
    "gpt-4o-mini": ["o200k_base", "cl100k_base"],
    "gpt-5.2": ["o200k_base", "cl100k_base"],
    "gpt-5.2-chat-latest": ["o200k_base", "cl100k_base"],
    "gpt-5.2-pro": ["o200k_base", "cl100k_base"],
}


class Tokenizer(object):
    def __init__(self, provider: str, model_name: str) -> None:
        if provider == "openai":
            try:
                self.tokenizer = tiktoken.encoding_for_model(model_name)
            except KeyError:
                encodings = OPENAI_MODEL_ENCODINGS.get(
                    model_name, ["cl100k_base"]
                )
                if isinstance(encodings, str):
                    encodings = [encodings]
                self.tokenizer = None
                for enc in encodings:
                    try:
                        self.tokenizer = tiktoken.get_encoding(enc)
                        break
                    except (KeyError, ValueError):
                        continue
                if self.tokenizer is None:
                    self.tokenizer = tiktoken.get_encoding("cl100k_base")
        elif provider == "huggingface":
            self.tokenizer = LlamaTokenizer.from_pretrained(model_name)
            # turn off adding special tokens automatically
            self.tokenizer.add_special_tokens = False  # type: ignore[attr-defined]
            self.tokenizer.add_bos_token = False  # type: ignore[attr-defined]
            self.tokenizer.add_eos_token = False  # type: ignore[attr-defined]
        elif provider == "google":
            self.tokenizer = None  # Not used for input length computation, as Gemini is based on characters
        else:
            raise NotImplementedError

    def encode(self, text: str) -> list[int]:
        return self.tokenizer.encode(text)

    def decode(self, ids: list[int]) -> str:
        return self.tokenizer.decode(ids)

    def __call__(self, text: str) -> list[int]:
        return self.tokenizer.encode(text)
