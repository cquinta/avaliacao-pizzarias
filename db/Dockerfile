FROM postgres:16-alpine

ENV POSTGRES_DB=pizzarias
ENV POSTGRES_USER=postgres



COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432

