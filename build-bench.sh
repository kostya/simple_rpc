crystal build bench/rpc.cr --release -o bin_bench_rpc
crystal build bench/bench_server.cr --release -o bin_bench_server
crystal build bench/bench_client.cr --release -o bin_bench_client
rm *.dwarf
