from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    APP_ENV: str = "dev"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000

    # Auth
    JWT_SECRET: str = "CHANGE_ME"
    JWT_EXPIRES_MINUTES: int = 60 * 24 * 30  # 30 days

    # DB
    DATABASE_URL: str

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Supabase (optional for development)
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # Models
    WHISPER_MODEL: str = "openai/whisper-large-v3"
    LLM_MODEL: str = "mistralai/Mistral-7B-Instruct-v0.2"


settings = Settings()
