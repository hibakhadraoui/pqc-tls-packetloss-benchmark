#!/bin/bash

OPENSSL=/home/hibalenovo/pqc-tls/openssl-3.3/bin/openssl
CERT=/home/hibalenovo/pqc-tls/certs/server.crt
KEY=/home/hibalenovo/pqc-tls/certs/server.key
RESULTS_DIR=/home/hibalenovo/pqc-tls/results_packetloss
RUNS=200
PORT=4433

export LD_LIBRARY_PATH=/home/hibalenovo/pqc-tls/liboqs-install/lib:/home/hibalenovo/pqc-tls/openssl-3.3/lib64:$LD_LIBRARY_PATH
export OPENSSL_CONF=/home/hibalenovo/pqc-tls/openssl-oqs.cnf

LOSS_RATES=("0" "1" "3" "5" "10")
RTT_MS=50
ALG="X25519MLKEM768"

for loss in "${LOSS_RATES[@]}"; do
    echo "Testing $ALG at ${loss}% packet loss..."
    sudo tc qdisc del dev lo root 2>/dev/null
    if [ "$loss" != "0" ] || [ "$RTT_MS" != "0" ]; then
        sudo tc qdisc add dev lo root netem delay ${RTT_MS}ms loss ${loss}%
    fi

    $OPENSSL s_server -accept $PORT -cert $CERT -key $KEY \
        -groups $ALG -www -quiet &
    SERVER_PID=$!
    sleep 2

    echo "handshake_ms" > "$RESULTS_DIR/${ALG}_loss${loss}.csv"
    for i in $(seq 1 $RUNS); do
        START=$(date +%s%N)
        echo | $OPENSSL s_client -connect localhost:$PORT \
            -groups $ALG -no_ign_eof 2>/dev/null >/dev/null
        END=$(date +%s%N)
        ELAPSED=$(( (END - START) / 1000000 ))
        echo "$ELAPSED" >> "$RESULTS_DIR/${ALG}_loss${loss}.csv"
        if [ $((i % 50)) -eq 0 ]; then echo "  $i/$RUNS done"; fi
    done

    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    sudo tc qdisc del dev lo root 2>/dev/null
    echo "Done"
    sleep 2
done
