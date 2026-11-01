#!/bin/sh
# 최초 기동(빈 데이터 디렉터리) 때만 실행됨: 앱별 사용자/DB 생성
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<SQL
CREATE USER mlflow WITH PASSWORD '${MLFLOW_DB_PASSWORD}';
CREATE DATABASE mlflow OWNER mlflow;
CREATE USER feast WITH PASSWORD '${FEAST_DB_PASSWORD}';
CREATE DATABASE feast OWNER feast;
SQL
