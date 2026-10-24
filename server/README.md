# Heartbeat Monitoring Server

파란학기제 비접촉 심박 모니터링 시스템의 서버 및 데이터베이스 개발 프로젝트입니다.

## 프로젝트 개요

UWB 센서와 Raspberry Pi 5에서 처리한 심박 측정 정보를
FastAPI 서버에서 수신하고 PostgreSQL에 저장하여
Flutter 모바일 애플리케이션에서 조회할 수 있도록 개발합니다.

## 기술 스택

- Python
- FastAPI
- PostgreSQL 16
- SQLAlchemy
- Naver Cloud Platform
- Ubuntu 24.04

## 주요 구현 기능

- 심박 측정 데이터 수신 및 저장
- 운전자별 최신 심박 상태 조회
- 과거 측정 이력 및 날짜별 측정 결과 조회
- 이벤트 및 사용자 정보 조회
- Flutter 애플리케이션과 REST API 연동

## 개발 진행 상황

- [x] PostgreSQL 데이터베이스 구축
- [x] FastAPI REST API 구현
- [x] HTTP 요청을 통한 데이터 저장 및 조회 검증
- [x] Flutter 애플리케이션 API 연동 확인
- [ ] Raspberry Pi 5와 실제 데이터 통신 연동
- [ ] 연속 데이터 전송 및 통신 안정성 검증
- [ ] 전체 시스템 통합 검증

## 보안

데이터베이스 접속 정보는 환경변수로 관리하며,
실제 비밀번호와 인증 정보는 저장소에 포함하지 않습니다.
