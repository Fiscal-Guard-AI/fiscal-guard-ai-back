from fastapi import APIRouter, Depends
from pydantic import BaseModel

from infra.config.settings import Settings, get_settings

router = APIRouter(tags=["Infra"])


class HealthResponse(BaseModel):
    status: str
    environment: str
    postgres_host: str
    redis_url: str
    aws_endpoint_url: str | None
    s3_bucket_name: str


@router.get("/health", response_model=HealthResponse)
def health(settings: Settings = Depends(get_settings)):
    return HealthResponse(
        status="ok",
        environment=settings.env,
        postgres_host=settings.postgres_host,
        redis_url=settings.redis_url,
        aws_endpoint_url=settings.aws_endpoint_url,
        s3_bucket_name=settings.s3_bucket_name,
    )
