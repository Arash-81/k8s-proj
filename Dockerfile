FROM ubuntu

WORKDIR /app

ENV POSTGRES_DB=""
ENV POSTGRES_USER=""
ENV POSTGRES_PASSWORD=""
ENV POSTGRESS_PORT=""
ENV db_host=""

RUN apt-get update && apt-get install -y postgresql-client iputils-ping bc

COPY ping-script.sh .

CMD ["/bin/bash", "ping-script.sh"]