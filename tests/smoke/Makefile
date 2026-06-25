CC = mpicc
TESTS = hello_world get_version init_finalize comm_info bcast

all: $(TESTS)

%: %.c
	$(CC) -o $@ $<

clean:
	rm -f $(TESTS)

.PHONY: all clean
