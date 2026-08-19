FROM postgres:16-alpine

ENV POSTGRES_DB=pizzarias
ENV POSTRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432

