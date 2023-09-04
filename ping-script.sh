#!/bin/bash

ping_count=5
db_name=$POSTGRES_DB
db_user=$POSTGRES_USER
db_pass=$POSTGRES_PASSWORD
db_port=$POSTGRESS_PORT
db_host="postgres-service"

PGPASSWORD="$db_pass" psql -h "$db_host" -p "$db_port" -d "$db_name" -U "$db_user" -c "
CREATE TABLE domain_info (
    id SERIAL PRIMARY KEY,
    ping_time timestamp without time zone DEFAULT current_timestamp,
    domain_name VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    jitter FLOAT NOT NULL,
    packet_loss FLOAT NOT NULL,
    avg_ping_time FLOAT NOT NULL
);"

function getPing() {
    ping -c $ping_count $1 > domain_info
    packet_loss=$(awk -v count="$ping_count" 'NR == (count + 4) {print $6}' domain_info | sed 's/%//')
    avg_ping=$(awk -v count="$ping_count" 'NR == (count + 5) {print $4}' domain_info | cut -d'/' -f2)
    min_ping=$(awk -v count="$ping_count" 'NR == (count + 5) {print $4}' domain_info | cut -d'/' -f1)
    max_ping=$(awk -v count="$ping_count" 'NR == (count + 5) {print $4}' domain_info | cut -d'/' -f3)
    jitter=$(echo "$max_ping - $min_ping" | bc)
    ip=$(awk 'NR == 1 {print $3}' domain_info | sed 's/[()]//g')

    PGPASSWORD="$db_pass" psql -h $db_host -p 5432 -U $db_user -d $db_name << EOF
    INSERT INTO domain_info (domain_name, ip_address, jitter, packet_loss, avg_ping_time)
    VALUES ('$1', '$ip', $jitter, $packet_loss, $avg_ping);
EOF
    echo "inserted $1 $ip"
}

while :; do
    while IFS= read -r line
    do
        getPing $line
    done < /my-domain/urls
    sleep 30
done
rm -f domain_info