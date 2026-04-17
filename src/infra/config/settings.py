from functools import lru_cache

from pydantic import computed_field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Banco de dados
    env: str = "local"

    postgres_user: str = "fiscal_guard"
    postgres_password: str = "fiscal_guard"  # noqa: S105
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "fiscal_guard"

    @computed_field
    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    redis_url: str = "redis://localhost:6379"

    # AWS / LocalStack
    aws_endpoint_url: str | None = None  # None = AWS real; URL = LocalStack
    aws_access_key_id: str = "test"
    aws_secret_access_key: str = "test"  # noqa: S105
    aws_default_region: str = "us-east-1"
    s3_bucket_name: str = "fiscal-guard-data"
    sqs_queue_url: str = "http://localhost:4566/000000000000/fiscal-guard-events"

    # External APIs
    mockserver_url: str = "http://localhost:1080"

    @model_validator(mode="after")
    def set_localstack_defaults(self) -> "Settings":
        """Se ambiente for local e o endpoint não foi sobrescrito, aponta para LocalStack."""
        if self.env == "local" and self.aws_endpoint_url is None:
            self.aws_endpoint_url = "http://localhost:4566"
        return self

    model_config = SettingsConfigDict(case_sensitive=False)


@lru_cache  # singleton instance
def get_settings() -> Settings:
    return Settings()
