import os
from datetime import datetime, timezone
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.exc import SQLAlchemyError

load_dotenv()

database_url = URL.create(
    "postgresql+psycopg2",
    username=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
    host=os.environ.get("DB_HOST", "127.0.0.1"),
    port=int(os.environ.get("DB_PORT", "5432")),
    database=os.environ["DB_NAME"],
)

engine = create_engine(
    database_url,
    pool_pre_ping=True,
)

app = FastAPI(
    title="Heartbeat Monitoring API",
    version="1.0.0",
)

# 개발 단계용. 실제 서비스 배포 시 허용 Origin을 제한할 예정.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class MeasurementIn(BaseModel):
    uid: str
    sessionId: Optional[int] = None
    deviceId: Optional[str] = None
    heartRate: Optional[int] = Field(default=None, ge=20, le=250)
    signalQuality: str = "UNKNOWN"
    deviceStatus: str = "UNKNOWN"
    measurementTime: Optional[datetime] = None


@app.get("/")
def root():
    return {
        "service": "heartbeat-server",
        "docs": "/docs"
    }


@app.get("/health")
def health():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {
            "status": "ok",
            "database": "connected"
        }
    except SQLAlchemyError:
        raise HTTPException(
            status_code=503,
            detail="Database connection failed"
        )


@app.get("/api/v1/users/{uid}")
def get_user(uid: str):
    with engine.connect() as conn:
        row = conn.execute(
            text("""
                SELECT
                    uid,
                    name,
                    user_type AS "userType"
                FROM users
                WHERE uid = :uid
            """),
            {"uid": uid},
        ).mappings().first()

    if row is None:
        raise HTTPException(status_code=404, detail="User not found")

    return dict(row)


@app.get("/api/v1/drivers/{uid}/status")
def get_driver_status(uid: str):
    with engine.connect() as conn:
        row = conn.execute(
            text("""
                SELECT
                    driver_uid AS uid,
                    heart_rate AS "heartRate",
                    measured_at AS "measurementTime",
                    signal_quality AS "signalQuality",
                    device_status AS "deviceStatus"
                FROM measurements
                WHERE driver_uid = :uid
                ORDER BY measured_at DESC
                LIMIT 1
            """),
            {"uid": uid},
        ).mappings().first()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Measurement not found"
        )

    return dict(row)


@app.get("/api/v1/drivers/{uid}/measurements")
def get_measurements(
    uid: str,
    limit: int = Query(default=100, ge=1, le=500),
):
    with engine.connect() as conn:
        rows = conn.execute(
            text("""
                SELECT
                    measurement_id AS "measurementId",
                    heart_rate AS "heartRate",
                    measured_at AS "measurementTime",
                    signal_quality AS "signalQuality",
                    device_status AS "deviceStatus",
                    device_id AS "deviceId",
                    session_id AS "sessionId"
                FROM measurements
                WHERE driver_uid = :uid
                ORDER BY measured_at DESC
                LIMIT :limit
            """),
            {
                "uid": uid,
                "limit": limit
            },
        ).mappings().all()

    return [dict(row) for row in rows]


@app.get("/api/v1/drivers/{uid}/events")
def get_events(
    uid: str,
    limit: int = Query(default=100, ge=1, le=500),
):
    with engine.connect() as conn:
        rows = conn.execute(
            text("""
                SELECT
                    event_id AS "eventId",
                    event_type AS "eventType",
                    event_time AS "eventTime",
                    heart_rate AS "heartRate",
                    message,
                    session_id AS "sessionId"
                FROM events
                WHERE driver_uid = :uid
                ORDER BY event_time DESC
                LIMIT :limit
            """),
            {
                "uid": uid,
                "limit": limit
            },
        ).mappings().all()

    return [dict(row) for row in rows]


