db: db.d dbuild/util.d dbuild/core.d dbuild/config.d dbuild/compilers.d dbuild/dlangcontracts.d
	dmd -ofdb -debug -g -I. $^

clean:
	rm -rf db
