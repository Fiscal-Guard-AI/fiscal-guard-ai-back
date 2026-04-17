from dataclasses import dataclass, field
from datetime import date, datetime

from domain.enums.http_request import HttpRequest
from domain.enums.period_type import PeriodType
from domain.enums.source_type import SourceType


@dataclass
class DownloadConfig:
    id: int
    source_name: str
    destiny_name: str
    description: str
    period_type: PeriodType
    source_type: SourceType
    period: date
    url: str
    http_method: HttpRequest
    cron_expression: str
    params: dict = field(default_factory=dict)
    headers: dict = field(default_factory=dict)
    requires_auth: bool = False
    is_active: bool = True
    last_run_at: datetime | None = None
    next_run_at: datetime | None = None
    last_modification: datetime | None = None
    last_hash: str | None = None

    def should_run(self, now: datetime) -> bool:
        pass

    def mark_as_run(self, now: datetime) -> None:
        pass
