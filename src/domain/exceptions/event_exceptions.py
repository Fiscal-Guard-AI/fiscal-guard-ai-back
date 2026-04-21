class EventNotFoundError(Exception):
    """Raised when an event is not found in the system."""

    pass


class InvalidEventStatusError(Exception):
    """Raised when an event has an invalid status for the requested operation."""

    pass