@app.post(
    "/api/v1/measurements",
    status_code=status.HTTP_201_CREATED
)
def create_measurement(data: MeasurementIn):
    measurement_time = data.measurementTime or datetime.now(timezone.utc)

    with engine.begin() as conn:
        user_exists = conn.execute(
            text("SELECT 1 FROM users WHERE uid = :uid"),
            {"uid": data.uid},
        ).first()

        if user_exists is None:
            raise HTTPException(
                status_code=404,
                detail="User not found"
            )

        if data.deviceId is not None:
            device_exists = conn.execute(
                text("""
                    SELECT 1
                    FROM devices
                    WHERE device_id = :device_id
                """),
                {"device_id": data.deviceId},
            ).first()

            if device_exists is None:
                raise HTTPException(
                    status_code=404,
                    detail="Device not found"
                )

        if data.sessionId is not None:
            session_exists = conn.execute(
                text("""
                    SELECT 1
                    FROM measurement_sessions
                    WHERE session_id = :session_id
                """),
                {"session_id": data.sessionId},
            ).first()

            if session_exists is None:
                raise HTTPException(
                    status_code=404,
                    detail="Session not found"
                )

        row = conn.execute(
            text("""
                INSERT INTO measurements (
                    session_id,
                    driver_uid,
                    device_id,
                    heart_rate,
                    signal_quality,
                    device_status,
                    measured_at
                )
                VALUES (
                    :session_id,
                    :uid,
                    :device_id,
                    :heart_rate,
                    :signal_quality,
                    :device_status,
                    :measured_at
                )
                RETURNING
                    measurement_id AS "measurementId",
                    driver_uid AS uid,
                    session_id AS "sessionId",
                    device_id AS "deviceId",
                    heart_rate AS "heartRate",
                    signal_quality AS "signalQuality",
                    device_status AS "deviceStatus",
                    measured_at AS "measurementTime"
            """),
            {
                "session_id": data.sessionId,
                "uid": data.uid,
                "device_id": data.deviceId,
                "heart_rate": data.heartRate,
                "signal_quality": data.signalQuality,
                "device_status": data.deviceStatus,
                "measured_at": measurement_time,
            },
        ).mappings().one()

    return dict(row)


class MockLoginIn(BaseModel):
    uid: str


@app.post("/api/v1/auth/mock-login")
def mock_login(data: MockLoginIn):
    with engine.connect() as conn:
        row = conn.execute(
            text("""
                SELECT
                    uid,
                    name,
                    user_type AS "userType"
                FROM users
                WHERE uid = :uid
            """),
            {"uid": data.uid},
        ).mappings().first()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    result = dict(row)
    result["mockLogin"] = True
    return result


@app.get("/api/v1/users/{uid}/drivers")
def get_connected_drivers(uid: str):
    with engine.connect() as conn:
        user = conn.execute(
            text("""
                SELECT uid, user_type
                FROM users
                WHERE uid = :uid
            """),
            {"uid": uid},
        ).mappings().first()

        if user is None:
            raise HTTPException(
                status_code=404,
                detail="User not found"
            )

        rows = conn.execute(
            text("""
                SELECT
                    u.uid,
                    u.name,
                    c.relationship_type AS "relationshipType",
                    latest.heart_rate AS "heartRate",
                    latest.measured_at AS "measurementTime",
                    latest.signal_quality AS "signalQuality",
                    latest.device_status AS "deviceStatus"
                FROM user_connections c
                JOIN users u
                    ON u.uid = c.driver_uid
                LEFT JOIN LATERAL (
                    SELECT
                        m.heart_rate,
                        m.measured_at,
                        m.signal_quality,
                        m.device_status
                    FROM measurements m
                    WHERE m.driver_uid = u.uid
                    ORDER BY m.measured_at DESC
                    LIMIT 1
                ) latest ON TRUE
                WHERE c.viewer_uid = :uid
                ORDER BY u.name
            """),
            {"uid": uid},
        ).mappings().all()

    return [dict(row) for row in rows]


@app.get("/api/v1/drivers/{uid}/measurements/by-date")
def get_measurements_by_date(
    uid: str,
    measurementDate: str,
    limit: int = Query(default=500, ge=1, le=1000),
):
    try:
        target_date = datetime.strptime(
            measurementDate,
            "%Y-%m-%d"
        ).date()
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="measurementDate must be YYYY-MM-DD"
        )

    with engine.connect() as conn:
        rows = conn.execute(
            text("""
                SELECT
                    measurement_id AS "measurementId",
                    heart_rate AS "heartRate",
                    measured_at AS "measurementTime",
                    signal_quality AS "signalQuality",
                    device_status AS "deviceStatus",
                    device_id AS "deviceId",
                    session_id AS "sessionId"
                FROM measurements
                WHERE driver_uid = :uid
                  AND measured_at::date = :measurement_date
                ORDER BY measured_at DESC
                LIMIT :limit
            """),
            {
                "uid": uid,
                "measurement_date": target_date,
                "limit": limit
            },
        ).mappings().all()

    return [dict(row) for row in rows]
