CC = dmd

EXECUTABLES = gamebb

all: $(EXECUTABLES) clean

gamebb: gamebb.d
	$(CC) $@

clean:
	rm -f *.o