from enum import StrEnum

class SourceType(StrEnum):
    API = "API"
    CSV = "CSV"
    XLSX = "XLSX"
    ZIP = "ZIP"