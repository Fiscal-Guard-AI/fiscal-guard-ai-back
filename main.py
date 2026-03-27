from fastapi import FastAPI
from src.adapters.inbound.api.health_router import router as health_router

app = FastAPI(
    title="Fiscal Guard AI",
    description="Ingestão e processamento de dados abertos do governo federal brasileiro",
    version="0.1.0",
)

app.include_router(health_router)
