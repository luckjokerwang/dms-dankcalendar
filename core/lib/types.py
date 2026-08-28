"""
types.py
Strong typing definitions and standard envelope structures for Dank Calendar Plus Core.
"""

from typing import TypedDict, List, Optional, Literal, Dict, Any, Union

class ErrorDetail(TypedDict, total=False):
    code: str
    message: str
    details: Optional[str]

class StandardResponse(TypedDict, total=False):
    status: Literal["ok", "error"]
    code: int
    data: Any
    error: Optional[ErrorDetail]
    timestamp: int

class CalendarItem(TypedDict, total=False):
    id: str
    name: str
    accountName: Optional[str]
    holdsTasks: bool
    holdsEvents: bool
    color: Optional[str]

class TaskItem(TypedDict, total=False):
    id: str
    summary: str
    calendarId: str
    calendarName: str
    status: Literal["needs_action", "completed"]
    percentComplete: int
    priority: int  # 0: None, 1: High, 5: Med, 9: Low
    due: Optional[str]
    completed: Optional[Union[bool, str]]

class TasksListResult(TypedDict):
    pending: List[TaskItem]
    completed: List[TaskItem]
    pendingCount: int
    completedCount: int
    defaultCalendarId: str
    taskCalendars: List[Dict[str, str]]

class EventItem(TypedDict, total=False):
    id: str
    uid: Optional[str]
    summary: str
    start: str
    end: str
    allDay: bool
    location: Optional[str]
    description: Optional[str]
    meetingUrl: Optional[str]
    url: Optional[str]
    recurringId: Optional[str]
    calendarId: Optional[str]

class AgendaResult(TypedDict):
    events: List[EventItem]
    count: int

class NextEventResult(TypedDict, total=False):
    summary: str
    start: str
    end: str
    allDay: bool
    location: str
    description: str
    meetingUrl: str
    url: str

class ModelItem(TypedDict, total=False):
    id: str
    name: str
    desc: Optional[str]
    contextWindow: Optional[int]

class ProviderConfig(TypedDict, total=False):
    id: str
    name: str
    baseUrl: str
    apiKey: str
    enabled: bool
    icon: str
    color: str
    protocol: Optional[str]
    models: List[ModelItem]

class ProviderStoreConfig(TypedDict, total=False):
    activeProvider: str
    activeModel: str
    providers: List[ProviderConfig]

class ChatMessage(TypedDict, total=False):
    role: Literal["user", "assistant", "system"]
    content: str
    timestamp: Optional[str]
    imagePath: Optional[str]
    filePath: Optional[str]
    proposal: Optional[Dict[str, Any]]

class SessionItem(TypedDict, total=False):
    id: str
    title: str
    createdAt: str
    updatedAt: str
    messages: List[ChatMessage]
    proposal: Optional[Dict[str, Any]]
