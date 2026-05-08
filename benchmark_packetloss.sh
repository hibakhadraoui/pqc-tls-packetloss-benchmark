#!/bin/bash
OPENSSL=/home/hibalenovo/pqc-tls/openssl-3.3/bin/openssl
CERT=/home/hibalenovo/pqc-tls/certs/server.crt
KEY=/home/hibalenovo/pqc-tls/certs/server.key
RESULTS_DIR=/home/hibalenovo/pqc-tls/results_packetloss

RUNS=200
PORT=4433

export LD_LIBRARY_PATH=/home/hibalenovo/pqc-tls/liboqs-install/lib:/home/hibalenovo/pqc-tls/openssl-3.3/lib64:$LD_LIBRARY_PATH
export OPENSSL_CONF=/home/hibalenovo/pqc-tls/openssl-oqs.cnf

mkdir -p $RESULTS_DIR

ALGORITHMS=("x25519" "mlkem768" "frodo640aes" "bikel1" "x25519_mlkem768")
LOSS_RATES=("0" "1" "3" "5" "10")
RTT_MS=50

run_benchmark() {
    local alg=$1
    local loss=$2
    local outfile="$RESULTS_DIR/${alg}_loss${loss}.csv"

    echo "Testing $alg at ${loss}% packet loss..."

    sudo tc qdisc del dev lo root 2>/dev/null
    if [ "$loss" != "0" ] || [ "$RTT_MS" != "0" ]; then
        sudo tc qdisc add dev lo root netem delay ${RTT_MS}ms loss ${loss}%
    fi

    $OPENSSL s_server -accept $PORT -cert $CERT -key $KEY \
        -groups $alg -www -quiet &
    SERVER_PID=$!
    sleep 2

    echo "handshake_ms" > $outfile
    for i in $(seq 1 $RUNS); do
        START=$(date +%s%N)
        echo | $OPENSSL s_client -connect localhost:$PORT \
            -groups $alg -no_ign_eof 2>/dev/null >/dev/null
        END=$(date +%s%N)

        ELAPSED=$(( (END - START) / 1000000 ))
        echo "$ELAPSED" >> $outfile

        if [ $((i % 50)) -eq 0 ]; then
            echo "  $i/$RUNS done"
        fi
    done

    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    sudo tc qdisc del dev lo root 2>/dev/null

    echo "Done: $outfile"
}

for loss in "${LOSS_RATES[@]}"; do
    for alg in "${ALGORITHMS[@]}"; do
        run_benchmark "$alg" "$loss"
        sleep 2
    done
done

echo "All benchmarks complete. Results in $RESULTS_DIR/"
