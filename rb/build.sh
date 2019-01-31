cd ../
crystal build rb/serv.cr --release -o rb/bin_serv
crystal build rb/cli.cr --release -o rb/bin_cli
rm *.dwarf
cd -
