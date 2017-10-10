db: db.d dbuild/util.d dbuild/core.d dbuild/run.d
	dmd -ofdb -debug -g -I. $^

clean:
	rm -rf db
